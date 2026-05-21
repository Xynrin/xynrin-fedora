#!/usr/bin/env bash
# 20-kde-theme.sh — KDE 美化（3 套主题方案，交互式选择）
#
# 1. 现代简约：Layan + Tela + Bibata
# 2. 绚丽多彩：Sweet + Candy + Sweet 光标
# 3. 暗黑质感：Orchis + Colloid + Nordic
#
# 资源安装策略：
#   - 优先 Fedora repo / RPM Fusion，包名命中即装
#   - 失败回落到 git clone 上游脚本安装到 ~/.local/share/{plasma/desktoptheme,icons,…}
#   - SDDM 主题同步切换并改背景

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

detect_target_user

is_kde_session=0
[[ "${XDG_CURRENT_DESKTOP:-}" == *"KDE"* ]] && is_kde_session=1

# ===== 备份当前 Plasma / GTK 配置 =====
_xf_init_backup_dir
stamp=$(date +%Y%m%d-%H%M%S)
backup_tar="$XF_BACKUP_DIR/plasma-${stamp}.tar.gz"
log "备份当前 Plasma / GTK 配置 → $backup_tar"
(
    cd "$HOME_DIR/.config" 2>/dev/null && \
    tar -czf "$backup_tar" --ignore-failed-read \
        kdeglobals kdedefaults plasmarc kcminputrc \
        gtk-3.0 gtk-4.0 Trolltech.conf \
        plasma-org.kde.plasma.desktop-appletsrc kwinrc \
        plasmashellrc kglobalshortcutsrc 2>/dev/null
) && chown "$TARGET_USER:" "$backup_tar" 2>/dev/null
dim "回滚: tar -xzf $backup_tar -C ~/.config/"

# ===== 通用依赖 =====
log "安装通用主题依赖"
dnf_install \
    kvantum \
    breeze-gtk breeze-cursor-theme breeze-icon-theme \
    sddm sddm-kcm \
    google-noto-sans-cjk-vf-fonts google-noto-sans-fonts \
    ImageMagick

# ===== 交互选择 =====
THEME_OPTIONS=(
    "1|modern|现代简约|Layan + Tela 图标 + Bibata 光标|layan-kde tela-icon-theme"
    "2|colorful|绚丽多彩|Sweet + Candy 图标 + Sweet 光标|sweet-kde sweet-icon-theme"
    "3|dark|暗黑质感|Orchis + Colloid 图标 + Nordic 光标|orchis-kde-theme colloid-icon-theme"
)

print_theme_menu() {
    echo ""
    echo -e "${C1}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${BOLD}${H_WHITE}KDE 全局主题选择${NC}  ${DIM}(Plasma 样式 + 图标 + 光标 + SDDM)${NC}"
    echo -e "${C1}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    for opt in "${THEME_OPTIONS[@]}"; do
        IFS='|' read -r num id title detail _ <<< "$opt"
        printf "    ${C3}%s${NC} ${BOLD}%s${NC}\n" "$num." "$title"
        printf "       ${DIM}%s${NC}\n\n" "$detail"
    done
    echo -e "    ${DIM}0. 跳过 KDE 美化${NC}"
    echo ""
}

PICK_NUM=""
PICK_ID=""
PICK_TITLE=""
PICK_PKGS=""

select_theme() {
    if [[ "${XF_NONINTERACTIVE:-0}" == "1" ]]; then
        # 非交互模式：默认现代简约
        PICK_NUM="1"
        IFS='|' read -r PICK_NUM PICK_ID PICK_TITLE _ PICK_PKGS <<< "${THEME_OPTIONS[0]}"
        log "非交互：使用默认 [$PICK_TITLE]"
        return 0
    fi

    print_theme_menu
    local ans
    while true; do
        read -r -p "$(echo -e "    ${C3}❯${NC} 输入数字 1-3 选择主题 (0 跳过): ")" ans
        case "${ans:-1}" in
            0) log "跳过 KDE 美化"; return 1 ;;
            1|2|3)
                IFS='|' read -r PICK_NUM PICK_ID PICK_TITLE _ PICK_PKGS <<< "${THEME_OPTIONS[$((ans-1))]}"
                log "已选择 [$PICK_NUM. $PICK_TITLE]"
                return 0
                ;;
            *) warn "请输入 0-3" ;;
        esac
    done
}

select_theme || exit 0

