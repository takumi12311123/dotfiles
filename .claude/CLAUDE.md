# ⚠️ CRITICAL: Mandatory Pre-Confirmation Review Gate

**YOU MUST FOLLOW THIS SEQUENCE EVERY TIME:**

```
┌─────────────────────────────────────┐
│ 1. Complete implementation/design   │
├─────────────────────────────────────┤
│ 2. STOP - Do NOT ask user yet      │
├─────────────────────────────────────┤
│ 3. Run codex-review SKILL           │
│    (automatic, no user trigger)     │
├─────────────────────────────────────┤
│ 4. Fix blocking issues (loop)       │
├─────────────────────────────────────┤
│ 5. Achieve ok: true status          │
├─────────────────────────────────────┤
│ 6. NOW present to user with review  │
└─────────────────────────────────────┘
```

## When to Trigger (Automatic Detection)

Run `codex-review` SKILL **automatically before** asking for user confirmation in these situations:

- After creating design documents
- After creating implementation plans (PLANS.md)
- After completing code implementation
- Before `git commit`
- Before creating PR
- Before asking "Is this okay?" or "Please confirm"

## Forbidden Patterns

**NEVER DO THIS:**
- ❌ Complete implementation → "Is this okay?" (NO codex-review)
- ❌ Skip codex-review and ask user directly
- ❌ Present to user with blocking issues remaining

**ALWAYS DO THIS:**
- ✅ Complete implementation → codex-review → Fix issues → ok: true → "Codex review passed, is this okay?"

## Self-Check Before User Confirmation

Before presenting ANYTHING to user, verify:
```
[ ] Did I run codex-review SKILL?
[ ] Did I fix all blocking issues?
[ ] Is review status ok: true?
[ ] Did I include review summary in my response?
```

If ANY checkbox is unchecked → Run codex-review first, then present.

## Presentation Format to User

When presenting after successful review:

```markdown
## [Title] ✅

[Implementation/design details in Japanese]

### Codex Review Results
- **Status**: ✅ ok
- **Iterations**: 2/5
- **Fixed Issues**:
  1. [Fix 1]
  2. [Fix 2]
- **Advisory (optional)**: [Minor suggestions if any]

Is this okay to proceed?
```

When blocking issues remain after max iterations:

```markdown
## [Title] ⚠️

[Details in Japanese]

### Codex Review Results
- **Status**: ⚠️ Unresolved issues remain
- **Iterations**: 5/5 (max reached)

### Unresolved Blocking Issues
1. `file.py:42-45`
   - **Problem**: [Description]
   - **Recommendation**: [Suggested fix]

Should we fix these before proceeding?
```

---

# Development Philosophy

## Test-Driven Development (TDD)

- As a general rule, development is done using Test-Driven Development (TDD)
- Begin by writing tests based on expected inputs and outputs
- Do not write any implementation code at this stage—only prepare the tests
- Run the tests and confirm that they fail
- Commit once it's confirmed that the tests are correctly written
- Then proceed with the implementation to make the tests pass
- During implementation, do not modify the tests; keep fixing the code
- Repeat the process until all tests pass

---

# Core Rules

- Consult the user whenever you plan to use an implementation method or technique that hasn't been used in other files
- For maximum efficiency, whenever you need to perform multiple independent operations, invoke all relevant tools simultaneously rather than sequentially

---

# Library Installation Policy

**NEVER add or download libraries without explicit user permission.**

This includes but is not limited to:
- `go mod download` / `go get`
- `yarn add` / `npm install` / `npm i`
- `pip install`
- `composer install`
- `bundle install`
- Any other package manager commands

**Exception:** If a library is absolutely necessary for the task, you MUST ask the user for permission first before installing or adding any dependencies.

---

# Frontend Development Rule

- Avoid creating a new component if the requirement can be met with minor modifications to an existing component

---

# Codex Collaboration Framework

## Role Division
- **Claude Code**: Implementation, orchestration, user interaction
- **Codex**: Review (read-only sandbox), design consultation, debugging assistance

## When to Involve Codex

### 1. Automatic Review (via codex-review SKILL)
- **ALWAYS** before user confirmation (mandatory)
- After design/implementation completion
- Before git commit/PR

### 2. Design Consultation (via codex-design SKILL)
- Complex architectural decisions
- Introducing new patterns not used in codebase
- Performance-critical implementations
- 3+ architectural options to choose from

### 3. Collaborative Debugging
- Stuck on same issue for 15+ minutes
- 3+ different approaches tried without success
- Unclear error messages requiring deep analysis

## Collaboration Protocol

```
┌────────────────────────────────────────────┐
│ Claude Code: Draft implementation          │
├────────────────────────────────────────────┤
│ Codex: Review in read-only sandbox         │
├────────────────────────────────────────────┤
│ Claude Code: Fix blocking issues           │
├────────────────────────────────────────────┤
│ Codex: Re-review (iterate until ok: true)  │
├────────────────────────────────────────────┤
│ Claude Code: Present to user with summary  │
├────────────────────────────────────────────┤
│ User: Final approval                       │
└────────────────────────────────────────────┘
```

## Context Optimization Strategy

- **Skills**: Keep only summaries in main context, load details on execution
- **Subagents**: Use separate context windows for parallel processing
- **Codex**: Offload deep analysis to reduce Claude Code context consumption
- **Results**: Only return concise summaries to main context
