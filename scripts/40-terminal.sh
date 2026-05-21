#!/usr/bin/env bash
# 40-terminal.sh — fish + starship + 现代 CLI + ~/.local/bin 工具脚本

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

detect_target_user

# ---- 必装：fish + starship 是终端美化的核心，缺任一立即失败提醒 ----
log "安装 fish 和 starship（必装）"
if ! dnf_install_required fish starship; then
    error "fish 或 starship 安装失败，请检查网络 / RPM Fusion 是否启用"
    error "诊断命令：sudo $XF_DNF install fish starship"
    exit 1
fi

# ---- 现代 CLI（缺一两个不致命，dnf_install 会逐个重试）----
log "安装现代 CLI 工具"
dnf_install \
    eza \
    bat \
    zoxide \
    fzf \
    fastfetch \
    ripgrep \
    fd-find \
    git \
    vim-enhanced \
    unzip \
    p7zip \
    p7zip-plugins

# ---- fish 配置（递归部署整个 .config/fish 目录，强刷）----
log "部署 fish 配置（config.fish + conf.d/ + functions/）"
deploy_tree \
    "$SETUP_DIR/kde-dotfiles/.config/fish" \
    "$HOME_DIR/.config/fish"

# ---- starship + fastfetch ----
log "部署 starship + fastfetch 配置"
for rel in starship.toml fastfetch/config.jsonc; do
    src="$SETUP_DIR/kde-dotfiles/.config/$rel"
    dst="$HOME_DIR/.config/$rel"
    [[ -f "$src" ]] && backup_and_copy "$src" "$dst"
done

# ---- ~/.local/bin 工具脚本 ----
if [[ -d "$SETUP_DIR/kde-dotfiles/.local/bin" ]]; then
    log "部署 xf-* 工具脚本到 ~/.local/bin"
    deploy_tree \
        "$SETUP_DIR/kde-dotfiles/.local/bin" \
        "$HOME_DIR/.local/bin" \
        --exec
fi

# ---- bash 兜底 PATH ----
ensure_local_bin_path_for_bash() {
    local rc="$HOME_DIR/.bashrc"
    [[ -f "$rc" ]] || return 0
    grep -q '# xynrin-fedora: ~/.local/bin' "$rc" 2>/dev/null && return 0
    cat >> "$rc" <<'EOF'

# xynrin-fedora: ~/.local/bin
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
EOF
    chown "$TARGET_USER:" "$rc" 2>/dev/null || true
}
ensure_local_bin_path_for_bash

# ---- 默认 shell 切 fish ----
current_shell=$(getent passwd "$TARGET_USER" | awk -F: '{print $7}')
fish_bin=$(command -v fish || true)
if [[ -n "$fish_bin" && "$current_shell" != "$fish_bin" ]]; then
    if confirm "把默认 shell 切换到 fish？" Y 15; then
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
    else
        dim "保持原 shell: $current_shell"
    fi
else
    dim "默认 shell 已是 fish"
fi

# ---- 提示一次性预览 ----
dim ""
dim "立即预览效果：在新终端窗口跑 ${BOLD}fish${NC}"
dim "回滚 dotfiles：备份在 ~/.config/.xynrin-backup/"

success "终端美化完成"
