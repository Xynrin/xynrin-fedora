#!/usr/bin/env bash
# 通过 nvm.fish 确保 LTS 存在，按 node/npm-globals.txt 装全局 npm 包
# npm 操作全部通过 fish -c 执行，确保使用 nvm 管理的 node 而非系统 node。
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "node / nvm.fish"
if ! command -v fish >/dev/null; then
    err "fish 未安装"
    exit 1
fi
if ! fish -c "functions -q nvm" 2>/dev/null; then
    warn "nvm.fish 未安装，请先跑 --only fisher"
    exit 1
fi

current=$(fish -c 'nvm current 2>/dev/null' || echo "")
if [[ -z "$current" || "$current" == "none" || "$current" == "system" ]]; then
    run fish -c "nvm install lts"
else
    dim "node 已激活: $current"
fi

pkgs_file="$SETUP_DIR/node/npm-globals.txt"
[[ ! -f "$pkgs_file" ]] && exit 0

pkgs=$(read_list "$pkgs_file")
[[ -z "$pkgs" ]] && { dim "没有 npm 全局包要装"; exit 0; }

installed=$(fish -c 'npm ls -g --depth=0 --parseable 2>/dev/null' \
    | sed -E 's|.*/node_modules/||' | sort -u)

while read -r p; do
    [[ -z "$p" ]] && continue
    if grep -qxF "$p" <<< "$installed"; then
        dim "已安装: $p"
    else
        run fish -c "npm install -g '$p'"
    fi
done <<< "$pkgs"
