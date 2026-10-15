#!/usr/bin/env bash
# Deterministic tests for pr-watch-poll.sh. Never calls the real gh: a fake `gh`
# on PATH replays fixtures/ and logs every call to $FAKE_GH_LOG.
set -u

TESTS_DIR=$(cd "$(dirname "$0")" && pwd -P)
SKILL_DIR=$(dirname "$TESTS_DIR")
POLL="$SKILL_DIR/scripts/pr-watch-poll.sh"
FIXTURES="$TESTS_DIR/fixtures"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n     %s\n' "$1" "${2:-}"; }

# check <name> <command...>: passes when the command exits 0.
check() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name" "command failed: $*"; fi
}

# exits_with <name> <code> <command...>: passes when the command exits with exactly <code>.
exits_with() {
  local name=$1 want=$2 got=0
  shift 2
  "$@" >/dev/null 2>&1 || got=$?
  if [ "$got" -eq "$want" ]; then pass "$name"; else fail "$name" "exit $got, wanted $want: $*"; fi
}

# json_is <name> <json> <python expression over d>: passes when the expression is truthy.
json_is() {
  local name=$1 json=$2 expr=$3 out
  if out=$(printf '%s' "$json" | python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
sys.exit(0 if eval(sys.argv[1]) else 1)' "$expr" 2>&1); then
    pass "$name"
  else
    fail "$name" "expr: $expr | got: $(printf '%s' "$json" | cut -c1-300) $out"
  fi
}

ROOT_TMP=$(mktemp -d "${TMPDIR:-/tmp}/pr-watch-tests.XXXXXX") && [ -d "$ROOT_TMP" ] || {
  echo "cannot create a temp directory; tests not run" >&2
  exit 2
}
ROOT_TMP=$(cd "$ROOT_TMP" && pwd -P)
trap 'rm -rf "$ROOT_TMP"' EXIT

# --- fake gh ------------------------------------------------------------------
# Dispatches on the argument list, prints the fixture named by FAKE_GH_* and
# appends one line per call to $FAKE_GH_LOG so tests can count side effects.
FAKEBIN="$ROOT_TMP/fakebin"
mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/gh" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_GH_LOG"
[ "${FAKE_GH_EXIT:-0}" -eq 0 ] || { echo "gh: simulated failure" >&2; exit "$FAKE_GH_EXIT"; }
# Keep the body a post would send, so tests can look at it.
for a in "$@"; do
  case "$a" in body=@*) cp "${a#body=@}" "$FAKE_GH_LOG.body" ;; esac
done
prev=""
for a in "$@"; do
  [ "$prev" = "--body-file" ] && cp "$a" "$FAKE_GH_LOG.body"
  prev=$a
done
args="$*"
case "$args" in
  "repo view"*) echo "acme/widgets" ;;
  "pr view"*) cat "$FAKE_GH_PR_VIEW" ;;
  "api graphql"*resolveReviewThread*)
    [ "${FAKE_GH_RESOLVE_EXIT:-0}" -eq 0 ] || { echo "gh: simulated resolve failure" >&2; exit "$FAKE_GH_RESOLVE_EXIT"; }
    echo '{"data":{"resolveReviewThread":{"thread":{"isResolved":true}}}}' ;;
  "api graphql"*"after="*) cat "$FAKE_GH_THREADS_PAGE2" ;;
  "api graphql"*) cat "$FAKE_GH_THREADS" ;;
  *"/issues/"*"/comments"*) cat "$FAKE_GH_ISSUE_COMMENTS" ;;
  *"/pulls/"*"/reviews"*) cat "$FAKE_GH_REVIEWS" ;;
  *"/replies"*) echo '{"id": 999}' ;;
  *"/pulls/"*"/comments"*) cat "$FAKE_GH_PR_COMMENTS" ;;
  "pr comment"*) echo "https://github.com/acme/widgets/pull/42#issuecomment-999" ;;
  *) echo "fake gh: unexpected call: $args" >&2; exit 64 ;;
esac
FAKE
chmod +x "$FAKEBIN/gh"
export PATH="$FAKEBIN:$PATH"
export FAKE_GH_LOG="$ROOT_TMP/gh.log"

