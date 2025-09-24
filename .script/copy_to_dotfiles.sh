#!/bin/zsh

source ~/.script/variables.sh

cp $ROOT_PATH/.claude/settings.json $GIT_PATH/.claude/
cp $ROOT_PATH/.claude/CLAUDE.md $GIT_PATH/.claude/
cp $ROOT_PATH/.claude/commands/* $GIT_PATH/.claude/commands/
cp $ROOT_PATH/.claude/agents/* $GIT_PATH/.claude/agents/

cp $CONFIG_PATH/alacritty/alacritty.toml $GIT_PATH/.config/alacritty/
cp $CONFIG_PATH/alacritty/keybindings.toml $GIT_PATH/.config/alacritty/
cp $CONFIG_PATH/gokurakujoudo/karabiner.edn $GIT_PATH/.config/gokurakujoudo
cp $CONFIG_PATH/starship/starship.toml $GIT_PATH/.config/starship/
cp $CONFIG_PATH/karabiner/karabiner.json $GIT_PATH/.config/karabiner/

cp $SCRIPT_PATH/ide.sh $GIT_PATH/.script/
cp $SCRIPT_PATH/copy_to_dotfiles.sh $GIT_PATH/.script/
cp $SCRIPT_PATH/back_to_exec_environment.sh $GIT_PATH/.script/
cp $SCRIPT_PATH/variables.sh $GIT_PATH/.script/

cp $VSCODE_PATH/settings.json $GIT_PATH/.vscode/
cp $VSCODE_PATH/keybindings.json $GIT_PATH/.vscode/

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

# Copy Codex config (only the public config, not private projects)
mkdir -p $GIT_PATH/codex
cp ~/.codex/config.toml $GIT_PATH/codex/ 2>/dev/null || true

echo 'copy to dotfiles done!'
