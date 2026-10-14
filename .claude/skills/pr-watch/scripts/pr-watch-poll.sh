#!/usr/bin/env bash
# gh side of /pr-watch: fetch a pull request's checks and comments, remember which
# comments were handled, and post replies without ever answering one twice.
# The state file is the only memory, so a restarted session continues where it left.
#
# Usage:
#   pr-watch-poll.sh init  --pr N --state FILE
#   pr-watch-poll.sh poll  --pr N --state FILE [--ai-logins a,b]
#   pr-watch-poll.sh mark  --pr N --state FILE --id ID [--id ID...] --action seen|replied
#   pr-watch-poll.sh set   --pr N --state FILE --key KEY --value VALUE
#   pr-watch-poll.sh reply --pr N --state FILE --id ID --kind thread|review|issue
#                          [--thread-id NODE_ID] --body-file FILE [--resolve]
#
# Exit codes: 0 ok, 1 gh or runtime failure (state untouched), 2 usage.
# `poll` never writes. `reply` posts at most once per id: the body carries the
# marker "<!-- pr-watch:reply-to:ID -->" and GitHub is searched for it before
# posting, so a crash between the post and the state write cannot double-post.
# Re-running `reply --resolve` for an id whose thread is still open only resolves
# (no --body-file needed); `poll` lists such ids under "pending_resolves".
#
# Limits: review threads are read 100 per page up to 20 pages (2,000 threads);
# comments inside one thread are capped at the first 100.
set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
PY="$SCRIPT_DIR/pr-watch.py"

usage() { echo "pr-watch-poll.sh: $1" >&2; echo "see the header of $0 for usage" >&2; exit 2; }
fail() { echo "pr-watch-poll.sh: $1" >&2; exit 1; }

CMD=${1:-}
[ -n "$CMD" ] || usage "missing subcommand"
shift
case "$CMD" in init | poll | mark | set | reply) ;; *) usage "unknown subcommand: $CMD" ;; esac

PR="" STATE="" AI_LOGINS="chatgpt-codex-connector[bot]" ACTION="" KIND="" THREAD_ID="" BODY_FILE="" RESOLVE=0 KEY="" VALUE=""
IDS=()
while [ $# -gt 0 ]; do
  if [ "$1" = "--resolve" ]; then RESOLVE=1; shift; continue; fi
  [ $# -ge 2 ] || usage "missing value for $1"
  case "$1" in
    --pr) PR=$2 ;;
    --state) STATE=$2 ;;
    --ai-logins) AI_LOGINS=$2 ;;
    --id) IDS+=("$2") ;;
    --action) ACTION=$2 ;;
    --kind) KIND=$2 ;;
    --thread-id) THREAD_ID=$2 ;;
    --body-file) BODY_FILE=$2 ;;
    --key) KEY=$2 ;;
    --value) VALUE=$2 ;;
    *) usage "unknown argument $1" ;;
  esac
  shift 2
done

case "$PR" in '' | *[!0-9]*) usage "--pr must be a number" ;; esac
[ -n "$STATE" ] || usage "--state is required"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/pr-watch.XXXXXX") || fail "mktemp failed"
trap 'rm -rf "$TMP"' EXIT

# gh_run <outfile> <gh args...>: stop on the first gh failure so a partial
# snapshot is never mistaken for "no comments".
gh_run() {
  local out=$1
  shift
  gh "$@" > "$out" 2> "$TMP/gh.err" || fail "gh $1 $2 failed: $(tail -1 "$TMP/gh.err")"
}

repo_slug() {
  gh_run "$TMP/repo" repo view --json nameWithOwner -q .nameWithOwner
  REPO=$(tr -d '[:space:]' < "$TMP/repo")
  [ -n "$REPO" ] || fail "cannot determine the repository (gh repo view returned nothing)"
  OWNER=${REPO%%/*}
  NAME=${REPO#*/}
}

THREADS_QUERY='query($owner:String!,$name:String!,$number:Int!,$after:String){
  viewer{login}
  repository(owner:$owner,name:$name){pullRequest(number:$number){
    reviewThreads(first:100,after:$after){
      pageInfo{hasNextPage endCursor}
      nodes{id isResolved comments(first:100){nodes{databaseId author{login} body path line createdAt url}}}}}}}'

fetch_threads() {  # writes one JSON document per page to $TMP/threads
  local after="" page=0
  : > "$TMP/threads"
  while :; do
    page=$((page + 1))
    [ "$page" -le 20 ] || fail "review threads: more than 20 pages (2,000 threads); not supported"
    if [ -n "$after" ]; then
      gh_run "$TMP/threads.page" api graphql -f query="$THREADS_QUERY" -F owner="$OWNER" -F name="$NAME" -F number="$PR" -F after="$after"
    else
      gh_run "$TMP/threads.page" api graphql -f query="$THREADS_QUERY" -F owner="$OWNER" -F name="$NAME" -F number="$PR"
    fi
    cat "$TMP/threads.page" >> "$TMP/threads"
    after=$(python3 -c '
import json, sys
info = json.load(open(sys.argv[1]))["data"]["repository"]["pullRequest"]["reviewThreads"]["pageInfo"]
print(info["endCursor"] if info.get("hasNextPage") else "")' "$TMP/threads.page" 2>/dev/null) || fail "unexpected graphql response"
    [ -n "$after" ] || break
  done
}

do_poll() {
  repo_slug
  gh_run "$TMP/pr" pr view "$PR" --json number,state,url,headRefOid,reviewDecision,statusCheckRollup
  fetch_threads
  gh_run "$TMP/issues" api --paginate "repos/$REPO/issues/$PR/comments"
  gh_run "$TMP/reviews" api --paginate "repos/$REPO/pulls/$PR/reviews"
  python3 "$PY" merge --pr "$PR" --pr-view "$TMP/pr" --threads "$TMP/threads" \
    --issues "$TMP/issues" --reviews "$TMP/reviews" --state "$STATE" --ai-logins "$AI_LOGINS"
}

do_mark() {
  [ "${#IDS[@]}" -gt 0 ] || usage "mark needs at least one --id"
  case "$ACTION" in seen | replied) ;; *) usage "--action must be seen or replied" ;; esac
  local args=()
  for id in "${IDS[@]}"; do args+=(--id "$id"); done
  python3 "$PY" mark --pr "$PR" --state "$STATE" "${args[@]}" --action "$ACTION"
}

