---
name: difit
description: Git diff viewer with web UI and AI prompt generation. Use when "difit" is mentioned, or when reviewing diffs, PRs, or changes with visual diff context.
metadata:
  context: difit, diff, review, git, cmux
  auto-trigger: false
---

# difit - Web-Based Git Diff Viewer

## Overview

Web-based Git diff viewer with AI prompt generation. Integrated into the `dev` command workflow with cmux browser split.

## Primary Usage: dev command

> `dev` は cmux ターミナル内でのみ実行可能です。通常のシェルから実行すると終了します。

```bash
dev                    # Launch cmux split: difit (left) + claude (right)
dev /path/to/project   # Specify project directory
```

This automatically:
1. Starts difit server (auto port detection from 3000)
2. Opens cmux browser split showing diff
3. Launches Claude Code in the right pane

### Diff Mode (automatic)

| Branch | Behavior |
|--------|----------|
| `main` / `master` | Shows all working directory changes |
| Feature branch | Diffs against merge-base with default branch |

## Standalone Usage from Claude Code

When you need to view diffs outside the `dev` workflow:

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

Choose one based on your branch. Run in background to keep terminal usable.

**On main/master** (working directory changes):

```bash
DIFIT_PORT=${DIFIT_PORT:-3000}
difit --no-open --keep-alive --include-untracked --port "$DIFIT_PORT" . &
cmux browser open-split "http://localhost:${DIFIT_PORT}"  # if inside cmux
```

**On feature branch** (diff against merge-base):

```bash
DIFIT_PORT=${DIFIT_PORT:-3000}
DEFAULT_REF=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || echo refs/remotes/origin/main)
MERGE_BASE=$(git merge-base "$DEFAULT_REF" HEAD 2>/dev/null || echo "HEAD")
difit --no-open --keep-alive --include-untracked --port "$DIFIT_PORT" "$MERGE_BASE" &
cmux browser open-split "http://localhost:${DIFIT_PORT}"  # if inside cmux
```

## Workflow with AI Review

1. `dev` opens difit + claude split
2. Browse diff in difit (left pane)
3. Click lines to add review comments
4. Use "Copy Prompt" button to generate AI review prompt
5. Paste into Claude (right pane) for code review

## Installation

```bash
npm install -g difit
```

## Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| Default port | 3000 | Auto-increments if busy |
| `DIFIT_PORT` env | Override default port | Set before running `dev` |
| `--keep-alive` | Server stays running | Used in dev workflow |
| `--include-untracked` | Shows new files | Enabled by default in dev |
| `--no-open` | Don't auto-open browser | cmux handles browser |
