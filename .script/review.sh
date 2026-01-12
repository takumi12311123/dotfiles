#!/bin/bash
# review - tmux PR review environment
# Layout:
#   +---------+-----------+----------+
#   | lazygit |  claude   |   nvim   |
#   |  (25%)  |   (50%)   |  (25%)   |
#   +---------+-----------+----------+

set -euo pipefail

SESSION_NAME="review"

# Usage
usage() {
    echo "Usage: $0 <pr-url-or-number> [repo]"
    echo ""
    echo "Examples:"
    echo "  $0 https://github.com/owner/repo/pull/123"
    echo "  $0 123 owner/repo"
    echo "  $0 123  # (uses current git remote)"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

PR_INPUT="$1"
REPO=""

# Parse PR number and repo from GitHub URL
if [[ "$PR_INPUT" =~ ^https?://github.com/([^/]+/[^/]+)/pull/([0-9]+)/?.*$ ]]; then
    REPO="${BASH_REMATCH[1]}"
    PR_NUMBER="${BASH_REMATCH[2]}"
elif [[ "$PR_INPUT" =~ ^[0-9]+$ ]]; then
    PR_NUMBER="$PR_INPUT"
    if [ $# -ge 2 ]; then
        REPO="$2"
    else
        # Try to get repo from current git remote
        if git remote get-url origin &>/dev/null; then
            REPO=$(git remote get-url origin | sed -E 's|.*github.com[:/]([^/]+/[^/]+)(\.git)?.*|\1|')
        fi
    fi
else
    echo "Error: Invalid PR number or URL format"
    usage
fi

if [ -z "$REPO" ]; then
    echo "Error: Could not determine repository"
    usage
fi

PRR_REF="${REPO}/${PR_NUMBER}"
WORK_DIR="${HOME}/.local/share/prr"

# Get terminal size
TERM_WIDTH=$(tput cols)
TERM_HEIGHT=$(tput lines)

echo "Setting up PR review environment..."
echo "Repository: $REPO"
echo "PR Number: #$PR_NUMBER"
echo ""

# Kill existing session if exists
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# Fetch PR with prr first
echo "Fetching PR with prr..."
prr get "$PRR_REF" --no-edit 2>/dev/null || prr get "$PRR_REF" 2>/dev/null || {
    echo "Note: prr get may have opened editor, continuing..."
}

# Find the review file
REVIEW_FILE="${WORK_DIR}/${REPO//\//_}/${PR_NUMBER}.prr"
if [ ! -f "$REVIEW_FILE" ]; then
    # Try alternative path format
    REVIEW_FILE=$(find "$WORK_DIR" -name "${PR_NUMBER}.prr" 2>/dev/null | head -1)
fi

if [ -z "$REVIEW_FILE" ] || [ ! -f "$REVIEW_FILE" ]; then
    echo "Warning: Review file not found, will open prr edit in nvim pane"
    REVIEW_FILE=""
fi

# Create new session
tmux new-session -d -s "$SESSION_NAME" -x "$TERM_WIDTH" -y "$TERM_HEIGHT"

# Split: left 25% for lazygit
tmux split-window -h -p 75 -t "$SESSION_NAME"

# Split right part: 67% claude, 33% nvim (of the 75%)
tmux split-window -h -p 33 -t "$SESSION_NAME:0.1"

# Pane layout: 0=lazygit, 1=claude, 2=nvim
tmux send-keys -t "$SESSION_NAME:0.0" 'lazygit' C-m

# Claude with PR context
CLAUDE_PROMPT="Review PR #${PR_NUMBER} in ${REPO}. Use gh pr view ${PR_NUMBER} --repo ${REPO} and gh pr diff ${PR_NUMBER} --repo ${REPO} to see the changes."
tmux send-keys -t "$SESSION_NAME:0.1" "claude \"${CLAUDE_PROMPT}\"" C-m

# nvim with prr file or prr edit
if [ -n "$REVIEW_FILE" ] && [ -f "$REVIEW_FILE" ]; then
    tmux send-keys -t "$SESSION_NAME:0.2" "nvim '${REVIEW_FILE}'" C-m
else
    tmux send-keys -t "$SESSION_NAME:0.2" "prr edit ${PRR_REF}" C-m
fi

# Focus on claude pane
tmux select-pane -t "$SESSION_NAME:0.1"

# Attach to session
tmux attach-session -t "$SESSION_NAME"
