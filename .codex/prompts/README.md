# Codex Prompts Collection

This directory contains custom prompts and commands ported from Claude Code for use with Codex CLI.

## Usage

To use a prompt in Codex, use the following command:
```bash
codex --prompt ~/.codex/prompts/[prompt-name].md
```

## Available Prompts

### Development Workflow
- `development.md` - Follow development best practices and code quality standards
- `orchestrator.md` - Orchestrate complex multi-step development tasks with structured planning
- `start-server.md` - Start development server with appropriate commands

### Git & GitHub
- `commit.md` - Create a git commit with proper message formatting
- `pr.md` - Create a pull request with proper formatting and review
- `gemini.md` - Perform web search using Google Gemini CLI
- `gemini-review.md` - Use Gemini for code review and best practices

### Test-Driven Development (TDD)
- `tdd-requirements.md` - Define requirements for TDD workflow
- `tdd-testcases.md` - Generate comprehensive test cases
- `tdd-red.md` - Write failing tests (Red phase)
- `tdd-green.md` - Implement code to pass tests (Green phase)
- `tdd-refactor.md` - Refactor code while maintaining tests (Refactor phase)
- `tdd-todo.md` - Create and manage TDD task list
- `tdd-verify-complete.md` - Verify TDD cycle completion
- `tdd-load-context.md` - Load project context for TDD
- `tdd-cycle-full.sh` - Complete TDD cycle automation script

### Kairo Development Method
- `kairo-requirements.md` - Define Kairo method requirements
- `kairo-design.md` - Create technical design for Kairo implementation
- `kairo-tasks.md` - Break down Kairo implementation into tasks
- `kairo-implement.md` - Execute Kairo implementation
- `kairo-task-verify.md` - Verify Kairo task completion

### Review & Verification
- `rev-requirements.md` - Review and validate requirements
- `rev-design.md` - Review technical design decisions
- `rev-specs.md` - Review specifications and documentation
- `rev-tasks.md` - Review task breakdown and planning

### Direct Implementation
- `direct-setup.md` - Direct implementation setup
- `direct-verify.md` - Direct implementation verification

### Code Analysis
- `similarity-ts.md` - Analyze code similarity and detect duplicates using similarity-ts

## Integration with Claude Code

These prompts are automatically synchronized from `~/.claude/commands/` to maintain compatibility between Claude Code and Codex CLI environments.

## Custom Prompts

To add custom prompts:
1. Create a new `.md` file in this directory
2. Follow the existing prompt structure
3. Test with: `codex --prompt ~/.codex/prompts/your-prompt.md`

## Prompt Structure

Each prompt typically includes:
- Clear task description
- Required inputs/parameters
- Step-by-step instructions
- Expected outputs
- Error handling guidelines

## Tips

- Use prompts for repetitive tasks
- Chain prompts for complex workflows
- Customize prompts for project-specific needs
- Keep prompts versioned in your dotfiles