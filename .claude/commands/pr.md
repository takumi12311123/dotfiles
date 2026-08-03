---
allowed-tools: Bash(git:*), Bash(gh:*)
description: Complete PR workflow - branch, commit, push, create/update PR
argument-hint: "[commit-message] (optional - will analyze changes if not provided)"
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
  - Continue with that branch, but **validate the name in Step 1.5**

### Step 1.5: Branch Name Validation (when already on a feature branch)

Some editors (e.g., Superset) auto-generate arbitrary branch names like
`cursor/xyz-abc123`, `codex/1234567890`, or `branch-tmp-42`. These break the
convention and make PR history hard to scan. Validate before pushing — but
lean conservative: only flag names that are clearly editor-generated or
convention-violating, so continuing work on a legitimate branch is never
disrupted.

**Preflight checks** (skip Step 1.5 entirely if any of these are true):

1. **Detached HEAD** — If `git branch --show-current` is empty, stop and
   tell the user to check out or create a branch first. Do NOT attempt rename.
2. **On `main`/`master`** — Already handled by Step 1.
3. **PR already attached** — Run `gh pr view --json number 2>/dev/null` and
   check exit status:
   - exit 0 with a number → PR exists, skip rename (would break PR reference)
   - exit ≠ 0 → **unconfirmable** (auth failure, network, non-GitHub remote,
     etc.). Treat as unsafe: also skip rename by default and tell the user
     "PR 状態を確認できなかったため rename を保留しました" so they can rerun after
     `gh auth login` or handle manually.

**Failure conditions** — flag the branch as needing rename ONLY when at least
one of the following is objectively true (do NOT rename on soft signals alone):

1. **No valid prefix** — Branch does NOT start with one of:
   `feature/`, `fix/`, `hotfix/`, `docs/`, `style/`, `refactor/`, `test/`, `chore/`.
   This alone is a hard flag.
2. **Obvious editor-generated pattern** — e.g. `cursor/…`, `codex/…`,
   `copilot/…`, `agent-…`, `tmp-…`, `branch-<digits>`, or a description that
   looks like a random hash / timestamp (`abc123`, `1234567890`).
3. **Non-kebab-case description** — camelCase / snake_case / spaces in the
   part after the prefix (e.g. `feature/AddUserAuth`, `fix/bug_report`).

**Advisory only (do NOT auto-rename)** — mention but let the user decide:

- **Prefix ↔ change-type mismatch** — the branch prefix and the current diff's
  dominant change type disagree (e.g. `feature/…` branch making a docs-only
  commit). This is often legitimate mid-flight work, so surface it as a note,
  not a rename trigger. Only propose a prefix change if the user explicitly
  asks to normalize.
- **Too generic description** — `feature/update`, `fix/bug`. Point it out
  once; still let the user proceed.

**If the branch is flagged (a failure condition matched):**

1. Propose an appropriate name based on the actual diff (same rules as Step 1).
2. Ask the user:

   > "現在のブランチ名 `{current}` は規約に合っていません（理由: `{reason}`）。
   > 提案: `{proposed}`
   > リネームしますか？ (yes / no / other name)"

3. On `yes` — execute rename safely:

   ```bash
   CURRENT=$(git branch --show-current)
   PROPOSED={proposed}

   # Detect upstream (do NOT hardcode `origin`)
   UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)

   # Local rename first — always safe
   git branch -m "$PROPOSED"

   if [ -n "$UPSTREAM" ]; then
     # Upstream exists (branch was already pushed). Order matters:
     # 1) push the NEW name to the SAME remote and set upstream
     # 2) only after that succeeds, delete the OLD remote branch
     # Never delete-then-push — a failed push leaves the remote with nothing.
     REMOTE="${UPSTREAM%%/*}"       # e.g. "origin", "upstream", "fork"
     git push -u "$REMOTE" "$PROPOSED" || {
       echo "❌ Push of $PROPOSED to $REMOTE failed. Old remote branch $CURRENT is untouched."
       exit 1
     }
     # Extra confirm before destroying the old remote branch
     echo "旧リモートブランチ $REMOTE/$CURRENT を削除してよいですか？ (yes/no)"
     # On yes:
     # git push "$REMOTE" --delete "$CURRENT"
   fi
   ```

4. On `no`: keep the current name, continue with Step 2.
5. On `other`: use the user-provided name — but **re-run ALL failure
   conditions above** (missing prefix, editor-generated pattern, non-kebab-case).
   Reject and re-prompt if any still fail. Prevents `feature/1234567890` and
   similar hash/timestamp names from slipping through on retry.

**Do NOT rename silently.** Always confirm before executing `git branch -m`.
**Never delete a remote branch before the replacement push succeeds.**

### Step 2: Commit Changes (Fine-Grained)

Create **multiple atomic commits** grouped by logical unit.

**Do NOT create a single big commit.** Instead:

1. **Analyze all changes** and group by logical unit (feature, fix, config, test, docs, etc.)
2. **Stage and commit each group separately** in dependency order
3. Each commit should be independently understandable

