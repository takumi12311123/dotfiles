---
name: context-hygiene
description: |
  セッション文脈依存のテキストを検出して排除する BLOCKING gate。
  対象は 4 面: (1) コードのインラインコメント (2) commit message (3) PR description (4) PR title。
  「この会話も PR も見ていない人が 1 年後に読んで通じるか」で判定し、
  永続すべきものはコードに残し、レビュー向け説明は prr の PR コメント下書きに移送する。
  quality-gate (commit/PR 前) から自動発火。`/commit` `/pr` `/push` からも発火。
  判定基準の実体は .claude/rules/comment-policy.md（単一の情報源）。
metadata:
  auto-trigger: true
  invoked-by: [quality-gate, commit, pr, push, user]
  blocking: true
  policy: .claude/rules/comment-policy.md
---

# Context Hygiene

## Purpose

**PR を読むのは、その会話にいなかった人。**

AI と対話しながら書くと、会話の痕跡がコードと PR に漏れる:
`// ご要望どおり` `// 指摘対応` `## 概要: 依頼された件の対応` `fix: レビュー対応`。
これらは書いた瞬間だけ意味があり、マージされた瞬間にノイズになる。

この skill は永続面をすべて走査し、**セッション文脈を機械的に剥がす**。
剥がした情報のうち価値があるものは、正しい置き場所（`prr` の PR コメント）へ移送する。

**判定基準（何をどこに置くか）は `.claude/rules/comment-policy.md` が唯一の情報源。**
この SKILL.md には「どう検出し、どう直し、どこへ移すか」の手順だけを書く。基準を再定義しない。

## Scope

| 面 | 対象 | 失敗時 |
|----|------|--------|
| S1 | **追加された**コメント（未コミット変更を含む） | BLOCKING（コードを直す） |
| S2 | commit message（**これから作るものを含む**） | commit 前は BLOCKING / 既存 commit は警告 |
| S3 | PR description（**投稿前の下書きを含む**） | BLOCKING（投稿前に直す） |
| S4 | PR title（`fix: レビュー対応` 等） | BLOCKING（投稿前に直す） |

### trigger 別の対象

| trigger | S1 | S2 | S3 | S4 |
|---------|----|----|----|----|
| `--trigger=commit` | ✅ 未コミット変更 | ✅ **これから作る message** | — | — |
| `--trigger=pr` | ✅ 未コミット + `BASE..HEAD` | ✅ `BASE..HEAD`（警告） | ✅ **投稿前の下書き** | ✅ 下書き |
| `--trigger=push` | ✅ 未コミット + `BASE..HEAD` | ✅（警告） | ✅ 既存 PR body | ✅ 既存 PR title |
| `--trigger=manual` / 引数なし | ✅ | ✅（警告） | PR があれば ✅ | PR があれば ✅ |

### 対象外（この gate では拾わない）

嘘の安心を与えないために明示する。

- diff に現れない**既存**コメント（過去に混入したものは別途 sweep が必要）
- 複数行 docstring / ブロックコメントの途中行（先頭行しか機械検出できない）
- Markdown / CHANGELOG 等の散文（レビューで人間が読む）
- マージ済み PR / 過去 commit の履歴（書き換えない）

## Step 0: 対象範囲の決定

**固定の `main` を前提にしない。** PR があれば PR のベースブランチが正。

```bash
# 1) PR があれば baseRefName を採用
#    stderr は捨てない — "no PR" と "確認不能" を後で区別するために必要
GH_ERR="${TMPDIR:-/tmp}/gh-err.txt"
PR_JSON=$(gh pr view --json number,title,body,baseRefName 2>"$GH_ERR")
GH_STATUS=$?
BASE_REF=$(printf '%s' "$PR_JSON" | jq -r '.baseRefName // empty' 2>/dev/null)

# 2) 無ければ remote の既定ブランチ、最後に main
if [ -z "$BASE_REF" ]; then
  BASE_REF=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
  [ -z "$BASE_REF" ] && BASE_REF=main
fi

BASE=$(git merge-base HEAD "origin/$BASE_REF" 2>/dev/null || git merge-base HEAD "$BASE_REF")
```

