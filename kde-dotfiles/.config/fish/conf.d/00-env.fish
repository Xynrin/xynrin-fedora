# 环境变量（登录 shell + 交互 shell 都跑）
set -gx EDITOR vim
set -gx VISUAL vim
set -gx PAGER less
set -gx LESS '-R --use-color -Dd+r$Du+b'

# 中文 locale（Fedora 装了 glibc-langpack-zh 才有效，否则会回退）
if locale -a 2>/dev/null | grep -qi '^zh_CN.utf'
    set -gx LANG zh_CN.UTF-8
end

# ~/.local/bin 加 PATH（xynrin-fedora 工具脚本住这里）
fish_add_path -gP ~/.local/bin

# fzf 默认外观
set -gx FZF_DEFAULT_OPTS '--height 60% --layout=reverse --border=rounded --color=label:cyan,marker:cyan,pointer:cyan'

# bat 当 man 渲染器（更好看的 man）
if type -q bat
    set -gx MANPAGER "sh -c 'col -bx | bat --language=man --plain'"
    set -gx MANROFFOPT '-c'
end

# 关闭 fish 自带 greeting，留给 fish_greeting 函数自定义
set -U fish_greeting ''
