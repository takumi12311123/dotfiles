# Workflow multiple execute

https://github.com/d-kuro/gwq
https://github.com/d-kuro/gwq?tab=readme-ov-file#multiple-ai-agent-workflow

# Development Philosophy

# Test-Driven Development (TDD)

- As a general rule, development is done using Test-Driven Development (TDD)
- Begin by writing tests based on the expected inputs and outputs
- Do not write any implementation code at this stage—only prepare the tests
- Run the tests and confirm that they fail
- Commit once it’s confirmed that the tests are correctly written
- Then proceed with the implementation to make the tests pass
- During implementation, do not modify the tests; keep fixing the code
- Repeat the process until all tests pass

# rule

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

# Frontend Development Rule

- creating a new component if the requirement can be met with minor modifications to an existing component.
