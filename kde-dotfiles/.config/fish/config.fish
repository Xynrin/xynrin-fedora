# xynrin-fedora — 通用 fish 配置（无个人 tide/alias）
if status is-interactive
    set fish_greeting ""

    # starship 提示符
    if type -q starship
        starship init fish | source
    end

    # zoxide 智能 cd
    if type -q zoxide
        zoxide init fish --cmd cd | source
    end

    # 登录时显示 fastfetch（非 tmux 内）
    if not set -q TMUX
        if type -q fastfetch
            fastfetch
        end
    end
end

# ===== 环境 =====
set -gx EDITOR vim
set -gx VISUAL vim
set -gx LANG zh_CN.UTF-8
fish_add_path ~/.local/bin

# ===== Aliases =====
if type -q eza
    alias ls 'eza --icons=auto --group-directories-first'
    alias ll 'eza -lh --icons=auto --group-directories-first --git'
    alias la 'eza -lha --icons=auto --group-directories-first --git'
    alias tree 'eza --tree --icons=auto --group-directories-first'
else
    alias ls 'ls --color=auto'
    alias ll 'ls -lh'
    alias la 'ls -A'
end

if type -q bat
    alias cat 'bat --paging=never'
end

alias grep 'grep --color=auto'
alias diff 'diff --color=auto'
alias du 'du -h'
alias df 'df -h'
alias free 'free -h'
alias reload 'exec fish'

alias .. 'cd ..'
alias ... 'cd ../..'
alias mkdir 'mkdir -p'

# ===== 快捷缩写 (abbreviation) =====
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

abbr -a please 'sudo !!'

# ===== yazi 文件管理器（若有）=====
if type -q yazi
    function y
        set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if read -z cwd <"$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
    end
end

# ===== fzf 默认选项 =====
set -gx FZF_DEFAULT_OPTS '--height 60% --layout=reverse --border'

# ===== man with bat =====
if type -q bat
    set -gx MANPAGER "sh -c 'col -bx | bat --language=man --plain'"
    set -gx MANROFFOPT "-c"
end
