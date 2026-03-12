---
name: gemini-review
description: |
  Gemini-based code review gate. Runs in parallel with codex-review via quality-gate.
  Uses Gemini CLI in non-interactive mode for independent second-opinion review.
metadata:
  auto-trigger: false
---

# Gemini Automatic Review Gate

## Purpose

**Independent second-opinion review**: Runs in parallel with codex-review to provide a different model perspective.
Cross-checking both results reduces missed issues and increases confidence.

## Execution Flow

### Step 1: Execute Gemini Review (Self-Contained)

**Critical: Gemini runs in non-interactive mode with -p flag**

**Important: Sensitive file exclusion**
Files matching the following patterns must NOT be sent to Gemini:
- `.env`, `.env.*` — environment variables
- `*.key`, `*.pem` — keys/certificates
- `*credentials*`, `*secret*` — authentication data
- `*.tfvars`, `*.tfstate` — Terraform sensitive data

If files are excluded, notify user:
`Warning: The following files were excluded from Gemini review due to sensitivity: [file list]`

```bash
ROOT=$(git rev-parse --show-toplevel)
REVIEW_OUT=$(mktemp "${TMPDIR:-/tmp}/gemini-review.XXXXXX")
FALLBACK_JSON='{"ok": false, "phase": "detail", "summary": "Gemini review failed", "issues": [], "notes_for_next_review": ""}'
SKIPPED_JSON='{"ok": true, "phase": "detail", "summary": "All files sensitive - Gemini review skipped", "issues": [], "notes_for_next_review": ""}'

# Build file lists (safe vs excluded)
EXCLUDE_PATTERNS='\.env|\.key|\.pem|credentials|secret|\.tfvars|\.tfstate'
ALL_FILES=$(git diff HEAD --name-only -z | tr '\0' '\n')
SAFE_FILES=$(echo "$ALL_FILES" | grep -vE "$EXCLUDE_PATTERNS" || true)
EXCLUDED_FILES=$(echo "$ALL_FILES" | grep -E "$EXCLUDE_PATTERNS" || true)

# Notify about excluded files (caller should display this to user)
if [ -n "$EXCLUDED_FILES" ]; then
  echo "EXCLUDED_FILES=$EXCLUDED_FILES" >&2
fi

# All files excluded → skip (not failure)
if [ -z "$SAFE_FILES" ]; then
  echo "$SKIPPED_JSON"
  rm -f "$REVIEW_OUT"
  exit 0
fi

# Build safe diff from filtered file list (-- prevents flag interpretation)
SAFE_DIFF=$(echo "$SAFE_FILES" | while IFS= read -r file; do git diff HEAD -- "$file"; done)

# macOS-compatible timeout: use array to avoid zsh word-splitting issues
if command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(gtimeout 300)
elif command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout 300)
else
  # No timeout available — run without timeout
  TIMEOUT_CMD=()
fi

"${TIMEOUT_CMD[@]}" gemini -m gemini-3-pro-preview -o json \
  -p "$(cat <<EOF
# Code Review Request

You are a code reviewer. Review the following changes strictly.
All output must be in Japanese.

## Changed Files
$(echo "$SAFE_FILES" | head -50)

## Diff
$SAFE_DIFF

## Review Focus Areas
- **Correctness**: Logic errors, edge cases, null/undefined handling
- **Security**: Vulnerabilities, input validation, authentication/authorization
- **Performance**: Bottlenecks, inefficient algorithms, resource leaks
- **Maintainability**: Readability, consistency with existing patterns
- **Testing**: Test coverage, test quality, missing test cases

## Output Format

Output exactly in the following JSON format (no code blocks, JSON only):

## Severity Definitions
- "blocking": Must be fixed. Any blocking issue → ok: false
- "advisory": Improvement recommended. Does not affect ok status

## Category Values
"correctness", "security", "perf", "maintainability", "testing", "style"

## Example Output
{
  "ok": true,
  "phase": "detail",
  "summary": "No issues found in changes",
  "issues": [],
  "notes_for_next_review": ""
}

## Example with issues
{
  "ok": false,
  "phase": "detail",
  "summary": "Security issues found",
  "issues": [
    {
      "severity": "blocking",
      "category": "security",
      "file": "src/auth.py",
      "lines": "42-45",
      "problem": "SQL injection vulnerability",
      "recommendation": "Use parameterized queries"
    }
  ],
  "notes_for_next_review": "Auth-related code needs re-review"
}

If no blocking issues, set ok: true.
EOF
)" > "$REVIEW_OUT" 2>/dev/null

EXIT_CODE=$?

# Validate: check exit code, timeout, and non-empty output
if [ $EXIT_CODE -ne 0 ] || [ ! -s "$REVIEW_OUT" ]; then
  echo "$FALLBACK_JSON"
  rm -f "$REVIEW_OUT"
  exit 0
fi

# Parse JSON from output (extract review JSON)
# Gemini CLI -o json returns: {"session_id": ..., "response": "<json-string>", "stats": ...}
PARSED=$(python3 -c "
import json, sys, re

FALLBACK = '{\"ok\": false, \"phase\": \"detail\", \"summary\": \"Failed to parse Gemini output JSON\", \"issues\": [], \"notes_for_next_review\": \"\"}'

try:
    data = json.load(open('$REVIEW_OUT'))
except Exception:
    print(FALLBACK); sys.exit(0)

def extract_json(text):
    \"\"\"Extract review JSON from text (may contain markdown code blocks).\"\"\"
    match = re.search(r'\x60\x60\x60json?\s*(\{.*?\})\s*\x60\x60\x60', text, re.DOTALL)
    if match:
        return json.loads(match.group(1))
    return json.loads(text.strip())

try:
    if isinstance(data, dict) and 'response' in data:
        # CLI v0.32+ format: {session_id, response (string), stats}
        resp = data['response']
        parsed = extract_json(resp) if isinstance(resp, str) else resp
        assert 'ok' in parsed and 'issues' in parsed
        print(json.dumps(parsed))
    elif isinstance(data, dict) and 'ok' in data:
        # Direct JSON output
        print(json.dumps(data))
    elif isinstance(data, list):
        # Legacy format: list of response objects
        for item in reversed(data):
            try:
                text = item['response']['candidates'][0]['content']['parts'][0]['text']
                parsed = extract_json(text)
                assert 'ok' in parsed and 'issues' in parsed
                print(json.dumps(parsed)); break
            except: continue
        else:
            print(FALLBACK)
    else:
        print(FALLBACK)
except Exception:
    print(FALLBACK)
" 2>/dev/null) || PARSED="$FALLBACK_JSON"

echo "$PARSED"
rm -f "$REVIEW_OUT"
```

