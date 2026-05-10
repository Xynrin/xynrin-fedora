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

log "安装 fcitx5 拼音"
dnf_install \
    fcitx5 \
    fcitx5-chinese-addons \
    fcitx5-configtool \
    fcitx5-gtk \
    fcitx5-qt \
    fcitx5-autostart

# 环境变量（XWayland + X11 应用用）
env_file="$HOME_DIR/.config/environment.d/fcitx5.conf"
if [[ ! -f "$env_file" ]] || ! grep -q "GTK_IM_MODULE=fcitx" "$env_file" 2>/dev/null; then
    mkdir -p "$(dirname "$env_file")"
    cat > "$env_file" <<'EOF'
# xynrin-fedora: fcitx5 input method
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
EOF
    success "写入 $env_file"
else
    dim "fcitx5 环境变量已配"
fi

# fcitx5 默认配置（默认英文+拼音组）
for f in config profile; do
    src="$SETUP_DIR/kde-dotfiles/.config/fcitx5/$f"
    dst="$HOME_DIR/.config/fcitx5/$f"
    [[ -f "$src" ]] && backup_and_copy "$src" "$dst"
done

# fontconfig 默认字体偏好
src="$SETUP_DIR/kde-dotfiles/.config/fontconfig/fonts.conf"
dst="$HOME_DIR/.config/fontconfig/fonts.conf"
[[ -f "$src" ]] && backup_and_copy "$src" "$dst"

# 刷新字体缓存
exe fc-cache -f >/dev/null 2>&1 || true

success "字体 + 输入法就绪（注销重登后 Ctrl+Space 切换中英）"
