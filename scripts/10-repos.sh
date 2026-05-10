#!/usr/bin/env bash
# 10-repos.sh — 启用 RPM Fusion free/nonfree + 添加 Flathub remote + 全量更新
# 前置必跑：其他模块的包依赖这两个源

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

fedver=$(rpm -E %fedora)

# ---- dnf.conf 一次性调优：并发下载 + 最快镜像 ----
tune_dnf_conf() {
    local conf="/etc/dnf/dnf.conf"
    [[ -f "$conf" ]] || return 0
    local changed=0
    if ! grep -q '^max_parallel_downloads=' "$conf"; then
        need_sudo
        echo "max_parallel_downloads=10" | sudo tee -a "$conf" >/dev/null
        changed=1
    fi
    if ! grep -q '^fastestmirror=' "$conf"; then
        need_sudo
        echo "fastestmirror=True" | sudo tee -a "$conf" >/dev/null
        changed=1
    fi
    if ! grep -q '^defaultyes=' "$conf"; then
        need_sudo
        echo "defaultyes=True" | sudo tee -a "$conf" >/dev/null
        changed=1
    fi
    if [[ $changed -eq 1 ]]; then
        success "dnf.conf 已优化：并发下载 10 + 最快镜像 + 默认 yes"
    else
        dim "dnf.conf 已优化过"
    fi
}

log "调优 dnf 配置"
tune_dnf_conf

# ---- RPM Fusion ----
_install_rpmfusion() {
    local variant="$1"
    local pkg="rpmfusion-${variant}-release"
    if rpm -q "$pkg" >/dev/null 2>&1; then
        dim "rpmfusion-${variant} 已启用"
        return 0
    fi
    local url="https://mirrors.rpmfusion.org/${variant}/fedora/rpmfusion-${variant}-release-${fedver}.noarch.rpm"
    need_sudo
    exe sudo dnf install -y "$url" && success "rpmfusion-${variant} 已启用"
}

log "启用 RPM Fusion free / nonfree"
_install_rpmfusion free
_install_rpmfusion nonfree

# ---- 刷新元数据 ----
log "刷新 dnf 元数据"
exe sudo dnf makecache --refresh

# ---- 全量更新（首次跑很关键，否则 rpmfusion 新包可能依赖更新的 glibc 等） ----
log "全量更新系统（可能需要几分钟）"
need_sudo
exe sudo dnf upgrade -y --refresh

# ---- Flatpak + Flathub ----
dnf_install flatpak

if flatpak remotes --columns=name 2>/dev/null | grep -qx flathub; then
    dim "Flathub remote 已存在"
else
    log "添加 Flathub remote"
    exe flatpak remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
fi

success "软件源就绪"
