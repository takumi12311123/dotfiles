---
name: test-generator
description: |
  TDD workflow: Generate tests BEFORE implementation. Use when user requests new feature or bug fix. Write failing tests first, then implement to pass. Creates unit, integration, and edge case tests.
---

# Test Generator SKILL

## Purpose

**TDD first step**: Generate comprehensive test cases before implementation.
Follows Test-Driven Development principles: Red → Green → Refactor.

## When to Use

### Automatic Triggers
- User mentions "TDD" or "test first"
- User requests "write tests for..."
- Before implementing new functionality (TDD workflow)

### Manual Invocation
- User explicitly asks for test generation
- During code review if tests are missing

## TDD Workflow Integration

```
1. [THIS SKILL] Generate tests (Red phase)
2. Run tests → Confirm they fail
3. Implement code (Green phase)
4. Run tests → Confirm they pass
5. codex-review → Quality check
6. Refactor if needed
```

## Test Types

### 1. Unit Tests
- Test individual functions/methods in isolation
- Mock external dependencies
- Cover all code paths

### 2. Integration Tests
- Test component interactions
- Test with real dependencies (when feasible)
- Test data flow between modules

### 3. Edge Case Tests
- Boundary values
- Null/undefined inputs
- Empty collections
- Large inputs
- Invalid data types

### 4. Error Case Tests
- Exception handling
- Error messages
- Failure recovery
- Timeout scenarios

## Test Generation Process

### Step 1: Analyze Target Code

Understand:
- Function/method signatures
- Expected inputs and outputs
- Dependencies and side effects
- Business logic requirements
- Error conditions

### Step 2: Identify Test Scenarios

Create test matrix:
```
| Scenario | Input | Expected Output | Test Type |
|----------|-------|-----------------|-----------|
| Normal case | valid data | success | unit |
| Edge case | boundary | correct handling | unit |
| Error case | invalid | error thrown | unit |
```

### Step 3: Generate Test Code

Follow language-specific conventions:

**JavaScript/TypeScript (Jest):**
```javascript
describe('FunctionName', () => {
  describe('Normal cases', () => {
    it('should return correct result for valid input', () => {
      // Arrange
      const input = { id: 1, name: 'test' };

      // Act
      const result = functionName(input);

      // Assert
      expect(result).toEqual({ success: true, data: input });
    });
  });

  describe('Edge cases', () => {
    it('should handle empty input', () => {
      const result = functionName({});
      expect(result).toEqual({ success: false, error: 'Invalid input' });
    });

    it('should handle null input', () => {
      expect(() => functionName(null)).toThrow('Input cannot be null');
    });
  });

  describe('Error cases', () => {
    it('should throw error for invalid data type', () => {
      expect(() => functionName('invalid')).toThrow(TypeError);
    });
  });
});
```

**Go:**
```go
func TestFunctionName(t *testing.T) {
	t.Run("normal: returns correct result for valid input", func(t *testing.T) {
		// Arrange
		input := Input{ID: 1, Name: "test"}

		// Act
		result, err := FunctionName(input)

		// Assert
		assert.NoError(t, err)
		assert.Equal(t, expectedResult, result)
	})

	t.Run("boundary: handles empty input", func(t *testing.T) {
		result, err := FunctionName(Input{})
		assert.Error(t, err)
		assert.Nil(t, result)
	})

	t.Run("error: handles nil input", func(t *testing.T) {
		result, err := FunctionName(nil)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "input cannot be nil")
	})
}
```

**Python (pytest):**
```python
class TestFunctionName:
    def test_normal_case_valid_input(self):
        """Normal: returns correct result for valid input"""
        # Arrange
        input_data = {"id": 1, "name": "test"}

        # Act
        result = function_name(input_data)

        # Assert
        assert result == {"success": True, "data": input_data}

    def test_edge_case_empty_input(self):
        """Boundary: handles empty input"""
        result = function_name({})
        assert result["success"] is False

    def test_error_case_invalid_type(self):
        """Error: raises error for invalid type"""
        with pytest.raises(TypeError):
            function_name("invalid")
```

### Step 4: Add Test Fixtures

Create reusable test data:
```javascript
// fixtures.js
export const validUser = {
  id: 1,
  name: 'Test User',
  email: 'test@example.com'
};

export const invalidUser = {
  id: -1,
  name: '',
  email: 'invalid-email'
};
```

### Step 5: Configure Mocks

Mock external dependencies:
```javascript
jest.mock('../api/userApi', () => ({
  fetchUser: jest.fn().mockResolvedValue({ id: 1, name: 'Mock User' }),
  createUser: jest.fn().mockResolvedValue({ success: true })
}));
```

## Output Format to User

**All user-facing output must be in Japanese.**

```markdown
## Test Generation Complete

### Generated Tests
- **File**: `tests/user.test.ts`
- **Test cases**: 12
  - Normal: 4
  - Boundary: 5
  - Error: 3

### Coverage Target
- Function coverage: 100%
- Branch coverage: 95%+
- Line coverage: 90%+

### Next Steps (TDD)
1. Run tests: `npm test` or `go test`
2. **Confirm failures** (Red phase - this is critical!)
3. Start implementation
4. Implement until tests pass
5. Quality check with codex-review

### Test Code
[Display generated test code]

Start TDD with these tests?
```

## Test Coverage Strategy

### Minimum Requirements
- **All public methods**: 100% coverage
- **Error paths**: All error conditions tested
- **Edge cases**: Identified and covered
- **Integration points**: External dependencies tested

### Coverage Tools
- JavaScript: Jest coverage, nyc
- Go: `go test -cover`
- Python: pytest-cov
- Rust: cargo-tarpaulin

## Best Practices

### 1. Test Naming
- Use descriptive, specific names
- Prefix with category: `normal:`, `boundary:`, `error:`
- Follow AAA pattern (Arrange-Act-Assert)

### 2. Test Independence
- Each test runs in isolation
- No shared state between tests
- Use beforeEach/afterEach for setup/teardown

### 3. Test Maintainability
- Keep tests simple
- One assertion per test (when possible)
- Use descriptive variable names
- Avoid test logic (no conditionals in tests)

### 4. Mock Strategy
- Mock external dependencies (APIs, databases)
- Don't mock what you own (internal modules)
- Use real implementations for critical paths

## Common Pitfalls to Avoid

1. **Testing implementation instead of behavior**
   - Bad: Test internal function calls
   - Good: Test public API behavior

2. **Brittle tests**
   - Bad: Tests break on refactoring
   - Good: Tests focus on contract, not implementation

3. **Incomplete coverage**
   - Bad: Only testing happy path
   - Good: Test edge cases and errors

4. **Slow tests**
   - Bad: Real database calls in unit tests
   - Good: Mock external dependencies

## Integration with Other SKILLs

### With codex-review
After implementation:
```
test-generator → Implementation → codex-review
                                   ├─ Verify tests pass
                                   ├─ Check test coverage
                                   └─ Security scan
```

### With security-scan
Security-focused tests:
```
test-generator generates security tests
  ├─ SQL injection tests
  ├─ XSS prevention tests
  ├─ Authentication tests
  └─ Authorization tests
```

## Important Reminders

1. **Generate tests BEFORE implementation** (TDD principle)
2. **Confirm tests fail initially** (Red phase)
3. **Output in Japanese** for user-facing text
4. **Include coverage requirements** in output
5. **Provide clear next steps** for TDD workflow
6. **Test behavior, not implementation**
