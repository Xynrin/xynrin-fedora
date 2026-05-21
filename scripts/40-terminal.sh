#!/usr/bin/env bash
# 40-terminal.sh — fish shell + bobthefish 圆角主题 + Nerd Fonts + ~/.local/bin
# 步骤：
#   1) 装 fish + 现代 CLI（必装 fish）
#   2) 装 Nerd Fonts（FiraCode + MesloLGS）到 ~/.local/share/fonts，fc-cache
#   3) 装 fisher 包管理器，再装 bobthefish 主题
#   4) 部署 dotfiles（config.fish + conf.d + functions）
#   5) 部署 ~/.local/bin（up / xynrin / xf-* 工具）+ 改 PATH
#   6) 询问是否切默认 shell
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

detect_target_user

# ===== 1. fish + 现代 CLI =====
log "安装 fish 和现代 CLI（fish 为必装）"
if ! dnf_install_required fish; then
    error "fish 安装失败：sudo $XF_DNF install fish"
    exit 1
fi
dnf_install \
    starship \
    eza bat zoxide fzf fastfetch \
    ripgrep fd-find git \
    vim-enhanced unzip p7zip p7zip-plugins \
    nodejs npm

# ===== 2. Nerd Fonts =====
install_nerd_font() {
    local name="$1" url="$2"
    local font_dir="$HOME_DIR/.local/share/fonts"
    if [[ -d "$font_dir/$name" ]] && find "$font_dir/$name" -maxdepth 1 -name '*.ttf' -o -name '*.otf' 2>/dev/null | grep -q .; then
        dim "$name 已就位"
        return 0
    fi
    mkdir -p "$font_dir/$name"
    log "下载 Nerd Font: $name"
    local tmp="$HOME_DIR/.cache/xynrin-fedora/fonts"
    mkdir -p "$tmp"
    if as_user curl -fsSL "$url" -o "$tmp/$name.zip" 2>>"$XF_LOG_FILE"; then
        as_user unzip -oq "$tmp/$name.zip" -d "$font_dir/$name" 2>>"$XF_LOG_FILE" \
            || warn "$name 解压失败"
        # 删 windows .otf 之类多余文件
        find "$font_dir/$name" -name "*.txt" -delete 2>/dev/null || true
        find "$font_dir/$name" -name "*.md" -delete 2>/dev/null || true
        chown -R "$TARGET_USER:" "$font_dir" 2>/dev/null || true
        success "$name 已安装"
    else
        warn "$name 下载失败（网络问题），稍后可重跑模块补"
    fi
}

# 用最新 release 通用 URL（NerdFonts 官方约定）
NF_BASE="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
install_nerd_font "FiraCode"   "$NF_BASE/FiraCode.zip"
install_nerd_font "Meslo"      "$NF_BASE/Meslo.zip"
install_nerd_font "JetBrainsMono" "$NF_BASE/JetBrainsMono.zip"

log "刷新字体缓存"
exe_silent fc-cache -f

# ===== 3. fisher + bobthefish =====
install_fish_plugins() {
    # fish 必须可用（没装就跳）
    command -v fish >/dev/null 2>&1 || { warn "fish 不可用，跳过插件"; return 0; }

    # 如果已经存在 bobthefish，直接跳过
    if as_user fish -c 'functions -q fish_prompt; and fish_prompt | string match -q "*\\ue0b0*"' 2>/dev/null; then
        dim "fish 已有 bobthefish 风格 prompt"
    fi

    # 安装 fisher（如果还没装）
    if ! as_user fish -c 'type -q fisher' 2>/dev/null; then
        log "安装 fisher 插件管理器"
        as_user fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher' \
            >>"$XF_LOG_FILE" 2>&1 || warn "fisher 安装失败"
    else
        dim "fisher 已装"
    fi

    # 安装 bobthefish（自带 powerline 圆角 + Nerd Font 图标）
    if ! as_user fish -c 'type -q __bobthefish_glyphs' 2>/dev/null; then
        log "安装 bobthefish 主题"
        as_user fish -c 'fisher install oh-my-fish/theme-bobthefish' \
            >>"$XF_LOG_FILE" 2>&1 || warn "bobthefish 安装失败"
    else
        dim "bobthefish 已装"
    fi
}
install_fish_plugins

# ===== 4. dotfiles =====
log "部署 fish 配置（config.fish + conf.d/ + functions/）"
deploy_tree \
    "$SETUP_DIR/kde-dotfiles/.config/fish" \
    "$HOME_DIR/.config/fish"

