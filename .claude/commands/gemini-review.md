# Gemini CLI Code Review Commands

## Overview

This command executes code reviews from Claude Code using Gemini CLI.

## Usage

### Basic Code Review

```bash
gemini --prompt="Please review the following code. Point out any bugs, performance issues, readability improvements, and security concerns." --file="[file_path]"
```

### Detailed Code Review

```bash
gemini --prompt="
Please conduct a detailed review of the following code:

【Review Aspects】
1. Bugs and logical errors
2. Performance issues
3. Security vulnerabilities
4. Code readability and maintainability
5. Best practice compliance
6. Proper error handling
7. Testing requirements

【Output Format】
- Point out issues with specific line numbers
- Include concrete code examples in improvement suggestions
- Evaluate with priority levels (High/Medium/Low)

" --file="[file_path]"
```

### Pull Request Review

```bash
gemini --prompt="
Review this code as a pull request. Please evaluate from the following perspectives:

1. Validity of changes
2. Impact on existing code
3. Testing requirements
4. Documentation update needs
5. Code style consistency

Review comments should be constructive and include specific improvement suggestions.
" --file="[file_path]"
```

### Multiple File Review

```bash
# Review multiple files simultaneously
gemini --prompt="
Please review the following multiple files including their relationships:
- Inter-file dependencies
- Architectural consistency
- Separation of concerns
- Interface design
" --file="[file1]" --file="[file2]" --file="[file3]"
```

### Security-Focused Review

```bash
gemini --prompt="
Please review this code from a security perspective:

【Checklist】
- Input validation issues
- SQL injection and other vulnerabilities
- Authentication and authorization problems
- Proper handling of sensitive information
- Cross-site scripting (XSS)
- CSRF attack countermeasures
- Password and API key management

If security risks exist, please provide specific countermeasures.
" --file="[file_path]"
```

### Performance-Focused Review

```bash
gemini --prompt="
Please review this code from a performance perspective:

【Checklist】
- Algorithm complexity
- Memory usage
- Database query efficiency
- Network communication optimization
- Cache utilization
- Elimination of unnecessary processing

If performance improvements are possible, please provide specific optimization suggestions.
" --file="[file_path]"
```

## Configuration Examples

### `.geminirc` Configuration File Example

```
model=gemini-1.5-pro-002
temperature=0.3
max_tokens=4096
```

### Environment Variables

```bash
export GEMINI_API_KEY="your-api-key-here"
export GEMINI_MODEL="gemini-1.5-pro-002"
```

## Gemini CLI Collaboration Guide

### Purpose

When a user instructs **"proceed while consulting with Gemini"** (or synonymous phrases), Claude will proceed with subsequent tasks in collaboration with **Gemini CLI**.
Present Gemini's responses as-is and add Claude's own explanations and integration to fuse the knowledge of both agents.

---

### Triggers

- Regular expression: `/Gemini.*consult.*while/`
- Examples:
  - "Proceed while consulting with Gemini"
  - "Let's work on this while talking with Gemini"

---

### Basic Flow

1. **PROMPT Generation**
   Claude summarizes the user's requirements into a single text and stores it in the environment variable `$PROMPT`.

2. **Gemini CLI Invocation**

   ```bash
   gemini <<EOF
   $PROMPT
   EOF
   ```

3. **Result Integration**
   Combine Gemini's response with Claude's analysis to provide final recommendations.

---

### Implementation Example

```bash
# Setting the prompt
PROMPT="Please review the following code and point out improvements:
$(cat path/to/code.py)"

# Consult with Gemini CLI
gemini <<EOF
$PROMPT

Additionally, please consider the following aspects:
- Security vulnerabilities
- Performance optimization
- Code readability
EOF
```

## Important Notes

- Properly manage API keys and do not commit them to version control systems
- Use review results as reference; final decisions should be made by humans
- Exercise caution when reviewing code containing sensitive information
