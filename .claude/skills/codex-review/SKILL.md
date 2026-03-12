---
name: codex-review
description: |
  MANDATORY quality gate. Run this skill BEFORE: (1) asking user "Is this okay?", (2) git commit, (3) creating PR, (4) presenting any implementation or design to user. Codex reviews in read-only sandbox, iterates until ok:true. NEVER skip this step.
---

# Codex Automatic Review Gate

## Purpose

**Automatic review gate**: Automatically executed before Claude Code asks for user confirmation.
Quality gate ensuring all blocking issues are resolved before presenting to user.

## Execution Flow

### Step 0: Pre-Review Analysis

```bash
# Determine scope of changes
git diff HEAD --stat
git diff HEAD --name-status --find-renames

# Identify changed files and line counts
# This determines review strategy (small/medium/large)
```

### Step 1: Scope-Based Review Strategy

| Scope | Criteria | Strategy |
|-------|----------|----------|
| small | ≤3 files, ≤100 lines | Single comprehensive review |
| medium | 4-10 files, 100-500 lines | Architecture review → Detailed review |
| large | >10 files, >500 lines | Architecture → Parallel detailed reviews → Cross-check |

### Step 2: Execute Codex Review

**Critical: Codex runs in read-only sandbox for safety**

```bash
ROOT=$(git rev-parse --show-toplevel)
REVIEW_OUT=$(mktemp "${TMPDIR:-/tmp}/codex-review.XXXXXX")

codex exec --model gpt-5.4 --sandbox read-only \
  --output-schema "$ROOT/.claude/skills/codex-review/review-schema.json" \
  -o "$REVIEW_OUT" \
  "$(cat <<'EOF'
# Review Request

All string fields (summary, problem, recommendation, notes_for_next_review) must be in Japanese.

## Context
[Claude Code provides implementation summary]

## Changed Files
[List of modified files with line counts]

## Review Focus Areas
- **Correctness**: Logic errors, edge cases, null handling
- **Security**: Vulnerabilities, input validation, authentication/authorization
- **Performance**: Bottlenecks, inefficient algorithms, resource leaks
- **Maintainability**: Code readability, consistency with existing patterns, comments
- **Testing**: Test coverage, test quality, missing test cases

## Previous Review Notes
[Notes from previous iteration, if any]

## Severity Guidelines
- **blocking**: Must be fixed. Even one blocking issue → ok: false
- **advisory**: Recommended improvement. Does not affect ok status

## Category Definitions
- correctness: Logic errors, incorrect behavior
- security: Security vulnerabilities, unsafe practices
- perf: Performance issues, inefficiency
- maintainability: Code quality, readability, pattern consistency
- testing: Missing tests, inadequate coverage
- style: Code style, naming conventions (usually advisory)
EOF
)"

# Verify result (fail-closed on error)
if [ $? -ne 0 ] || [ ! -s "$REVIEW_OUT" ]; then
  rm -f "$REVIEW_OUT"
  echo "ERROR: codex exec failed or produced empty output" >&2
  exit 1
fi

# Parse result and cleanup
if ! jq . "$REVIEW_OUT"; then
  rm -f "$REVIEW_OUT"
  echo "ERROR: invalid review JSON" >&2
  exit 1
fi
rm -f "$REVIEW_OUT"
```

**Important: Wait for Codex completion**

- Poll every 60 seconds (max 20 times = 20 minutes)
- Progress log: `[Codex review] Poll 5/20 (elapsed: 5min)...`
- Do NOT proceed to other tasks while waiting
- On timeout: Split files and retry

### Step 3: Review Iteration Loop

```python
max_iterations = 5
current_iteration = 0

while current_iteration < max_iterations:
    # Execute Codex review
    review_result = execute_codex_review()

    if review_result["ok"] == True:
        # Review passed - proceed to user presentation
        break

    # Fix all blocking issues
    blocking_issues = [
        issue for issue in review_result["issues"]
        if issue["severity"] == "blocking"
    ]

    for issue in blocking_issues:
        # Claude Code fixes the issue
        fix_issue(issue)

    # Run tests if available
    run_project_tests()

    # Increment iteration counter
    current_iteration += 1

    # If tests fail twice consecutively, stop iteration
    if consecutive_test_failures >= 2:
        break

# After loop completion
if review_result["ok"]:
    present_to_user_with_success_summary()
else:
    present_to_user_with_unresolved_issues()
```

### Step 4: Large Scope - Parallel Subagent Reviews

When scope is "large" (>10 files, >500 lines):

**Split into groups:**
```
Group 1: Authentication related files (3 files)
Group 2: API layer files (4 files)
Group 3: Database layer files (5 files)
Group 4: UI components (4 files)
```

