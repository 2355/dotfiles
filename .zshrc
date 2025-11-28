# alias
alias ls='ls -F --color=auto'
alias la='ls -laF --color=auto'
alias lah='ls -lahF --color=auto'
alias ga='git add . '
alias gb='git branch '
alias gc='git checkout '
alias gcb='git checkout -b '
alias gcm='git commit -m '
alias gd='git diff '
alias gl='git log --oneline '
alias gp='git pull '
alias gps='git push '
alias gs='git status '
alias gst='git stash '
alias gstp='git stash pop '

# snytax heighlight
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# 補完
FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
autoload -Uz compinit
compinit
# 新しいコマンドを即認識させる
zstyle ":completion:*:commands" rehash 1
# 大文字・小文字無視
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# if command not found consider using cd
setopt auto_cd

# history
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
# 他のターミナルとヒストリーを共有
setopt share_history
# ヒストリーに重複を表示しない
setopt histignorealldups
# ヒストリーに保存するときに余分なスペースを削除する
setopt hist_reduce_blanks
# ヒストリーを呼び出してから実行する間に一旦編集できる状態になる
setopt hist_verify

# prompt
autoload -Uz vcs_info
setopt prompt_subst
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr '%F{yellow}!'
zstyle ':vcs_info:git:*' unstagedstr '%F{red}+'
zstyle ':vcs_info:*' formats ' %F{green}%c%u(%b)%f'
zstyle ':vcs_info:*' actionformats ' (%b|%a)'
precmd () {
    vcs_info
}
# 左プロンプト - ディレクトリ名と git status
PROMPT='%F{cyan}%~%f${vcs_info_msg_0_}\$ %f'
# 右プロンプト - 時刻。前回のコマンド失敗時には赤くなる
RPROMPT='%(?.%{%F{green}%}.%{%F{red}%})[%*]%f'

# fzf history - ^r でコマンド履歴表示
function fzf-select-history() {
    BUFFER=$(history -n -r 1 | fzf --query "$LBUFFER")
    CURSOR=$#BUFFER
    zle reset-prompt
}
zle -N fzf-select-history
bindkey '^r' fzf-select-history

# cdr 自体の設定
if [[ -n $(echo ${^fpath}/chpwd_recent_dirs(N)) && -n $(echo ${^fpath}/cdr(N)) ]]; then
    autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
    add-zsh-hook chpwd chpwd_recent_dirs
    zstyle ':completion:*' recent-dirs-insert both
    zstyle ':chpwd:*' recent-dirs-default true
    zstyle ':chpwd:*' recent-dirs-max 1000
fi

# fzf cdr - ^q で過去に訪問した dir に移動
function fzf-cdr() {
    local selected_dir=$(cdr -l | awk '{ print $2 }' | fzf --reverse)
    if [ -n "$selected_dir" ]; then
        BUFFER="cd ${selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N fzf-cdr
setopt noflowcontrol
bindkey '^q' fzf-cdr

# fzf ghq - ^g で git の repository dir に移動
function _fzf_cd_ghq() {
    FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS} --reverse --height=50%"
    local root="$(ghq root)"
    local repo="$(ghq list | fzf --preview="ls -AF --color=always ${root}/{1}")"
    local dir="${root}/${repo}"
    [ -n "${dir}" ] && cd "${dir}"
    zle accept-line
    zle reset-prompt
}
zle -N _fzf_cd_ghq
bindkey "^g" _fzf_cd_ghq

# fgb - checkout git branch
fgb() {
    local branches branch
    branches=$(git --no-pager branch -vv) &&
    branch=$(echo "$branches" | fzf +m) &&
    git checkout $(echo "$branch" | awk '{print $1}' | sed "s/.* //")
}

# anyenv
eval "$(anyenv init -)"
