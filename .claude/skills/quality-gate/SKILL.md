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
│  2.5. Design Sanity Check (Necessity Audit)         │
│     → Compare against main: extra lines / defensive │
│       code / self-patch (throw+catch own throw)     │
│     → Reuse audit: did this diff reimplement code   │
│       that already exists in the repo?              │
│     → Surface concerns for the reviewer to evaluate │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  2.6. Context Hygiene (→ context-hygiene skill)      │
│     → Audits code comments / commit msgs / PR body   │
│       for session-only context                       │
│     → BLOCKING: rewrite, delete, or move to prr      │
│     → Rules: .claude/rules/comment-policy.md         │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  3. Run codex-review + gemini-review IN PARALLEL    │
│     → Launch both as background tasks               │
│     → Inject necessity-audit prompts                │
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
┌─────────────────────────────────────────────────────┐
│  4.7. PR Spec Digest (via pr-comprehend)            │
│     → commit trigger: light digest (Claude only)    │
│     → PR trigger:     full digest (Gemini + Codex)  │
│     → Report → .claude/pr-review/ (git-excluded)    │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  5. Behavior Verification (Runtime Smoke)           │
│     → Format/lint/unit tests verify CODE, not       │
│       FEATURE correctness. Run an actual smoke      │
│       based on what changed (E2E / dev server /     │
│       curl). Declare honestly if impossible.        │
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

## Step 2.5: Design Sanity Check (Necessity + Reuse Audit)

**The single most common quality failure: locally-optimal but globally-wasteful defensive code.**
Reviewers (including LLM reviewers) tend to optimize *the diff you handed them* rather than ask
"is this diff necessary at all?" — so we inject that question explicitly.

**The second: new code that duplicates something the repo already has.** A plan-time reuse survey
exists (`spec-agree` Step 2 / Gate A), but implementation drifts. This step re-checks the *actual*
diff, not the plan.

Run BEFORE dispatching review subagents.

### Mechanics

1. **Compute diff vs main** (or the PR base branch):
   ```bash
   BASE=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main)
   git diff --stat "$BASE"..HEAD
   ```
2. **For each touched file, fetch the main-side version** to give the reviewer a baseline:
   ```bash
   git show "$BASE":<file>   # save as context for review subagents
   ```
3. **Scan for red-flag patterns** in the diff (`git diff "$BASE"..HEAD`):
   - Newly-introduced `try`/`catch` blocks
   - New `throw` statements
   - New null/undefined guards (`if (!x)`, `x?.`, `x ?? fallback`)
   - New early returns guarding hypothetical states
   - New fallback paths / "safety nets"
4. **For every match, formulate a necessity question** and bundle it into the codex-review prompt:
   - "Does main's behavior already handle this case implicitly?"
   - "Is this catching an error introduced *by this same diff*? (self-patch anti-pattern)"
   - "Would removing this construct break a real scenario, or only a hypothetical one?"
   - "Is there an alternative implementation closer to main with fewer added lines?"
5. **Coarse heuristic**: If a single function gained **5+ defensive lines vs main**, escalate it
   to the reviewer with explicit "justify each defensive line" instruction.

### Reuse scan (mandatory, runs alongside the above)

Find what this diff **newly introduces**, then check whether the repo already had it.

```bash
# 1. Files added by this diff (awk, not `grep '^A'` — grep exits 1 when there are none)
git diff --name-status "$BASE"..HEAD | awk '$1=="A" {print $2}'

# 2. New dependencies
# Any added manifest line, not only dependency additions — read the output, don't trust the count
git diff "$BASE"..HEAD -- package.json go.mod Cargo.toml pyproject.toml requirements.txt \
  | grep -E '^\+' | grep -v '^+++' || true   # no dependency change is a normal result
```

**Symbol extraction — use the accurate path first.** For each file added or heavily modified,
get its declared symbols via `serena` (`get_symbols_overview`), or the language's own tooling.
Then `find_referencing_symbols` on each new symbol: **zero references outside its own file
is a signal it duplicates something already reachable elsewhere.**

Only when no symbol tooling is available, fall back to this **coarse heuristic** — it is
line-based and misses methods, `interface`/`enum`/`struct`, renames, and nested helpers,
so a clean result here is **not** evidence of no duplication:

