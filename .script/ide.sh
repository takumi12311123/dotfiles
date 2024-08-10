# set tmux panes for ide

if [ "$#" -eq 0 ]; then
  tmux split-window -v
  tmux split-window -h
  tmux resize-pane -D 15
  tmux select-pane -t 1
  tmux select-pane -t 0
  tmux split-window -h
  tmux select-pane -t 0
else
  case $1 in
    1)
      tmux split-window -v
      tmux resize-pane -D 15
      tmux select-pane -D
      clear
      ;;
    2)
      tmux split-window -h
      tmux split-window -v
      tmux resize-pane -D 15
      tmux select-pane -t 1
      tmux split-window -v
      tmux select-pane -t 1
      clear
      ;;
    exit)
      exit
      exit
      exit
      exit
      ;;
    *)
      echo [ERROR] "$1" は設定されていない引数です。
      ;;
  esac
fi
