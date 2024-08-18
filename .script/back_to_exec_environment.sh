#!/bin/zsh

source ~/.script/variables.sh

cp $GIT_PATH/.config/gokurakujoudo/karabiner.edn $CONFIG_PATH/gokurakujoudo
cp $GIT_PATH/.config/starship.toml $CONFIG_PATH/

cp $GIT_PATH/.script/ide.sh $SCRIPT_PATH/
cp $GIT_PATH/.script/copy_to_dotfiles.sh $SCRIPT_PATH/
cp $GIT_PATH/.script/back_to_exec_environment.sh $SCRIPT_PATH/
cp $GIT_PATH/.script/variables.sh $SCRIPT_PATH/

cp $GIT_PATH/.zsh/alias.zsh $ZSH_PATH/
cp $GIT_PATH/.zsh/fzf_function.zsh $ZSH_PATH/
cp $GIT_PATH/.zsh/init.zsh $ZSH_PATH/
cp $GIT_PATH/.zsh/secrets.zsh $ZSH_PATH/
cp $GIT_PATH/.zsh/setopt.zsh $ZSH_PATH/

cp $GIT_PATH/.skhdrc $ROOT_PATH/
cp $GIT_PATH/.yabairc $ROOT_PATH/
cp $GIT_PATH/.zprofile $ROOT_PATH/
cp $GIT_PATH/.zsh_history $ROOT_PATH/
cp $GIT_PATH/.zshrc $ROOT_PATH/
cp $GIT_PATH/.tmux.conf $ROOT_PATH/
