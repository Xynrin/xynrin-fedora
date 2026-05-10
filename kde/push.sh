#!/usr/bin/env bash
# kde/push.sh — 把仓库里的 KDE 配置部署到当前机器
# 会先备份现有文件到 ~/.config/.kde-backup-YYYYMMDD-HHMMSS/

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP=$(date +%Y%m%d-%H%M%S)

push_list() {
    local src_root="$1" dst_root="$2" list="$3" label="$4"
    [[ ! -f "$list" ]] && return 0
    [[ ! -d "$src_root" ]] && { printf "  \033[0;90m— 无 %s 快照，跳过\033[0m\n" "$label"; return 0; }
    local backup="$dst_root/.kde-backup-$STAMP"
    local count=0 backups=0
    while read -r item; do
        [[ -z "$item" || "$item" =~ ^[[:space:]]*# ]] && continue
        local src="$src_root/$item"
        local dst="$dst_root/$item"
        [[ ! -e "$src" ]] && continue
        if [[ -e "$dst" ]]; then
            mkdir -p "$backup/$(dirname "$item")"
            cp -a "$dst" "$backup/$item"
            backups=$((backups+1))
        fi
        mkdir -p "$(dirname "$dst")"
        cp -a "$src" "$dst"
        count=$((count+1))
    done < "$list"
    printf "  \033[0;32m✓\033[0m 部署 %d 项" "$count"
    [[ $backups -gt 0 ]] && printf "，备份 %d 项 → %s" "$backups" "$backup"
    printf "\n"
}

printf "\033[0;34m==>\033[0m 部署 kde/config/ → ~/.config/\n"
push_list "$DIR/config" "$HOME/.config" "$DIR/files.txt" "config"

printf "\033[0;34m==>\033[0m 部署 kde/konsole/ → ~/.local/share/konsole/\n"
push_list "$DIR/konsole" "$HOME/.local/share/konsole" "$DIR/konsole-files.txt" "konsole"

printf "\033[1;33m!\033[0m Plasma 需要注销重登或跑 \033[1mkquitapp6 plasmashell && kstart plasmashell\033[0m 才会重载。\n"
