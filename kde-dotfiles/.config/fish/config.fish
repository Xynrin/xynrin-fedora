# xynrin-fedora — fish 入口
# bobthefish 是默认主题（fisher 装好后自动接管 fish_prompt）
# 真正的逻辑在 conf.d/*.fish（自动加载）与 functions/*.fish（按需加载）

if status is-interactive
    # bobthefish 主题变量（圆角 + Nerd Font 图标）
    set -g theme_powerline_fonts yes
    set -g theme_nerd_fonts yes
    set -g theme_color_scheme dracula
    set -g theme_display_user yes
    set -g theme_display_hostname yes
    set -g theme_display_git yes
    set -g theme_display_git_dirty yes
    set -g theme_display_git_master_branch yes
    set -g theme_show_exit_status yes
    set -g theme_display_jobs_verbose yes
    set -g theme_title_display_path no
    set -g theme_title_use_abbreviated_path no

    # 没装 bobthefish 时回落 starship（保证安装失败也有美观提示符）
    if not functions -q __bobthefish_glyphs
        if type -q starship
            starship init fish | source
        end
    end

    # zoxide 智能 cd
    if type -q zoxide
        zoxide init fish --cmd cd | source
    end
end
