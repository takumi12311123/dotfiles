#!/usr/bin/env bash
# Deterministic tests for the agy wrapper scripts. Never calls the real agy:
# a fake `agy` on PATH replays recorded outputs from fixtures/.
set -u

TESTS_DIR=$(cd "$(dirname "$0")" && pwd -P)
SKILL_DIR=$(dirname "$TESTS_DIR")
SCRIPTS="$SKILL_DIR/scripts"
FIXTURES="$TESTS_DIR/fixtures"
REPO=$(git -C "$SKILL_DIR" rev-parse --show-toplevel)

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

# Abort before anything else if the temp dir is missing: with an empty ROOT_TMP the
# `cd` below would stay in the caller's directory and the trap would delete it.
ROOT_TMP=$(mktemp -d "${TMPDIR:-/tmp}/agy-tests.XXXXXX") && [ -d "$ROOT_TMP" ] || {
  echo "cannot create a temp directory; tests not run" >&2
  exit 2
}
ROOT_TMP=$(cd "$ROOT_TMP" && pwd -P)
trap 'rm -rf "$ROOT_TMP"' EXIT

# --- fake agy -----------------------------------------------------------------
FAKEBIN="$ROOT_TMP/fakebin"
mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/agy" <<'FAKE'
#!/usr/bin/env bash
pwd -P > "$FAKE_AGY_LOG.cwd"
echo run >> "$FAKE_AGY_LOG.runs"
# FAKE_AGY_FIRST: fixture for the first run only (to exercise the retry).
if [ -n "${FAKE_AGY_FIRST:-}" ] && [ "$(wc -l < "$FAKE_AGY_LOG.runs")" -eq 1 ]; then FAKE_AGY_FIXTURE=$FAKE_AGY_FIRST; fi
printf '%s\0' "$@" > "$FAKE_AGY_LOG.args"
[ -n "${FAKE_AGY_COPY:-}" ] && cp -R . "$FAKE_AGY_COPY"
[ -n "${FAKE_AGY_SLEEP:-}" ] && sleep "$FAKE_AGY_SLEEP"
cat "$FAKE_AGY_FIXTURE.json"
cat "$FAKE_AGY_FIXTURE.stderr" >&2
exit "${FAKE_AGY_EXIT:-0}"
FAKE
chmod +x "$FAKEBIN/agy"
# Fake gh: `gh pr diff` prints $FAKE_GH_DIFF, `gh pr view` prints $FAKE_GH_HEAD.
cat > "$FAKEBIN/gh" <<'FAKE'
#!/usr/bin/env bash
[ "${FAKE_GH_EXIT:-0}" -eq 0 ] || { echo "gh: simulated failure" >&2; exit "$FAKE_GH_EXIT"; }
case "$1 $2" in
  "pr diff") cat "$FAKE_GH_DIFF" ;;
  "pr view") printf '%s\n' "$FAKE_GH_HEAD" ;;
esac
FAKE
chmod +x "$FAKEBIN/gh"
export FAKE_AGY_LOG="$ROOT_TMP/fake-agy"

# PATH without any agy, for "not installed" cases.
NOAGY_PATH=$(printf '%s' "$PATH" | tr ':' '\n' | while IFS= read -r d; do
  [ -x "$d/agy" ] || printf '%s:' "$d"
done)
NOAGY_PATH=${NOAGY_PATH%:}

fake_reset() {
  rm -f "$FAKE_AGY_LOG.cwd" "$FAKE_AGY_LOG.args" "$FAKE_AGY_LOG.runs"
  unset FAKE_AGY_COPY FAKE_AGY_SLEEP FAKE_AGY_EXIT FAKE_AGY_FIRST FAKE_GH_EXIT
}
fake_called() { [ -f "$FAKE_AGY_LOG.args" ]; }
# fake_arg_after <flag>: prints the argument that followed <flag>.
fake_arg_after() {
  python3 -c '
import sys
a = open(sys.argv[1], "rb").read().split(b"\0")
i = a.index(sys.argv[2].encode())
sys.stdout.write(a[i + 1].decode())' "$FAKE_AGY_LOG.args" "$1"
}

