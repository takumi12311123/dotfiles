ZSH_DIR="${HOME}/.zsh"

source "${ZSH_DIR}/init.zsh"

if [ -d $ZSH_DIR ] && [ -r $ZSH_DIR ] && [ -x $ZSH_DIR ]; then
    for file in ${ZSH_DIR}/*.zsh; do
        # skip init.zsh
        if [[ "$file" == "${ZSH_DIR}/init.zsh" ]]; then
            continue
        fi
        [ -r $file ] && source $file
    done
fi

# Added by Windsurf
export PATH="/Users/takumiakasaka/.codeium/windsurf/bin:$PATH"

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
