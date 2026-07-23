# Reviewer Mode

このモードは **他人 (人間 or AI) が出した GitHub PR を人間として把握する** ためのもの。

## 前提

- GitHub 上の PR を対象とする
- `pr-comprehend <PR番号>` で呼び出す
- `gh` CLI が必要 (未インストール時はエラー)

## Data acquisition

```bash
PR_NUM=$1
gh pr view "$PR_NUM" --json title,body,author,baseRefName,headRefName,files,additions,deletions,labels,url \
  > /tmp/pr-comprehend-meta.$$.json
gh pr diff "$PR_NUM" > /tmp/pr-comprehend-diff.$$.patch
```

Author が bot / AI アカウントかを heuristic 判定:
- `author.login` が `github-actions[bot]`, `dependabot[bot]`, `claude-code[bot]` 等
- PR body に `🤖 Generated with [Claude Code]` などのフッタあり
- label に `ai-generated` 等がある

判定結果を Codex prompt に注入する ("author is likely AI" hint)。

## Extra prompts to inject

Reviewer mode では、Codex ai-risk scan に以下を追加で問う:

```
## Reviewer-mode extra checks

このレビュアーはこの PR のコンテキストを持たない。以下を明示的に説明せよ:

1. **PR タイトル/description との整合性**:
   - PR title: <inject>
   - PR body: <inject (最初の 500 文字)>
   - diff がこの description の範囲と一致しているか?
   - description に無い変更があれば `spec_deviation` として ai_risks[] に記録

2. **暗黙の前提**:
   - この PR は何かを前提としているか (feature flag が有効、DB migration が先に適用済み等)
   - 前提が満たされない環境で merge した場合の挙動は?
   - `open_questions[]` にレビュアーが確認すべき前提を列挙

3. **レビュアーが試すべき動作確認**:
   - この diff を確認するために手元で何を実行すればよいか
   - `review_checklist[]` の `axis=ops` に具体的な検証手順を書く

## Output guidance

- Author が AI と判定された場合、ai_risks[] のスキャンをより厳しく
- Author が人間の場合、hallucination / self_patch のスキャンは軽めでよい
  (人間はハルシネートしにくいが、他パターンは同様に警戒)
```

## Report file naming

```
.claude/pr-review/PR<番号>-<head-branch-slug>.md
```

同じ PR で複数回実行するとファイルは上書き。

## Present to user

```
📄 PR #<番号> digest 生成完了
   .claude/pr-review/PR<番号>-<slug>.md
   <PR URL>

## 全体像
- Title: <title>
- Author: <login> (<AI判定結果>)
- 変更: <files> files, +<additions> -<deletions>
- 主な変更: <one_liner>
- 破壊的変更: <あり/なし>
- AI 特有リスク: <レベル> — <上位1件>

どこを詳しく見ますか?
1. 仕様サマリ
2. 影響範囲
3. リスク評価
4. AI 特有リスク
5. レビュー観点チェックリスト (手元で試す手順を含む)
6. オープン質問
0. スキップ
```

## `--comment` option

`pr-comprehend <PR番号> --comment` の場合、以下の内容で PR にコメント投稿:

**投稿前に必ずユーザーに投稿内容を提示し、明示的な承認を得る**。自動投稿は絶対にしない。

投稿本文テンプレート:

```markdown
## 🤖 PR Digest (by pr-comprehend)

### 仕様サマリ
<summary.one_liner>

<summary.changes を category ごとに箇条書き>

### 影響範囲
- 破壊的変更: <あり/なし>
- マイグレーション必要: <yes/no>

### レビュアー向けチェック
<review_checklist の主要 5-7 項目>

### 気になる点 (要確認)
<ai_risks の blocking 全件 + advisory 上位 3件>

### 質問
<open_questions>

---
_この digest はレビュー支援用の自動生成です。実際の判断は人間のレビュアーがしてください。_
```

投稿コマンド:
```bash
BODY_FILE=$(mktemp)
# ... build body ...
gh pr comment "$PR_NUM" --body-file "$BODY_FILE"
rm -f "$BODY_FILE"
```
