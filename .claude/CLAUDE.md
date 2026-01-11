# Skills

## Auto Skills（自動実行条件）

| Skill | Trigger | Description |
|-------|---------|-------------|
| quality-gate | 実装完了後（commit/PR依頼の有無に関わらず） | Format/lint/build + codex-review |
| latest-docs | 実装開始前 | Verify latest documentation |
| backend-go | Go実装時 | Go backend best practices |
| frontend-design | Figma実装時 | Figma to code implementation |
| infra-terraform | Terraform実装時 | Terraform best practices |

## Manual Skills（ユーザー依頼時のみ）

| Skill | Description |
|-------|-------------|
| codex-review | Code review via Codex |
| test-generator | TDD: Generate tests before implementation |
| security-scan | Security vulnerability scanning |
| codex-design | Design consultation for complex decisions |
| date-check | Verify current date from system |

# Core Rules

- Never install libraries without user permission
- Prefer editing existing files over creating new ones
- Consult user before using patterns not in codebase
- Use `test-generator` skill before implementation (TDD)
- **実装完了後は必ず `quality-gate` を実行する**
