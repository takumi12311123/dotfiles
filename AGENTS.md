# AGENTS.md

Instructions for AI coding assistants following the [Agent Skills open standard](https://agentskills.io/).

## Primary Reference

See [.claude/CLAUDE.md](.claude/CLAUDE.md) for detailed development guidelines.

## Skills

Skills are located in `.claude/skills/` and `.codex/skills/` (symlinked).

Available skills:
- `codex-review` - Automatic review gate before user confirmation
- `codex-design` - Design consultation for complex decisions
- `backend-go` - Go backend best practices
- `frontend-design` - Figma to code implementation
- `infra-terraform` - Terraform best practices
- `security-scan` - Security vulnerability scanning
- `test-generator` - TDD test generation

## Key Principles

- **TDD**: Test-Driven Development is mandatory
- **Quality Gate**: `codex-review` skill must run before user confirmation
- **Language**: Japanese for docs/reviews, English for code/commits
- **Library Policy**: Never install packages without explicit permission
