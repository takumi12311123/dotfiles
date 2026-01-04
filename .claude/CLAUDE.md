# Skills

| Skill | Auto | Description |
|-------|------|-------------|
| quality-gate | ✓ | Format/lint/build + codex-review before commit/PR |
| codex-review | - | Code review via Codex (called by quality-gate) |
| latest-docs | ✓ | Verify latest documentation before implementation |
| test-generator | - | TDD: Generate tests before implementation |
| backend-go | ✓ | Go backend best practices |
| frontend-design | ✓ | Figma to code implementation |
| infra-terraform | ✓ | Terraform best practices |
| security-scan | - | Security vulnerability scanning |
| codex-design | - | Design consultation for complex decisions |
| date-check | - | Verify current date from system |

# Core Rules

- Never install libraries without user permission
- Prefer editing existing files over creating new ones
- Consult user before using patterns not in codebase
- Use `test-generator` skill before implementation (TDD)
