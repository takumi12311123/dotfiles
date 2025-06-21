# PR Creation Rules

## Important Rules

- PR titles must be written in **English**
- PR body must be written in **Japanese**
- Link related GitHub tickets in the format `issue: #123`
- Always use the `gh pr create` command to create PRs
- Review the diff against the base branch and include a summary of approximately 100 characters
- If there are any unclear points or concerns when reviewing the diff, consult the user before creating the PR

## PR Creation Process

### 1. Review the Differences

```bash
# Check diff against main branch
git diff main...HEAD

# Check commit history
git log --oneline main..HEAD
```

### 2. Create the PR

```bash
# Use gh pr create command
gh pr create --title "feat: implement user authentication" --body "$(cat <<'EOF'
## 概要
ユーザー認証機能を実装しました。JWT認証によるログイン・ログアウト機能と、アクセストークンのリフレッシュ機能を追加し、ユーザー体験を向上させました。

## 変更点
- JWT認証の導入
- ログイン・ログアウト機能の実装
- トークンリフレッシュ機能の追加

issue: #123
EOF
)"
```

## PR Checklist

- [ ] Is the PR title in English?
- [ ] PR 本文は日本語で記載されていますか？
- [ ] Are related GitHub tickets linked?
- [ ] Have you thoroughly reviewed the diff?
- [ ] Have you included a summary of approximately 100 characters?
- [ ] Are there any unclear points or concerns? (If yes, consult the user)
- [ ] Are you using the `gh pr create` command?

## Notes

- Always review the diff before creating a PR to ensure no unintended changes are included
- Create a clear summary of approximately 100 characters based on the diff
- Explain changes clearly to help reviewers understand the modifications
