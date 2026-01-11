#!/usr/bin/env bash
set -euo pipefail

# Dotfiles setup script - creates symlinks from home directory to this repo

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Track created symlinks for rollback
CREATED_SYMLINKS=()
BACKUP_FILES=()

# Cleanup function for rollback on failure
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        error "Setup failed! Rolling back changes..."

        # Remove created symlinks
        for link in "${CREATED_SYMLINKS[@]}"; do
            if [ -L "$link" ]; then
                rm "$link"
                warn "Removed symlink: $link"
            fi
        done

        # Restore backups
        for backup in "${BACKUP_FILES[@]}"; do
            local original="${backup%.bak*}"
            if [ -e "$backup" ] && [ ! -e "$original" ]; then
                mv "$backup" "$original"
                warn "Restored backup: $backup -> $original"
            fi
        done

        error "Rollback complete. Please fix the issue and try again."
    fi
}
trap cleanup EXIT

# Pre-flight checks
preflight_check() {
    step "Running pre-flight checks..."
    local failed=0

    # Check for required commands
    for cmd in git; do
        if ! command -v "$cmd" &>/dev/null; then
            error "Required command not found: $cmd"
            failed=1
        else
            info "Found: $cmd"
        fi
    done

    # Check for Homebrew (optional but recommended)
    if ! command -v brew &>/dev/null; then
        warn "Homebrew not found. Some features may not work correctly."
        warn "Install from: https://brew.sh"
    else
        info "Found: brew"
    fi

    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        warn "This dotfiles is designed for macOS. Some configurations may not work on $(uname)."
    else
        info "Platform: macOS"
    fi

    # Check if dotfiles directory exists
    if [ ! -d "$DOTFILES_DIR" ]; then
        error "Dotfiles directory not found: $DOTFILES_DIR"
        failed=1
    fi

    if [ $failed -eq 1 ]; then
        error "Pre-flight checks failed. Please install missing dependencies."
        exit 1
    fi

    info "Pre-flight checks passed!"
    echo ""
}

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
        BACKUP_FILES+=("$backup")
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$dst")"

    ln -s "$src" "$dst"
    CREATED_SYMLINKS+=("$dst")
    info "Created symlink: $dst -> $src"
}

# Verify symlinks are working correctly
verify_setup() {
    step "Verifying setup..."
    local failed=0

    for link in "${CREATED_SYMLINKS[@]}"; do
        if [ -L "$link" ]; then
            local target
            target=$(readlink "$link")
            if [ -e "$target" ]; then
                info "Verified: $link -> $target"
            else
                error "Broken symlink: $link -> $target"
                failed=1
            fi
        else
            error "Not a symlink: $link"
            failed=1
        fi
    done

    if [ $failed -eq 1 ]; then
        error "Verification failed!"
        return 1
    fi

    info "All symlinks verified successfully!"
}

echo "======================================"
echo "  Dotfiles Setup"
echo "  Source: $DOTFILES_DIR"
echo "======================================"
echo ""

# Run pre-flight checks
preflight_check

# Root dotfiles
step "Setting up root dotfiles..."
for f in .skhdrc .tmux.conf .yabairc .zshrc .zprofile .tool-versions; do
    if [ -e "$DOTFILES_DIR/$f" ]; then
        create_symlink "$DOTFILES_DIR/$f" "$HOME/$f"
    fi
done

# .zsh directory (individual files, not whole directory - secrets.zsh stays local)
step "Setting up .zsh files..."
mkdir -p "$HOME/.zsh"
for f in alias.zsh fzf_function.zsh init.zsh setopt.zsh; do
    if [ -e "$DOTFILES_DIR/.zsh/$f" ]; then
        create_symlink "$DOTFILES_DIR/.zsh/$f" "$HOME/.zsh/$f"
    fi
done

# .config directory items
step "Setting up .config..."
mkdir -p "$HOME/.config"
create_symlink "$DOTFILES_DIR/.config/alacritty" "$HOME/.config/alacritty"
create_symlink "$DOTFILES_DIR/.config/gokurakujoudo" "$HOME/.config/gokurakujoudo"
mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
create_symlink "$DOTFILES_DIR/.config/ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
mkdir -p "$HOME/.config/starship"
create_symlink "$DOTFILES_DIR/.config/starship/starship.toml" "$HOME/.config/starship/starship.toml"

# .claude directory (selective - keep local data like history, todos)
step "Setting up .claude..."
mkdir -p "$HOME/.claude"
create_symlink "$DOTFILES_DIR/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
create_symlink "$DOTFILES_DIR/.claude/settings.json" "$HOME/.claude/settings.json"
create_symlink "$DOTFILES_DIR/.claude/commands" "$HOME/.claude/commands"
create_symlink "$DOTFILES_DIR/.claude/skills" "$HOME/.claude/skills"
create_symlink "$DOTFILES_DIR/.claude/plugins" "$HOME/.claude/plugins"

# .codex directory
step "Setting up .codex..."
mkdir -p "$HOME/.codex"
create_symlink "$DOTFILES_DIR/.codex/config.toml" "$HOME/.codex/config.toml"
create_symlink "$DOTFILES_DIR/.codex/prompts" "$HOME/.codex/prompts"
create_symlink "$DOTFILES_DIR/.codex/skills" "$HOME/.codex/skills"

# .script directory
step "Setting up .script..."
create_symlink "$DOTFILES_DIR/.script" "$HOME/.script"

echo ""

# Verify all symlinks
verify_setup

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

# Check if secrets.zsh exists
if [ ! -f "$HOME/.zsh/secrets.zsh" ]; then
    warn "~/.zsh/secrets.zsh not found."
    if [ -f "$DOTFILES_DIR/.zsh/secrets.zsh.template" ]; then
        echo "  Run: cp $DOTFILES_DIR/.zsh/secrets.zsh.template ~/.zsh/secrets.zsh"
    fi
    echo ""
fi
