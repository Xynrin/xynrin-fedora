#!/usr/bin/env bash
# 所有 install-*.sh 共享的通用函数。通过 install.sh source，不应直接执行。

# 防止被直接 bash 运行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "common.sh 不应直接执行，应由 install.sh source"
    exit 1
fi

# ===== 颜色 / 日志 =====
c_reset='\033[0m';  c_blue='\033[0;34m';  c_green='\033[0;32m'
c_yellow='\033[1;33m'; c_red='\033[0;31m'; c_gray='\033[0;90m'
c_cyan='\033[0;36m'; c_mag='\033[0;35m';  c_bold='\033[1m'

log()  { printf "${c_blue}==>${c_reset} ${c_bold}%s${c_reset}\n" "$*"; }
ok()   { printf "${c_green}  ✓${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}  !${c_reset} %s\n" "$*"; }
err()  { printf "${c_red}  ✗${c_reset} %s\n" "$*" >&2; }
dim()  { printf "${c_gray}    %s${c_reset}\n" "$*"; }

run() {
    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        dim "DRY: $*"
    else
        "$@"
    fi
}

# ===== 工具函数 =====
read_list() {
    grep -vE '^\s*(#|$)' "$1" 2>/dev/null || true
}

link_into() {
    local src="$1" dst="$2"
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        return 0
    fi
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        local backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
        warn "备份已存在文件 $dst -> $backup"
        run mv "$dst" "$backup"
    elif [[ -L "$dst" ]]; then
        run rm "$dst"
    fi
    run mkdir -p "$(dirname "$dst")"
    run ln -s "$src" "$dst"
    ok "linked $(basename "$dst")"
}

# install.sh 在入口就 sudo -v 过一次，保持后台续期；这里只兜底
need_sudo() {
    if [[ ${DRY_RUN:-0} -eq 1 ]]; then return 0; fi
    sudo -n true 2>/dev/null && return 0
    warn "sudo 凭据已过期，可能需要重新输入密码"
    sudo -v
}
