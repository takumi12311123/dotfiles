---
allowed-tools: Bash(ls:*), Bash(find:*), Bash(rg:*), Bash(npm:*), Bash(pytest:*), Bash(git:*)
description: Follow development best practices and code quality standards
argument-hint: [task-description] (optional - describe what you're working on)
---

## Project Context

- Project structure: !`find . -type f -name "package.json" -o -name "requirements.txt" -o -name "Cargo.toml" -o -name "go.mod" | head -5`
- Available scripts: !`if [ -f package.json ]; then cat package.json | grep -A 10 '"scripts"'; elif [ -f requirements.txt ]; then echo "Python project detected"; fi`
- Git status: !`git status --porcelain`

## Development Workflow

Follow these core principles for high-quality development:

### 1. Research Phase

- **Check existing patterns**: Search codebase for similar implementations
- **Verify dependencies**: Confirm required libraries are available
- **Understand conventions**: Follow project's established patterns

### 2. Implementation Standards

#### Code Quality

- Write clean, readable code with descriptive names
- Keep functions small and focused (single responsibility)
- Follow existing code style and conventions
- Add appropriate error handling and edge case management

#### Language-Specific Guidelines

**JavaScript/TypeScript:**

- Use `const` by default, `let` when reassignment needed
- Prefer arrow functions for callbacks
- Use async/await over promises
- Always handle promise rejections

**Python:**

- Follow PEP 8 style guide
- Use type hints for parameters and returns
- Prefer f-strings for formatting
- Use context managers for file operations

**React/Frontend:**

- Use functional components with hooks
- Keep components small and focused
- Extract reusable logic into custom hooks
- Use semantic HTML elements

### 3. Quality Assurance

Run these checks before completing any task:

```bash
# JavaScript/TypeScript projects
npm run lint && npm run typecheck && npm test

# Python projects
ruff check . && mypy . && pytest

# General code search
rg "TODO|FIXME|console\.log" --type js --type ts
```

### 4. Security & Best Practices

- **Never commit secrets, keys, or tokens**
- **Validate all user input**
- **Use environment variables for configuration**
- **Handle errors gracefully with meaningful messages**
- **Optimize for performance (avoid unnecessary re-renders, use memoization)**

### 5. File Management Rules

- **Prefer editing existing files over creating new ones**
- **Never create documentation unless explicitly requested**
- **Check for similar files before creating new ones**
- **Follow project's directory structure**

## Pre-Development Checklist

- [ ] Task requirements understood completely
- [ ] Similar implementations searched and reviewed
- [ ] Required dependencies verified as available
- [ ] Existing utilities and helpers identified
- [ ] Code patterns and conventions noted

## Completion Checklist

- [ ] Code follows project conventions
- [ ] No hardcoded values (use constants/config)
- [ ] Error handling implemented
- [ ] Code is self-documenting
- [ ] No debug statements left behind
- [ ] Tests pass (if applicable)
- [ ] Linting and type checking pass
- [ ] Git workflow followed (small, focused commits)

**Remember**: Do only what is asked, ask for clarification when unclear, and run quality checks before completion.
