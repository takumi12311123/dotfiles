---
name: pr-comprehend
description: |
  PR の仕様・影響範囲・AI特有リスクを網羅的に把握するための digest 生成 skill。
  自分/AIが書いたPR、他人のPR、ローカルブランチのマージ前振り返り の 3 モード。
  レポートは worktree 内 (.claude/pr-review/) に保存され、.git/info/exclude で自動的にコミット対象外。
  quality-gate から commit / PR 作成前に自動発火する。
metadata:
  auto-trigger: false
  invoked-by: [quality-gate, user]
---

# PR Comprehend

## Purpose

**「AI が書いた PR を、人間はどこまで読むべきか」問題への回答。**

品質チェック (codex-review / gemini-review) は「何を直すべきか」に答えるが、
それだけでは「この PR が何をやろうとしているのか」「どこに影響するのか」
「AI が変な方向に走っていないか」は把握できない。

この skill は **人間のレビュー負荷を下げる仕様把握レポート** を生成する。
生の diff を人間が全部読まなくても、レポートを読めば全体像が掴める状態を目指す。

## 3 Modes

| Mode | 呼び出し | 対象 |
|------|---------|------|
| `author` | quality-gate から自動 | ローカルブランチの staged/unstaged 変更 |
| `reviewer` | `pr-comprehend <PR番号>` | GitHub 上の他人 (or AI) の PR |
| `self-recap` | `pr-comprehend` (引数なし) | ローカルブランチのマージ前振り返り |

Mode の自動判定:
- 引数に PR 番号 → `reviewer`
- `quality-gate` から `--mode=author` 付きで呼ばれた → `author`
- それ以外 → `self-recap`

## Output Location

**worktree 内 + コミット対象外** が要件。

```
.claude/pr-review/
├── PR<番号>-<slug>.md        # reviewer mode
├── local-<branch>-<hash>.md  # author / self-recap mode
└── .gitkeep
```

### コミット対象外の担保

skill 実行時に **`.git/info/exclude` に `.claude/pr-review/` を自動追加** する。
`.git/info/exclude` は per-clone のローカル設定なので、共有 .gitignore を汚さない。

```bash
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || { echo "not in git repo"; exit 1; }
EXCLUDE_FILE="$GIT_DIR/info/exclude"
mkdir -p "$(dirname "$EXCLUDE_FILE")"
touch "$EXCLUDE_FILE"
if ! grep -qxF '.claude/pr-review/' "$EXCLUDE_FILE"; then
  echo '.claude/pr-review/' >> "$EXCLUDE_FILE"
fi
mkdir -p .claude/pr-review
```

**注意**: dotfiles リポジトリ自体は `.gitignore` にも入れる (ソース管理側の意図明示)。

## Execution Flow

```
┌────────────────────────────────────────────┐
│  Step 0: Mode detection & prep             │
│    → Detect mode (author/reviewer/self)    │
│    → Ensure .git/info/exclude entry        │
│    → Compute diff scope                    │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│  Step 1: Diff acquisition                  │
│    author/self-recap: git diff BASE..HEAD  │
│    reviewer:          gh pr diff <num>     │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│  Step 2: Weight decision (light vs full)   │
│    trigger=commit  → light digest          │
│    trigger=PR      → full digest           │
│    trigger=manual  → full digest           │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│  Step 3: Delegate summarization to Gemini  │
│    Large diff (>500 lines) → Gemini        │
│    Small diff              → Claude inline │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│  Step 4: AI-specific risk scan via Codex   │
│    (full mode only)                        │
│    → hallucination / self-patch /          │
│      over-abstraction / spec deviation     │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│  Step 5: Synthesize & save report          │
│    → Merge Gemini summary + Codex risks    │
│    → Write .claude/pr-review/<name>.md     │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│  Step 6: Present to user (staged dialog)   │
│    → 全体像を先に提示                        │
│    → AskUserQuestion で深掘りセクション選択  │
│    → (reviewer mode) --comment で PR 投稿   │
└────────────────────────────────────────────┘
```

