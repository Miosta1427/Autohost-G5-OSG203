#!/usr/bin/env bash
# ==============================================================================
# Thư viện hàm dùng chung: Ghi log, Kiểm tra dữ liệu (Regex), Quản lý CSV, Rollback
# Đường dẫn: lib/common.sh (Phụ trách: Thành viên C)
# ==============================================================================

# Nạp file cấu hình nếu chưa nạp
if [[ -z "${BASE_DIR:-}" ]]; then
    CONF_PATH="/opt/autohost/conf/autohost.conf"
    if [[ -f "${CONF_PATH}" ]]; then
        # shellcheck source=/dev/null
        source "${CONF_PATH}"
    else
        # Dự phòng khi chạy trực tiếp từ thư mục gốc chưa qua /opt/autohost
        SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
        # shellcheck source=/dev/null
        source "${SCRIPT_ROOT}/conf/autohost.conf"
    fi
fi

# Mảng lưu trữ danh sách các hành động cần hoàn tác (rollback) khi gặp sự cố
declare -a ROLLBACK_TASKS=()

# ------------------------------------------------------------------------------
# Hàm: check_root
# Mục đích: Đảm bảo script đang được chạy bởi tài khoản root (EUID == 0)
# ------------------------------------------------------------------------------
check_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "[ERROR] Script này bắt buộc phải chạy bằng quyền root!" >&2
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Hàm: log
# Cú pháp: log <LEVEL> <"Nội dung thông báo">
# Định dạng chuẩn: YYYY-MM-DD HH:MM:SS [LEVEL] nội dung
# ------------------------------------------------------------------------------
log() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Đảm bảo thư mục chứa file log tồn tại
    local log_dir
    log_dir="$(dirname "${LOG_FILE}")"
    mkdir -p "${log_dir}"

    local log_entry="${timestamp} [${level}] ${message}"

    # Ghi vào file log và đồng thời in ra màn hình (nếu là ERROR thì in ra stderr)
    echo "${log_entry}" >> "${LOG_FILE}"
    if [[ "${level}" == "ERROR" ]]; then
        echo "${log_entry}" >&2
    else
        echo "${log_entry}"
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Hàm: validate_user
# Mục đích: Kiểm tra tên user theo Regex ^[a-z][a-z0-9_-]{2,15}$
# Giải thích: Bắt đầu bằng chữ thường a-z, theo sau là 2 đến 15 ký tự (tổng 3-16)
# ------------------------------------------------------------------------------
validate_user() {
    local username="${1:-}"
    local regex='^[a-z][a-z0-9_-]{2,15}$'

    if [[ -z "${username}" ]]; then
        log "ERROR" "Tên người dùng không được để trống."
        return 1
    fi

    if [[ ! "${username}" =~ ${regex} ]]; then
        log "ERROR" "Tên người dùng '${username}' không hợp lệ! Phải bắt đầu bằng chữ thường (a-z), dài 3-16 ký tự, chỉ gồm chữ thường, số, gạch dưới (_) hoặc gạch ngang (-)."
        return 1
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Hàm: validate_domain
# Mục đích: Kiểm tra tên miền theo Regex ^([a-z0-9-]+\.)+[a-z]{2,}$
# ------------------------------------------------------------------------------
validate_domain() {
    local domain="${1:-}"
    local regex='^([a-z0-9-]+\.)+[a-z]{2,}$'

    if [[ -z "${domain}" ]]; then
        log "ERROR" "Tên miền (domain) không được để trống."
        return 1
    fi

    if [[ ! "${domain}" =~ ${regex} ]]; then
        log "ERROR" "Tên miền '${domain}' không hợp lệ! Ví dụ hợp lệ: alice.autohost.local"
        return 1
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Hàm: register_rollback
# Mục đích: Đăng ký một lệnh dọn dẹp vào danh sách chờ hoàn tác nếu có lỗi
# ------------------------------------------------------------------------------
register_rollback() {
    local cmd="${1:-}"
    if [[ -n "${cmd}" ]]; then
        # Thêm lệnh mới vào đầu mảng để khi rollback sẽ chạy theo thứ tự ngược lại (LIFO)
        ROLLBACK_TASKS=("${cmd}" "${ROLLBACK_TASKS[@]}")
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Hàm: clear_rollback
# Mục đích: Xóa danh sách rollback sau khi mọi bước đã hoàn tất thành công
# ------------------------------------------------------------------------------
clear_rollback() {
    ROLLBACK_TASKS=()
    return 0
}

# ------------------------------------------------------------------------------
# Hàm: execute_rollback
# Mục đích: Được gọi tự động bởi trap khi xảy ra lỗi giữa chừng để dọn sạch rác
# ------------------------------------------------------------------------------
execute_rollback() {
    if [[ "${#ROLLBACK_TASKS[@]}" -eq 0 ]]; then
        return 0
    fi

    log "WARN" "Phát hiện lỗi giữa chừng! Bắt đầu quá trình ROLLBACK (dọn dẹp tự động)..."
    local task
    for task in "${ROLLBACK_TASKS[@]}"; do
        log "INFO" "Đang hoàn tác: ${task}"
        eval "${task}" || log "WARN" "Lệnh hoàn tác gặp cảnh báo nhỏ: ${task}"
    done
    ROLLBACK_TASKS=()
    log "WARN" "Đã hoàn tất ROLLBACK. Hệ thống trở về trạng thái sạch."
    return 0
}

# ------------------------------------------------------------------------------
# Hàm: init_sites_db
# Mục đích: Đảm bảo file /etc/autohost/sites.csv luôn tồn tại trước khi đọc/ghi
# ------------------------------------------------------------------------------
init_sites_db() {
    local db_dir
    db_dir="$(dirname "${SITES_DB}")"
    mkdir -p "${db_dir}"
    if [[ ! -f "${SITES_DB}" ]]; then
        echo "username,domain,created_at,status" > "${SITES_DB}"
        chmod 600 "${SITES_DB}"
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Hàm: site_exists
# Mục đích: Kiểm tra xem user hoặc domain đã tồn tại trong hệ thống hay CSV chưa
# Trả về: 0 nếu ĐÃ TỒN TẠI (trùng), 1 nếu CHƯA TỒN TẠI (an toàn để tạo mới)
# ------------------------------------------------------------------------------
site_exists() {
    local username="${1:-}"
    local domain="${2:-}"

    init_sites_db

    # 1. Kiểm tra user đã có trong Linux (/etc/passwd) chưa
    if id "${username}" >/dev/null 2>&1; then
        log "ERROR" "Người dùng hệ thống '${username}' đã tồn tại!"
        return 0
    fi

    # 2. Kiểm tra user hoặc domain đã có trong file sites.csv chưa
    if grep -qE "^${username},|,${domain}," "${SITES_DB}" 2>/dev/null; then
        log "ERROR" "Người dùng '${username}' hoặc tên miền '${domain}' đã có trong danh sách ${SITES_DB}!"
        return 0
    fi

    # 3. Kiểm tra file cấu hình vhost của domain đã tồn tại chưa
    if [[ -f "${APACHE_SITES_AVAIL}/${domain}.conf" ]]; then
        log "ERROR" "File cấu hình Apache cho '${domain}' đã tồn tại!"
        return 0
    fi

    return 1
}

# ------------------------------------------------------------------------------
# Hàm: add_site_csv
# Mục đích: Ghi thông tin trang web mới vào sổ quản lý /etc/autohost/sites.csv
# ------------------------------------------------------------------------------
add_site_csv() {
    local username="${1:-}"
    local domain="${2:-}"
    local created_at
    created_at="$(date '+%Y-%m-%d %H:%M:%S')"

    init_sites_db
    echo "${username},${domain},${created_at},active" >> "${SITES_DB}"
    log "INFO" "Đã ghi nhận site '${domain}' (user: '${username}') vào ${SITES_DB}."
    return 0
}

# ------------------------------------------------------------------------------
# Hàm: remove_site_csv
# Mục đích: Xóa dòng chứa domain hoặc user khỏi file sites.csv (dùng khi xóa/rollback)
# ------------------------------------------------------------------------------
remove_site_csv() {
    local domain="${1:-}"
    if [[ -z "${domain}" || ! -f "${SITES_DB}" ]]; then
        return 0
    fi
    sed -i "/,${domain},/d" "${SITES_DB}"
    log "INFO" "Đã xóa thông tin tên miền '${domain}' khỏi ${SITES_DB}."
    return 0
}
