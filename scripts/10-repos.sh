#!/usr/bin/env bash
# 10-repos.sh — 启用 RPM Fusion free/nonfree + 添加 Flathub remote
# 前置必跑：其他模块的包依赖这两个源

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

fedver=$(rpm -E %fedora)

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

# ---- 更新元数据（一次）----
dim "刷新 dnf 元数据"
exe sudo dnf makecache --refresh >/dev/null 2>&1 || true

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
