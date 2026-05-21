# abbreviation：按空格自动展开（比 alias 更友好，命令历史里是真实命令）

# git
abbr -a g     git
abbr -a ga    'git add'
abbr -a gaa   'git add --all'
abbr -a gc    'git commit'
abbr -a gcm   'git commit -m'
abbr -a gca   'git commit --amend'
abbr -a gp    'git push'
abbr -a gpl   'git pull'
abbr -a gst   'git status'
abbr -a gd    'git diff'
abbr -a gds   'git diff --staged'
abbr -a gco   'git checkout'
abbr -a gsw   'git switch'
abbr -a gb    'git branch'
abbr -a gl    'git log --oneline --graph --decorate'
abbr -a glo   'git log --oneline --graph --decorate --all'

# dnf / flatpak
abbr -a in    'sudo dnf install'
abbr -a rm-   'sudo dnf remove'
abbr -a up    'sudo dnf upgrade --refresh'
abbr -a fi    'flatpak install flathub'
abbr -a fu    'flatpak update'
abbr -a fr    'flatpak run'

# systemd
abbr -a sc    'systemctl'
abbr -a scu   'systemctl --user'
abbr -a jc    'journalctl'
abbr -a jcu   'journalctl --user'

# 杂项
abbr -a please 'sudo $history[1]'
abbr -a c     clear
abbr -a q     exit
