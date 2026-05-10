#!/usr/bin/env bash
# 按 packages/dnf.txt 安装缺失的 rpm 包
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "dnf 软件包"
need_sudo

pkgs=$(read_list "$SETUP_DIR/packages/dnf.txt")
if [[ -z "$pkgs" ]]; then
    warn "packages/dnf.txt 为空"
    exit 0
fi

missing=()
while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    if ! rpm -q "$pkg" >/dev/null 2>&1; then
        missing+=("$pkg")
    fi
done <<< "$pkgs"

if [[ ${#missing[@]} -eq 0 ]]; then
    ok "所有 dnf 包都已安装"
    exit 0
fi
dim "安装: ${missing[*]}"
run sudo dnf install -y "${missing[@]}"