fake_reset() {
  : > "$FAKE_GH_LOG"
  rm -f "$FAKE_GH_LOG.body"
  unset FAKE_GH_EXIT FAKE_GH_RESOLVE_EXIT
  export FAKE_GH_PR_VIEW="$FIXTURES/pr-view-open.json"
  export FAKE_GH_THREADS="$FIXTURES/threads.json"
  export FAKE_GH_THREADS_PAGE2="$FIXTURES/threads-page2.json"
  export FAKE_GH_ISSUE_COMMENTS="$FIXTURES/issue-comments.json"
  export FAKE_GH_REVIEWS="$FIXTURES/reviews.json"
  export FAKE_GH_PR_COMMENTS="$FIXTURES/empty-list.json"
}
# gh_calls <pattern>: number of fake gh calls whose argument line matches.
gh_calls() { grep -c -- "$1" "$FAKE_GH_LOG" 2>/dev/null || true; }

STATE="$ROOT_TMP/state.json"
AI="chatgpt-codex-connector[bot]"

# ==============================================================================
echo "# poll"

fake_reset; rm -f "$STATE"
out=$("$POLL" poll --pr 42 --state "$STATE" --ai-logins "$AI")
json_is "AC11 poll prints pr_state / head_sha / checks / new_ai_comments / new_human_comments" "$out" \
  'd["pr_state"] == "OPEN" and d["head_sha"].startswith("abc123") and isinstance(d["checks"], list) and isinstance(d["new_ai_comments"], list) and isinstance(d["new_human_comments"], list)'
json_is "AC11 checks are normalized to name/state (CheckRun and StatusContext)" "$out" \
  '{(c["name"], c["state"]) for c in d["checks"]} == {("ShellCheck","success"),("unit","failure"),("e2e","pending"),("codecov/patch","success")}'
json_is "AC11 checks_summary is failure when any check failed" "$out" 'd["checks_summary"] == "failure"'
json_is "AC11 AI comments: unresolved bot threads + bot review body; resolved thread excluded" "$out" \
  'sorted(c["id"] for c in d["new_ai_comments"]) == [101, 102, 104, 5001]'
json_is "AC11 AI login matches with or without the [bot] suffix" "$out" \
  '{c["author"] for c in d["new_ai_comments"]} == {"chatgpt-codex-connector"}'
json_is "AC11 thread comments carry thread_id / path / line / round" "$out" \
  '(lambda by: by[104]["thread_id"] == "PRRT_bot2" and by[104]["round"] == 2 and by[101]["round"] == 1 and by[101]["path"] == "a.py" and by[101]["line"] == 3)({c["id"]: c for c in d["new_ai_comments"]})'
json_is "AC11 kind is thread / review / issue" "$out" \
  '{c["id"]: c["kind"] for c in d["new_ai_comments"]}[5001] == "review" and {c["id"]: c["kind"] for c in d["new_ai_comments"]}[101] == "thread" and {c["id"]: c["kind"] for c in d["new_human_comments"]}[7001] == "issue"'
json_is "AC8 human comments listed; viewer's own comments and empty review bodies excluded" "$out" \
  'sorted(c["id"] for c in d["new_human_comments"]) == [106, 7001]'
json_is "AC11 poll does not create the state file" "$(printf '{"exists": %s}' "$([ -f "$STATE" ] && echo true || echo false)")" 'd["exists"] is False'

fake_reset; printf '{"pr": 42, "handled": {"101": {"action": "replied"}, "7001": {"action": "seen"}}}\n' > "$STATE"
out=$("$POLL" poll --pr 42 --state "$STATE" --ai-logins "$AI")
json_is "AC11 handled IDs are excluded from new_*" "$out" \
  'sorted(c["id"] for c in d["new_ai_comments"]) == [102, 104, 5001] and sorted(c["id"] for c in d["new_human_comments"]) == [106]'

fake_reset; FAKE_GH_PR_VIEW="$FIXTURES/pr-view-merged.json"; FAKE_GH_THREADS="$FIXTURES/threads-empty.json"
FAKE_GH_ISSUE_COMMENTS="$FIXTURES/empty-list.json"; FAKE_GH_REVIEWS="$FIXTURES/empty-list.json"
out=$("$POLL" poll --pr 42 --state "$STATE" --ai-logins "$AI")
json_is "AC10 merged PR reports pr_state MERGED with empty lists" "$out" \
  'd["pr_state"] == "MERGED" and d["new_ai_comments"] == [] and d["new_human_comments"] == [] and d["checks"] == []'

