🌐 Hướng Dẫn Sử Dụng Autohost (Dành Cho Khách Hàng)

Đối tượng áp dụng: Người dùng đã được Quản trị viên (Admin) cấp tài khoản hosting.

👋 Chào mừng bạn đến với Autohost!

Bạn đã được cấp một không gian lưu trữ website riêng biệt và bảo mật. Chỉ cần làm theo 4 bước dưới đây là website của bạn sẽ lên sóng:

Nhận thông tin → Khai báo tên miền → Upload file → Xem website

📑 Mục lục
Thông tin đăng nhập
Chuẩn bị trên máy của bạn (làm 1 lần)
Tải mã nguồn website lên (Upload)
Truy cập website
Xử lý lỗi thường gặp
Lưu ý bảo mật
🔑 1. Thông tin đăng nhập

Admin sẽ gửi cho bạn một lần duy nhất các thông tin sau:

Thuộc tính	Ví dụ	Mô tả
Username	alice	Tên tài khoản của bạn
Password	********	Mật khẩu ngẫu nhiên do Admin cấp
Địa chỉ máy chủ	192.168.159.130	IP của server chứa website
Tên miền	alice.autohost.local	Tên miền riêng của website bạn
Port	22	Cổng kết nối SFTP

💡 Hãy lưu mật khẩu vào nơi an toàn ngay khi nhận được. Phân biệt chữ hoa/thường, nên copy-paste thay vì gõ tay để tránh nhầm (ví dụ l và I, 0 và O).

🖥️ 2. Chuẩn bị trên máy của bạn (làm 1 lần)

Tên miền .local chỉ là tên nội bộ, không có trên Internet. Máy của bạn cần được “chỉ đường” đến server thì mới mở được. Bước này giống như lưu tên bạn bè vào danh bạ điện thoại kèm số.

Nếu bạn dùng Windows
Bấm nút Start, gõ Notepad, chuột phải → Run as administrator.
Trong Notepad: File → Open, dán đường dẫn sau vào ô tên file rồi Enter:
   C:\Windows\System32\drivers\etc\hosts

(Nếu không thấy file, đổi ô lọc từ Text Documents sang All Files.)
3. Kéo xuống cuối file, thêm 1 dòng (thay IP và tên miền bằng thông tin Admin gửi cho bạn):

   192.168.159.130   alice.autohost.local
Lưu file (Ctrl + S).
Nếu bạn dùng Linux / macOS

Mở Terminal và chạy:

echo "192.168.159.130 alice.autohost.local" | sudo tee -a /etc/hosts

Kiểm tra: mở Command Prompt (hoặc Terminal), gõ ping alice.autohost.local. Nếu thấy hiện đúng địa chỉ IP của server là thành công.

📤 3. Tải mã nguồn website lên (Upload)

Lưu ý: Vì lý do bảo mật, bạn không thể đăng nhập vào máy chủ bằng SSH. Bạn dùng giao thức SFTP (Secure File Transfer Protocol) để chuyển file.

Bước 3.1: Cài phần mềm

Tải và cài một trong hai (miễn phí): FileZilla hoặc WinSCP.

Bước 3.2: Kết nối

Với FileZilla: vào File → Site Manager → New Site, điền:

Ô	Giá trị
Protocol	SFTP - SSH File Transfer Protocol
Host	IP máy chủ (ví dụ 192.168.159.130)
Port	22
Logon Type	Normal
User	Username của bạn
Password	Mật khẩu Admin cấp

Bấm Connect. Lần đầu sẽ hiện hộp thoại “Unknown host key”: tick Always trust this host rồi bấm OK.

Với WinSCP: chọn File protocol = SFTP, điền Host name, Port, User name, Password rồi bấm Login. Hộp thoại hỏi host key thì bấm Yes.

Bước 3.3: Upload đúng chỗ
Cột bên trái là máy của bạn, cột bên phải là server.
Phía server, hãy vào thư mục public_html. Đây là “mặt tiền” của website, chỉ file nằm trong đây mới được hiển thị ra ngoài.
Kéo thả toàn bộ file website từ trái sang phải.

