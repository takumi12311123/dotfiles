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