# ===== 主题资源安装（Fedora repo 优先，git 上游回落） =====
install_modern() {
    log "安装现代简约主题资源"
    # Fedora 自带 layan-kde / tela-icon-theme（官方仓库自 F38 起）
    dnf_install layan-kde 2>/dev/null || install_layan_from_git
    dnf_install tela-icon-theme 2>/dev/null || install_tela_from_git
    install_bibata_cursor
}

install_layan_from_git() {
    warn "Fedora 仓库无 layan-kde，回落 git 安装"
    local tmp="$HOME_DIR/.cache/xynrin-fedora/layan"
    mkdir -p "$tmp"
    if as_user git clone --depth 1 https://github.com/vinceliuice/Layan-kde.git "$tmp/Layan-kde" 2>/dev/null; then
        ( cd "$tmp/Layan-kde" && as_user bash install.sh >>"$XF_LOG_FILE" 2>&1 ) || warn "Layan 主题安装失败"
    fi
}

install_tela_from_git() {
    warn "Fedora 仓库无 tela-icon-theme，回落 git 安装"
    local tmp="$HOME_DIR/.cache/xynrin-fedora/tela"
    mkdir -p "$tmp"
    if as_user git clone --depth 1 https://github.com/vinceliuice/Tela-icon-theme.git "$tmp/Tela" 2>/dev/null; then
        ( cd "$tmp/Tela" && as_user bash install.sh -a >>"$XF_LOG_FILE" 2>&1 ) || warn "Tela 图标安装失败"
    fi
}

install_bibata_cursor() {
    if rpm -q bibata-cursor-themes >/dev/null 2>&1; then
        dim "Bibata 光标已装"
        return 0
    fi
    if dnf_install bibata-cursor-themes 2>/dev/null; then
        return 0
    fi
    log "从 GitHub release 下载 Bibata 光标"
    local tmp="$HOME_DIR/.cache/xynrin-fedora/bibata"
    mkdir -p "$tmp" "$HOME_DIR/.local/share/icons"
    local url="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz"
    if as_user curl -fsSL "$url" -o "$tmp/bibata.tar.xz" 2>>"$XF_LOG_FILE"; then
        as_user tar -xJf "$tmp/bibata.tar.xz" -C "$HOME_DIR/.local/share/icons/" || warn "Bibata 解压失败"
    else
        warn "Bibata 下载失败，使用 Breeze_Snow 兜底"
    fi
}

install_colorful() {
    log "安装绚丽多彩主题资源"
    # Sweet 不在 Fedora 仓库，需从上游
    local tmp="$HOME_DIR/.cache/xynrin-fedora/sweet"
    mkdir -p "$tmp"
    if as_user git clone --depth 1 https://github.com/EliverLara/Sweet.git "$tmp/Sweet" 2>/dev/null; then
        # KDE 全局主题
        as_user mkdir -p "$HOME_DIR/.local/share/plasma/look-and-feel"
        as_user cp -rf "$tmp/Sweet/kde/look-and-feel/." "$HOME_DIR/.local/share/plasma/look-and-feel/" 2>/dev/null || true
        # Plasma 桌面主题
        as_user mkdir -p "$HOME_DIR/.local/share/plasma/desktoptheme"
        as_user cp -rf "$tmp/Sweet/kde/plasma/desktoptheme/." "$HOME_DIR/.local/share/plasma/desktoptheme/" 2>/dev/null || true
        # 配色
        as_user mkdir -p "$HOME_DIR/.local/share/color-schemes"
        as_user cp -rf "$tmp/Sweet/kde/colors/." "$HOME_DIR/.local/share/color-schemes/" 2>/dev/null || true
    fi
    # Candy 图标
    local tmp2="$HOME_DIR/.cache/xynrin-fedora/candy"
    mkdir -p "$tmp2"
    if as_user git clone --depth 1 https://github.com/EliverLara/candy-icons.git "$tmp2/candy" 2>/dev/null; then
        as_user mkdir -p "$HOME_DIR/.local/share/icons"
        as_user cp -rf "$tmp2/candy" "$HOME_DIR/.local/share/icons/candy-icons" 2>/dev/null || true
    fi
    # Sweet 光标
    local tmp3="$HOME_DIR/.cache/xynrin-fedora/sweet-cursors"
    mkdir -p "$tmp3"
    if as_user git clone --depth 1 https://github.com/EliverLara/Sweet-cursors.git "$tmp3/cur" 2>/dev/null; then
        as_user mkdir -p "$HOME_DIR/.local/share/icons"
        as_user cp -rf "$tmp3/cur/Sweet-cursors" "$HOME_DIR/.local/share/icons/Sweet-cursors" 2>/dev/null || true
    fi
}