parse() { # parse <fixture> <exit-code> [extra args...]
  local fx=$1 code=$2
  shift 2
  python3 "$SCRIPTS/agy-parse.py" --raw "$FIXTURES/$fx.json" --stderr "$FIXTURES/$fx.stderr" --exit-code "$code" "$@"
}

# new_repo <dir>: a git repo with one commit containing a.py, gone.py and .gitignore.
new_repo() {
  local dir=$1
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    git init -q
    git config user.email t@example.com
    git config user.name t
    printf 'def q(db, name):\n    return 1\n' > a.py
    printf 'gone = True\n' > gone.py
    printf 'ignored.log\n' > .gitignore
    git add . && git commit -qm init
  )
}

# ==============================================================================
echo "# agy-parse.py"

out=$(parse success-structured-no-issues 0 --schema-mode)
json_is "AC1 structured success -> completed with the structured object" "$out" \
  'd["status"] == "completed" and d["result"]["issues"] == [] and d["result"]["summary"] == "問題なし"'

out=$(parse timeout-empty 0 --schema-mode)
json_is "AC2 exit 0 + SUCCESS + empty response + 'print timeout' on stderr -> timeout" "$out" \
  'd["status"] == "timeout" and d["result"] is None'

out=$(parse timeout-empty 0)
json_is "AC2 same output without a schema -> timeout" "$out" 'd["status"] == "timeout"'

out=$(parse success-text-markdown 0)
json_is "AC2b text success -> completed, result round-trips newlines/quotes/Japanese" "$out" \
  "d['status'] == 'completed' and d['result'] == json.load(open('$FIXTURES/success-text-markdown.json'))['response']"

out=$(parse success-text-empty 0)
json_is "AC2b text mode with empty response is not completed" "$out" \
  'd["status"] == "error" and d["result"] is None and d["detail"] != ""'

out=$(parse error-bad-model 1 --schema-mode)
json_is "AC3 exit 1 + ERROR -> error with the agy error text" "$out" \
  'd["status"] == "error" and "no-such-model" in d["detail"]'

out=$(parse success-structured-missing 0 --schema-mode)
json_is "AC3 SUCCESS without structured_output in schema mode -> error" "$out" \
  'd["status"] == "error" and "structured_output" in d["detail"]'

out=$(parse denied-empty 0)
json_is "AC3 denied action with empty response -> error naming the denied action" "$out" \
  'd["status"] == "error" and "RunCommand" in d["detail"]'

out=$(parse not-json 0 --schema-mode)
json_is "AC3 non-JSON output -> error" "$out" 'd["status"] == "error" and d["detail"] != ""'

out=$(parse success-with-preamble 0 --schema-mode)
json_is "JSON on the last line after non-JSON noise is still parsed" "$out" 'd["status"] == "completed"'

out=$(parse error-quota 1 --schema-mode)
json_is "AC4 RESOURCE_EXHAUSTED / quota error -> quota" "$out" \
  'd["status"] == "quota" and "RESOURCE_EXHAUSTED" in d["detail"]'

# ==============================================================================
echo "# agy-exec.sh"

WD="$ROOT_TMP/workdir"
mkdir -p "$WD"
printf 'Say hello.\n' > "$ROOT_TMP/prompt.md"

fake_reset
export FAKE_AGY_FIXTURE="$FIXTURES/success-structured-no-issues"
out=$(PATH="$FAKEBIN:$PATH" bash "$SCRIPTS/agy-exec.sh" --workdir "$WD" --prompt-file "$ROOT_TMP/prompt.md" \
  --schema "$SKILL_DIR/../codex-review/review-schema.json" --timeout 42s)
json_is "AC1 agy-exec returns the completed envelope on one line" "$out" 'd["status"] == "completed"'
check "AC2 agy-exec passes --print-timeout 42s" test "$(fake_arg_after --print-timeout)" = "42s"
check "AC2 agy-exec passes --output-format json" test "$(fake_arg_after --output-format)" = "json"
check "AC2 agy runs inside the given workdir" test "$(cat "$FAKE_AGY_LOG.cwd")" = "$WD"
prompt=$(fake_arg_after -p)
case "$prompt" in
  "NEVER run shell"*"Say hello."*) pass "AC2 prompt starts with the no-shell constraint and keeps the task" ;;
  *) fail "AC2 prompt starts with the no-shell constraint and keeps the task" "$(printf '%s' "$prompt" | head -c 120)" ;;
