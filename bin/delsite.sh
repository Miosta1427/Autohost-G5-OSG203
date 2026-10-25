#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/conf/autohost.conf"
source "$SCRIPT_DIR/lib/common.sh"

check_root

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Cach dung: $0 <domain> [--keep-data]" >&2
    exit 1
fi

domain="$1"
keep="${2:-}"

[[ -z $keep || $keep == --keep-data ]] || {
    echo "Tuy chon khong hop le: $keep" >&2
    exit 1
}

validate_domain "$domain"

# Chi cho mot lenh xoa site chay tai mot thoi diem.
exec 9>/run/lock/autohost-delete.lock
flock -n 9 || {
    echo "Dang co lenh xoa site khac chay." >&2
    exit 1
}

username=$(awk -F, -v d="$domain" '
    NR>1 && $2==d {user=$1; count++}
    END {
        if (count!=1) exit 1
        print user
    }
' "$SITES_DB") || {
    echo "Khong tim thay duy nhat mot site: $domain" >&2
    exit 1
}

validate_user "$username"

# Khong xoa user neu user nay con quan ly site khac.
count=$(awk -F, -v u="$username" '
    NR>1 && $1==u {n++}
    END {print n+0}
' "$SITES_DB")

[[ $count -eq 1 ]] || {
    echo "User dang gan voi nhieu site; dung xoa." >&2
    exit 1
}

web="$WEB_ROOT/$username"
dav="/var/lib/autohost/webdav/$username"
locks="/var/lib/autohost/dav-lock/$username"
auth="/etc/autohost/auth/$username.htpasswd"
davconf="/etc/autohost/webdav/$domain.conf"
vhost="$APACHE_SITES_AVAIL/$domain.conf"
ssl="$SSL_DIR/$domain"
enabled="/etc/apache2/sites-enabled/$domain.conf"

# Chi chap nhan tai khoan khach dung cau truc AutoHost.
account=$(getent passwd "$username")
IFS=: read -r _ _ uid _ _ user_home user_shell <<< "$account"

[[ $WEB_ROOT == /var/www &&
   $uid -ge 1000 &&
   $user_home == "$web" &&
   $user_shell == /usr/sbin/nologin ]] || {
    echo "Tai khoan khong dung cau truc AutoHost; dung xoa." >&2
    exit 1
}

id -nG "$username" | tr ' ' '\n' | grep -Fxq "$SFTP_GROUP" || {
    echo "User khong thuoc nhom SFTP cua AutoHost." >&2
    exit 1
}

# Tu choi symlink tai cac duong dan se xu ly.
for path in "$web" "$dav" "$locks" "$auth" \
            "$davconf" "$vhost" "$ssl" "$SITES_DB"; do
    [[ $path == /* && $path != / ]] || exit 1
    while [[ $path != / ]]; do
        [[ ! -L $path ]] || {
            echo "Tu choi duong dan symlink: $path" >&2
            exit 1
        }
        path=$(dirname -- "$path")
    done
done

# Khong xoa du lieu co mount rieng ben trong.
mounts=$(findmnt -rn --raw -o TARGET)
for path in "$web" "$dav" "$locks" "$ssl"; do
    while IFS= read -r target; do
        if [[ $target == "$path" || $target == "$path/"* ]]; then
            echo "Can thao mount truoc: $target" >&2
            exit 1
        fi
    done <<< "$mounts"
done

# Yeu cau dong cac phien SFTP/tien trinh cua khach.
if pgrep -u "$uid" >/dev/null; then
    echo "User con tien trinh. Hay dong phien SFTP truoc." >&2
    exit 1
else
    rc=$?
    [[ $rc -eq 1 ]] || exit 1
fi

was_enabled=0
if [[ -e $enabled || -L $enabled ]]; then
    [[ -L $enabled &&
       $(readlink -f -- "$enabled") == "$vhost" ]] || {
        echo "Lien ket site Apache khong dung; dung xoa." >&2
        exit 1
    }
    was_enabled=1
fi

apache2ctl configtest

echo "Domain: $domain"
echo "User:   $username"

if [[ $keep == --keep-data ]]; then
    echo "Du lieu web va WebDAV se GIU LAI duoi quyen root."
else
    echo "Du lieu web va WebDAV se BI XOA sau khi backup."
fi

read -r -p "Nhap lai dung domain de xac nhan: " answer

[[ $answer == "$domain" ]] || {
    echo "Da huy. Chua xoa gi."
    exit 0
}

# Backup phai thanh cong truoc moi thao tac xoa.
archive=$(bash "$SCRIPT_DIR/bin/backup.sh" "$domain") || {
    echo "Backup that bai; khong xoa site." >&2
    exit 1
}

[[ $archive == "$BACKUP_DIR/"* &&
   -s $archive && -f $archive.sha256 ]] || {
    echo "Khong co goi backup hop le; dung xoa." >&2
    exit 1
}

sha256sum -c "$archive.sha256"
tar -tzf "$archive" >/dev/null
echo "Backup da kiem tra: $archive"

# Chuan bi CSV moi, so sanh domain chinh xac.
csvtmp=""
trap '
    rc=$?
    if [[ -n $csvtmp ]]; then
        rm -f -- "$csvtmp"
    fi
    if (( rc != 0 )); then
        echo "Thao tac dung giua chung. Kiem tra trang thai truoc khi chay lai." >&2
        echo "Backup: $archive" >&2
    fi
' EXIT

csvtmp=$(mktemp "$SITES_DB.delete.XXXXXXXX")
awk -F, -v d="$domain" 'NR==1 || $2!=d' \
    "$SITES_DB" > "$csvtmp"
chmod 0600 "$csvtmp"

# Ngung phuc vu site truoc khi xoa user va du lieu.
if [[ $was_enabled -eq 1 ]]; then
    a2dissite "$domain.conf"
fi

if ! apache2ctl configtest || ! systemctl reload apache2; then
    if [[ $was_enabled -eq 1 ]]; then
        a2ensite "$domain.conf"
        apache2ctl configtest && systemctl reload apache2
    fi
    echo "Khong tai lai duoc Apache; chua xoa user/du lieu." >&2
    exit 1
fi

# Khong dung -r: du lieu duoc xu ly rieng ben duoi.
if ! userdel "$username"; then
    if [[ $was_enabled -eq 1 ]]; then
        a2ensite "$domain.conf"
        apache2ctl configtest && systemctl reload apache2
    fi
    echo "Khong xoa duoc user; dung xu ly du lieu." >&2
    exit 1
fi

# Chi thu xoa nhom rieng trung ten user.
if getent group "$username" >/dev/null; then
    groupdel "$username" || echo "Giu lai nhom $username vi con duoc su dung."
fi

for path in "$web" "$dav"; do
    if [[ -d $path ]]; then
        if [[ $keep == --keep-data ]]; then
            chmod 0700 "$path"
            find -P "$path" -xdev -exec chown -h root:root -- {} +
            setfacl -R -P -b -k -- "$path"
            chmod 0700 "$path"
        else
            rm -rf --one-file-system -- "$path"
        fi
    fi
done

rm -rf --one-file-system -- "$ssl" "$locks"
rm -f -- "$auth" "$davconf" "$vhost"

mv -- "$csvtmp" "$SITES_DB"
csvtmp=""
trap - EXIT

log INFO "Da xoa site $domain; user=$username; backup=$archive"
echo "Giu lai backup va nhat ky Apache."
