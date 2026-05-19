#!/usr/bin/env bash
# 15-cn-mirror.sh — 国内镜像切换（默认跑，非 CN 时区自动跳过）
# 触发条件：/etc/localtime 指向 Asia/Shanghai，或 export XF_CN_MIRROR=1
# 想跳过：XF_SKIP_CN_MIRROR=1
# 兼容 Fedora 41+（dnf5）与 Fedora 40-（dnf4）

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

# repo 文件占位符模式（Fedora 长年保持）：
#   #baseurl=http://download.example/pub/fedora/linux...
#   #baseurl=http://download1.rpmfusion.org/...
# 改前先校验占位符存在，避免新版本格式变化时静默失效
_switch_repo() {
    local file="$1" placeholder_pat="$2" replacement="$3"
    [[ -f "$file" ]] || return 0

    if ! grep -qE "$placeholder_pat" "$file"; then
        warn "$(basename "$file") 中未找到 baseurl 占位符，跳过（格式可能已变）"
        return 0
    fi

    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        dim "DRY-RUN: 会切 $(basename "$file")"
        return 0
    fi

    sudo cp -n "$file" "${file}.xfbak"
    sudo sed -i \
        -e 's|^metalink=|#metalink=|g' \
        -e "s|^#baseurl=${placeholder_pat}|baseurl=${replacement}|g" \
        "$file"
    dim "已切: $(basename "$file")"
}

log "切换 Fedora 主仓库到 TUNA"
need_sudo

# Fedora 主仓库（F41+ 把官方源拆得更细，统一遍历 fedora*.repo）
for f in /etc/yum.repos.d/fedora.repo \
         /etc/yum.repos.d/fedora-updates.repo \
         /etc/yum.repos.d/fedora-updates-testing.repo \
         /etc/yum.repos.d/fedora-cisco-openh264.repo; do
    _switch_repo "$f" \
        'http://download\.example/pub/fedora/linux' \
        "$TUNA/fedora"
done

# RPM Fusion
for f in /etc/yum.repos.d/rpmfusion-*.repo; do
    [[ -f "$f" ]] || continue
    _switch_repo "$f" \
        'http://download1\.rpmfusion\.org' \
        "$TUNA/rpmfusion"
done

# Flathub → SJTU 镜像
if flatpak remotes --columns=name 2>/dev/null | grep -qx flathub; then
    log "切换 Flathub 到 SJTU 镜像"
    exe flatpak remote-modify flathub --url="$SJTU_FLATHUB" || \
        warn "Flathub 镜像切换失败，保留官方"
fi

# 刷新元数据，让新镜像立即生效
log "刷新 dnf 元数据（用新镜像）"
exe sudo "$XF_DNF" makecache --refresh

success "国内镜像切换完成"
dim "回滚：sudo cp /etc/yum.repos.d/*.xfbak 同名文件（去掉 .xfbak 后缀）"
