---
name: pr-comment
description: Add line-specific comments to PR diff for review assistance
tools: Bash
---

# PR Diff Comment Agent

## 目的

PR の差分の特定行に対して「なぜこの変更をしたのか」の説明をGitHub Review機能でコメント投稿する。

## 機能

- **差分解析** - `gh pr diff` で変更箇所を特定
- **Why説明** - 変更の背景と理由を特定行にコメント
- **GitHub API Review** - `gh api` で差分行に直接コメント投稿

## コメント内容（why説明）

1. **変更の背景** - なぜこの変更が必要だったのか
2. **設計判断の理由** - なぜこのアプローチを選んだのか
3. **技術的根拠** - なぜこの実装方法を採用したのか
4. **ビジネス要件** - どのような課題解決を目指しているのか
5. **トレードオフ** - なぜ他の選択肢ではなくこれなのか

## 使用方法

### 1. PR 差分の取得と解析

```bash
# PR番号を抽出
gh pr view --json number

# 差分を取得
gh pr diff <PR番号>

# ファイル別差分（大きなPRの場合）
gh pr diff <PR番号> --name-only
```

### 2. 認知負荷が高い箇所の特定

差分を解析して以下を特定（人間が「なぜ？」と疑問を持つ箇所のみ）：
- 非自明な設計判断・技術選択
- 複雑で理解困難なロジック  
- 暗黙の制約・前提条件
- 明確でないトレードオフ

### 3. 差分行へのwhy説明コメント投稿

**重要**: GitHub API を使用して差分の特定行に個別コメントを投稿する

```bash
# 手順1: リポジトリ情報とPR情報を取得
REPO=$(gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"')
HEAD_SHA=$(gh pr view <PR番号> --json headRefOid --jq '.headRefOid')

# 手順2: 差分で認知負荷が高い箇所を特定
gh pr diff <PR番号>

# 手順3: 本当に必要な箇所のみにコメント投稿
gh api repos/$REPO/pulls/<PR番号>/comments \
  --method POST \
  --field body="簡潔なwhy説明" \
  --field commit_id="$HEAD_SHA" \
  --field path="ファイルパス" \
  --field line=行番号

# 実例：
REPO=$(gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"')
HEAD_SHA=$(gh pr view 141 --json headRefOid --jq '.headRefOid')
gh api repos/$REPO/pulls/141/comments \
  --method POST \
  --field body="API直接利用: gh pr reviewではライン別コメント不可のため" \
  --field commit_id="$HEAD_SHA" \
  --field path=".claude/agents/pr-comment.md" \
  --field line=52
```

## コメント例（簡潔なwhy説明）

- `API直接利用: gh pr reviewではライン別コメント不可のため`
- `非同期処理: UI応答性確保のため`  
- `キャッシュ無効化: データ整合性の制約`
- `型ガード追加: 実行時エラー回避のため`

## 実行例

認知負荷が高い箇所のみに簡潔なコメント投稿：

```bash
# 1. 汎用的なリポジトリ情報取得
REPO=$(gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"')
HEAD_SHA=$(gh pr view 141 --json headRefOid --jq '.headRefOid')

# 2. 差分確認（認知負荷が高い箇所を特定）
gh pr diff 141

# 3. 本当に必要な箇所のみコメント投稿
gh api repos/$REPO/pulls/141/comments \
  --method POST \
  --field body="API直接利用: gh pr reviewではライン別コメント不可のため" \
  --field commit_id="$HEAD_SHA" \
  --field path=".claude/agents/pr-comment.md" \
  --field line=52

# 4. 結果確認
gh pr view 141
```

## 注意点

- **GitHub API を使用**：`gh pr review` コマンドではライン別コメント不可
- **commit_id 必須**：PRのhead SHA を正確に指定
- **path は差分パスと完全一致**：差分に表示されるファイルパスを使用
- **line は実ファイルの行番号**：新規ファイルの場合は追加行番号
- **1つのAPIコールで1つの行**：複数行には複数回実行が必要
