#!/usr/bin/env bash
# 20-kde-theme.sh — KDE Plasma 视觉主题
# 策略：dnf 装主题包，用 kwriteconfig6 写几项基础配置（深色 + 图标），
# 不覆盖 kwinrc/plasmashellrc 等用户私有布局。

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

detect_target_user

log "安装 KDE 视觉增强包"
dnf_install \
    papirus-icon-theme \
    breeze-gtk \
    kvantum \
    f38-backgrounds \
    f39-backgrounds \
    f40-backgrounds 2>/dev/null || true

# 核心壁纸包（按 Fedora 版本号挑一个存在的）
fedver=$(rpm -E %fedora 2>/dev/null || echo "0")
wp_pkg="f${fedver}-backgrounds"
rpm -q "$wp_pkg" >/dev/null 2>&1 || dnf_install "$wp_pkg" 2>/dev/null || true

# kwriteconfig 工具
kw=""
for c in kwriteconfig6 kwriteconfig5 kwriteconfig; do
    command -v "$c" >/dev/null 2>&1 && { kw="$c"; break; }
done

if [[ -z "$kw" ]]; then
    warn "未找到 kwriteconfig，跳过 Plasma 主题配置"
    success "主题包已装，请手动在系统设置里切主题"
    exit 0
fi

as_user_kw() { as_user "$kw" "$@"; }

log "设置 Plasma 深色主题 + Papirus 图标"
as_user_kw --file kdeglobals --group General --key ColorScheme BreezeDark || true
as_user_kw --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop || true
as_user_kw --file kdeglobals --group Icons --key Theme Papirus-Dark || true

# 通用 UI 小改进：开启左键单击打开（对小白更接近 Windows 直觉可选，这里不强制）
# as_user_kw --file kdeglobals --group KDE --key SingleClick false || true

success "KDE 视觉主题已配置（注销重登后完全生效）"
dim "想进一步调：系统设置 → 全局主题 / 颜色 / 图标"
