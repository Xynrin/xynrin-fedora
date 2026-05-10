#!/usr/bin/env bash
# symlink config.fish / functions / conf.d / fish_plugins，并应用 universal_vars.fish
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "fish 配置、函数、conf.d、插件"
if ! command -v fish >/dev/null; then
    err "fish 未安装，请先跑 --only dnf"
    exit 1
fi

dst_fns="$HOME/.config/fish/functions"
dst_conf="$HOME/.config/fish/conf.d"
run mkdir -p "$dst_fns" "$dst_conf"

for f in config.fish fish_plugins; do
    if [[ -f "$SETUP_DIR/fish/$f" ]]; then
        link_into "$SETUP_DIR/fish/$f" "$HOME/.config/fish/$f"
    fi
done

shopt -s nullglob
for f in "$SETUP_DIR/fish/functions"/*.fish; do
    link_into "$f" "$dst_fns/$(basename "$f")"
done
for f in "$SETUP_DIR/fish/conf.d"/*.fish; do
    link_into "$f" "$dst_conf/$(basename "$f")"
done
shopt -u nullglob

if [[ -f "$SETUP_DIR/fish/universal_vars.fish" ]]; then
    if [[ ${DRY_RUN:-0} -eq 0 ]]; then
        fish "$SETUP_DIR/fish/universal_vars.fish" \
            && ok "已应用 universal_vars.fish" \
            || warn "universal_vars.fish 执行出错"
    else
        dim "DRY: fish $SETUP_DIR/fish/universal_vars.fish"
    fi
fi
