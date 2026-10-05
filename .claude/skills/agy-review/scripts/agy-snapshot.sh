#!/usr/bin/env bash
# Build the inputs agy is allowed to read, leaving out secret-named paths.
#
#   agy-snapshot.sh diff <out-file>           uncommitted changes of the current repo as one diff
#   agy-snapshot.sh tree <dest-dir>           copy of the current working tree
#   agy-snapshot.sh filter-diff <in> <out>    drop per-file patches of secret-named paths
#
# Exit 3 from diff / filter-diff means nothing reviewable is left.
# Excluded paths are reported on stderr as EXCLUDED_FILE=<path>.
set -u

EXCLUDE_RE='\.env|\.key|\.pem|credentials|secret|\.tfvars|\.tfstate'

is_secret() { printf '%s' "$1" | grep -qE "$EXCLUDE_RE"; }

# Paths that are a submodule (160000) or a symlink (120000) in the index or in HEAD,
# one per line. Asking git instead of the filesystem also covers deleted ones, whose
# diff would still print the old link target.
non_regular_paths() {
  {
    git -c core.quotePath=false ls-files -s
    git -c core.quotePath=false ls-tree -r HEAD 2>/dev/null
  } | awk '$1 == "160000" || $1 == "120000" { sub(/^[^\t]*\t/, ""); print }' | sort -u
}

is_non_regular() { printf '%s\n' "$NON_REGULAR" | grep -qxF -- "$1"; }

# True when the directory holding <path> is physically inside the repository.
# A parent directory replaced by a symlink would otherwise let a tracked path
# resolve to a file outside it.
REPO_ROOT=""
inside_repo() {
  local dir
  dir=$(cd "$(dirname "$1")" 2>/dev/null && pwd -P) || return 1
  case "$dir/" in "$REPO_ROOT"/*) return 0 ;; esac
  return 1
}

cmd_diff() {
  local out=$1 f
  NON_REGULAR=$(non_regular_paths)
  : > "$out"
  # Tracked paths changed against HEAD, including deletions.
  git diff HEAD --name-only -z | while IFS= read -r -d '' f; do
    if is_secret "$f"; then echo "EXCLUDED_FILE=$f" >&2; continue; fi
    is_non_regular "$f" && continue
    [ -L "./$f" ] && continue # a regular file replaced by a symlink, not staged yet
    git diff HEAD -- "$f" >> "$out"
  done
  # Untracked files never show up in `git diff HEAD`; add them as new-file patches.
  git ls-files -o --exclude-standard -z | while IFS= read -r -d '' f; do
    if is_secret "$f"; then echo "EXCLUDED_FILE=$f" >&2; continue; fi
    [ -f "./$f" ] && [ ! -L "./$f" ] && inside_repo "./$f" || continue
    git diff --no-index -- /dev/null "$f" >> "$out"
  done
  [ -s "$out" ] || return 3
}

cmd_tree() {
  local dest=$1 f
  mkdir -p "$dest" || return 1
  # Regular files only: a symlink could point outside the repository, a deleted
  # path is still listed by ls-files, and a submodule shows up as a directory.
  git ls-files -co --exclude-standard -z | while IFS= read -r -d '' f; do
    is_secret "$f" && continue
    # "./" keeps a file named like an option (e.g. --help) from being parsed as one.
    [ -f "./$f" ] && [ ! -L "./$f" ] && inside_repo "./$f" || continue
    # A partial copy would be read as the complete surrounding code.
    mkdir -p "$dest/$(dirname "./$f")" && cp -p "./$f" "$dest/$f" || exit 1
  done
}

cmd_filter_diff() {
  local in=$1 out=$2
  # The pattern goes through the environment: `awk -v` would eat its backslashes.
  # Each per-file patch is buffered until its end: whether it is a symlink (120000)
  # or submodule (160000) patch is only known from the mode lines after the header.
  EXCLUDE_RE="$EXCLUDE_RE" awk '
    function flush() {
      if (header != "" && !drop) { printf "%s", buf; kept++ }
      else if (header != "") print "EXCLUDED_FILE=" substr(header, 12) > "/dev/stderr"
      buf = ""; header = ""; drop = 0
    }
    BEGIN { re = ENVIRON["EXCLUDE_RE"] }
    /^diff --git / { flush(); header = $0; drop = ($0 ~ re) }
    header == "" { print; next }
    /^(old mode|new mode|new file mode|deleted file mode) (120000|160000)$/ { drop = 1 }
    /^index [0-9a-f]+\.\.[0-9a-f]+ (120000|160000)$/ { drop = 1 }
    { buf = buf $0 "\n" }
    END { flush(); exit kept ? 0 : 3 }
  ' "$in" > "$out"
}

# The git calls below sit inside pipelines, which would hide "not a git repository"
# behind an empty result that reads as "nothing to review".
in_repo() {
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) && REPO_ROOT=$(cd "$REPO_ROOT" && pwd -P) && return 0
  echo "agy-snapshot.sh: not a git repository" >&2
  return 1
}

case "${1:-}" in
  diff) [ $# -eq 2 ] || exit 2; in_repo && cmd_diff "$2" ;;
  tree) [ $# -eq 2 ] || exit 2; in_repo && cmd_tree "$2" ;;
  filter-diff) [ $# -eq 3 ] || exit 2; cmd_filter_diff "$2" "$3" ;;
  *) echo "usage: agy-snapshot.sh diff <out> | tree <dest> | filter-diff <in> <out>" >&2; exit 2 ;;
esac
