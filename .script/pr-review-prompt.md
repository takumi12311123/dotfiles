# PR Review Guidelines

Please review the following Pull Request in Japanese. Keep the review concise and practical.

## Review Focus Areas

### 1. Functionality & Bugs

- Is the intended functionality correctly implemented?
- Are there any obvious bugs or logic errors?
- Is error handling appropriate?

### 2. Code Quality

- Is the code readable and maintainable?
- Are variable and function names clear and descriptive?
- Is there unnecessary code duplication?

### 3. Unused Code

- Is there any new code that isn't being used in the existing production codebase?
- Are there any dead code or unreferenced functions/variables?
- Are there any imported modules that are not being used?

### 4. Security

- Are user inputs properly validated and sanitized?
- Is sensitive data properly protected?

### 5. Performance

- Are there any obvious performance bottlenecks?
- Is there unnecessary computation or memory usage?

## Output Format

Please respond in Japanese using the following format:

1. **概要**: Brief overview of the PR
2. **良い点**: What's done well
3. **重要な問題**: Critical issues that must be fixed (if any)
4. **改善提案**: Suggestions for improvement
5. **質問**: Questions for the author (if any)
