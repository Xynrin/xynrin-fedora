#!/usr/bin/env bash
# 15-cn-mirror.sh — 国内镜像切换（默认跑，非 CN 时区自动跳过）
# 触发条件：/etc/localtime 指向 Asia/Shanghai，或 export XF_CN_MIRROR=1
# 想跳过：XF_SKIP_CN_MIRROR=1

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

if [[ "${XF_SKIP_CN_MIRROR:-0}" == "1" ]]; then
    dim "显式跳过国内镜像切换"
    exit 0
fi

is_cn=0
tz=$(readlink -f /etc/localtime 2>/dev/null || echo "")
[[ "$tz" == *"Shanghai"* || "$tz" == *"Chongqing"* || "$tz" == *"Urumqi"* ]] && is_cn=1
[[ "${XF_CN_MIRROR:-0}" == "1" ]] && is_cn=1

if [[ $is_cn -eq 0 ]]; then
    dim "非 CN 时区，使用默认官方镜像"
    exit 0
fi

info_kv "检测到" "时区 Asia/Shanghai" "国内用户建议切 TUNA 镜像加速"

if ! confirm "切换到 TUNA（清华）镜像？" Y 20; then
    dim "保留官方镜像"
    exit 0
fi

TUNA="https://mirrors.tuna.tsinghua.edu.cn"
SJTU_FLATHUB="https://mirror.sjtu.edu.cn/flathub"

log "切换 Fedora 主仓库到 TUNA"
need_sudo

# Fedora 主仓库（metalink → TUNA baseurl）
# 覆盖 fedora.repo / fedora-updates.repo 等；cisco-openh264 单独处理
for f in /etc/yum.repos.d/fedora{,-updates,-updates-testing}.repo; do
    [[ -f "$f" ]] || continue
    sudo sed -i.xfbak \
        -e 's|^metalink=|#metalink=|g' \
        -e 's|^#baseurl=http://download\.example/pub/fedora/linux|baseurl='"$TUNA"'/fedora|g' \
        "$f"
    dim "已切: $(basename "$f")"
done

# RPM Fusion（10-repos 刚装的）
for f in /etc/yum.repos.d/rpmfusion-*.repo; do
    [[ -f "$f" ]] || continue
    sudo sed -i.xfbak \
        -e 's|^metalink=|#metalink=|g' \
        -e 's|^#baseurl=http://download1\.rpmfusion\.org|baseurl='"$TUNA"'/rpmfusion|g' \
        "$f"
    dim "已切: $(basename "$f")"
done

# Flathub → SJTU 镜像
if flatpak remotes --columns=name 2>/dev/null | grep -qx flathub; then
    log "切换 Flathub 到 SJTU 镜像"
    exe flatpak remote-modify flathub --url="$SJTU_FLATHUB" || \
        warn "Flathub 镜像切换失败，保留官方"
fi

# 刷新元数据，让新镜像立即生效
log "刷新 dnf 元数据（用新镜像）"
exe sudo dnf makecache --refresh

success "国内镜像切换完成（如要回官方：删除 /etc/yum.repos.d/*.xfbak 前的 sed 改动可人工改回）"
