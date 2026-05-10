#!/usr/bin/env bash
# ~/fedora-setup/install.sh
# Idempotent Fedora setup. Re-runnable. Supports --only <step> and --dry-run.

set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
ONLY=""

# ===== logging =====
c_reset='\033[0m'; c_blue='\033[0;34m'; c_green='\033[0;32m'
c_yellow='\033[1;33m'; c_red='\033[0;31m'; c_gray='\033[0;90m'
log()  { printf "${c_blue}==>${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}  ✓${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}  !${c_reset} %s\n" "$*"; }
err()  { printf "${c_red}  ✗${c_reset} %s\n" "$*" >&2; }
dim()  { printf "${c_gray}    %s${c_reset}\n" "$*"; }

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        dim "DRY: $*"
    else
        "$@"
    fi
}

usage() {
    cat <<EOF
Usage: $0 [--only STEP] [--dry-run]

Steps (run in this order when no --only):
  mirrors   Switch dnf to fast mirror per mirrors/preferred.txt (requires sudo)
  repos     Enable RPM Fusion + copy .repo files + enable COPR (requires sudo)
  dnf       Install packages from packages/dnf.txt (requires sudo)
  flatpak   Install flatpaks from packages/flatpak.txt (if any)
  fish      Symlink config.fish / functions / conf.d / fish_plugins, apply universal_vars.fish
  fisher    Install fisher + plugins from fish_plugins
  vscode    Symlink vscode/settings.json and install extensions
  node      Ensure nvm + LTS + global npm packages
  systemd   Enable services from systemd/{system,user}.txt
  scripts   Symlink scripts/*.sh into ~/.local/bin (dir auto-created)

Examples:
  $0                  # full run (fresh machine)
  $0 --only fish
  $0 --only dnf --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --only)
            [[ $# -lt 2 ]] && { err "--only needs a value"; usage; exit 2; }
            ONLY="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) err "unknown arg: $1"; usage; exit 2 ;;
    esac
done

should_run() { [[ -z "$ONLY" || "$ONLY" == "$1" ]]; }

# ===== helpers =====
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
        warn "backup existing $dst -> $backup"
        run mv "$dst" "$backup"
    elif [[ -L "$dst" ]]; then
        run rm "$dst"
    fi
    run mkdir -p "$(dirname "$dst")"
    run ln -s "$src" "$dst"
    ok "linked $(basename "$dst")"
}

need_sudo() {
    if ! sudo -n true 2>/dev/null; then
        warn "this step needs sudo; you may be prompted"
        if [[ $DRY_RUN -eq 0 ]]; then
            sudo -v || { err "sudo unavailable"; return 1; }
        fi
    fi
}

# ===== steps =====

step_mirrors() {
    log "dnf mirror"
    local pref_file="$SETUP_DIR/mirrors/preferred.txt"
    if [[ ! -f "$pref_file" ]]; then
        dim "no mirrors/preferred.txt, skipping"
        return 0
    fi
    local mirror
    mirror=$(read_list "$pref_file" | head -1 | tr -d '[:space:]')
    if [[ -z "$mirror" || "$mirror" == "official" ]]; then
        dim "mirror preference empty or 'official', skipping"
        return 0
    fi
    need_sudo || return 1
    run sudo "$SETUP_DIR/mirrors/switch-mirror.sh" "$mirror"
}

step_repos() {
    log "dnf repos (rpmfusion + third-party + copr)"
    need_sudo || return 1

    local fedver
    fedver=$(rpm -E %fedora)
    if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
        run sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedver}.noarch.rpm"
    else
        dim "rpmfusion-free already enabled"
    fi
    if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
        run sudo dnf install -y \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedver}.noarch.rpm"
    else
        dim "rpmfusion-nonfree already enabled"
    fi

    shopt -s nullglob
    for r in "$SETUP_DIR/repos"/*.repo; do
        local dst="/etc/yum.repos.d/$(basename "$r")"
        if [[ -f "$dst" ]] && cmp -s "$r" "$dst"; then
            dim "already in place: $(basename "$r")"
        else
            run sudo install -m 644 "$r" "$dst"
            ok "installed $(basename "$r")"
        fi
    done
    shopt -u nullglob

    if [[ -f "$SETUP_DIR/repos/copr.txt" ]]; then
        local enabled
        enabled=$(ls /etc/yum.repos.d/_copr*.repo 2>/dev/null | \
            sed -E 's|.*_copr:copr\.fedorainfracloud\.org:([^:]+):([^.]+)\.repo|\1/\2|' || true)
        while read -r copr; do
            [[ -z "$copr" ]] && continue
            if grep -qxF "$copr" <<< "$enabled"; then
                dim "copr already enabled: $copr"
            else
                run sudo dnf copr enable -y "$copr"
            fi
        done < <(read_list "$SETUP_DIR/repos/copr.txt")
    fi
}

step_dnf() {
    log "dnf packages"
    need_sudo || return 1
    local pkgs
    pkgs=$(read_list "$SETUP_DIR/packages/dnf.txt")
    if [[ -z "$pkgs" ]]; then
        warn "no packages in packages/dnf.txt"
        return 0
    fi
    local missing=()
    while read -r pkg; do
        [[ -z "$pkg" ]] && continue
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done <<< "$pkgs"
    if [[ ${#missing[@]} -eq 0 ]]; then
        ok "all dnf packages already installed"
        return 0
    fi
    dim "installing: ${missing[*]}"
    run sudo dnf install -y "${missing[@]}"
}

step_flatpak() {
    log "flatpak apps"
    if ! command -v flatpak >/dev/null; then
        warn "flatpak not installed, skipping"
        return 0
    fi
    if ! flatpak remotes --columns=name 2>/dev/null | grep -qx flathub; then
        run flatpak remote-add --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo
    fi
    local apps
    apps=$(read_list "$SETUP_DIR/packages/flatpak.txt")
    if [[ -z "$apps" ]]; then
        dim "no flatpak ids listed, skipping"
        return 0
    fi
    while read -r id; do
        [[ -z "$id" ]] && continue
        if flatpak info "$id" >/dev/null 2>&1; then
            dim "already installed: $id"
        else
            run flatpak install -y --noninteractive flathub "$id"
        fi
    done <<< "$apps"
}

step_fish() {
    log "fish config, functions, conf.d, plugins"
    if ! command -v fish >/dev/null; then
        err "fish not installed; run --only dnf first"
        return 1
    fi
    local dst_fns="$HOME/.config/fish/functions"
    local dst_conf="$HOME/.config/fish/conf.d"
    run mkdir -p "$dst_fns" "$dst_conf"

    # Top-level files
    for f in config.fish fish_plugins; do
        if [[ -f "$SETUP_DIR/fish/$f" ]]; then
            link_into "$SETUP_DIR/fish/$f" "$HOME/.config/fish/$f"
        fi
    done

    # Functions & conf.d
    shopt -s nullglob
    for f in "$SETUP_DIR/fish/functions"/*.fish; do
        link_into "$f" "$dst_fns/$(basename "$f")"
    done
    for f in "$SETUP_DIR/fish/conf.d"/*.fish; do
        link_into "$f" "$dst_conf/$(basename "$f")"
    done
    shopt -u nullglob

    # Apply universal vars (tide colors, fish_color_*, etc.)
    if [[ -f "$SETUP_DIR/fish/universal_vars.fish" ]]; then
        if [[ $DRY_RUN -eq 0 ]]; then
            fish "$SETUP_DIR/fish/universal_vars.fish" \
                && ok "applied universal_vars.fish" \
                || warn "universal_vars.fish had errors"
        else
            dim "DRY: fish $SETUP_DIR/fish/universal_vars.fish"
        fi
    fi
}

step_fisher() {
    log "fisher plugins"
    if ! command -v fish >/dev/null; then
        err "fish not installed"
        return 1
    fi
    local plugins_file="$SETUP_DIR/fish/fish_plugins"
    [[ ! -f "$plugins_file" ]] && { warn "no fish_plugins"; return 0; }

    if ! fish -c "functions -q fisher" 2>/dev/null; then
        log "bootstrapping fisher"
        run fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
    fi

    local plugins
    plugins=$(read_list "$plugins_file" | xargs echo)
    [[ -z "$plugins" ]] && { dim "no plugins listed"; return 0; }

    local have missing=""
    have=$(fish -c 'string join \n $_fisher_plugins' 2>/dev/null \
        | sed 's/@.*//' | tr '[:upper:]' '[:lower:]')
    for p in $plugins; do
        local key="${p%@*}"
        key=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        if ! grep -qxF "$key" <<< "$have"; then
            missing+=" $p"
        fi
    done
    if [[ -z "${missing// /}" ]]; then
        ok "all fisher plugins already installed"
        return 0
    fi
    dim "missing:$missing"
    # shellcheck disable=SC2086
    run fish -c "fisher install$missing"
}

