#!/usr/bin/env bash
# 30-fonts-cjk.sh — 中文字体 + fcitx5 拼音输入法

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

detect_target_user

log "安装中文字体"
dnf_install \
    google-noto-sans-cjk-vf-fonts \
    google-noto-serif-cjk-vf-fonts \
    google-noto-sans-mono-cjk-vf-fonts \
    google-noto-emoji-fonts \
    jetbrains-mono-fonts-all \
    cascadia-code-fonts

log "安装 fcitx5 拼音（必装）"
if ! dnf_install_required fcitx5 fcitx5-chinese-addons; then
    error "fcitx5 安装失败"
    exit 1
fi

# 可选附件
dnf_install \
    fcitx5-configtool \
    fcitx5-gtk \
    fcitx5-qt \
    fcitx5-autostart

# 环境变量（XWayland + X11 应用）
env_file="$HOME_DIR/.config/environment.d/fcitx5.conf"
mkdir -p "$(dirname "$env_file")"
cat > "$env_file" <<'EOF'
# xynrin-fedora: fcitx5 input method
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
INPUT_METHOD=fcitx
EOF
chown -R "$TARGET_USER:" "$(dirname "$env_file")" 2>/dev/null || true
success "已写: $env_file"

# fcitx5 默认配置
log "部署 fcitx5 配置（默认英文+拼音组）"
for f in config profile; do
    src="$SETUP_DIR/kde-dotfiles/.config/fcitx5/$f"
    dst="$HOME_DIR/.config/fcitx5/$f"
    [[ -f "$src" ]] && backup_and_copy "$src" "$dst"
done

# fontconfig
log "部署 fontconfig 默认偏好"
src="$SETUP_DIR/kde-dotfiles/.config/fontconfig/fonts.conf"
dst="$HOME_DIR/.config/fontconfig/fonts.conf"
[[ -f "$src" ]] && backup_and_copy "$src" "$dst"

exe_silent fc-cache -f

# 立即启动 fcitx5（如果当前桌面会话）
if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" && ${DRY_RUN:-0} -eq 0 ]]; then
    if ! pgrep -u "$TARGET_USER" -x fcitx5 >/dev/null 2>&1; then
        log "启动 fcitx5"
        as_user bash -c 'nohup setsid fcitx5 -d >/dev/null 2>&1 < /dev/null &' || true
    else
        dim "fcitx5 已在运行，重载配置"
        as_user fcitx5-remote -r 2>/dev/null || true
    fi
fi

success "字体 + 输入法就绪（注销重登后 Ctrl+Space 切换中英）"
