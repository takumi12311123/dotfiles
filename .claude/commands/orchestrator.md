---
allowed-tools: Bash(gh:*), Bash(git:*), Bash(npm:*), Bash(pytest:*)
description: Orchestrate complex multi-step development tasks with structured planning
argument-hint: <task-description> - describe the complex task to orchestrate
---

## Context

- Current repository: !`git remote get-url origin 2>/dev/null || echo "No remote repository"`
- Active issues: !`gh issue list --limit 5 2>/dev/null || echo "No GitHub CLI or issues available"`
- Active PRs: !`gh pr list --limit 3 2>/dev/null || echo "No active PRs"`
- Project type: !`if [ -f package.json ]; then echo "Node.js project"; elif [ -f requirements.txt ]; then echo "Python project"; else echo "Unknown project type"; fi`

## Orchestration Framework

Execute complex tasks using structured, parallel processing:

### 1. Initial Analysis

- Analyze task scope, requirements, and dependencies
- Identify potential blockers and execution flow
- **Present structured execution plan for user confirmation**

### 2. Step Planning

- Break task into 2-4 sequential steps
- Define parallel subtasks within each step
- Specify required context from previous steps

### 3. Step-by-Step Execution

- Execute all subtasks in current step in parallel
- Collect results as concise summaries (100-200 words each)
- Pass only relevant context to next step
- Wait for all subtasks to complete before continuing

### 4. Review and Adaptation

- After each step, assess if remaining steps are appropriate
- Modify, add, or remove steps as necessary
- Insert intermediate steps for new issues

### 5. Progressive Aggregation

- Synthesize results from completed steps
- Build progressively complete understanding
- Use insights from earlier steps to optimize later ones

## Example Orchestration: "Test, Lint, and Commit"

### Execution Plan:

1. **Analysis**: Review project structure and tooling setup
2. **Quality Checks** (parallel): Run tests, linting, check git status
3. **Fixes & Prep** (parallel): Fix errors, generate commit message
4. **Final Validation** (parallel): Re-run checks, commit changes

_Note: If Step 2 has no errors, skip Step 3 and proceed to simplified Step 4_

## Your Task

Orchestrate the provided complex task using the framework above:

1. First, analyze the task and present a structured execution plan
2. Wait for user confirmation before proceeding
3. Execute the plan using the orchestration framework above
