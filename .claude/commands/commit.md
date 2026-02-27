---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*)
description: Create a git commit with proper message formatting
argument-hint: [message] (optional - if not provided, will analyze changes and suggest)
---

## Context

- Current git status: !`git status`
- Current diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your Task

Based on the above changes, create **fine-grained, atomic commits** following these rules.

### Core Principle: One Logical Unit Per Commit

**Do NOT create a single big commit for all changes.** Instead:

1. **Analyze all changes** and group them by logical unit
2. **Stage and commit each group separately** in a meaningful order
3. Each commit should be independently understandable and ideally pass tests on its own

### Grouping Strategy

Group changes by these criteria (in priority order):

1. **By feature/purpose**: Each distinct feature, fix, or improvement gets its own commit
2. **By file relationship**: Files that are tightly coupled go together (e.g., implementation + its tests)
3. **By type**: Separate structural changes (refactor, rename) from behavioral changes (feat, fix)

**Examples of good splitting:**
- Config changes → separate commit
- New utility function → separate commit
- Feature implementation using that utility → separate commit
- Tests for the feature → same commit as feature OR separate commit
- Documentation updates → separate commit
- Dependency changes → separate commit

### Commit Process

For each logical group:

```bash
# 1. Stage specific files for this group
git add path/to/file1 path/to/file2

# 2. Commit with appropriate message
git commit -m "$(cat <<'EOF'
<type>: <subject>
EOF
)"
```

**Order commits logically:**
- Infrastructure/config changes first
- Dependencies/utilities before consumers
- Implementation before documentation
- Base features before features that depend on them

### Commit Message Format

**Always use HEREDOC format** for consistency with PR workflow:

```bash
git commit -m "$(cat <<'EOF'
<type>: <subject>

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Multi-line format (when detailed explanation needed):**

```bash
git commit -m "$(cat <<'EOF'
<type>: <subject>

Detailed explanation of changes and reasoning.
Additional context or breaking changes if applicable.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Commit Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only changes
- `style`: Code formatting, missing semi-colons, etc (no logic changes)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding or modifying tests
- `chore`: Build process, auxiliary tools, or libraries

### Guidelines

- Write in **English** using imperative mood ("Add feature", "Fix bug")
- Capitalize the first letter
- No period at the end of the subject line
- Keep subject line under 50 characters
- Use body for detailed explanation when necessary
- **Aim for 2-5 commits** for typical changes (don't over-split trivial changes)
- **Single file changes** can still be one commit
- If a commit message was provided as an argument and changes are small/cohesive, use it as-is

### Examples

**Before (bad - one big commit):**
```
chore: update config and add authentication
```

**After (good - fine-grained commits):**
```
chore: add JWT dependencies to package.json
feat: add token validation utility
feat: implement user authentication flow
test: add authentication integration tests
docs: update API documentation for auth endpoints
```
