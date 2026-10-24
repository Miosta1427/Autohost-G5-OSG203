<VirtualHost *:80>
    ServerName {{DOMAIN}}
    ServerAdmin {{USER}}@{{DOMAIN}}

    # Tự động chuyển hướng vĩnh viễn (301) mọi truy cập HTTP thường sang HTTPS bảo mật
    Redirect permanent / https://{{DOMAIN}}/

    ErrorLog {{APACHE_LOG_DIR}}/{{DOMAIN}}/error.log
    CustomLog {{APACHE_LOG_DIR}}/{{DOMAIN}}/access.log combined
</VirtualHost>

<VirtualHost *:443>
    ServerName {{DOMAIN}}
    ServerAdmin {{USER}}@{{DOMAIN}}
    DocumentRoot {{WEB_ROOT}}/{{USER}}/public_html

    # Cấu hình quyền thư mục web: cấm hiển thị danh sách file khi không có index.html (-Indexes)
    <Directory {{WEB_ROOT}}/{{USER}}/public_html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Bật mã hóa SSL/TLS (HTTPS) với chứng chỉ riêng của domain
    SSLEngine on
    SSLCertificateFile {{SSL_DIR}}/{{DOMAIN}}/selfsigned.crt
    SSLCertificateKeyFile {{SSL_DIR}}/{{DOMAIN}}/selfsigned.key

    # Ghi nhật ký truy cập và nhật ký lỗi vào thư mục riêng của domain
    ErrorLog {{APACHE_LOG_DIR}}/{{DOMAIN}}/error.log
    CustomLog {{APACHE_LOG_DIR}}/{{DOMAIN}}/access.log combined
</VirtualHost>