do_set() {
  [ -n "$KEY" ] || usage "set needs --key"
  python3 "$PY" set --pr "$PR" --state "$STATE" --key "$KEY" --value "$VALUE"
}

resolve_thread() {  # $1: thread node id. Prints true/false; never exits.
  if gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' \
       -F id="$1" > "$TMP/resolve" 2> "$TMP/gh.err"; then
    echo true
  else
    echo "pr-watch-poll.sh: resolveReviewThread failed for $1: $(tail -1 "$TMP/gh.err")" >&2
    echo false
  fi
}

do_reply() {
  [ "${#IDS[@]}" -eq 1 ] || usage "reply needs exactly one --id"
  local id=${IDS[0]} entry marker resolved handled
  case "$KIND" in thread | review | issue) ;; *) usage "--kind must be thread, review or issue" ;; esac
  [ "$KIND" != thread ] || [ -n "$THREAD_ID" ] || usage "--thread-id is required for --kind thread"
  marker="<!-- pr-watch:reply-to:$id -->"

  # 0 = handled, 3 = not handled, anything else = the state file is unreadable or
  # belongs to another PR; never post on a state we cannot trust.
  entry=$(python3 "$PY" is-handled --pr "$PR" --state "$STATE" --id "$id") && handled=0 || handled=$?
  [ "$handled" -eq 0 ] || [ "$handled" -eq 3 ] || fail "cannot read state file $STATE"
  if [ "$handled" -eq 0 ]; then
    # Already answered, so no body is needed: the only thing left to do is a
    # resolve that failed last time.
    if [ "$RESOLVE" -eq 1 ] && [ "$KIND" = thread ] && printf '%s' "$entry" | grep -q '"resolved": false'; then
      resolved=$(resolve_thread "$THREAD_ID")
      [ "$resolved" = true ] || fail "resolve retry failed for $id"
      python3 "$PY" mark --pr "$PR" --state "$STATE" --id "$id" --action replied --resolved true || fail "state update failed"
      printf '{"status":"resolved","id":%s,"kind":"%s","resolved":true}\n' "$id" "$KIND"
      return 0
    fi
    printf '{"status":"already-handled","id":%s,"kind":"%s"}\n' "$id" "$KIND"
    return 0
  fi
  [ -n "$BODY_FILE" ] && [ -s "$BODY_FILE" ] || usage "--body-file must name a non-empty file"

  repo_slug
  # Look for the marker on GitHub first: a reply posted by an earlier run that
  # died before writing the state must not be posted again.
  if [ "$KIND" = thread ]; then
    gh_run "$TMP/existing" api --paginate "repos/$REPO/pulls/$PR/comments"
  else
    gh_run "$TMP/existing" api --paginate "repos/$REPO/issues/$PR/comments"
  fi
  if python3 "$PY" find-marker --file "$TMP/existing" --marker "$marker"; then
    resolved=false
    if [ "$RESOLVE" -eq 1 ] && [ "$KIND" = thread ]; then
      resolved=$(resolve_thread "$THREAD_ID")
    fi
    python3 "$PY" mark --pr "$PR" --state "$STATE" --id "$id" --action replied --resolved "$resolved" \
      --thread-id "$THREAD_ID" --kind "$KIND" || fail "state update failed"
    printf '{"status":"already-posted","id":%s,"kind":"%s","resolved":%s}\n' "$id" "$KIND" "$resolved"
    return 0
  fi

  { cat "$BODY_FILE"; printf '\n\n%s\n' "$marker"; } > "$TMP/body.md"
  if [ "$KIND" = thread ]; then
    gh_run "$TMP/post" api -X POST "repos/$REPO/pulls/$PR/comments/$id/replies" -F body=@"$TMP/body.md"
  else
    gh_run "$TMP/post" pr comment "$PR" --body-file "$TMP/body.md"
  fi

  resolved=false
  if [ "$RESOLVE" -eq 1 ] && [ "$KIND" = thread ]; then
    resolved=$(resolve_thread "$THREAD_ID")
  fi
  python3 "$PY" mark --pr "$PR" --state "$STATE" --id "$id" --action replied --resolved "$resolved" \
    --thread-id "$THREAD_ID" --kind "$KIND" || fail "state update failed after posting"
  printf '{"status":"posted","id":%s,"kind":"%s","resolved":%s}\n' "$id" "$KIND" "$resolved"
}

case "$CMD" in
  init) python3 "$PY" init --pr "$PR" --state "$STATE" ;;
  poll) do_poll ;;
  mark) do_mark ;;
  set) do_set ;;
  reply) do_reply ;;
esac