esac

fake_reset
export FAKE_AGY_FIXTURE="$FIXTURES/success-text-markdown"
export FAKE_AGY_FIRST="$FIXTURES/denied-empty"
out=$(PATH="$FAKEBIN:$PATH" bash "$SCRIPTS/agy-exec.sh" --workdir "$WD" --prompt-file "$ROOT_TMP/prompt.md")
json_is "a denied-tool empty run is retried once and the second result is used" "$out" 'd["status"] == "completed"'
check "the retry ran agy exactly twice" test "$(wc -l < "$FAKE_AGY_LOG.runs" | tr -d ' ')" = "2"

fake_reset
export FAKE_AGY_FIXTURE="$FIXTURES/denied-empty"
out=$(PATH="$FAKEBIN:$PATH" bash "$SCRIPTS/agy-exec.sh" --workdir "$WD" --prompt-file "$ROOT_TMP/prompt.md")
json_is "two denied-tool runs in a row -> error" "$out" 'd["status"] == "error" and "RunCommand" in d["detail"]'
check "no third attempt" test "$(wc -l < "$FAKE_AGY_LOG.runs" | tr -d ' ')" = "2"

fake_reset
export FAKE_AGY_FIXTURE="$FIXTURES/timeout-empty"
out=$(PATH="$FAKEBIN:$PATH" bash "$SCRIPTS/agy-exec.sh" --workdir "$WD" --prompt-file "$ROOT_TMP/prompt.md")
check "a timeout is not retried" test "$(wc -l < "$FAKE_AGY_LOG.runs" | tr -d ' ')" = "1"

fake_reset
export FAKE_AGY_FIXTURE="$FIXTURES/success-text-markdown"
out=$(PATH="$FAKEBIN:$PATH" bash "$SCRIPTS/agy-exec.sh" --prompt "Search the web for X.")
json_is "--prompt without --workdir -> completed" "$out" 'd["status"] == "completed"'
check "--prompt without --workdir runs agy in a fresh empty directory" test "$(basename "$(cat "$FAKE_AGY_LOG.cwd")")" = "empty"
case "$(fake_arg_after -p)" in
  "NEVER run shell"*"Search the web for X.") pass "--prompt text is sent after the constraint" ;;
  *) fail "--prompt text is sent after the constraint" "" ;;
esac
out=$(bash "$SCRIPTS/agy-exec.sh" --timeout 5s)
json_is "neither --prompt nor --prompt-file -> error" "$out" 'd["status"] == "error"'

out=$(bash "$SCRIPTS/agy-exec.sh" --workdir "$WD" --prompt-file; echo "exit=$?")
json_is "option without its value -> error envelope" "${out%exit=*}" 'd["status"] == "error" and "--prompt-file" in d["detail"]'
check "option without its value still exits 0" test "${out##*exit=}" = "0"

fake_reset
out=$(PATH="$NOAGY_PATH" bash "$SCRIPTS/agy-exec.sh" --workdir "$WD" --prompt-file "$ROOT_TMP/prompt.md"; echo "exit=$?")
json_is "AC3 agy missing from PATH -> error envelope" "${out%exit=*}" 'd["status"] == "error" and "not found" in d["detail"]'
check "AC3 agy-exec still exits 0 when agy is missing" test "${out##*exit=}" = "0"

# ==============================================================================
echo "# agy-snapshot.sh"

