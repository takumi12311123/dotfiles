# Codex Delegation Rule

Offload to Codex CLI (via `codex-review` or `codex-design` skill) to protect Claude Code's context window.

## Auto-delegate to Codex when:
- **Design decisions**: 3+ design options exist, or introducing patterns not in codebase
- **Code review**: Before commit/PR (handled by quality-gate)
- **Debugging**: Root cause analysis of complex bugs (>3 files involved)
- **Comparison**: Evaluating trade-offs between approaches
- **Architecture**: Major refactoring or structural changes

## How to delegate:
- Use Agent tool (subagent) or Bash with `codex` CLI in `--full-auto` mode
- Always pass minimal, focused context (not entire files)
- Summarize Codex output before adding to conversation (context protection)

## Do NOT delegate:
- Simple edits, typo fixes, small changes
- Tasks where you already have full context
- When user explicitly wants Claude to handle it