**Important: Wait for Gemini completion**

- Gemini is typically faster than Codex (good at large context processing)
- macOS-compatible timeout (gtimeout/timeout fallback) limits to 5 minutes max
- Progress log: `[Gemini review] Running (max 5min)...`
- On timeout: Return fallback JSON, proceed with Codex result only

### Step 2: Result Handling

Gemini review does NOT iterate independently. Results are passed back to quality-gate for merged evaluation.

Results always follow this schema (same as codex-review/review-schema.json):
```json
{
  "ok": true,
  "phase": "detail",
  "summary": "...",
  "issues": [],
  "notes_for_next_review": ""
}
```

## Error Handling

**All error cases return fallback JSON.** This guarantees quality-gate can always process results mechanically.

### Gemini Timeout (exit code 124)
- Return fallback JSON
- Log: `Warning: Gemini review timed out (exceeded 5min)`

### Gemini API Failure (non-zero exit)
- Return fallback JSON
- Log: `Warning: Gemini API call failed`

### Empty Output
- Return fallback JSON
- Log: `Warning: Gemini returned empty output`

### JSON Parse Failure
- Return fallback JSON
- Log: `Warning: Failed to parse Gemini output as JSON`

## Output Format to User

**All user-facing output must be in Japanese.**

Gemini review results are shown alongside Codex results in quality-gate output:

```markdown
### Gemini Review Result
- **Status**: ok / issues found / failed
- **Issues**: blocking: N, advisory: M

#### Gemini-only Issues (not found by Codex)
- `file.py:42` - [Problem description] (category/severity)
```

## Important Reminders

1. **Parallel execution**: Always run in parallel with codex-review
2. **Sensitive file exclusion**: Always exclude `.env`, keys, credentials before sending
3. **Fallback guarantee**: All error cases return valid JSON
4. **Non-interactive**: Run with `-p` flag, limit with `timeout 300`
5. **Output in Japanese**: All user-facing text in Japanese
6. **Merge decision**: Final decision is made by quality-gate
