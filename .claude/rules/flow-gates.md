# Flow Gates

開発とレビューは **フェーズ順に進み、ゲートで必ず止まる**。
ゲートの成立条件・成果物形式・検証手順を **この文書だけ** が定義する。
skill / command はここを参照し、条件を再定義しない。

## 2 つのフロー

```
開発フロー (/dev-flow)
1. 依頼受領
2. 開発案 → 仕様調整                    ── Gate A: 仕様合意
3. TDD 実装 + quality-gate
4. 仕様・シナリオ・内部実装の理解         ── Gate B: 理解 OK
5. /pr
6. /prr でレビュワー向け補足

レビューフロー (/review-flow)
1. PR 受領
2. 把握 (pr-comprehend)
3. 機械チェック                          ── Gate C: 機械チェック完了
4. 読解支援                              ── Gate B': 理解 OK
5. 指摘の裁定 (model-consensus)          ── Gate D: 全指摘に行き先が付いた
6. 終端分岐: approve / comment / change request
```

**approve は裁定の後。** 未裁定の指摘を抱えたまま approve してはいけない。

## 共通: 成果物のキーと再入性

ゲート成果物は `.claude/specs/` と `.claude/pr-review/` に置く（worktree 内・git 管理外）。

```bash
GIT_DIR=$(git rev-parse --git-dir) || exit 1
EXCLUDE_FILE="$GIT_DIR/info/exclude"
mkdir -p "$(dirname "$EXCLUDE_FILE")" && touch "$EXCLUDE_FILE"
for p in '.claude/pr-review/' '.claude/specs/'; do
  grep -qxF "$p" "$EXCLUDE_FILE" || echo "$p" >> "$EXCLUDE_FILE"
done
mkdir -p .claude/pr-review .claude/specs
```

### ファイル名とキー

ファイル名は人間が読むためのもので、**照合には使わない**。照合は本文の frontmatter で行う。

| 種別 | ファイル名 | 照合キー |
|------|-----------|---------|
| 仕様 | `.claude/specs/<slug>.md` | 本文の `task-id` |
| 理解確認（開発） | `.claude/pr-review/understanding-<slug>.md` | `task-id` |
| 理解確認（レビュー） | `.claude/pr-review/understanding-pr<番号>.md` | `pr-number` |

`<slug>` は初回作成時のブランチ名の `/` を `-` にしたもの。
`task-id` は初回に決める安定 ID（例: `add-auth-retry`）。**以後ブランチ名が変わっても変えない。**

**`task-id` は `.claude/specs/` 全体で一意でなければならない。**

```bash
grep -h '^task-id:' .claude/specs/*.md 2>/dev/null | sort | uniq -d
```

出力があれば重複。**その時点で BLOCKING** — どちらかを改名する（`status: superseded` の
古い spec も含めて重複させない）。`spec-agree` は新しい spec を書く前にこの検査を行う。

### 解決手順（ブランチ改名・複数タスク・detached HEAD）

```bash
BRANCH=$(git branch --show-current)
```

1. `BRANCH` が空（detached HEAD）→ **ゲート評価不能**。ブランチを作るよう促して停止する
2. `.claude/specs/*.md` を全部読み、`status: active` のものを集める
3. `branch:` が現在のブランチと一致するものを集める
   - ちょうど 1 件 → それを使う
   - **2 件以上 → `AskUserQuestion` でどのタスクか聞く**（同一ブランチに複数タスクが同居しうる）
   - 0 件 → 手順 4 へ
4. 一致が無く、`base-head` が現在の HEAD の祖先である active spec が **1 つだけ** あるなら、
   ブランチ改名とみなし、ユーザーに確認してから `branch:` を更新する
   ```bash
   git merge-base --is-ancestor "$BASE_HEAD" HEAD && echo "ancestor: yes"
   ```
5. 候補が複数 → どのタスクか `AskUserQuestion` で聞く（**推測で選ばない**）
6. 候補ゼロ → Gate A 未成立

こうして選ばれた 1 件の `task-id` が、そのセッションの **current task** になる。
以降のゲート評価はすべてこの `task-id` を使う（ファイル名では照合しない）。

```bash
# current task の記録（解決結果のキャッシュ。信用する前に必ず再検証する）
printf '%s\n' "$TASK_ID" > .claude/pr-review/current-task
```

