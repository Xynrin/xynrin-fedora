function fish_greeting --description '登录时显示 fastfetch（tmux 内跳过）'
    if set -q TMUX
        return
    end
    if type -q fastfetch
        fastfetch
    end
end
