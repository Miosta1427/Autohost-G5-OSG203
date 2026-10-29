#!/usr/bin/env bash

# Cau hinh SFTP Chroot cho nhom sftpusers.
setup_sftp() (
    # Dung subshell de khong thay doi shell dang lam viec.
    if [[ $EUID -ne 0 ]]; then
        echo "Loi: phai chay bang root."
        return 1
    fi

    local config="/etc/ssh/sshd_config"
    local backup_dir

    getent group sftpusers >/dev/null || {
        echo "Loi: chua co nhom sftpusers."
        return 1
    }

    # Khong cho hai lan cau hinh chay cung luc.
    exec 9>/run/lock/autohost-sftp.lock || return 1
    flock -n 9 || {
        echo "Dang co tien trinh khac cau hinh SFTP."
        return 1
    }

    /usr/sbin/sshd -t || return 1

    if grep -Fxq '# BEGIN AUTOHOST SFTP' "$config"; then
        echo "Da co cau hinh AutoHost SFTP; khong them trung."
        return 0
    fi

    # Tao thu muc backup rieng, chi root truy cap.
    backup_dir=$(mktemp -d /etc/ssh/autohost-backup.XXXXXXXX) \
        || return 1

    cp -p "$config" "$backup_dir/original" || return 1
    cp -p "$config" "$backup_dir/candidate" || return 1

    # Them quy tac o CUOI file cau hinh.
    cat >> "$backup_dir/candidate" <<'EOF'

# BEGIN AUTOHOST SFTP
Match Group sftpusers
    ChrootDirectory /var/www/%u
    ForceCommand internal-sftp -d /public_html -u 0027
    PasswordAuthentication yes
    AuthenticationMethods password
    DisableForwarding yes
    PermitTTY no
    PermitTunnel no
    PermitUserRC no
Match all
# END AUTOHOST SFTP
EOF

    [[ $? -eq 0 ]] || return 1

    # Kiem tra ban moi truoc khi thay cau hinh dang dung.
    /usr/sbin/sshd -t -f "$backup_dir/candidate" || {
        echo "Cau hinh moi bi loi; chua thay doi SSH."
        return 1
    }

    mv "$backup_dir/candidate" "$config" || return 1

    if systemctl reload ssh; then
        echo "Da ap dung cau hinh SFTP Chroot."
        echo "Ban sao cau hinh cu: $backup_dir/original"
    else
        echo "Reload that bai; dang khoi phuc cau hinh cu."
        cp -p "$backup_dir/original" "$config" || return 1
        /usr/sbin/sshd -t && systemctl reload ssh
        return 1
    fi
)

# Cau hinh WebDAV cho mot website da tao.
# Cach goi: setup_webdav kh001 kh001.example.test
setup_webdav() (
    [[ $EUID -eq 0 ]] || {
        echo "Phai chay bang root."
        return 1
    }

    umask 077
    source /opt/autohost/conf/autohost.conf || return 1
    source /opt/autohost/lib/common.sh || return 1

    local username="${1:-}"
    local domain="${2:-}"

    validate_user "$username" || return 1
    validate_domain "$domain" || return 1

    # Kiem tra dung tai khoan va domain trong sites.csv.
    awk -F, -v u="$username" -v d="$domain" \
        'NR>1 && $1==u && $2==d {n++}
         END {exit (n!=1)}' "$SITES_DB" || {
        echo "Khong tim thay dung user/domain trong sites.csv."
        return 1
    }

    local data="/var/lib/autohost/webdav/$username"
    local locks="/var/lib/autohost/dav-lock/$username"
    local auth="/etc/autohost/auth/$username.htpasswd"
    local conf="/etc/autohost/webdav/$domain.conf"
    local vhost="$APACHE_SITES_AVAIL/$domain.conf"
    local snapshot path

    # Tu choi duong dan co lien ket tuong trung.
    for path in "$data" "$locks" "$auth" "$conf" "$vhost" "$BACKUP_DIR"; do
        while [[ $path != / ]]; do
            [[ ! -L $path ]] || {
                echo "Tu choi duong dan symlink: $path"
                return 1
            }
            path=$(dirname -- "$path") || return 1
        done
    done

    grep -Fxq "    IncludeOptional $conf" "$vhost" || {
        echo "Hay them IncludeOptional vao VirtualHost HTTPS truoc."
        return 1
    }

    exec 9>/run/lock/autohost-webdav.lock || return 1
    flock -n 9 || return 1
    apache2ctl configtest || return 1

    install -d -o root -g root -m 0755 \
        /etc/autohost/auth \
        /etc/autohost/webdav \
        /var/lib/autohost/webdav \
        /var/lib/autohost/dav-lock || return 1

    mkdir -p "$BACKUP_DIR" || return 1
    snapshot=$(mktemp -d "$BACKUP_DIR/webdav-XXXXXXXX") \
        || return 1

    if [[ -f $auth ]]; then
        cp -p "$auth" "$snapshot/old-auth" || return 1
        cp -p "$auth" "$snapshot/new-auth" || return 1
    else
        : > "$snapshot/new-auth" || return 1
    fi

    if [[ -f $conf ]]; then
        cp -p "$conf" "$snapshot/old-conf" || return 1
    fi

    echo "Dat mat khau WebDAV cho $username:"
    htpasswd -B "$snapshot/new-auth" "$username" || return 1

    install -d -o "$APACHE_USER" -g "$APACHE_USER" -m 0750 \
        "$data" "$locks" || return 1

    cat > "$snapshot/new-conf" <<EOF
DavLockDB "$locks/DavLock"

Alias /webdav/ "$data/"

<Directory "$data">
    Dav On
    Options None
    AllowOverride None
    SSLRequireSSL

    AuthType Basic
    AuthName "AutoHost WebDAV - $domain"
    AuthBasicProvider file
    AuthUserFile "$auth"
    Require user $username
</Directory>

<Location "/webdav/">
    SetHandler default-handler
    ForceType application/octet-stream
    Header always set X-Content-Type-Options nosniff
    Header always set Content-Disposition attachment
</Location>
EOF
    [[ $? -eq 0 ]] || return 1

    # Neu ap dung that bai, khoi phuc auth va cau hinh cu.
    trap '
        rc=$?
        if (( rc != 0 )); then
            echo "Co loi; dang khoi phuc cac file truoc khi ap dung."
            if [[ -f $snapshot/old-auth ]]; then
                cp -p "$snapshot/old-auth" "$auth"
            else
                rm -f -- "$auth"
            fi
            if [[ -f $snapshot/old-conf ]]; then
                cp -p "$snapshot/old-conf" "$conf"
            else
                rm -f -- "$conf"
            fi
            apache2ctl configtest && systemctl reload apache2
            echo "Ban sao de kiem tra: $snapshot"
        fi
    ' EXIT

    install -o root -g "$APACHE_USER" -m 0640 \
        "$snapshot/new-auth" "$auth" || return 1

    install -o root -g root -m 0644 \
        "$snapshot/new-conf" "$conf" || return 1

    apache2ctl configtest || return 1
    systemctl reload apache2 || return 1

    trap - EXIT
    echo "WebDAV san sang: https://$domain/webdav/"
)
