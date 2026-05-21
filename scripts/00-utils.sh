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

# 渐变色（Catppuccin 风格）
export C1='\033[38;5;141m'   # purple
export C2='\033[38;5;111m'   # blue
export C3='\033[38;5;117m'   # cyan
export C4='\033[38;5;156m'   # green
export C5='\033[38;5;216m'   # peach

export TICK="${H_GREEN}✓${NC}"
export CROSS="${H_RED}✗${NC}"
export ARROW="${C2}❯${NC}"
export WARN_SYM="${H_YELLOW}!${NC}"
export DOT="${H_GRAY}·${NC}"

# ===== 2. 日志 =====
export XF_LOG_FILE="${XF_LOG_FILE:-/tmp/xynrin-fedora-install.log}"
[[ -f "$XF_LOG_FILE" ]] || { touch "$XF_LOG_FILE" 2>/dev/null && chmod 664 "$XF_LOG_FILE" 2>/dev/null; } || true

_write_log() {
    local level="$1" msg="$2"
    local clean
    clean=$(printf '%b' "$msg" | sed 's/\x1b\[[0-9;]*m//g')
    printf '[%s] [%s] %s\n' "$(date '+%H:%M:%S')" "$level" "$clean" >> "$XF_LOG_FILE" 2>/dev/null || true
}

log()     { echo -e "  ${ARROW} $*"; _write_log LOG "$*"; }
success() { echo -e "  ${TICK} ${H_GREEN}$*${NC}"; _write_log OK "$*"; }
warn()    { echo -e "  ${WARN_SYM} ${H_YELLOW}$*${NC}"; _write_log WARN "$*"; }
error()   { echo -e "  ${CROSS} ${H_RED}$*${NC}" >&2; _write_log ERR "$*"; }
dim()     { echo -e "    ${DIM}$*${NC}"; }

# 紧凑版分节标题（更现代）
section() {
    local title="$1" subtitle="${2:-}"
    echo ""
    echo -e "${C1}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [[ -n "$subtitle" ]]; then
        echo -e " ${BOLD}${H_WHITE}$title${NC}  ${DIM}${subtitle}${NC}"
    else
        echo -e " ${BOLD}${H_WHITE}$title${NC}"
    fi
    echo -e "${C1}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    _write_log SECTION "$title - $subtitle"
}

# 步骤进度（[1/5] step name）
step() {
    local cur="$1" total="$2" name="$3"
    echo ""
    echo -e "${C2}┌─ [${cur}/${total}]${NC} ${BOLD}${name}${NC}"
    _write_log STEP "[$cur/$total] $name"
}

step_end() {
    echo -e "${C2}└─${NC} ${DIM}done${NC}"
}

info_kv() {
    printf "    ${H_BLUE}∙${NC} %-14s ${DIM}│${NC} ${BOLD}%s${NC} ${DIM}%s${NC}\n" "$1" "$2" "${3:-}"
    _write_log INFO "$1=$2"
}

# ===== 3. 执行器 =====
exe() {
    echo -e "    ${H_GRAY}\$${NC} ${DIM}$*${NC}"
    _write_log EXEC "$*"
    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        echo -e "    ${DIM}${H_YELLOW}↳ dry-run${NC}"
        return 0
    fi
    "$@"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        echo -e "    ${H_RED}↳ rc=$rc${NC}"
        _write_log FAIL "rc=$rc $*"
    fi
    return $rc
}

# 静默执行（仅日志）
exe_silent() {
    _write_log EXEC_SILENT "$*"
    [[ ${DRY_RUN:-0} -eq 1 ]] && return 0
    "$@" >/dev/null 2>&1
}

# ===== 4. 目标用户识别 =====
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

as_user() {
    if [[ $EUID -eq 0 ]]; then
        runuser -u "$TARGET_USER" -- "$@"
    else
        "$@"
    fi
}

# ===== 5. sudo 封装 =====
need_sudo() {
    [[ ${DRY_RUN:-0} -eq 1 ]] && return 0
    if sudo -n true 2>/dev/null; then return 0; fi
    warn "sudo 凭据已过期"
    sudo -v
}

XF_DNF_OPTS="--setopt=max_parallel_downloads=10 --setopt=install_weak_deps=False"

