---
allowed-tools: Bash(git:*), Bash(gh:*)
description: Push current branch and verify PR description ↔ diff consistency
argument-hint: "(optional - no args; behavior is automatic)"
---

## Purpose

Push the current branch to remote, then — if a PR is already attached — verify that the
PR description and the actual diff are still consistent. Catches cases like
"description mentions `useLoadModels.ts` but it's no longer in the diff (reverted earlier)".

Companion to `/commit` (which only commits) and `/pr` (which handles the full branch +
commit + push + PR-create workflow). Use `/push` after `/commit` when you just want to
publish commits without touching PR creation logic.

## Context

- Current branch: !`git branch --show-current`
- Upstream: !`git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "no upstream"`
- Status: !`git status --short`
- Unpushed commits: !`git log @{u}..HEAD --oneline 2>/dev/null || git log -10 --oneline`
- Existing PR: !`gh pr view --json number,title,body,baseRefName 2>/dev/null || echo "No PR exists"`

## Your Task

Execute the steps below in order. **Refuse if the current branch is `main` or `master`** — push to those branches must go through a PR, per project policy.

### Step 1: Safety check

```bash
BRANCH=$(git branch --show-current)
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  echo "❌ Refusing to push directly to $BRANCH. Create a feature branch first."
  exit 1
fi
```

If on a protected branch, stop and tell the user to create a feature branch (or run `/pr`).

### Step 2: Push

```bash
# First push: set upstream
if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
  git push -u origin "$BRANCH"
else
  git push
fi
```

Surface the resulting `remote → branch` line for the user.

### Step 3: PR existence check

```bash
PR_JSON=$(gh pr view --json number,title,body,baseRefName 2>/dev/null || true)
```

If empty: no PR yet. Tell the user:

> "Push complete. No PR attached yet — run `/pr` to create one."

Then exit (skip Steps 4-5).

### Step 4: Consistency audit (PR description ↔ diff)

Goal: detect file/symbol mentions in the PR description that no longer exist in the diff
(e.g. a file mentioned in the description was reverted later), or files in the diff that
are not mentioned in the description.

```bash
PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number')
PR_BODY=$(echo "$PR_JSON" | jq -r '.body')
BASE=$(echo "$PR_JSON" | jq -r '.baseRefName')

# 1. Actual touched files in this PR
TOUCHED=$(git diff "origin/$BASE"...HEAD --name-only | sort -u)

# 2. File paths mentioned in PR description
# Strip code fences first so example/snippet paths don't pollute.
BODY_NO_FENCE=$(printf '%s\n' "$PR_BODY" | awk '/^```/{f=!f;next} !f')

# Extract file-path-like tokens. Tune patterns to your stack.
MENTIONED=$(printf '%s\n' "$BODY_NO_FENCE" \
  | grep -oE '[A-Za-z0-9_./\-]+\.(ts|tsx|js|jsx|py|go|rs|md|yml|yaml|json|sh|sql)' \
  | sort -u)
```

Compute two sets:

- **Mentioned but not touched** = `MENTIONED - TOUCHED` (stale references in description)
- **Touched but not mentioned** = `TOUCHED - MENTIONED` (files changed but not described)

Show both. The first is usually more important (it implies the description is *wrong*).

### Step 5: Offer to update

If discrepancies are found, present them clearly and ask:

> "PR description appears out of sync. Want me to draft an updated body and run
> `gh pr edit $PR_NUMBER --body ...`?"

**Do not auto-edit**. The user must confirm. When confirmed:

1. Draft a replacement body that:
   - Preserves the original structure (PR template sections, headings, language)
   - Removes mentions of files no longer in the diff
   - Adds mentions for files in the diff but missing from the description
   - Keeps any unrelated narrative (rationale, screenshots, test notes)
2. Apply with `gh pr edit $PR_NUMBER --body "$(cat <<'EOF' ... EOF)"`.

If everything matches: print a short ✅ and stop.

## Output format (success path)

```markdown
## Push 完了 ✅

### Branch
- **`feature/foo`** → `origin/feature/foo`

### Commits pushed
- `abc1234` feat: ...
- `def5678` fix: ...

### PR consistency check
- PR: #123 "feat: foo"
- ⚠ Description mentions but diff doesn't contain:
  - `src/legacy/oldHandler.ts` (likely reverted later)
- ⚠ Diff contains but description doesn't mention:
  - `src/lib/newHelper.ts`

→ Update PR description? (yes/no)
```

Or when clean:

```markdown
## Push 完了 ✅

### Branch
- **`feature/foo`** → `origin/feature/foo`

### Commits pushed
- `abc1234` feat: ...

### PR consistency check
- PR: #123 "feat: foo"
- ✅ Description and diff are consistent.
```

## Notes & caveats

- **False positives**: A description might legitimately reference a file from
  another PR / past context. The user is the judge — never silently rewrite.
- **Pattern tuning**: The extension list in Step 4 is conservative. If a project
  uses unusual extensions (`.tf`, `.proto`, `.kt`, etc.), extend the regex.
- **Symbol-level checks** (function/class names mentioned in description but
  not in diff) are out of scope here — too noisy. File-level is the sweet spot.
- **No PR**: This skill is a no-op for branches without a PR attached. Use `/pr`
  to create one.
- **Force push** is intentionally not handled here. If a force push is needed,
  the user should do it explicitly with awareness.

## Error handling

**If push fails (non-fast-forward):**
- Show the error
- Suggest `git pull --rebase` and re-run

**If `gh` not authenticated:**
- Show `gh auth status` output
- Tell the user to `gh auth login` then re-run

**If PR description is empty:**
- Skip the consistency check, just confirm push success
- Suggest filling in the description via `gh pr edit`