**`gh` が失敗したときに黙って素通りさせない。**

| `gh pr view` の結果 | 扱い |
|---------------------|------|
| exit 0 + JSON | PR あり。S3/S4 を実施 |
| exit ≠ 0 かつ `$GH_ERR` が "no pull requests found" 相当 | PR 無し。S3/S4 はスキップ（正常） |
| exit ≠ 0 かつそれ以外（auth / network / 非 GitHub remote） | **確認不能**。S3/S4 を「未実施」としてユーザーに明示報告する。✅ にしない |

## S1: コードコメント監査

### 1-1. 追加コメント行の収集

**未コミット変更を必ず含める**（`/commit` から呼ばれる時点では commit はまだ存在しない）。

```bash
OUT="${TMPDIR:-/tmp}/added-lines.txt"
: > "$OUT"

collect() {  # $1: diff コマンドの出力を file:line:content 化
  awk '
    /^\+\+\+ b\// { file = substr($0, 7); next }
    /^@@/ {
      # ハンクヘッダから新側の開始行を取る (@@ -a,b +c,d @@ ...)
      if (match($0, /\+[0-9]+/)) line = substr($0, RSTART + 1, RLENGTH - 1)
      next
    }
    /^\+/ { print file ":" line ":" substr($0, 2); line++ }
  '
}

# (a) 未コミットの変更 (staged + unstaged)
git diff HEAD --unified=0 | collect >> "$OUT"

# (b) 未追跡ファイルは全行が追加行 (.gitignore 対象は --exclude-standard が除外)
#     バイナリはコメント監査の対象外なので grep -I で弾く
git ls-files --others --exclude-standard | while IFS= read -r f; do
  [ -f "$f" ] || continue
  grep -Iq . "$f" 2>/dev/null || continue   # binary skip
  awk -v f="$f" '{ print f ":" NR ":" $0 }' "$f" >> "$OUT"
done

# (c) trigger=pr / push / manual のときは commit 済み分も
if [ "$TRIGGER" != "commit" ]; then
  git diff "$BASE"..HEAD --unified=0 | collect >> "$OUT"
fi

# コメント行に絞る。行頭コメントだけでなく **行末のインラインコメントも拾う**
# (`x := 1 // 今回追加` という最も漏れやすい形を取りこぼさないため)
# file:line: の接頭辞があるので、行頭コメントは ':<行番号>:' の直後に来る点に注意
grep -E '(:[0-9]+:[[:space:]]*|[[:space:]])(//|#|--|/\*|\*/|<!--)' "$OUT"
```

コメント追加が 0 件ならこの面はスキップ。

### 1-2. 禁止パターンの機械検出

```bash
EPHEMERAL_RE='(as (requested|discussed|mentioned|per)|per (your|the user|review|feedback|codex|gemini)|you (asked|requested|wanted)|we (changed|added|discussed|decided|now)|this (pr|change|commit|fix|diff)|now (returns|uses|handles)|changed (to|from)|updated to|modified to|switched to|replaced with|renamed to|previously|used to|no longer|todo\(claude\)|対応(しました|した)?|反映|指摘|今回|先ほど|さっき|一旦|とりあえず|修正しました|変更しました|追加しました|レビュー(で|の指摘)|要望|依頼)'