R="$ROOT_TMP/repo"
new_repo "$R"
SUB="$ROOT_TMP/subsrc"
new_repo "$SUB"
printf 'SUBMODULE_BODY = 1\n' > "$SUB/inner.py"
(cd "$SUB" && git add . && git commit -qm inner)
printf 'OUTSIDE_SECRET=1\n' > "$ROOT_TMP/outside.txt"
mkdir "$ROOT_TMP/outside-dir" && printf 'OUTSIDE_SECRET_VIA_DIR = 1\n' > "$ROOT_TMP/outside-dir/mod.py"
(
  cd "$R" || exit 1
  git -c protocol.file.allow=always submodule add -q "$SUB" sub
  ln -s a.py tracked-link
  printf 'plain = 1\n' > becomes-link.py
  printf 'dash = 1\n' > ./--version
  git add -- ./--version
  mkdir pkg && printf 'IN_REPO_PKG = 1\n' > pkg/mod.py
  git add tracked-link becomes-link.py pkg
  git commit -qm sub
  printf 'def q(db, name):\n    return 2  # CHANGED_MARK\n' > a.py
  rm gone.py
  printf 'NEW_FILE_MARK = 1\n' > new.py
  printf 'DASH_UNTRACKED_MARK = 1\n' > ./--help
  printf 'DASH_TRACKED_CHANGED = 1\n' >> ./--version
  printf 'ENV_SECRET=hunter2\n' > .env
  printf 'PEM_SECRET_BODY\n' > secret.pem
  printf 'IGNORED_BODY\n' > ignored.log
  ln -s "$ROOT_TMP/outside.txt" link-out
  ln -sf "$ROOT_TMP/SECRET_LINK_TARGET" tracked-link
  rm becomes-link.py && ln -s "$ROOT_TMP/UNSTAGED_LINK_TARGET" becomes-link.py
  rm -rf pkg && ln -s "$ROOT_TMP/outside-dir" pkg
  printf 'SUBMODULE_DIRTY = 1\n' >> sub/inner.py
)

SNAP="$ROOT_TMP/snap"
(cd "$R" && bash "$SCRIPTS/agy-snapshot.sh" tree "$SNAP/repo" 2>"$ROOT_TMP/tree.err")
check "AC6 tree exits 0 with deleted file, symlink and submodule present" test "$?" = "0"
check "AC6 copy has the modified tracked file" grep -q CHANGED_MARK "$SNAP/repo/a.py"
check "AC6 copy has the untracked new file" grep -q NEW_FILE_MARK "$SNAP/repo/new.py"
check "copy has an untracked file named --help" grep -q DASH_UNTRACKED_MARK "$SNAP/repo/--help"
check "copy has a tracked file named --version" grep -q DASH_TRACKED_CHANGED "$SNAP/repo/--version"
for missing in .env secret.pem ignored.log link-out tracked-link becomes-link.py pkg/mod.py gone.py sub/inner.py; do
  if [ -e "$SNAP/repo/$missing" ] || [ -L "$SNAP/repo/$missing" ]; then
    fail "AC6 copy does not contain $missing" "found"
  else
    pass "AC6 copy does not contain $missing"
  fi
done
if grep -rq 'OUTSIDE_SECRET\|ENV_SECRET\|PEM_SECRET_BODY\|IGNORED_BODY' "$SNAP" 2>/dev/null; then
  fail "AC6 no excluded content anywhere in the copy" "leaked"
else
  pass "AC6 no excluded content anywhere in the copy"
fi

(cd "$R" && bash "$SCRIPTS/agy-snapshot.sh" diff "$ROOT_TMP/review.diff" 2>"$ROOT_TMP/diff.err")
check "AC7 diff exits 0" test "$?" = "0"
check "AC7 diff has the modification" grep -q '^+.*CHANGED_MARK' "$ROOT_TMP/review.diff"
check "AC7 diff has the deletion" grep -q '^-gone = True' "$ROOT_TMP/review.diff"
check "AC7 diff has the untracked file as an addition" grep -q '^+NEW_FILE_MARK = 1' "$ROOT_TMP/review.diff"
check "diff covers files named --help and --version" test "$(grep -c '^+DASH_' "$ROOT_TMP/review.diff")" = "2"
if grep -q 'ENV_SECRET\|PEM_SECRET_BODY\|SUBMODULE_\|Subproject commit\|IGNORED_BODY\|OUTSIDE_SECRET\|SECRET_LINK_TARGET\|UNSTAGED_LINK_TARGET' "$ROOT_TMP/review.diff"; then
  fail "AC7 diff has no secret, ignored, submodule or symlinked content" "$(grep -n 'ENV_SECRET\|PEM_SECRET_BODY\|SUBMODULE_\|Subproject commit\|IGNORED_BODY\|OUTSIDE_SECRET\|SECRET_LINK_TARGET\|UNSTAGED_LINK_TARGET' "$ROOT_TMP/review.diff" | head -3)"
else
  pass "AC7 diff has no secret, ignored, submodule or symlinked content"
