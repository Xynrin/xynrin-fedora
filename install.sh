#!/usr/bin/env bash
# install.sh — xynrin-fedora 主入口

set -uo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SETUP_DIR/scripts"
export SETUP_DIR SCRIPTS_DIR
export DRY_RUN=0
ONLY=""

# shellcheck source=scripts/00-utils.sh
source "$SCRIPTS_DIR/00-utils.sh"

usage() {
    cat <<EOF
用法: $0 [--only STEP[,STEP...]] [--dry-run] [--all]

可选模块（默认弹 FZF 菜单多选）:
  kde-theme   KDE 视觉主题（Breeze Dark / Papirus 图标 / 壁纸 / GTK 跟随）
  fonts-cjk   中文字体 + fcitx5 拼音
  terminal    fish + starship + eza/bat/zoxide/fzf/fastfetch
  apps        常用软件（浏览器 / 音视频 / 办公 / 通讯）
  gpu         显卡驱动（自动识别 NVIDIA / AMD / Intel）

说明:
  * repos 模块（RPM Fusion + Flathub）始终执行，是前置。
  * cleanup 模块（隐藏无用图标）最后自动跑。
  * --all       跳过菜单，全量执行（也跳过 confirm 提示）
  * --only X    跳过菜单，只跑 X（可逗号分隔多个）
  * --dry-run   只打印要执行的命令，不真动

环境变量:
  XF_DOTFILES_FORCE=0   保留宿主机已有 dotfiles（默认 1，强刷+备份）
  XF_BACKUP_DIR         dotfiles 备份目录（默认 ~/.config/.xynrin-backup）
  XF_SKIP_CN_MIRROR=1   跳过 TUNA 镜像切换
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --only)    [[ $# -lt 2 ]] && { error "--only 需要一个值"; usage; exit 2; }
                   ONLY="$2"; shift 2 ;;
        --all)     ONLY="ALL"; export XF_NONINTERACTIVE=1; shift ;;
        --dry-run) export DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *)         error "未知参数: $1"; usage; exit 2 ;;
    esac
done

if [[ $EUID -eq 0 ]]; then
    error "请以普通用户运行（脚本内部会按需 sudo）"
    exit 1
fi
xf_is_fedora || { error "仅支持 Fedora"; exit 1; }
command -v fzf >/dev/null 2>&1 || { error "缺少 fzf，请先 sudo dnf install -y fzf"; exit 1; }

detect_target_user

# ===== Banner =====
show_banner() {
    clear
    echo ""
    echo -e "${C1}    ╭───────────────────────────────────────────────────────╮${NC}"
    echo -e "${C1}    │${NC}                                                       ${C1}│${NC}"
    echo -e "${C1}    │${NC}     ${C2}╳${C3}╳ ${BOLD}xynrin-fedora${NC}                                ${C1}│${NC}"
    echo -e "${C1}    │${NC}     ${DIM}Fedora KDE 一键美化 · fish / starship / cjk${NC}      ${C1}│${NC}"
    echo -e "${C1}    │${NC}                                                       ${C1}│${NC}"
    echo -e "${C1}    ╰───────────────────────────────────────────────────────╯${NC}"
    echo ""
}

# ===== 模块定义 =====
MODULES=(
    "kde-theme|20-kde-theme.sh|KDE 视觉主题|Breeze Dark · Papirus · GTK 跟随"
    "fonts-cjk|30-fonts-cjk.sh|中文字体+输入法|Noto CJK + fcitx5 拼音"
    "terminal|40-terminal.sh|终端美化|fish + starship + 现代 CLI"
    "apps|50-apps.sh|常用软件|浏览器/音视频/办公/通讯"
    "gpu|60-gpu.sh|显卡驱动|NVIDIA / AMD / Intel 自动"
)
MANDATORY_PRE="10-repos.sh"
MANDATORY_POST="90-cleanup.sh"

