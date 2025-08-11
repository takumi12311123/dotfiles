ZSH_DIR="${HOME}/.zsh"

# Initialize core settings
source "${ZSH_DIR}/init.zsh"

# Load optional zsh fragments safely
setopt null_glob
for file in "${ZSH_DIR}"/*.zsh; do
  [[ "$file" == "${ZSH_DIR}/init.zsh" ]] && continue
  [[ -r "$file" ]] && source "$file"
done

# Added by Windsurf
export PATH="/Users/takumiakasaka/.codeium/windsurf/bin:$PATH"

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# Cursor Agent
export PATH="$HOME/.local/bin:$PATH"
