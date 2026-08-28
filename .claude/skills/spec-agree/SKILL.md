---
name: spec-agree
description: |
  チケット / ざっくりした依頼を、実装可能な「合意済み仕様」に変換する skill。
  開発案を複数提示 → ユーザーと調整 → 受け入れ基準まで落として .claude/specs/ に記録する（task-id で照合、digest で改変検出）。
  このファイルが無いと実装フェーズに入れない (Gate A / .claude/rules/flow-gates.md)。
  「これ作って」「このチケットやって」と依頼された最初に使う。
metadata:
  auto-trigger: false
  invoked-by: [dev-flow, user]
  gate: A
  policy: .claude/rules/flow-gates.md
---

# Spec Agree

## Purpose

**AI 開発で一番高くつく失敗は、間違ったものを正しく作ること。**

依頼はたいてい曖昧で、AI は曖昧なまま「それっぽく」実装できてしまう。
この skill は実装前に立ち止まり、**何を作るか / 何を作らないか / 完成の定義** をユーザーと合意する。

出力は `.claude/specs/<slug>.md`（形式・成立条件・照合キーは `.claude/rules/flow-gates.md` の Gate A が定義）。
このファイルが後工程の入力になる:

- `test-generator` は受け入れ基準からテストを書く
- `user-scenario` は仕様との差分を見る
- `/pr` の description は背景・スコープをここから引く

## Process

```
Step 1: 依頼の分解      → 何を求められているか / 前提 / 制約
Step 2: 現状調査        → 既存実装・関連コードを読む (推測で設計しない)
Step 3: 開発案を 2-3 案 → trade-off つきで提示 (codex-design に相談可)
Step 4: 調整            → ユーザーの選択・修正を反映
Step 5: 受け入れ基準化  → 観測可能な形に落とす
Step 6: 合意記録        → ユーザーの明示 OK を得てファイルに書く
```

## Step 1: 依頼の分解

依頼文をそのまま実装しない。まず 3 つに割る。

| 区分 | 内容 |
|------|------|
| **明示されている要求** | 依頼文に書いてある |
| **暗黙の期待** | 書いていないが当然そう思っている（既存の挙動を壊さない 等） |
| **不明** | 読み取れない。Step 4 で必ず聞く |

**不明を推測で埋めない。** 埋めた瞬間に「間違ったものを正しく作る」が始まる。

## Step 2: 現状調査

- 関連する既存実装を読む（`serena` の `find_symbol` / grep）
- 似た機能が既にあるなら、それに寄せる（`.claude/rules/coding-principles.md`）
- 外部ライブラリを使うなら `latest-docs` で現行 API を確認する
- 調査で分かった **制約** を仕様に持ち込む（「この経路は同期でしか呼べない」等）

## Step 3: 開発案の提示

**必ず 2 案以上出す。** 1 案しか無いときは「なぜ他が無いのか」を書く。

```markdown
### 案A: <名前>
- 概要:
- メリット:
- デメリット:
- 影響範囲:
- 実装量の目安:

### 案B: <名前>
...

**推奨: 案X** — 理由: <この文脈で何を優先したか>
```

設計判断が重い場合（新パターン導入 / 3 案以上 / 性能要件）は `codex-design` に相談し、
その結果を要約して案に反映する（`.claude/rules/codex-delegation.md`）。

## Step 4: 調整

- Step 1 の **不明** を `AskUserQuestion` で潰す（選択肢には推奨を先頭に置く）
- ユーザーの修正を仕様に反映し、影響する箇所を明示する
- 「今回やらないこと」をここで確定させる — **非スコープが空の仕様は合意になっていない**

## Step 5: 受け入れ基準化

各要求を **観測可能** な形に落とす。

| NG | OK |
|----|-----|
| 正しく動く | 終了コード 0 かつ `~/.claude/skills` が symlink になっている |
| 速い | 100 件の入力で 1 秒以内 |
| エラーを処理する | 上流が 500 を返したとき 3 回リトライし、失敗したら exit 1 と stderr にメッセージ |