## Step 1: Diff Acquisition

### author / self-recap mode

```bash
BASE=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main)
# 変更ファイル一覧 + 統計
git diff --stat "$BASE"..HEAD
# 差分本体 (context 保護のため full diff は Gemini に投げる用)
git diff "$BASE"..HEAD > /tmp/pr-comprehend-diff.$$.patch
# ブランチ名 (ファイル名 slug 用)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
HEAD_HASH=$(git rev-parse --short HEAD)
```

### reviewer mode

```bash
PR_NUM=$1
gh pr view "$PR_NUM" --json title,body,author,baseRefName,headRefName,files > /tmp/pr-comprehend-meta.$$.json
gh pr diff "$PR_NUM" > /tmp/pr-comprehend-diff.$$.patch
```

## Step 2: Weight Decision

呼び出し元 (`--trigger` フラグ) で digest の重さを決める:

| `--trigger` | 挙動 | Codex/Gemini 呼び出し |
|---|---|---|
| `commit` | **light digest** — Claude 内部で diff 要約のみ | なし |
| `pr` | **full digest** — Gemini 要約 + Codex リスク検出 | あり |
| `manual` (default) | **full digest** | あり |

理由: commit ごとに Codex/Gemini を叩くとトークン消費が大きすぎる。
commit 時は「今何が変わったか」の軽い記録として保存し、PR 作成時にフル分析する。

### Light digest の内容

- Section 1 (仕様サマリ) と Section 2 (影響範囲) のみ
- Claude Code が git diff を直接読んで要約
- Section 3-6 (リスク / AI特有 / チェックリスト / オープン質問) はスキップ

### Full digest の内容

- 全 6 セクション
- Gemini に summarization を委譲、Codex に AI-specific risk 検出を委譲

## Step 3: Delegate Summarization to Gemini

**Context 保護のため、生 diff は Claude が読まない** (`.claude/rules/gemini-delegation.md` 準拠)。

diff サイズが 500 行超なら Gemini に投げる:

```bash
DIFF_LINES=$(wc -l < /tmp/pr-comprehend-diff.$$.patch)
if [ "$DIFF_LINES" -gt 500 ]; then
  gemini -p "$(cat prompts/gemini-summary.md) $(cat /tmp/pr-comprehend-diff.$$.patch)" \
    > /tmp/pr-comprehend-gemini.$$.md
else
  # 小さければ Claude が直接要約
  cat /tmp/pr-comprehend-diff.$$.patch  # → 内部で要約
fi
```

Gemini prompt (`prompts/gemini-summary.md`):

```
以下の git diff を読んで、日本語で以下を出力してください:

## 1. 仕様サマリ (What changed)
- API 変更 (追加/変更/削除)
- UI 変更
- DB スキーマ変更
- 環境変数/設定変更
- CLI 変更
- Before → After の振る舞い差分

## 2. 影響範囲マップ
- 変更ファイルの呼び出し元 (推測でよい)
- 破壊的変更の有無
- データマイグレーションの必要性

出力は事実ベース。推測は「(推測)」と明記。
```

## Step 4: AI-Specific Risk Scan via Codex

Full digest 時のみ。Codex に **AI が書いた PR に特有のワナ** を検出させる。

