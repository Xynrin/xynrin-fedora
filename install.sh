#!/usr/bin/env bash
# xynrin-fedora 入口
# - 打 banner (oh-my-logo 如果可用)
# - 一次 sudo -v + 后台守护续期，全程只问一次密码
# - 把每一步委托给 install-config/install-<name>.sh
# author: xynrin <xynrin@163.com>
# create-time: 2026-05-10
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SETUP_DIR
export DRY_RUN=0
ONLY=""

source "$SETUP_DIR/install-config/common.sh"

usage() {
    cat <<EOF
用法: $0 [--only STEP] [--dry-run]

步骤（无 --only 时按顺序全跑）:
  mirrors   切换 dnf 镜像 (mirrors/preferred.txt)
  repos     RPM Fusion + 第三方 .repo + COPR
  dnf       packages/dnf.txt
  flatpak   packages/flatpak.txt
  fish      symlink config / functions / conf.d + universal_vars
  fisher    fisher 本身 + fish_plugins
  vscode    settings.json + extensions
  node      nvm LTS + npm-globals.txt
  systemd   systemd/{system,user}.txt
  scripts   scripts/*.sh → ~/.local/bin/<name>

例:
  $0                   # 全量（推荐）
  $0 --only fish
  $0 --only dnf --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --only)
            [[ $# -lt 2 ]] && { err "--only 需要一个值"; usage; exit 2; }
            ONLY="$2"; shift 2 ;;
        --dry-run) export DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) err "未知参数: $1"; usage; exit 2 ;;
    esac
done

steps=(mirrors repos dnf flatpak fish fisher vscode node systemd scripts)

if [[ -n "$ONLY" ]] && ! printf '%s\n' "${steps[@]}" | grep -qx "$ONLY"; then
    err "未知的 --only 值: $ONLY"
    usage
    exit 2
fi

# ===== Banner =====
show_banner() {
    if command -v oh-my-logo >/dev/null 2>&1; then
        oh-my-logo "xynrin-fedora" purple 2>/dev/null || \
        oh-my-logo "xynrin-fedora" 2>/dev/null || true
    else
        printf "${c_mag}${c_bold}xynrin-fedora${c_reset}\n"
    fi
    printf "${c_gray}    %s${c_reset}\n\n" "一键 Fedora KDE 工作站配置"
}

show_banner
log "仓库: $SETUP_DIR"
[[ $DRY_RUN -eq 1 ]] && warn "DRY-RUN 模式，不会真正改动"

# ===== 一次性 sudo（仅需 dnf/flatpak-system/systemd 等步骤） =====
SUDO_KEEPALIVE_PID=""
cleanup() {
    [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap cleanup EXIT

need_upfront_sudo() {
    # 哪些步骤需要 sudo？mirrors / repos / dnf / systemd；node 可能需要（全局 npm）
    local needs=(mirrors repos dnf systemd node)
    for s in "${needs[@]}"; do
        if [[ -z "$ONLY" || "$ONLY" == "$s" ]]; then
            return 0
        fi
    done
    return 1
}

if [[ $DRY_RUN -eq 0 ]] && need_upfront_sudo; then
    log "提升权限（整个流程只需输入一次密码）"
    sudo -v || { err "sudo 不可用"; exit 1; }
    # 后台每 50 秒续期一次，直到父进程退出
    ( while true; do sudo -n true 2>/dev/null || exit; sleep 50; done ) &
    SUDO_KEEPALIVE_PID=$!
fi

# ===== 执行 =====
run_step() {
    local name="$1"
    local script="$SETUP_DIR/install-config/install-${name}.sh"
    if [[ ! -x "$script" ]]; then
        err "模块不存在或不可执行: $script"
        return 1
    fi
    bash "$script"
}

for s in "${steps[@]}"; do
    if [[ -z "$ONLY" || "$ONLY" == "$s" ]]; then
        run_step "$s"
    fi
done

log "完成"
