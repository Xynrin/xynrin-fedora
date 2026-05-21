#!/usr/bin/env bash
# install.sh — xynrin-fedora 主入口（严格 7 步流程）
#
# 1. 环境检查（Fedora 版本 + 网络）
# 2. 基础依赖（git/curl/wget/whiptail/fontconfig/fzf...）
# 3. KDE 美化（交互式选择 3 套主题方案）
# 4. Fish 安装与美化（fish + bobthefish + Nerd Fonts）
# 5. 便捷脚本部署（~/.local/bin/up + ~/.local/bin/xynrin）
# 6. TUI 主程序部署（xynrin 已在 5 中部署）
# 7. 收尾与提示

set -uo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SETUP_DIR/scripts"
export SETUP_DIR SCRIPTS_DIR
export DRY_RUN=0
ONLY=""

# 兼容 `curl ... | bash` 的"裸 install.sh"调用：发现自己不在仓库里，转发给 bootstrap
if [[ ! -f "$SCRIPTS_DIR/00-utils.sh" ]]; then
    echo "==> 检测到非仓库环境，自动回落 bootstrap 流程..."
    exec bash <(curl -fsSL "https://raw.githubusercontent.com/Xynrin/xynrin-fedora/main/bootstrap.sh") "$@"
fi

XF_VERSION="dev"
[[ -f "$SETUP_DIR/VERSION" ]] && XF_VERSION=$(<"$SETUP_DIR/VERSION")
export XF_VERSION

# shellcheck source=scripts/00-utils.sh
source "$SCRIPTS_DIR/00-utils.sh"