grep -iE "$EPHEMERAL_RE" <収集したコメント行>
```

**機械検出はスクリーニングに過ぎない。** 正規表現に掛からなかったコメントにも
policy の Stranger Test を適用し、**追加コメントは必ず全件を目視分類**する。

### 1-3. 分類

追加コメント **1 行ずつ** に 4 択を割り当てる（判定基準は policy の決定木）。

| 判定 | 行動 |
|------|------|
| `KEEP` | そのまま |
| `REWRITE` | 文脈フリーに書き換える（policy の書き換えレシピ） |
| `MOVE` | **コードから削除** + prr 下書きへ移送 |
| `DELETE` | 削除 |

### 1-4. 適用

- `REWRITE` / `MOVE` / `DELETE` は **この skill が実際にファイルを編集して直す**。報告だけで終わらせない
- 迷った行は `MOVE` に倒す（コードに残す方が不可逆 — 誰も後から消さない）
- 過剰コメント率も見る:

```bash
for f in $(git diff --name-only "$BASE"..HEAD --diff-filter=ACMR; git diff --name-only HEAD --diff-filter=ACMR); do
  add=$(git diff HEAD -- "$f" | grep -cE '^\+')
  cmt=$(git diff HEAD -- "$f" | grep -E '^\+' | grep -cE '(//|#|--|/\*|\*)')
  [ "$add" -gt 0 ] && [ $(( cmt * 100 / add )) -ge 40 ] && echo "⚠️  $f: コメント率 $(( cmt * 100 / add ))%"
done
```

40% 超は「コードの読み上げ」が混ざっているサイン。ハード失敗ではなく確認の合図。

## S2: commit message 監査

### 草案の受け取り（I/F）

`/commit` `/pr` は message を **確定する前に草案をファイルへ書き**、この skill を呼ぶ。

```bash
mkdir -p .claude/pr-review
DRAFT_MSG=.claude/pr-review/commit-msg-draft.txt   # 1 commit につき 1 回
```

| 状況 | 監査対象 |
|------|---------|
| `$DRAFT_MSG` が存在する | その草案（commit 前）— **BLOCKING** |
| 存在しない & `--trigger=commit` | 草案が渡されていない。**未実施として報告**し、呼び出し側に草案の書き出しを促す |
| `--trigger=pr` / `push` / `manual` | `BASE..HEAD` の既存 commit — 警告のみ |

### これから作る message（`--trigger=commit`）— BLOCKING

- 内容の無い subject を拒否する: `fix: レビュー対応` / `chore: 指摘反映` / `feat: ご要望の実装`
  → **何をしたかで書き直す**: `fix: handle null from listAll()`
- body に `EPHEMERAL_RE`（S1 と同じ）が当たるものを拒否
- **直した草案を `$DRAFT_MSG` に書き戻す**。呼び出し側はそのファイルで commit する:

```bash
git commit -F .claude/pr-review/commit-msg-draft.txt
rm -f .claude/pr-review/commit-msg-draft.txt
```

### 既存 commit（`BASE..HEAD`）— 警告のみ

```bash
git log --format='%H%n%s%n%b%n---' "$BASE"..HEAD
```

- 検出したら内容ベースの書き換え案を提示する
- 書き換えは `git rebase -i` / `--amend` と force push を伴うため **自動実行しない**。提案のみ

## S3 / S4: PR description と title の監査

### 3-1. 入力の受け取り（下書きの I/F）

**投稿してから直すのではなく、投稿前に止める。** 呼び出し側は下書きをファイルで渡す。

```bash
mkdir -p .claude/pr-review
# 呼び出し側 (/pr) が投稿予定の本文・タイトルをここに書いてから skill を呼ぶ
DRAFT_BODY=.claude/pr-review/pr-body-draft.md
DRAFT_TITLE=.claude/pr-review/pr-title-draft.txt
```

| 状況 | 監査対象 |
|------|---------|
| `$DRAFT_BODY` が存在する | その下書き（投稿前） |
| 存在せず PR がある | `gh pr view --json title,body` の中身 |
| 存在せず PR も無い | S3/S4 スキップ |
| `gh` が確認不能 | **未実施として報告**（✅ にしない） |

下書きファイルは監査・投稿後に削除する（`.claude/pr-review/` は git 管理外）。

### 3-2. チェック

判定項目は policy の「PR description の規約」に従う。ここでは再定義しない。
S4（title）も同様: `fix: address review feedback` のような**会話参照 title を拒否**し、
内容ベースの title に直す。

### 3-3. 適用

- 違反があれば **修正版を生成して提示** → ユーザー確認の上で反映
  （create 前なら下書きを書き換える。既存 PR なら `gh pr edit --title/--body`）
- 自動投稿・自動編集はしない
- プロジェクトの PR テンプレートがある場合は **節構成を維持したまま** 中身だけ直す

## Output: prr 移送下書き

`MOVE` 判定になった説明と、description から外したレビュー向け文脈は捨てずに移送する。

保存先（`pr-comprehend` と同じく worktree 内 + git 管理外）:

```bash
GIT_DIR=$(git rev-parse --git-dir) || exit 1
EXCLUDE_FILE="$GIT_DIR/info/exclude"
mkdir -p "$(dirname "$EXCLUDE_FILE")" && touch "$EXCLUDE_FILE"
grep -qxF '.claude/pr-review/' "$EXCLUDE_FILE" || echo '.claude/pr-review/' >> "$EXCLUDE_FILE"
mkdir -p .claude/pr-review
```

`.claude/pr-review/prr-draft-<branch>.md`:

```markdown
# PR コメント下書き (prr)