fi
check "AC7 excluded secret names are reported on stderr" grep -q 'EXCLUDED_FILE=.env' "$ROOT_TMP/diff.err"

cat > "$ROOT_TMP/pr3.diff" <<'DIFF'
diff --git a/a.py b/a.py
index 1111111..2222222 100644
--- a/a.py
+++ b/a.py
@@ -1 +1 @@
-old
+KEEP_ME
diff --git a/.env b/.env
index 1111111..2222222 100644
--- a/.env
+++ b/.env
@@ -1 +1 @@
-A=1
+ENV_PATCH_SECRET=2
diff --git a/config/secret.pem b/config/secret.pem
new file mode 100644
--- /dev/null
+++ b/config/secret.pem
@@ -0,0 +1 @@
+PEM_PATCH_SECRET
DIFF
sed -n '/^diff --git a\/.env/,/^diff --git a\/config/p' "$ROOT_TMP/pr3.diff" | sed '$d' > "$ROOT_TMP/pr-env-only.diff"

bash "$SCRIPTS/agy-snapshot.sh" filter-diff "$ROOT_TMP/pr3.diff" "$ROOT_TMP/pr3.out" 2>/dev/null
check "AC8c filter-diff exits 0 when a non-secret patch remains" test "$?" = "0"
check "AC8c filter-diff keeps the a.py patch" grep -q KEEP_ME "$ROOT_TMP/pr3.out"
if grep -q 'ENV_PATCH_SECRET\|PEM_PATCH_SECRET\|secret.pem' "$ROOT_TMP/pr3.out"; then
  fail "AC8c filter-diff drops the .env and secret.pem patches" "leaked"
else
  pass "AC8c filter-diff drops the .env and secret.pem patches"
fi
cat > "$ROOT_TMP/pr-links.diff" <<'DIFF'
diff --git a/a.py b/a.py
index 1111111..2222222 100644
--- a/a.py
+++ b/a.py
@@ -1 +1 @@
-old
+KEEP_ME
diff --git a/link b/link
new file mode 120000
index 0000000..3333333
--- /dev/null
+++ b/link
@@ -0,0 +1 @@
+/home/user/PR_LINK_TARGET
\ No newline at end of file
diff --git a/retarget b/retarget
index 4444444..5555555 120000
--- a/retarget
+++ b/retarget
@@ -1 +1 @@
-old-target
+/home/user/PR_RETARGET
diff --git a/vendor/lib b/vendor/lib
index 6666666..7777777 160000
--- a/vendor/lib
+++ b/vendor/lib
@@ -1 +1 @@
-Subproject commit 6666666
+Subproject commit 7777777
DIFF
bash "$SCRIPTS/agy-snapshot.sh" filter-diff "$ROOT_TMP/pr-links.diff" "$ROOT_TMP/pr-links.out" 2>/dev/null
check "filter-diff keeps the regular patch next to symlink/submodule patches" grep -q KEEP_ME "$ROOT_TMP/pr-links.out"
if grep -q 'PR_LINK_TARGET\|PR_RETARGET\|Subproject commit' "$ROOT_TMP/pr-links.out"; then
  fail "filter-diff drops symlink (120000) and submodule (160000) patches" "$(grep -n 'PR_LINK_TARGET\|PR_RETARGET\|Subproject' "$ROOT_TMP/pr-links.out" | head -3)"
else
  pass "filter-diff drops symlink (120000) and submodule (160000) patches"
fi
bash "$SCRIPTS/agy-snapshot.sh" filter-diff "$ROOT_TMP/pr-env-only.diff" "$ROOT_TMP/pr-env.out" 2>/dev/null
check "AC8c filter-diff exits 3 when nothing reviewable remains" test "$?" = "3"

# ==============================================================================
echo "# agy-review.sh"

RUN_TMP="$ROOT_TMP/run-tmp" # TMPDIR for the script under test, so leftovers are observable
review() { # review <repo> [args...]  (runs with the fake agy and an isolated TMPDIR)
  local repo=$1
  shift
  rm -rf "$RUN_TMP" && mkdir -p "$RUN_TMP"
  (cd "$repo" && PATH="$FAKEBIN:$PATH" TMPDIR="$RUN_TMP" bash "$SCRIPTS/agy-review.sh" "$@")
}
leftovers() { find "$RUN_TMP" -mindepth 1 | wc -l | tr -d ' '; }