fake_reset; FAKE_GH_PR_VIEW="$FIXTURES/pr-view-green.json"
out=$("$POLL" poll --pr 42 --state "$STATE" --ai-logins "$AI")
json_is "AC3 checks_summary is success when skipped is the only non-success" "$out" 'd["checks_summary"] == "success"'

fake_reset; FAKE_GH_THREADS="$FIXTURES/threads-page1.json"; FAKE_GH_REVIEWS="$FIXTURES/empty-list.json"
out=$("$POLL" poll --pr 42 --state "$STATE" --ai-logins "$AI")
json_is "AC11 review threads are read across pages" "$out" 'sorted(c["id"] for c in d["new_ai_comments"]) == [201, 202]'
check "AC11 the second page is requested with the first page's cursor" bash -c 'grep -q -- "after=CUR1" "$FAKE_GH_LOG"'

fake_reset; printf '{"pr": 42, "handled": {}}\n' > "$STATE"; before=$(shasum "$STATE")
export FAKE_GH_EXIT=1
out=$("$POLL" poll --pr 42 --state "$STATE" --ai-logins "$AI" 2> "$ROOT_TMP/err") && code=0 || code=$?
check "AC12 gh failure -> exit 1" test "$code" -eq 1
check "AC12 gh failure -> message on stderr" grep -q "gh" "$ROOT_TMP/err"
check "AC12 gh failure -> nothing on stdout" test -z "$out"
check "AC12 gh failure -> state file unchanged" test "$before" = "$(shasum "$STATE")"
unset FAKE_GH_EXIT

fake_reset
exits_with "usage: poll without --pr exits 2" 2 "$POLL" poll --state "$STATE"
exits_with "usage: unknown subcommand exits 2" 2 "$POLL" bogus --pr 42

# ==============================================================================
echo "# init / set"

fake_reset; rm -f "$STATE"
check "AC1 init creates the state file" "$POLL" init --pr 42 --state "$STATE"
json_is "AC1 init records the PR number and an empty handled map" "$(cat "$STATE")" 'd["pr"] == 42 and d["handled"] == {}'
"$POLL" mark --pr 42 --state "$STATE" --id 1 --action seen >/dev/null
check "AC1 init is a no-op when the file exists" "$POLL" init --pr 42 --state "$STATE"
json_is "AC1 init keeps existing entries" "$(cat "$STATE")" '"1" in d["handled"]'
exits_with "init on a state file for another PR exits 1" 1 "$POLL" init --pr 43 --state "$STATE"

check "set stores a scalar" "$POLL" set --pr 42 --state "$STATE" --key last_fix_head --value abc123
"$POLL" set --pr 42 --state "$STATE" --key poll_failures --value 2 >/dev/null
json_is "set keeps earlier keys" "$(cat "$STATE")" 'd["vars"] == {"last_fix_head": "abc123", "poll_failures": "2"}'
out=$("$POLL" poll --pr 42 --state "$STATE" --ai-logins "$AI")
json_is "poll exposes the stored vars" "$out" 'd["vars"]["last_fix_head"] == "abc123"'
exits_with "set without --key exits 2" 2 "$POLL" set --pr 42 --state "$STATE" --value x

# ==============================================================================
echo "# mark"

fake_reset; rm -f "$STATE"
check "mark creates the state file" "$POLL" mark --pr 42 --state "$STATE" --id 7001 --action seen
json_is "mark records id + action" "$(cat "$STATE")" 'd["pr"] == 42 and d["handled"]["7001"]["action"] == "seen"'
check "mark is idempotent" "$POLL" mark --pr 42 --state "$STATE" --id 7001 --action seen
"$POLL" mark --pr 42 --state "$STATE" --id 106 --id 5001 --action seen >/dev/null
json_is "mark keeps previous entries and accepts several --id" "$(cat "$STATE")" \
  'sorted(d["handled"]) == ["106", "5001", "7001"]'
