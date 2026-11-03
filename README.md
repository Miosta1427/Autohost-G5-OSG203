 🌐 Hướng Dẫn Sử Dụng Autohost (Dành Cho Khách Hàng)

Đối tượng áp dụng: Người dùng đã được Quản trị viên (Admin) cấp tài khoản hosting.

👋 Chào mừng bạn đến với Autohost!

Bạn đã được cấp một không gian lưu trữ website riêng biệt và bảo mật. Tài liệu này sẽ hướng dẫn bạn cách đưa website của mình lên internet một cách nhanh chóng và an toàn nhất.

---

📑 Mục lục
1. [Thông tin đăng nhập](#1-thông-tin-đăng-nhập)
2. [Cách tải mã nguồn website lên (Upload)](#2-cách-tải-mã-nguồn-website-lên-upload)
3. [Truy cập website](#3-truy-cập-website)
4. [Lưu ý bảo mật](#4-lưu-ý-bảo-mật)

---

🔑 1. Thông tin đăng nhập

Bạn sẽ nhận được các thông tin truy cập sau từ Quản trị viên (Admin):

| Thuộc tính | Ví dụ | Mô tả |
| :--- | :--- | :--- |
| Username | `alice` | Tên tài khoản của bạn. |
| Password | `********` | Mật khẩu ngẫu nhiên do Admin cấp. |
| Địa chỉ máy chủ | `192.168.159.130` | IP của server chứa website. |
| Tên miền | `alice.autohost.local` | Tên miền riêng của website bạn. |

---

 📤 2. Cách tải mã nguồn website lên (Upload)

> Lưu ý: Vì lý do bảo mật, bạn không thể đăng nhập vào máy chủ bằng SSH. Thay vào đó, bạn sẽ sử dụng giao thức SFTP (Secure File Transfer Protocol).

Các bước thực hiện:

1. Tải và cài đặt phần mềm quản lý file: [FileZilla](https://filezilla-project.org/) hoặc [WinSCP](https://winscp.net/).
2. Tạo kết nối mới (New Site) với các thông số sau:
   - Protocol: `SFTP`
   - Host: `[Địa chỉ máy chủ]`
   - Username: `[Username của bạn]`
   - Password: `[Password của bạn]`
   - Port: `22`
3. Nhấn Connect để kết nối.
4. Khi kết nối thành công, bạn sẽ thấy một thư mục cá nhân. Hãy upload toàn bộ file website của bạn (bao gồm `index.html`, các thư mục `css`, `js`, `images`, v.v.) vào đây.

---

🌐 3. Truy cập website

Sau khi upload thành công, bạn có thể truy cập và kiểm tra website của mình thông qua:

- Địa chỉ chính thức: `https://[tên_miền_của_bạn]` 
  (Website của bạn đã được tích hợp sẵn ổ khóa SSL bảo mật).
- Địa chỉ truy cập nhanh: `http://[IP_máy_chủ]/~[username]/`

---

⚠️ 4. Lưu ý bảo mật

Để đảm bảo an toàn cho hệ thống chung, vui lòng tuân thủ các quy định sau:

- ✅ Bạn chỉ có quyền thao tác trong thư mục của chính mình.
- ❌ Bạn không thể truy cập vào thư mục của người dùng khác hoặc file hệ thống của máy chủ.
- 🔄 Nếu quên mật khẩu, vui lòng liên hệ Quản trị viên để được cấp lại.

---
*Cảm ơn bạn đã sử dụng dịch vụ của Autohost!*
