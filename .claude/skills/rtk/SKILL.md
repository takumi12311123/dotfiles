---
name: rtk
description: RTK token optimization proxy. Transparent via PreToolUse hook. Use this skill to check token savings, troubleshoot hook issues, or manually optimize specific commands.
metadata:
  context: rtk, token, optimization, proxy
  auto-trigger: false
---

# RTK - Token Optimization Proxy

## Overview

RTK transparently intercepts Bash commands via a PreToolUse hook, filtering and compressing output to reduce LLM token consumption by 60-90%. No manual intervention needed for daily use.

## How It Works

```
Claude Code: git status
  -> Hook rewrites to: rtk git status
  -> RTK executes git status, filters output
  -> Claude receives compact output (~75% fewer tokens)
```

## Token Savings Check

```bash
rtk gain                    # Summary stats
rtk gain --graph            # ASCII graph (last 30 days)
rtk gain --history          # With recent command history
rtk gain --quota --tier 20x # Monthly quota analysis (pro/5x/20x)
rtk gain --daily            # Daily breakdown
rtk gain --all              # All breakdowns combined
rtk gain --all --format json # JSON export
```

## Project Discovery

```bash
rtk discover                # Current project stats
rtk discover --all          # All Claude Code projects
rtk discover --all --since 7 # Last 7 days
```

## Manual Usage (when needed)

```bash
# File operations
rtk ls .                    # Compact directory tree (-80%)
rtk read file.rs            # Smart file reading (-70%)
rtk read file.rs -l aggressive # Signatures only (strips bodies)
rtk grep "pattern" .        # Grouped search results (-80%)
rtk json config.json        # Structure without values

# Git operations
rtk git status              # Compact status (-75%)
rtk git log -n 10           # One-line commits
rtk git diff                # Condensed diff

# Test output
rtk cargo test              # Failures only (-90%)
rtk vitest run              # Failures only (-99%)
rtk pytest                  # Failures only (-90%)
rtk go test ./...           # NDJSON format (-90%)

# Error filtering
rtk err npm run build       # Errors/warnings only
rtk tsc                     # Grouped by file
rtk lint                    # Grouped by rule

# Docker/K8s
rtk docker ps               # Compact (-80%)
rtk kubectl get pods         # Compact (-80%)
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Hook not working | Restart Claude Code |
| Wrong rtk package | `rtk gain` should work; if not, `brew reinstall rtk` |
| Check hook status | `rtk init --show` |
| Full uninstall | `rtk init -g --uninstall` |
| Full output needed | Check `~/.local/share/rtk/tee/` for unfiltered logs |

## Configuration

```bash
# Config file location
~/.config/rtk/config.toml

# Hook files
~/.claude/hooks/rtk-rewrite.sh   # Hook script
~/.claude/RTK.md                 # Slim reference
~/.local/share/rtk/history.db    # Tracking DB
```

## Global Flags

```bash
rtk -u <cmd>    # Ultra-compact mode (extra savings)
rtk -v <cmd>    # Verbose output
```