```bash
ROOT=$(git rev-parse --show-toplevel)
if [ -f "$ROOT/.claude/skills/pr-comprehend/digest-schema.json" ]; then
  SCHEMA_PATH="$ROOT/.claude/skills/pr-comprehend/digest-schema.json"
elif [ -f "$HOME/.claude/skills/pr-comprehend/digest-schema.json" ]; then
  SCHEMA_PATH="$HOME/.claude/skills/pr-comprehend/digest-schema.json"
else
  echo "ERROR: digest-schema.json not found" >&2
  exit 1
fi

DIGEST_OUT=$(mktemp "${TMPDIR:-/tmp}/pr-comprehend-digest.XXXXXX")

# Portable timeout (codex-review と同じパターン)
if command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(gtimeout 900)
elif command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout 900)
else
  TIMEOUT_CMD=()
fi

"${TIMEOUT_CMD[@]}" codex exec --model gpt-5.6-terra --sandbox read-only --ephemeral \
  --output-schema "$SCHEMA_PATH" \
  -o "$DIGEST_OUT" \
  "$(cat prompts/codex-ai-risk.md)
---DIFF---
$(cat /tmp/pr-comprehend-diff.$$.patch)" < /dev/null

CODEX_EXIT=$?
if [ "$CODEX_EXIT" -ne 0 ] || [ ! -s "$DIGEST_OUT" ]; then
  echo "WARN: codex ai-risk scan failed (exit=$CODEX_EXIT) — proceeding without" >&2
  DIGEST_OUT=""
fi
```

Codex prompt (`prompts/codex-ai-risk.md`) は AI 特有パターンに特化:
- **Hallucination**: 存在しない関数/API/ライブラリの呼び出し
- **Self-patch**: 自分が導入した throw を自分で catch している (quality-gate Step 2.5 と同型)
- **Over-abstraction**: 単一呼び出しから helper 抽出、premature DRY
- **Spec deviation**: PR タイトル/description に書かれた範囲外の変更
- **Test water-filling**: assert のない test、mock だけで自己完結する test
- **Dead code**: 削除すべきコメントアウトや unused import の追加

出力は JSON schema (`digest-schema.json`) に従う。

## Step 5: Synthesize & Save Report

Gemini の仕様サマリ + Codex の AI-risk 結果を統合し、レポートを保存:

```bash
# ファイル名決定
case "$MODE" in
  reviewer)
    SLUG=$(gh pr view "$PR_NUM" --json headRefName -q .headRefName | tr '/' '-')
    REPORT="$ROOT/.claude/pr-review/PR${PR_NUM}-${SLUG}.md"
    ;;
  author|self-recap)
    REPORT="$ROOT/.claude/pr-review/local-${BRANCH//\//-}-${HEAD_HASH}.md"
    ;;
esac
```

### Report Template (6 sections)

