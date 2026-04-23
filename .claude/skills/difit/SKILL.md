---
name: difit
description: Git diff viewer with web UI and AI prompt generation. Use when "difit" is mentioned, or when reviewing diffs, PRs, or changes with visual diff context.
metadata:
  context: difit, diff, review, git
  auto-trigger: false
---

# difit - Web-Based Git Diff Viewer

## Overview

Web-based Git diff viewer with AI prompt generation.

## Usage from Claude Code

```bash
# Basic: pipe git diff to difit
git diff | bunx difit

# Staged changes only
git diff --staged | bunx difit

# Specific commit
git show <commit-hash> | bunx difit

# Branch comparison
git diff main..HEAD | bunx difit

# Latest commit
git show HEAD | bunx difit
```

Use `run_in_background: true` to keep the difit server running while continuing work.

## Server Mode (manual)

**On main/master** (working directory changes):

```bash
DIFIT_PORT=${DIFIT_PORT:-3000}
difit --no-open --keep-alive --include-untracked --port "$DIFIT_PORT" .
```

**On feature branch** (diff against merge-base):

```bash
DIFIT_PORT=${DIFIT_PORT:-3000}
DEFAULT_REF=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || echo refs/remotes/origin/main)
MERGE_BASE=$(git merge-base "$DEFAULT_REF" HEAD 2>/dev/null || echo "HEAD")
difit --no-open --keep-alive --include-untracked --port "$DIFIT_PORT" "$MERGE_BASE"
```

## Workflow with AI Review

1. Start difit server
2. Browse diff in browser
3. Click lines to add review comments
4. Use "Copy Prompt" button to generate AI review prompt
5. Paste into Claude Code for code review

## Installation

```bash
npm install -g difit
```

## Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| Default port | 3000 | Auto-increments if busy |
| `DIFIT_PORT` env | Override default port | Set before running |
| `--keep-alive` | Server stays running | Useful for ongoing review |
| `--include-untracked` | Shows new files | Recommended |
| `--no-open` | Don't auto-open browser | For headless usage |
