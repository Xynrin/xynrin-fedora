#!/usr/bin/env bash
# 把 scripts/*.sh 软链接到 ~/.local/bin/<name>（脱 .sh 后缀）
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "scripts -> ~/.local/bin"
bindir="$HOME/.local/bin"
run mkdir -p "$bindir"

shopt -s nullglob
for s in "$SETUP_DIR/scripts"/*.sh; do
    name=$(basename "$s" .sh)
    run chmod +x "$s"
    link_into "$s" "$bindir/$name"
done
shopt -u nullglob
