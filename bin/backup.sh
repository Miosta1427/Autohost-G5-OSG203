#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/conf/autohost.conf"
source "$SCRIPT_DIR/lib/common.sh"

check_root
[[ $# -eq 1 ]] || {
    echo "Cach dung: $0 <domain>" >&2
    exit 1
}

domain="$1"
validate_domain "$domain"

# Lay dung mot tai khoan tu sites.csv.
username=$(awk -F, -v d="$domain" '
    NR > 1 && $2 == d {user=$1; count++}
    END {
        if (count != 1) exit 1
        print user
    }
' "$SITES_DB") || {
    echo "Khong tim thay duy nhat mot site: $domain" >&2
    exit 1
}

validate_user "$username"
id "$username" >/dev/null

web="$WEB_ROOT/$username"
vhost="$APACHE_SITES_AVAIL/$domain.conf"
ssl="$SSL_DIR/$domain"
dav="/var/lib/autohost/webdav/$username"
auth="/etc/autohost/auth/$username.htpasswd"
davconf="/etc/autohost/webdav/$domain.conf"

[[ -d $web && -f $vhost && -d $ssl ]] || {
    echo "Thieu du lieu web, vhost hoac chung chi; dung backup." >&2
    exit 1
}

# Khong di qua symlink tai cac duong dan quan ly.
for path in "$BACKUP_DIR" "$web" "$vhost" "$ssl" \
            "$dav" "$auth" "$davconf"; do
    [[ $path == /* && $path != / ]] || exit 1
    while [[ $path != / ]]; do
        [[ ! -L $path ]] || {
            echo "Tu choi duong dan symlink: $path" >&2
            exit 1
        }
        path=$(dirname -- "$path")
    done
done

# Khong bo sot du lieu nam tren mount rieng.
mounts=$(findmnt -rn --raw -o TARGET)
for path in "$web" "$ssl" "$dav"; do
    while IFS= read -r target; do
        if [[ $target == "$path" || $target == "$path/"* ]]; then
            echo "Co mount rieng trong $path; can xu ly truoc." >&2
            exit 1
        fi
    done <<< "$mounts"
done

mkdir -p "$BACKUP_DIR"
stage=$(mktemp -d "$BACKUP_DIR/.stage-XXXXXXXX")
archive=""
complete=0

# Don file tam; khong de lai goi backup loi.
trap '
    rm -rf -- "$stage"
    if [[ $complete -ne 1 && -n $archive ]]; then
        rm -f -- "$archive" "$archive.sha256"
    fi
' EXIT

mkdir "$stage/metadata"

# Chi luu dong CSV cua site dang backup.
awk -F, -v d="$domain" 'NR==1 || $2==d' \
    "$SITES_DB" > "$stage/metadata/site.csv"

getent passwd "$username" > "$stage/metadata/passwd"
getent shadow "$username" > "$stage/metadata/shadow"
getent group "$(id -g "$username")" > "$stage/metadata/group"

cp "$SCRIPT_DIR/conf/autohost.conf" "$stage/metadata/"

# WebDAV co the chua duoc bat; chi them file dang ton tai.
items=()
for path in "$web" "$vhost" "$ssl" "$dav" "$auth" "$davconf"; do
    if [[ -e $path ]]; then
        items+=("${path#/}")
    fi
done

archive=$(mktemp \
    "$BACKUP_DIR/$domain-$(date +%Y%m%d-%H%M%S)-XXXXXXXX.tar.gz")

tar --acls --xattrs --numeric-owner --one-file-system \
    -czpf "$archive" \
    -C / "${items[@]}" \
    -C "$stage" metadata

# Doc thu toan bo goi nen truoc khi bao thanh cong.
tar -tzf "$archive" >/dev/null
sha256sum "$archive" > "$archive.sha256"
chmod 0600 "$archive" "$archive.sha256"

complete=1
echo "Backup thanh cong:" >&2

# stdout chi chua duong dan de delsite.sh co the nhan lai.
printf '%s\n' "$archive"