usage() {
    cat <<EOF
用法: $0 [--only STEP[,STEP...]] [--dry-run] [--all]

模块（默认按 7 步全量执行）:
  kde-theme   KDE 美化（3 套主题选 1）
  fonts-cjk   中文字体 + fcitx5 拼音
  terminal    fish + bobthefish + Nerd Fonts + ~/.local/bin
  apps        常用软件
  gpu         显卡驱动

  --all       跳过所有 confirm，全量执行
  --only X    只跑指定模块（逗号分隔）
  --dry-run   只预览不真动

环境变量:
  XF_DOTFILES_FORCE=0   保留宿主机已有 dotfiles（默认 1，强刷+备份）
  XF_BACKUP_DIR         备份目录（默认 ~/.config/.xynrin-backup）
  XF_SKIP_CN_MIRROR=1   跳过 TUNA 镜像切换
  XF_NONINTERACTIVE=1   非交互（CI 用）
  XF_AGREE=1            预先同意免责声明（自动化场景，不弹同意书）
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

# ========== 步骤 1：环境检查 ==========
if [[ $EUID -eq 0 ]]; then
    error "请以普通用户运行（脚本内部会按需 sudo）"
    exit 1
fi

if ! xf_is_fedora; then
    error "✗ 检测到非 Fedora 系统，本脚本仅支持 Fedora"
    error "  在线脚本到此终止"
    exit 1
fi

fedver=$(xf_fedora_version)
if [[ "$fedver" -lt 41 ]]; then
    warn "当前 Fedora $fedver，推荐 Fedora 44+，部分包名可能缺失"
    if [[ "${XF_NONINTERACTIVE:-0}" != "1" ]]; then
        read -r -p "$(echo -e "    ${C3}❯${NC} 继续? [y/N] ")" ans
        [[ "${ans:-N}" =~ ^[Yy]$ ]] || { echo "取消"; exit 0; }
    fi
elif [[ "$fedver" -ne 44 ]]; then
    dim "Fedora $fedver（项目以 Fedora 44 为基线，其它版本兼容）"
fi

# 网络检查
if ! curl -fsI --max-time 8 https://github.com >/dev/null 2>&1; then
    warn "GitHub 不可达，安装可能受影响"
    if [[ "${XF_NONINTERACTIVE:-0}" != "1" ]]; then
        read -r -p "$(echo -e "    ${C3}❯${NC} 继续? [y/N] ")" ans
        [[ "${ans:-N}" =~ ^[Yy]$ ]] || exit 1
    fi
fi

detect_target_user

# ===== Banner =====
show_banner() {
    clear
    echo ""
    echo -e "${C1}    ╭───────────────────────────────────────────────────────╮${NC}"
    echo -e "${C1}    │${NC}                                                       ${C1}│${NC}"
    echo -e "${C1}    │${NC}     ${C2}╳${C3}╳ ${BOLD}xynrin-fedora${NC} ${DIM}v${XF_VERSION}${NC}                          ${C1}│${NC}"
    echo -e "${C1}    │${NC}     ${DIM}Fedora 44 KDE 一键美化 · 小白友好${NC}             ${C1}│${NC}"
    echo -e "${C1}    │${NC}                                                       ${C1}│${NC}"
    echo -e "${C1}    ╰───────────────────────────────────────────────────────╯${NC}"
    echo ""
}

# ========== 步骤 2：基础依赖 ==========
install_base_deps() {
    log "安装基础依赖（git / curl / wget / fzf / whiptail / fontconfig）"
    local base_pkgs=(
        git curl wget tar unzip rsync
        fontconfig
        newt        # whiptail
        fzf
        pciutils
        ImageMagick # 用于横幅资源处理
    )
    dnf_install "${base_pkgs[@]}"
}

# ===== 模块定义 =====
MODULES=(
    "kde-theme|20-kde-theme.sh|KDE 美化|3 套主题方案选择"
    "fonts-cjk|30-fonts-cjk.sh|中文字体+输入法|Noto CJK + fcitx5 拼音"
    "terminal|40-terminal.sh|终端美化|fish + bobthefish + Nerd Fonts"
    "apps|50-apps.sh|常用软件|浏览器/音视频/办公"
    "gpu|60-gpu.sh|显卡驱动|NVIDIA / AMD / Intel"
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
        --multi --delimiter=$'\t' --with-nth=1 \
        --layout=reverse --border=rounded \
        --border-label="  选择要执行的模块  " --border-label-pos=3 \
        --info=inline-right \
        --prompt="搜索 ❯ " \
        --header="Enter 开始 · TAB 切换 · Ctrl-A 全选 · Ctrl-D 全不选" \
        --bind 'start:select-all' \
        --bind 'ctrl-a:select-all' \
        --bind 'ctrl-d:deselect-all' \
        --preview 'echo {} | cut -f3' \
        --preview-window=down:2:wrap \
        --color="fg:#cdd6f4,bg:-1,hl:#f9e2af,fg+:#cdd6f4,bg+:#313244,hl+:#f9e2af" \
        --color="info:#89b4fa,prompt:#cba6f7,pointer:#cba6f7,marker:#a6e3a1,spinner:#94e2d5" \
        --color="header:#94e2d5,border:#cba6f7,label:#f5c2e7" \
        --pointer="❯" --marker="✓" --height=60%) || return 1
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

# ===== 免责声明 =====
show_disclaimer() {
    # 非交互（CI / --all）跳过提示，但日志里仍留痕迹
    if [[ "${XF_NONINTERACTIVE:-0}" == "1" ]]; then
        _write_log DISCLAIMER "non-interactive mode: implicit acceptance"
        return 0
    fi

    # DRY-RUN 也不必弹（不会真动机器）
    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        return 0
    fi

    # 用户标记跳过（高级用户重复执行时设置）
    if [[ "${XF_AGREE:-0}" == "1" ]]; then
        _write_log DISCLAIMER "XF_AGREE=1: skipped"
        return 0
    fi

    echo ""
    echo -e "${C1}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${BOLD}${H_YELLOW}⚠  免责声明 / Disclaimer${NC}"
    echo -e "${C1}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  本脚本会对你的 Fedora 系统进行下列${BOLD}有写入和潜在破坏性${NC}的操作："
    echo ""
    echo -e "    ${C5}•${NC} 启用第三方软件源（${BOLD}RPM Fusion${NC} free / nonfree、${BOLD}Flathub${NC}）"
    echo -e "    ${C5}•${NC} 安装/替换系统包（mesa-freeworld、akmod-nvidia 等）"
    echo -e "    ${C5}•${NC} 写入 ${BOLD}~/.config/${NC}（KDE / fish / starship / fcitx5 / GTK 等）"
    echo -e "    ${C5}•${NC} 询问后修改默认 shell 为 ${BOLD}fish${NC}（chsh）"
    echo -e "    ${C5}•${NC} 下载 Nerd Fonts、KDE 主题等资源到 ${BOLD}~/.local/share/${NC}"
    echo -e "    ${C5}•${NC} 修改 SDDM 登录界面主题"
    echo -e "    ${C5}•${NC} 写 ${BOLD}~/.local/bin/${NC}（up / xynrin / xf-* 工具脚本）"
    echo ""
    echo -e "  ${BOLD}${H_GREEN}保护机制${NC}"
    echo -e "    ${TICK} 所有覆盖前自动备份到 ${DIM}~/.config/.xynrin-backup/${NC}"
    echo -e "    ${TICK} 默认 shell 切换会${BOLD}单独询问${NC}（默认 ${BOLD}Y${NC}，可拒绝）"
    echo -e "    ${TICK} 任何一步报错都会写日志：${DIM}$XF_LOG_FILE${NC}"
    echo -e "    ${TICK} 失败的软件清单：${DIM}~/Documents/xynrin-fedora-install-failed.txt${NC}"
    echo -e "    ${TICK} 美化卸载与备份还原内置在 TUI（${BOLD}xynrin${NC}）"
    echo ""
    echo -e "  ${BOLD}${H_RED}风险声明${NC}"
    echo -e "    ${CROSS} 本项目以 ${BOLD}GPL-v3${NC} 发布，按 ${BOLD}\"现状\"${NC} 提供，${BOLD}不附带任何明示或暗示的担保${NC}"
    echo -e "    ${CROSS} 作者不对因使用本脚本造成的${BOLD}数据丢失 / 系统不可启动 / 其他损失${NC}承担责任"
    echo -e "    ${CROSS} 在生产 / 工作机上运行前，请确保${BOLD}已备份重要数据${NC}"
    echo -e "    ${CROSS} 你须自行评估各步骤的影响，并对自己执行的操作负责"
    echo ""
    echo -e "  ${DIM}详细说明请阅读: https://github.com/Xynrin/xynrin-fedora/wiki${NC}"
    echo -e "${C1}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # 显式同意：必须输入 yes / y / 同意 才放行；其它一律视为拒绝
    local ans
    while true; do
        read -r -p "$(echo -e "  ${BOLD}${C3}❯${NC} 我已阅读并${BOLD}同意上述免责声明${NC}，继续安装? (输入 ${BOLD}yes${NC} 同意 / ${BOLD}no${NC} 取消): ")" ans
        case "${ans,,}" in
            yes|y|同意)
                _write_log DISCLAIMER "user accepted: $ans"
                echo -e "  ${TICK} ${H_GREEN}已同意，开始安装${NC}"
                echo ""
                return 0
                ;;
            no|n|不同意|"")
                _write_log DISCLAIMER "user declined: ${ans:-empty}"
                echo -e "  ${CROSS} ${H_YELLOW}已取消（未做任何修改）${NC}"
                exit 0
                ;;
            *)
                echo -e "  ${WARN_SYM} 请输入 ${BOLD}yes${NC} 或 ${BOLD}no${NC}"
                ;;
        esac
    done
}