step_vscode() {
    log "vscode"
    if ! command -v code >/dev/null; then
        warn "code not on PATH, skipping vscode"
        return 0
    fi
    link_into "$SETUP_DIR/vscode/settings.json" "$HOME/.config/Code/User/settings.json"

    local exts
    exts=$(read_list "$SETUP_DIR/vscode/extensions.txt")
    [[ -z "$exts" ]] && { dim "no extensions listed"; return 0; }

    local installed
    installed=$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')
    while read -r ext; do
        [[ -z "$ext" ]] && continue
        if grep -qxF "$(echo "$ext" | tr '[:upper:]' '[:lower:]')" <<< "$installed"; then
            dim "already installed: $ext"
        else
            run code --install-extension "$ext"
        fi
    done <<< "$exts"
}

step_node() {
    log "node / nvm.fish"
    if ! command -v fish >/dev/null; then
        err "fish not installed"
        return 1
    fi
    if ! fish -c "functions -q nvm" 2>/dev/null; then
        warn "nvm.fish not installed; run --only fisher first"
        return 1
    fi

    local current
    current=$(fish -c 'nvm current 2>/dev/null' || echo "")
    if [[ -z "$current" || "$current" == "none" || "$current" == "system" ]]; then
        run fish -c "nvm install lts"
    else
        dim "node already active: $current"
    fi

    local pkgs_file="$SETUP_DIR/node/npm-globals.txt"
    [[ ! -f "$pkgs_file" ]] && return 0

    local pkgs
    pkgs=$(read_list "$pkgs_file")
    [[ -z "$pkgs" ]] && { dim "no npm globals listed"; return 0; }

    local installed
    installed=$(fish -c 'npm ls -g --depth=0 --parseable 2>/dev/null' | \
        sed -E 's|.*/node_modules/||' | sort -u)
    while read -r p; do
        [[ -z "$p" ]] && continue
        if grep -qxF "$p" <<< "$installed"; then
            dim "already installed: $p"
        else
            run fish -c "npm install -g '$p'"
        fi
    done <<< "$pkgs"
}

