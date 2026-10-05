---
name: web-research
description: |
  Delegated web research: agy does primary search, Codex cross-verifies.
  Claude Code only merges and presents results (zero context window consumption).
metadata:
  context: research, documentation, library, api, investigation
  auto-trigger: false
---

# Web Research (agy + Codex)

## Purpose

**Dual-source research**: agy does primary investigation (web search), Codex cross-verifies.
Claude Code only merges and presents results — zero context window consumption.

## When to Use

- Library/framework investigation
- API specification verification
- Best practices research
- Error root cause investigation
- Technology selection research
- Latest version/changelog verification

## Research Result Schema

agy and Codex return results in the same JSON schema.

### Field Definitions

| Field | Type | Values |
|-------|------|--------|
| verification_status | string | `"confirmed"`, `"partially_confirmed"`, `"contradicted"`, `"error"` |
| freshness | string | `"current"`, `"outdated"`, `"uncertain"` |
| freshness_detail | string | Free-form description (Japanese) |
| confirmed_facts | string[] | List of confirmed facts |
| contradictions | object[] | `{claim, correction, source}` |
| missing_info | string[] | Important missing information |
| additional_findings | string[] | Additional discovered information |
| recommended_sources | string[] | Recommended documentation URLs |

### Example (valid JSON)

```json
{
  "verification_status": "partially_confirmed",
  "freshness": "current",
  "freshness_detail": "Confirmed match with latest official documentation",
  "confirmed_facts": ["React 19 released as stable"],
  "contradictions": [
    {
      "claim": "useEffect is deprecated",
      "correction": "useEffect is not deprecated; use hook is recommended for specific cases",
      "source": "https://react.dev/reference/react/use"
    }
  ],
  "missing_info": ["No mention of Server Components"],
  "additional_findings": ["React Compiler experimentally available"],
  "recommended_sources": ["https://react.dev/blog"]
}
```

### Error Fallback (valid JSON)

```json
{
  "verification_status": "error",
  "freshness": "uncertain",
  "freshness_detail": "Verification failed",
  "confirmed_facts": [],
  "contradictions": [],
  "missing_info": [],
  "additional_findings": [],
  "recommended_sources": []
}
```

## Execution Flow

### Step 1: agy Primary Research (Background)

Execute primary investigation via Antigravity CLI (`agy`) web search.
**Claude Code must NOT use WebSearch/WebFetch.**

