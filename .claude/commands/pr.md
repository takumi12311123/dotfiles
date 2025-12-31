---
allowed-tools: Bash(git:*), Bash(gh:*)
description: Complete PR workflow - branch, commit, push, create/update PR
argument-hint: [commit-message] (optional - will analyze changes if not provided)
---

## Full PR Workflow

This command handles the complete PR workflow:
1. Create feature branch (if on main/master)
2. Commit changes with conventional commit format
3. Push to remote
4. Create or update pull request

## Context

- Current branch: !`git branch --show-current`
- Current status: !`git status`
- Unstaged/staged changes: !`git diff HEAD --stat`
- Recent commits: !`git log --oneline -10`
- Existing PR: !`gh pr view --json number,title,body 2>/dev/null || echo "No PR exists"`
- Related issues: !`gh issue list --limit 5 2>/dev/null || echo "No issues found"`

## Your Task

Execute the following steps in order:

### Step 1: Branch Management

Check current branch:
- If on `main` or `master`:
  1. Analyze changes to determine commit type
  2. Create branch with appropriate prefix:
     - `feat:` changes → `feature/{description}`
     - `fix:` changes → `fix/{description}`
     - `hotfix:` changes → `hotfix/{description}`
     - `docs:` changes → `docs/{description}`
     - `style:` changes → `style/{description}`
     - `refactor:` changes → `refactor/{description}`
     - `test:` changes → `test/{description}`
     - `chore:` changes → `chore/{description}`
  3. Use kebab-case for description (e.g., `feature/add-user-auth`)
  4. Execute: `git checkout -b {prefix}/{description}`

- If already on a feature branch:
  - Continue with that branch

### Step 2: Commit Changes

Create commit with conventional commit format:

**Commit Message Format:**
```
<type>: <subject>

[Optional detailed explanation]

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Commit Types:**
- `feat`: New feature
- `fix`: Bug fix
- `hotfix`: Critical bug fix (production)
- `docs`: Documentation only
- `style`: Code formatting (no logic change)
- `refactor`: Code refactoring
- `test`: Adding/modifying tests
- `chore`: Build/tooling changes

**Process:**
1. Stage all changes: `git add .`
2. If commit message provided as argument, use it
3. Otherwise, analyze changes and generate appropriate message
4. Create commit with message in HEREDOC format:
   ```bash
   git commit -m "$(cat <<'EOF'
   feat: add user authentication

   - Implement OAuth2 flow
   - Add JWT token handling

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

### Step 3: Push to Remote

Push branch to remote:
```bash
git push -u origin $(git branch --show-current)
```

### Step 4: Create or Update PR

**Check if PR exists:**
```bash
gh pr view --json number 2>/dev/null
```

**If PR does NOT exist (create new):**

1. Generate PR title (English, conventional format):
   - Format: `<type>: <description>`
   - Keep under 50 characters
   - Examples: `feat: add user authentication`, `fix: resolve token expiration`

2. Generate PR body (Japanese):
   ```markdown
   ## 概要
   [変更内容の概要を日本語で]

   ## 変更点
   - [具体的な変更1]
   - [具体的な変更2]
   - [具体的な変更3]

   ## テスト
   - [テスト内容]

   ## 注意点
   [破壊的変更や注意事項があれば]

   issue: #[issue-number]

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   ```

3. Create PR:
   ```bash
   gh pr create --title "{title}" --body "$(cat <<'EOF'
   {body content}
   EOF
   )"
   ```

**If PR already exists (update):**

1. Analyze new changes since last commit
2. Update PR body to reflect all changes (not just new ones):
   - Keep the same structure
   - Update 変更点 section with ALL changes in the PR
   - Add any new 注意点 if applicable

3. Update PR:
   ```bash
   gh pr edit {pr-number} --body "$(cat <<'EOF'
   {updated body content}
   EOF
   )"
   ```

4. Add comment about the update:
   ```bash
   gh pr comment {pr-number} --body "Updated PR with additional changes:
   - [新しい変更1]
   - [新しい変更2]"
   ```

## Quality Checks

Before executing, verify:
- [ ] No sensitive information in changes (API keys, passwords, etc.)
- [ ] No debug code or console.logs left in
- [ ] Changes are intentional and complete
- [ ] Commit message accurately describes changes
- [ ] Branch name follows conventions

## Branch Naming Examples

```bash
# Feature development
feat: add user profile page → feature/add-user-profile-page
feat: implement OAuth2 → feature/implement-oauth2

# Bug fixes
fix: resolve login timeout → fix/resolve-login-timeout
fix: correct email validation → fix/correct-email-validation

# Hotfixes (production)
hotfix: patch security vulnerability → hotfix/patch-security-vulnerability

# Documentation
docs: update API documentation → docs/update-api-documentation

# Refactoring
refactor: simplify auth logic → refactor/simplify-auth-logic

# Tests
test: add integration tests → test/add-integration-tests

# Chore/tooling
chore: update dependencies → chore/update-dependencies
```

## Error Handling

**If branch creation fails:**
- Check if branch already exists
- Suggest alternative branch name

**If commit fails:**
- Check for pre-commit hooks
- Show hook output
- Ask user how to proceed

**If push fails:**
- Check remote connection
- Check if branch is up to date
- Suggest `git pull --rebase` if needed

**If PR creation/update fails:**
- Check gh CLI authentication: `gh auth status`
- Check if upstream remote exists
- Show error message and suggest fixes

## Important Notes

1. **Always use HEREDOC for commit messages and PR bodies** to handle multi-line content
2. **Always add Claude Code attribution** to commits and PRs
3. **Keep PR body in Japanese** for better readability for Japanese teams
4. **Keep PR title in English** following conventional commit format
5. **Update existing PR body completely**, not just append
6. **Use kebab-case** for branch names (lowercase with hyphens)
7. **Determine branch prefix from commit type**, not manually specified

## Output Format to User

After successful execution:

```markdown
## PR作成完了 ✅

### ブランチ
- **作成/使用**: `feature/add-user-authentication`
- **ベースブランチ**: `main`

### コミット
- **メッセージ**: `feat: add user authentication`
- **変更ファイル**: 5 files changed, 234 insertions(+), 12 deletions(-)

### プッシュ
- **リモート**: `origin/feature/add-user-authentication`
- **ステータス**: ✅ 成功

### プルリクエスト
- **番号**: #123
- **タイトル**: `feat: add user authentication`
- **URL**: https://github.com/{owner}/{repo}/pull/123
- **状態**: Open

次のステップ:
- レビューを依頼する
- CIの結果を確認する
- マージ準備をする
```

For PR update:

```markdown
## PR更新完了 ✅

### 新しいコミット
- **メッセージ**: `feat: add password reset flow`
- **変更ファイル**: 3 files changed, 87 insertions(+), 5 deletions(-)

### プルリクエスト
- **番号**: #123
- **タイトル**: `feat: add user authentication` (変更なし)
- **URL**: https://github.com/{owner}/{repo}/pull/123
- **更新内容**:
  - PR bodyを最新の変更内容で更新
  - コメントを追加して変更点を通知

次のステップ:
- 追加の変更があればレビュアーに通知
- CIの結果を再確認する
```
