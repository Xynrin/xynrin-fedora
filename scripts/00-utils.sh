#!/usr/bin/env bash
# 00-utils.sh — 视觉引擎 + 公共工具函数
# 所有模块 source 本文件，不要直接执行。

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "00-utils.sh 不应直接执行，应由各模块 source" >&2
    exit 1
fi

# ===== 1. 颜色与样式 =====
export NC='\033[0m'
export BOLD='\033[1m'
export DIM='\033[2m'
export H_RED='\033[1;31m'
export H_GREEN='\033[1;32m'
export H_YELLOW='\033[1;33m'
export H_BLUE='\033[1;34m'
export H_PURPLE='\033[1;35m'
export H_CYAN='\033[1;36m'
export H_WHITE='\033[1;37m'
export H_GRAY='\033[1;90m'

export TICK="${H_GREEN}✔${NC}"
export CROSS="${H_RED}✘${NC}"
export ARROW="${H_CYAN}➜${NC}"
export WARN_SYM="${H_YELLOW}⚠${NC}"

# ===== 2. 日志 =====
# 日志文件（可被上层覆盖）
export XF_LOG_FILE="${XF_LOG_FILE:-/tmp/xynrin-fedora-install.log}"
[[ -f "$XF_LOG_FILE" ]] || { touch "$XF_LOG_FILE" 2>/dev/null && chmod 664 "$XF_LOG_FILE" 2>/dev/null; } || true

_write_log() {
    local level="$1" msg="$2"
    local clean
    clean=$(printf '%b' "$msg" | sed 's/\x1b\[[0-9;]*m//g')
    printf '[%s] [%s] %s\n' "$(date '+%H:%M:%S')" "$level" "$clean" >> "$XF_LOG_FILE" 2>/dev/null || true
}

log()     { echo -e "   $ARROW $*"; _write_log LOG "$*"; }
success() { echo -e "   $TICK ${H_GREEN}$*${NC}"; _write_log OK "$*"; }
warn()    { echo -e "   $WARN_SYM ${H_YELLOW}$*${NC}"; _write_log WARN "$*"; }
error()   { echo -e "   $CROSS ${H_RED}$*${NC}" >&2; _write_log ERR "$*"; }
dim()     { echo -e "   ${DIM}$*${NC}"; }

section() {
    local title="$1" subtitle="${2:-}"
    echo ""
    echo -e "${H_PURPLE}╭─────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${H_PURPLE}│${NC} ${BOLD}${H_WHITE}$title${NC}"
    [[ -n "$subtitle" ]] && echo -e "${H_PURPLE}│${NC} ${H_CYAN}$subtitle${NC}"
    echo -e "${H_PURPLE}╰─────────────────────────────────────────────────────────────────╯${NC}"
    _write_log SECTION "$title - $subtitle"
}

info_kv() {
    printf "   ${H_BLUE}●${NC} %-15s : ${BOLD}%s${NC} ${DIM}%s${NC}\n" "$1" "$2" "${3:-}"
    _write_log INFO "$1=$2"
}

# ===== 3. 执行器 =====
# exe: 执行命令并显示，失败返回原 exit code（不 exit）
exe() {
    echo -e "   ${H_GRAY}┌──[ ${H_PURPLE}EXEC${H_GRAY} ]──${NC} ${H_CYAN}\$${NC} ${BOLD}$*${NC}"
    _write_log EXEC "$*"
    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        echo -e "   ${H_GRAY}└────────────────────────── ${H_YELLOW}DRY${H_GRAY} ─┘${NC}"
        return 0
    fi
    "$@"
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        echo -e "   ${H_GRAY}└─────────────────────────── ${H_GREEN}OK${H_GRAY} ─┘${NC}"
    else
        echo -e "   ${H_GRAY}└───────────────────────── ${H_RED}FAIL${H_GRAY} ─┘${NC}"
        _write_log FAIL "rc=$rc"
    fi
    return $rc
}

exe_silent() { "$@" >/dev/null 2>&1; }

# ===== 4. 目标用户识别 =====
# 多数场景：调用方是 $USER 自己，但通过 sudo 跑 root-only 子步骤时需要把
# 配置落到真实用户的 $HOME 上。detect_target_user 填充 TARGET_USER / HOME_DIR。
detect_target_user() {
    if [[ -n "${TARGET_USER:-}" && -n "${HOME_DIR:-}" ]]; then
        return 0
    fi
    if [[ $EUID -ne 0 ]]; then
        TARGET_USER="$USER"
        HOME_DIR="$HOME"
    else
        TARGET_USER="${SUDO_USER:-$(awk -F: '$3 == 1000 {print $1; exit}' /etc/passwd)}"
        [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]] && {
            error "未找到普通用户（UID 1000），请用普通用户跑本脚本"
            return 1
        }
        HOME_DIR="/home/$TARGET_USER"
    fi
    export TARGET_USER HOME_DIR
}

