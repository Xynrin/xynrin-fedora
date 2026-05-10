#!/usr/bin/env bash
# symlink settings.json + 按 extensions.txt 装 VSCode 扩展
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "vscode"
if ! command -v code >/dev/null; then
    warn "code 不在 PATH，跳过"
    exit 0
fi

link_into "$SETUP_DIR/vscode/settings.json" "$HOME/.config/Code/User/settings.json"

exts=$(read_list "$SETUP_DIR/vscode/extensions.txt")
[[ -z "$exts" ]] && { dim "没有扩展要装"; exit 0; }

installed=$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')
while read -r ext; do
    [[ -z "$ext" ]] && continue
    if grep -qxF "$(echo "$ext" | tr '[:upper:]' '[:lower:]')" <<< "$installed"; then
        dim "已安装: $ext"
    else
        run code --install-extension "$ext"
    fi
done <<< "$exts"
