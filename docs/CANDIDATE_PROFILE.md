# Candidate Profile Card
+
+Áp dụng migration `20261105000100_candidate_profile.sql` sau migration Auth. Trang `/candidate` đọc/sửa hồ sơ chính chủ, xem trước card, xác nhận trước lưu và quản lý upload CV. Trang `/candidate/public/[id]` chỉ trả card opt-in cho HR đang có membership; không công khai bảng hồ sơ gốc.
+
+- Owner-only: họ tên đầy đủ, cài đặt discoverable, danh sách/đường dẫn CV. Không có contact hoặc điểm test trong card.
+- Card chia sẻ: tên hiển thị, trường/năm học tùy chọn, địa bàn, vị trí/hình thức/lương VND và đơn vị, 3–5 kỹ năng, bio tối đa 30 đơn vị tách bằng khoảng trắng. Cách đếm này là mặc định triển khai Q-14, chưa phải chuẩn ngôn ngữ học.
+- Avatar hiện là chữ cái tên hiển thị, mặc định ẩn; upload ảnh đại diện chưa triển khai.
+- CV: PDF tối đa 5 MB (giới hạn kỹ thuật MVP), kiểm MIME và PDF magic bytes, bucket private, chỉ owner upload/đọc. Signed download TTL 60 giây. Không tự gửi CV sang AI/HR; chưa có malware scanner. Storage và metadata khác transaction, có cleanup khi ghi metadata thất bại; vẫn cần đối soát file mồ côi khi request đứt giữa chừng.
+- `CvExtractionAdapter` chỉ định nghĩa giao diện trả gợi ý, không có provider AI hoặc gọi API thực. Các gợi ý tương lai phải được nạp vào editor, xem lại và xác nhận như dữ liệu nhập thủ công.
+
+Đã kiểm thử validation/projection bằng Node test và ownership/RLS bằng PostgreSQL với Auth/Storage schema giả lập. Chưa có cấu hình Supabase thực để kiểm chứng upload/download qua Storage HTTP hay E2E trình duyệt. Không coi stub Storage là bằng chứng triển khai Storage thật đã hoạt động.
