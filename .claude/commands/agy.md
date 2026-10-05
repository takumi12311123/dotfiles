---
allowed-tools: Bash(~/.claude/skills/agy-review/scripts/agy-exec.sh:*)
description: Perform web search using Antigravity CLI (agy)
argument-hint: <search-query> - what you want to search for
---

## Web Search with agy

Use Antigravity CLI (`agy`) in non-interactive mode to search the web for information.

### Usage

```bash
~/.claude/skills/agy-review/scripts/agy-exec.sh --timeout 180s \
  --prompt "Use web search. {your search query here}. Cite the source URLs you relied on."
```

The script runs agy in an empty temp directory (it has no local files to read) and prints one
line of JSON: `{"status": ..., "detail": ..., "result": ...}`.

- `status: "completed"` → `result` is the answer
- anything else (`timeout` / `quota` / `error`) → the search did not run to completion.
  Report the status and `detail` instead of answering from memory

### Examples

```bash
# Search for technical documentation
~/.claude/skills/agy-review/scripts/agy-exec.sh --timeout 180s \
  --prompt "Use web search. React hooks best practices. Cite the source URLs you relied on."

# Search for error solutions
~/.claude/skills/agy-review/scripts/agy-exec.sh --timeout 180s \
  --prompt "Use web search. TypeError cannot read property of undefined JavaScript. Cite the source URLs you relied on."
```

### Your Task

Perform a web search for the provided query.

Execute the search and provide a summary of the most relevant findings.