**Launch parallel Subagents:**
```javascript
// Launch 3-5 Subagents in parallel
const subagent_reviews = await Promise.all([
  launch_subagent({ group: 1, files: auth_files }),
  launch_subagent({ group: 2, files: api_files }),
  launch_subagent({ group: 3, files: db_files }),
  launch_subagent({ group: 4, files: ui_files })
]);

// Each Subagent executes Codex review independently
// Results are aggregated for cross-check
```

**Cross-check prompt (after parallel reviews):**
```
Parallel reviews complete. Verify the following cross-cutting concerns:

## Review Results per Group
[Group 1 results]
[Group 2 results]
[Group 3 results]
[Group 4 results]

## Cross-cutting Verification
- Interface consistency: API interface coherence
- Error handling consistency: Uniform error handling
- Authorization coverage: No auth/authz gaps
- API compatibility: Compatibility with existing APIs
- Cross-cutting concerns: Logging, monitoring, security

Report any cross-cutting blocking issues.
```

## Error Handling

### Codex Timeout
1. Split files into half and retry
2. If retry also times out → Skip that section, document as "not reviewed"
3. Continue with remaining files

### Codex API Failure
1. Wait 5 seconds and retry once
2. If retry fails → Partial review with unreviewed sections clearly marked
3. Report error details to user

### Test Failures (after fixes)
- 2 consecutive test failures → Stop iteration
- Report test failures to user with context
- Let user decide whether to proceed

## Output Format to User

**All user-facing output must be in Japanese.**

### Success Case (ok: true)

```markdown
## [Implementation Title]

[Claude Code implementation description]

### Codex Review Result
- **Status**: ok
- **Iterations**: 2/5
- **Review scope**: medium (7 files, 280 lines)
- **Fixed items**:
  1. `auth.py:42-45` - Added authorization check (security/blocking)
  2. `api.py:128` - Improved null check (correctness/blocking)
  3. `utils.py:89` - Unified error handling (maintainability/blocking)

### Advisory (optional)
- `main.py:67` - Verbose function name, refactor recommended (style/advisory)
- `config.py:15` - Extract magic number to constant (maintainability/advisory)

### Not Reviewed
- None

Proceed with this?
```

### Failure Case (ok: false after max iterations)

```markdown
## [Implementation Title]

[Implementation description]

### Codex Review Result
- **Status**: Unresolved issues remain
- **Iterations**: 5/5 (limit reached)
- **Review scope**: small (2 files, 150 lines)

### Unresolved Blocking Issues
1. `database.py:89-92` (security/blocking)
   - **Problem**: Potential SQL injection vulnerability
   - **Detail**: User input directly embedded in query
   - **Recommendation**: Use parameterized query or ORM
   - **Approach**: [Claude Code's proposal]

2. `auth.py:156-160` (correctness/blocking)
   - **Problem**: Token validation logic error
   - **Detail**: Expired tokens may pass validation
   - **Recommendation**: Add expiry check and verify with test cases
   - **Approach**: [Claude Code's proposal]

### Advisory
- `utils.py:45` - Review log level (maintainability/advisory)

These issues should be resolved before proceeding. What would you like to do?
- [A] Fix issues and re-review
- [B] Review current state as-is
- [C] Fix specific issues only
```

### Large Scope with Parallel Reviews

```markdown
## [Implementation Title]

[Implementation description]

### Codex Review Result
- **Status**: ok
- **Iterations**: 3/5
- **Review scope**: large (15 files, 820 lines)
- **Parallel reviews**: 4 groups, each reviewed independently

#### Per-Group Review Summary
1. **Auth layer** (3 files): ok after 1 fix
   - JWT validation logic improvement
2. **API layer** (4 files): ok after 2 fixes
   - Unified error response format
   - Added input validation
3. **DB layer** (5 files): ok after 3 fixes
   - Fixed transaction boundaries
   - Index optimization
4. **UI layer** (3 files): ok on first pass
   - Minor accessibility improvement

#### Cross-check Results
- Interface consistency: No issues
- Error handling consistency: Unified
- Authorization coverage: Complete
- API compatibility: No breaking changes

### Key Fixes
1. Proper transaction boundary setup (correctness/blocking)
2. Input validation on all API endpoints (security/blocking)
3. Unified error response format (maintainability/blocking)

### Advisory
- Some functions too long, split recommended (maintainability/advisory)

Proceed with this?
```

## Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| max_iterations | 5 | Maximum review-fix iterations |
| timeout_minutes | 20 | Codex wait timeout (20 polls × 60s) |
| parallel_max | 5 | Max parallel Subagents for large scope |
| auto_fix | true | Automatically fix blocking issues |
| poll_interval_seconds | 60 | Codex completion check interval |
| max_files_per_subagent | 5 | Files per Subagent in parallel mode |
| max_lines_per_subagent | 300 | Lines per Subagent in parallel mode |

## Integration Points