select_modules_via_fzf() {
    local items=()
    for m in "${MODULES[@]}"; do
        local id="${m%%|*}" rest="${m#*|}"
        local script="${rest%%|*}"; rest="${rest#*|}"
        local title="${rest%%|*}"; rest="${rest#*|}"
        local desc="$rest"
        items+=("$(printf '%-22s %s\t%s\t%s' "$title" "[$id]" "$id" "$desc")")
    done

    local out
    out=$(printf '%s\n' "${items[@]}" | fzf \
        --multi \
        --delimiter=$'\t' \
        --with-nth=1 \
        --layout=reverse \
        --border=rounded \
        --border-label="  选择要执行的模块  " \
        --border-label-pos=3 \
        --header="TAB 切换 / Ctrl-A 全选 / Enter 确认" \
        --bind 'load:select-all,ctrl-a:select-all,ctrl-d:deselect-all' \
        --preview 'echo {} | cut -f3' \
        --preview-window=down:2:wrap \
        --color="fg:#cdd6f4,bg:-1,hl:#f9e2af,fg+:#cdd6f4,bg+:#313244,hl+:#f9e2af" \
        --color="info:#89b4fa,prompt:#cba6f7,pointer:#cba6f7,marker:#a6e3a1,spinner:#94e2d5" \
        --color="header:#94e2d5,border:#cba6f7,label:#f5c2e7" \
        --pointer="❯" \
        --marker="✓" \
        --height=60%) || return 1

    [[ -z "$out" ]] && return 1
    awk -F'\t' '{print $2}' <<< "$out" | tr '\n' ',' | sed 's/,$//'
}

resolve_modules() {
    local picked=""
    if [[ "$ONLY" == "ALL" ]]; then
        for m in "${MODULES[@]}"; do picked+="${m%%|*} "; done
    elif [[ -n "$ONLY" ]]; then
        picked="${ONLY//,/ }"
    else
        local raw
        raw=$(select_modules_via_fzf) || { error "取消"; exit 130; }
        picked="${raw//,/ }"
    fi
    echo "$picked"
}

run_script() {
    local script="$1"
    local path="$SCRIPTS_DIR/$script"
    [[ -f "$path" ]] || { warn "模块脚本不存在: $script"; return 0; }
    bash "$path"
}

# ===== 执行 =====
show_banner
[[ $DRY_RUN -eq 1 ]] && warn "DRY-RUN 模式：仅预览不真动"

info_kv "目标用户" "$TARGET_USER" "($HOME_DIR)"
info_kv "Fedora" "$(xf_fedora_version)" "$XF_DNF"
info_kv "日志" "$XF_LOG_FILE"
info_kv "备份" "$HOME_DIR/.config/.xynrin-backup"

picked=$(resolve_modules)
picked_trim=$(echo "$picked" | xargs)
[[ -z "$picked_trim" ]] && { warn "未选择任何模块，退出"; exit 0; }

info_kv "已选模块" "$picked_trim"

SUDO_KEEPALIVE_PID=""
cleanup() {
    [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap cleanup EXIT

if [[ $DRY_RUN -eq 0 ]]; then
    log "申请 sudo 权限（之后后台续期，全程不再问密码）"
    sudo -v || { error "sudo 不可用"; exit 1; }
    ( while true; do sudo -n true 2>/dev/null || exit; sleep 50; done ) &
    SUDO_KEEPALIVE_PID=$!
fi

# 计算总步数
total=2  # repos + cleanup 是默认步骤
for m in "${MODULES[@]}"; do
    mod_id="${m%%|*}"
    [[ " $picked_trim " == *" $mod_id "* ]] && total=$((total + 1))
done
current=0

# 前置：软件源
current=$((current + 1))
step "$current" "$total" "软件源（RPM Fusion + Flathub）"
run_script "$MANDATORY_PRE" || { error "前置失败，终止"; exit 1; }
step_end

# 国内镜像（自动检测，非 CN 时区直接跳）
run_script "15-cn-mirror.sh" || warn "镜像切换异常，继续使用默认"

# 模块（按定义顺序）
for m in "${MODULES[@]}"; do
    mod_id="${m%%|*}"
    rest="${m#*|}"
    script="${rest%%|*}"
    rest="${rest#*|}"
    title="${rest%%|*}"

    if [[ " $picked_trim " == *" $mod_id "* ]]; then
        current=$((current + 1))
        step "$current" "$total" "$title"
        run_script "$script" || warn "模块 $mod_id 异常，继续下一个"
        step_end
    fi
done

# 收尾
current=$((current + 1))
step "$current" "$total" "收尾"
run_script "$MANDATORY_POST" || true
step_end

echo ""
echo -e "${C4}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${TICK} ${BOLD}${H_GREEN}xynrin-fedora 安装完成${NC}"
echo -e "${C4}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
dim "日志：$XF_LOG_FILE"
dim "备份：$HOME_DIR/.config/.xynrin-backup"
[[ -n "${XF_FAILED_PKGS:-}" ]] && warn "未装上的包：${XF_FAILED_PKGS}"
log "字体 / 输入法 / shell / 主题需要 ${BOLD}注销重登${NC} 或重启才完全生效"
echo ""
