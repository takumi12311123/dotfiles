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

# Install Homebrew if it is not already present
install_homebrew() {
    step "Setting up Homebrew..."
    if command -v brew &>/dev/null; then
        info "Homebrew already installed"
    else
        info "Installing Homebrew..."
        # Download and run separately so a curl failure is not masked by the
        # command substitution (an empty script would otherwise exit 0).
        local installer
        if ! installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            warn "Homebrew installer download failed. Skipping package installation."
            return 0
        fi
        if ! /bin/bash -c "$installer"; then
            warn "Homebrew install failed. Skipping package installation."
            return 0
        fi
    fi

    # Ensure brew is on PATH for the rest of this script (Apple Silicon / Intel)
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

# Install every package declared in the Brewfile
brew_bundle() {
    step "Installing packages from Brewfile..."
    if ! command -v brew &>/dev/null; then
        warn "brew not available. Skipping brew bundle."
        return 0
    fi

    local brewfile="$DOTFILES_DIR/.homebrew/Brewfile"
    if [ ! -f "$brewfile" ]; then
        warn "Brewfile not found at $brewfile. Skipping."
        return 0
    fi

    info "Running brew bundle (this may take a while)..."
    brew bundle --file="$brewfile" || warn "brew bundle reported failures (continuing)."
}

# Install language runtimes declared in .tool-versions via asdf
install_asdf_tools() {
    step "Installing runtimes from .tool-versions..."
    if ! command -v asdf &>/dev/null; then
        warn "asdf not found. Skipping runtime installation."
        return 0
    fi

    local tool_versions="$DOTFILES_DIR/.tool-versions"
    if [ ! -f "$tool_versions" ]; then
        warn ".tool-versions not found. Skipping."
        return 0
    fi

    # Add each required plugin (skip ones already installed; keep stderr visible
    # so genuine failures such as a typo'd plugin name remain diagnosable)
    local plugin _rest installed
    installed="$(asdf plugin list 2>/dev/null || true)"
    while read -r plugin _rest; do
        [ -z "$plugin" ] && continue
        case "$plugin" in \#*) continue ;; esac
        grep -qxF "$plugin" <<<"$installed" && continue
        asdf plugin add "$plugin" || warn "asdf plugin add $plugin failed (continuing)."
    done <"$tool_versions"

    # Install the pinned versions from $HOME (where .tool-versions is symlinked)
    (cd "$HOME" && asdf install) || warn "asdf install reported issues (continuing)."
}

# Generate the Karabiner config from the GokuRakuJoudo .edn source
generate_karabiner() {
    step "Generating Karabiner config with goku..."
    if ! command -v goku &>/dev/null; then
        warn "goku not found. Skipping Karabiner generation."
        return 0
    fi

    GOKU_EDN_CONFIG_FILE="$HOME/.config/gokurakujoudo/karabiner.edn" goku ||
        warn "goku generation failed (continuing)."
}

# Set sensible global git defaults (aligned with existing zsh aliases)
# Each config is non-fatal so a failure never triggers the EXIT-trap rollback.
configure_git() {
    step "Configuring global git settings..."
    git config --global init.defaultBranch main || warn "git config init.defaultBranch failed"
    git config --global push.autoSetupRemote true || warn "git config push.autoSetupRemote failed"
    git config --global pull.ff only || warn "git config pull.ff failed"
    git config --global fetch.prune true || warn "git config fetch.prune failed"
    git config --global rerere.enabled true || warn "git config rerere.enabled failed"
    info "Global git settings applied."
}

# Apply a standard developer set of macOS system preferences
configure_macos_defaults() {
    if [[ "$(uname)" != "Darwin" ]]; then
        info "Not macOS. Skipping system defaults."
        return 0
    fi

    step "Applying macOS system defaults..."

    # Absorb any single-key failure (e.g. an unsupported key on a different macOS
    # version) so it never escapes to `set -e` and fires the EXIT-trap rollback.
    local d="defaults write"
    {
        # Keyboard: fastest key repeat + disable press-and-hold accent popup
        $d NSGlobalDomain KeyRepeat -int 2
        $d NSGlobalDomain InitialKeyRepeat -int 15
        $d NSGlobalDomain ApplePressAndHoldEnabled -bool false

        # Trackpad: disable natural scroll direction
        $d NSGlobalDomain com.apple.swipescrolldirection -bool false

        # Dock: auto-hide instantly, no recents
        $d com.apple.dock autohide -bool true
        $d com.apple.dock autohide-delay -float 0
        $d com.apple.dock autohide-time-modifier -float 0
        $d com.apple.dock show-recents -bool false

        # Screenshots: save to ~/Screenshots as shadowless PNGs
        mkdir -p "$HOME/Screenshots"
        $d com.apple.screencapture location -string "$HOME/Screenshots"
        $d com.apple.screencapture disable-shadow -bool true
        $d com.apple.screencapture type -string "png"

        # Finder: show extensions, hidden files, path/status bars, list view, POSIX path
        $d NSGlobalDomain AppleShowAllExtensions -bool true
        $d com.apple.finder AppleShowAllFiles -bool true
        $d com.apple.finder ShowPathbar -bool true
        $d com.apple.finder ShowStatusBar -bool true
        $d com.apple.finder FXPreferredViewStyle -string "Nlsv"
        $d com.apple.finder _FXShowPosixPathInTitle -bool true
        $d com.apple.finder FXEnableExtensionChangeWarning -bool false

        # Misc: no .DS_Store on network volumes, always show scrollbars
        $d com.apple.desktopservices DSDontWriteNetworkStores -bool true
        $d NSGlobalDomain AppleShowScrollBars -string "Always"
    } || warn "Some macOS defaults could not be applied (continuing)."

    # Restart affected apps so changes take effect immediately
    killall Dock Finder SystemUIServer &>/dev/null || true

    info "macOS system defaults applied."
}

echo "======================================"
echo "  Dotfiles Setup"
echo "  Source: $DOTFILES_DIR"
echo "======================================"
echo ""

# Run pre-flight checks
preflight_check

# Install phase: Homebrew + every package in the Brewfile (goku, asdf, etc.)
install_homebrew
brew_bundle

echo ""

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
mkdir -p "$HOME/.config/prr"
create_symlink "$DOTFILES_DIR/.config/prr/config.toml" "$HOME/.config/prr/config.toml"

# .claude directory (selective - keep local data like history, todos)
step "Setting up .claude..."
mkdir -p "$HOME/.claude"
create_symlink "$DOTFILES_DIR/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
create_symlink "$DOTFILES_DIR/.claude/settings.json" "$HOME/.claude/settings.json"
create_symlink "$DOTFILES_DIR/.claude/commands" "$HOME/.claude/commands"
create_symlink "$DOTFILES_DIR/.claude/skills" "$HOME/.claude/skills"
create_symlink "$DOTFILES_DIR/.claude/plugins" "$HOME/.claude/plugins"

# .gemini directory (selective - keep auth/history local)
step "Setting up .gemini..."
mkdir -p "$HOME/.gemini"
create_symlink "$DOTFILES_DIR/.gemini/settings.json" "$HOME/.gemini/settings.json"

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

# Post-symlink provisioning (needs symlinked configs + installed tools)
install_asdf_tools
generate_karabiner
configure_git
configure_macos_defaults

echo ""

# Post-install: AI tool setup
step "Setting up AI tools..."

# RTK: Install hook script for Claude Code (--no-patch since settings.json is managed by dotfiles)
if command -v rtk &>/dev/null; then
    info "Setting up RTK hook for Claude Code..."
    rtk init -g --no-patch < /dev/null 2>/dev/null || warn "RTK hook setup skipped (run 'rtk init -g --no-patch' manually)"
else
    warn "RTK not installed. Run 'brew install rtk' first."
fi

# agent-browser: Install Chromium for headless browser automation
if command -v agent-browser &>/dev/null; then
    info "Installing Chromium for agent-browser..."
    agent-browser install < /dev/null 2>/dev/null || warn "agent-browser Chromium install skipped (run 'agent-browser install' manually)"
else
    warn "agent-browser not installed. Run 'brew install agent-browser' first."
fi

echo ""
echo "======================================"
echo "  Setup complete!"
echo "======================================"
echo ""
echo "Notes:"
echo "  - Backup files created with .bak extension (timestamped if exists)"
echo "  - Local secrets stay in ~/.zsh/secrets.zsh (not symlinked)"
echo "  - Packages installed from .homebrew/Brewfile via 'brew bundle'"
echo "  - Runtimes installed from .tool-versions via 'asdf install'"
echo "  - Karabiner config generated from .edn via 'goku'"
echo "  - macOS system defaults applied (some need a logout/restart)"
echo "  - RTK: Restart Claude Code for hook to take effect"
echo "  - agent-browser: Run 'agent-browser install' if Chromium was not installed"
echo ""

# Check if secrets.zsh exists
if [ ! -f "$HOME/.zsh/secrets.zsh" ]; then
    warn "~/.zsh/secrets.zsh not found."
    if [ -f "$DOTFILES_DIR/.zsh/secrets.zsh.template" ]; then
        echo "  Run: cp $DOTFILES_DIR/.zsh/secrets.zsh.template ~/.zsh/secrets.zsh"
    fi
    echo ""
fi