```bash
git diff "$BASE"..HEAD | grep -E '^\+.*(func |function |class |const |def |type )' | head -40
```

For each new symbol name and its core keywords, search the repo excluding the new file.
Use `-F` so names containing `.` `+` `[` are matched literally, and exclude by **exact path**
(a substring filter would also drop `foo.tsx` while excluding `foo.ts`):

```bash
NEW_FILE='path/to/new_file.ts'
grep -rnF -- '<symbol-or-keyword>' --include='*.<ext>' . \
  | awk -F: -v skip="./$NEW_FILE" '$1 != skip' | head -20
```

Escalate to the reviewer when any of these hold:

| Signal | Question to raise |
|--------|-------------------|
| A new file was added | Could this have lived in an existing file? Which one, and why not? |
| A new helper matches an existing symbol's name or purpose | Why not call the existing one? |
| A new dependency was added | Does an already-installed dependency cover this? |
| A new pattern appears that no other file in the repo uses | Why diverge from the codebase's shape? |
| The diff is large relative to the stated scope | Which parts are essential vs incidental? |

If a spec exists for this branch, read its `## 既存資産の調査` section and **compare against the
actual diff**. A row that said `再利用` but produced a fresh implementation is a BLOCKING mismatch —
either the implementation drifted, or the survey was wrong. Report which.

Resolve which spec applies via the procedure in `.claude/rules/flow-gates.md`
(「共通: 成果物のキーと再入性」— the `current-task` cache must be re-validated, not trusted).
No spec on this branch → skip this comparison; the reuse scan above still runs.

### What to inject into the review prompt

When dispatching to `codex-review` / `gemini-review` in Step 3, the prompt MUST include:

```
## Necessity audit (mandatory)

The following file(s) gained defensive code (try/catch, throw, null guard, fallback, early return)
relative to <BASE>. For EACH new defensive construct, answer:

  1. Is it load-bearing? Would removing it break a real (not hypothetical) scenario?
  2. Is it a "self-patch" — i.e. catching/guarding against an error this same diff introduced?
  3. Does main's simpler shape already handle the case implicitly?
  4. Propose at least one alternative implementation closer to main. Compare line count + clarity.

If you find a self-patch or unjustified defense, classify as BLOCKING — not advisory.

main-side baseline for context:
<paste output of `git show <BASE>:<file>` for each touched file>
```

And, when the reuse scan raised any signal, append:

```
## Reuse audit (mandatory)

This diff introduces the following new files / symbols / dependencies:
<list from the reuse scan>

For EACH one, answer:

  1. Does the repo already contain something that does this? Name the file and symbol if so.
  2. If a similar thing exists but was not reused, is the divergence justified — or is this
     duplication that will now need to be maintained twice?
  3. Could this new code live in an existing file instead of a new one? Which file?
  4. Does this follow the shape of the surrounding codebase, or introduce a pattern nothing else uses?

Repo-side search results for each new symbol (searched excluding this diff):
<paste the grep output from the reuse scan>

Duplication of existing behavior is BLOCKING, not advisory.
```

This is the single most impactful change. It addresses the failure mode where reviewers say
"ok looks good, just tighten this throw" instead of "wait, why is this throw here at all?"

## Step 2.6: Context Hygiene (delegated, BLOCKING)

**Second most common AI quality failure: text that only makes sense to someone who was in the session.**
`// ご要望どおり`, `// 指摘対応`, `## 概要: 依頼された件の対応` — these read fine while the PR is open and
become noise the moment it merges. The PR is read by people who never saw the conversation.

This step is **fully delegated** to the `context-hygiene` skill. Do not re-implement the detection or the
judgment rules here — the single source of truth for *what belongs where* is
[`.claude/rules/comment-policy.md`](../../rules/comment-policy.md).

### Invocation

```
Skill(skill="context-hygiene", args="--trigger=<commit|pr|manual>")
```

