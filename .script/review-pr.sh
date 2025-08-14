#!/bin/zsh

# Check if PR number or URL is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <pr-number-or-url> [repo-owner/repo-name]"
    echo "Examples:"
    echo "  $0 123"
    echo "  $0 123 owner/repo"
    echo "  $0 https://github.com/owner/repo/pull/123"
    exit 1
fi

PR_INPUT="$1"
REPO=""

# Parse PR number and repo from GitHub URL if provided
if [[ "$PR_INPUT" =~ ^https?://github.com/([^/]+/[^/]+)/pull/([0-9]+)/?$ ]]; then
    REPO="${match[1]}"
    PR_NUMBER="${match[2]}"
elif [[ "$PR_INPUT" =~ ^[0-9]+$ ]]; then
    PR_NUMBER="$PR_INPUT"
    # Use second argument as repo if provided
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
    exit 1
fi

# Check if repository was determined
if [ -z "$REPO" ]; then
    echo "Error: Could not determine repository. Please specify it as a second argument."
    echo "Usage: $0 <pr-number> <owner/repo>"
    exit 1
fi

# Set the prompt file path
PROMPT_FILE="${HOME}/.script/pr-review-prompt.md"

# Check if prompt file exists
if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: Review prompt file not found at $PROMPT_FILE"
    exit 1
fi

# Read the prompt template
PROMPT_TEMPLATE=$(cat "$PROMPT_FILE")

# Build the full prompt
FULL_PROMPT="Repository: ${REPO}
Pull Request: #${PR_NUMBER}

以下のghコマンドを実行してPull Requestを取得し、日本語でレビューしてください：
1. gh pr view ${PR_NUMBER} --repo ${REPO}
2. gh pr diff ${PR_NUMBER} --repo ${REPO}

${PROMPT_TEMPLATE}"

# Create new tmux session or attach to existing one
SESSION_NAME="pr-review-${PR_NUMBER}"

# Check if existing session exists and ask for confirmation
tmux has-session -t "$SESSION_NAME" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "An existing review session for PR #${PR_NUMBER} was found."
    echo -n "Do you want to kill it and create a new one? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Killing existing session: $SESSION_NAME"
        tmux kill-session -t "$SESSION_NAME"
    else
        echo "Attaching to existing session..."
        tmux attach-session -t "$SESSION_NAME"
        exit 0
    fi
fi

echo "Creating review session for PR #${PR_NUMBER}..."
echo "Repository: $REPO"

# Create new session with claude in the first pane
tmux new-session -d -s "$SESSION_NAME" -n "PR-Review" "echo 'Claude AI Review:'; echo ''; claude \"${FULL_PROMPT}\"; exec zsh"

# Split horizontally and run cursor-agent in the second pane (if available)
if command -v cursor-agent &> /dev/null; then
    tmux split-window -h -t "$SESSION_NAME:0" "echo 'Cursor Agent Review:'; echo ''; cursor-agent \"${FULL_PROMPT}\"; exec zsh"
else
    tmux split-window -h -t "$SESSION_NAME:0" "echo 'Cursor Agent not found. You can install it or use another AI tool.'; exec zsh"
fi

# Split the second pane vertically and run gemini in the third pane (if available)
if command -v gemini &> /dev/null; then
    GEMINI_PATH=$(command -v gemini)
    tmux split-window -v -t "$SESSION_NAME:0.1" "echo 'Gemini AI Review:'; echo ''; env -u ASDF_DIR -u ASDF_DATA_DIR ${GEMINI_PATH} --sandbox --approval-mode yolo -p \"${FULL_PROMPT}\"; exec zsh"
else
    tmux split-window -v -t "$SESSION_NAME:0.1" "echo 'Gemini not found. You can install it or use another AI tool.'; exec zsh"
fi

# Select the layout to make panes equal size
tmux select-layout -t "$SESSION_NAME:0" even-horizontal

# Select the first pane
tmux select-pane -t "$SESSION_NAME:0.0"

# Attach to the session
tmux attach-session -t "$SESSION_NAME"