Launch as background Agent task with Bash (one command; the script runs agy in an empty
temp directory and applies agy's own `--print-timeout`):

```bash
~/.claude/skills/agy-review/scripts/agy-exec.sh --timeout 300s \
  --schema ~/.claude/skills/web-research/verification-schema.json \
  --prompt "$(cat <<'PROMPT'
# Web Research: Primary Investigation

All output must be in Japanese.

You MUST perform independent web searches to get the latest information.

## Research Topic
[Insert user's research query here]

## Your Task

1. Collect the latest official information via web search on the above topic
2. Focus on:
   - Latest version/release information
   - Official documentation URLs
   - Best practices/recommended patterns
   - Deprecated features/breaking changes
3. Note the freshness of information (when it was published)
4. Put the URLs you relied on in recommended_sources
PROMPT
)"
```

The command prints one envelope line: `{"status": ..., "detail": ..., "result": ...}`.

- `status: "completed"` → `result` is the research JSON (Research Result Schema above)
- any other status (`timeout` / `quota` / `error`) → agy did not research. Use the Error Fallback
  JSON as agy's result for Step 3 and tell the user "agy research unavailable (<status>: <detail>)".
  Do not present the fallback as a research result

### Step 2: Codex Cross-Verification (Background)

Receives agy's results and independently verifies.
**Runs in parallel with Step 1. If agy returns first, pass its results to Codex.**
**If agy hasn't returned yet, have Codex investigate independently with topic only.**

Launch as background Agent task with Bash:

```bash
ROOT=$(git rev-parse --show-toplevel)
CODEX_OUT=$(mktemp "${TMPDIR:-/tmp}/codex-research.XXXXXX")
FALLBACK='{"verification_status":"error","freshness":"uncertain","freshness_detail":"Codex verification failed","confirmed_facts":[],"contradictions":[],"missing_info":[],"additional_findings":[],"recommended_sources":[]}'

# macOS-compatible timeout (array for zsh compatibility).
# `perl alarm` shim ensures a hard cap even when coreutils is not installed.
if command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(gtimeout 300)
elif command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout 300)
elif command -v perl >/dev/null 2>&1; then
  TIMEOUT_CMD=(perl -e 'my $t=shift; my $pid=fork; if(!defined $pid){die "fork: $!"} if($pid==0){exec @ARGV; exit 127} $SIG{ALRM}=sub{kill "TERM",$pid; sleep 2; kill "KILL",$pid; exit 124}; alarm $t; waitpid $pid,0; my $st=$?; exit($st & 127 ? 128 + ($st & 127) : $st >> 8)' 300)
else
  TIMEOUT_CMD=()
fi

# `< /dev/null` and `--ephemeral` are mandatory:
# - codex exec probes stdin even when prompt is passed as arg → would hang on inherited pipes
# - --ephemeral avoids ~/.codex/history.jsonl contention with parallel codex invocations
"${TIMEOUT_CMD[@]}" codex exec --model gpt-5.6-terra --sandbox read-only --ephemeral \
  --output-schema "$ROOT/.claude/skills/web-research/verification-schema.json" \
  -o "$CODEX_OUT" \
  "$(cat <<PROMPT
# Web Research Cross-Verification

All output must be in Japanese.

## Research Topic
[Insert user's research query here]

## agy's Research Results (if available)
[Insert agy results here. If not yet returned: "agy results unavailable - investigate independently"]

## Your Task

1. Independently verify the above topic using your own knowledge
2. If agy results are available, verify their accuracy
3. Check from the following perspectives:
   - Is the information current? (Any outdated or deprecated content?)
   - Are the facts accurate?
   - Is important information missing?
   - Are there better alternatives or approaches?
PROMPT
)" < /dev/null

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || [ ! -s "$CODEX_OUT" ]; then
  echo "$FALLBACK"
else
  if python3 -c "import json; json.load(open('$CODEX_OUT'))" 2>/dev/null; then
    cat "$CODEX_OUT"
  else
    echo "$FALLBACK"
  fi
fi
rm -f "$CODEX_OUT"
```

### Step 3: Merge & Analyze Results

Merge agy/Codex results and determine confidence level.
**Claude Code receives results here for the first time (summary only).**

```python
def normalize_result(result):
    """Normalize None, error, or incomplete JSON to safe defaults."""
    FALLBACK = {
        "verification_status": "error",
        "freshness": "uncertain",
        "freshness_detail": "Failed to retrieve results",
        "confirmed_facts": [],
        "contradictions": [],
        "missing_info": [],
        "additional_findings": [],
        "recommended_sources": []
    }

    if result is None or not isinstance(result, dict):
        return dict(FALLBACK)

    normalized = {}

    VALID_STATUS = {"confirmed", "partially_confirmed", "contradicted", "error"}
    VALID_FRESHNESS = {"current", "outdated", "uncertain"}

    status = result.get("verification_status", "error")
    normalized["verification_status"] = status if status in VALID_STATUS else "error"

    freshness = result.get("freshness", "uncertain")
    normalized["freshness"] = freshness if freshness in VALID_FRESHNESS else "uncertain"

    detail = result.get("freshness_detail", "")
    normalized["freshness_detail"] = str(detail) if detail else ""

    for key in ["confirmed_facts", "missing_info", "additional_findings", "recommended_sources"]:
        val = result.get(key, [])
        if not isinstance(val, list):
            normalized[key] = []
        else:
            normalized[key] = [str(item) for item in val if isinstance(item, str)]

    raw_contradictions = result.get("contradictions", [])
    if not isinstance(raw_contradictions, list):
        normalized["contradictions"] = []
    else:
        valid_contradictions = []
        for item in raw_contradictions:
            if isinstance(item, dict) and all(
                k in item and isinstance(item[k], str)
                for k in ("claim", "correction", "source")
            ):
                valid_contradictions.append({
                    "claim": item["claim"],
                    "correction": item["correction"],
                    "source": item["source"]
                })
        normalized["contradictions"] = valid_contradictions

    return normalized


def merge_research(agy_result, codex_result):
    """Merge agy (primary) and Codex (verification) results, determine confidence."""
    agy = normalize_result(agy_result)
    codex = normalize_result(codex_result)

    sources_available = sum(1 for r in [agy, codex]
                           if r["verification_status"] != "error")

    freshness_votes = [
        r["freshness"] for r in [agy, codex]
        if r["verification_status"] != "error"
    ]

    if not freshness_votes:
        freshness_assessment = "uncertain"
    elif "outdated" in freshness_votes:
        freshness_assessment = "outdated"
    elif all(f == "current" for f in freshness_votes):
        freshness_assessment = "current"
    else:
        freshness_assessment = "uncertain"

    all_contradictions = (
        agy.get("contradictions", []) +
        codex.get("contradictions", [])
    )

    if sources_available == 0:
        confidence = "unverified"
    elif sources_available == 1:
        confidence = "low"
    elif all_contradictions:
        confidence = "low"
    elif all(r["verification_status"] == "confirmed"
             for r in [agy, codex]
             if r["verification_status"] != "error"):
        confidence = "high"
    else:
        confidence = "medium"

    return {
        "confidence": confidence,
        "sources_available": sources_available,
        "freshness_assessment": freshness_assessment,
        "contradictions": all_contradictions,
        "agy_detail": agy.get("freshness_detail", ""),
        "codex_detail": codex.get("freshness_detail", "")
    }
```

### Step 4: Present Results to User

## Output Format

**All user-facing output must be in Japanese.**

```markdown
## Research Results: [Topic]

### Confidence Assessment
- **Overall confidence**: High (2 sources confirmed) / Medium (1 source or partial match) / Low (contradictions) / Unverified (external research failed)
- **Verification sources**: N/2
- **Information freshness**: Current / Potentially outdated / Unknown

### Primary Research Results (agy Web Search)
[agy's primary research results]

### Cross-check Results (Codex Verification)

#### Agreed Information (high confidence)
- [Facts both sources agree on]

#### Additional Information
- **agy additional**: [Information only agy found (web search based)]
- **Codex additional**: [Information only Codex noted]

#### Contradictions (attention required)
| Item | agy | Codex |
|------|--------|-------|
| [Item] | [Claim] | [Claim] |

#### Freshness Check
- **agy assessment**: [Detail]
- **Codex assessment**: [Detail]

### Recommended Documentation
- [URL1] (source: agy/Codex)
- [URL2] (source: agy/Codex)

### Notes
- [Notes about contradictions if any]
- [Items that may be outdated]
```

## Error Handling

**All error cases return fallback JSON.**

### Both Succeed (agy and Codex)
- Normal merge processing, confidence based on agreement level

### One Succeeds (agy or Codex only)
- Use successful source's results
- Set confidence to "medium"
- Note which source failed

### Both Fail
- Set confidence to "unverified"
- Recommend manual verification: `Warning: External research failed. Manual verification recommended.`

## Integration with latest-docs

When called from `latest-docs` skill:
- Add version/deprecation keywords to agy search query
- Return results in `latest-docs` format

## Important Reminders

1. **Claude Code must NOT use WebSearch/WebFetch** - Delegate everything to agy+Codex
2. **Parallel execution**: Always run agy and Codex in background in parallel
3. **agy = primary research**: Get latest information via web search
4. **Codex = verification**: Verify agy's results with knowledge base
5. **Don't hide contradictions**: Present all contradictions for user to judge
6. **Fallback guarantee**: All error cases return valid JSON
7. **Output in Japanese**: All user-facing text in Japanese
