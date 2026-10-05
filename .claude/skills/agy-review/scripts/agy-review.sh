#!/usr/bin/env bash
# Have agy read a diff (plus, when it matches the diff, a copy of the working
# tree) from a private temp directory, and print a one-line envelope JSON.
# Always exits 0: the outcome is in "status".
#
# Usage: agy-review.sh [--pr NUMBER | --diff-file FILE] [--diff-name NAME]
#                      [--prompt-file FILE] [--no-schema] [--timeout 300s]
#
#   (neither)     review the uncommitted changes of the current repository
#   --pr          review that pull request (fetched with gh). The working-tree copy is
#                 attached only when HEAD is the PR head and the tree is clean.
#   --diff-file   work on that diff alone, without a working-tree copy
set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
SKILLS_DIR=$(cd "$SCRIPT_DIR/../.." && pwd -P)

DIFF_FILE=""
PR=""
PR_HEAD=""
DIFF_NAME="review.diff"
PROMPT_FILE="$SCRIPT_DIR/../prompts/review.md"
SCHEMA="$SKILLS_DIR/codex-review/review-schema.json"
TIMEOUT=""

emit() { python3 "$SCRIPT_DIR/agy-parse.py" --emit "$1" --detail "$2"; exit 0; }

while [ $# -gt 0 ]; do
  if [ "$1" = "--no-schema" ]; then SCHEMA=""; shift; continue; fi
  [ $# -ge 2 ] || emit error "agy-review.sh: missing value for $1"
  case "$1" in
    --diff-file) DIFF_FILE=$2 ;;
    --pr) PR=$2 ;;
    --diff-name) DIFF_NAME=$2 ;;
    --prompt-file) PROMPT_FILE=$2 ;;
    --timeout) TIMEOUT=$2 ;;
    *) emit error "agy-review.sh: unknown argument $1" ;;
  esac
  shift 2
done

[ -z "$DIFF_FILE" ] || [ -f "$DIFF_FILE" ] || emit error "agy-review.sh: diff file not found: $DIFF_FILE"
[ -z "$PR" ] || [ -z "$DIFF_FILE" ] || emit error "agy-review.sh: --pr and --diff-file cannot be combined"
[ -f "$PROMPT_FILE" ] || emit error "agy-review.sh: prompt file not found: $PROMPT_FILE"
case "$DIFF_NAME" in
  "" | . | .. | */*) emit error "agy-review.sh: --diff-name must be a plain file name: $DIFF_NAME" ;;
esac

TMP=$(mktemp -d "${TMPDIR:-/tmp}/agy-review.XXXXXX") || emit error "agy-review.sh: mktemp failed"
CHILD=""
cleanup() {
  [ -n "$CHILD" ] && kill "$CHILD" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT
trap 'exit 143' INT TERM HUP

if [ -n "$PR" ]; then
  # Stop on any gh failure: an empty diff would otherwise be reported as "skipped".
  DIFF_FILE="$TMP/pr-raw.diff"
  gh pr diff "$PR" > "$DIFF_FILE" 2> "$TMP/gh.err" || emit error "gh pr diff $PR failed: $(tail -1 "$TMP/gh.err")"
  PR_HEAD=$(gh pr view "$PR" --json headRefOid -q .headRefOid 2> "$TMP/gh.err") \
    || emit error "gh pr view $PR failed: $(tail -1 "$TMP/gh.err")"
fi

WORK="$TMP/work" # the only directory agy can read
TREE_FAILED=""
mkdir -p "$WORK"
NOTE=""

if [ -n "$DIFF_FILE" ]; then
  bash "$SCRIPT_DIR/agy-snapshot.sh" filter-diff "$DIFF_FILE" "$WORK/$DIFF_NAME" 2> "$TMP/excluded"
  RC=$?
  if [ -n "$PR_HEAD" ]; then
    # A tree that differs from the PR head would be presented as context for code the PR does not contain.
    if [ "$(git rev-parse HEAD 2>/dev/null)" != "$PR_HEAD" ]; then
      NOTE="diff only: local HEAD is not the PR head"
    elif [ -n "$(git status --porcelain 2>/dev/null)" ]; then
      NOTE="diff only: working tree has uncommitted or untracked changes"
    elif [ "$RC" -eq 0 ]; then
      bash "$SCRIPT_DIR/agy-snapshot.sh" tree "$WORK/repo" 2>/dev/null || TREE_FAILED=1
    fi
  fi
else
  bash "$SCRIPT_DIR/agy-snapshot.sh" diff "$WORK/$DIFF_NAME" 2> "$TMP/excluded"
  RC=$?
  if [ "$RC" -eq 0 ]; then
    bash "$SCRIPT_DIR/agy-snapshot.sh" tree "$WORK/repo" 2>/dev/null || TREE_FAILED=1
  fi
fi
[ -z "$TREE_FAILED" ] || emit error "agy-review.sh: copying the working tree failed"

EXCLUDED=$(sed -n 's/^EXCLUDED_FILE=//p' "$TMP/excluded" | tr '\n' ' ')
if [ "$RC" -eq 3 ]; then
  emit skipped "nothing to send to agy; excluded as sensitive: ${EXCLUDED:-none}"
elif [ "$RC" -ne 0 ]; then
  emit error "agy-review.sh: building the diff failed (exit $RC)"
fi
[ -n "$EXCLUDED" ] && NOTE="${NOTE:+$NOTE; }excluded as sensitive: $EXCLUDED"

{
  printf 'The diff to work on is the file `%s` in the current directory.\n' "$DIFF_NAME"
  if [ -d "$WORK/repo" ]; then
    # A path list lets agy open files directly: its open-ended search tends to reach for denied tools.
    (cd "$WORK/repo" && find . -type f | sed 's|^\./||' | sort) > "$WORK/repo-files.txt"
    printf 'The directory `repo/` is a copy of the working tree the diff applies to, and `repo-files.txt` lists every file in it. Before judging a change, open the surrounding code by path (callers, definitions, tests): pick paths from `repo-files.txt` and read `repo/<path>`.\n'
  else
    printf 'Only the diff is available; surrounding code is not.\n'
  fi
  printf '\n'
  cat "$PROMPT_FILE"
} > "$TMP/prompt.md"

set -- --workdir "$WORK" --prompt-file "$TMP/prompt.md"
[ -n "$SCHEMA" ] && set -- "$@" --schema "$SCHEMA"
[ -n "$TIMEOUT" ] && set -- "$@" --timeout "$TIMEOUT"

bash "$SCRIPT_DIR/agy-exec.sh" "$@" > "$TMP/envelope" &
CHILD=$!
wait "$CHILD"
CHILD=""

python3 "$SCRIPT_DIR/agy-parse.py" --normalize-review --detail "$NOTE" < "$TMP/envelope"
exit 0
