---
name: agy-review
description: |
  Antigravity CLI (agy) code review gate. Runs in parallel with codex-review via quality-gate.
  Uses agy in non-interactive mode for an independent second-opinion review.
metadata:
  auto-trigger: false
---

# agy Automatic Review Gate

## Purpose

**Independent second-opinion review**: Runs in parallel with codex-review to provide a different model perspective.
Cross-checking both results reduces missed issues and increases confidence.

## What agy can see

agy runs headless inside a private temp directory and cannot read outside it. The directory holds:

| File | Content |
|------|---------|
| `review.diff` | The diff under review |
| `repo/` | A copy of the working tree (tracked files + untracked files that are not ignored), attached only when it matches the diff |
| `repo-files.txt` | Paths of every file under `repo/`, so agy opens files by path instead of searching |

Left out of both — by **path name**, not by content:
`.env`, `.env.*`, `*.key`, `*.pem`, `*credentials*`, `*secret*`, `*.tfvars`, `*.tfstate`.
Symlinks and submodules are never copied. Everything else in the working tree can be sent to the
model provider, so a secret written directly into a source or config file is **not** filtered.

The temp directory is removed when the script ends, including on failure and on INT/TERM/HUP.

## Execution Flow

### Step 1: Execute agy Review

One command, no setup. The scripts live in the installed skills directory
(`~/.claude/skills` is a symlink to this repository's `.claude/skills`).

```bash
# Local changes (uncommitted + untracked) of the current repository:
~/.claude/skills/agy-review/scripts/agy-review.sh

# Someone else's PR (the script runs `gh pr diff` / `gh pr view` itself):
~/.claude/skills/agy-review/scripts/agy-review.sh --pr <PR番号>
```

In PR mode `repo/` is attached only when the local `HEAD` is the PR head **and** the working tree
is clean. Otherwise agy gets the diff alone and the envelope's `detail` says why — a tree that
differs from the PR would be read as context for code the PR does not contain.

Option: `--timeout 300s` (default; agy's own `--print-timeout`). The model is fixed in `agy-exec.sh`.

- Progress log: `[agy review] Running (max 5min)...`

### Step 2: Result Handling

agy-review does NOT iterate independently. The script prints **one line of JSON, the envelope**, and
always exits 0. Callers decide on `status`, never on the exit code or on wording:

| `status` | `result` | `detail` | Caller |
|----------|----------|----------|--------|
| `completed` | Review object (same shape as `codex-review/review-schema.json`) | Empty, or why `repo/` was not attached / which files were excluded | Use the review |
| `skipped` | `null` | Excluded file names | Report "agy: nothing reviewable (all files excluded)". Not a failure |
| `timeout` | `null` | The time limit | No agy result. Say "Codex 単独" explicitly and continue |
| `quota` | `null` | agy's error text | Same |
| `error` | `null` | Reason (not installed, not signed in, denied tool, malformed output, ...) | Same |

**Anything other than `completed` is not "no issues found".**

```json
{"status": "completed", "detail": "", "result": {"ok": false, "phase": "detail", "summary": "...", "issues": [], "notes_for_next_review": ""}}
```

`result.ok` is recomputed by the script: `false` when any issue has `severity: "blocking"`, otherwise
`true`. The model's own `ok` is discarded because it has returned `ok: true` together with a blocking issue.

## Failure modes the script already handles

| What agy does | Why it matters |
|---------------|----------------|
| Print timeout → exit 0, `status: "SUCCESS"`, empty response | The exit code cannot detect it → `timeout` |
| Denied tool call (headless agy cannot ask for permission) → may end with an empty response | → `error`, with the denied action in `detail` |
| Long prompt argument → the tail is silently dropped | The diff is passed as a file, never inside the prompt |
| stdin | Not read by `agy -p` |

## Tests

```bash
bash .claude/skills/agy-review/tests/run-tests.sh
```

Runs without calling agy: a fake `agy` on `PATH` replays recorded outputs from `tests/fixtures/`.

## Output Format to User

**All user-facing output must be in Japanese.**

agy review results are shown alongside Codex results in quality-gate output:

```markdown
### agy Review Result
- **Status**: completed / skipped / timeout / quota / error
- **Issues**: blocking: N, advisory: M

#### agy-only Issues (not found by Codex)
- `file.py:42` - [Problem description] (category/severity)
```

## Important Reminders

1. **Parallel execution**: Always run in parallel with codex-review
2. **Decide on `status`**: only `completed` carries a review
3. **Non-interactive**: the script runs `agy -p`; do not call `agy` directly for reviews
4. **Output in Japanese**: All user-facing text in Japanese
5. **Merge decision**: Final decision is made by quality-gate
