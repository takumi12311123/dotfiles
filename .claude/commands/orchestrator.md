# Orchestrator Framework

## GitHub

you can see issue and pr by gh command.

```
gh issue view
gh pr view
```

## Orchestrator

1. Initial Analysis

- Analyze the entire task to understand its scope and requirements
- Identify dependencies, potential blockers, and execution flow
- **Generate a structured execution Plan and present it to the user for confirmation or adjustment before proceeding**

2. Step Planning

- Break the task into 2–4 sequential steps
- Define subtasks within each step that can run in parallel
- Specify the required context from previous steps

3. Step-by-Step Execution

- Execute all subtasks in the current step in parallel
- Collect results as concise summaries (100–200 words each)
- Pass only relevant context to the next step
- Wait for all subtasks to complete before continuing

4. Step Review and Adaptation

- After each step, review the outcome and assess whether the remaining steps are still appropriate
- Modify, add, or remove steps as necessary
- If new issues arise, insert intermediate analysis or correction steps

5. Progressive Aggregation

- Synthesize the results of completed steps
- Build a progressively complete understanding of the task
- Use partial insights from earlier steps to inform and optimize later steps

## 🧠 Example: "Test, Lint, and Commit"

### Plan Preview:

1. Initial Analysis

- Review project structure and determine test/lint setup

2. Quality Checks (parallel)

- Run tests
- Run linting
- Check git status

3. Fixes & Commit Prep (parallel)

- Fix lint errors
- Fix test failures
- Generate commit message

4. Final Validation (parallel)

- Re-run tests
- Re-run lint
- Commit changes

If no errors in Step 2: skip Step 3, proceed directly to simplified Step 4.
