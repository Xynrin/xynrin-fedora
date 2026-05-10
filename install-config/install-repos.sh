#!/usr/bin/env bash
# RPM Fusion free/nonfree + 复制第三方 .repo + 启用 COPR
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "dnf repos（rpmfusion + 第三方 + copr）"
need_sudo

fedver=$(rpm -E %fedora)
if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
    run sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedver}.noarch.rpm"
else
    dim "rpmfusion-free 已启用"
fi
if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
    run sudo dnf install -y \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedver}.noarch.rpm"
else
    dim "rpmfusion-nonfree 已启用"
fi

shopt -s nullglob
for r in "$SETUP_DIR/repos"/*.repo; do
    dst="/etc/yum.repos.d/$(basename "$r")"
    if [[ -f "$dst" ]] && cmp -s "$r" "$dst"; then
        dim "已就位: $(basename "$r")"
    else
        run sudo install -m 644 "$r" "$dst"
        ok "已部署 $(basename "$r")"
    fi
done
shopt -u nullglob

if [[ -f "$SETUP_DIR/repos/copr.txt" ]]; then
    enabled=$(ls /etc/yum.repos.d/_copr*.repo 2>/dev/null | \
        sed -E 's|.*_copr:copr\.fedorainfracloud\.org:([^:]+):([^.]+)\.repo|\1/\2|' || true)
    while read -r copr; do
        [[ -z "$copr" ]] && continue
        if grep -qxF "$copr" <<< "$enabled"; then
            dim "copr 已启用: $copr"
        else
            run sudo dnf copr enable -y "$copr"
        fi
    done < <(read_list "$SETUP_DIR/repos/copr.txt")
fi
