#!/usr/bin/env bash
# bootstrap.sh — xynrin-fedora 在线引导
# 用法：
#   bash <(curl -fsSL https://raw.githubusercontent.com/Xynrin/xynrin-fedora/main/install.sh)
#
# 步骤：
#   1) 严格检测 Fedora（非 Fedora 立即退出）
#   2) 静默装 curl / tar / fzf / git
#   3) 下 tarball / git clone 到 /tmp/xynrin-fedora
#   4) exec install.sh

set -euo pipefail

BRANCH="${XF_BRANCH:-main}"
REPO_URL="https://github.com/Xynrin/xynrin-fedora.git"
TARBALL_URL="https://github.com/Xynrin/xynrin-fedora/archive/refs/heads/${BRANCH}.tar.gz"
TARGET_DIR="${XF_TARGET_DIR:-/tmp/xynrin-fedora}"

R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'; B='\033[1;34m'; N='\033[0m'
log()  { printf "${B}==>${N} %s\n" "$*"; }
ok()   { printf "${G}  ✓${N} %s\n" "$*"; }
warn() { printf "${Y}  !${N} %s\n" "$*"; }
die()  { printf "${R}  ✗${N} %s\n" "$*" >&2; exit 1; }

# ===== 1. 必须以普通用户跑 =====
if [[ $EUID -eq 0 ]]; then
    die "请以普通用户跑本脚本（脚本内部按需 sudo），用 root 会让 ~/.config 落到 /root"
fi

# ===== 2. 严格检测 Fedora =====
if [[ ! -f /etc/fedora-release ]]; then
    die "本脚本仅支持 Fedora，当前系统非 Fedora，立即退出"
fi
if ! grep -qi fedora /etc/os-release 2>/dev/null; then
    die "/etc/os-release 不包含 Fedora，立即退出"
fi

fedver=$(rpm -E %fedora 2>/dev/null || echo 0)
if [[ "$fedver" -lt 41 ]]; then
    warn "当前 Fedora $fedver，推荐 Fedora 44+，部分包名可能缺失"
fi

# ===== 3. 检测架构 =====
arch=$(uname -m)
case "$arch" in
    x86_64|aarch64) ;;
    *) die "不支持的架构: $arch（仅支持 x86_64 / aarch64）" ;;
esac

log "xynrin-fedora — Fedora $fedver KDE 一键美化"
log "分支: $BRANCH  目标: $TARGET_DIR"

# ===== 4. 装基础依赖（静默） =====
missing=()
for c in curl tar fzf rsync git; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    log "安装基础依赖: ${missing[*]}"
    sudo dnf install -y "${missing[@]}" >/dev/null 2>&1 \
        || die "依赖安装失败，请手动 sudo dnf install ${missing[*]}"
    ok "基础依赖装好"
fi

# ===== 5. 拉仓库 =====
if [[ -d "$TARGET_DIR/.git" ]]; then
    log "已有仓库，git pull 增量更新"
    git -C "$TARGET_DIR" fetch origin "$BRANCH" >/dev/null 2>&1 || die "git fetch 失败"
    git -C "$TARGET_DIR" checkout "$BRANCH" >/dev/null 2>&1 || die "git checkout 失败"
    git -C "$TARGET_DIR" reset --hard "origin/$BRANCH" >/dev/null 2>&1 || die "git reset 失败"
elif command -v git >/dev/null 2>&1; then
    [[ -d "$TARGET_DIR" ]] && { warn "覆盖旧目录: $TARGET_DIR"; rm -rf "$TARGET_DIR"; }
    log "git clone（最多 3 次重试）"
    ok_clone=0
    for attempt in 1 2 3; do
        if git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TARGET_DIR" 2>/dev/null; then
            ok_clone=1; break
        fi
        warn "第 $attempt 次 clone 失败，重试..."
        sleep 2
    done
    [[ $ok_clone -eq 1 ]] || die "git clone 失败，请检查网络"
else
    [[ -d "$TARGET_DIR" ]] && rm -rf "$TARGET_DIR"
    mkdir -p "$TARGET_DIR"
    log "下载 tarball（最多 3 次重试）"
    ok_dl=0
    for attempt in 1 2 3; do
        if curl -#L "$TARBALL_URL" | tar -xz -C "$TARGET_DIR" --strip-components=1; then
            ok_dl=1; break
        fi
        warn "第 $attempt 次下载失败，重试..."
        sleep 2
    done
    [[ $ok_dl -eq 1 ]] || die "下载失败"
fi

ok "仓库就绪: $TARGET_DIR"

# ===== 6. exec install.sh =====
chmod +x "$TARGET_DIR/install.sh" "$TARGET_DIR/scripts/"*.sh 2>/dev/null || true
exec "$TARGET_DIR/install.sh" "$@"
