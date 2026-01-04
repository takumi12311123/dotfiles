# Core Rules

- Consult user before using implementation patterns not found in existing codebase
- Parallelize independent operations for efficiency
- NEVER install libraries without explicit user permission (go get, npm install, pip, etc.)
- Prefer modifying existing components over creating new ones

# Plan Mode

When in plan mode:
1. Write plan to `.claude/plans/{task-name}.md`
2. Run `codex-review` skill on the plan
3. Fix blocking issues until ok: true
4. Then ExitPlanMode

# Quality Gate (CRITICAL)

Run `codex-review` skill BEFORE:
- Exiting plan mode (after writing plan to file)
- Asking "commit?" or similar confirmation
- Running git commit
- Creating PR

Applies to ANY file changes (code, config, Brewfile, plans, etc.).
Fix all blocking issues and achieve ok: true status.

# TDD

Use `test-generator` skill BEFORE implementation.
Write failing tests first, then implement to pass.
