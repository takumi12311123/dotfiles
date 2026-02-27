---
name: quality-gate
description: |
  MANDATORY quality gate. Auto-triggered before: ExitPlanMode, commit, PR, user confirmation.
  Handles plan file output, format/lint/build checks, and codex-review iteration.
metadata:
  auto-trigger: true
---

# Quality Gate

## Purpose

Ensure code quality through automated checks before any user-facing action.

## Auto-Triggers

- Before `ExitPlanMode`
- Before asking "commit?" or similar confirmation
- Before `git commit`
- Before creating PR

## Flow

```
┌─────────────────────────────────────────────────────┐
│  1. Plan Mode Exit?                                 │
│     → Write plan to `.claude/plans/{task-name}.md`  │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  2. Detect & Run Project Checks                     │
│     → Auto-detect from Makefile/package.json/go.mod │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  3. Run codex-review                                │
│     → Wait for ok: true                             │
└─────────────────────────────────────────────────────┘
                        ↓
          ┌─────────────────────────┐
          │  Errors or blocking?    │
          └─────────────────────────┘
                 ↓ Yes        ↓ No
          ┌──────────┐   ┌──────────────┐
          │ Fix      │   │ Notify user  │
          │ issues   │   │ or proceed   │
          └──────────┘   └──────────────┘
                 ↓
          Loop back to step 2
```

## Step 1: Plan File Output & Plan Review

When exiting plan mode:

1. Create file: `.claude/plans/{task-name}.md`
2. Include:
   - Task summary
   - Implementation steps
   - Files to modify
   - Risks/considerations

3. **Run codex-review on the plan itself** (Plan Review mode):
   - Submit the plan file content to Codex for architectural review
   - Codex reviews for: feasibility, missing considerations, risk assessment, better alternatives
   - See codex-review SKILL.md "Plan Review Mode" section for details
   - If Codex identifies blocking issues in the plan, iterate before presenting to user

## Step 2: Project Check Detection

Scan for ALL applicable config files and run ALL matching checks.

**IMPORTANT: Prefer incremental/changed-files-only checks for speed.**

### Incremental Lint Strategy

Before running full lint, detect changed files and run lint on them only:

```bash
# Get changed files (staged + unstaged + untracked)
CHANGED_FILES=$( (git diff --name-only HEAD --diff-filter=ACMR; git ls-files --others --exclude-standard) | sort -u )
```

**For each ecosystem, use targeted lint commands:**

| File | Incremental (preferred) | Full (fallback) |
|------|------------------------|-----------------|
| `package.json` | `npx eslint $JS_TS_FILES` | `yarn lint` |
| `go.mod` | `go vet $GO_PACKAGES` | `go vet ./...` |
| `pyproject.toml` | `ruff check $PY_FILES` | `ruff check` |
| `Cargo.toml` | `cargo clippy --manifest-path` (per crate, see below) | `cargo clippy` |
| `Makefile` | N/A (use make targets) | `make lint` |

Variables are defined in the sample code blocks below (`JS_TS_FILES`, `GO_PACKAGES`, `PY_FILES`, `RS_FILES`).

**JavaScript/TypeScript incremental lint:**
```bash
# Filter changed files by extension
JS_TS_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(js|jsx|ts|tsx)$')

if [ -n "$JS_TS_FILES" ]; then
  # Run ESLint directly on changed files only (MUCH faster than yarn lint)
  npx eslint $JS_TS_FILES
fi
```

**Go incremental lint:**
```bash
# Get unique packages from changed .go files
GO_PACKAGES=$(echo "$CHANGED_FILES" | grep '\.go$' | xargs -I{} dirname {} | sort -u | sed 's|^|./|')

if [ -n "$GO_PACKAGES" ]; then
  go fmt $GO_PACKAGES
  go vet $GO_PACKAGES
fi
```

**Python incremental lint:**
```bash
PY_FILES=$(echo "$CHANGED_FILES" | grep '\.py$')

if [ -n "$PY_FILES" ]; then
  ruff format $PY_FILES
  ruff check $PY_FILES
fi
```

**Rust incremental lint (crate-level):**
```bash
# cargo clippy does NOT accept file paths directly.
# Instead, derive the crate/package from changed .rs files.
RS_FILES=$(echo "$CHANGED_FILES" | grep '\.rs$')

if [ -n "$RS_FILES" ]; then
  # Find Cargo.toml directories for changed files to determine packages
  CRATE_DIRS=$(echo "$RS_FILES" | while read f; do
    dir=$(dirname "$f")
    while [ "$dir" != "." ] && [ ! -f "$dir/Cargo.toml" ]; do
      dir=$(dirname "$dir")
    done
    echo "$dir"
  done | sort -u)

  for crate_dir in $CRATE_DIRS; do
    cargo clippy --manifest-path "$crate_dir/Cargo.toml"
  done
fi
```

### Fallback to Full Lint

Use full lint only when:
- Incremental lint is not possible (e.g., no changed files detected)
- Config files changed (`.eslintrc`, `tsconfig.json`, `ruff.toml`, etc.) that may affect all files
- More than 50% of source files changed

### Format/Build/Test Checks (always run as-is)

Format, build, and test checks typically need full runs:

| File | Check Command |
|------|---------------|
| `package.json` | `npm run build` (if script exists) + `npm test` (if script exists) |
| `go.mod` | `go build ./...` + `go test ./...` |
| `Cargo.toml` | `cargo build` + `cargo test` |
| `pyproject.toml` | `pytest` (if available) |
| `Makefile` | `make test` (if target exists), `make check` (if target exists) |

**Detection rules:**
1. Scan ALL config files in project root
2. Collect ALL applicable commands (not first-match)
3. **Use incremental lint by default** for speed
4. Fall back to full lint when config files changed
5. Verify target/script exists before running
6. Skip unavailable commands gracefully (no error)
7. If no checks found, proceed to codex-review

## Step 3: Run codex-review

**When triggered from ExitPlanMode (plan review):**
- Step 1 already ran Plan Review via codex-review
- **Skip Step 2 and Step 3** (no code changes to lint or review yet)
- Proceed directly to user presentation for plan approval

**When triggered from commit/PR/user confirmation (code review):**
Execute `codex-review` skill:
- Wait for `ok: true`
- If blocking issues exist, fix and re-run checks
- Max 5 iterations

## Important

- NEVER skip this gate
- ALWAYS wait for checks to complete
- Fix ALL blocking issues before proceeding
- Document any skipped checks with reason