exits_with "mark without --id exits 2" 2 "$POLL" mark --pr 42 --state "$STATE"
exits_with "mark on a state file for another PR exits 1" 1 "$POLL" mark --pr 43 --state "$STATE" --id 1 --action seen

# ==============================================================================
echo "# reply"

fake_reset; rm -f "$STATE"
printf 'Fixed in deadbeef: the list is checked before indexing.\n' > "$ROOT_TMP/body.md"
out=$("$POLL" reply --pr 42 --state "$STATE" --id 101 --kind thread --thread-id PRRT_bot1 --body-file "$ROOT_TMP/body.md" --resolve)
json_is "AC5 reply posts to the thread, resolves it, and reports posted" "$out" 'd["status"] == "posted" and d["id"] == 101 and d["resolved"] is True'
check "AC5 reply used the replies endpoint once" test "$(gh_calls '/pulls/42/comments/101/replies')" -eq 1
check "AC5 reply ran the resolveReviewThread mutation with the thread id" bash -c 'grep -- "resolveReviewThread" "$FAKE_GH_LOG" | grep -q "PRRT_bot1"'
json_is "AC5 reply records the id as replied with its thread" "$(cat "$STATE")" \
  'd["handled"]["101"]["action"] == "replied" and d["handled"]["101"]["resolved"] is True and d["handled"]["101"]["thread_id"] == "PRRT_bot1"'
check "AC15 posted body carries the dedup marker" grep -q -- "<!-- pr-watch:reply-to:101 -->" "$FAKE_GH_LOG.body"
check "AC5 posted body keeps the draft text" grep -q "Fixed in deadbeef" "$FAKE_GH_LOG.body"

out=$("$POLL" reply --pr 42 --state "$STATE" --id 101 --kind thread --thread-id PRRT_bot1 --body-file "$ROOT_TMP/body.md" --resolve)
json_is "AC15 second reply to the same id is skipped" "$out" 'd["status"] == "already-handled"'
check "AC15 no second post" test "$(gh_calls '/replies')" -eq 1

fake_reset; FAKE_GH_PR_COMMENTS="$FIXTURES/pr-comments-marker.json"
out=$("$POLL" reply --pr 42 --state "$STATE" --id 102 --kind thread --thread-id PRRT_bot2 --body-file "$ROOT_TMP/body.md")
json_is "AC15 a reply already on GitHub (state lost) is detected by its marker" "$out" 'd["status"] == "already-posted"'
check "AC15 no post when the marker exists" test "$(gh_calls '/replies')" -eq 0
json_is "AC15 the marker hit is recorded as replied" "$(cat "$STATE")" 'd["handled"]["102"]["action"] == "replied"'

fake_reset; export FAKE_GH_RESOLVE_EXIT=1
out=$("$POLL" reply --pr 42 --state "$STATE" --id 104 --kind thread --thread-id PRRT_bot2 --body-file "$ROOT_TMP/body.md" --resolve) && code=0 || code=$?
json_is "AC5 resolve failure still reports the post, with resolved false" "$out" 'd["status"] == "posted" and d["resolved"] is False'
check "AC5 resolve failure exits 0 (the reply landed)" test "$code" -eq 0
unset FAKE_GH_RESOLVE_EXIT
out=$("$POLL" poll --pr 42 --state "$STATE" --ai-logins "$AI")
json_is "AC5 poll lists threads whose resolve is still pending (102 from the marker hit, 104 from the failed resolve)" "$out" \
  'd["pending_resolves"] == [{"id": "102", "thread_id": "PRRT_bot2"}, {"id": "104", "thread_id": "PRRT_bot2"}]'
out=$("$POLL" reply --pr 42 --state "$STATE" --id 104 --kind thread --thread-id PRRT_bot2 --resolve)
json_is "AC5 re-running reply --resolve (no body file) only resolves" "$out" 'd["status"] == "resolved" and d["resolved"] is True'
check "AC5 the retry posts nothing" test "$(gh_calls '/replies')" -eq 1
check "AC5 the retry ran the mutation again" test "$(gh_calls 'resolveReviewThread')" -eq 2
json_is "AC5 the retry records resolved true" "$(cat "$STATE")" 'd["handled"]["104"]["resolved"] is True'
out=$("$POLL" poll --pr 42 --state "$STATE" --ai-logins "$AI")
json_is "AC5 a resolved thread leaves pending_resolves" "$out" '[e["id"] for e in d["pending_resolves"]] == ["102"]'

