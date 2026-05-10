#!/usr/bin/env bash
# install.sh — xynrin-fedora 主入口
# FZF 菜单选模块 → 依次执行

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
  kde-theme   KDE 视觉主题（Breeze Dark / Papirus 图标 / 壁纸）
  fonts-cjk   中文字体 + fcitx5 拼音
  terminal    fish + starship + eza/bat/zoxide/fzf/fastfetch
  apps        常用软件（浏览器 / 音视频 / 办公 / 通讯）

说明:
  * repos 模块（RPM Fusion + Flathub）始终执行，是前置。
  * cleanup 模块（隐藏无用图标）最后自动跑。
  * --all       跳过菜单，全量执行
  * --only X    跳过菜单，只跑 X（可逗号分隔多个）
  * --dry-run   只打印要执行的命令，不真动
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --only)    [[ $# -lt 2 ]] && { error "--only 需要一个值"; usage; exit 2; }
                   ONLY="$2"; shift 2 ;;
        --all)     ONLY="ALL"; shift ;;
        --dry-run) export DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *)         error "未知参数: $1"; usage; exit 2 ;;
    esac
done

# 环境前置检查
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
    printf "${H_PURPLE}${BOLD}"
    cat <<'BANNER'

   __  __ __   __ _  _ ___  ___ _  _     ___ ___ ___   ___  ___    _
   \ \/ / \ \ / / \| | _ \|_ _| \| |   | __| __|   \ / _ \| _ \  /_\
    >  <   \ V /| .` |   / | || .` |   | _|| _|| |) | (_) |   / / _ \
   /_/\_\   |_| |_|\_|_|_\|___|_|\_|   |_| |___|___/ \___/|_|_\/_/ \_\

BANNER
    printf "${NC}"
    printf "${H_GRAY}   Fedora KDE 一键美化 — 新机从零到好看好用${NC}\n\n"
}

# ===== 模块定义 =====
# 格式: <ID>|<脚本>|<中文标题>|<描述>
MODULES=(
    "kde-theme|20-kde-theme.sh|KDE 视觉主题|深色 Breeze + Papirus 图标 + 壁纸"
    "fonts-cjk|30-fonts-cjk.sh|中文字体+输入法|思源/Noto + fcitx5 拼音"
    "terminal|40-terminal.sh|终端美化|fish + starship + 现代 CLI"
    "apps|50-apps.sh|常用软件|浏览器/音视频/办公/通讯 FZF 选装"
)
MANDATORY_PRE="10-repos.sh"
MANDATORY_POST="90-cleanup.sh"

# ===== 选模块 =====
select_modules_via_fzf() {
    local items=()
    for m in "${MODULES[@]}"; do
        local id="${m%%|*}" rest="${m#*|}"
        local script="${rest%%|*}"; rest="${rest#*|}"
        local title="${rest%%|*}"; rest="${rest#*|}"
        local desc="$rest"
        items+=("$(printf '%-14s %s\t%s\t%s' "$title" "[$id]" "$id" "$desc")")
    done

    local out
    out=$(printf '%s\n' "${items[@]}" | fzf \
        --multi \
        --delimiter=$'\t' \
        --with-nth=1 \
        --layout=reverse \
        --border=rounded \
        --border-label="  选择要执行的模块 (TAB 切换 / Enter 确认 / Ctrl-A 全选)  " \
        --border-label-pos=5 \
        --header="默认全选 · TAB 切换勾选 · Enter 开始安装" \
        --bind 'load:select-all,ctrl-a:select-all,ctrl-d:deselect-all' \
        --preview 'echo {} | cut -f3' \
        --preview-window=down:3:wrap \
        --color="marker:cyan,pointer:cyan,label:yellow" \
        --pointer=">" \
        --height=50%) || return 1

    [[ -z "$out" ]] && return 1
    awk -F'\t' '{print $2}' <<< "$out" | tr '\n' ',' | sed 's/,$//'
}

# 解析 ONLY / 菜单，输出要跑的模块 ID（空格分隔）
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
[[ $DRY_RUN -eq 1 ]] && warn "DRY-RUN 模式，不真动"

log "目标用户: $TARGET_USER ($HOME_DIR)"
log "日志: $XF_LOG_FILE"

picked=$(resolve_modules)
picked_trim=$(echo "$picked" | xargs)
[[ -z "$picked_trim" ]] && { warn "未选择任何模块，退出"; exit 0; }

info_kv "已选模块" "$picked_trim"

# 提升权限（若非 dry-run）
SUDO_KEEPALIVE_PID=""
cleanup() {
    [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap cleanup EXIT

if [[ $DRY_RUN -eq 0 ]]; then
    log "即将申请一次 sudo 权限（之后后台续期，全程不再问密码）"
    sudo -v || { error "sudo 不可用"; exit 1; }
    ( while true; do sudo -n true 2>/dev/null || exit; sleep 50; done ) &
    SUDO_KEEPALIVE_PID=$!
fi

# 前置必跑
section "前置" "配置软件源（RPM Fusion + Flathub）"
run_script "$MANDATORY_PRE" || { error "前置失败，终止"; exit 1; }

# 执行所选模块（按定义顺序）
for m in "${MODULES[@]}"; do
    mod_id="${m%%|*}"
    rest="${m#*|}"
    script="${rest%%|*}"
    rest="${rest#*|}"
    title="${rest%%|*}"

    if [[ " $picked_trim " == *" $mod_id "* ]]; then
        section "$title" "$script"
        run_script "$script" || warn "模块 $mod_id 执行异常，继续下一个"
    fi
done

# 收尾
section "收尾" "清理 + 提示"
run_script "$MANDATORY_POST" || true

echo ""
echo -e "${H_GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${H_GREEN}║              xynrin-fedora 安装完成                  ║${NC}"
echo -e "${H_GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
dim "日志已存到 $XF_LOG_FILE"
log "部分改动（字体/输入法/shell/主题）需要注销重登或重启才完全生效"
