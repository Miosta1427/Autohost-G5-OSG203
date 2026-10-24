#!/usr/bin/env bash
# ==============================================================================
# Kịch bản tạo mới một website (gian hàng) tự động hoàn chỉnh
# Cú pháp: /opt/autohost/bin/addsite.sh <username> <domain> [--simulate-fail]
# Đường dẫn: bin/addsite.sh (Phụ trách: Thành viên C)
# ==============================================================================
set -u

# Xác định thư mục gốc của dự án và nạp các thư viện
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/conf/autohost.conf"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/user.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/apache.sh"

# ------------------------------------------------------------------------------
# Hàm: main
# ------------------------------------------------------------------------------
main() {
    # 1. Kiểm tra quyền root ở đầu script
    check_root || return 1

    local username="${1:-}"
    local domain="${2:-}"
    local extra_flag="${3:-}"

    # Kiểm tra số lượng tham số đầu vào
    if [[ -z "${username}" || -z "${domain}" ]]; then
        echo "Cách dùng: $0 <username> <domain> [--simulate-fail]" >&2
        log "ERROR" "Gọi addsite.sh thiếu tham số (user='${username}', domain='${domain}')."
        return 1
    fi

    # 2. Kiểm tra định dạng input bằng Regex trước khi làm bất cứ việc gì khác
    validate_user "${username}" || return 1
    validate_domain "${domain}" || return 1

    # 3. Kiểm tra trùng lặp (chặn nếu user hoặc domain đã tồn tại)
    if site_exists "${username}" "${domain}"; then
        return 1
    fi

    # 4. Bật bẫy (trap) để tự động chạy execute_rollback nếu script thoát bất thường
    trap 'execute_rollback' EXIT

    log "INFO" "=== Bắt đầu khởi tạo website '${domain}' cho người dùng '${username}' ==="

    # 5. Tạo user Linux và sinh mật khẩu ngẫu nhiên
    create_site_user "${username}" || return 1

    # 6. Tạo cây thư mục /var/www/<user>/public_html, phân quyền 750 và ACL cho www-data
    setup_site_dirs "${username}" "${domain}" || return 1

    # 7. Sinh chứng chỉ bảo mật SSL tự ký (key quyền 600)
    generate_ssl_cert "${domain}" || return 1

    # 8. Ghi thông tin vào sổ quản lý /etc/autohost/sites.csv và đăng ký rollback
    add_site_csv "${username}" "${domain}" || return 1
    register_rollback "remove_site_csv '${domain}'"

    # Tùy chọn hỗ trợ kiểm thử bắt buộc: Giả lập lỗi giữa chừng trước khi bật Apache
    if [[ "${extra_flag}" == "--simulate-fail" ]]; then
        log "ERROR" "Giả lập sự cố giữa chừng (--simulate-fail) để kiểm tra cơ chế Rollback!"
        return 1
    fi

    # 9. Tạo cấu hình VirtualHost, kiểm tra configtest và reload Apache
    create_apache_vhost "${username}" "${domain}" || return 1

    # 10. Mọi bước đã thành công -> Xóa danh sách rollback và gỡ trap để giữ lại thành quả
    clear_rollback
    trap - EXIT

    log "INFO" "=== Khởi tạo hoàn tất website '${domain}' cho '${username}' ==="

    # 11. In bảng tóm tắt thông tin và mật khẩu (CHỈ IN ĐÚNG 1 LẦN, không ghi vào log/CSV)
    echo ""
    echo "=================================================================="
    echo "          THÔNG TIN GIAN HÀNG MỚI (LƯU LẠI MẬT KHẨU NGAY)         "
    echo "=================================================================="
    echo " Chủ sở hữu (User)  : ${username}"
    echo " Mật khẩu (1 lần)   : ${GENERATED_PASS}"
    echo " Tên miền (Domain)  : https://${domain}"
    echo " Thư mục Web        : ${WEB_ROOT}/${username}/public_html"
    echo " Cấu hình Apache    : ${APACHE_SITES_AVAIL}/${domain}.conf"
    echo " Chứng chỉ SSL      : ${SSL_DIR}/${domain}/selfsigned.crt"
    echo " Nhật ký truy cập   : ${APACHE_LOG_DIR}/${domain}/access.log"
    echo "=================================================================="
    echo ""

    return 0
}

main "$@"
exit "$?"