Cấu trúc đúng sẽ như sau:

public_html/
├── index.html      ← BẮT BUỘC, trang chủ của bạn
├── css/
├── js/
└── images/

Các quy tắc cần nhớ:

File trang chủ phải tên chính xác là index.html (viết thường, không phải Index.html hay trangchu.html). Linux phân biệt chữ hoa/thường.
Upload nội dung bên trong thư mục website, không upload nguyên thư mục cha. Nếu không, địa chỉ sẽ thành .../ten-thu-muc/index.html thay vì trang chủ.
Tên file nên dùng chữ không dấu, không khoảng trắng (ví dụ anh-bia.jpg).
🌐 4. Truy cập website

Sau khi upload xong:

Địa chỉ chính thức: https://[tên_miền_của_bạn] (ví dụ https://alice.autohost.local)
Địa chỉ truy cập nhanh: http://[IP_máy_chủ]/~[username]/
⚠️ Cảnh báo “Kết nối không an toàn”

Website dùng chứng chỉ SSL tự ký (do Autohost tự tạo, chưa qua nhà cung cấp bên ngoài). Vì vậy trình duyệt sẽ hiện cảnh báo ở lần đầu. Đây là bình thường, dữ liệu vẫn được mã hóa.

Trình duyệt	Cách bỏ qua cảnh báo
Chrome / Edge	Bấm Advanced → Continue to ... (unsafe)
Firefox	Bấm Advanced → Accept the Risk and Continue

💡 Mỗi lần bạn sửa file và upload lại, hãy nhấn Ctrl + F5 để trình duyệt tải bản mới thay vì dùng bản cũ trong bộ nhớ đệm.

🛠️ 5. Xử lý lỗi thường gặp
Hiện tượng	Nguyên nhân thường gặp	Cách xử lý
Không mở được tên miền (“This site can’t be reached”)	Chưa khai báo tên miền ở Bước 2	Làm lại Bước 2, kiểm tra bằng ping
FileZilla báo “Connection timed out”	Sai IP hoặc máy chủ chưa bật	Kiểm tra lại IP, hỏi Admin xem server đang chạy chưa
“Authentication failed” / “Access denied”	Sai username hoặc password	Copy-paste lại thông tin, chú ý chữ hoa/thường, không dính khoảng trắng
Cố đăng nhập bằng SSH/PuTTY bị từ chối	Tài khoản chỉ được dùng SFTP	Dùng FileZilla hoặc WinSCP
Mở web ra thấy trang mặc định của Apache hoặc danh sách file	Thiếu index.html hoặc upload sai thư mục	Đảm bảo index.html nằm trực tiếp trong public_html
Lỗi 403 Forbidden	File/thư mục bị sai quyền	Liên hệ Admin để kiểm tra phân quyền
Lỗi 404 Not Found	Sai tên file hoặc đường dẫn	Kiểm tra chữ hoa/thường, đường dẫn trong code HTML
Web hiện nhưng mất ảnh hoặc CSS	Đường dẫn trong code sai	Dùng đường dẫn tương đối, ví dụ css/style.css thay vì C:\Users\...
Quên mật khẩu		Liên hệ Admin để được cấp lại
⚠️ 6. Lưu ý bảo mật
✅ Bạn chỉ có quyền thao tác trong thư mục của chính mình.
❌ Bạn không thể truy cập thư mục của người dùng khác hoặc file hệ thống của máy chủ.
🔒 Không chia sẻ mật khẩu cho bất kỳ ai, kể cả người tự xưng là Admin qua tin nhắn.
🔄 Quên mật khẩu hoặc nghi ngờ lộ mật khẩu: báo ngay cho Admin để được cấp lại.
🚫 Không upload file chứa thông tin nhạy cảm (mật khẩu, khóa API, file .env) vào public_html, vì mọi file trong đó đều có thể bị người khác tải về.

Cần hỗ trợ? Liên hệ Quản trị viên: Minh, Huân, Hoàng

Cảm ơn bạn đã sử dụng dịch vụ của Autohost!
