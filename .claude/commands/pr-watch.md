---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(bash:*), Bash(python3:*), Bash(mkdir:*), Bash(cat:*), Bash(rm:*), Bash(printf:*), Bash(echo:*), Bash(grep:*), Bash(sed:*), Bash(jq:*), Bash(ls:*), Read, Write, Edit, Skill, AskUserQuestion, ScheduleWakeup
description: PR 作成後に CI とレビューコメントを監視し、CI 失敗と AI レビュー指摘に対応する（dev-flow Phase 7）
argument-hint: "[PR番号] [--ai-logins login,login] (省略時は現在ブランチの PR / Codex ボット)"
---

## Purpose

`/pr` の後、PR が merge されるまで **セッション内で** 見張る。

- CI が落ちたら原因を確定し、確定できたときだけ直して push する
- AI レビューボットの指摘は `model-consensus` で裁定し、本物なら直して返信、誤りなら根拠つきで返信する
- 人間のコメントは報告するだけ。裁定が割れた指摘（`UNRESOLVED`）はユーザーに渡す

判断の実体は既存 skill が持つ（`error-diagnosis` / `model-consensus` / `quality-gate` / `context-hygiene`）。
このコマンドの仕事は **ポーリングと、結果をどの skill に渡すかの振り分け** だけ。

## Context

- Current branch: !`git branch --show-current`
- PR: !`gh pr view --json number,state,url,headRefOid 2>&1 | head -5`
- Local HEAD: !`git rev-parse HEAD`
- State files: !`ls .claude/pr-review/pr-watch-*.json 2>/dev/null || echo "(none)"`

## 道具

```bash
POLL=~/.claude/skills/pr-watch/scripts/pr-watch-poll.sh
PR=<番号>                                   # 引数、無ければ Context の PR
STATE=.claude/pr-review/pr-watch-${PR}.json  # 処理済みコメント ID の記録。git 管理外
AI_LOGINS=chatgpt-codex-connector[bot]       # --ai-logins で上書き。[bot] の有無は問わない

bash "$POLL" init  --pr "$PR" --state "$STATE"                            # 無ければ作る。あれば no-op
bash "$POLL" poll  --pr "$PR" --state "$STATE" --ai-logins "$AI_LOGINS"   # 取得のみ。書かない
bash "$POLL" mark  --pr "$PR" --state "$STATE" --id <ID> [--id ...] --action seen|replied
bash "$POLL" set   --pr "$PR" --state "$STATE" --key <KEY> --value <VALUE> # 連続失敗数などの控え
bash "$POLL" reply --pr "$PR" --state "$STATE" --id <ID> --kind thread|review|issue \
                   [--thread-id <NODE_ID>] --body-file <FILE> [--resolve]
```

`poll` の出力（1 行 JSON）:

| キー | 意味 |
|------|------|
| `pr_state` | `OPEN` / `MERGED` / `CLOSED` |
| `head_sha` | PR head。ローカル HEAD と違えば先に `git pull --ff-only` |
| `checks[]` | `{name, state(success/failure/pending/skipped), url}` |
| `checks_summary` | `failure` > `pending` > `success` の優先で 1 語 |
| `new_ai_comments[]` | 未処理の AI ボットコメント。`kind` / `thread_id` / `path` / `line` / `round`（同一スレッドで何度目の指摘か） |
| `new_human_comments[]` | 未処理の人間コメント |
| `vars` | `set` で控えた値（`poll_failures` / `last_fix_head`） |
| `pending_resolves[]` | 返信済みで resolve だけ失敗しているスレッド（`id` / `thread_id`） |

resolved 済みスレッド、自分のコメント、処理済み ID は出てこない。
`reply` は同じ ID に二度投稿しない: 状態ファイルを見るだけでなく、本文に付ける不可視マーカー
`<!-- pr-watch:reply-to:<ID> -->` を GitHub 側でも照合する（状態ファイルを失っても二重投稿しない）。
返信済みで resolve だけ失敗した ID は、同じ `reply --resolve` を再実行すると resolve だけやり直す。

## 0. 前提

