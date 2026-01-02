# Core Rules

- Consult user before using implementation patterns not found in existing codebase
- Parallelize independent operations for efficiency
- NEVER install libraries without explicit user permission (go get, npm install, pip, etc.)
- Prefer modifying existing components over creating new ones
- Follow TDD: use `test-generator` skill to write tests first, then implement

# Quality Gate

Run `codex-review` skill before ANY user confirmation, git commit, or PR creation.
