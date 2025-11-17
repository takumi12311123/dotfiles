# Workflow Multiple Execute

https://github.com/d-kuro/gwq
https://github.com/d-kuro/gwq?tab=readme-ov-file#multiple-ai-agent-workflow

# Development Philosophy

## Test-Driven Development (TDD)

- As a general rule, development is done using Test-Driven Development (TDD)
- Begin by writing tests based on the expected inputs and outputs
- Do not write any implementation code at this stage—only prepare the tests
- Run the tests and confirm that they fail
- Commit once it's confirmed that the tests are correctly written
- Then proceed with the implementation to make the tests pass
- During implementation, do not modify the tests; keep fixing the code
- Repeat the process until all tests pass

# Rules

- Please make sure to consult the user whenever you plan to use an implementation method or technique that hasn't been used in other files.
- For maximum efficiency, whenever you need to perform multiple independent operations, invoke all relevant tools simultaneously rather than sequentially.

## Library Installation Policy

**NEVER add or download libraries without explicit user permission.**
This includes but is not limited to:

- `go mod download` / `go get`
- `yarn add` / `npm install` / `npm i`
- `pip install`
- `composer install`
- `bundle install`
- Any other package manager commands

**Exception:** If a library is absolutely necessary for the task, you MUST ask the user for permission first before installing or adding any dependencies.

# Frontend Development Rules

- Avoid creating a new component if the requirement can be met with minor modifications to an existing component.

# Auto Review & Explanation Flow

## Trigger Conditions
Automatically execute the review flow after implementation completion when:
- Changes exceed 100 lines

## Automated Flow

### 1. Diff Check
- Check the number of changed lines with `git diff --stat`
- If changes exceed 100 lines, proceed to the next step

### 2. Code Quality Checks (Sequential Execution)
Detect the project's language/environment and execute appropriate commands sequentially. Proceed to next step only if all checks pass:

1. **Formatting**: Run language-specific formatters
   - Go: `go fmt ./...`, `goimports -w .`
   - TypeScript/JavaScript: `npm run format` or `prettier --write .`
   - Python: `black .` or `ruff format .`
   - Rust: `cargo fmt`

2. **Linting**: Run language-specific linters
   - Go: `golangci-lint run`
   - TypeScript/JavaScript: `npm run lint` or `eslint .`
   - Python: `ruff check .` or `pylint`
   - Rust: `cargo clippy`

3. **Testing**: Run language-specific test commands
   - Go: `go test -race -parallel 4 ./...`
   - TypeScript/JavaScript: `npm test`
   - Python: `pytest` or `python -m pytest`
   - Rust: `cargo test`

**Detection Method**:
- Detect language from project root files (`go.mod`, `package.json`, `pyproject.toml`, `Cargo.toml`, etc.)
- Prioritize commands defined in the `scripts` section of package.json
- Skip to the next step if the corresponding command doesn't exist

### 3. Code Review
- Launch the `review` agent with the Task tool
- Perform comprehensive code review
- Analyze review results

### 4. Fix Issues
- Fix any Critical/Major issues
- After fixes, restart from step 2

### 5. Implementation Explanation
- After all checks and reviews pass
- Launch the `explain-implementation` agent with the Task tool
- Concisely explain implementation details, intent, and impact to the user

## Example Flow
```
Implementation Complete → Diff Check (150 lines) → format → lint → test → review → fix → explain-implementation → Report to User
```

## Notes
- Critical/Major issues identified in review MUST be fixed
- If tests fail, identify the cause and fix before re-running
- Keep explanations concise (10-15 sentences) and technically accurate