fake_reset
export FAKE_AGY_FIXTURE="$FIXTURES/success-structured-ok-true-blocking"
export FAKE_AGY_COPY="$ROOT_TMP/seen-local"
out=$(review "$R")
json_is "AC5 ok:true with a blocking issue is rewritten to ok:false" "$out" \
  'd["status"] == "completed" and d["result"]["ok"] is False and len(d["result"]["issues"]) == 1'
check "local mode: agy sees review.diff in its working directory" grep -q CHANGED_MARK "$ROOT_TMP/seen-local/review.diff"
check "local mode: agy sees the working-tree copy under repo/" grep -q NEW_FILE_MARK "$ROOT_TMP/seen-local/repo/new.py"
check "local mode: no secret file in what agy sees" test ! -e "$ROOT_TMP/seen-local/repo/.env"
check "AC9 temp dir removed after a successful run" test "$(leftovers)" = "0"

fake_reset
export FAKE_AGY_FIXTURE="$FIXTURES/success-structured-no-issues"
out=$(review "$R")
json_is "AC5 no blocking issue -> ok:true" "$out" 'd["status"] == "completed" and d["result"]["ok"] is True'

U="$ROOT_TMP/repo-untracked"
new_repo "$U"
printf 'ONLY_UNTRACKED_MARK = 1\n' > "$U/brand_new.py"
fake_reset
export FAKE_AGY_COPY="$ROOT_TMP/seen-untracked"
out=$(review "$U")
json_is "AC8 untracked-only change is reviewed, not skipped" "$out" 'd["status"] == "completed"'
check "AC8 untracked file content reaches review.diff" grep -q '^+ONLY_UNTRACKED_MARK = 1' "$ROOT_TMP/seen-untracked/review.diff"

E="$ROOT_TMP/repo-env"
new_repo "$E"
printf 'TOKEN=abc\n' > "$E/.env"
fake_reset
out=$(review "$E")
json_is "AC8 .env-only change -> skipped with the excluded name in detail" "$out" \
  'd["status"] == "skipped" and d["result"] is None and ".env" in d["detail"]'
if fake_called; then fail "AC8 agy is not started when everything is excluded" "fake agy ran"; else pass "AC8 agy is not started when everything is excluded"; fi

C="$ROOT_TMP/repo-clean"
new_repo "$C"
HEAD_SHA=$(git -C "$C" rev-parse HEAD)
export FAKE_GH_DIFF="$ROOT_TMP/pr3.diff" FAKE_GH_HEAD="$HEAD_SHA"
fake_reset
export FAKE_AGY_COPY="$ROOT_TMP/seen-pr-clean"
out=$(review "$C" --pr 7)
json_is "AC8b clean tree at the PR head -> completed" "$out" 'd["status"] == "completed"'
check "AC8b clean tree at the PR head -> working-tree copy attached" test -f "$ROOT_TMP/seen-pr-clean/repo/a.py"
check "AC8c external diff is copied into the workdir as review.diff" grep -q KEEP_ME "$ROOT_TMP/seen-pr-clean/review.diff"
if grep -q 'ENV_PATCH_SECRET\|PEM_PATCH_SECRET' "$ROOT_TMP/seen-pr-clean/review.diff"; then
  fail "AC8c secret patches are not in the copied diff" "leaked"
else
  pass "AC8c secret patches are not in the copied diff"
fi

fake_reset
export FAKE_AGY_COPY="$ROOT_TMP/seen-pr-otherhead"
out=$(FAKE_GH_HEAD=0000000000000000000000000000000000000000 review "$C" --pr 7)
json_is "AC8b HEAD differs from the PR head -> diff only, reason in detail" "$out" \
  'd["status"] == "completed" and d["detail"] != ""'
check "AC8b HEAD differs -> no working-tree copy" test ! -e "$ROOT_TMP/seen-pr-otherhead/repo"

