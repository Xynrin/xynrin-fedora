#!/usr/bin/env bash
# 40-terminal.sh — fish + starship + 现代 CLI 工具

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

detect_target_user

log "安装 shell 和现代 CLI"
dnf_install \
    fish \
    starship \
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
    p7zip

# dotfiles
for rel in fish/config.fish starship.toml fastfetch/config.jsonc; do
    src="$SETUP_DIR/kde-dotfiles/.config/$rel"
    dst="$HOME_DIR/.config/$rel"
    [[ -f "$src" ]] && backup_and_copy "$src" "$dst"
done

# 默认 shell 切成 fish
current_shell=$(getent passwd "$TARGET_USER" | awk -F: '{print $7}')
fish_bin=$(command -v fish || true)
if [[ -n "$fish_bin" && "$current_shell" != "$fish_bin" ]]; then
    if confirm "把默认 shell 切换到 fish？" Y 15; then
        need_sudo
        exe sudo chsh -s "$fish_bin" "$TARGET_USER" \
            && success "默认 shell 已切 fish（下次登录生效）"
    else
        dim "保持原 shell: $current_shell"
    fi
else
    dim "默认 shell 已是 fish"
fi

success "终端美化完成"
