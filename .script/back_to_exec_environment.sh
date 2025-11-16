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
  ".codex"
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

echo "Dotfiles copied to $HOME from $DOTFILES_REPO"
