#!/usr/bin/env bash
# 20-kde-theme.sh — KDE Plasma 6 视觉美化（Fedora 44）
#
# 关键设计：
#   1. 安装：图标 / Kvantum / Papirus / Breeze GTK / 中文字体（必装那些不能跳过）
#   2. 写配置：用 plasma-apply-* 系列命令是首选，因为它会同时写
#      ~/.config/kdeglobals + ~/.config/kdedefaults/* + 通知 plasmashell
#      （直接写 kdeglobals 在 Plasma 6 上经常不生效，因为还有 kdedefaults 兜底）
#   3. 兜底：找不到 plasma-apply-* 才回落到 kwriteconfig6 + 触发 reload
#   4. GTK：写 settings.ini + gsettings + ~/.gtkrc-2.0 + 全局光标
#   5. 强制刷新：plasmashell --replace 后台重启（用户不会感知）

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

detect_target_user

is_kde_session=0
[[ "${XDG_CURRENT_DESKTOP:-}" == *"KDE"* ]] && is_kde_session=1

if [[ $is_kde_session -eq 0 ]]; then
    warn "当前会话不是 KDE，仍会装包写配置，下次以 KDE 登录生效"
fi

# ---- 安装主题相关包 ----
log "安装主题包（图标 / Kvantum / Breeze GTK / 中文字体）"
dnf_install \
    papirus-icon-theme \
    breeze-gtk \
    breeze-cursor-theme \
    breeze-icon-theme \
    kvantum \
    google-noto-sans-cjk-vf-fonts \
    google-noto-sans-fonts

# 壁纸
fedver=$(xf_fedora_version)
wp_pkg="f${fedver}-backgrounds"
if ! rpm -q "$wp_pkg" >/dev/null 2>&1; then
    if "$XF_DNF" -q info "$wp_pkg" >/dev/null 2>&1; then
        dnf_install "$wp_pkg"
    else
        dnf_install fedora-backgrounds 2>/dev/null \
            || dnf_install desktop-backgrounds-basic 2>/dev/null \
            || warn "未能装上壁纸包，手动到系统设置 → 壁纸 自行选择"
    fi
fi

# ---- 备份当前 KDE 配置 ----
_xf_init_backup_dir
stamp=$(date +%Y%m%d-%H%M%S)
backup_tar="$XF_BACKUP_DIR/plasma-${stamp}.tar.gz"

log "备份当前 Plasma / GTK 配置"
(
    cd "$HOME_DIR/.config" 2>/dev/null && \
    tar -czf "$backup_tar" \
        --ignore-failed-read \
        kdeglobals \
        kdedefaults \
        plasmarc \
        kcminputrc \
        gtk-3.0 gtk-4.0 \
        Trolltech.conf \
        plasma-org.kde.plasma.desktop-appletsrc \
        kwinrc \
        plasmashellrc \
        kglobalshortcutsrc 2>/dev/null
) && chown "$TARGET_USER:" "$backup_tar" 2>/dev/null
dim "备份: $backup_tar"

# ===== Plasma 主题 =====
# 优先使用 plasma-apply-* 系列：会同时写 kdeglobals + kdedefaults + 通知 plasmashell
# 这是 Plasma 5.20+ / Plasma 6 的官方推荐做法。直接 kwriteconfig 经常被 kdedefaults 覆盖。

apply_kde_theme_via_plasma_apply() {
    local ok=0
    if command -v plasma-apply-lookandfeel >/dev/null 2>&1; then
        log "应用 LookAndFeel: BreezeDark"
        as_user plasma-apply-lookandfeel -a org.kde.breezedark.desktop 2>&1 | grep -v '^$' | sed 's/^/    /' || true
        ok=1
    fi
    if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
        log "应用 ColorScheme: BreezeDark"
        as_user plasma-apply-colorscheme BreezeDark 2>&1 | grep -v '^$' | sed 's/^/    /' || true
        ok=1
    fi
    if command -v plasma-apply-desktoptheme >/dev/null 2>&1; then
        log "应用 DesktopTheme: breeze-dark"
        as_user plasma-apply-desktoptheme breeze-dark 2>&1 | grep -v '^$' | sed 's/^/    /' || true
    fi
    if command -v plasma-apply-cursortheme >/dev/null 2>&1; then
        log "应用 CursorTheme: Breeze_Snow"
        as_user plasma-apply-cursortheme Breeze_Snow 2>&1 | grep -v '^$' | sed 's/^/    /' || true
    fi
    return $((1 - ok))
}

