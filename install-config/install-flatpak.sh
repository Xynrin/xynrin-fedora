#!/usr/bin/env bash
# 按 packages/flatpak.txt 安装 flatpak 应用
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "flatpak 应用"
if ! command -v flatpak >/dev/null; then
    warn "flatpak 未安装，跳过"
    exit 0
fi

if ! flatpak remotes --columns=name 2>/dev/null | grep -qx flathub; then
    run flatpak remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
fi

apps=$(read_list "$SETUP_DIR/packages/flatpak.txt")
if [[ -z "$apps" ]]; then
    dim "没有 flatpak 应用，跳过"
    exit 0
fi

while read -r id; do
    [[ -z "$id" ]] && continue
    if flatpak info "$id" >/dev/null 2>&1; then
        dim "已安装: $id"
    else
        run flatpak install -y --noninteractive flathub "$id"
    fi
done <<< "$apps"
