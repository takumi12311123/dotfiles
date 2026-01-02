#!/usr/bin/env bash
set -euo pipefail

# Dotfiles setup script - creates symlinks from home directory to this repo

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create symlink with backup
create_symlink() {
    local src="$1"
    local dst="$2"

    if [ -L "$dst" ]; then
        # Already a symlink - check if pointing to correct location
        if [ "$(readlink "$dst")" = "$src" ]; then
            info "Already linked: $dst"
            return 0
        else
            warn "Updating symlink: $dst"
            rm "$dst"
        fi
    elif [ -e "$dst" ]; then
        # File/directory exists - backup with timestamp to avoid overwriting
        local backup="${dst}.bak"
        if [ -e "$backup" ]; then
            backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
        fi
        warn "Backing up: $dst -> $backup"
        mv "$dst" "$backup"
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$dst")"

    ln -s "$src" "$dst"
    info "Created symlink: $dst -> $src"
}

echo "======================================"
echo "  Dotfiles Setup"
echo "  Source: $DOTFILES_DIR"
echo "======================================"
echo ""

# Root dotfiles
info "Setting up root dotfiles..."
for f in .skhdrc .tmux.conf .yabairc .zshrc .zprofile .tool-versions; do
    if [ -e "$DOTFILES_DIR/$f" ]; then
        create_symlink "$DOTFILES_DIR/$f" "$HOME/$f"
    fi
done

# .zsh directory (individual files, not whole directory - secrets.zsh stays local)
info "Setting up .zsh files..."
mkdir -p "$HOME/.zsh"
for f in alias.zsh fzf_function.zsh init.zsh setopt.zsh; do
    if [ -e "$DOTFILES_DIR/.zsh/$f" ]; then
        create_symlink "$DOTFILES_DIR/.zsh/$f" "$HOME/.zsh/$f"
    fi
done

# .config directory items
info "Setting up .config..."
mkdir -p "$HOME/.config"
create_symlink "$DOTFILES_DIR/.config/alacritty" "$HOME/.config/alacritty"
create_symlink "$DOTFILES_DIR/.config/gokurakujoudo" "$HOME/.config/gokurakujoudo"
create_symlink "$DOTFILES_DIR/.config/starship/starship.toml" "$HOME/.config/starship.toml"

# .claude directory (selective - keep local data like history, todos)
info "Setting up .claude..."
mkdir -p "$HOME/.claude"
create_symlink "$DOTFILES_DIR/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
create_symlink "$DOTFILES_DIR/.claude/settings.json" "$HOME/.claude/settings.json"
create_symlink "$DOTFILES_DIR/.claude/commands" "$HOME/.claude/commands"
create_symlink "$DOTFILES_DIR/.claude/skills" "$HOME/.claude/skills"
create_symlink "$DOTFILES_DIR/.claude/plugins" "$HOME/.claude/plugins"

# .codex directory
info "Setting up .codex..."
mkdir -p "$HOME/.codex"
create_symlink "$DOTFILES_DIR/.codex/config.toml" "$HOME/.codex/config.toml"
create_symlink "$DOTFILES_DIR/.codex/prompts" "$HOME/.codex/prompts"
create_symlink "$DOTFILES_DIR/.codex/skills" "$HOME/.codex/skills"

# .script directory
info "Setting up .script..."
create_symlink "$DOTFILES_DIR/.script" "$HOME/.script"

echo ""
echo "======================================"
echo "  Setup complete!"
echo "======================================"
echo ""
echo "Notes:"
echo "  - Backup files created with .bak extension (timestamped if exists)"
echo "  - Local secrets stay in ~/.zsh/secrets.zsh (not symlinked)"
echo "  - Run 'goku' to generate Karabiner config from .edn"
echo ""