1. `git branch --show-current` が空（detached HEAD）→ 停止
2. PR が無い（`gh pr view` が "no pull requests found"）→ 「PR なし」と報告して **終了。wakeup は予約しない**
3. `gh` が確認不能（auth / network）→ 「確認不能」と報告して終了。✅ にしない
4. `.claude/pr-review/` を `.git/info/exclude` に登録（`flow-gates.md` の手順）
5. `bash "$POLL" init --pr "$PR" --state "$STATE"`（初回 tick で状態ファイルができる）

## 1 tick の手順

毎 tick、この順で進める。途中で「停止条件」に当たったらそこで止める。

### Step 1: 取得

```bash
if OUT=$(bash "$POLL" poll --pr "$PR" --state "$STATE" --ai-logins "$AI_LOGINS"); then
  bash "$POLL" set --pr "$PR" --state "$STATE" --key poll_failures --value 0
else
  N=$(( $(jq -r '.vars.poll_failures // 0' "$STATE") + 1 ))
  bash "$POLL" set --pr "$PR" --state "$STATE" --key poll_failures --value "$N"
fi
```

`poll` が失敗したら（exit 1）その tick は何もせず、gh のエラーを報告して次の wakeup を予約する。
`poll_failures` が 3 になったら **停止** してユーザーに知らせる。

### Step 2: 終端判定

`pr_state` が `MERGED` / `CLOSED` → 最終報告を出し、`ScheduleWakeup(stop: true)`。

### Step 3: CI

| `checks_summary` | 動作 |
|------------------|------|
| `success` | 次へ |
| `pending` | 次へ（wakeup は短め） |
| `failure` | 下記 |

CI red のとき、**最初に** 再失敗かどうかを見る:

0. `vars.last_fix_head` が今の `head_sha` と同じなら、修正 push 後の再失敗。ログ取得も診断もせず **停止**
   （直し損ねを積まない）。2 回分の diff と失敗内容を残す
1. 失敗ジョブのログを取る
   ```bash
   gh run list --branch "$(git branch --show-current)" --status failure --limit 3 --json databaseId,name,headSha
   gh run view <databaseId> --log-failed | tail -200
   ```
   `head_sha` と一致する run だけを見る（古い run の失敗を直さない）
2. `Skill(skill="error-diagnosis")` に **ログ + 変更差分** を渡す
3. 結果が **確定** → 修正 → `Skill(skill="quality-gate")` → commit → `git push`
   → `set --key last_fix_head --value "$(git rev-parse HEAD)"` を控え、次の tick へ（wakeup は CI 所要時間に合わせる）
4. 結果が **仮説** 止まり → **停止**。失敗ジョブ名・ログ抜粋・仮説を報告してユーザー判断を待つ

### Step 4: AI レビューコメント

まず `pending_resolves[]` を上記 6 の手順で片付ける。次に `new_ai_comments[]` を `thread_id` ごとにまとめる。

1. `round > 2` のスレッドがあれば **停止** して AskUserQuestion（ボットとの往復は 2 回まで）
2. `kind: review` / `issue` で、具体的な指摘を含まない要約本文（「Here are some automated review suggestions」等）は
   `mark --action seen` して終わり。返信しない
3. 残りの指摘を **まとめて** `Skill(skill="model-consensus")` に渡す。入力は指摘本文 + `path:line` + 現在の diff。
   model-consensus が返す区分で振り分ける:

| 区分 | 動作 |
|------|------|
| `AGREED` / `ADJUDICATED: real` | 修正を書く（複数件は 1 commit にまとめてよい） |
| `ADJUDICATED: false` | 返信のみ（下記テンプレート、根拠 `file:line` 必須） |
| `UNRESOLVED` | **何も投稿・push せず停止**。AskUserQuestion で行き先を聞く: 修正する / 返信する / 破棄する / 質問として出す |

4. 修正がある場合: `Skill(skill="quality-gate")` → commit → `git push` → commit SHA を控える
5. 返信: 指摘ごとに下書きを `.claude/pr-review/reply-draft-<ID>.md` に書き、
   `Skill(skill="context-hygiene", args="--trigger=reply --draft=.claude/pr-review/reply-draft-<ID>.md")` を通してから
   ```bash
   bash "$POLL" reply --pr "$PR" --state "$STATE" --id <ID> --kind thread --thread-id <thread_id> \
        --body-file .claude/pr-review/reply-draft-<ID>.md --resolve
   rm -f .claude/pr-review/reply-draft-<ID>.md
   ```
   `kind: review` / `issue` は `--kind review|issue`（`--resolve` 無し。PR 全体へのコメントになる）