printf '# local edit\n' >> "$C/a.py"
fake_reset
export FAKE_AGY_COPY="$ROOT_TMP/seen-pr-dirty"
out=$(review "$C" --pr 7)
json_is "AC8b uncommitted change -> diff only, reason in detail" "$out" 'd["status"] == "completed" and d["detail"] != ""'
check "AC8b uncommitted change -> no working-tree copy" test ! -e "$ROOT_TMP/seen-pr-dirty/repo"
git -C "$C" checkout -q -- a.py

printf 'x = 1\n' > "$C/untracked.py"
fake_reset
export FAKE_AGY_COPY="$ROOT_TMP/seen-pr-untracked"
out=$(review "$C" --pr 7)
check "AC8b untracked file present -> no working-tree copy" test ! -e "$ROOT_TMP/seen-pr-untracked/repo"
rm "$C/untracked.py"

fake_reset
out=$(FAKE_GH_DIFF="$ROOT_TMP/pr-env-only.diff" review "$C" --pr 7)
json_is "AC8c diff with only secret patches -> skipped" "$out" 'd["status"] == "skipped"'
if fake_called; then fail "AC8c agy is not started for a secrets-only diff" "fake agy ran"; else pass "AC8c agy is not started for a secrets-only diff"; fi

fake_reset
export FAKE_AGY_FIXTURE="$FIXTURES/error-bad-model"
export FAKE_AGY_EXIT=1
out=$(review "$R")
json_is "AC9 agy failure -> error envelope" "$out" 'd["status"] == "error"'
check "AC9 temp dir removed after a failed run" test "$(leftovers)" = "0"

fake_reset
out=$(review "$C" --diff-file "$ROOT_TMP/pr3.diff" --diff-name ../escaped.diff)
json_is "--diff-name with a path component -> error" "$out" 'd["status"] == "error"'
check "--diff-name traversal writes nothing outside the workdir" test "$(find "$RUN_TMP" -name escaped.diff | wc -l | tr -d ' ')" = "0"
out=$(review "$C" --diff-file "$ROOT_TMP/pr3.diff" --prompt-file "$ROOT_TMP/no-such-prompt.md")
json_is "missing --prompt-file -> error" "$out" 'd["status"] == "error" and "prompt file" in d["detail"]'
if fake_called; then fail "agy is not started with a missing prompt file" "fake agy ran"; else pass "agy is not started with a missing prompt file"; fi

X="$ROOT_TMP/repo-unreadable"
new_repo "$X"
printf 'changed = 1\n' >> "$X/a.py"
printf 'secret-free but unreadable\n' > "$X/locked.py"
chmod 000 "$X/locked.py"
fake_reset
out=$(review "$X")
chmod 644 "$X/locked.py"
json_is "a file that cannot be copied -> error, no partial tree" "$out" 'd["status"] == "error"'
if fake_called; then fail "agy is not started after a failed copy" "fake agy ran"; else pass "agy is not started after a failed copy"; fi

NOREPO="$ROOT_TMP/not-a-repo"
mkdir -p "$NOREPO"
fake_reset
out=$(review "$NOREPO")
json_is "outside a git repository -> error, not skipped" "$out" 'd["status"] == "error"'
out=$(review "$NOREPO" --pr; echo "exit=$?")
json_is "agy-review option without its value -> error envelope" "${out%exit=*}" 'd["status"] == "error" and "--pr" in d["detail"]'

fake_reset
export FAKE_GH_EXIT=1
out=$(review "$C" --pr 7)
json_is "gh failure -> error, not skipped and not a local review" "$out" 'd["status"] == "error" and "gh pr diff" in d["detail"]'
if fake_called; then fail "agy is not started when gh fails" "fake agy ran"; else pass "agy is not started when gh fails"; fi
fake_reset
out=$(review "$C" --pr 7 --diff-file "$ROOT_TMP/pr3.diff")
json_is "--pr with --diff-file -> error" "$out" 'd["status"] == "error"'

fake_reset
export FAKE_AGY_FIXTURE="$FIXTURES/success-text-markdown"
export FAKE_AGY_COPY="$ROOT_TMP/seen-summary"
printf 'Summarize pr.diff.\n' > "$ROOT_TMP/summary-prompt.md"
out=$(review "$C" --diff-file "$ROOT_TMP/pr3.diff" --diff-name pr.diff --prompt-file "$ROOT_TMP/summary-prompt.md" --no-schema)
json_is "summary mode (no schema) returns the Markdown string" "$out" \
  'd["status"] == "completed" and d["result"].startswith("## 1.")'
