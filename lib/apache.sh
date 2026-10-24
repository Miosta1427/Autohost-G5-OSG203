#!/usr/bin/env bash
# ==============================================================================
# Module quản lý Chứng chỉ SSL (OpenSSL) và Cấu hình VirtualHost cho Apache2
# Đường dẫn: lib/apache.sh (Phụ trách: Thành viên A)
# ==============================================================================

# ------------------------------------------------------------------------------
# Hàm: generate_ssl_cert
# Mục đích: Tạo chứng chỉ SSL tự ký (Self-Signed) cho domain, khóa riêng quyền 600
# Đầu vào: $1 = domain
# ------------------------------------------------------------------------------
generate_ssl_cert() {
    local domain="${1:-}"
    local cert_dir="${SSL_DIR}/${domain}"
    local key_file="${cert_dir}/selfsigned.key"
    local crt_file="${cert_dir}/selfsigned.crt"

    if [[ -z "${domain}" ]]; then
        log "ERROR" "generate_ssl_cert: Thiếu tên miền."
        return 1
    fi

    mkdir -p "${cert_dir}" || {
        log "ERROR" "Không thể tạo thư mục SSL '${cert_dir}'."
        return 1
    }

    # Đăng ký rollback xóa thư mục SSL của domain nếu có lỗi xảy ra sau bước này
    register_rollback "rm -rf \"${SSL_DIR:?}/${domain:?}\""

    # Sinh cặp khóa RSA 2048-bit và chứng chỉ có hạn 365 ngày không hỏi mật khẩu (-nodes)
    if ! openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${key_file}" \
        -out "${crt_file}" \
        -subj "/C=VN/ST=DaNang/L=DaNang/O=AutoHost/OU=Hosting/CN=${domain}" \
        -addext "subjectAltName=DNS:${domain}" >/dev/null 2>&1; then
        # Dự phòng nếu phiên bản openssl không hỗ trợ cờ -addext
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "${key_file}" \
            -out "${crt_file}" \
            -subj "/C=VN/ST=DaNang/L=DaNang/O=AutoHost/OU=Hosting/CN=${domain}" >/dev/null 2>&1 || {
            log "ERROR" "Không thể tạo chứng chỉ SSL cho '${domain}'."
            return 1
        }
    fi

    # Bảo mật bắt buộc: Chìa khóa riêng (Private Key) chỉ cho phép root đọc/ghi (600)
    chown root:root "${key_file}" "${crt_file}" || return 1
    chmod 600 "${key_file}" || return 1
    chmod 644 "${crt_file}" || return 1

    log "INFO" "Đã tạo chứng chỉ SSL tự ký tại '${cert_dir}' (key 600)."
    return 0
}

# ------------------------------------------------------------------------------
# Hàm: create_apache_vhost
# Mục đích: Tạo thư mục log riêng, sinh file vhost từ template, bật site và reload
# Đầu vào: $1 = username, $2 = domain
# ------------------------------------------------------------------------------
create_apache_vhost() {
    local username="${1:-}"
    local domain="${2:-}"
    local vhost_file="${APACHE_SITES_AVAIL}/${domain}.conf"
    local site_log_dir="${APACHE_LOG_DIR}/${domain}"
    local tpl_vhost="${BASE_DIR}/templates/vhost.conf.tpl"

    if [[ -z "${username}" || -z "${domain}" ]]; then
        log "ERROR" "create_apache_vhost: Thiếu username hoặc domain."
        return 1
    fi

    # 1. Tạo thư mục chứa log riêng cho domain (/var/log/apache2/<domain>)
    mkdir -p "${site_log_dir}" || {
        log "ERROR" "Không thể tạo thư mục log '${site_log_dir}'."
        return 1
    }
    register_rollback "rm -rf \"${APACHE_LOG_DIR:?}/${domain:?}\""

    # 2. Xác định đường dẫn template vhost
    if [[ ! -f "${tpl_vhost}" ]]; then
        tpl_vhost="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates/vhost.conf.tpl"
    fi

    # 3. Sinh file cấu hình VirtualHost từ template bằng lệnh sed
    sed -e "s|{{USER}}|${username}|g" \
        -e "s|{{DOMAIN}}|${domain}|g" \
        -e "s|{{WEB_ROOT}}|${WEB_ROOT}|g" \
        -e "s|{{SSL_DIR}}|${SSL_DIR}|g" \
        -e "s|{{APACHE_LOG_DIR}}|${APACHE_LOG_DIR}|g" \
        "${tpl_vhost}" > "${vhost_file}" || {
        log "ERROR" "Không thể tạo file VirtualHost '${vhost_file}'."
        return 1
    }

    # Đăng ký rollback tắt site và xóa file vhost nếu bước sau bị lỗi
    register_rollback "a2dissite -q '${domain}.conf' >/dev/null 2>&1; rm -f \"${APACHE_SITES_AVAIL:?}/${domain:?}.conf\"; systemctl reload apache2 >/dev/null 2>&1"

    # 4. Bật module ssl và rewrite (đảm bảo đã bật) rồi kích hoạt site mới
    a2enmod ssl rewrite >/dev/null 2>&1 || true
    a2ensite "${domain}.conf" >/dev/null 2>&1 || {
        log "ERROR" "Không thể kích hoạt site '${domain}.conf' bằng a2ensite."
        return 1
    }

    # 5. Kiểm tra cú pháp cấu hình Apache TRƯỚC KHI reload (Quy ước bắt buộc)
    if ! apache2ctl configtest >/dev/null 2>&1; then
        log "ERROR" "Kiểm tra apache2ctl configtest THẤT BẠI! Cấu hình Apache có lỗi."
        return 1
    fi

    # 6. Tải lại (reload) Apache để nhận trang web mới mà không làm gián đoạn các trang khác
    systemctl reload apache2 || {
        log "ERROR" "Không thể reload dịch vụ apache2."
        return 1
    }

    log "INFO" "Đã kích hoạt VirtualHost và reload Apache2 thành công cho '${domain}'."
    return 0
}