**キャッシュは毎回検証してから使う。** 次のいずれかに当てはまったら破棄して 1 から解決し直す:

```bash
CACHED=$(cat .claude/pr-review/current-task 2>/dev/null)
SPEC=$(grep -l "^task-id: ${CACHED}$" .claude/specs/*.md 2>/dev/null | head -1)
```

| 失効条件 | 判定 |
|---------|------|
| `current-task` が空 / ファイルが無い | 再解決 |
| その `task-id` を持つ spec が存在しない | 再解決 |
| spec の `status` が `active` でない | 再解決 |
| spec の `branch:` が現在のブランチと違う | 再解決（改名なら手順 4 の祖先チェックを経て `branch:` を更新） |
| spec の `base-head` が現在の HEAD の祖先でない | 再解決（別系統の作業に移っている） |

- 理解確認記録の照合は **本文 frontmatter の `task-id`** で行う
  （`grep -l "task-id: $TASK_ID" .claude/pr-review/understanding-*.md`）
- 同じ `task-id` の記録が複数見つかった場合は、`confirmed-head` が最新のものを使い、
  残りは古い記録として無視する（削除はしない）

完了したタスクの spec は `status: done` にする。1 ブランチに複数タスクが同居してよい。

## Gate A: 仕様合意（実装開始の条件）

**成果物**: `.claude/specs/<slug>.md`（`spec-agree` skill が書く）

```markdown
---
task-id: add-auth-retry
branch: feature/add-auth-retry
status: active            # active | done | superseded
base-head: <合意時点の HEAD SHA>
agreed-by: user           # ユーザーが明示 OK と言った場合のみ
agreed-at: <YYYY-MM-DD HH:MM>
agreed-digest: <本文の SHA-256 先頭 12 桁>
---

# <タイトル>

## 背景 / 解きたい問題
## スコープ（やること）
## 非スコープ（やらないこと）
## 受け入れ基準
- [ ] AC1: <条件> のとき <観測可能な結果>
## 設計判断
| 判断 | 採用案 | 却下案 | 理由 |
## 未決事項
| # | 論点 | 誰が決める | 期限 |
```

### 成立条件（すべて満たすこと）

1. `## 受け入れ基準` が 1 件以上あり、すべて観測可能（「正しく動く」は不可）
2. `## 非スコープ` が空でない
3. `agreed-by: user` がある
4. **`agreed-digest` が本文と一致する**（承認後の改変を検出するため）

### digest の計算と検証

frontmatter を除いた本文（`---` の 2 つ目より後）のハッシュを取る。

```bash
spec_digest() {  # $1: spec ファイル
  awk 'BEGIN{c=0} /^---$/{c++; next} c>=2' "$1" | shasum -a 256 | cut -c1-12
}
```

- `spec-agree` は承認時に `agreed-digest` を書き込む
- ゲート評価側は再計算して比較する。**不一致なら Gate A 未成立**
  → 変更点を提示し、再合意を取ってから `agreed-at` / `agreed-digest` を更新する

**BLOCKING**: Gate A 未成立で実装フェーズに入らない。
未決事項がある場合は「その項目に触れない範囲で実装する」ことを明記して進める。

## Gate B: 理解 OK（開発フロー / `/pr` の条件）

**成果物**: `.claude/pr-review/understanding-<slug>.md`

```markdown
---
task-id: add-auth-retry
kind: dev
confirmed-head: <確認時点の HEAD SHA>
base-head: <spec の base-head>
skills-used: [user-scenario, explain-impl, grill-me]
---

## 1. 問題 ✅
> **ユーザーの説明**: 上流が 5xx を返すと即失敗していて、実際には再試行すれば通る
> ケースが大半だった。原因はリトライ層が無いこと。

## 2. 解決策・設計判断・エッジケース ✅
> **ユーザーの説明**: 指数バックオフで 3 回。5 回にしなかったのは上流のレート制限に
> 当たるから。冪等でない POST は対象外にしている。

## 3. 影響範囲 ✅
> **ユーザーの説明**: 認証経路だけ。失敗時の総待ち時間が最大 7 秒延びる。

## grill-me 結果
L1 ✅ / L2 ✅ / L3 ✅ / L4 ❌→再出題後 ✅  — 弱点: 並行実行時の挙動

## 残った疑問
- なし
```

### 成立条件（すべて満たすこと）

