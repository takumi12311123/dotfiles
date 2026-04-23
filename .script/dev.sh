#!/bin/bash
# dev - tmux development environment
# Layout:
#   +---------+------------------+
#   | lazygit |   claude code    |
#   |  (33%)  |      (67%)       |
#   +---------+------------------+

WORK_DIR="${1:-$(pwd)}"
DIR_NAME=$(basename "$WORK_DIR")
SESSION_NAME="dev-${DIR_NAME}"

# Get current terminal size
TERM_WIDTH=$(tput cols)
TERM_HEIGHT=$(tput lines)

# If session already exists, just attach to it
if tmux has-session -t "=$SESSION_NAME" 2>/dev/null; then
    tmux attach-session -t "=$SESSION_NAME"
    exit 0
fi

# Create new session with actual terminal size
tmux new-session -d -s "$SESSION_NAME" -c "$WORK_DIR" -x "$TERM_WIDTH" -y "$TERM_HEIGHT"

# Split vertically: left 33% for lazygit
tmux split-window -h -p 67 -t "$SESSION_NAME" -c "$WORK_DIR"

# Layout: pane 0 = left (lazygit), pane 1 = right (claude code)
tmux send-keys -t "$SESSION_NAME:0.0" 'lazygit' C-m
tmux send-keys -t "$SESSION_NAME:0.1" 'claude' C-m

# Focus on claude code pane
tmux select-pane -t "$SESSION_NAME:0.1"

# Attach to session
tmux attach-session -t "$SESSION_NAME"
