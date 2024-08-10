## history
alias h='fzf-history-selection'
function fzf-history-selection() {
    BUFFER=`history -n 1 | tac  | awk '!a[$0]++' | fzf-tmux -p 80%`
    CURSOR=#BUFFER
    zle reset-prompt
}
zle -N fzf-history-selection
bindkey '^h' fzf-history-selection

## fzf-cdr
alias cdd='fzf-cdr'
function fzf-cdr() {
    target_dir=`ghq list -p | sed 's/^[^ ][^ ]*  *//' | fzf-tmux -p 80%`
    target_dir=`echo ${target_dir/\~/$HOME}`
    if [ -n "$target_dir" ]; then
      cd $target_dir
    fi
}

## fzf-diff
alias gd='git-diff'
function git-diff() {
	local selected_file="."
	while getopts ":sf:" opt; do
		case $opt in
		  f) selected_file="$OPTARG"; break ;;
		  s)
		  	selected_file="$(git ls-files -m | fzf-tmux -p 80%)"
		  	if [ -z $selected_file ]; then
		  		echo "No selected for diff."
		  		return 1
		  	fi
		  	echo "$selected_file" | pbcopy
		  	break
		  	;;
		  ?)
			echo "Unknown option selected."
			return 1
			;;
		esac
	done
	git diff $selected_file
}

## fzf-add
alias ga='git-add'
function git-add() {
  local git_repo_root
  git_repo_root=$(git rev-parse --show-toplevel)
  local selected
  selected=$(unbuffer \git status -s | fzf-tmux -m -p 80% --ansi --bind="k:preview-up" --bind="j:preview-down" \
                    --preview='
                        if [[ {} =~ "^\?\?" ]]; then
                          bat --theme="Visual Studio Dark+" {2};
                        else
                          git -C '"$git_repo_root"' diff --color=always {2};
                        fi
                    ' | \
                   awk '{print $1 " " $2}')

  if [[ -n "$selected" ]]; then
    local add_files=""
    local add_p_files=""

    while IFS= read -r line; do
      file_status=$(echo $line | awk '{print $1}')
      file_name=$(echo $line | awk '{print $2}')
      if [[ $file_status == "??" ]]; then
        add_files="$add_files $file_name"
      else
        add_p_files="$add_p_files $file_name"
      fi
    done <<< "$selected"

    if [[ -n "$add_files" ]]; then
      git add $(echo $add_files | tr '\n' ' ')
    fi

    if [[ -n "$add_p_files" ]]; then
      git add -p $(echo $add_p_files | tr '\n' ' ')
    fi
  fi

  git status --short --branch
}

## fzf-restore
alias gr='git-restore'
function git-restore() {
  local git_repo_root
  git_repo_root=$(git rev-parse --show-toplevel)
  local selected
  selected=$(unbuffer git status -s | fzf-tmux -m -p 80% --ansi --bind="k:preview-up" --bind="j:preview-down" \
                    --preview='
                        file=$(echo {} | awk "{print \$2}");
                        if [[ {} =~ "^\?\?" ]]; then
                          bat --theme="Visual Studio Dark+" -- "$file";
                        elif [[ {} =~ "^A" ]]; then
                          git -C "$git_repo_root" diff --color=always --cached -- "$file";
                        else
                          git -C "$git_repo_root" diff --color=always -- "$file";
                        fi
                     ' | \
                   awk '{ print $2 }')
  if [[ -n "$selected" ]]; then
    git restore --staged $(echo $selected | tr '\n' ' ')
  fi
  git status --short --branch
}

## fzf-stash-pop
alias gsp='git-stash-pop'
function git-stash-pop() {
  local selected
  selected=$(git stash list "$@" | fzf-tmux -p 80% --ansi --no-sort --reverse --print-query --query="$query" \
                --bind="ctrl-space:preview-page-up" \
                --bind="space:preview-page-down" \
                --bind="k:preview-up" \
                --bind="j:preview-down" \
                --preview="echo {} | cut -d':' -f1 | xargs -I {STASH} sh -c 'git stash show --color=always -p {STASH}; git show --color=always --format=\"\" -p {STASH}^3'")
  if [[ -n "$selected" ]]; then
    local variable=$(echo "$selected" | sed -n '2p' | cut -d ':' -f 1)
    git stash pop "$variable"
  fi
}

## fzf-stash-save
alias gss='git-stash-selected-files'
function git-stash-selected-files() {
  local git_repo_root
  git_repo_root=$(git rev-parse --show-toplevel)

  local instructions="Select multiple files by TAB, and then press Enter to stash them"
  local selected_files
  selected_files=$(unbuffer \git status --porcelain | \
                   fzf-tmux -p 80% --multi \
                       --bind="k:preview-up" \
                       --bind="j:preview-down" \
                       --header="$instructions" \
                       --preview='
                          if [[ {} =~ "^\?\?" ]]; then
                            cat '"$git_repo_root"'/{2};
                          else
                            git -C '"$git_repo_root"' diff --color=always {2};
                          fi
                       ' | \
                   awk '{ print $2 }'
                  )
  if [[ -z "$selected_files" ]]; then
      echo "No files selected. Exiting."
      return 1
  fi

  # Prompt for a stash message
  echo "Enter a stash message:"
  local stash_message
  read stash_message

  # Stash the selected files
  git stash push -m "$stash_message" -- `paste - <<< $selected_files`
}

## fzf-search
alias search="ag-and-code"
function ag-and-code() {
    if [ -z "$1" ]; then
      echo 'Usage: agg PATTERN'
      return 0
    fi
    result=`ag $1 | fzf-tmux -p 80%`
    line=`echo "$result" | awk -F ':' '{print $2}'`
    file=`echo "$result" | awk -F ':' '{print $1}'`
    if [ -n "$file" ]; then
      code $file
    fi
}

## fzf-switch
alias gsw='git switch $(git branch -a | tr -d " " |fzf-tmux -p 80% --height 100% --prompt "CHECKOUT BRANCH>" --preview "git log --color=always {}" | head -n 1 | sed -e "s/^\*\s*//g" | perl -pe "s/remotes\/origin\///g")'
