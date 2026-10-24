<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Chào mừng đến với {{DOMAIN}}</title>
    <style>
        body { font-family: Arial, sans-serif; background-color: #f4f6f9; color: #333; text-align: center; padding-top: 80px; }
        .card { background: #fff; max-width: 550px; margin: 0 auto; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; }
        .badge { display: inline-block; background: #27ae60; color: #fff; padding: 6px 14px; border-radius: 20px; font-size: 14px; }
        .info { margin-top: 20px; text-align: left; background: #ecf0f1; padding: 15px; border-radius: 6px; }
    </style>
</head>
<body>
    <div class="card">
        <span class="badge">HTTPS Đang Hoạt Động</span>
        <h1>Website {{DOMAIN}} đã sẵn sàng!</h1>
        <p>Gian hàng này được khởi tạo tự động bởi hệ thống <strong>AutoHost</strong>.</p>
        <div class="info">
            <p><strong>Chủ sở hữu (User):</strong> {{USER}}</p>
            <p><strong>Tên miền (Domain):</strong> {{DOMAIN}}</p>
            <p><strong>Thư mục chứa web:</strong> /var/www/{{USER}}/public_html</p>
        </div>
    </div>
</body>
</html>
