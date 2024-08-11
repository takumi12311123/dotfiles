#!/bin/zsh

source ~/.script/variables.sh

cp $CONFIG_PATH/karabiner.edn $GIT_PATH/.config/
cp $CONFIG_PATH/starship.toml $GIT_PATH/.config/

cp $SCRIPT_PATH/ide.sh $GIT_PATH/.script/
cp $SCRIPT_PATH/copy_to_dotfiles.sh $GIT_PATH/.script/
cp $SCRIPT_PATH/variables.sh $GIT_PATH/.script/

cp $ZSH_PATH/alias.zsh $GIT_PATH/.zsh/
cp $ZSH_PATH/fzf_function.zsh $GIT_PATH/.zsh/
cp $ZSH_PATH/init.zsh $GIT_PATH/.zsh/
cp $ZSH_PATH/secrets.zsh $GIT_PATH/.zsh/
cp $ZSH_PATH/setopt.zsh $GIT_PATH/.zsh/

cp ~/.skhdrc $GIT_PATH/
cp ~/.yabairc $GIT_PATH/
cp ~/.zprofile $GIT_PATH/
cp ~/.zsh_history $GIT_PATH/
cp ~/.zshrc $GIT_PATH/
cp ~/.tmux.conf $GIT_PATH/
