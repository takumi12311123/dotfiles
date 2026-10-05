#!/usr/bin/env bash
# agy pane of review-pr.sh: fetch the PR with gh, then let headless agy review
# the fetched files. agy cannot run gh itself and reads only its working directory.
#
# Usage: review-pr-agy.sh <pr-number> <owner/repo> <review-prompt-file>
set -u

PR_NUMBER=$1
REPO=$2
PROMPT_FILE=$3
SCRIPTS="$HOME/.claude/skills/agy-review/scripts"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/review-pr-agy.XXXXXX") || exit 1
CHILD=""
cleanup() {
  [ -n "$CHILD" ] && kill "$CHILD" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT
trap 'exit 143' INT TERM HUP

mkdir "$TMP/work"
gh pr view "$PR_NUMBER" --repo "$REPO" > "$TMP/work/pr.md" || { echo "gh pr view failed"; exit 1; }
gh pr diff "$PR_NUMBER" --repo "$REPO" > "$TMP/raw.diff" || { echo "gh pr diff failed"; exit 1; }

bash "$SCRIPTS/agy-snapshot.sh" filter-diff "$TMP/raw.diff" "$TMP/work/pr.diff"
case $? in
  0) ;;
  3) echo "Nothing to review: every changed file is excluded as sensitive."; exit 0 ;;
  *) echo "Filtering the PR diff failed."; exit 1 ;;
esac

{
  printf 'Repository: %s\nPull Request: #%s\n\n' "$REPO" "$PR_NUMBER"
  printf 'The pull request description is the file pr.md and its diff is the file pr.diff, both in the current directory. Read both in full and review the pull request in Japanese.\n\n'
  cat "$PROMPT_FILE"
} > "$TMP/prompt.md"

bash "$SCRIPTS/agy-exec.sh" --workdir "$TMP/work" --prompt-file "$TMP/prompt.md" --timeout 900s > "$TMP/envelope" &
CHILD=$!
wait "$CHILD"
CHILD=""

python3 -c '
import json, sys
e = json.load(open(sys.argv[1]))
print(e["result"] if e["status"] == "completed" else "agy review unavailable: %s %s" % (e["status"], e["detail"]))
' "$TMP/envelope"
