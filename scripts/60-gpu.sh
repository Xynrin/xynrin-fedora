#!/usr/bin/env bash
# 60-gpu.sh — 显卡驱动
# 检测策略：lspci 找 VGA/3D/Display，取第一张。
# NVIDIA → akmod-nvidia + 32bit + cuda + vaapi（akmod 构建可能需要几分钟）
# AMD    → mesa-va-drivers-freeworld + mesa-vdpau-drivers-freeworld（rpmfusion 替换）
# Intel  → intel-media-driver + libva-intel-driver

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

# ===== 虚拟机直接跳 =====
if command -v systemd-detect-virt >/dev/null 2>&1; then
    virt=$(systemd-detect-virt 2>/dev/null || echo none)
    if [[ "$virt" != "none" ]]; then
        warn "检测到虚拟机环境 ($virt)，跳过显卡驱动（用宿主机驱动 + SPICE/VirGL）"
        exit 0
    fi
fi

# ===== 检测 GPU =====
if ! command -v lspci >/dev/null 2>&1; then
    dnf_install pciutils
fi

gpu_lines=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' || true)
if [[ -z "$gpu_lines" ]]; then
    warn "没检测到显卡，跳过"
    exit 0
fi

log "检测到显卡："
while IFS= read -r line; do
    dim "  $line"
done <<< "$gpu_lines"

has_nvidia=0
has_amd=0
has_intel=0
while IFS= read -r line; do
    case "$line" in
        *NVIDIA*|*nvidia*)                       has_nvidia=1 ;;
        *AMD*|*ATI*|*Radeon*|*amd*)              has_amd=1 ;;
        *Intel*|*intel*)                         has_intel=1 ;;
    esac
done <<< "$gpu_lines"

# ===== NVIDIA（优先：混合架构常见 Intel + NVIDIA，NVIDIA 是独显需要驱动）=====
if [[ $has_nvidia -eq 1 ]]; then
    section "GPU: NVIDIA" "akmod-nvidia + CUDA 支持"

    # RPM Fusion 必须已启用（10-repos.sh 已处理，这里兜底）
    if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
        error "RPM Fusion nonfree 未启用，无法装 NVIDIA 驱动"
        exit 1
    fi

    warn "NVIDIA 驱动会触发 akmod 后台编译内核模块，首次需要 3-10 分钟"
    warn "编译完成前屏幕可能还是 nouveau 驱动，重启后才切到 nvidia"

    if ! confirm "继续安装 NVIDIA 专有驱动？" Y 30; then
        dim "跳过 NVIDIA 驱动"
    else
        dnf_install \
            akmod-nvidia \
            xorg-x11-drv-nvidia-cuda \
            xorg-x11-drv-nvidia-cuda-libs.i686 \
            nvidia-vaapi-driver \
            libva-utils \
            vdpauinfo

        # 触发构建并等待
        log "触发 akmod 内核模块构建（可能要几分钟）"
        exe sudo akmods --force >/dev/null 2>&1 || true
        exe sudo dracut --force >/dev/null 2>&1 || true

        success "NVIDIA 驱动已安装（重启后生效）"
        warn "重启前请不要进行其他 GPU 相关操作"
    fi
fi

# ===== AMD =====
if [[ $has_amd -eq 1 ]]; then
    section "GPU: AMD" "Mesa + VAAPI/VDPAU (freeworld)"

    # RPM Fusion 的 freeworld 版 mesa 支持更多编解码器（h264/h265/vc1）
    dnf_install mesa-dri-drivers

    # freeworld 替换（swap 不抛错）
    need_sudo
    exe sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld 2>/dev/null || \
        dim "mesa-va-drivers-freeworld 已就位或无需替换"
    exe sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld 2>/dev/null || \
        dim "mesa-vdpau-drivers-freeworld 已就位或无需替换"

    # 32 位支持（Steam/Wine 用）
    exe sudo dnf swap -y mesa-va-drivers.i686 mesa-va-drivers-freeworld.i686 2>/dev/null || true
    exe sudo dnf swap -y mesa-vdpau-drivers.i686 mesa-vdpau-drivers-freeworld.i686 2>/dev/null || true

    dnf_install libva-utils vdpauinfo

    success "AMD 开源驱动 + 硬解编码器就绪"
fi

# ===== Intel =====
if [[ $has_intel -eq 1 && $has_nvidia -eq 0 ]]; then
    # 混合架构（Intel + NVIDIA）通常以 NVIDIA 为主，不再装 Intel 硬解
    section "GPU: Intel" "Mesa + VAAPI 硬解"

    dnf_install \
        mesa-dri-drivers \
        intel-media-driver \
        libva-intel-driver \
        libva-utils

    success "Intel 显卡驱动 + 硬解就绪"
fi

success "显卡驱动检查完成"
