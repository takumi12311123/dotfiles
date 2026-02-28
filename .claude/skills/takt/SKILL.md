---
name: takt
description: TAKT workflow orchestration for AI coding agents. Use when the user wants structured plan-implement-review cycles, batch task execution, or GitHub Issue-driven development.
metadata:
  context: workflow, orchestration, ai-agent, review, takt
  auto-trigger: false
---

# TAKT - AI Agent Workflow Orchestration

## Overview

TAKT orchestrates AI coding agents through YAML-defined workflows (Pieces).
Each Piece defines a series of Movements: plan -> implement -> review -> fix.

## Quick Reference

### Basic Usage

```bash
# Interactive mode (asks for task input)
takt

# Direct task execution
takt -t "ログイン機能を追加して"

# From GitHub Issue
takt -i 42

# Specify workflow piece
takt -w backend-mini -t "REST APIのエラーハンドリングを統一"
```

### Task Queue (Batch)

```bash
takt add "タスク1"
takt add "タスク2"
takt add -i 43
takt run              # Execute all queued tasks (parallel by concurrency setting)
```

### Piece Selection

| Piece | Use Case |
|-------|----------|
| `default-mini` | Lightweight dev (default) |
| `backend-mini` | Backend API |
| `frontend-mini` | Frontend/React |
| `default` | Full production quality review |
| `default-test-first-mini` | TDD workflow |
| `review` | Code review (5 parallel reviewers) |
| `deep-research` | Investigation/research tasks |

```bash
takt switch           # Interactive piece selection
takt -w <piece>       # One-time piece override
```

### Workflow Flow (default-mini)

```
plan -> implement -> [ai_review + supervise] -> fix -> COMPLETE
                            ^                     |
                            +---- if issues ------+
```

### Useful Commands

```bash
takt prompt           # Preview assembled prompt
takt eject <piece>    # Copy builtin piece for customization
takt metrics review   # Review quality metrics
takt clear            # Reset agent session
takt list             # Manage task branches (merge/delete/diff)
```

### CLI Flags

| Flag | Description |
|------|-------------|
| `-t, --task <text>` | Task text |
| `-i, --issue <N>` | GitHub Issue number |
| `-w, --piece <name>` | Piece selection |
| `-b, --branch <name>` | Custom branch name |
| `--auto-pr` | Auto-create PR on completion |
| `--draft-pr` | Create as draft PR |
| `--skip-git` | Skip branch/commit/push |
| `--provider <name>` | Override provider |
| `--model <name>` | Override model |
| `-q, --quiet` | Suppress AI output (CI) |
| `--pipeline` | Non-interactive CI mode |

### Config Location

- Global: `~/.takt/config.yaml`
- Project: `.takt/config.yaml` (overrides global)
- Custom pieces: `~/.takt/pieces/`
- Custom facets: `~/.takt/personas/`, `policies/`, `instructions/`, `knowledge/`

### When to Use TAKT vs Direct Claude Code

| Scenario | Tool |
|----------|------|
| Quick fix, single file | Claude Code directly |
| Structured feature implementation | `takt -t "..."` |
| Issue-driven development | `takt -i 42` |
| Batch processing multiple tasks | `takt add` -> `takt run` |
| Need multi-perspective review | `takt -w review` |
| Deep investigation | `takt -w deep-research` |
