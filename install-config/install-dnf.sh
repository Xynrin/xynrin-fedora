#!/usr/bin/env bash
# 按 packages/dnf.txt 安装缺失的 rpm 包，并按硬件检测加载可选清单
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "dnf 软件包"
dim "$(xf_hw_summary)"
need_sudo

_install_list() {
    local list_file="$1"
    [[ -f "$list_file" ]] || return 0

    local pkgs
    pkgs=$(read_list "$list_file")
    [[ -z "$pkgs" ]] && return 0

    local missing=()
    while read -r pkg; do
        [[ -z "$pkg" ]] && continue
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done <<< "$pkgs"

    if [[ ${#missing[@]} -eq 0 ]]; then
        ok "已全部安装: $(basename "$list_file")"
        return 0
    fi
    dim "安装 ($(basename "$list_file")): ${missing[*]}"
    run sudo dnf install -y "${missing[@]}"
}

# 通用包（所有机器）
_install_list "$SETUP_DIR/packages/dnf.txt"

# 硬件相关包（物理机才装）
if xf_is_vm; then
    dim "虚拟机环境 ($(xf_virt))，跳过硬件相关包"
else
    # NVIDIA GPU
    if xf_has_nvidia; then
        dim "检测到 NVIDIA GPU，安装驱动"
        _install_list "$SETUP_DIR/packages/dnf-nvidia.txt"
    fi

    # ASUS 主板
    if xf_is_asus; then
        dim "检测到 ASUS 主板，安装 asusctl"
        _install_list "$SETUP_DIR/packages/dnf-asus.txt"
    fi

    # VirtualBox host（物理机上才有意义）
    if [[ -f "$SETUP_DIR/packages/dnf-vbox.txt" ]]; then
        _install_list "$SETUP_DIR/packages/dnf-vbox.txt"
    fi
fi
