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

Based on the above changes, create a single git commit following these rules:

### Commit Message Format

**Single line format (preferred):**

```
<type>: <subject>
```

**Multi-line format (when detailed explanation needed):**

```
<type>: <subject>

Detailed explanation of changes and reasoning.
Additional context or breaking changes if applicable.
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

### Examples

```
feat: add user authentication system
fix: resolve token expiration handling
refactor: simplify database connection logic
docs: update API documentation for v2.0
```

If a commit message was provided as an argument, use it. Otherwise, analyze the changes and suggest an appropriate commit message following these conventions.
