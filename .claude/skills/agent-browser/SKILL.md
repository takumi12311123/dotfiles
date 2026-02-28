---
name: agent-browser
description: Browser automation CLI for AI agents. Use when the user needs to interact with websites, fill forms, click buttons, take screenshots, extract data, test web apps, or automate any browser task.
metadata:
  context: browser, automation, web, testing, scraping, playwright
  auto-trigger: false
---

# agent-browser - AI Agent Browser Automation

## Overview

CLI tool for browser automation designed for AI agents. Uses a ref system (`@e1`, `@e2`) for compact element identification, reducing token usage vs CSS selectors.

## Core Workflow

```bash
# 1. Navigate
agent-browser open https://example.com

# 2. Snapshot (get element refs)
agent-browser snapshot -i     # -i = interactive elements only (RECOMMENDED)

# 3. Interact using refs
agent-browser fill @e1 "text"
agent-browser click @e2

# 4. Re-snapshot after navigation (refs are invalidated on page change)
agent-browser snapshot -i
```

**IMPORTANT:** Always re-snapshot after navigation or DOM changes. Refs are invalidated.

## Command Reference

### Navigation

```bash
agent-browser open <url>           # Navigate (auto-adds https://)
agent-browser back                 # Previous page
agent-browser forward              # Next page
agent-browser reload               # Refresh
agent-browser close                # Close browser
```

### Snapshot (Page Analysis)

```bash
agent-browser snapshot             # Full accessibility tree
agent-browser snapshot -i          # Interactive elements only (recommended)
agent-browser snapshot -i -c       # Interactive + compact
agent-browser snapshot -d 3        # Limit depth
agent-browser snapshot -s "#main"  # Scope to selector
```

### Interaction

```bash
agent-browser click @e1            # Click
agent-browser dblclick @e1         # Double-click
agent-browser fill @e1 "text"      # Clear + fill input
agent-browser type @e1 "text"      # Append text
agent-browser press Enter          # Key press
agent-browser press Control+a      # Key combination
agent-browser check @e1            # Check checkbox
agent-browser uncheck @e1          # Uncheck
agent-browser select @e1 "value"   # Select dropdown
agent-browser scroll down 500      # Scroll
agent-browser drag @e1 @e2         # Drag and drop
agent-browser upload @e1 file.pdf  # Upload file
agent-browser hover @e1            # Hover
```

### Semantic Locators (no ref needed)

```bash
agent-browser find role button click --name "Submit"
agent-browser find text "Sign In" click
agent-browser find label "Email" fill "user@test.com"
agent-browser find placeholder "Search" type "query"
agent-browser find testid "submit-btn" click
```

### Data Extraction

```bash
agent-browser get text @e1         # Text content
agent-browser get html @e1         # innerHTML
agent-browser get value @e1        # Input value
agent-browser get attr @e1 href    # Attribute
agent-browser get title            # Page title
agent-browser get url              # Current URL
agent-browser get count ".item"    # Element count
```

### Screenshots & PDF

```bash
agent-browser screenshot           # Save to temp dir
agent-browser screenshot out.png   # Save to path
agent-browser screenshot --full    # Full page
agent-browser screenshot --annotate # Numbered labels
agent-browser pdf output.pdf       # PDF export
```

### Wait

```bash
agent-browser wait @e1             # Wait for element
agent-browser wait 2000            # Wait ms
agent-browser wait --text "Done"   # Wait for text
agent-browser wait --url "**/dash" # Wait for URL
agent-browser wait --load networkidle # Wait for idle
```

### Sessions (Isolated Contexts)

```bash
agent-browser --session auth open https://app.com/login
agent-browser --session public open https://example.com
agent-browser session list         # List active sessions
```

### State Persistence

```bash
agent-browser state save auth.json  # Save cookies/storage
agent-browser state load auth.json  # Restore state
agent-browser state list            # List saved states
```

### Security

```bash
# Auth vault (credentials hidden from LLM)
echo "pass" | agent-browser auth save github \
  --url https://github.com/login \
  --username user --password-stdin
agent-browser auth login github

# Domain allowlist
agent-browser open site.com --allowed-domains "example.com,*.api.com"

# Output limit
agent-browser open site.com --max-output 50000
```

### Diff (Comparison)

```bash
agent-browser diff snapshot                    # Current vs last
agent-browser diff screenshot --baseline b.png # Pixel diff
agent-browser diff url https://v1 https://v2   # Compare URLs
```

### Tabs

```bash
agent-browser tab                  # List tabs
agent-browser tab new [url]        # New tab
agent-browser tab 2                # Switch tab
agent-browser tab close            # Close tab
```

### JavaScript

```bash
agent-browser eval "document.title"
agent-browser eval --stdin          # Piped input (for complex JS)
```

## Common Patterns

### Form Automation

```bash
agent-browser open https://app.com/form
agent-browser wait --load networkidle
agent-browser snapshot -i
agent-browser fill @e1 "user@example.com"
agent-browser fill @e2 "password"
agent-browser click @e3
agent-browser wait --load networkidle
agent-browser snapshot -i
```

### Authenticated Session (Reusable)

```bash
# Login once, save state
agent-browser open https://app.com/login
agent-browser snapshot -i
agent-browser fill @e1 "$USER"
agent-browser fill @e2 "$PASS"
agent-browser click @e3
agent-browser wait --url "**/dashboard"
agent-browser state save auth.json

# Reuse later
agent-browser state load auth.json
agent-browser open https://app.com/dashboard
```

### Full Page Capture

```bash
agent-browser open https://example.com
agent-browser wait --load networkidle
agent-browser screenshot --full page.png
agent-browser pdf output.pdf
```

## Best Practices

- Use `snapshot -i` (interactive only) to minimize tokens
- Always re-snapshot after navigation
- Use `wait --load networkidle` for async pages
- Use `--session` for parallel browser tasks
- Use auth vault instead of hardcoding credentials
- Close browser with `agent-browser close` when done