> `prr get <owner>/<repo>/<PR番号>` で開いた .prr ファイルの該当行の下に貼り付ける。

## src/auth/token.go:42
リトライ回数を 3 にしたのは計測値ベース。1 回だと SLA を割り、5 回で上流のレート制限に当たった。
次の PR で設定値に外出しする。

## src/auth/token.go:88
旧経路を意図的に残している。#123 の移行完了まで削除不可。
```

**投稿は行わない。** 下書きのパスとコピペ手順を提示するところまで。

## 報告フォーマット

```markdown
## Context Hygiene 結果

### S1 コードコメント (BLOCKING)
| 判定 | 件数 |
|------|------|
| KEEP | 3 |
| REWRITE | 2 |
| MOVE | 1 |
| DELETE | 4 |

修正済み:
- `src/a.go:12` DELETE 「// 今回追加」
- `src/a.go:30` REWRITE 「// ご指摘どおり 30s」→「// 30s: 上流 API のタイムアウト 25s + マージン」

### S2 commit message
- 草案「fix: レビュー対応」→「fix: handle null from listAll()」に修正して commit
- 既存 `abc1234` 「chore: 指摘反映」→ 提案のみ（履歴書き換えは未実施）

### S3/S4 PR description / title
- ❌ title 「fix: address review feedback」→ 「fix: handle expired refresh token」
- ❌ 「ご要望どおり実装しました」→ 背景を PR 単体で読める内容に差し替え（案は下記）
- ⚠️ 検証方法が未記載 → 「未検証（手元で実行できず）」と明記する案

### prr 移送下書き
- `.claude/pr-review/prr-draft-<branch>.md` に 2 件
```

`gh` 確認不能で S3/S4 を実施できなかった場合は、✅ ではなく **「未実施」と明記**する。

## 通過条件

- S1: `REWRITE` / `MOVE` / `DELETE` が **すべて適用済み**（残存ゼロ）
- S2: `--trigger=commit` の草案が内容ベースになっている（既存履歴は対象外）
- S3/S4: policy のチェック項目がすべて ✅、またはユーザーが明示的に「このまま出す」と判断
- 実施できなかった面がある場合は、通過ではなく **未実施として報告**する

## Anti-patterns

| NG | 理由 |
|----|------|
| 検出して報告するだけで直さない | 結局そのまま出る |
| 正規表現に当たった行だけ見る | 「〜のため一旦」等は網に掛からない。追加分は全件 Stranger Test |
| commit 済み diff だけ見る | `/commit` 時点では未コミット。gate として機能しない |
| 迷ったコメントをコードに残す | コードに残す方が不可逆 |
| PR コメントを自動投稿する | レビューはユーザーが主導する |
| `gh` 失敗を「問題なし」として通す | 監査していないのに ✅ が出る |
| 判定基準をこの SKILL.md 内で再定義する | policy との二重管理。基準は `.claude/rules/comment-policy.md` のみ |
