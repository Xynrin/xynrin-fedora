#!/usr/bin/env bash
# kde/pull.sh — 把当前机器的 KDE 配置采集到仓库里
# 读取 kde/files.txt 和 kde/konsole-files.txt，复制到 kde/config/ 和 kde/konsole/

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pull_list() {
    local src_root="$1" dst_root="$2" list="$3"
    [[ ! -f "$list" ]] && return 0
    mkdir -p "$dst_root"
    local count=0 skipped=0
    while read -r item; do
        [[ -z "$item" || "$item" =~ ^[[:space:]]*# ]] && continue
        local src="$src_root/$item"
        local dst="$dst_root/$item"
        if [[ ! -e "$src" ]]; then
            printf "  \033[0;90m— 跳过 (不存在): %s\033[0m\n" "$item"
            skipped=$((skipped+1))
            continue
        fi
        mkdir -p "$(dirname "$dst")"
        cp -a "$src" "$dst"
        count=$((count+1))
    done < "$list"
    printf "  \033[0;32m✓\033[0m 采集 %d 项，跳过 %d 项\n" "$count" "$skipped"
}

printf "\033[0;34m==>\033[0m 采集 ~/.config/ → kde/config/\n"
pull_list "$HOME/.config" "$DIR/config" "$DIR/files.txt"

printf "\033[0;34m==>\033[0m 采集 ~/.local/share/konsole/ → kde/konsole/\n"
pull_list "$HOME/.local/share/konsole" "$DIR/konsole" "$DIR/konsole-files.txt"

printf "\033[0;34m==>\033[0m 完成。检查 git diff 后再提交。\n"
