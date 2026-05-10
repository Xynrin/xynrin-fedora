#!/usr/bin/env bash
# 50-apps.sh — 常用软件 FZF 多选 + 批量装

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

detect_target_user
PARENT_DIR="$SETUP_DIR"

LIST_KDE="$PARENT_DIR/applist-kde.txt"
LIST_COMMON="$PARENT_DIR/applist-common.txt"

# 汇总清单：先 common，再 kde
merged=""
[[ -f "$LIST_COMMON" ]] && merged+=$(cat "$LIST_COMMON")$'\n'
[[ -f "$LIST_KDE" ]] && merged+=$(cat "$LIST_KDE")$'\n'

if [[ -z "${merged// /}" ]]; then
    warn "未找到 applist 清单，跳过"
    exit 0
fi

# 过滤注释空行，并把行内注释变 TAB（FZF 用 TAB 分字段）
cleaned=$(echo "$merged" | grep -vE '^\s*(#|$)' | sed -E 's/[[:space:]]+#/\t#/')

section "常用软件" "FZF 多选（默认全选 · TAB 切换 · Enter 确认）"
echo ""
dim "20 秒内按任意键进入自选菜单；不按就默认安装全部。"

if read -t 20 -n 1 -s -r; then
    customize=true
else
    customize=false
fi

selected=""
if [[ "$customize" == true ]]; then
    selected=$(echo "$cleaned" | fzf \
        --multi \
        --delimiter=$'\t' \
        --with-nth=1 \
        --layout=reverse \
        --border=rounded \
        --border-label="  选择要安装的软件  " \
        --header="[TAB] 选 | [CTRL-A] 全选 | [CTRL-D] 全不选 | [Enter] 确认" \
        --bind 'load:select-all,ctrl-a:select-all,ctrl-d:deselect-all' \
        --preview 'echo {} | cut -f2- | sed "s/^#[ ]*//"' \
        --preview-window=down:3:wrap \
        --color="marker:cyan,pointer:cyan,label:yellow" \
        --pointer=">" \
        --height=80%) || {
            warn "用户取消，跳过软件安装"
            exit 0
        }
    [[ -z "$selected" ]] && { warn "未选择任何软件，跳过"; exit 0; }
else
    log "超时未选，默认安装全部"
    selected="$cleaned"
fi

# 解析：flatpak: 前缀走 flatpak，其余走 dnf
declare -a DNF_APPS=()
declare -a FLATPAK_APPS=()
while IFS= read -r line; do
    pkg=$(echo "$line" | cut -f1 | xargs)
    [[ -z "$pkg" ]] && continue
    if [[ "$pkg" == flatpak:* ]]; then
        FLATPAK_APPS+=("${pkg#flatpak:}")
    else
        DNF_APPS+=("$pkg")
    fi
done <<< "$selected"

info_kv "计划安装" "dnf: ${#DNF_APPS[@]}" "flatpak: ${#FLATPAK_APPS[@]}"

declare -a FAILED=()

# ---- dnf 批量 ----
if [[ ${#DNF_APPS[@]} -gt 0 ]]; then
    log "dnf 批量安装"
    need_sudo
    if ! exe sudo dnf install -y "${DNF_APPS[@]}"; then
        warn "批量安装失败，逐个重试"
        for pkg in "${DNF_APPS[@]}"; do
            if ! rpm -q "$pkg" >/dev/null 2>&1; then
                if ! sudo dnf install -y "$pkg"; then
                    FAILED+=("dnf:$pkg")
                fi
            fi
        done
    fi
fi

# ---- flatpak 逐个 ----
if [[ ${#FLATPAK_APPS[@]} -gt 0 ]]; then
    log "flatpak 安装（每个独立）"
    for app in "${FLATPAK_APPS[@]}"; do
        if flatpak info "$app" >/dev/null 2>&1; then
            dim "已装: $app"
            continue
        fi
        if ! exe flatpak install -y --noninteractive flathub "$app"; then
            FAILED+=("flatpak:$app")
        fi
    done
fi

# ---- 失败报告 ----
if [[ ${#FAILED[@]} -gt 0 ]]; then
    docs="$HOME_DIR/Documents"
    mkdir -p "$docs"
    report="$docs/xynrin-fedora-install-failed.txt"
    {
        echo "======================================"
        echo "  安装失败的软件 - $(date '+%F %T')"
        echo "======================================"
        printf '%s\n' "${FAILED[@]}"
    } >> "$report"
    chown "$TARGET_USER:$TARGET_USER" "$report" 2>/dev/null || true
    warn "部分软件安装失败，清单已写入:"
    dim "  $report"
else
    success "所有软件安装成功"
fi

# ---- 国产软件手动下载提示 ----
# QQ / 微信 官方下载页是纯 JS 渲染，curl 抓不到稳定直链（且链接带时效 token）
# Flathub 上也没有官方版本，因此不做自动安装，打印手动下载指引
section "国产软件提示" "QQ / 微信 需手动下载"
cat <<'EOF'

   这两款没有官方 Flathub / Fedora 源仓库，请手动下载 .rpm：

     QQ Linux：  https://im.qq.com/linuxqq/
     微信 Linux：https://pc.weixin.qq.com/

   下载完后在下载目录执行：

     sudo dnf install ./linuxqq_*.rpm
     sudo dnf install ./WeChat_*.rpm

   dnf 会自动解决依赖。

EOF
