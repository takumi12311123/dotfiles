#!/bin/bash
# dev - cmux development environment with difit + claude
# Layout:
#   +----------+----------+
#   |  difit   |  claude  |
#   |  (50%)   |  (50%)   |
#   +----------+----------+
#
# Run this from a cmux terminal pane.

set -euo pipefail

# ── Dependency checks ──────────────────────────────────────────────
if [ -z "${CMUX_WORKSPACE_ID:-}" ]; then
    echo "Error: not running inside cmux." >&2
    echo "  Open cmux.app and run this command from a cmux terminal." >&2
    exit 1
fi

if ! command -v difit &>/dev/null; then
    echo "Error: difit is not installed." >&2
    echo "  Install with: npm install -g difit" >&2
    exit 1
fi

# ── Working directory ──────────────────────────────────────────────
WORK_DIR="${1:-$(pwd)}"
cd "$WORK_DIR"

# ── Diff detection ─────────────────────────────────────────────────
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)

if [ -z "$CURRENT_BRANCH" ]; then
    echo "Error: not a git repository" >&2
    exit 1
fi

# Find an available port
DIFIT_PORT=${DIFIT_PORT:-3000}
while curl -sf "http://localhost:${DIFIT_PORT}" >/dev/null 2>&1; do
    DIFIT_PORT=$((DIFIT_PORT + 1))
done

DIFIT_ARGS=(--no-open --keep-alive --include-untracked --port "$DIFIT_PORT")

if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    DIFIT_ARGS+=(".")
else
    DEFAULT_REF=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || true)
    DEFAULT_REF=${DEFAULT_REF:-refs/remotes/origin/main}
    MERGE_BASE=$(git merge-base "$DEFAULT_REF" HEAD 2>/dev/null || echo "HEAD")
    DIFIT_ARGS+=("$MERGE_BASE")
fi

# ── Start difit server (quiet, in background) ─────────────────────
difit "${DIFIT_ARGS[@]}" >/dev/null 2>&1 &
DIFIT_PID=$!

trap 'kill $DIFIT_PID 2>/dev/null; wait $DIFIT_PID 2>/dev/null' EXIT INT TERM

# Wait for difit server to be ready
for _ in $(seq 1 30); do
    curl -sf "http://localhost:${DIFIT_PORT}" >/dev/null 2>&1 && break
    sleep 0.2
done

# ── Open difit browser split on the left ───────────────────────────
cmux browser open-split "http://localhost:${DIFIT_PORT}"

# ── Replace this terminal with claude ──────────────────────────────
exec claude