1. 3 項目すべてに **ユーザー自身の説明が引用として入っている**
   （AI が書いた要約で埋めるのは **偽装**。ユーザーの発話から転記したものだけが有効）
2. `confirmed-head` が現在の HEAD と一致する
   - 不一致なら差分を提示: `git log --oneline <confirmed-head>..HEAD`
   - その差分についてユーザーの説明を追記して `confirmed-head` を更新すれば再成立する
3. `## 残った疑問` が「なし」、または残った疑問がユーザー自身の判断で「これは残してよい」とされている

### grill-me の要否

- 既定では実施する（`/dev-flow` Phase 4）
- **省略してよいのは**、ユーザーの説明が既に L3（設計判断）・L4（エッジケース）に
  踏み込んでいて、`grill-me` が新たに問える論点が無いと判断できるときだけ
- 省略した場合は `skills-used` に含めず、`## grill-me 結果` に「未実施（説明が L4 まで到達）」と書く

**BLOCKING**: Gate B 未成立で `/pr` を実行しない。

## Gate B': 理解 OK（レビューフロー / approve の条件）

レビュー時は **ローカル HEAD が対象 PR の head とは限らない**ので、基準を PR head に置く。

**成果物**: `.claude/pr-review/understanding-pr<番号>.md`

```markdown
---
pr-number: 123
kind: review
pr-head: <gh pr view <番号> --json headRefOid -q .headRefOid の値>
reviewed-at: <YYYY-MM-DD HH:MM>
---

## 1. この PR が解こうとしている問題 ✅
> **ユーザーの説明**: ...
## 2. 実装方針と設計判断 ✅
> **ユーザーの説明**: ...
## 3. 影響範囲・壊れうるもの ✅
> **ユーザーの説明**: ...

## 未解消の疑問
- <あれば。approve の前に解消するか、コメントで質問する>
```

### 成立条件

1. 3 項目すべてにユーザー自身の説明が入っている
2. `pr-head` が現在の PR head と一致する（**push されたら再確認**）
   ```bash
   gh pr view <番号> --json headRefOid -q .headRefOid
   ```
3. `## 未解消の疑問` が空、または「コメントで質問する」と決まっている

**BLOCKING**: Gate B' 未成立で approve しない。

## Gate C: 機械チェック完了（レビューフロー）

「モデルに読ませた」だけでは機械チェックではない。次を **実行結果として** 残す。

```bash
gh pr checks <番号>                      # CI の結果
gh pr view <番号> --json mergeable,mergeStateStatus
```

| 状況 | 扱い |
|------|------|
| CI があり全て green | ✅ |
| CI があり red | ⛔ 失敗内容を提示。approve に進まない |
| **CI が無い / 一部しか無い** | ローカルで実行する（下記「ローカル実行の内容」） |
| ローカル実行もできない（依存が無い等） | **「未実施」と明記**。✅ にしない |

### ローカル実行の内容

`gh pr checkout <番号>` した上で、**変更ファイルから遡って見つけたプロジェクトルートすべて**で
該当コマンドを実行する（`quality-gate` と似ているが、Gate C の成立条件はこの表が決める。他文書に委譲しない）。

対象ディレクトリの決め方 — monorepo / サブディレクトリ構成を取りこぼさないため:

```bash
# 変更ファイルの各ディレクトリから上へ辿り、設定ファイルを持つディレクトリを「すべて」拾う
# (ネストしたワークスペース: sub/app/package.json と ルートの Makefile は両方対象)
gh pr diff <番号> --name-only | while IFS= read -r f; do
  d=$(dirname "$f")
  while :; do
    for m in Makefile package.json go.mod Cargo.toml pyproject.toml; do
      [ -f "$d/$m" ] && { echo "$d"; break; }
    done
    [ "$d" = "." ] || [ "$d" = "/" ] && break
    d=$(dirname "$d")
  done
done | sort -u
```

| 検出ファイル | 実行する（存在するターゲット / スクリプトのみ） |
|-------------|--------------------------------|
| `Makefile` | `make lint` / `make test` / `make check` |
| `package.json` | `npm run lint` / `npm run build` / `npm test`（scripts に定義があるものだけ） |
| `go.mod` | `go vet ./...` / `go build ./...` / `go test ./...` |
| `Cargo.toml` | `cargo clippy` / `cargo build` / `cargo test` |
| `pyproject.toml` | `ruff check` / `pytest` |
| 上記なし（対象ディレクトリが 1 つも見つからない） | **「機械チェック対象なし」と明記**（✅ にはしない） |