```markdown
# PR<番号> or local-<branch>: <title>

**生成日時**: <ISO8601>
**Mode**: <author|reviewer|self-recap>
**Weight**: <light|full>
**Base**: <base-ref>  **Head**: <head-ref>
**変更**: <N files, +X -Y lines>

---

## 1. 仕様サマリ (What changed)

<Gemini or Claude が生成した振る舞いレベルの要約>

### API / UI / DB / 設定 の変更
- [API] `POST /foo` を追加 (認証必須)
- [UI] `<UserCard>` に status バッジを追加
- [DB] `users.last_seen_at` カラムを追加 (nullable)
- ...

### Before → After
- Before: ユーザー削除時は soft-delete のみ
- After: 30日経過後に hard-delete する batch を追加

---

## 2. 影響範囲マップ (Blast radius)

### 呼び出し関係
- `handleDelete()` の変更 ← `UserSettings.tsx`, `AdminPanel.tsx` から呼ばれる
- ...

### 破壊的変更
- [ ] API シェイプ変更あり: `/api/users` レスポンスに `deleted_at` 追加 (既存クライアント互換)
- [ ] DB マイグレーション必要: `ALTER TABLE users ADD COLUMN last_seen_at`
- [ ] 環境変数追加: `USER_HARD_DELETE_ENABLED`

### データマイグレーション
- 必要 / 不要
- 必要な場合: ロールバック手順

---

## 3. リスク評価

| 観点 | Level | 内容 |
|---|---|---|
| セキュリティ | Low/Med/High | ... |
| 性能 | Low/Med/High | ... |
| データ整合性 | Low/Med/High | ... |
| 可観測性 | Low/Med/High | ... |

---

## 4. AI 特有リスク (最重要)

<Codex ai-risk scan の結果>

### Hallucination 疑い
- `src/foo.ts:42` — 呼んでいる `parseFoo()` が定義されていない可能性

### Self-patch (自己パッチ)
- `src/bar.ts:88` — 同一 diff で `throw new BarError()` を追加し、
  隣接ブロックで catch している

### Over-abstraction
- `src/util/helper.ts` — 1 箇所からしか呼ばれないヘルパー関数

### Spec deviation (指示逸脱)
- PR title は "Add user avatar" だが `src/auth/*` にも変更あり

### Test 水増し
- `test/foo.test.ts:15` — assert なしの test ケース

### Dead code
- コメントアウトされた `// old logic` が 3 箇所残存

---

## 5. レビュー観点チェックリスト (人間が確認)

- [ ] 正当性: 主要 happy path が動くか
- [ ] 正当性: エッジケース (null/empty/最大値) の考慮
- [ ] セキュリティ: 認証/認可の抜け
- [ ] セキュリティ: 入力バリデーション
- [ ] 性能: N+1、無限ループ、無駄なフェッチ
- [ ] エラーハンドリング: 例外の握り潰し
- [ ] テスト網羅性: happy / error / edge

---

## 6. オープン質問 (人間が判断)

- Q1: `USER_HARD_DELETE_ENABLED` のデフォルト値は false でよいか?
- Q2: 30日という閾値の根拠は? 設定可能にすべきか?
- ...
```

Light digest の場合は Section 3-6 を **「full digest 時に生成」** のプレースホルダにする。

## Step 6: Present to User (Staged Dialog)

レポート保存後、ユーザーに提示:

```markdown
📄 PR digest 生成完了: .claude/pr-review/<filename>.md

## 全体像
- **変更ファイル**: N
- **主な変更**: <1行サマリ>
- **破壊的変更**: あり/なし
- **AI 特有リスク**: <High/Med/Low> — <上位1件>

どこを詳しく見ますか? (数字で選択)
1. 仕様サマリ
2. 影響範囲
3. リスク評価
4. AI 特有リスク
5. レビュー観点チェックリスト
6. オープン質問
0. スキップ (レポートは保存済み)
```

`AskUserQuestion` を使って対話的に深掘り。ユーザーがスキップすればレポートだけ残る。

### `--comment` オプション (reviewer mode のみ)

`pr-comprehend <PR番号> --comment` は **Section 1 (仕様サマリ) のみ** を
`gh pr comment <PR番号> --body-file <抜粋>` で投稿する。

**Section 4 (AI 特有リスク) を含む「指摘」は投稿しない。**
未裁定のモデル指摘を PR に出すのは、レビューフローの裁定フェーズ (`model-consensus`) を
迂回することになるため（`.claude/rules/flow-gates.md` の Phase 5-6）。
リスクや疑わしい点を PR に出したい場合は `/review-flow` を通し、
`model-consensus` の裁定を経てから `prr` で出す。

**投稿前に必ずユーザー確認**。自動投稿はしない (blast radius 大)。

## Integration with quality-gate

`quality-gate` の Step 4.7 で自動発火。詳細は `quality-gate/SKILL.md` を参照。

- Trigger `commit`: light digest (Claude 内部要約のみ)
- Trigger `pr`: full digest (Gemini + Codex 使用)

## Error Handling

| エラー | 対応 |
|---|---|
| `gh` CLI 未インストール (reviewer mode) | エラー表示、reviewer mode は使用不可 |
| Gemini 未インストール | Claude で summarization にフォールバック |
| Codex 失敗 | Section 4 (AI特有リスク) を「スキャン失敗」として記録し継続 |
| diff が空 | 何もせず終了 |

## Important

- **Context 保護**: 大 diff の生読みは Claude ではなく Gemini に委譲する
- **コミット防止**: 初回実行時に `.git/info/exclude` へ登録
- **light/full の使い分け**: commit ごとに full digest を回さない (トークン浪費)
- **--comment は必ず確認**: 自動投稿禁止
- **日本語出力**: 全 user-facing text は日本語
