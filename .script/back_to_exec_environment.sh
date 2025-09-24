#!/usr/bin/env bash
set -euo pipefail

# Simple, quiet copy of selected dotfiles from repo to $HOME
DOTFILES_REPO="${DOTFILES_REPO:-$HOME/Git-Project/github.com/takumi12311123/dotfiles}"

SYNC_ITEMS=(
  ".zshrc"
  ".zprofile"
  ".tmux.conf"
  ".yabairc"
  ".skhdrc"
  ".zsh"
  ".script"
  ".claude"
)

for item in "${SYNC_ITEMS[@]}"; do
  src="$DOTFILES_REPO/$item"
  dst="$HOME/$item"
  if [[ -d "$src" ]]; then
    mkdir -p "$dst"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a "$src/" "$dst/" >/dev/null 2>&1
    else
      cp -R "$src/." "$dst" >/dev/null 2>&1
    fi
  elif [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst" >/dev/null 2>&1
  fi
done

# Copy Codex config
if [[ -d "$DOTFILES_REPO/codex" ]]; then
  mkdir -p "$HOME/.codex"
  cp -f "$DOTFILES_REPO/codex/config.toml" "$HOME/.codex/config.toml" >/dev/null 2>&1
  # Copy private configuration files if they exist
  if [[ -f "$DOTFILES_REPO/codex/.projects.toml" ]]; then
    cp -f "$DOTFILES_REPO/codex/.projects.toml" "$HOME/.codex/.projects.toml" >/dev/null 2>&1
  fi
  if [[ -f "$DOTFILES_REPO/codex/.system-prompt.md" ]]; then
    cp -f "$DOTFILES_REPO/codex/.system-prompt.md" "$HOME/.codex/system-prompt.md" >/dev/null 2>&1
  fi
fi

# Copy Claude commands to Codex prompts
if [[ -d "$DOTFILES_REPO/.claude/commands" ]]; then
  mkdir -p "$HOME/.codex/prompts"
  cp -f "$DOTFILES_REPO/.claude/commands/"* "$HOME/.codex/prompts/" >/dev/null 2>&1
fi

echo "Dotfiles copied to $HOME from $DOTFILES_REPO"
