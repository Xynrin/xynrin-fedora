# Disable fish greeting
set fish_greeting

if status is-interactive
    # Show system info on startup (clean, won't show in tmux)
    if not set -q TMUX
        fastfetch
    end
end

# ===== Editor =====
set -gx EDITOR vim
set -gx VISUAL vim
set -gx LANG zh_CN.UTF-8

# ===== xdg =====
set -gx XDG_CONFIG_HOME ~/.config

# ===== Aliases =====
if type -q eza
    alias ls='eza --icons=auto --group-directories-first'
    alias ll='eza -lh --icons=auto --group-directories-first --git'
    alias la='eza -lha --icons=auto --group-directories-first --git'
    alias l='eza --icons=auto --group-directories-first'
    alias lt='eza -lh --icons=auto --sort=modified'
    alias tree='eza --tree --icons=auto --group-directories-first'
else
    alias ls='ls --color=auto'
    alias ll='ls -lh'
    alias la='ls -A'
    alias l='ls -CF'
    alias lt='ls -lhtr'
end

alias cat='bat --paging=never'
alias batcat='bat --paging=never'

alias grep='grep --color=auto'
alias diff='diff --color=auto'

alias du='du -h'
alias df='df -h'
alias free='free -h'

alias reload='exec fish'
alias cls='clear; fastfetch'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias mkdir='mkdir -p'

# ===== Abbreviations (expand after space) =====
abbr -a g git
abbr -a ga 'git add'
abbr -a gc 'git commit'
abbr -a gcm 'git commit -m'
abbr -a gp 'git push'
abbr -a gpl 'git pull'
abbr -a gst 'git status'
abbr -a gd 'git diff'
abbr -a gco 'git checkout'
abbr -a gb 'git branch'
abbr -a gl 'git log --oneline --graph --decorate'
abbr -a gla 'git log --oneline --graph --decorate --all'
abbr -a gcl 'git clone'

abbr -a vi vim
abbr -a nv vim

abbr -a py python3
abbr -a ipy ipython

abbr -a please 'sudo !!'

# ===== fzf =====
set -gx FZF_DEFAULT_OPTS '--height 60% --layout=reverse --border --color=fg:-1,bg:-1,hl:5,fg+:3,bg+:236,hl+:5,info:4,prompt:3,pointer:3,marker:2,spinner:1,header:6'

# ===== History =====
set -gx fish_history_max 10000
set -gx history_ignore_cmds "ls ll la lt cd"

# ===== man pages with bat =====
set -gx MANPAGER "sh -c 'col -bx | bat --language=man --plain'"
set -gx MANROFFOPT "-c"

# ===== Node =====
# set -gx nvm_default_version latest

# ===== Path =====
fish_add_path ~/.local/bin
alias opt='bash ~/opt.sh'

# ===== zoxide (smart cd) =====
if type -q zoxide
    zoxide init fish --cmd cd | source
end