step_systemd() {
    log "systemd services"
    need_sudo || return 1

    if [[ -f "$SETUP_DIR/systemd/system.txt" ]]; then
        while read -r svc; do
            [[ -z "$svc" ]] && continue
            if systemctl is-enabled "$svc" >/dev/null 2>&1; then
                dim "already enabled: $svc"
            else
                run sudo systemctl enable --now "$svc"
            fi
        done < <(read_list "$SETUP_DIR/systemd/system.txt")
    fi

    if [[ -f "$SETUP_DIR/systemd/user.txt" ]]; then
        while read -r svc; do
            [[ -z "$svc" ]] && continue
            if systemctl --user is-enabled "$svc" >/dev/null 2>&1; then
                dim "already enabled (user): $svc"
            else
                run systemctl --user enable --now "$svc"
            fi
        done < <(read_list "$SETUP_DIR/systemd/user.txt")
    fi
}

step_scripts() {
    log "scripts -> ~/.local/bin"
    local bindir="$HOME/.local/bin"
    run mkdir -p "$bindir"
    shopt -s nullglob
    for s in "$SETUP_DIR/scripts"/*.sh; do
        local name
        name=$(basename "$s" .sh)
        run chmod +x "$s"
        link_into "$s" "$bindir/$name"
    done
    shopt -u nullglob
}

# ===== dispatch =====
steps=(mirrors repos dnf flatpak fish fisher vscode node systemd scripts)

if [[ -n "$ONLY" ]] && ! printf '%s\n' "${steps[@]}" | grep -qx "$ONLY"; then
    err "unknown --only value: $ONLY"
    usage
    exit 2
fi

log "fedora-setup at $SETUP_DIR"
[[ $DRY_RUN -eq 1 ]] && warn "dry-run mode, no changes will be made"

for s in "${steps[@]}"; do
    if should_run "$s"; then
        "step_$s"
    fi
done

log "done"
