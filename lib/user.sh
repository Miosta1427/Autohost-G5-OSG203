#!/usr/bin/env bash
# ==============================================================================
# Module quản lý User, Thư mục, Phân quyền (chmod/chown) và ACL (setfacl)
# Đường dẫn: lib/user.sh (Phụ trách: Thành viên B)
# ==============================================================================

# ------------------------------------------------------------------------------
# Hàm: create_site_user
# Mục đích: Tạo user mới với nhóm chính riêng và nhóm phụ sftpusers, đặt mật khẩu
# Đầu vào: $1 = username
# Đầu ra: Lưu mật khẩu vừa sinh vào biến toàn cục GENERATED_PASS (in 1 lần ở addsite)
# ------------------------------------------------------------------------------
create_site_user() {
    local username="${1:-}"

    if [[ -z "${username}" ]]; then
        log "ERROR" "create_site_user: Thiếu tên người dùng."
        return 1
    fi

    # Đảm bảo nhóm phụ sftpusers đã tồn tại
    if ! getent group "${SFTP_GROUP}" >/dev/null 2>&1; then
        groupadd "${SFTP_GROUP}" || {
            log "ERROR" "Không thể tạo nhóm '${SFTP_GROUP}'."
            return 1
        }
    fi

    # Tạo user:
    # -U: tự tạo một nhóm chính trùng tên với user (TUYỆT ĐỐI không dùng chung nhóm chính)
    # -G sftpusers: thêm user vào nhóm phụ sftpusers
    # -d /var/www/<user>: đặt thư mục nhà
    # -M: không tự tạo thư mục nhà (để hàm setup_site_dirs bên dưới tự tạo và gán quyền chuẩn cho chroot)
    # -s /usr/sbin/nologin: cấm đăng nhập shell tương tác (chỉ được dùng SFTP)
    useradd -U -G "${SFTP_GROUP}" -d "${WEB_ROOT}/${username}" -M -s /usr/sbin/nologin "${username}" || {
        log "ERROR" "Không thể tạo người dùng '${username}'."
        return 1
    }

    # Đăng ký lệnh hoàn tác (rollback) ngay sau khi tạo user thành công
    register_rollback "userdel -f '${username}' 2>/dev/null; groupdel '${username}' 2>/dev/null"

    # Sinh mật khẩu ngẫu nhiên 12 byte mã hóa base64 (không ghi vào log hay CSV)
    GENERATED_PASS="$(openssl rand -base64 12)"
    if [[ -z "${GENERATED_PASS}" ]]; then
        log "ERROR" "Không thể sinh mật khẩu ngẫu nhiên cho '${username}'."
        return 1
    fi

    # Đặt mật khẩu cho user qua lệnh chpasswd
    echo "${username}:${GENERATED_PASS}" | chpasswd || {
        log "ERROR" "Không thể đặt mật khẩu cho '${username}'."
        return 1
    }

    log "INFO" "Đã tạo user '${username}' (nhóm chính: '${username}', nhóm phụ: '${SFTP_GROUP}')."
    return 0
}

# ------------------------------------------------------------------------------
# Hàm: setup_site_dirs
# Mục đích: Tạo /var/www/<user> (root:root 755), public_html (<user>:<user> 750),
#           cấp quyền đọc ACL cho www-data và sinh trang index.html từ template
# Đầu vào: $1 = username, $2 = domain
# ------------------------------------------------------------------------------
setup_site_dirs() {
    local username="${1:-}"
    local domain="${2:-}"
    local user_root="${WEB_ROOT}/${username}"
    local public_html="${user_root}/public_html"
    local tpl_index="${BASE_DIR}/templates/index.html.tpl"

    if [[ -z "${username}" || -z "${domain}" ]]; then
        log "ERROR" "setup_site_dirs: Thiếu username hoặc domain."
        return 1
    fi

    # 1. Tạo thư mục gốc của user và thư mục public_html
    mkdir -p "${public_html}" || {
        log "ERROR" "Không thể tạo thư mục '${public_html}'."
        return 1
    }

    # Đăng ký rollback xóa thư mục (có bảo vệ biến rỗng :?)
    register_rollback "rm -rf \"${WEB_ROOT:?}/${username:?}\""

    # 2. Thiết lập chủ sở hữu và quyền cho thư mục Chroot (/var/www/<user>)
    # Bắt buộc phải là root:root và 755 thì OpenSSH ChrootDirectory mới cho phép đăng nhập
    chown root:root "${user_root}" || return 1
    chmod 755 "${user_root}" || return 1

    # 3. Thiết lập chủ sở hữu và quyền 750 cho public_html
    # 750: Chủ (<user>) có toàn quyền (7=rwx), Nhóm (<user>) có quyền đọc/vào (5=r-x),
    # Người khác (Others - gồm các user khách hàng khác như bob) hoàn toàn KHÔNG có quyền gì (0=---)
    chown "${username}:${username}" "${public_html}" || return 1
    chmod 750 "${public_html}" || return 1

    # 4. Cấp quyền ACL cho Apache (www-data) để đọc được web mà không cần mở quyền cho Others
    # -m u:www-data:rx  -> cấp quyền đọc và đi vào thư mục hiện tại
    # -d -m u:www-data:rx -> cấp ACL mặc định (default) để mọi file/thư mục khách upload sau này
    #                        tự động kế thừa quyền đọc cho www-data
    setfacl -R -m "u:${APACHE_USER}:rx" "${public_html}" || {
        log "ERROR" "Không thể thiết lập ACL hiện tại cho '${APACHE_USER}' trên '${public_html}'."
        return 1
    }
    setfacl -R -d -m "u:${APACHE_USER}:rx" "${public_html}" || {
        log "ERROR" "Không thể thiết lập ACL mặc định (-d) cho '${APACHE_USER}' trên '${public_html}'."
        return 1
    }

    # 5. Tạo file index.html từ bản mẫu (template) bằng sed
    if [[ ! -f "${tpl_index}" ]]; then
        tpl_index="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates/index.html.tpl"
    fi

    sed -e "s|{{USER}}|${username}|g" \
        -e "s|{{DOMAIN}}|${domain}|g" \
        "${tpl_index}" > "${public_html}/index.html" || {
        log "ERROR" "Không thể tạo file index.html từ template."
        return 1
    }

    # Đảm bảo file index.html thuộc sở hữu của user và có quyền 640
    chown "${username}:${username}" "${public_html}/index.html" || return 1
    chmod 640 "${public_html}/index.html" || return 1
    setfacl -m "u:${APACHE_USER}:r" "${public_html}/index.html" || return 1

    log "INFO" "Đã thiết lập thư mục '${public_html}' (750) và ACL cho '${APACHE_USER}'."
    return 0
}
