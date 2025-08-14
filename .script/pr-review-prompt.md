# PR Review Guidelines

Please review the following Pull Request in Japanese. Use appropriate labels for each comment to indicate priority and type.

## Comment Labels

Use these labels at the beginning of each comment to indicate its priority and nature:

- **[Must]**: Critical issues that MUST be fixed before merging (bugs, security issues, breaking changes)
- **[Should]**: Important improvements that should be addressed (performance issues, code quality problems)
- **[IMO]**: Opinion-based suggestions (design choices, alternative approaches, stylistic preferences)
- **[Nit]**: Minor issues (typos, formatting, naming conventions)
- **[Question]**: Clarifications needed or questions about the implementation
- **[Good]**: Positive feedback on well-implemented parts

## Review Focus Areas

### 1. Functionality & Bugs
- Is the intended functionality correctly implemented?
- Are there any obvious bugs or logic errors?
- Is error handling appropriate?
- Are edge cases properly handled?

### 2. Code Quality
- Is the code readable and maintainable?
- Are variable and function names clear and descriptive?
- Is there unnecessary code duplication?
- Does the code follow project conventions?

### 3. Testing
- Are there adequate tests for new functionality?
- Do existing tests still pass?
- Are edge cases covered in tests?

### 4. Unused Code
- Is there any new code that isn't being used in the existing production codebase?
- Are there any dead code or unreferenced functions/variables?
- Are there any imported modules that are not being used?

### 5. Security
- Are user inputs properly validated and sanitized?
- Is sensitive data properly protected?
- Are there any potential security vulnerabilities?

### 6. Performance
- Are there any obvious performance bottlenecks?
- Is there unnecessary computation or memory usage?
- Could any algorithms be optimized?

### 7. Documentation
- Is the code adequately documented?
- Are complex logic sections explained?
- Is user-facing documentation updated if needed?

## Output Format

Please respond in Japanese with specific line-by-line comments using the following structure:

### 📋 サマリー
Brief overview of the PR and overall assessment.

### 📝 詳細レビュー

For each file with comments, use this format:

**`path/to/file.ext`**

- **Line X-Y**: [Label] Comment
  ```language
  // Code snippet if needed
  ```
  
- **Line Z**: [Label] Another comment

### 💭 総合評価

- **承認状態**: APPROVE / REQUEST_CHANGES / COMMENT
- **マージ可否**: 可能 / 要修正 / 要議論
- **優先対応事項**: List of [Must] items that need immediate attention

## Example Comments

**`src/utils/validator.js`**

- **Line 15-20**: [Must] SQL インジェクションの脆弱性があります。ユーザー入力を直接クエリに使用しています。
  ```javascript
  const query = `SELECT * FROM users WHERE id = ${userId}`;
  ```
  パラメータ化クエリを使用してください。

- **Line 45**: [IMO] この関数は責務が多すぎるように見えます。複数の小さな関数に分割することを検討してください。

- **Line 72**: [Nit] 変数名 `tmp` は意味が不明確です。`temporaryUserData` など具体的な名前にしてください。

- **Line 89**: [Question] なぜここで同期処理を使用していますか？パフォーマンスへの影響はありませんか？

- **Line 102-110**: [Good] エラーハンドリングが適切に実装されています。全てのケースが考慮されていて素晴らしいです。