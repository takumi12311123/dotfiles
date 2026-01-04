# AGENTS.md

Instructions for AI coding assistants following the [Agent Skills open standard](https://agentskills.io/).

## Primary Reference

See [.claude/CLAUDE.md](.claude/CLAUDE.md) for detailed development guidelines.

## Skills

Skills are located in `.claude/skills/` and `.codex/skills/` (symlinked).

Available skills:
- `quality-gate` - Auto: format/lint/build + codex-review before commit/PR
- `codex-review` - Code review via Codex (called by quality-gate)
- `codex-design` - Design consultation for complex decisions
- `backend-go` - Go backend best practices
- `frontend-design` - Figma to code implementation
- `infra-terraform` - Terraform best practices
- `security-scan` - Security vulnerability scanning
- `test-generator` - TDD test generation
- `latest-docs` - Auto: verify latest documentation before implementation
- `date-check` - Verify current date from system

## Key Principles

- **TDD**: Test-Driven Development is mandatory
- **Quality Gate**: `quality-gate` skill runs automatically before commit/PR (includes codex-review)
- **Language**: English for docs/code/commits
- **Library Policy**: Never install packages without explicit permission
