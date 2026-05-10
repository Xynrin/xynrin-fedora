#!/usr/bin/env bash
# 编译 VirtualBox 内核模块并启动 vboxdrv 服务
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log "VirtualBox 内核模块"

if xf_is_vm; then
    warn "检测到虚拟机环境 ($(xf_virt))，跳过 VirtualBox 内核模块编译"
    exit 0
fi

need_sudo

if systemctl is-active vboxdrv >/dev/null 2>&1; then
    ok "vboxdrv 已在运行"
    exit 0
fi

dim "编译内核模块 (akmods)..."
run sudo akmods

dim "启动 vboxdrv 服务..."
run sudo systemctl restart vboxdrv.service

if systemctl is-active vboxdrv >/dev/null 2>&1; then
    ok "vboxdrv 已启动"
else
    err "vboxdrv 启动失败，可能需要检查 Secure Boot 签名"
    exit 1
fi
