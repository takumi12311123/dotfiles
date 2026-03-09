##############################################################################
#   MANDATORY: QUALITY-GATE - READ THIS FIRST, DO NOT SKIP                  #
##############################################################################

**After Edit/Write/file-modifying Bash → MUST run `quality-gate` skill BEFORE responding.**

1. Complete ALL file edits
2. STOP - run: Skill tool with skill="quality-gate"
3. If fail → fix → re-run (max 5 retries, then notify user)
4. THEN respond to user

⚠️ Responding WITHOUT running quality-gate = violation. Run it NOW.

##############################################################################

# Skills

## Auto Skills

| Skill | Trigger | Description |
|-------|---------|-------------|
| quality-gate | After Edit/Write, before commit/PR | Format/lint/build + codex-review + gemini-review (parallel) |
| latest-docs | Before implementation | Verify latest documentation |
| backend-go | Go implementation | Go backend best practices |
| frontend-design | Figma implementation | Figma to code implementation |
| infra-terraform | Terraform implementation | Terraform best practices |

## Manual Skills

| Skill | Description |
|-------|-------------|
| codex-review | Code review via Codex |
| gemini-review | Code review via Gemini (parallel with codex-review) |
| web-research | 3者裏取りリサーチ (Claude + Codex + Gemini) |
| test-generator | TDD: Generate tests before implementation |
| security-scan | Security vulnerability scanning |
| codex-design | Design consultation for complex decisions |
| date-check | Verify current date from system |

@RTK.md
