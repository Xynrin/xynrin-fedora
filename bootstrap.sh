#!/usr/bin/env bash
# bootstrap.sh — xynrin-fedora 在线引导脚本
# 用法：
#   bash <(curl -fsSL https://raw.githubusercontent.com/Xynrin/xynrin-fedora/main/bootstrap.sh)
#
# 做三件事：
#   1. 确保 git 已装（缺就用 dnf 装）
#   2. 克隆仓库到 ~/xynrin-fedora（已存在就跳过或 git pull）
#   3. 自动执行 install.sh

set -euo pipefail

_GH_BASE="https://github.com"
_GH_PROXY_BASE="https://ghfast.top/https://github.com"
REPO_PATH="Xynrin/xynrin-fedora.git"
DEST="${XYNRIN_FEDORA_DIR:-$HOME/xynrin-fedora}"

c_reset='\033[0m'; c_blue='\033[0;34m'; c_green='\033[0;32m'
c_yellow='\033[1;33m'; c_red='\033[0;31m'
log()  { printf "${c_blue}==>${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}  ✓${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}  !${c_reset} %s\n" "$*"; }
die()  { printf "${c_red}  ✗${c_reset} %s\n" "$*" >&2; exit 1; }

# 仅支持 Fedora 系
if ! command -v dnf >/dev/null 2>&1; then
    die "没找到 dnf，这个脚本只支持 Fedora。"
fi

# 1) git
if ! command -v git >/dev/null 2>&1; then
    log "安装 git"
    sudo dnf install -y git || die "git 安装失败"
    ok "git 已装"
else
    ok "git 已存在"
fi

# 探测 GitHub 直连是否可达，不可达时走 ghfast.top 代理
_pick_gh_base() {
    if git ls-remote --exit-code "$_GH_BASE/$REPO_PATH" HEAD >/dev/null 2>&1; then
        printf '%s' "$_GH_BASE"
    else
        warn "github.com 不可达，使用 ghfast.top 代理"
        printf '%s' "$_GH_PROXY_BASE"
    fi
}

# 2) clone / pull
if [[ -d "$DEST/.git" ]]; then
    log "仓库已存在，拉取最新"
    git -C "$DEST" pull --ff-only || warn "git pull 失败，继续用本地版本"
elif [[ -e "$DEST" ]]; then
    die "$DEST 已存在但不是 git 仓库，请先手动处理"
else
    _gh_base=$(_pick_gh_base)
    REPO_URL="$_gh_base/$REPO_PATH"
    log "克隆 $REPO_URL → $DEST"
    git clone "$REPO_URL" "$DEST"
fi
ok "仓库就绪：$DEST"

# 3) 执行 install.sh
chmod +x "$DEST/install.sh"
exec "$DEST/install.sh" "$@"
