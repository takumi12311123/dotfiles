# Core Rules

- Consult user before using implementation patterns not found in existing codebase
- Parallelize independent operations for efficiency
- NEVER install libraries without explicit user permission (go get, npm install, pip, etc.)
- Prefer modifying existing components over creating new ones

# Quality Gate (CRITICAL)

Run `codex-review` skill BEFORE:
- Asking "commit?" or similar confirmation
- Running git commit
- Creating PR

Applies to ANY file changes (code, config, Brewfile, etc.).
Fix all blocking issues and achieve ok: true status.

# TDD

Use `test-generator` skill BEFORE implementation.
Write failing tests first, then implement to pass.
