#!/usr/bin/env bash
set -euo pipefail

# Back-sync dotfiles from repository into $HOME.
# Usage:
#   DOTFILES_REPO=/path/to/repo back_to_exec_environment.sh [-n|--dry-run] [-y]
# Defaults:
#   DOTFILES_REPO=$HOME/Git-Project/github.com/takumi12311123/dotfiles

DRY_RUN=false
ASSUME_YES=false
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=true ;;
    -y|--yes) ASSUME_YES=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

DOTFILES_REPO="${DOTFILES_REPO:-$HOME/Git-Project/github.com/takumi12311123/dotfiles}"
if [[ ! -d "$DOTFILES_REPO" ]]; then
  echo "Repository not found: $DOTFILES_REPO" >&2
  exit 1
fi

# Files and directories to sync from repo root to $HOME
# Directories are rsync'ed recursively; files are copied individually with backup
SYNC_ITEMS=(
  ".zshrc"
  ".zprofile"
  ".tmux.conf"
  ".yabairc"
  ".skhdrc"
  ".zsh"
  ".script"
)

# Exclusions when syncing directories
RSYNC_EXCLUDES=(
  "--exclude" "secrets.zsh"
  "--exclude" ".DS_Store"
)

timestamp() { date +%Y%m%d-%H%M%S; }
backup_file() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local bak="$target.bak.$(timestamp)"
    $DRY_RUN && echo "Would backup: $target -> $bak" || mv -f "$target" "$bak"
  fi
}

confirm() {
  $ASSUME_YES && return 0
  read -r -p "Proceed to sync dotfiles from $DOTFILES_REPO to $HOME? [y/N] " ans
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) echo "Aborted."; exit 0 ;;
  esac
}

rsync_dir() {
  local src_dir="$1"; shift
  local dst_dir="$1"; shift
  local -a opts=("-aH" "--delete" "--no-perms" "--no-owner" "--no-group")
  $DRY_RUN && opts+=("-n" "-v")
  rsync "${opts[@]}" "${RSYNC_EXCLUDES[@]}" "$src_dir/" "$dst_dir/"
}

copy_file() {
  local src="$1"; shift
  local dst="$1"; shift
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" || -L "$dst" ]]; then
    backup_file "$dst"
  fi
  if $DRY_RUN; then
    echo "Would copy: $src -> $dst"
  else
    cp -f "$src" "$dst"
  fi
}

main() {
  confirm
  for item in "${SYNC_ITEMS[@]}"; do
    local src="$DOTFILES_REPO/$item"
    local dst="$HOME/$item"
    if [[ -d "$src" ]]; then
      mkdir -p "$dst"
      echo "Sync dir: $src -> $dst"
      rsync_dir "$src" "$dst"
    elif [[ -f "$src" ]]; then
      echo "Copy file: $src -> $dst"
      copy_file "$src" "$dst"
    else
      echo "Skip (not found in repo): $src"
    fi
  done
  echo "Done."
}

main "$@"
