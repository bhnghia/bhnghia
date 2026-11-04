# Interview và CV Consent

HR đề xuất lịch từ application ở trạng thái interview_invited. Thời điểm lưu timestamptz; nhập ISO 8601 có offset, múi giờ IANA dùng để hiển thị. Database chặn thời gian đã qua, vô hạn, timezone không hợp lệ. Một application có một lịch đang hoạt động. HR sửa đề xuất hoặc phản hồi yêu cầu đổi lịch; revision ngăn ứng viên xác nhận bản cũ. Lịch đã xác nhận được khóa, chưa triển khai hủy/đổi lịch đã xác nhận.

Ứng viên chọn confirmed, declined hoặc reschedule_requested. Xác nhận bắt buộc quyết định CV yes/no riêng, không chọn sẵn. Không chia sẻ CV vẫn xác nhận được. Đồng ý phải chọn file chính chủ; grant gắn file, application, tổ chức và lịch. Thời hạn mặc định MVP là mốc sớm hơn giữa 7 ngày từ cấp và 24 giờ sau lịch; cần Product chốt Q-04 trước phát hành. Thu hồi do chính chủ, idempotent, audit ghi cấp/từ chối/thu hồi và lần kiểm quyền tải.

RPC authorize_interview_cv kiểm membership hiện tại, lịch confirmed, consent đồng ý, chưa hết hạn/thu hồi và CV đúng chủ. API `/api/interview-cv?application=...` dùng session SSR để gọi RPC trước, sau đó server-only SUPABASE_SERVICE_ROLE_KEY ký đúng object_path trả về với TTL tối đa 30 giây và không vượt hạn consent. Không nhận object path hay TTL từ client. Không cấp thêm Storage SELECT cho HR, tránh client tự ký URL dài hạn. Bucket giữ private; URL trả no-store. Secret chỉ cấu hình ở server, không dùng NEXT_PUBLIC. Thiếu cấu hình trả 503, không fallback public URL.

Thu hồi chặn lần cấp URL tiếp theo; URL đã cấp có thể còn hiệu lực tối đa 30 giây, không thu hồi được bản đã tải. Audit access_authorized ghi việc kiểm quyền, không khẳng định đã tải thành công. Signed URL là bearer link; không ghi URL vào log.

Inbox `/interviews`, chi tiết `/interviews/[id]`, HR calendar dạng danh sách phân trang `/organization/[id]/interviews`. Loading/error kế thừa boundary chung, empty state riêng. Chi tiết có dialog CV, trạng thái, địa điểm và lời nhắc an toàn về tiền đặt cọc/giấy tờ gốc. Không gửi email tự động.

Kiểm thử SQL kiểm tra không đồng ý, consent bắt buộc, đổi lịch, cấp hợp lệ, hết hạn, thu hồi lặp, audit và tenant khác. PostgreSQL harness dùng Auth/Storage stubs; cần kiểm thử Supabase HTTP/Storage thật với secret server và token thật trước triển khai production.