### With PLANS.md
Automatically integrated into implementation milestones:

```markdown
## Phase 1: Authentication Implementation
- [ ] Implement OAuth2 flow
- [ ] Write tests
- [ ] **[AUTO]** codex-review gate
- [ ] User confirmation

## Phase 2: API Development
- [ ] Implement REST endpoints
- [ ] Add input validation
- [ ] **[AUTO]** codex-review gate
- [ ] User confirmation
```

### With Git Hooks (Optional)
Can be integrated with pre-commit hook:

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Check if already reviewed
if [ -f .codex-review-passed ]; then
  exit 0
fi

# Trigger Claude Code to run codex-review
# (Implementation depends on project setup)
```

## Internal Processing Notes

### Codex Prompt Construction
Claude Code constructs the prompt dynamically based on:
- Changed files and line counts
- Review phase (arch/detail/cross-check)
- Previous review notes
- Project-specific context

### Result Parsing
- `--output-schema` guarantees JSON schema compliance via OpenAI structured output
- `-o` outputs result to a unique temp file (via `mktemp`) — avoids stale reads and parallel conflicts
- Schema paths use `$(git rev-parse --show-toplevel)` for location-independent execution
- Always verify `codex exec` exit code and file non-emptiness before parsing (fail-closed)
- `mktemp`, `codex exec`, verification, `jq` parse, and `rm -f` cleanup all run in the same shell block
- Extract issues by severity for fixing

### Fix Priority
1. **Security** blocking issues (highest priority)
2. **Correctness** blocking issues
3. **Performance** blocking issues (if critical)
4. **Maintainability** blocking issues
5. **Testing** blocking issues
6. Advisory issues (document only, don't fix automatically)

## Plan Review Mode

When triggered from **ExitPlanMode** (via quality-gate Step 1), Codex reviews the **plan itself** instead of code changes.

### When to Trigger

- quality-gate detects plan mode exit
- Plan file has been written to `.claude/plans/{task-name}.md`

### Plan Review Prompt

```bash
ROOT=$(git rev-parse --show-toplevel)
PLAN_REVIEW_OUT=$(mktemp "${TMPDIR:-/tmp}/codex-plan-review.XXXXXX")

codex exec --model gpt-5.4 --sandbox read-only \
  --output-schema "$ROOT/.claude/skills/codex-review/plan-review-schema.json" \
  -o "$PLAN_REVIEW_OUT" \
  "$(cat <<'EOF'
# Plan Review Request

All string fields (summary, section, problem, recommendation, suggestions) must be in Japanese.

## Plan Content
[Contents of .claude/plans/{task-name}.md]

## Review Focus Areas
- **Feasibility**: Is the plan technically feasible? Any overlooked constraints?
- **Risk assessment**: Are potential risks and issues properly identified?
- **Alternatives**: Are there better approaches?
- **Impact scope**: Is the change impact accurately assessed? Side effects?
- **Dependencies**: Are step dependencies correct? Is the order appropriate?
- **Test strategy**: Is the testing approach sufficient?

## Severity Guidelines
- **blocking**: Fatal issue in plan. Fix required → ok: false
- **advisory**: Improvement recommended but plan can proceed
EOF
)"

# Verify result (fail-closed on error)
if [ $? -ne 0 ] || [ ! -s "$PLAN_REVIEW_OUT" ]; then
  rm -f "$PLAN_REVIEW_OUT"
  echo "ERROR: codex exec failed or produced empty output" >&2
  exit 1
fi

# Parse result and cleanup
if ! jq . "$PLAN_REVIEW_OUT"; then
  rm -f "$PLAN_REVIEW_OUT"
  echo "ERROR: invalid plan review JSON" >&2
  exit 1
fi
rm -f "$PLAN_REVIEW_OUT"
```

### Plan Review Iteration

- If `ok: false`: Claude Code revises the plan, re-submits for review
- Max 3 iterations for plan review (lighter than code review)
- If plan passes, present to user for approval via ExitPlanMode

### Output to User (Plan Review)

```markdown
### Codex Plan Review Result
- **Status**: ok / needs revision
- **Iterations**: 1/3
- **Fixed items**: [List of revised items]
- **Suggestions**: [List of advisory items]
```

## Success Criteria

Review is considered successful when:
- `ok: true` received from Codex
- All blocking issues resolved
- Tests pass (if available)
- No timeouts or API errors
- Cross-check complete (for large scope)

After success, Claude Code can present to user with confidence.

## Important Reminders

1. **ALWAYS run before user confirmation** - This is mandatory
2. **Output in Japanese** - All user-facing text must be in Japanese
3. **Wait for Codex** - Do not proceed until review completes
4. **Fix blocking only** - Don't auto-fix advisory issues
5. **Document everything** - Include full review summary in user presentation
6. **Never skip** - Even if changes seem trivial, run the review