# dnf_install: 逐包安装，每个独立反馈
#
# 为什么不批量？
#   批量 `dnf install A B C ...` 在 dnf5 上要先解析整个事务，dependency 很多时
#   会出现"卡 30s+ 没任何输出"的体感问题。而且只要一个包名错了或冲突，整批失败。
# 现在的策略：
#   1) rpm -q 把已装的过滤掉（O(n) 但每次 ~5ms，几乎瞬时）
#   2) 逐个 dnf install，每个完成立刻显示 [N/M] ✓ pkg
#   3) 失败的包累积到 XF_FAILED_PKGS，最后报告，不阻塞其它包
#   4) 用 dnf cache 已经热的好处：第二个包起几乎不再有 metadata 解析延迟
dnf_install() {
    local pkgs=("$@")
    [[ ${#pkgs[@]} -eq 0 ]] && return 0

    # 1) 过滤已装
    local missing=()
    for p in "${pkgs[@]}"; do
        rpm -q "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        dim "已全部安装 (${#pkgs[@]}): ${pkgs[*]}"
        return 0
    fi

    need_sudo

    # 2) 逐包装，实时反馈
    local total=${#missing[@]} idx=0 ok=0 failed=()
    log "安装 $total 个包：${missing[*]}"
    for p in "${missing[@]}"; do
        idx=$((idx + 1))
        # 进度行：用 \r 不停刷，避免刷屏
        printf "    ${C3}[%d/%d]${NC} ${DIM}%s${NC}\r" "$idx" "$total" "$p"
        # shellcheck disable=SC2086
        if sudo "$XF_DNF" install -y $XF_DNF_OPTS "$p" </dev/null >>"$XF_LOG_FILE" 2>&1; then
            printf "    ${C3}[%d/%d]${NC} ${TICK} %-40s\n" "$idx" "$total" "$p"
            ok=$((ok + 1))
            _write_log OK "dnf install $p"
        else
            printf "    ${C3}[%d/%d]${NC} ${CROSS} %-40s ${DIM}(见日志)${NC}\n" "$idx" "$total" "$p"
            failed+=("$p")
            _write_log FAIL "dnf install $p"
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        warn "$ok/$total 装上，未装上：${failed[*]}"
        export XF_FAILED_PKGS="${XF_FAILED_PKGS:-}${failed[*]} "
        return 1
    else
        success "$ok/$total 已装"
        return 0
    fi
}

# 必装：失败直接终止当前模块（用于 fish/starship 这类硬依赖）
dnf_install_required() {
    dnf_install "$@"
    for p in "$@"; do
        if ! rpm -q "$p" >/dev/null 2>&1; then
            error "必装包 [$p] 安装失败，模块无法继续"
            return 1
        fi
    done
}

flatpak_install() {
    command -v flatpak >/dev/null 2>&1 || { warn "flatpak 不可用"; return 1; }
    local rc=0
    for app in "$@"; do
        if flatpak info "$app" >/dev/null 2>&1; then
            dim "已装: $app"
        else
            exe flatpak install -y --noninteractive flathub "$app" || rc=$?
        fi
    done
    return $rc
}

# ===== 6. dotfiles 部署 =====
# 策略改了：默认强制覆盖 + 自动备份（XF_DOTFILES_FORCE 默认 1）
# 原因：保守模式会让"已有 fish/starship 配置"的用户跑完脚本看不到任何变化，
#       美化等于没上。要"一键美化生效"，就必须强势覆盖 + 给清晰备份路径。
# 想保留私有配置：XF_DOTFILES_FORCE=0
export XF_DOTFILES_FORCE="${XF_DOTFILES_FORCE:-1}"
export XF_BACKUP_DIR="${XF_BACKUP_DIR:-$HOME/.config/.xynrin-backup}"

_xf_init_backup_dir() {
    detect_target_user || return 1
    XF_BACKUP_DIR="$HOME_DIR/.config/.xynrin-backup"
    mkdir -p "$XF_BACKUP_DIR" 2>/dev/null || true
    chown "$TARGET_USER:" "$XF_BACKUP_DIR" 2>/dev/null || true
    export XF_BACKUP_DIR
}

# backup_and_copy SRC DST — 单文件部署
#   相同：跳过；不同：备份后覆盖（XF_DOTFILES_FORCE=0 时保留宿主机）
backup_and_copy() {
    local src="$1" dst="$2"
    [[ ! -e "$src" ]] && { warn "源不存在: $src"; return 1; }
    _xf_init_backup_dir

    if [[ -e "$dst" ]]; then
        if cmp -s "$src" "$dst" 2>/dev/null; then
            dim "已就位: $dst"
            return 0
        fi
        if [[ "${XF_DOTFILES_FORCE:-1}" != "1" ]]; then
            dim "保留宿主机: $dst（XF_DOTFILES_FORCE=1 强刷）"
            return 0
        fi
        local stamp rel bak
        stamp=$(date +%Y%m%d-%H%M%S)
        rel="$(basename "$dst")"
        bak="$XF_BACKUP_DIR/${rel}.${stamp}.bak"
        cp -a "$dst" "$bak" && dim "备份: $bak"
    fi
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
    chown "$TARGET_USER:" "$dst" 2>/dev/null || true
}

# deploy_tree SRC_DIR DST_DIR [--exec]
#   递归部署。已存在且不同 → 备份后覆盖（XF_DOTFILES_FORCE=1 默认）
#   --exec：所有文件 chmod +x（用于 ~/.local/bin）
deploy_tree() {
    local src="$1" dst="$2" exec_flag="${3:-}"
    [[ ! -d "$src" ]] && { warn "源目录不存在: $src"; return 1; }
    detect_target_user || return 1
    _xf_init_backup_dir

    local rel target stamp bak_root copied=0 backed=0 skipped=0
    stamp=$(date +%Y%m%d-%H%M%S)
    bak_root="$XF_BACKUP_DIR/$(basename "$dst").${stamp}"

    while IFS= read -r -d '' file; do
        rel="${file#"$src"/}"
        target="$dst/$rel"
        if [[ -e "$target" ]]; then
            if cmp -s "$file" "$target" 2>/dev/null; then
                skipped=$((skipped + 1))
                continue
            fi
            if [[ "${XF_DOTFILES_FORCE:-1}" != "1" ]]; then
                skipped=$((skipped + 1))
                continue
            fi
            mkdir -p "$bak_root/$(dirname "$rel")"
            cp -a "$target" "$bak_root/$rel"
            backed=$((backed + 1))
        fi
        mkdir -p "$(dirname "$target")"
        cp -a "$file" "$target"
        [[ "$exec_flag" == "--exec" ]] && chmod +x "$target"
        copied=$((copied + 1))
    done < <(find "$src" -type f -print0)

    if [[ -d "$dst" ]]; then
        chown -R "$TARGET_USER:" "$dst" 2>/dev/null || true
    fi

    dim "部署 $(basename "$dst"): ${copied} 写 / ${backed} 备份 / ${skipped} 已就位"
    [[ $backed -gt 0 ]] && dim "备份目录: $bak_root"
    return 0
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

xf_fedora_version() {
    rpm -E %fedora 2>/dev/null || echo 0
}

xf_min_fedora="${XF_MIN_FEDORA:-41}"
xf_check_fedora_version() {
    local v
    v=$(xf_fedora_version)
    if [[ "$v" -lt "$xf_min_fedora" ]]; then
        warn "当前 Fedora $v 低于推荐的 $xf_min_fedora，部分包名/特性可能不可用"
        return 1
    fi
    return 0
}

xf_dnf_bin() {
    if command -v dnf5 >/dev/null 2>&1; then
        echo dnf5
    elif command -v dnf >/dev/null 2>&1; then
        echo dnf
    else
        return 1
    fi
}
export XF_DNF
XF_DNF=$(xf_dnf_bin || echo dnf)

read_list() { grep -vE '^\s*(#|$)' "$1" 2>/dev/null || true; }

confirm() {
    local prompt="$1" default="${2:-N}" timeout="${3:-30}"
    # --all 模式：直接走默认值（不阻塞）
    if [[ "${XF_NONINTERACTIVE:-0}" == "1" ]]; then
        [[ "$default" =~ ^[Yy]$ ]] && return 0 || return 1
    fi
    local hint
    if [[ "$default" =~ ^[Yy]$ ]]; then hint="[Y/n]"; else hint="[y/N]"; fi
    local ans
    if ! read -t "$timeout" -p "$(echo -e "    ${C3}?${NC} $prompt $hint (${timeout}s): ")" ans; then
        echo ""
        ans="$default"
    fi
    ans="${ans:-$default}"
    [[ "$ans" =~ ^[Yy]$ ]]
}
