#!/usr/bin/env bash
# ==============================================================================
# Script cài đặt môi trường và triển khai AutoHost vào /opt/autohost
# Đường dẫn: autohost/install.sh
# ==============================================================================
set -u

# 1. Kiểm tra quyền root (EUID phải bằng 0)
if [[ "${EUID}" -ne 0 ]]; then
    echo "[LỖI] Vui lòng chạy script này bằng quyền root (không dùng sudo bên trong script)." >&2
    exit 1
fi

echo "=== BẮT ĐẦU CÀI ĐẶT HỆ THỐNG AUTOHOST ==="

# 2. Cài đặt các gói phần mềm cần thiết từ kho apt
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y apache2 openssh-server openssl acl ufw cron git shellcheck curl apache2-utils

# 3. Tạo nhóm phụ sftpusers nếu chưa tồn tại
if ! getent group sftpusers >/dev/null 2>&1; then
    groupadd sftpusers
    echo "[OK] Đã tạo nhóm sftpusers."
else
    echo "[OK] Nhóm sftpusers đã tồn tại."
fi

# 4. Bật các module cần thiết của Apache (ssl, rewrite, headers, dav, dav_fs, userdir)
a2enmod ssl rewrite headers dav dav_fs userdir >/dev/null
echo "[OK] Đã bật các module cho Apache2."

# 5. Tạo các thư mục hệ thống và file cơ sở dữ liệu
mkdir -p /opt/autohost/{bin,lib,templates,conf,tests,docs}
mkdir -p /etc/autohost
mkdir -p /etc/ssl/autohost
mkdir -p /backup
mkdir -p /var/www

# Đảm bảo /var/www thuộc sở hữu root:root và quyền 755
chown root:root /var/www
chmod 755 /var/www

# Khởi tạo file sites.csv nếu chưa có
if [[ ! -f /etc/autohost/sites.csv ]]; then
    echo "username,domain,created_at,status" > /etc/autohost/sites.csv
    chmod 600 /etc/autohost/sites.csv
    echo "[OK] Đã khởi tạo /etc/autohost/sites.csv."
fi

# Khởi tạo file log nếu chưa có
if [[ ! -f /var/log/autohost.log ]]; then
    touch /var/log/autohost.log
    chmod 640 /var/log/autohost.log
    echo "[OK] Đã khởi tạo /var/log/autohost.log."
fi

# 6. Copy toàn bộ mã nguồn từ thư mục hiện tại vào /opt/autohost
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${SCRIPT_DIR}" != "/opt/autohost" ]]; then
    cp -r "${SCRIPT_DIR}/"* /opt/autohost/
    echo "[OK] Đã sao chép mã nguồn vào /opt/autohost."
fi

# Cấp quyền thực thi (chạy) cho các file .sh trong bin/, lib/, tests/
chmod +x /opt/autohost/install.sh
find /opt/autohost/bin /opt/autohost/lib /opt/autohost/tests -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true

# 7. Kiểm tra cấu hình Apache trước khi tải lại
if apache2ctl configtest >/dev/null 2>&1; then
    systemctl enable --now apache2
    systemctl reload apache2
    echo "[OK] Apache2 đã được kiểm tra và tải lại thành công."
else
    echo "[LỖI] Cấu hình Apache2 không hợp lệ. Vui lòng kiểm tra bằng lệnh: apache2ctl configtest" >&2
    exit 1
fi

echo "=== CÀI ĐẶT AUTOHOST HOÀN TẤT THÀNH CÔNG! ==="
exit 0