check "summary mode: diff is named pr.diff in the workdir" grep -q KEEP_ME "$ROOT_TMP/seen-summary/pr.diff"
check "AC9 temp dir removed after a summary run" test "$(leftovers)" = "0"

fake_reset
export FAKE_AGY_FIXTURE="$FIXTURES/success-structured-no-issues"
export FAKE_AGY_SLEEP=30
rm -rf "$RUN_TMP" && mkdir -p "$RUN_TMP"
(cd "$R" && PATH="$FAKEBIN:$PATH" TMPDIR="$RUN_TMP" exec bash "$SCRIPTS/agy-review.sh" >/dev/null 2>&1) &
bg=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do fake_called && break; sleep 0.5; done
kill -TERM "$bg" 2>/dev/null
waited=0
while kill -0 "$bg" 2>/dev/null && [ "$waited" -lt 10 ]; do sleep 0.5; waited=$((waited + 1)); done
if kill -0 "$bg" 2>/dev/null; then
  kill -KILL "$bg" 2>/dev/null
  fail "AC9 TERM stops the run promptly" "still running 5s after TERM"
else
  pass "AC9 TERM stops the run promptly"
fi
check "AC9 temp dir removed after TERM" test "$(leftovers)" = "0"
fake_reset

# ==============================================================================
echo "# repository checks"

# AC10: every remaining "gemini" must match one allowlist entry: "<path glob>|<regex on the line>".
ALLOW=$(cat <<'EOF'
*|gemini-3\.
.claude/skills/context-hygiene/SKILL.md|gemini\|agy
README.md|Gemini (モデル|models?)
.claude/rules/agy-delegation.md|Gemini (モデル|models?)
.claude/skills/agy-review/tests/*|.
EOF
)
unexpected=$(cd "$REPO" && git grep -niE --untracked 'gemini' -- . ':!.claude/plugins' | python3 -c '
import fnmatch, re, sys
allow = [l.split("|", 1) for l in sys.argv[1].splitlines() if l]
for line in sys.stdin:
    path, _, rest = line.rstrip("\n").partition(":")
    _, _, text = rest.partition(":")
    if not any(fnmatch.fnmatch(path, g) and re.search(r, text) for g, r in allow):
        print(line.rstrip("\n")[:160])' "$ALLOW")
if [ -z "$unexpected" ]; then
  pass "AC10 no 'gemini' outside the allowlist"
else
  fail "AC10 no 'gemini' outside the allowlist" "$(printf '%s\n' "$unexpected" | wc -l | tr -d ' ') unexpected line(s), first: $(printf '%s\n' "$unexpected" | head -5)"
fi

for p in .claude/skills/agy-review/SKILL.md .claude/commands/agy.md .claude/rules/agy-delegation.md \
  .claude/skills/pr-comprehend/prompts/agy-summary.md; do
  check "AC11 exists: $p" test -f "$REPO/$p"
done
for p in .claude/skills/gemini-review .claude/commands/gemini.md .claude/rules/gemini-delegation.md \
  .claude/skills/pr-comprehend/prompts/gemini-summary.md .gemini; do
  check "AC11 removed: $p" test ! -e "$REPO/$p"
done

check "AC12 .claude/settings.json is valid JSON and allows Bash(agy:*)" \
  python3 -c 'import json,sys; s=open(sys.argv[1]).read(); json.loads(s); sys.exit(0 if "Bash(agy:*)" in s else 1)' "$REPO/.claude/settings.json"
check "AC12 Brewfile has the antigravity-cli cask" grep -qx 'cask "antigravity-cli"' "$REPO/.homebrew/Brewfile"
if command -v zsh >/dev/null 2>&1; then
  check "AC12 zsh -n .script/review-pr.sh" zsh -n "$REPO/.script/review-pr.sh"
fi
if command -v shellcheck >/dev/null 2>&1; then
  # shellcheck disable=SC2046
  check "AC12 shellcheck --severity=warning on all bash scripts" \
    shellcheck --severity=warning $(cd "$REPO" && grep -rlE '^#!.*\bbash\b' --include='*.sh' . | sed "s|^\./|$REPO/|")
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