# as_user: 以目标普通用户身份跑命令
as_user() {
    if [[ $EUID -eq 0 ]]; then
        runuser -u "$TARGET_USER" -- "$@"
    else
        "$@"
    fi
}

# ===== 5. sudo 封装 =====
# 期望 install.sh 已 sudo -v + 后台续期。此处只兜底
need_sudo() {
    [[ ${DRY_RUN:-0} -eq 1 ]] && return 0
    if sudo -n true 2>/dev/null; then return 0; fi
    warn "sudo 凭据已过期，可能需要重新输入密码"
    sudo -v
}

# dnf_install PKG [PKG...]  — 按需装，已装的跳过
dnf_install() {
    local missing=()
    for p in "$@"; do
        rpm -q "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        dim "dnf 已全部安装: $*"
        return 0
    fi
    need_sudo
    exe sudo dnf install -y "${missing[@]}"
}

# flatpak_install APPID [APPID...] — flathub
flatpak_install() {
    command -v flatpak >/dev/null 2>&1 || { warn "flatpak 不可用"; return 1; }
    local rc=0
    for app in "$@"; do
        if flatpak info "$app" >/dev/null 2>&1; then
            dim "flatpak 已安装: $app"
        else
            exe flatpak install -y --noninteractive flathub "$app" || rc=$?
        fi
    done
    return $rc
}

# ===== 6. dotfiles 部署 =====
# backup_and_copy SRC DST — 先备份 DST（如存在且非同一文件），再 cp
backup_and_copy() {
    local src="$1" dst="$2"
    if [[ ! -e "$src" ]]; then warn "源不存在: $src"; return 1; fi
    if [[ -e "$dst" ]]; then
        if cmp -s "$src" "$dst" 2>/dev/null; then
            dim "已就位: $dst"; return 0
        fi
        local bak="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
        exe cp -a "$dst" "$bak"
    fi
    exe mkdir -p "$(dirname "$dst")"
    exe cp -a "$src" "$dst"
}

# rsync_dotfiles SRC_DIR DST_DIR — 把 SRC_DIR 下的东西合并到 DST_DIR
# 先备份 DST_DIR 到 DST_DIR.bak.TIMESTAMP（整体打包，小白易回滚）
rsync_dotfiles() {
    local src="$1" dst="$2"
    [[ ! -d "$src" ]] && { warn "dotfiles 源目录不存在: $src"; return 1; }
    mkdir -p "$dst"
    if command -v rsync >/dev/null 2>&1; then
        exe rsync -a --backup --suffix=".bak.$(date +%s)" "$src/" "$dst/"
    else
        exe cp -a "$src/." "$dst/"
    fi
}

# ===== 7. 隐藏无用 .desktop =====
hide_desktop_file() {
    local app="$1"
    detect_target_user || return 1
    local sys="/usr/share/applications/$app"
    local user_dir="$HOME_DIR/.local/share/applications"
    local user_file="$user_dir/$app"
    [[ -f "$sys" ]] || return 0
    mkdir -p "$user_dir"
    cp -f "$sys" "$user_file"
    if grep -q "^NoDisplay=" "$user_file"; then
        sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$user_file"
    else
        echo "NoDisplay=true" >> "$user_file"
    fi
    chown -R "$TARGET_USER:" "$user_dir" 2>/dev/null || true
}

run_hide_desktop_files() {
    local apps=(
        avahi-discover.desktop
        qv4l2.desktop qvidcap.desktop
        bssh.desktop bvnc.desktop
        xgps.desktop xgpsspeed.desktop
        kbd-layout-viewer5.desktop
        assistant.desktop qdbusviewer.desktop
        linguist.desktop designer.desktop
        lstopo.desktop cmake-gui.desktop
        org.kde.drkonqi.coredump.gui.desktop
        org.fcitx.fcitx5-migrator.desktop
    )
    for app in "${apps[@]}"; do hide_desktop_file "$app"; done
}

# ===== 8. 工具函数 =====
xf_is_fedora() { [[ -f /etc/fedora-release ]]; }

read_list() { grep -vE '^\s*(#|$)' "$1" 2>/dev/null || true; }

confirm() {
    local prompt="$1" default="${2:-N}" timeout="${3:-30}"
    local hint
    if [[ "$default" =~ ^[Yy]$ ]]; then hint="[Y/n]"; else hint="[y/N]"; fi
    local ans
    if ! read -t "$timeout" -p "$(echo -e "   ${H_CYAN}$prompt $hint (${timeout}s): ${NC}")" ans; then
        echo ""
        ans="$default"
    fi
    ans="${ans:-$default}"
    [[ "$ans" =~ ^[Yy]$ ]]
}