# ===== 执行 =====
show_banner
show_disclaimer
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

# 计算总步数（基础依赖 + 软件源 + 选中模块 + 收尾）
total=3
for m in "${MODULES[@]}"; do
    mod_id="${m%%|*}"
    [[ " $picked_trim " == *" $mod_id "* ]] && total=$((total + 1))
done
current=0

# 步骤 2：基础依赖
current=$((current + 1))
step "$current" "$total" "基础依赖"
install_base_deps
step_end

# 前置：软件源（必跑）
current=$((current + 1))
step "$current" "$total" "软件源（RPM Fusion + Flathub）"
run_script "$MANDATORY_PRE" || { error "前置失败，终止"; exit 1; }
step_end

# 国内镜像（自动检测，非 CN 时区直接跳）
run_script "15-cn-mirror.sh" || warn "镜像切换异常，继续使用默认"

# 模块（按 MODULES 顺序：kde-theme → fonts-cjk → terminal → apps → gpu）
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

# ========== 步骤 7：完成提示 ==========
echo ""
echo -e "${C4}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${TICK} ${BOLD}${H_GREEN}xynrin-fedora 安装完成${NC}"
echo -e "${C4}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}下一步${NC}"
echo -e "    ${ARROW} 终端输入 ${BOLD}${C3}xynrin${NC} 打开 TUI 管理界面"
echo -e "    ${ARROW} 终端输入 ${BOLD}${C3}up${NC} 一键更新系统"
echo -e "    ${ARROW} ${DIM}注销重新登录（或 exec fish）让 fish + 字体生效${NC}"
echo ""
dim "日志：$XF_LOG_FILE"
dim "备份：$HOME_DIR/.config/.xynrin-backup"
[[ -n "${XF_FAILED_PKGS:-}" ]] && warn "未装上的包：${XF_FAILED_PKGS}"

# 二维码（手机扫码看 wiki）
qr_url="https://github.com/Xynrin/xynrin-fedora/wiki"
if command -v qrencode >/dev/null 2>&1; then
    echo ""
    echo -e "    ${DIM}手机扫码查看 wiki：${NC}"
    qrencode -t ANSIUTF8 "$qr_url" 2>/dev/null | sed 's/^/    /' || true
else
    echo -e "    ${DIM}wiki: $qr_url${NC}"
fi
echo ""