異常系・エッジケースの AC も入れる（詳細なシナリオ化が要るなら `user-scenario` に委譲）。

## Step 6: 合意記録

**ユーザーが明示的に OK と言うまで書かない。** 勝手に `agreed-by: user` を書くのは違反。

ファイル形式・frontmatter・成立条件は `.claude/rules/flow-gates.md` の Gate A が定義する。
この skill の責務は「合意を取り、その版を改変不能な形で刻む」こと。

```bash
GIT_DIR=$(git rev-parse --git-dir) || exit 1
EXCLUDE_FILE="$GIT_DIR/info/exclude"
mkdir -p "$(dirname "$EXCLUDE_FILE")" && touch "$EXCLUDE_FILE"
for p in '.claude/pr-review/' '.claude/specs/'; do
  grep -qxF "$p" "$EXCLUDE_FILE" || echo "$p" >> "$EXCLUDE_FILE"
done
mkdir -p .claude/specs

BRANCH=$(git branch --show-current)
[ -n "$BRANCH" ] || { echo "detached HEAD: ブランチを作ってから再実行"; exit 1; }
SLUG=$(printf '%s' "$BRANCH" | tr '/' '-')
SPEC=".claude/specs/${SLUG}.md"
```

`task-id` を決めたら、**書く前に重複を検査する**（一意性は Gate A の前提）:

```bash
grep -h '^task-id:' .claude/specs/*.md 2>/dev/null | sort | uniq -d   # 出力があれば BLOCKING
grep -l "^task-id: ${TASK_ID}$" .claude/specs/*.md 2>/dev/null        # 既存があれば別 ID にする
```

手順:

1. 本文（背景 / スコープ / 非スコープ / 受け入れ基準 / 設計判断 / 未決事項）を書く
2. **全文をユーザーに提示**し、「この内容で実装に入る」ことを確認する
3. OK が出たら frontmatter を埋める:
   - `task-id`: 安定 ID。**以後ブランチ名が変わっても変えない**
   - `branch`: 現在のブランチ、`status: active`
   - `base-head`: `git rev-parse HEAD`
   - `agreed-by: user` / `agreed-at`
   - `agreed-digest`: 本文のハッシュ（下記）

```bash
spec_digest() {  # $1: spec ファイル。frontmatter を除いた本文のみを対象にする
  awk 'BEGIN{c=0} /^---$/{c++; next} c>=2' "$1" | shasum -a 256 | cut -c1-12
}
spec_digest "$SPEC"
```

`agreed-digest` があることで、**承認後に本文を書き換えたら Gate A が落ちる**。
これは事故防止であって不便ではない — 仕様が変わったなら再合意すべきだから。

## 仕様変更が起きたとき

実装中に仕様がズレるのは正常。**黙って実装を変えない。**

1. 何がズレたか、なぜかを提示する
2. 本文を更新する（この時点で digest が合わなくなり Gate A は落ちる）
3. ユーザーの再 OK を取り、`agreed-at` と `agreed-digest` を更新する
4. 影響する受け入れ基準を書き換える（テストも当然変わる）

古い仕様を捨てるのではなく置き換える場合は、旧 spec を `status: superseded` にする。

## Anti-patterns

| NG | 理由 |
|----|------|
| 不明点を推測で埋めて実装に進む | 間違ったものを正しく作る |
| 案を 1 つしか出さない | 選んだ理由が測れない |
| 非スコープを書かない | 際限なく膨らむ / 「これも入ってると思った」が起きる |
| 受け入れ基準が「正しく動く」 | 検証できない = 完成判定ができない |
| ユーザーの OK 前に `agreed-by: user` を書く | ゲートの偽装 |
| 本文を直した後に `agreed-digest` だけ再計算して通す | 再合意なしの改変。ゲートの偽装 |
| 実装中の仕様変更を口頭で済ませる | 後工程（テスト・PR description）が古い仕様のまま |
