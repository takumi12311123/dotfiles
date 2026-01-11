#!/bin/bash
# dev - tmux development environment
# Layout:
#   +---------+------------------+
#   | lazygit |   claude code    |
#   |  (25%)  |      (75%)       |
#   +---------+------------------+

SESSION_NAME="dev"
WORK_DIR="${1:-$(pwd)}"

# Kill existing session if exists
tmux kill-session -t "$SESSION_NAME" 2>/dev/null

# Create new session with lazygit (left pane)
tmux new-session -d -s "$SESSION_NAME" -c "$WORK_DIR"

# Split vertically: left 25%, right 75% (claude code on right)
tmux split-window -h -p 75 -t "$SESSION_NAME" -c "$WORK_DIR"

# Layout: pane 0 = left (lazygit), pane 1 = right (claude code)
tmux send-keys -t "$SESSION_NAME:0.0" 'lazygit' C-m
tmux send-keys -t "$SESSION_NAME:0.1" 'claude' C-m

# Focus on claude code pane
tmux select-pane -t "$SESSION_NAME:0.1"

# Attach to session
tmux attach-session -t "$SESSION_NAME"
