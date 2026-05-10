#!/usr/bin/env bash
# 所有 install-*.sh 共享的通用函数。通过 install.sh source，不应直接执行。

# 防止被直接 bash 运行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "common.sh 不应直接执行，应由 install.sh source"
    exit 1
fi

# ===== 颜色 / 日志 =====
c_reset='\033[0m';  c_blue='\033[0;34m';  c_green='\033[0;32m'
c_yellow='\033[1;33m'; c_red='\033[0;31m'; c_gray='\033[0;90m'
c_cyan='\033[0;36m'; c_mag='\033[0;35m';  c_bold='\033[1m'

log()  { printf "${c_blue}==>${c_reset} ${c_bold}%s${c_reset}\n" "$*"; }
ok()   { printf "${c_green}  ✓${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}  !${c_reset} %s\n" "$*"; }
err()  { printf "${c_red}  ✗${c_reset} %s\n" "$*" >&2; }
dim()  { printf "${c_gray}    %s${c_reset}\n" "$*"; }

run() {
    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        dim "DRY: $*"
    else
        "$@"
    fi
}

# ===== 工具函数 =====
read_list() {
    grep -vE '^\s*(#|$)' "$1" 2>/dev/null || true
}

link_into() {
    local src="$1" dst="$2"
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        return 0
    fi
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        local backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
        warn "备份已存在文件 $dst -> $backup"
        run mv "$dst" "$backup"
    elif [[ -L "$dst" ]]; then
        run rm "$dst"
    fi
    run mkdir -p "$(dirname "$dst")"
    run ln -s "$src" "$dst"
    ok "linked $(basename "$dst")"
}

# install.sh 在入口就 sudo -v 过一次，保持后台续期；这里只兜底
need_sudo() {
    if [[ ${DRY_RUN:-0} -eq 1 ]]; then return 0; fi
    sudo -n true 2>/dev/null && return 0
    warn "sudo 凭据已过期，可能需要重新输入密码"
    sudo -v
}

# ===== 架构 / 虚拟化 / 硬件 检测 =====
# 结果缓存，避免重复调用
_XF_ARCH=""
_XF_VIRT=""
_XF_GPU=""
_XF_VENDOR=""

# CPU 架构：x86_64 / aarch64 / ...
xf_arch() {
    [[ -n "$_XF_ARCH" ]] || _XF_ARCH=$(uname -m)
    printf '%s' "$_XF_ARCH"
}

# 虚拟化环境：none / kvm / vmware / oracle / microsoft / qemu / ...
# 需要 sudo 才准？不需要，systemd-detect-virt 普通用户就能读
xf_virt() {
    if [[ -z "$_XF_VIRT" ]]; then
        if command -v systemd-detect-virt >/dev/null 2>&1; then
            _XF_VIRT=$(systemd-detect-virt 2>/dev/null || echo "none")
        else
            _XF_VIRT="none"
        fi
    fi
    printf '%s' "$_XF_VIRT"
}

xf_is_vm() {
    [[ "$(xf_virt)" != "none" ]]
}

# 检测 GPU 厂商：nvidia / amd / intel / none（多个时取第一个）
xf_gpu() {
    if [[ -z "$_XF_GPU" ]]; then
        if command -v lspci >/dev/null 2>&1; then
            local line
            line=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' | head -1)
            case "$line" in
                *NVIDIA*|*nvidia*) _XF_GPU="nvidia" ;;
                *AMD*|*ATI*|*Radeon*|*amd*) _XF_GPU="amd" ;;
                *Intel*|*intel*) _XF_GPU="intel" ;;
                *) _XF_GPU="none" ;;
            esac
        else
            _XF_GPU="none"
        fi
    fi
    printf '%s' "$_XF_GPU"
}

xf_has_nvidia() {
    [[ "$(xf_gpu)" == "nvidia" ]]
}

# 主板厂商/产品：asus / lenovo / dell / ... / unknown
# 走 /sys/class/dmi，不需要 sudo
xf_vendor() {
    if [[ -z "$_XF_VENDOR" ]]; then
        local v=""
        if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
            v=$(tr '[:upper:]' '[:lower:]' < /sys/class/dmi/id/sys_vendor | tr -d '[:space:]')
        fi
        case "$v" in
            *asus*)    _XF_VENDOR="asus" ;;
            *lenovo*)  _XF_VENDOR="lenovo" ;;
            *dell*)    _XF_VENDOR="dell" ;;
            *hp*|*hewlett*) _XF_VENDOR="hp" ;;
            *acer*)    _XF_VENDOR="acer" ;;
            *msi*)     _XF_VENDOR="msi" ;;
            *apple*)   _XF_VENDOR="apple" ;;
            "")        _XF_VENDOR="unknown" ;;
            *)         _XF_VENDOR="$v" ;;
        esac
    fi
    printf '%s' "$_XF_VENDOR"
}

xf_is_asus() {
    [[ "$(xf_vendor)" == "asus" ]]
}

# 打印一行硬件摘要，便于 debug
xf_hw_summary() {
    printf 'arch=%s virt=%s gpu=%s vendor=%s\n' \
        "$(xf_arch)" "$(xf_virt)" "$(xf_gpu)" "$(xf_vendor)"
}