6. `reply` が `resolved: false` を返したら（返信は済んでいる）そのまま進む。次の tick の `poll` が
   `pending_resolves[]` に載せるので、Step 4 の先頭で
   `bash "$POLL" reply --pr "$PR" --state "$STATE" --id <id> --kind thread --thread-id <thread_id> --resolve`
   を実行する（本文は不要。投稿はされず resolve だけやり直される）

### Step 5: 人間のコメント

`new_human_comments[]` は **自動で何もしない**。tick 報告に著者と本文冒頭を列挙し、
`mark --action seen` で次の tick から出ないようにする。返信するかはユーザーが決める。

### Step 6: 報告と次の wakeup

報告フォーマット（下記）を出し、`ScheduleWakeup` を呼ぶ。`prompt` には **このコマンドの呼び出しをそのまま**
（`/pr-watch <PR番号> [--ai-logins ...]`）渡す。

| 状況 | `delaySeconds` | `noop` |
|------|----------------|--------|
| 今 push した / `checks_summary: pending` | 300（CI 1 周分。CI が長い repo なら所要時間に合わせる） | false |
| CI green、未処理コメントなし | 1800 | true |
| 何か処理した | 1200 | false |

## 返信テンプレート

文面規約は `.claude/rules/comment-policy.md`。**この会話を見ていない人が読んで通じる**こと。
「指摘のとおり」「先ほど」「codex が」のようなセッション参照は書かない。言語は PR description に合わせる。

修正した（`AGREED` / `ADJUDICATED: real`）:

```
Fixed in <short SHA>: <何をどう変えたか 1 文>. <非自明なら理由 1 文>.
```

修正しない（`ADJUDICATED: false`）:

```
Not changing this: <前提が成り立たない理由>. <それを防いでいる箇所 `path:line`>.
```

## 停止条件（ユーザーに渡す）

| 条件 | 残すもの |
|------|---------|
| CI 失敗の原因が「仮説」止まり | 失敗ジョブ名 / ログ抜粋 / 仮説一覧 |
| 修正 push 後に同じ check がまた落ちた | 2 回分の diff と失敗内容 |
| `UNRESOLVED` の指摘 | 指摘本文 / 両モデルの見解 / AskUserQuestion |
| 同一スレッドで `round > 2` | スレッド URL と往復の要約 |
| `vars.poll_failures` が 3 | gh のエラー |
| PR が merged / closed | 最終報告（`ScheduleWakeup(stop: true)`） |

停止したら **wakeup を予約しない**。ユーザーの返答後に `/pr-watch` を再実行すれば状態ファイルから続きになる。

## Output（各 tick）

```markdown
## PR Watch — #<番号> tick <N>

- head: <sha> / CI: ✅ success | ⏳ pending | ⛔ failure (<失敗 check 名>)
- AI 指摘: 新規 <n> 件 → 修正 <a> / 返信のみ <b> / UNRESOLVED <c> / 要約のみ <d>
- 人間コメント: <著者>: <本文冒頭>（<n> 件）
- 投稿した返信: <ID> → <URL>
- 次: <delaySeconds> 秒後 / 停止（理由）
```

## Rules

1. **投稿・push するのは裁定が付いたものだけ。** `UNRESOLVED` と「仮説」は必ずユーザーに渡す
2. 返信は `reply` サブコマンド経由のみ（二重投稿防止のマーカー照合はここにしかない）。`gh api` で直接返信しない
3. 人間のコメントに自動返信しない。人間のスレッドを resolve しない
4. 修正は必ず `quality-gate` を通してから push する
5. 応答は日本語（`.claude/rules/language.md`）。返信コメントは PR の言語
6. 状態ファイルを手で消さない。消すと人間のコメントがもう一度「新規」として報告される（返信の二重投稿はマーカー照合で防がれる）
