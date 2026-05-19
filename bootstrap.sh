#!/usr/bin/env bash
# bootstrap.sh — xynrin-fedora 在线引导
# 用法：
#   bash <(curl -fsSL https://raw.githubusercontent.com/Xynrin/xynrin-fedora/main/bootstrap.sh)
#
# 做 4 件事：
#   1. 检测 Fedora
#   2. 静默装 curl / tar / fzf（FZF 菜单要用）
#   3. 下 tarball 到 /tmp/xynrin-fedora（带重试）
#   4. exec install.sh（以普通用户身份，模块内部按需 sudo）

set -euo pipefail

BRANCH="${XF_BRANCH:-main}"
TARBALL_URL="https://github.com/Xynrin/xynrin-fedora/archive/refs/heads/${BRANCH}.tar.gz"
TARGET_DIR="${XF_TARGET_DIR:-/tmp/xynrin-fedora}"

R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'; B='\033[1;34m'; N='\033[0m'
log()  { printf "${B}==>${N} %s\n" "$*"; }
ok()   { printf "${G}  ✓${N} %s\n" "$*"; }
warn() { printf "${Y}  !${N} %s\n" "$*"; }
die()  { printf "${R}  ✗${N} %s\n" "$*" >&2; exit 1; }

# 不允许以 root 跑，避免 $HOME 变 /root 污染小白 ~
if [[ $EUID -eq 0 ]]; then
    die "请以普通用户跑本脚本，模块内部会按需 sudo（这样 ~/.config 落到你自己家里）"
fi

# 检测 Fedora
[[ -f /etc/fedora-release ]] || die "本脚本仅支持 Fedora"

# 检测架构
arch=$(uname -m)
[[ "$arch" == "x86_64" || "$arch" == "aarch64" ]] || die "不支持的架构: $arch"

log "xynrin-fedora — Fedora KDE 一键美化"
log "分支: $BRANCH  目标: $TARGET_DIR"

# 静默装依赖（pv 用于下载进度条）
missing=()
for c in curl tar fzf rsync pv; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    log "安装依赖: ${missing[*]}"
    sudo dnf install -y "${missing[@]}" >/dev/null 2>&1 \
        || die "依赖安装失败，请检查网络或手动 sudo dnf install ${missing[*]}"
    ok "依赖装好"
fi

# 清理旧目录
if [[ -d "$TARGET_DIR" ]]; then
    warn "覆盖旧目录: $TARGET_DIR"
    rm -rf "$TARGET_DIR"
fi
mkdir -p "$TARGET_DIR"

# 下 + 解压（最多 3 次重试，pv 提供进度条）
log "下载仓库…"
ok_download=0
# GitHub 不发 Content-Length，估算 tarball ~2MB
est_size="2m"
for attempt in 1 2 3; do
    if command -v pv >/dev/null 2>&1; then
        if curl -fsSL "$TARBALL_URL" | pv -pterb -s "$est_size" -N "下载" \
            | tar -xz -C "$TARGET_DIR" --strip-components=1; then
            ok_download=1
            break
        fi
    else
        if curl -#L "$TARBALL_URL" | tar -xz -C "$TARGET_DIR" --strip-components=1; then
            ok_download=1
            break
        fi
    fi
    warn "第 $attempt 次下载失败，重试中…"
    sleep 2
done
[[ $ok_download -eq 1 ]] || die "下载 $TARBALL_URL 失败，请检查网络"
ok "仓库就绪: $TARGET_DIR"

# exec install.sh
chmod +x "$TARGET_DIR/install.sh"
exec "$TARGET_DIR/install.sh" "$@"
