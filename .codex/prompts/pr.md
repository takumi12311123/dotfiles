---
allowed-tools: Bash(gh:*), Bash(git:*)
description: Create a pull request with proper formatting and review
argument-hint: [title] [issue-number] (optional - will analyze changes if not provided)
---

## Context

- Current branch: !`git branch --show-current`
- Diff against main: !`git diff main...HEAD --stat`
- Commit history: !`git log --oneline main..HEAD`
- Related issues: !`gh issue list --limit 5 2>/dev/null || echo "No issues found"`

## PR Creation Process

### 1. Change Analysis

Review the changes to understand:

- What functionality was added/modified/fixed
- Impact and scope of changes
- Any potential concerns or breaking changes

### 2. PR Requirements

**Title Format (English):**

- Use conventional commit format: `<type>: <description>`
- Keep under 50 characters
- Examples: `feat: add user authentication`, `fix: resolve token expiration`

**Body Format (Japanese):**

```
## 概要
[Brief overview of changes in Japanese]

## 変更点
- [List of specific changes]
- [Additional modifications]

## 注意点
[Any concerns or breaking changes if applicable]

issue: #[issue-number]
```

### 3. Quality Checks

Before creating PR:

- [ ] All changes are intentional and reviewed
- [ ] No sensitive information or debug code included
- [ ] Related issue numbers are identified
- [ ] Changes align with project conventions

### Your Task

Based on the diff analysis above:

1. **Review the changes** and identify the main purpose
2. **Generate appropriate PR title** (English, conventional format)
3. **Create PR body** (Japanese, following template above)
4. **Link related issues** if any exist
5. **Create the PR** using `gh pr create`

If title and issue number were provided as arguments, use those. Otherwise, analyze the changes and suggest appropriate values.

**Important**: If any changes seem unclear or concerning, ask for clarification before creating the PR.
