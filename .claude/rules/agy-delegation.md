# Gemini Delegation Rule

Offload to Gemini CLI to protect Claude Code's context window.

## Auto-delegate to Gemini when:
- **Web research**: Library docs, API references, best practices lookup
- **Repository analysis**: Large codebase exploration, dependency mapping
- **Documentation**: Generating or reviewing large docs
- **Multimodal**: Image/screenshot analysis tasks

## How to delegate:
- Use `gemini` skill or Bash with `gemini -p "prompt"` in non-interactive mode
- Run in background when possible (Agent tool with run_in_background)
- Summarize results before injecting into conversation (context protection)
- For research tasks, save results to `.claude/docs/research/` for reuse

## Do NOT delegate:
- Code editing (Gemini has no file access in CLI mode)
- Tasks requiring current conversation context
- When user explicitly wants Claude to handle it
