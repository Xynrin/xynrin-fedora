# 别名（仅在工具存在时生效，避免 type -q 错误）

if type -q eza
    alias ls 'eza --icons=auto --group-directories-first'
    alias ll 'eza -lh --icons=auto --group-directories-first --git'
    alias la 'eza -lha --icons=auto --group-directories-first --git'
    alias lt 'eza --tree --level=2 --icons=auto --group-directories-first'
    alias tree 'eza --tree --icons=auto --group-directories-first'
else
    alias ls 'ls --color=auto'
    alias ll 'ls -lh --color=auto'
    alias la 'ls -lha --color=auto'
end

if type -q bat
    alias cat 'bat --paging=never'
end

# 通用增强
alias grep 'grep --color=auto'
alias diff 'diff --color=auto'
alias ip 'ip --color=auto'
alias du 'du -h'
alias df 'df -h'
alias free 'free -h'

# 快捷
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias reload 'exec fish'
