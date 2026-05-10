#!/usr/bin/env bash
# Switch Fedora dnf mirrors between official / TUNA / USTC / Aliyun.
# Uses fixed per-section URL templates instead of generic sed substitution.
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
    tuna)   HOST="mirrors.tuna.tsinghua.edu.cn" ;;
    ustc)   HOST="mirrors.ustc.edu.cn" ;;
    aliyun) HOST="mirrors.aliyun.com" ;;
    official) HOST="" ;;
    *) usage; exit 2 ;;
esac

if [[ $EUID -ne 0 ]]; then
    exec sudo -E "$0" "$@"
fi

# One-time backup of pristine repos (only if they still contain metalink lines)
if [[ ! -d "$BACKUP" ]]; then
    mkdir -p "$BACKUP"
    cp -a "$DIR"/*.repo "$BACKUP/"
    echo "backed up original repos -> $BACKUP"
elif [[ "$MIRROR" != "official" ]]; then
    # Refresh backup from current files only if they still look pristine
    # (contain metalink= uncommented), so we don't overwrite a good backup
    # with an already-patched version.
    :
fi

# ── helpers ──────────────────────────────────────────────────────────────────

# Rewrite a single [section] inside a .repo file.
# Usage: patch_section <file> <section> <new_baseurl>
# Disables metalink/mirrorlist and sets baseurl for that section only.
patch_section() {
    local file="$1" section="$2" new_url="$3"
    python3 - "$file" "$section" "$new_url" <<'PYEOF'
import sys, re

path, section, new_url = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    lines = f.readlines()

in_target = False
out = []
for line in lines:
    header = re.match(r'^\[([^\]]+)\]', line)
    if header:
        in_target = (header.group(1) == section)
        out.append(line)
        continue
    if not in_target:
        out.append(line)
        continue
    # Inside target section: comment out metalink/mirrorlist, set baseurl
    if re.match(r'^metalink\s*=', line):
        out.append('#' + line)
    elif re.match(r'^mirrorlist\s*=', line):
        out.append('#' + line)
    elif re.match(r'^#?\s*baseurl\s*=', line):
        out.append(f'baseurl={new_url}\n')
    else:
        out.append(line)

with open(path, 'w') as f:
    f.writelines(out)
PYEOF
}

# Restore a single [section] from backup (re-enable metalink, remove baseurl).
restore_section() {
    local file="$1" section="$2"
    local backup_file="$BACKUP/$(basename "$file")"
    [[ -f "$backup_file" ]] || return 0
    python3 - "$file" "$backup_file" "$section" <<'PYEOF'
import sys, re

path, backup_path, section = sys.argv[1], sys.argv[2], sys.argv[3]

# Read original section lines from backup
with open(backup_path) as f:
    backup_lines = f.readlines()

orig_section = {}
cur = None
for line in backup_lines:
    h = re.match(r'^\[([^\]]+)\]', line)
    if h:
        cur = h.group(1)
        orig_section.setdefault(cur, []).append(line)
    elif cur:
        orig_section[cur].append(line)

if section not in orig_section:
    sys.exit(0)

# Read current file, replace target section with backup version
with open(path) as f:
    lines = f.readlines()

out = []
in_target = False
for line in lines:
    h = re.match(r'^\[([^\]]+)\]', line)
    if h:
        if in_target:
            in_target = False
        if h.group(1) == section:
            in_target = True
            out.extend(orig_section[section])
            continue
    if not in_target:
        out.append(line)

with open(path, 'w') as f:
    f.writelines(out)
PYEOF
}

# ── per-repo section mapping ──────────────────────────────────────────────────
# Format: "filename:section:url_template"
# $H is replaced with $HOST at runtime.
# Only sections that are meaningful to mirror are listed; debug/source/testing
# sections are left pointing at official (they're disabled by default anyway).

build_map() {
    local H="$1"
    cat <<EOF
fedora.repo:fedora:https://$H/fedora/releases/\$releasever/Everything/\$basearch/os/
fedora-updates.repo:updates:https://$H/fedora/updates/\$releasever/Everything/\$basearch/
fedora-updates-testing.repo:updates-testing:https://$H/fedora/updates/testing/\$releasever/Everything/\$basearch/
fedora-cisco-openh264.repo:fedora-cisco-openh264:https://$H/fedora/releases/\$releasever/Everything/\$basearch/os/
rpmfusion-free.repo:rpmfusion-free:https://$H/rpmfusion/free/fedora/releases/\$releasever/Everything/\$basearch/os/
rpmfusion-free-updates.repo:rpmfusion-free-updates:https://$H/rpmfusion/free/fedora/updates/\$releasever/\$basearch/
rpmfusion-free-updates-testing.repo:rpmfusion-free-updates-testing:https://$H/rpmfusion/free/fedora/updates/testing/\$releasever/\$basearch/
rpmfusion-nonfree.repo:rpmfusion-nonfree:https://$H/rpmfusion/nonfree/fedora/releases/\$releasever/Everything/\$basearch/os/
rpmfusion-nonfree-updates.repo:rpmfusion-nonfree-updates:https://$H/rpmfusion/nonfree/fedora/updates/\$releasever/\$basearch/
rpmfusion-nonfree-updates-testing.repo:rpmfusion-nonfree-updates-testing:https://$H/rpmfusion/nonfree/fedora/updates/testing/\$releasever/\$basearch/
EOF
}

# ── cisco-openh264 special case ───────────────────────────────────────────────
# aliyun/tuna/ustc don't mirror cisco-openh264 content (it's a Cisco-hosted
# binary). We disable the repo when switching to a CN mirror and re-enable on
# official. This avoids slow timeouts from an unreachable host.
disable_cisco_openh264() {
    local f="$DIR/fedora-cisco-openh264.repo"
    [[ -f "$f" ]] || return 0
    python3 - "$f" <<'PYEOF'
import sys, re
path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()
out = []
in_cisco = False
for line in lines:
    h = re.match(r'^\[([^\]]+)\]', line)
    if h:
        in_cisco = ('cisco' in h.group(1).lower() or 'openh264' in h.group(1).lower())
        out.append(line)
        continue
    if in_cisco and re.match(r'^enabled\s*=\s*1', line):
        out.append('enabled=0\n')
    else:
        out.append(line)
with open(path, 'w') as f:
    f.writelines(out)
PYEOF
    echo "disabled fedora-cisco-openh264 (not mirrored by CN mirrors)"
}

# ── main ──────────────────────────────────────────────────────────────────────

if [[ "$MIRROR" == "official" ]]; then
    # Restore all managed repos from backup
    for f in "$BACKUP"/fedora*.repo "$BACKUP"/rpmfusion-*.repo; do
        [[ -f "$f" ]] || continue
        cp -a "$f" "$DIR/"
    done
    echo "restored official repos from backup"
else
    while IFS=: read -r fname section url; do
        local_file="$DIR/$fname"
        [[ -f "$local_file" ]] || continue
        patch_section "$local_file" "$section" "$url"
    done < <(build_map "$HOST")

    # Cisco openh264 is not available on CN mirrors — disable it
    disable_cisco_openh264

    echo "switched fedora + rpmfusion mirrors -> $HOST"
fi

echo
echo "refreshing dnf cache..."
dnf makecache --refresh >/dev/null 2>&1 && echo "ok" || echo "warning: makecache had issues, check 'dnf repolist'"
