# agy Delegation Rule

Offload to Antigravity CLI (`agy`) to protect Claude Code's context window.
`agy` is the CLI that runs Gemini models on the Google subscription.

## Auto-delegate to agy when:
- **Web research**: Library docs, API references, best practices lookup
- **Repository analysis**: Large codebase exploration, dependency mapping
- **Documentation**: Generating or reviewing large docs
- **Multimodal**: Image/screenshot analysis tasks

## How to delegate:
- Always go through the wrapper scripts — each call is one command and prints an envelope JSON
  (`status` / `detail` / `result`); only `status: "completed"` carries a result
  - Review of local changes or a PR: `~/.claude/skills/agy-review/scripts/agy-review.sh [--pr <number>]`
  - Web search or any prompt that needs no local files: `~/.claude/skills/agy-review/scripts/agy-exec.sh --prompt "<prompt>"`
  - Cross-verified research: the `web-research` skill
- Do not start `agy -p` directly inside a repository: headless agy reads any file under its
  working directory. The scripts run it in a temp directory holding only what it should see
  (secret-named files, symlinks and submodules are left out)
- Run in background when possible (Agent tool with run_in_background)
- Summarize results before injecting into conversation (context protection)
- For research tasks, save results to `.claude/docs/research/` for reuse

## Do NOT delegate:
- Code editing (headless agy cannot write files)
- Tasks requiring current conversation context
- When user explicitly wants Claude to handle it
