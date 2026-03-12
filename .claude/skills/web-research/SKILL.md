---
name: web-research
description: |
  Delegated web research: Gemini does primary search, Codex cross-verifies.
  Claude Code only merges and presents results (zero context window consumption).
metadata:
  context: research, documentation, library, api, investigation
  auto-trigger: false
---

# Web Research (Gemini + Codex)

## Purpose

**Dual-source research**: Gemini does primary investigation (web search), Codex cross-verifies.
Claude Code only merges and presents results — zero context window consumption.

## When to Use

- Library/framework investigation
- API specification verification
- Best practices research
- Error root cause investigation
- Technology selection research
- Latest version/changelog verification

## Research Result Schema

Gemini and Codex return results in the same JSON schema.

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

### Step 1: Gemini Primary Research (Background)

Execute primary investigation via Gemini CLI web search.
**Claude Code must NOT use WebSearch/WebFetch.**

Launch as background Agent task with Bash:

```bash
GEMINI_OUT=$(mktemp "${TMPDIR:-/tmp}/gemini-research.XXXXXX")
FALLBACK='{"verification_status":"error","freshness":"uncertain","freshness_detail":"Gemini research failed","confirmed_facts":[],"contradictions":[],"missing_info":[],"additional_findings":[],"recommended_sources":[]}'

# macOS-compatible timeout (array for zsh compatibility)
if command -v gtimeout >/dev/null 2>&1; then TIMEOUT_CMD=(gtimeout 300)
elif command -v timeout >/dev/null 2>&1; then TIMEOUT_CMD=(timeout 300)
else TIMEOUT_CMD=(); fi

"${TIMEOUT_CMD[@]}" gemini -m gemini-3-pro-preview -o json \
  -p "$(cat <<PROMPT
# Web Research: Primary Investigation

All output must be in Japanese.

Important: You are running as Gemini CLI. Web search is enabled by default.
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

Output exactly in the following JSON format (no code blocks, JSON only).

## Example Output
{
  "verification_status": "confirmed",
  "freshness": "current",
  "freshness_detail": "Matches latest information as of March 2026",
  "confirmed_facts": ["Fact 1", "Fact 2"],
  "contradictions": [],
  "missing_info": [],
  "additional_findings": ["Additional info from web search"],
  "recommended_sources": ["https://example.com/docs"]
}
PROMPT
)" > "$GEMINI_OUT" 2>/dev/null

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || [ ! -s "$GEMINI_OUT" ]; then
  echo "$FALLBACK"
  rm -f "$GEMINI_OUT"
  exit 0
fi

# Parse Gemini JSON output
# Gemini CLI -o json returns: {"session_id": ..., "response": "<json-string>", "stats": ...}
PARSED=$(python3 -c "
import json, sys, re

FALLBACK = '{\"verification_status\":\"error\",\"freshness\":\"uncertain\",\"freshness_detail\":\"Failed to parse Gemini output\",\"confirmed_facts\":[],\"contradictions\":[],\"missing_info\":[],\"additional_findings\":[],\"recommended_sources\":[]}'

try:
    data = json.load(open('$GEMINI_OUT'))
except Exception:
    print(FALLBACK); sys.exit(0)

def extract_json(text):
    match = re.search(r'\x60\x60\x60json?\s*(\{.*?\})\s*\x60\x60\x60', text, re.DOTALL)
    if match:
        return json.loads(match.group(1))
    return json.loads(text.strip())

try:
    if isinstance(data, dict) and 'response' in data:
        resp = data['response']
        parsed = extract_json(resp) if isinstance(resp, str) else resp
        assert 'verification_status' in parsed
        print(json.dumps(parsed))
    elif isinstance(data, dict) and 'verification_status' in data:
        print(json.dumps(data))
    elif isinstance(data, list):
        for item in reversed(data):
            try:
                text = item['response']['candidates'][0]['content']['parts'][0]['text']
                parsed = extract_json(text)
                assert 'verification_status' in parsed
                print(json.dumps(parsed)); break
            except: continue
        else:
            print(FALLBACK)
    else:
        print(FALLBACK)
except Exception:
    print(FALLBACK)
" 2>/dev/null) || PARSED="$FALLBACK"

echo "$PARSED"
rm -f "$GEMINI_OUT"
```

### Step 2: Codex Cross-Verification (Background)

Receives Gemini's results and independently verifies.
**Runs in parallel with Step 1. If Gemini returns first, pass its results to Codex.**
**If Gemini hasn't returned yet, have Codex investigate independently with topic only.**