**Grouping Strategy:**
- Config/dependency changes → separate commit
- Each distinct feature or fix → separate commit
- Tests → same commit as implementation OR separate commit
- Documentation → separate commit
- Refactoring → separate commit from behavioral changes

**Commit Types:**
- `feat`: New feature
- `fix`: Bug fix
- `hotfix`: Critical bug fix (production)
- `docs`: Documentation only
- `style`: Code formatting (no logic change)
- `refactor`: Code refactoring
- `test`: Adding/modifying tests
- `chore`: Build/tooling changes

**Process for each logical group:**
1. Stage specific files: `git add path/to/file1 path/to/file2`
2. Create commit with HEREDOC format:
   ```bash
   git commit -m "$(cat <<'EOF'
   feat: add JWT token handling

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```
3. Repeat for next group

**Commit order (dependencies first):**
1. Infrastructure/config changes
2. Dependencies/utilities
3. Core implementation
4. Tests
5. Documentation

**Guidelines:**
- Aim for **2-5 commits** for typical PRs
- Don't over-split trivial changes (single file change = one commit is fine)
- If argument provided and changes are small/cohesive, use single commit

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

Apply the same disambiguation as Step 1.5: exit 0 → PR exists (go to update
path); exit ≠ 0 → **unconfirmable** (auth, network, non-GitHub remote). Do
NOT silently treat unconfirmable as "no PR" — stop and tell the user
"PR 状態を確認できませんでした。`gh auth status` を確認してから再実行してください。"
so we never create a duplicate PR against an already-open one.

**Detect PR template (run via Bash tool BEFORE generating PR body):**

Check the following paths in order and use the first one that exists:
```bash
ls -1 .github/PULL_REQUEST_TEMPLATE.md \
      .github/pull_request_template.md \
      PULL_REQUEST_TEMPLATE.md \
      pull_request_template.md \
      docs/PULL_REQUEST_TEMPLATE.md \
      docs/pull_request_template.md 2>/dev/null | head -n 1
```

Also check for multiple templates:
```bash
ls -1 .github/PULL_REQUEST_TEMPLATE/ 2>/dev/null
```

If a template file is found, read its contents with the Read tool.

**If PR does NOT exist (create new):**

1. Generate PR title (English, conventional format):
   - Format: `<type>: <description>`
   - Keep under 50 characters
   - Examples: `feat: add user authentication`, `fix: resolve token expiration`

2. Generate PR body — **PR templates take priority**:

   **Priority order:**
   1. **Project PR template exists** (`.github/PULL_REQUEST_TEMPLATE.md`, `.github/pull_request_template.md`, `PULL_REQUEST_TEMPLATE.md`, `pull_request_template.md`, `docs/PULL_REQUEST_TEMPLATE.md`, or `docs/pull_request_template.md`):
      - **MUST use the project template as-is** (structure, sections, headings, language)
      - Fill in each section based on the actual changes
      - Preserve comments (`<!-- -->`), checkboxes (`- [ ]`), and section order from the template
      - Do NOT translate section headings or restructure the template
      - Append Claude Code attribution at the end:
        ```
        🤖 Generated with [Claude Code](https://claude.com/claude-code)
        ```

   2. **Multiple PR templates exist** (`.github/PULL_REQUEST_TEMPLATE/*.md`):
      - Pick the template that best matches the change type (e.g., `feature.md` for `feat:`, `bugfix.md` for `fix:`)
      - If unclear, ask the user which template to use
      - Fill in and follow the same rules as above

   3. **No PR template** (fallback to default Japanese body):
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

3. Create PR (always self-assign with `--assignee @me`):
   ```bash
   gh pr create --assignee @me --title "{title}" --body "$(cat <<'EOF'
   {body content}
   EOF
   )"
   ```

   If `--assignee @me` fails (e.g. the account can't be resolved), create the
   PR without it and then self-assign as a follow-up:
   ```bash
   gh pr edit {pr-number} --add-assignee @me
   ```

**If PR already exists (update):**

1. Analyze new changes since last commit
2. Update PR body to reflect all changes (not just new ones):
   - **Preserve the existing PR body's structure** (whether it follows a project template or the default Japanese body)
   - If the existing body follows a project PR template, keep its sections, headings, and language as-is
   - Update all sections with the latest content (not just append)
   - Add any new notes/caveats if applicable

3. Update PR (also ensure self-assignment — no-op if already assigned):
   ```bash
   gh pr edit {pr-number} --add-assignee @me --body "$(cat <<'EOF'
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
3. **PR template priority**: If a project PR template exists, follow it exactly (structure, language, sections). The default Japanese body is only a fallback when no template exists.
4. **Keep PR title in English** following conventional commit format
5. **Update existing PR body completely**, not just append
6. **Use kebab-case** for branch names (lowercase with hyphens)
7. **Determine branch prefix from commit type**, not manually specified
8. **Validate arbitrary branch names** from editors like Superset in Step 1.5 — propose a rename before push when the name doesn't follow convention (never rename silently)
9. **Always self-assign the PR** with `--assignee @me` on create (and `--add-assignee @me` on update) so the PR is owned by the author automatically

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
