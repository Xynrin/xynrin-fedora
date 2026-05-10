#!/usr/bin/env bash
# 90-cleanup.sh — 隐藏无用 .desktop + 收尾提示

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

detect_target_user

log "隐藏工具类无用菜单图标"
run_hide_desktop_files
success "菜单清理完成"

# 丢一份 README 到桌面
if [[ -f "$SETUP_DIR/resources/KDE-README.txt" ]]; then
    desktop="$HOME_DIR/Desktop"
    mkdir -p "$desktop"
    if [[ -f "$desktop/xynrin-fedora-使用说明.txt" ]] \
        && cmp -s "$SETUP_DIR/resources/KDE-README.txt" "$desktop/xynrin-fedora-使用说明.txt"; then
        dim "桌面说明已在"
    else
        cp -f "$SETUP_DIR/resources/KDE-README.txt" "$desktop/xynrin-fedora-使用说明.txt"
        success "桌面已放 xynrin-fedora-使用说明.txt"
    fi
fi