Launch as background Agent task with Bash:

```bash
ROOT=$(git rev-parse --show-toplevel)
CODEX_OUT=$(mktemp "${TMPDIR:-/tmp}/codex-research.XXXXXX")
FALLBACK='{"verification_status":"error","freshness":"uncertain","freshness_detail":"Codex verification failed","confirmed_facts":[],"contradictions":[],"missing_info":[],"additional_findings":[],"recommended_sources":[]}'

# macOS-compatible timeout (array for zsh compatibility)
if command -v gtimeout >/dev/null 2>&1; then TIMEOUT_CMD=(gtimeout 300)
elif command -v timeout >/dev/null 2>&1; then TIMEOUT_CMD=(timeout 300)
else TIMEOUT_CMD=(); fi

"${TIMEOUT_CMD[@]}" codex exec --model gpt-5.4 --sandbox read-only \
  --output-schema "$ROOT/.claude/skills/web-research/verification-schema.json" \
  -o "$CODEX_OUT" \
  "$(cat <<PROMPT
# Web Research Cross-Verification

All output must be in Japanese.

## Research Topic
[Insert user's research query here]

## Gemini's Research Results (if available)
[Insert Gemini results here. If not yet returned: "Gemini results unavailable - investigate independently"]

## Your Task

1. Independently verify the above topic using your own knowledge
2. If Gemini results are available, verify their accuracy
3. Check from the following perspectives:
   - Is the information current? (Any outdated or deprecated content?)
   - Are the facts accurate?
   - Is important information missing?
   - Are there better alternatives or approaches?
PROMPT
)"

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

Merge Gemini/Codex results and determine confidence level.
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


def merge_research(gemini_result, codex_result):
    """Merge Gemini (primary) and Codex (verification) results, determine confidence."""
    gemini = normalize_result(gemini_result)
    codex = normalize_result(codex_result)

    sources_available = sum(1 for r in [gemini, codex]
                           if r["verification_status"] != "error")

    freshness_votes = [
        r["freshness"] for r in [gemini, codex]
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
        gemini.get("contradictions", []) +
        codex.get("contradictions", [])
    )

    if sources_available == 0:
        confidence = "unverified"
    elif sources_available == 1:
        confidence = "low"
    elif all_contradictions:
        confidence = "low"
    elif all(r["verification_status"] == "confirmed"
             for r in [gemini, codex]
             if r["verification_status"] != "error"):
        confidence = "high"
    else:
        confidence = "medium"

    return {
        "confidence": confidence,
        "sources_available": sources_available,
        "freshness_assessment": freshness_assessment,
        "contradictions": all_contradictions,
        "gemini_detail": gemini.get("freshness_detail", ""),
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

### Primary Research Results (Gemini Web Search)
[Gemini's primary research results]

### Cross-check Results (Codex Verification)

#### Agreed Information (high confidence)
- [Facts both sources agree on]

#### Additional Information
- **Gemini additional**: [Information only Gemini found (web search based)]
- **Codex additional**: [Information only Codex noted]

#### Contradictions (attention required)
| Item | Gemini | Codex |
|------|--------|-------|
| [Item] | [Claim] | [Claim] |

#### Freshness Check
- **Gemini assessment**: [Detail]
- **Codex assessment**: [Detail]

### Recommended Documentation
- [URL1] (source: Gemini/Codex)
- [URL2] (source: Gemini/Codex)

### Notes
- [Notes about contradictions if any]
- [Items that may be outdated]
```

## Error Handling

**All error cases return fallback JSON.**

### Both Succeed (Gemini and Codex)
- Normal merge processing, confidence based on agreement level

### One Succeeds (Gemini or Codex only)
- Use successful source's results
- Set confidence to "medium"
- Note which source failed

### Both Fail
- Set confidence to "unverified"
- Recommend manual verification: `Warning: External research failed. Manual verification recommended.`

## Integration with latest-docs

When called from `latest-docs` skill:
- Add version/deprecation keywords to Gemini search query
- Return results in `latest-docs` format

## Important Reminders

1. **Claude Code must NOT use WebSearch/WebFetch** - Delegate everything to Gemini+Codex
2. **Parallel execution**: Always run Gemini and Codex in background in parallel
3. **Gemini = primary research**: Get latest information via web search
4. **Codex = verification**: Verify Gemini's results with knowledge base
5. **Don't hide contradictions**: Present all contradictions for user to judge
6. **Fallback guarantee**: All error cases return valid JSON
7. **Output in Japanese**: All user-facing text in Japanese
