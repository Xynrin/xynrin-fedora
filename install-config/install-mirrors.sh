#!/usr/bin/env bash
# 切换 dnf 镜像到 mirrors/preferred.txt 指定的国内源
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "dnf 镜像切换"
pref_file="$SETUP_DIR/mirrors/preferred.txt"
if [[ ! -f "$pref_file" ]]; then
    dim "没有 mirrors/preferred.txt，跳过"
    exit 0
fi
mirror=$(read_list "$pref_file" | head -1 | tr -d '[:space:]')
if [[ -z "$mirror" || "$mirror" == "official" ]]; then
    dim "镜像偏好为空或 official，跳过"
    exit 0
fi
need_sudo
run sudo "$SETUP_DIR/mirrors/switch-mirror.sh" "$mirror"
