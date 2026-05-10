#!/usr/bin/env bash
# RPM Fusion free/nonfree + 复制第三方 .repo + 启用 COPR
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "dnf repos（rpmfusion + 第三方 + copr）"
need_sudo

fedver=$(rpm -E %fedora)

# 从 preferred.txt 读取镜像，用于 rpmfusion release rpm 的下载 URL
_rpmfusion_host() {
    local pref_file="$SETUP_DIR/mirrors/preferred.txt"
    local mirror=""
    [[ -f "$pref_file" ]] && mirror=$(grep -vE '^\s*(#|$)' "$pref_file" | head -1 | tr -d '[:space:]')
    case "$mirror" in
        tuna)   printf 'mirrors.tuna.tsinghua.edu.cn' ;;
        ustc)   printf 'mirrors.ustc.edu.cn' ;;
        aliyun) printf 'mirrors.aliyun.com' ;;
        *)      printf 'mirrors.rpmfusion.org' ;;
    esac
}

_install_rpmfusion_release() {
    local variant="$1"   # free or nonfree
    local pkg="rpmfusion-${variant}-release"
    rpm -q "$pkg" >/dev/null 2>&1 && { dim "rpmfusion-${variant} 已启用"; return 0; }

    local host
    host=$(_rpmfusion_host)
    local url="https://${host}/rpmfusion/${variant}/fedora/rpmfusion-${variant}-release-${fedver}.noarch.rpm"
    local fallback="https://mirrors.rpmfusion.org/${variant}/fedora/rpmfusion-${variant}-release-${fedver}.noarch.rpm"

    if run sudo dnf install -y "$url"; then
        ok "rpmfusion-${variant} 已安装（via $host）"
    elif [[ "$url" != "$fallback" ]]; then
        warn "镜像下载失败，回退到官方 CDN"
        run sudo dnf install -y "$fallback"
    fi
}

_install_rpmfusion_release free
_install_rpmfusion_release nonfree

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