install_dark() {
    log "安装暗黑质感主题资源"
    local tmp="$HOME_DIR/.cache/xynrin-fedora/orchis"
    mkdir -p "$tmp"
    if as_user git clone --depth 1 https://github.com/vinceliuice/Orchis-kde.git "$tmp/Orchis-kde" 2>/dev/null; then
        ( cd "$tmp/Orchis-kde" && as_user bash install.sh >>"$XF_LOG_FILE" 2>&1 ) || warn "Orchis 主题安装失败"
    fi
    local tmp2="$HOME_DIR/.cache/xynrin-fedora/colloid"
    mkdir -p "$tmp2"
    if as_user git clone --depth 1 https://github.com/vinceliuice/Colloid-icon-theme.git "$tmp2/Colloid" 2>/dev/null; then
        ( cd "$tmp2/Colloid" && as_user bash install.sh -t default -s default >>"$XF_LOG_FILE" 2>&1 ) || warn "Colloid 图标失败"
    fi
    # Nordic 光标
    local tmp3="$HOME_DIR/.cache/xynrin-fedora/nordzy"
    mkdir -p "$tmp3"
    if as_user git clone --depth 1 https://github.com/alvatip/Nordzy-cursors.git "$tmp3/Nordzy" 2>/dev/null; then
        ( cd "$tmp3/Nordzy" && as_user bash install.sh >>"$XF_LOG_FILE" 2>&1 ) || warn "Nordzy 光标失败"
    fi
}

# 各方案的 KDE 应用参数
declare -A LNF=(
    [modern]="com.github.vinceliuice.Layan"
    [colorful]="com.github.eliverlara.Sweet"
    [dark]="com.github.vinceliuice.Orchis"
)
declare -A SCHEME=(
    [modern]="LayanDark"
    [colorful]="Sweet"
    [dark]="OrchisDark"
)
declare -A ICONS=(
    [modern]="Tela-circle-dark"
    [colorful]="candy-icons"
    [dark]="Colloid-Dark"
)
declare -A CURSOR=(
    [modern]="Bibata-Modern-Classic"
    [colorful]="Sweet-cursors"
    [dark]="Nordzy-cursors"
)

# 不同方案命中失败时的兜底候选
fallback_lnf="org.kde.breezedark.desktop"
fallback_scheme="BreezeDark"
fallback_icons="Papirus-Dark"
fallback_cursor="Breeze_Snow"

# ===== 安装 + 应用 =====
case "$PICK_ID" in
    modern)   install_modern ;;
    colorful) install_colorful ;;
    dark)     install_dark ;;
esac

apply_theme() {
    local lnf="${LNF[$PICK_ID]}" sch="${SCHEME[$PICK_ID]}" ic="${ICONS[$PICK_ID]}" cur="${CURSOR[$PICK_ID]}"

    # plasma-apply-* 系列优先（同时刷新 kdeglobals + kdedefaults + 通知 plasmashell）
    if command -v plasma-apply-lookandfeel >/dev/null 2>&1; then
        as_user plasma-apply-lookandfeel -a "$lnf" 2>/dev/null \
            || as_user plasma-apply-lookandfeel -a "$fallback_lnf" 2>/dev/null \
            || true
    fi
    if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
        as_user plasma-apply-colorscheme "$sch" 2>/dev/null \
            || as_user plasma-apply-colorscheme "$fallback_scheme" 2>/dev/null \
            || true
    fi
    if command -v plasma-apply-cursortheme >/dev/null 2>&1; then
        as_user plasma-apply-cursortheme "$cur" 2>/dev/null \
            || as_user plasma-apply-cursortheme "$fallback_cursor" 2>/dev/null \
            || true
    fi

    # kwriteconfig 兜底（图标 / 字体）
    local kw=""
    for c in kwriteconfig6 kwriteconfig5; do
        command -v "$c" >/dev/null 2>&1 && { kw="$c"; break; }
    done
    if [[ -n "$kw" ]]; then
        for f in kdeglobals kdedefaults/kdeglobals; do
            mkdir -p "$HOME_DIR/.config/$(dirname "$f")"
            as_user "$kw" --file "$f" --group Icons --key Theme "$ic" 2>/dev/null \
                || as_user "$kw" --file "$f" --group Icons --key Theme "$fallback_icons" 2>/dev/null
            as_user "$kw" --file "$f" --group General --key font "Noto Sans CJK SC,11,-1,5,50,0,0,0,0,0,Regular" 2>/dev/null
            as_user "$kw" --file "$f" --group General --key fixed "JetBrains Mono,11,-1,5,50,0,0,0,0,0,Regular" 2>/dev/null
        done
    fi
}