apply_kde_theme_via_kwriteconfig() {
    local kw=""
    for c in kwriteconfig6 kwriteconfig5 kwriteconfig; do
        command -v "$c" >/dev/null 2>&1 && { kw="$c"; break; }
    done
    [[ -z "$kw" ]] && { warn "无 kwriteconfig，跳过"; return 1; }

    dim "回落到 $kw 直写"

    # Plasma 6 的关键：必须同时写 kdeglobals 和 kdedefaults/kdeglobals
    local kdedef="$HOME_DIR/.config/kdedefaults"
    mkdir -p "$kdedef"
    chown -R "$TARGET_USER:" "$kdedef" 2>/dev/null || true

    local files=("kdeglobals" "kdedefaults/kdeglobals")
    for f in "${files[@]}"; do
        as_user "$kw" --file "$f" --group General --key ColorScheme       BreezeDark || true
        as_user "$kw" --file "$f" --group KDE     --key LookAndFeelPackage org.kde.breezedark.desktop || true
        as_user "$kw" --file "$f" --group KDE     --key widgetStyle        Breeze || true
        as_user "$kw" --file "$f" --group Icons   --key Theme              Papirus-Dark || true
        as_user "$kw" --file "$f" --group General --key fixed              "JetBrains Mono,11,-1,5,50,0,0,0,0,0,Regular" || true
        as_user "$kw" --file "$f" --group General --key font               "Noto Sans CJK SC,11,-1,5,50,0,0,0,0,0,Regular" || true
    done

    as_user "$kw" --file kcminputrc --group Mouse --key cursorTheme Breeze_Snow || true

    chown -R "$TARGET_USER:" "$HOME_DIR/.config/kdeglobals" "$HOME_DIR/.config/kcminputrc" 2>/dev/null || true
}

if apply_kde_theme_via_plasma_apply; then
    success "Plasma 主题已通过 plasma-apply-* 应用"
else
    warn "plasma-apply-* 不可用，使用 kwriteconfig 直写"
    apply_kde_theme_via_kwriteconfig
fi

# ===== GTK 跟随深色 =====
log "GTK 应用跟随深色"

write_gtk_ini() {
    local dir="$1"
    mkdir -p "$dir"
    local ini="$dir/settings.ini"
    cat > "$ini" <<'EOF'
[Settings]
gtk-theme-name=Breeze-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Breeze_Snow
gtk-cursor-theme-size=24
gtk-font-name=Noto Sans CJK SC 10
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=icon:minimize,maximize,close
EOF
    chown "$TARGET_USER:" "$ini" 2>/dev/null || true
}
write_gtk_ini "$HOME_DIR/.config/gtk-3.0"
write_gtk_ini "$HOME_DIR/.config/gtk-4.0"

# GTK2 老应用
gtk2rc="$HOME_DIR/.gtkrc-2.0"
cat > "$gtk2rc" <<'EOF'
gtk-theme-name="Breeze-Dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-cursor-theme-name="Breeze_Snow"
gtk-font-name="Noto Sans CJK SC 10"
EOF
chown "$TARGET_USER:" "$gtk2rc" 2>/dev/null || true

# gsettings（libadwaita 应用读这个）
if command -v gsettings >/dev/null 2>&1; then
    as_user gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    as_user gsettings set org.gnome.desktop.interface gtk-theme    'Breeze-Dark' 2>/dev/null || true
    as_user gsettings set org.gnome.desktop.interface icon-theme   'Papirus-Dark' 2>/dev/null || true
    as_user gsettings set org.gnome.desktop.interface cursor-theme 'Breeze_Snow' 2>/dev/null || true
    as_user gsettings set org.gnome.desktop.interface font-name    'Noto Sans CJK SC 10' 2>/dev/null || true
fi

# 全局光标主题
default_index="$HOME_DIR/.icons/default/index.theme"
mkdir -p "$(dirname "$default_index")"
cat > "$default_index" <<'EOF'
[Icon Theme]
Inherits=Breeze_Snow
EOF
chown -R "$TARGET_USER:" "$HOME_DIR/.icons" 2>/dev/null || true

# ===== 强制刷新（不重登也能见效）=====
if [[ $is_kde_session -eq 1 && ${DRY_RUN:-0} -eq 0 ]]; then
    log "刷新 KDE 服务（不会注销当前会话）"
    # 1. KWin 重载（窗口装饰、标题栏色彩）
    if command -v qdbus6 >/dev/null 2>&1; then
        as_user qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
    elif command -v qdbus >/dev/null 2>&1; then
        as_user qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
    fi

    # 2. KGlobalAccel 重载（防止快捷键飞了）
    if command -v qdbus6 >/dev/null 2>&1; then
        as_user qdbus6 org.kde.kded6 /kded reconfigure 2>/dev/null || true
    fi

    # 3. plasmashell 重启（最后兜底，让面板/小组件吃到新主题）
    # 用 nohup + setsid 后台跑，避免脚本退出时被杀
    if command -v plasmashell >/dev/null 2>&1; then
        as_user bash -c 'nohup setsid plasmashell --replace >/dev/null 2>&1 < /dev/null &' || true
        dim "plasmashell 已后台重启，1-2 秒后面板会刷新"
    fi
fi

success "KDE 视觉主题已应用（深色 + Papirus + GTK 跟随 + 中文字体）"
dim "面板布局 / 快捷键保留原样；切回浅色: xf-theme light"