各対象ディレクトリで、そこに存在する設定ファイルに対応するコマンドだけを実行する。
1 つの PR が複数プロジェクトに跨る場合は **すべての対象で実行**し、結果をディレクトリ別に報告する。

判定:

- 実行したものが全て成功 → ✅
- 1 つでも失敗 → ⛔（失敗内容を提示。approve に進まない）
- 実行できなかったもの（依存未インストール等）は **個別に「未実施」と列挙**する
- **他人の PR なので自動修正はしない**（format の差分を勝手に当てない）

マージ可能性も Gate C の判定に含める（`gh pr view --json mergeable,mergeStateStatus`）:

| 値 | 扱い |
|----|------|
| `mergeable: CONFLICTING` | ⛔ 競合解消が先。approve に進まない |
| `mergeStateStatus: DIRTY` / `BLOCKED` | ⛔（BLOCKED は必須チェック未達 or レビュー不足）。理由を提示 |
| `mergeStateStatus: BEHIND` | ⚠️ 記録して続行可。ベース更新後に再確認が要ることを伝える |
| `mergeable: UNKNOWN` | GitHub が計算中。数秒おいて再取得。取れなければ **未実施** と明記 |

`codex-review` / `gemini-review` の結果は Gate C ではなく **Phase 5 の裁定材料**。
モデルの指摘だけで Gate C を満たしたことにしない。

## Gate D: 裁定完了（approve / change request の条件）

`model-consensus` の出力すべてに **処理済みの行き先** が付いていること。

| 区分 | 必要な処理 |
|------|-----------|
| `AGREED` | change request か comment に載せる（載せない判断をした場合は理由を記録） |
| `ADJUDICATED: real` | 同上 |
| `ADJUDICATED: false` | 破棄。**破棄した事実をユーザーに報告**（PR には出さない） |
| `UNRESOLVED` | **ユーザーが行き先を決めるまで終端に進まない** |

`UNRESOLVED` の行き先はユーザーが次の 4 つから選ぶ:

1. **質問として出す** — PR コメントで著者に確認する（approve は保留）
2. **change request に含める** — ユーザーが「これは問題」と判断した
3. **comment に留める** — 気になるが blocking ではない
4. **破棄する** — ユーザーが「問題なし」と判断した（理由を 1 行残す）

**AI が UNRESOLVED を勝手に処理して先に進むのは違反。**
未処理の `UNRESOLVED` が 1 件でも残っていたら approve しない。

処理結果は `.claude/pr-review/prr-draft-pr<番号>.md` の末尾に記録する:

```markdown
## 裁定結果の行き先
| # | 指摘 | 区分 | 行き先 | 決めた人 |
|---|------|------|--------|---------|
| 1 | nil 参照 | AGREED | change request | model-consensus |
| 2 | エラー握り潰し | UNRESOLVED | 質問として出す | user |
```

## スキップの作法

ゲートは **ユーザーだけがスキップできる**。

- スキップの合図: ユーザーが「スキップ」「今回は要らない」と **明示的に言った** とき
- スキップしたら成果物に 1 行残す: `skipped-by: user (<理由>)`（何も残さないのは不可）
- 「軽微だから」「時間がない」を **AI が推測して** 飛ばすのは違反

## フェーズと skill の対応

| フェーズ | 使う skill / command |
|---------|---------------------|
| 開発 1-2 | `spec-agree`（内部で `codex-design` / `latest-docs`） |
| 開発 3 | `test-generator` → 実装 → `quality-gate` |
| 開発 4 | `user-scenario` → `explain-impl` →（必要なら）`grill-me` |
| 開発 5 | `/pr`（`context-hygiene` が BLOCKING） |
| 開発 6 | `prr`（下書きは `context-hygiene` が生成） |
| レビュー 2 | `pr-comprehend <PR番号>` |
| レビュー 3 | `gh pr checks` / ローカル実行 |
| レビュー 4 | `explain-impl <PR番号>`（`eli5` / `user-scenario` / `grill-me` を随時） |
| レビュー 5 | `codex-review` + `gemini-review` → `model-consensus`（Gate D） |
| レビュー 6 | `prr`（approve / comment / change request、投稿はユーザー） |
