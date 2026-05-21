#!/usr/bin/env bash
# 50-apps.sh — 常用软件 FZF 多选 + 逐包安装

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=00-utils.sh
source "$SCRIPT_DIR/00-utils.sh"

detect_target_user
PARENT_DIR="$SETUP_DIR"

LIST_KDE="$PARENT_DIR/applist-kde.txt"
LIST_COMMON="$PARENT_DIR/applist-common.txt"

# ---- 汇总清单 ----
merged=""
[[ -f "$LIST_COMMON" ]] && merged+=$(cat "$LIST_COMMON")$'\n'
[[ -f "$LIST_KDE" ]] && merged+=$(cat "$LIST_KDE")$'\n'

if [[ -z "${merged// /}" ]]; then
    warn "未找到 applist 清单，跳过"
    exit 0
fi

# 过滤注释空行，行内注释变 TAB 分隔（fzf 用 TAB 分字段）
cleaned=$(echo "$merged" | grep -vE '^\s*(#|$)' | sed -E 's/[[:space:]]+#/\t#/')
total_count=$(echo "$cleaned" | grep -c '^[^[:space:]]')

section "常用软件" "共 $total_count 个候选 · 默认全选"

# ---- 选择 ----
# 1) --all / 非交互：直接全选，不弹菜单
# 2) 交互：fzf 流式接收（pipe），开窗即出列表，无空窗期
selected=""
if [[ "${XF_NONINTERACTIVE:-0}" == "1" ]]; then
    log "非交互模式：默认安装全部 ($total_count)"
    selected="$cleaned"
else
    dim "操作：[TAB] 切换 / [Ctrl-A] 全选 / [Ctrl-D] 全不选 / [Enter] 确认 / [Esc] 取消"
    echo ""

    # 流式喂给 fzf：边读边渲染，避免"打开后空白"的体感
    # 关键：去掉 --sync（它会等 stdin 关闭再渲染），用默认异步模式
    # --bind 'start:...'：fzf 启动瞬间触发，不必等 load 完成再全选
    # --tac：从尾部往头部进，让最常用的（applist 顶部）排在最上面（视觉一致）
    # 注：echo "$cleaned" 已经在内存，但 fzf 用流式读取仍然边收边显示
    if selected=$(
        echo "$cleaned" | fzf \
            --multi \
            --delimiter=$'\t' \
            --with-nth=1 \
            --layout=reverse \
            --border=rounded \
            --border-label="  $total_count 个软件包 / 默认全选  " \
            --border-label-pos=3 \
            --info=inline-right \
            --prompt="搜索 ❯ " \
            --header="Enter 安装勾选项 · TAB 切换 · Ctrl-A 全选 · Ctrl-D 全不选" \
            --bind 'start:select-all' \
            --bind 'ctrl-a:select-all' \
            --bind 'ctrl-d:deselect-all' \
            --preview 'echo {} | cut -f2- | sed "s/^#[ ]*//;s/^$/(无说明)/"' \
            --preview-window=down:2:wrap \
            --color="fg:#cdd6f4,bg:-1,hl:#f9e2af,fg+:#cdd6f4,bg+:#313244,hl+:#f9e2af" \
            --color="info:#89b4fa,prompt:#cba6f7,pointer:#cba6f7,marker:#a6e3a1,spinner:#94e2d5" \
            --color="header:#94e2d5,border:#cba6f7,label:#f5c2e7" \
            --pointer="❯" \
            --marker="✓" \
            --height=80%
    ); then
        :
    else
        warn "用户取消，跳过软件安装"
        exit 0
    fi
    [[ -z "$selected" ]] && { warn "未选择任何软件，跳过"; exit 0; }
fi

# ---- 解析：flatpak: 前缀走 flatpak，其余走 dnf ----
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

# ---- dnf 逐包安装（用 00-utils.sh 的 dnf_install，自带 [N/M] 进度 + 实时反馈）----
if [[ ${#DNF_APPS[@]} -gt 0 ]]; then
    XF_FAILED_PKGS_BEFORE="${XF_FAILED_PKGS:-}"
    dnf_install "${DNF_APPS[@]}" || true
    NEW_FAIL="${XF_FAILED_PKGS#"$XF_FAILED_PKGS_BEFORE"}"
    for p in $NEW_FAIL; do
        [[ -n "$p" ]] && FAILED+=("dnf:$p")
    done
fi

# ---- flatpak 逐个 ----
if [[ ${#FLATPAK_APPS[@]} -gt 0 ]]; then
    log "flatpak 安装 ${#FLATPAK_APPS[@]} 个"
    fp_total=${#FLATPAK_APPS[@]} fp_idx=0
    for app in "${FLATPAK_APPS[@]}"; do
        fp_idx=$((fp_idx + 1))
        if flatpak info "$app" >/dev/null 2>&1; then
            printf "    ${C3}[%d/%d]${NC} ${DOT} ${DIM}%s (已装)${NC}\n" "$fp_idx" "$fp_total" "$app"
            continue
        fi
        printf "    ${C3}[%d/%d]${NC} ${DIM}%s${NC}\r" "$fp_idx" "$fp_total" "$app"
        if flatpak install -y --noninteractive flathub "$app" </dev/null >>"$XF_LOG_FILE" 2>&1; then
            printf "    ${C3}[%d/%d]${NC} ${TICK} %-40s\n" "$fp_idx" "$fp_total" "$app"
        else
            printf "    ${C3}[%d/%d]${NC} ${CROSS} %-40s ${DIM}(见日志)${NC}\n" "$fp_idx" "$fp_total" "$app"
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
