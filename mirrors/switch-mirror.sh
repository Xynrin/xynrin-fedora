#!/usr/bin/env bash
# Switch Fedora dnf mirrors between official / TUNA / USTC / Aliyun.
# Safe: backs up /etc/yum.repos.d/ before edits, idempotent, reversible.

set -euo pipefail

MIRROR="${1:-}"
DIR=/etc/yum.repos.d
BACKUP="$DIR/.mirror-backup"

usage() {
    cat <<EOF
Usage: $0 <mirror>

Mirrors:
  tuna      Tsinghua (mirrors.tuna.tsinghua.edu.cn)
  ustc      USTC    (mirrors.ustc.edu.cn)
  aliyun    Aliyun  (mirrors.aliyun.com)
  official  Revert to Fedora metalink

First run creates a backup at $BACKUP. Safe to re-run.
EOF
}

[[ -z "$MIRROR" || "$MIRROR" == "-h" || "$MIRROR" == "--help" ]] && { usage; exit 0; }

case "$MIRROR" in
    tuna)     HOST="mirrors.tuna.tsinghua.edu.cn" ;;
    ustc)     HOST="mirrors.ustc.edu.cn" ;;
    aliyun)   HOST="mirrors.aliyun.com" ;;
    official) HOST="" ;;
    *) usage; exit 2 ;;
esac

# Require root
if [[ $EUID -ne 0 ]]; then
    exec sudo -E "$0" "$@"
fi

# One-time backup of pristine repos
if [[ ! -d "$BACKUP" ]]; then
    mkdir -p "$BACKUP"
    cp -a "$DIR"/*.repo "$BACKUP/"
    echo "backed up original repos -> $BACKUP"
fi

edit_repos() {
    # Replace metalink= / mirrorlist= with a baseurl= pointing at $HOST for
    # the Fedora & RPM Fusion repos. Leave third-party repos (vscode, charm,
    # etc) untouched since they host on their own CDN.
    local target_host="$1"
    for f in "$DIR"/fedora*.repo "$DIR"/rpmfusion-*.repo; do
        [[ -f "$f" ]] || continue
        # Skip if already pointing at this host
        if grep -q "baseurl=https://$target_host/" "$f" 2>/dev/null; then
            continue
        fi

        # fedora.repo & fedora-updates.repo etc: swap metalink for baseurl
        # Map fedora repo path: mirrors.*/fedora/releases/$releasever/...
        # RPM Fusion path: mirrors.*/rpmfusion/free|nonfree/fedora/...

        case "$(basename "$f")" in
            fedora.repo|fedora-updates.repo|fedora-updates-testing.repo)
                sed -i \
                    -e 's|^metalink=|#metalink=|' \
                    -e 's|^#\?baseurl=http[s]*://[^/]*|baseurl=https://'"$target_host"'|' \
                    "$f"
                # If no baseurl line exists yet, add one derived from repo id
                ;;
            rpmfusion-*.repo)
                sed -i \
                    -e 's|^metalink=|#metalink=|' \
                    -e 's|^mirrorlist=|#mirrorlist=|' \
                    -e 's|^#\?baseurl=http[s]*://download1\.rpmfusion\.org|baseurl=https://'"$target_host"'/rpmfusion|' \
                    -e 's|^#\?baseurl=http[s]*://[^/]*/rpmfusion|baseurl=https://'"$target_host"'/rpmfusion|' \
                    "$f"
                ;;
        esac
    done
}

restore_official() {
    rm -f "$DIR"/fedora*.repo "$DIR"/rpmfusion-*.repo
    cp -a "$BACKUP"/fedora*.repo "$BACKUP"/rpmfusion-*.repo "$DIR/" 2>/dev/null || true
    echo "restored official repos from backup"
}

if [[ "$MIRROR" == "official" ]]; then
    restore_official
else
    # Ensure we have a clean base to work from; start each time from backup
    # (so switching mirrors doesn't accumulate sed damage)
    cp -a "$BACKUP"/fedora*.repo "$BACKUP"/rpmfusion-*.repo "$DIR/" 2>/dev/null || true
    edit_repos "$HOST"
    echo "switched fedora + rpmfusion mirrors -> $HOST"
fi

echo
echo "refreshing dnf cache..."
dnf makecache --refresh >/dev/null 2>&1 && echo "ok" || echo "warning: makecache had issues, check 'dnf repolist'"
