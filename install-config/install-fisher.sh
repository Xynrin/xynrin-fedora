#!/usr/bin/env bash
# 引导 fisher 本身 + 按 fish_plugins 安装缺失的插件
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "fisher 插件"
if ! command -v fish >/dev/null; then
    err "fish 未安装"
    exit 1
fi

plugins_file="$SETUP_DIR/fish/fish_plugins"
if [[ ! -f "$plugins_file" ]]; then
    warn "没有 fish_plugins 文件"
    exit 0
fi

if ! fish -c "functions -q fisher" 2>/dev/null; then
    log "引导 fisher"
    # raw.githubusercontent.com 在国内经常不可达，自动探测并走代理
    _gh_raw_base="https://raw.githubusercontent.com"
    _gh_proxy_base="https://ghfast.top/https://raw.githubusercontent.com"
    _fisher_path="jorgebucaran/fisher/main/functions/fisher.fish"

    _pick_raw_base() {
        if curl -fsSL --max-time 5 "$_gh_raw_base/jorgebucaran/fisher/main/README.md" \
                -o /dev/null 2>/dev/null; then
            printf '%s' "$_gh_raw_base"
        else
            warn "raw.githubusercontent.com 不可达，使用 ghfast.top 代理"
            printf '%s' "$_gh_proxy_base"
        fi
    }

    _raw_base=$(_pick_raw_base)
    run fish -c "curl -fsSL '$_raw_base/$_fisher_path' | source && fisher install jorgebucaran/fisher"
fi

plugins=$(read_list "$plugins_file" | xargs echo)
[[ -z "$plugins" ]] && { dim "没有插件要装"; exit 0; }

have=$(fish -c 'string join \n $_fisher_plugins' 2>/dev/null \
    | sed 's/@.*//' | tr '[:upper:]' '[:lower:]')
missing=""
for p in $plugins; do
    key="${p%@*}"
    key=$(echo "$key" | tr '[:upper:]' '[:lower:]')
    if ! grep -qxF "$key" <<< "$have"; then
        missing+=" $p"
    fi
done
if [[ -z "${missing// /}" ]]; then
    ok "所有 fisher 插件都已安装"
    exit 0
fi
dim "待装:$missing"
# shellcheck disable=SC2086
run fish -c "fisher install$missing"