fake_reset; FAKE_GH_PR_COMMENTS="$FIXTURES/pr-comments-marker.json"
printf '{"pr": 42, "handled": {}}\n' > "$STATE"
out=$("$POLL" reply --pr 42 --state "$STATE" --id 102 --kind thread --thread-id PRRT_bot2 --body-file "$ROOT_TMP/body.md" --resolve)
json_is "AC15 marker hit with --resolve resolves the thread" "$out" 'd["status"] == "already-posted" and d["resolved"] is True'
check "AC15 marker hit with --resolve posts nothing" test "$(gh_calls '/replies')" -eq 0
check "AC15 marker hit with --resolve ran the mutation" test "$(gh_calls 'resolveReviewThread')" -eq 1

fake_reset
out=$("$POLL" reply --pr 42 --state "$STATE" --id 5001 --kind review --body-file "$ROOT_TMP/body.md")
json_is "AC6 reply to a review/issue comment goes through gh pr comment" "$out" 'd["status"] == "posted" and d["resolved"] is False'
check "AC6 gh pr comment called once" test "$(gh_calls '^pr comment')" -eq 1
check "AC6 no resolve for non-thread kinds" test "$(gh_calls 'resolveReviewThread')" -eq 0

fake_reset; before=$(shasum "$STATE"); export FAKE_GH_EXIT=1
exits_with "AC12 reply: gh failure -> exit 1" 1 "$POLL" reply --pr 42 --state "$STATE" --id 777 --kind thread --thread-id PRRT_new --body-file "$ROOT_TMP/body.md"
check "AC12 reply: gh failure leaves the state unchanged (id not marked)" test "$before" = "$(shasum "$STATE")"
unset FAKE_GH_EXIT

fake_reset
fake_reset; printf '{"pr": 43, "handled": {}}\n' > "$ROOT_TMP/other-pr.json"
exits_with "reply with another PR's state file exits 1" 1 "$POLL" reply --pr 42 --state "$ROOT_TMP/other-pr.json" --id 555 --kind thread --thread-id PRRT_x --body-file "$ROOT_TMP/body.md"
check "reply with another PR's state file posts nothing" test "$(gh_calls '/replies')" -eq 0
printf 'not json\n' > "$ROOT_TMP/broken.json"
exits_with "reply with a broken state file exits 1" 1 "$POLL" reply --pr 42 --state "$ROOT_TMP/broken.json" --id 555 --kind thread --thread-id PRRT_x --body-file "$ROOT_TMP/body.md"
check "reply with a broken state file posts nothing" test "$(gh_calls '/replies')" -eq 0

fake_reset; printf '{"pr": 42, "handled": {}}\n' > "$STATE"
python3 "$SKILL_DIR/scripts/pr-watch.py" mark --pr 42 --state "$STATE" --id 10 --action replied --resolved false --thread-id T10 --kind thread
python3 "$SKILL_DIR/scripts/pr-watch.py" mark --pr 42 --state "$STATE" --id 2 --action replied --resolved false --thread-id T2 --kind thread
out=$("$POLL" poll --pr 42 --state "$STATE" --ai-logins "$AI")
json_is "pending_resolves is ordered numerically (2 before 10)" "$out" '[e["id"] for e in d["pending_resolves"]] == ["2", "10"]'

exits_with "reply with an empty body file exits 2" 2 "$POLL" reply --pr 42 --state "$STATE" --id 888 --kind thread --thread-id PRRT_new --body-file /dev/null
exits_with "reply without a body file for a new id exits 2" 2 "$POLL" reply --pr 42 --state "$STATE" --id 889 --kind thread --thread-id PRRT_new
exits_with "reply kind=thread without --thread-id exits 2" 2 "$POLL" reply --pr 42 --state "$STATE" --id 102 --kind thread --body-file "$ROOT_TMP/body.md"

# ==============================================================================
echo "# static"

if command -v shellcheck >/dev/null 2>&1; then
  check "AC13 shellcheck --severity=warning on pr-watch scripts and tests" \
    shellcheck --severity=warning "$POLL" "$TESTS_DIR/run-tests.sh"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
