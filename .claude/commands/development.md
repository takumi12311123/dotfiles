# Development Rules

## Core Development Principles

### 1. Code Quality Standards

- **Always check existing code patterns** before implementing new features
- **Follow the project's established conventions** for naming, structure, and style
- **Never assume libraries are available** - always verify in package.json, requirements.txt, etc.
- **Minimize code duplication** - reuse existing components and utilities

### 2. Before Starting Development

- [ ] Understand the task requirements completely
- [ ] Search the codebase for similar implementations
- [ ] Check for existing utilities or helper functions
- [ ] Verify required dependencies are installed
- [ ] Create a todo list for complex tasks using TodoWrite tool

### 3. Development Workflow

#### Step 1: Research and Planning

```bash
# Search for related code patterns
rg "pattern" --type js
# Check file structure
ls -la src/
# Read relevant files to understand context
```

#### Step 2: Implementation

- Write clean, readable code
- Follow existing code style (indentation, naming conventions)
- Add appropriate error handling
- Keep functions small and focused
- Use descriptive variable and function names

#### Step 3: Testing

```bash
# Run tests if available
npm test
# or
pytest
# or check README for test commands
```

#### Step 4: Code Quality Checks

```bash
# Always run before completing a task
npm run lint
npm run typecheck
# or equivalent commands for the project
```

## Language-Specific Rules

### JavaScript/TypeScript

- Use `const` by default, `let` when reassignment is needed
- Prefer arrow functions for callbacks
- Use async/await over promises when possible
- Always handle promise rejections

### Python

- Follow PEP 8 style guide
- Use type hints for function parameters and returns
- Prefer f-strings for string formatting
- Use context managers (with statements) for file operations

### React/Frontend

- Prefer functional components with hooks
- Keep components small and focused
- Extract reusable logic into custom hooks
- Use semantic HTML elements

## Security Best Practices

- **Never commit secrets, keys, or tokens**
- **Never log sensitive information**
- **Always validate user input**
- **Use environment variables for configuration**

## File Management Rules

- **Never create files unless absolutely necessary**
- **Always prefer editing existing files**
- **Never create documentation files unless explicitly requested**
- **Check if a similar file exists before creating a new one**

## Error Handling

- Always provide meaningful error messages
- Handle edge cases appropriately
- Use try-catch blocks for operations that might fail
- Log errors appropriately (without exposing sensitive data)

## Performance Considerations

- Avoid unnecessary re-renders in React
- Use memoization for expensive calculations
- Implement pagination for large data sets
- Optimize database queries

## Git Workflow

1. Make small, focused commits
2. Follow commit message rules (see commit.md)
3. Always review changes before committing
4. Never commit directly to main/master branch

## Code Review Checklist

Before marking a task as complete:

- [ ] Code follows project conventions
- [ ] No hardcoded values (use constants/config)
- [ ] Error handling is implemented
- [ ] Code is self-documenting (clear naming)
- [ ] No console.logs or debug statements left
- [ ] Tests pass (if applicable)
- [ ] Linting and type checking pass

## Common Commands Reference

### Finding Code

```bash
# Search for text in files
rg "searchterm"
# Find files by name
find . -name "*.js"
# List files with pattern
ls src/**/*.ts
```

### Code Quality

```bash
# JavaScript/TypeScript
npm run lint
npm run typecheck
npm run format

# Python
ruff check .
mypy .
black .
```

### Testing

```bash
# JavaScript
npm test
npm run test:watch

# Python
pytest
pytest -v
```

## Important Reminders

- **Do only what is asked** - nothing more, nothing less
- **Ask for clarification** when requirements are unclear
- **Use TodoWrite** for complex multi-step tasks
- **Run quality checks** before completing any task
- **Follow TDD** when explicitly requested
- **Check CLAUDE.md** for project-specific instructions
