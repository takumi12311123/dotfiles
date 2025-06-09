# Commit Rules

## Important Rules

- Commit messages must be written in **English**
- Use clear and understandable English expressions
- **If multi-line commit messages are not supported, use simple one-line messages**

## Basic Commit Message Structure

### Ideal Structure (when multi-line is supported)

```
<type>: <subject>

line:
hoge:
```

### Simple Structure (single line only)

```
<type>: <subject>
```

## Commit Message Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding or modifying tests
- `chore`: Changes to the build process, auxiliary tools, or libraries

## Examples of Good Commit Messages

### Multi-line Example

```
feat: add user authentication function

Implement JWT based authentication with login/logout features.
Also add token refresh functionality for better user experience.
```

### Single Line Examples

```
feat: add user authentication function
refactor: remove unnecessary setStringValue function
fix: correct expired authentication token handling
```

## Commit Message Checklist

- [ ] Is the message written in English?
- [ ] Is the English expression clear and understandable?
- [ ] Does it clearly convey what was changed?
- [ ] Is the appropriate type selected?
- [ ] If multi-line is not available, does the single line convey the key point?

## Commit Message Guidelines

- Use imperative mood in present tense ("Add feature" / "Fix bug" etc.)
- Capitalize the first letter
- Do not end the message with a period
- Add body only when necessary to provide detailed explanation