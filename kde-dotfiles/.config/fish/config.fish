# xynrin-fedora — fish 入口
# 真正的逻辑在 conf.d/*.fish（自动加载）与 functions/*.fish（按需加载）
# 这里只做最小化引导，便于用户自己增删模块

if status is-interactive
    # starship 提示符（无则自动跳过）
    if type -q starship
        starship init fish | source
    end

    # zoxide 智能 cd（替代内置 cd）
    if type -q zoxide
        zoxide init fish --cmd cd | source
    end
end
