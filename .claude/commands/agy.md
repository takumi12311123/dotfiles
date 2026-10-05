---
allowed-tools: Bash(gemini:*)
description: Perform web search using Google Gemini CLI
argument-hint: <search-query> - what you want to search for
---

## Web Search with Gemini

Use Google Gemini CLI to search the web for information.

### Usage

```bash
gemini -p "WebSearch: {your search query here}"
```

### Examples

```bash
# Search for technical documentation
gemini -p "WebSearch: React hooks best practices 2024"

# Search for error solutions
gemini -p "WebSearch: TypeError cannot read property of undefined JavaScript"

# Search for library information
gemini -p "WebSearch: Next.js 14 new features"
```

### Your Task

Perform a web search for the provided query.

Execute the search and provide a summary of the most relevant findings.
