# Thông báo MVP

Migration `20261105000700_notifications.sql` tạo inbox theo người nhận, khóa chống trùng `(recipient_id,dedupe_key)`, trạng thái `read_at`, chỉ đọc theo RLS. Client đánh dấu đọc qua RPC chính chủ; không được tạo thông báo hay chạy queue. Nội dung UI dùng nhãn cố định, không chứa tên, email, CV, điểm hoặc lời nhắn riêng.

Trigger phát thông báo xác minh email, lời mời ứng tuyển, hoàn thành Micro-test, HR mời phỏng vấn, thay đổi lịch và quyết định/thu hồi CV Consent. Sau khi thành phần báo cáo/cộng đồng có bảng và quyền riêng, adapter tin cậy sẽ phát `report_result` và `community_reply`; hiện không cấp liên kết cho hai loại đó vì chưa có kiểm tra quyền trên đối tượng. Inbox kiểm tra lại quyền trên target tại thời điểm mở, trả target_id null khi quyền đã mất. Trang đích vẫn kiểm tra quyền server/RLS độc lập.

Lịch đã xác nhận tạo job nhắc trước 24 giờ (hoặc ngay nếu lịch gần hơn). `run_due_notification_jobs(batch_size)` xử lý job đến hạn bằng `FOR UPDATE SKIP LOCKED`, kiểm lịch còn confirmed và chưa qua giờ, retry backoff tối đa 5 lần và khóa dedupe. Hàm không cấp execute cho client. Chưa cài pg_cron/scheduler trong môi trường này; deployment cần cấu hình lịch chạy tin cậy. Email sau này dùng cùng queue/outbox nhưng cần worker và policy nội dung riêng, không thêm email vào thông báo hiện tại.

Inbox `/notifications` phân trang 20, empty/error/loading dùng App Router. Tests `supabase/tests/notifications.sql` kiểm tra xác minh, gửi trùng, RLS, đánh dấu đọc, quyền liên kết và không thể chạy queue từ client. Harness SQL dùng Auth/Storage stubs; cần kiểm thử Supabase thật trước production.
