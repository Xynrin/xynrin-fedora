#!/usr/bin/env bash
# 20-kde-theme.sh — KDE Plasma 视觉主题（Plasma 6.x）
# 策略：dnf 装主题包，用 kwriteconfig6 写几项基础配置（深色 + 图标），
# 不覆盖 kwinrc/plasmashellrc 等用户私有布局。
# 兼容 Fedora 41+ Plasma 6；F40 及以下 Plasma 5 也能跑（kwriteconfig5 兜底）

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

detect_target_user

# 非 KDE 桌面也允许跑（装包 + 写配置不需要 KDE 在线）
# 但提示一下
if [[ "${XDG_CURRENT_DESKTOP:-}" != *"KDE"* ]]; then
    warn "当前桌面环境不是 KDE，仍会装主题包并写配置，下次登 KDE 会生效"
fi

log "安装 KDE 视觉增强包"
dnf_install \
    papirus-icon-theme \
    breeze-gtk \
    kvantum

# 壁纸：按当前 Fedora 版本号挑包，找不到就装通用 fedora-backgrounds
fedver=$(xf_fedora_version)
wp_pkg="f${fedver}-backgrounds"

if ! rpm -q "$wp_pkg" >/dev/null 2>&1; then
    if "$XF_DNF" -q info "$wp_pkg" >/dev/null 2>&1; then
        dnf_install "$wp_pkg"
    else
        warn "$wp_pkg 不在源中，回退到 fedora-backgrounds 通用包"
        dnf_install fedora-backgrounds 2>/dev/null || \
            dnf_install desktop-backgrounds-basic 2>/dev/null || \
            warn "未能装上壁纸包，手动到系统设置 → 壁纸 自行选择"
    fi
fi

# kwriteconfig 工具：F41+ 默认 Plasma 6，用 kwriteconfig6
kw=""
for c in kwriteconfig6 kwriteconfig5 kwriteconfig; do
    command -v "$c" >/dev/null 2>&1 && { kw="$c"; break; }
done

if [[ -z "$kw" ]]; then
    warn "未找到 kwriteconfig，跳过 Plasma 主题配置"
    success "主题包已装，请手动在系统设置里切主题"
    exit 0
fi

dim "使用 $kw 写入主题配置"

as_user_kw() { as_user "$kw" "$@"; }

# ---- 备份：只备份本脚本会动的文件，面板布局/快捷键单独备份以防万一 ----
backup_dir="$HOME_DIR/.config/.xynrin-backup"
stamp=$(date +%Y%m%d-%H%M%S)
mkdir -p "$backup_dir"
backup_tar="$backup_dir/plasma-before-${stamp}.tar.gz"

log "备份当前 Plasma 相关配置到 $backup_tar"
(
    cd "$HOME_DIR/.config" 2>/dev/null && \
    tar -czf "$backup_tar" \
        --ignore-failed-read \
        kdeglobals \
        plasmarc \
        plasma-org.kde.plasma.desktop-appletsrc \
        kwinrc \
        plasmashellrc \
        kglobalshortcutsrc 2>/dev/null
) && chown "$TARGET_USER:" "$backup_tar" 2>/dev/null
dim "回滚命令：tar -xzf '$backup_tar' -C ~/.config/"

# ---- 只改色板级 key，不碰布局类文件 ----
log "设置 Plasma 深色主题 + Papirus 图标（不改动面板/小组件/快捷键）"
as_user_kw --file kdeglobals --group General --key ColorScheme BreezeDark || true
as_user_kw --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop || true
as_user_kw --file kdeglobals --group Icons --key Theme Papirus-Dark || true

# ---- 不注销即生效（命令不存在或失败都 OK）----
log "实时应用主题（免注销）"
as_user plasma-apply-colorscheme BreezeDark >/dev/null 2>&1 || true
as_user plasma-apply-lookandfeel -a org.kde.breezedark.desktop >/dev/null 2>&1 || true
as_user plasma-apply-desktoptheme breeze-dark >/dev/null 2>&1 || true

success "KDE 视觉主题已配置"
dim "面板布局 / 小组件 / 快捷键保持原样；想进一步调：系统设置 → 全局主题"
