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

## Step 1: Plan File Output

When exiting plan mode:

1. Create file: `.claude/plans/{task-name}.md`
2. Include:
   - Task summary
   - Implementation steps
   - Files to modify
   - Risks/considerations

## Step 2: Project Check Detection

Scan for ALL applicable config files and run ALL matching checks:

| File | Check Command |
|------|---------------|
| `Makefile` | Run available targets: `make lint`, `make check`, `make fmt` |
| `package.json` | Run available scripts: `lint`, `check`, `build`, `test` |
| `go.mod` | `go fmt ./...` + `go vet ./...` + `go build ./...` |
| `pyproject.toml` | `ruff format` + `ruff check` |
| `Cargo.toml` | `cargo fmt` + `cargo clippy` + `cargo build` |

**Detection rules:**
1. Scan ALL config files in project root
2. Collect ALL applicable commands (not first-match)
3. Verify target/script exists before running
4. Skip unavailable commands gracefully (no error)
5. If no checks found, proceed to codex-review

## Step 3: Run codex-review

Execute `codex-review` skill:
- Wait for `ok: true`
- If blocking issues exist, fix and re-run checks
- Max 5 iterations

## Important

- NEVER skip this gate
- ALWAYS wait for checks to complete
- Fix ALL blocking issues before proceeding
- Document any skipped checks with reason
