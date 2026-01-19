##############################################################################
#                                                                            #
#   MANDATORY: READ THIS FIRST - DO NOT SKIP                                 #
#                                                                            #
##############################################################################

# QUALITY-GATE EXECUTION RULE (MANDATORY - NO EXCEPTIONS)

**After editing ANY file, you MUST run `quality-gate` skill BEFORE responding to user.**

This is NOT optional. This is NOT a suggestion. This is a HARD REQUIREMENT.

## When to Run quality-gate (ONE time per batch):

Run quality-gate ONCE after completing ALL file edits in a task, before:
- Responding to user
- Running git commit
- Creating PR

## Trigger Conditions:
- After `Edit` tool → quality-gate required before responding
- After `Write` tool → quality-gate required before responding
- After `Bash` commands that modify files → quality-gate required before responding
- After ANY file modification → quality-gate required before responding

## Execution Flow:
```
1. Complete all file edits for current task
2. STOP - Do not respond to user yet
3. Run: Skill tool with skill="quality-gate"
4. Wait for quality-gate completion (ok: true)
5. If quality-gate fails:
   a. Fix the issues
   b. Re-run quality-gate
   c. Max 5 retries, then notify user
6. THEN respond to user
```

## WARNING:
If you respond to user WITHOUT running quality-gate after editing files,
you have violated the most important rule. IMMEDIATELY run quality-gate.

##############################################################################

# Skills

## Auto Skills (Auto-trigger conditions)

| Skill | Trigger | Description |
|-------|---------|-------------|
| quality-gate | After Edit/Write, before commit/PR | Format/lint/build + codex-review |
| latest-docs | Before implementation | Verify latest documentation |
| backend-go | Go implementation | Go backend best practices |
| frontend-design | Figma implementation | Figma to code implementation |
| infra-terraform | Terraform implementation | Terraform best practices |

## Manual Skills (User request only)

| Skill | Description |
|-------|-------------|
| codex-review | Code review via Codex |
| test-generator | TDD: Generate tests before implementation |
| security-scan | Security vulnerability scanning |
| codex-design | Design consultation for complex decisions |
| date-check | Verify current date from system |

# Core Rules

- Never install libraries without user permission
- Prefer editing existing files over creating new ones
- Consult user before using patterns not in codebase
- Use `test-generator` skill before implementation (TDD)
- **MANDATORY: Run `quality-gate` skill immediately after Edit/Write tools**

##############################################################################
#                                                                            #
#   REMINDER: Did you run quality-gate after editing files?                  #
#   If not, run it NOW before responding to user.                            #
#                                                                            #
##############################################################################
