#!/usr/bin/env bash
# Run one headless agy prompt inside a working directory and print a one-line
# envelope JSON (see agy-parse.py). Always exits 0: the outcome is in "status".
#
# Usage: agy-exec.sh (--prompt TEXT | --prompt-file FILE) [--workdir DIR]
#                    [--schema FILE] [--timeout 300s]
#
# Without --workdir agy runs in a fresh empty directory, so it has no local
# files to read (web search and other tasks that need none).
set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)

WORKDIR=""
PROMPT_FILE=""
PROMPT_TEXT=""
SCHEMA=""
TIMEOUT="300s"
MODEL="gemini-3.1-pro-high"

fail() { python3 "$SCRIPT_DIR/agy-parse.py" --emit error --detail "$1"; exit 0; }

while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || fail "agy-exec.sh: missing value for $1"
  case "$1" in
    --workdir) WORKDIR=$2 ;;
    --prompt-file) PROMPT_FILE=$2 ;;
    --prompt) PROMPT_TEXT=$2 ;;
    --schema) SCHEMA=$2 ;;
    --timeout) TIMEOUT=$2 ;;
    *) fail "agy-exec.sh: unknown argument $1" ;;
  esac
  shift 2
done

[ -z "$WORKDIR" ] || [ -d "$WORKDIR" ] || fail "agy-exec.sh: workdir not found: $WORKDIR"
if [ -n "$PROMPT_FILE" ]; then
  [ -f "$PROMPT_FILE" ] || fail "agy-exec.sh: prompt file not found: $PROMPT_FILE"
  PROMPT_TEXT=$(cat "$PROMPT_FILE")
fi
[ -n "$PROMPT_TEXT" ] || fail "agy-exec.sh: --prompt or --prompt-file is required"
[ -z "$SCHEMA" ] || [ -f "$SCHEMA" ] || fail "agy-exec.sh: schema not found: $SCHEMA"
command -v agy >/dev/null 2>&1 || fail "agy not found in PATH"

# Headless agy auto-denies shell commands, and one denied call can end the run
# with an empty response. It also tends to hand reading work to a subagent and
# end the turn with "I have dispatched a subagent" instead of an answer.
# The constraint goes first because agy truncates the tail of an over-long
# prompt argument.
CONSTRAINT='NEVER run shell or terminal commands (no grep, git, ls, cat through a shell): they are denied in this headless run and a denied command can abort the whole run with no output. To read files, use your built-in file reading, directory listing and file search tools, and only on files inside the current working directory. Do NOT dispatch subagents or background tasks: this is a single non-interactive turn, so do all the work yourself now and put the complete final answer in this reply.'
PROMPT=$(printf '%s\n\n%s' "$CONSTRAINT" "$PROMPT_TEXT")

OUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/agy-exec.XXXXXX") || fail "agy-exec.sh: mktemp failed"
AGY_PID=""
cleanup() {
  [ -n "$AGY_PID" ] && kill "$AGY_PID" 2>/dev/null
  rm -rf "$OUT_DIR"
}
trap cleanup EXIT
trap 'exit 143' INT TERM HUP
if [ -z "$WORKDIR" ]; then
  WORKDIR="$OUT_DIR/empty"
  mkdir "$WORKDIR"
fi

set -- -p "$PROMPT" --model "$MODEL" --output-format json --print-timeout "$TIMEOUT"
[ -n "$SCHEMA" ] && set -- "$@" --json-schema "$SCHEMA"

# Despite the constraint, agy sometimes still reaches for a denied tool and ends
# with no output; the same prompt usually succeeds when run again, so that one
# case gets a second attempt.
for ATTEMPT in 1 2; do
  # Run in the background and wait: bash defers traps while a foreground child
  # runs, so a TERM would otherwise leave agy and the temp files behind.
  (cd "$WORKDIR" && exec agy "$@" < /dev/null > "$OUT_DIR/raw" 2> "$OUT_DIR/err") &
  AGY_PID=$!
  wait "$AGY_PID"
  CODE=$?
  AGY_PID=""

  ENVELOPE=$(python3 "$SCRIPT_DIR/agy-parse.py" --raw "$OUT_DIR/raw" --stderr "$OUT_DIR/err" \
    --exit-code "$CODE" --timeout-label "$TIMEOUT" ${SCHEMA:+--schema-mode})
  case "$ENVELOPE" in
    '{"status": "error"'*'denied actions:'*) [ "$ATTEMPT" -eq 1 ] && continue ;;
  esac
  break
done
printf '%s\n' "$ENVELOPE"
exit 0
