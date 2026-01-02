# Core Rules

- Consult user before using implementation patterns not found in existing codebase
- Parallelize independent operations for efficiency
- NEVER install libraries without explicit user permission (go get, npm install, pip, etc.)
- Prefer modifying existing components over creating new ones

# Quality Gate (CRITICAL)

BEFORE asking user confirmation, git commit, or PR:
1. Run `codex-review` skill
2. Fix all blocking issues
3. Achieve ok: true status
4. Include review summary in response

# TDD

Use `test-generator` skill BEFORE implementation.
Write failing tests first, then implement to pass.
