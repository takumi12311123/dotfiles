# PR Creation Rules

## Important Rules

- PR titles must be written in **English**
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
## Summary
Implemented user authentication functionality. This includes JWT authentication with login/logout features and access token refresh capabilities for improved user experience.

## Changes
- Introduced JWT authentication
- Implemented login/logout functionality
- Added token refresh feature

issue: #123
EOF
)"
```

## PR Checklist

- [ ] Is the PR title in English?
- [ ] Are related GitHub tickets linked?
- [ ] Have you thoroughly reviewed the diff?
- [ ] Have you included a summary of approximately 100 characters?
- [ ] Are there any unclear points or concerns? (If yes, consult the user)
- [ ] Are you using the `gh pr create` command?

## Notes

- Always review the diff before creating a PR to ensure no unintended changes are included
- Create a clear summary of approximately 100 characters based on the diff
- Explain changes clearly to help reviewers understand the modifications