log "应用 KDE 主题：${PICK_TITLE}"
apply_theme

# ===== GTK 跟随 =====
write_gtk_ini() {
    local dir="$1" gtk_t="$2" gtk_i="$3" gtk_c="$4"
    mkdir -p "$dir"
    cat > "$dir/settings.ini" <<EOF
[Settings]
gtk-theme-name=$gtk_t
gtk-icon-theme-name=$gtk_i
gtk-cursor-theme-name=$gtk_c
gtk-cursor-theme-size=24
gtk-font-name=Noto Sans CJK SC 10
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=icon:minimize,maximize,close
EOF
    chown "$TARGET_USER:" "$dir/settings.ini" 2>/dev/null || true
}

# 大多数主题不一定提供 GTK 配套，统一回落到 Breeze-Dark
gtk_t="Breeze-Dark"
write_gtk_ini "$HOME_DIR/.config/gtk-3.0" "$gtk_t" "${ICONS[$PICK_ID]}" "${CURSOR[$PICK_ID]}"
write_gtk_ini "$HOME_DIR/.config/gtk-4.0" "$gtk_t" "${ICONS[$PICK_ID]}" "${CURSOR[$PICK_ID]}"

if command -v gsettings >/dev/null 2>&1; then
    as_user gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    as_user gsettings set org.gnome.desktop.interface gtk-theme    "$gtk_t"      2>/dev/null || true
    as_user gsettings set org.gnome.desktop.interface icon-theme   "${ICONS[$PICK_ID]}"  2>/dev/null || true
    as_user gsettings set org.gnome.desktop.interface cursor-theme "${CURSOR[$PICK_ID]}" 2>/dev/null || true
fi

# 全局光标
default_index="$HOME_DIR/.icons/default/index.theme"
mkdir -p "$(dirname "$default_index")"
echo "[Icon Theme]
Inherits=${CURSOR[$PICK_ID]}" > "$default_index"
chown -R "$TARGET_USER:" "$HOME_DIR/.icons" 2>/dev/null || true

# ===== SDDM 主题（登录界面）=====
log "调整 SDDM 登录界面"
sddm_conf="/etc/sddm.conf.d/xynrin-fedora.conf"
need_sudo
sudo mkdir -p /etc/sddm.conf.d
case "$PICK_ID" in
    modern)   sddm_theme="breeze" ;;
    colorful) sddm_theme="breeze" ;;
    dark)     sddm_theme="breeze" ;;
esac
echo "[Theme]
Current=$sddm_theme

[General]
GreeterEnvironment=QT_SCREEN_SCALE_FACTORS=1,QT_FONT_DPI=96
" | sudo tee "$sddm_conf" >/dev/null
dim "SDDM 主题: $sddm_theme（如需更换请到系统设置 → 开始/关闭/系统）"

# ===== 强制刷新（不重登也能见效）=====
if [[ $is_kde_session -eq 1 && ${DRY_RUN:-0} -eq 0 ]]; then
    log "刷新 KDE 服务（不会注销当前会话）"
    for q in qdbus6 qdbus; do
        if command -v "$q" >/dev/null 2>&1; then
            as_user "$q" org.kde.KWin /KWin reconfigure 2>/dev/null || true
            break
        fi
    done
    if command -v plasmashell >/dev/null 2>&1; then
        as_user bash -c 'nohup setsid plasmashell --replace >/dev/null 2>&1 < /dev/null &' || true
        dim "plasmashell 已后台重启，1-2 秒后面板会刷新"
    fi
fi

success "KDE 主题 [${PICK_TITLE}] 已应用"
dim "切回 Breeze 默认：xynrin → 美化卸载"
