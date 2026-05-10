#!/usr/bin/env bash
# bootstrap.sh — fedora-setup 在线引导脚本
# 用法：
#   curl -fsSL https://raw.githubusercontent.com/Xynrin/fedora-setup/main/bootstrap.sh | bash
#
# 做三件事：
#   1. 确保 git 已装（缺就用 dnf 装）
#   2. 克隆仓库到 ~/fedora-setup（已存在就跳过或 git pull）
#   3. 打印下一步命令（install.sh 需要交互输入 sudo，不在管道里自动跑）

set -euo pipefail

REPO_URL="https://github.com/Xynrin/fedora-setup.git"
DEST="${FEDORA_SETUP_DIR:-$HOME/fedora-setup}"

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

# 2) clone / pull
if [[ -d "$DEST/.git" ]]; then
    log "仓库已存在，拉取最新"
    git -C "$DEST" pull --ff-only || warn "git pull 失败，继续"
elif [[ -e "$DEST" ]]; then
    die "$DEST 已存在但不是 git 仓库，请先处理"
else
    log "克隆 $REPO_URL → $DEST"
    git clone "$REPO_URL" "$DEST"
fi
ok "仓库就绪：$DEST"

# 3) 下一步提示
cat <<EOF

${c_green}引导完成。${c_reset}下一步手动跑：

  cd $DEST
  ./install.sh                 # 全量安装
  ./install.sh --dry-run       # 或先预览
  ./install.sh --only fish     # 或只装某一步

install.sh 会弹 sudo 密码，不能通过管道直接跑。
EOF
