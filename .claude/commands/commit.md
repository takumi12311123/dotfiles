---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git ls-files:*), Bash(git merge-base:*), Bash(git rev-parse:*), Bash(mkdir:*), Bash(cat:*), Bash(rm:*), Bash(touch:*), Bash(printf:*), Bash(echo:*), Bash(grep:*), Bash(awk:*), Bash(sed:*), Bash(jq:*), Bash(dirname:*), Bash(ls:*), Read, Write, Edit, Skill
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

1. Stage specific files for this group:
   ```bash
   git add path/to/file1 path/to/file2
   ```
2. Write the draft message — **never `git commit -m` inline**, it bypasses the gate:
   ```bash
   mkdir -p .claude/pr-review
   cat > .claude/pr-review/commit-msg-draft.txt <<'EOF'
   <type>: <subject>
   EOF
   ```
3. Run the mandatory gate (see Context Hygiene below) and fix whatever it flags:
   ```
   Skill(skill="context-hygiene", args="--trigger=commit")
   ```
4. Commit from the audited file:
   ```bash
   git commit -F .claude/pr-review/commit-msg-draft.txt
   rm -f .claude/pr-review/commit-msg-draft.txt
   ```

**Order commits logically:**
- Infrastructure/config changes first
- Dependencies/utilities before consumers
- Implementation before documentation
- Base features before features that depend on them

### Context Hygiene (BLOCKING, before every commit)

The code and the message are read by people who were not in this session. For **each** commit,
write the draft message to a file first, then run the gate, then commit from that file:

```bash
mkdir -p .claude/pr-review
cat > .claude/pr-review/commit-msg-draft.txt <<'MSG'
{draft subject}

{draft body}
MSG
```

```
Skill(skill="context-hygiene", args="--trigger=commit")
```

It audits the **working tree** (staged + unstaged + untracked — the commit does not exist yet) and
the **draft message file**, rewriting what fails. Criteria: `.claude/rules/comment-policy.md`.

Then commit from the audited file (do NOT re-type the message inline — that bypasses the gate):

```bash
git commit -F .claude/pr-review/commit-msg-draft.txt
rm -f .claude/pr-review/commit-msg-draft.txt
```

Explanations that belong to the reviewer rather than to a future maintainer are moved out of the
code into `.claude/pr-review/prr-draft-<branch>.md` for posting via `prr` — never auto-posted.

### Commit Message Format

**Always write the message to the draft file** (`git commit -m` inline bypasses the
context-hygiene gate and is not allowed):

```bash
cat > .claude/pr-review/commit-msg-draft.txt <<'EOF'
<type>: <subject>

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
```

**Multi-line format (when detailed explanation needed):**

```bash
cat > .claude/pr-review/commit-msg-draft.txt <<'EOF'
<type>: <subject>

Detailed explanation of changes and reasoning.
Additional context or breaking changes if applicable.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
```

Then run the gate and `git commit -F .claude/pr-review/commit-msg-draft.txt`.

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
