#!/bin/bash
# dev - tmux development environment
# Layout:
#   +------------+------------+
#   |  lazygit   |   nvim     |  30%
#   +------------+------------+
#   |       claude code       |  70%
#   +-------------------------+

SESSION_NAME="dev"
WORK_DIR="${1:-$(pwd)}"

# Kill existing session if exists
tmux kill-session -t "$SESSION_NAME" 2>/dev/null

# Create new session with claude code (main pane - bottom)
tmux new-session -d -s "$SESSION_NAME" -c "$WORK_DIR"

# Split horizontally: top 30%, bottom 70% (claude code stays at bottom)
tmux split-window -v -p 70 -t "$SESSION_NAME" -c "$WORK_DIR"

# Now pane 0 is top (30%), pane 1 is bottom (70%)
# Split top pane vertically for lazygit (left) and nvim (right)
tmux split-window -h -t "$SESSION_NAME:0.0" -c "$WORK_DIR"

# Layout: pane 0 = top-left, pane 1 = top-right, pane 2 = bottom
# Send commands to each pane
tmux send-keys -t "$SESSION_NAME:0.0" 'lazygit' C-m
tmux send-keys -t "$SESSION_NAME:0.1" 'nvim .' C-m
tmux send-keys -t "$SESSION_NAME:0.2" 'claude' C-m

# Focus on claude code pane
tmux select-pane -t "$SESSION_NAME:0.2"

# Attach to session
tmux attach-session -t "$SESSION_NAME"