The trigger decides which surfaces are audited (S1 comments / S2 commit messages / S3 PR body /
S4 PR title — the skill's Scope table is authoritative):

| trigger | S1 | S2 | S3 / S4 |
|---------|----|----|---------|
| commit | ✅ BLOCKING (working tree — the commit does not exist yet) | ✅ BLOCKING (draft message) | — |
| pr | ✅ BLOCKING | ✅ warn (existing history) | ✅ BLOCKING (pre-post draft) |
| push | ✅ BLOCKING | ✅ warn | ✅ (existing PR) |
| manual | ✅ BLOCKING | ✅ warn | PR があれば ✅ |

### Gate condition

- **BLOCKING**: proceed only when S1 has zero remaining REWRITE/MOVE/DELETE items, and (for `pr`)
  S3/S4 pass — or the user explicitly decides to ship as-is.
- Explanations classified `MOVE` are removed from the code and written to
  `.claude/pr-review/prr-draft-<branch>.md` for the user to post via `prr`. **Never auto-post.**
- A surface the skill could not audit (e.g. `gh` unreachable) is reported as 未実施 — **not** a pass.
- Skip only when there are no added comment lines and no PR surfaces in play.

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

Codex and Gemini results are **kept independently** — do not modify the existing review-schema.json.
Merge metadata is returned as a **separate object** (does not pollute review-schema.json).

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

**All user-facing output must be in Japanese.**

```markdown
## Review Results

### Codex Review
- **Status**: ok / unresolved issues remain
- **Iterations**: N/5
- **Issues**: blocking: N, advisory: M

### Gemini Review
- **Status**: ok / issues found / timeout
- **Issues**: blocking: N, advisory: M

### Cross-check
- **Agreed issues** (high confidence):
  - `file.py:42` - [Problem] (category/severity) cross-verified
- **Gemini-only issues** (reference):
  - `file.py:88` - [Problem] (category/advisory) gemini-only
```

### Iteration Behavior

- **Codex blocking issues**: Claude Code fixes → re-run both reviews
- **Gemini-only blocking**: Presented as elevated advisory, does NOT trigger fix iteration
- **Both agree blocking**: Highest priority fix
- Max 5 iterations (same as before)

## Step 4.7: PR Spec Digest (via pr-comprehend)

Review 結果評価と behavior verification の間に **仕様把握レポート** を生成する。
これは quality (何を直すか) ではなく comprehension (何が変わったか) を担う。

**目的**:
- AI が書いた PR を人間がレビューする際の認知負荷を下げる
- 「AI が指示逸脱していないか」「hallucination がないか」を機械的に検出
- レポートはローカル worktree に保存し、必要に応じて PR body に添付

### Trigger 判定

quality-gate は呼び出しコンテキストに応じて digest の重さを変える:

| quality-gate の起点 | pr-comprehend trigger | digest weight |
|---|---|---|
| commit 直前 | `commit` | light (Claude 内部要約のみ) |
| PR 作成/更新 直前 | `pr` | full (Gemini 要約 + Codex AI-risk scan) |
| ExitPlanMode | — | 実行しない (まだコードが無い) |
| user confirmation | 通常 skip | full を明示要求された場合のみ |

**Rationale**: commit ごとに Gemini/Codex を叩くとトークン浪費が大きい。commit 時は軽い記録のみ、
PR 時にフル分析する。ただし「commit も PR も自動発火」というユーザー要求は満たす。

### 実行手順

```bash
# 1. .git/info/exclude に登録 (初回のみ、以降は no-op)
GIT_DIR=$(git rev-parse --git-dir)
EXCLUDE_FILE="$GIT_DIR/info/exclude"
mkdir -p "$(dirname "$EXCLUDE_FILE")" && touch "$EXCLUDE_FILE"
grep -qxF '.claude/pr-review/' "$EXCLUDE_FILE" || echo '.claude/pr-review/' >> "$EXCLUDE_FILE"
mkdir -p .claude/pr-review

# 2. pr-comprehend skill を呼び出し
#    Trigger は quality-gate の起点から自動判定
case "$QUALITY_GATE_TRIGGER" in
  commit) TRIGGER=commit ;;
  pr)     TRIGGER=pr ;;
  *)      TRIGGER=manual ;;
esac

# Skill 呼び出し (実装: pr-comprehend/SKILL.md 参照)
# quality-gate 側では skill=pr-comprehend を Skill tool 経由で呼ぶ
```

Skill invocation (Claude が実行):
```
Skill(skill="pr-comprehend", args="--mode=author --trigger=<TRIGGER>")
```

### 結果の扱い

- **light digest (commit trigger)**:
  - 1 行報告のみユーザーに提示: `📝 commit digest: <one_liner>`
  - 詳細確認プロンプトは出さない (割り込み最小化)
  - `.claude/pr-review/local-<branch>-<hash>.md` に保存されている

- **full digest (pr trigger)**:
  - 全体像 + セクション選択プロンプトをユーザーに提示
  - ユーザーが選んだセクションを深掘り
  - `pr` skill と連携: 生成した digest のパスを PR body 末尾に `<!-- pr-comprehend: <path> -->` として追記可能

### エラー時の挙動

- `pr-comprehend` が失敗しても quality-gate は blocking しない (Step 5 へ進む)
- 失敗理由をユーザーに通知: `⚠️ PR digest 生成に失敗: <reason>`
- 後で `pr-comprehend` を手動再実行できるよう案内

### 除外条件

以下の場合 Step 4.7 はスキップ:
- diff が空
- `.claude/`, `docs/`, `*.md` のみの変更 (レビュー観点が薄い)
- ユーザーが `QUALITY_GATE_NO_DIGEST=1` を設定

## Step 5: Behavior Verification (Runtime Smoke)

**Format/lint/unit tests verify CODE correctness, NOT FEATURE correctness.**
A PR that compiles, lints, and has all unit tests green can still ship a broken feature
(e.g. a `throw` that fires on the mock path, or a `process.env.E2E` that's undefined in the
client bundle). Catch these by running the actual feature once.

### Verification matrix

Pick at least one verification step matching the largest scope of change:

| Change scope | Verification | Cost |
|---|---|---|
| **E2E spec** changed | Run the spec: `yarn e2e:integration --project=chromium` (or relevant subset) | ~1min |
| **UI / React component** | Start dev server, open the page, click through the changed flow | manual ~2min |
| **API route / Server Action** | `curl` the endpoint or run integration test | ~30s |
| **Build config / next.config** | Full `yarn build` (already in Step 2) — verify build output | included |
| **Runtime env flag (e.g. NEXT_PUBLIC_*)** | Run with the env actually set and confirm the branch fires | ~1min |
| **Pure utility (no I/O)** | Unit tests in Step 2 are sufficient | — |
| **Docs / comments only** | Skip | — |

### Self-honesty rule

If verification **cannot** be run in this environment (no browser, slow CI hardware,
needs a credential), the user MUST be told explicitly:

> "Type-check / lint / unit tests pass. Feature-level behavior was NOT verified
> because <reason>. Recommend running `<command>` before merging."

**Do NOT** claim "all checks pass" when only the code-level checks passed. This was the
exact failure mode that caused a self-patch (a throw firing on the E2E mock path) to ship
past two review rounds — the reviewers approved the code, but nobody ran it.

### When to insist

For PRs touching:
- A `getTrace` / `getPerformance` / DI-injected mock surface
- A `process.env.*` flag that gates runtime behavior
- Anything where the mock and the real path diverge in error semantics

→ Runtime smoke is **mandatory**, not optional. The class of bug that hides in these
surfaces is exactly the class that lint/type/unit cannot catch.

## Important

- NEVER skip this gate
- ALWAYS run Step 2.5 (necessity + reuse audit) and inject its findings into the review prompt
- ALWAYS run Step 2.6 by invoking the `context-hygiene` skill — it strips session-dependent text from
  code comments, commit messages, and the PR description, and drafts the moved explanations for `prr`.
  This is BLOCKING. Judgment rules live in `.claude/rules/comment-policy.md`, not here
- ALWAYS launch both reviews in parallel
- ALWAYS wait for at least Codex to complete
- Gemini failure is non-blocking (proceed with Codex only)
- Fix ALL Codex blocking issues before proceeding
- ALWAYS run Step 4.7 (PR spec digest) — light for commit, full for PR. Non-blocking on failure
- ALWAYS run Step 5 (behavior verification) before declaring done — and if you cannot,
  say so explicitly rather than implying success
- Document any skipped checks with reason
