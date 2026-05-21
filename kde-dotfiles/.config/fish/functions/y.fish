function y --description 'yazi 文件管理器：退出后 cd 到最后所在目录'
    if not type -q yazi
        echo "yazi 未安装：sudo dnf install yazi" >&2
        return 1
    end
    set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if read -z cwd <"$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