log "部署 starship + fastfetch 配置"
for rel in starship.toml fastfetch/config.jsonc; do
    src="$SETUP_DIR/kde-dotfiles/.config/$rel"
    dst="$HOME_DIR/.config/$rel"
    [[ -f "$src" ]] && backup_and_copy "$src" "$dst"
done

# ===== 5. ~/.local/bin（up / xynrin / xf-*） =====
log "部署 ~/.local/bin（up / xynrin / xf-* 工具脚本）"
mkdir -p "$HOME_DIR/.local/bin"
chown "$TARGET_USER:" "$HOME_DIR/.local/bin" 2>/dev/null || true
deploy_tree \
    "$SETUP_DIR/kde-dotfiles/.local/bin" \
    "$HOME_DIR/.local/bin" \
    --exec

log "部署 VERSION + 命令速查文档"
mkdir -p "$HOME_DIR/.config/xynrin-fedora"
[[ -f "$SETUP_DIR/VERSION" ]] && \
    backup_and_copy "$SETUP_DIR/VERSION" "$HOME_DIR/.config/xynrin-fedora/VERSION"
[[ -f "$SETUP_DIR/docs/COMMANDS.md" ]] && \
    backup_and_copy "$SETUP_DIR/docs/COMMANDS.md" "$HOME_DIR/.config/xynrin-fedora/COMMANDS.md"

# 预生成 oh-my-logo banner（防止小白机器没装 npx 也能看到 logo）
generate_banner() {
    local banner="$HOME_DIR/.config/xynrin-fedora/banner.ansi"
    [[ -f "$banner" && -s "$banner" ]] && return 0
    if command -v npx >/dev/null 2>&1; then
        log "生成 oh-my-logo 横幅（缓存避免运行时联网）"
        as_user bash -c "npx --yes oh-my-logo 'xynrin-fedora' --color > '$banner' 2>/dev/null" \
            || warn "oh-my-logo 生成失败（不影响使用，xynrin 会用兜底图形）"
    else
        dim "未装 npx，将使用 xynrin 内置 ASCII 横幅"
    fi
}
generate_banner

# ===== 6. PATH =====
ensure_local_bin_path_for_bash() {
    local rc="$HOME_DIR/.bashrc"
    [[ -f "$rc" ]] || touch "$rc"
    grep -q '# xynrin-fedora: ~/.local/bin' "$rc" 2>/dev/null && return 0
    cat >> "$rc" <<'EOF'

# xynrin-fedora: ~/.local/bin
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
EOF
    chown "$TARGET_USER:" "$rc" 2>/dev/null || true
}
ensure_local_bin_path_for_bash
# fish 的 PATH 已在 conf.d/00-env.fish 里 fish_add_path -gP ~/.local/bin

# ===== 7. 切默认 shell（询问） =====
current_shell=$(getent passwd "$TARGET_USER" | awk -F: '{print $7}')
fish_bin=$(command -v fish || true)
if [[ -n "$fish_bin" && "$current_shell" != "$fish_bin" ]]; then
    if confirm "把 ${TARGET_USER} 默认 shell 切换到 fish？" Y 15; then
        if ! grep -qx "$fish_bin" /etc/shells 2>/dev/null; then
            need_sudo
            echo "$fish_bin" | sudo tee -a /etc/shells >/dev/null
        fi
        need_sudo
        if exe sudo chsh -s "$fish_bin" "$TARGET_USER"; then
            success "默认 shell 已切 fish（下次登录生效）"
        else
            warn "chsh 失败，手动跑：sudo chsh -s $fish_bin $TARGET_USER"
        fi
        # root（可选）
        if confirm "把 root 默认 shell 也切到 fish？" N 10; then
            need_sudo
            sudo chsh -s "$fish_bin" root 2>/dev/null \
                && success "root shell 已切 fish" \
                || warn "切 root shell 失败"
        fi
    else
        dim "保持原 shell: $current_shell"
    fi
else
    dim "默认 shell 已是 fish"
fi

dim ""
dim "立即预览：在新终端跑 ${BOLD}fish${NC}（或 ${BOLD}exec fish${NC}）"
dim "回滚 dotfiles：备份在 ~/.config/.xynrin-backup/"

success "终端美化完成（fish + bobthefish + Nerd Fonts）"
