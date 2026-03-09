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
│  3. Run codex-review + gemini-review IN PARALLEL    │
│     → Launch both as background tasks               │
│     → Wait for both to complete                     │
│     → Merge results                                 │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  4. Merge & Evaluate Review Results                 │
│     → Both agree ok: proceed                        │
│     → Codex blocking: must fix                      │
│     → Gemini-only blocking: present as advisory+    │
│     → Contradictions: flag to user                  │
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

## Step 3: Run codex-review + gemini-review IN PARALLEL

**When triggered from ExitPlanMode (plan review):**
- Step 1 already ran Plan Review via codex-review
- **Skip Step 2 and Step 3** (no code changes to lint or review yet)
- Proceed directly to user presentation for plan approval

**When triggered from commit/PR/user confirmation (code review):**

### Security: Gemini Review is Opt-In

Gemini review sends diffs to Google's API. It is only active when:
1. `gemini` CLI is installed and authenticated
2. `gemini` CLI command is available in PATH

Gemini review is **automatically available** when the CLI is installed.
To **disable** Gemini review, uninstall or remove `gemini` from PATH.

**Sensitive content protection**: gemini-review applies filename-based filtering
(`.env`, `*.key`, `*.pem`, `*credentials*`, `*secret*`, `*.tfvars`, `*.tfstate`).
However, secrets embedded in regular source files are NOT filtered.
For repositories with embedded secrets, ensure Gemini CLI is not installed.

If `gemini` CLI is not available, quality-gate proceeds with Codex-only review.

### Parallel Execution

Launch both reviews simultaneously using background Subagents:

```
┌──────────────────┐     ┌──────────────────┐
│  Subagent 1:     │     │  Subagent 2:     │
│  codex-review    │     │  gemini-review   │
│  (primary)       │     │  (secondary)     │
└──────────────────┘     └──────────────────┘
         │                        │
         └────────┬───────────────┘
                  ↓
         ┌──────────────────┐
         │  Merge Results   │
         └──────────────────┘
```

**Implementation:**
- Launch `codex-review` as background Agent task
- Launch `gemini-review` as background Agent task
- Wait for both to complete (Gemini timeout: 5min, Codex timeout: 20min)
- If Gemini times out, proceed with Codex result only

### Step 4: Merge & Evaluate Results

Codex と Gemini の結果は **それぞれ独立に保持** し、既存の review-schema.json には手を加えない。
マージ結果は `codex_result` とは **別オブジェクト** として返す（review-schema.json を汚染しない）。

```python
def merge_reviews(codex_result, gemini_result, gemini_status):
    """
    Codex = primary reviewer (blocking authority)
    Gemini = secondary reviewer (additional perspective)

    Args:
        codex_result: dict - codex-review result (review-schema.json)
        gemini_result: dict or None - gemini-review result
        gemini_status: str - "completed" | "timeout" | "error"

    Returns:
        dict with keys:
          - "codex": codex_result (untouched, schema-valid)
          - "gemini": gemini_result or None (untouched)
          - "merge_meta": cross-check metadata (separate structure)
    """

    merge_meta = {
        "gemini_status": gemini_status,
        "cross_verified_files": [],
        "gemini_only_issues": [],
    }

    if gemini_status == "completed" and gemini_result and isinstance(gemini_result, dict):
        gemini_issues = gemini_result.get("issues", [])
        if isinstance(gemini_issues, list):
            for g_issue in gemini_issues:
                if not isinstance(g_issue, dict):
                    continue
                # Match on file + lines + category for stronger identity
                matched_codex = None
                for c in codex_result.get("issues", []):
                    if (c.get("file") == g_issue.get("file") and
                        c.get("lines") == g_issue.get("lines") and
                        c.get("category") == g_issue.get("category")):
                        matched_codex = c
                        break

                if matched_codex:
                    merge_meta["cross_verified_files"].append({
                        "file": g_issue.get("file"),
                        "lines": g_issue.get("lines"),
                        "category": g_issue.get("category"),
                    })
                else:
                    merge_meta["gemini_only_issues"].append({
                        "severity": g_issue.get("severity", "advisory"),
                        "category": g_issue.get("category", ""),
                        "file": g_issue.get("file", ""),
                        "lines": g_issue.get("lines", ""),
                        "problem": g_issue.get("problem", ""),
                        "recommendation": g_issue.get("recommendation", ""),
                    })

    # Return as separate objects — codex_result is never modified
    return {
        "codex": codex_result,
        "gemini": gemini_result,
        "merge_meta": merge_meta,
    }
```

### Output Format (Merged)

```markdown
## レビュー結果

### Codexレビュー ✅/⚠️
- **ステータス**: ok / 未解決issue残存
- **反復回数**: N/5
- **指摘件数**: blocking: N件, advisory: M件

### Geminiレビュー ✅/⚠️/⏰
- **ステータス**: ok / 指摘あり / タイムアウト
- **指摘件数**: blocking: N件, advisory: M件

### クロスチェック
- **両者一致の指摘** (信頼度: 高):
  - `file.py:42` - [問題] (category/severity) ✅ cross-verified
- **Gemini独自の指摘** (参考):
  - `file.py:88` - [問題] (category/advisory) 🔍 gemini-only
```

### Iteration Behavior

- **Codex blocking issues**: Claude Code fixes → re-run both reviews
- **Gemini-only blocking**: Presented as elevated advisory, does NOT trigger fix iteration
- **Both agree blocking**: Highest priority fix
- Max 5 iterations (same as before)

## Important

- NEVER skip this gate
- ALWAYS launch both reviews in parallel
- ALWAYS wait for at least Codex to complete
- Gemini failure is non-blocking (proceed with Codex only)
- Fix ALL Codex blocking issues before proceeding
- Document any skipped checks with reason
