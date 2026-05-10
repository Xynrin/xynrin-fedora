#!/usr/bin/env bash
# 按 systemd/{system,user}.txt 启用服务
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "systemd 服务"
need_sudo

if [[ -f "$SETUP_DIR/systemd/system.txt" ]]; then
    while read -r svc; do
        [[ -z "$svc" ]] && continue
        if systemctl is-enabled "$svc" >/dev/null 2>&1; then
            dim "已启用: $svc"
        else
            run sudo systemctl enable --now "$svc"
        fi
    done < <(read_list "$SETUP_DIR/systemd/system.txt")
fi

if [[ -f "$SETUP_DIR/systemd/user.txt" ]]; then
    while read -r svc; do
        [[ -z "$svc" ]] && continue
        if systemctl --user is-enabled "$svc" >/dev/null 2>&1; then
            dim "已启用（用户）: $svc"
        else
            run systemctl --user enable --now "$svc"
        fi
    done < <(read_list "$SETUP_DIR/systemd/user.txt")
fi
