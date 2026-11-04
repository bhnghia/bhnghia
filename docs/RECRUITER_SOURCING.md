# Recruiter Dashboard và Sourcing

Migration `20261105000500_recruiter_sourcing.sql` bổ sung RPC dashboard, sourcing và lời mời có quota. Tất cả yêu cầu membership hiện tại có email xác minh, không dùng service_role.

Dashboard `/organization/[id]/dashboard` thống kê Job/applicant, bài đã nộp còn chờ chấm viết, application submitted/under_review chờ HR review và lịch proposed/confirmed. Không coi interview_invited là lịch đã đề xuất. Bảng interview_appointments là contract lưu lịch có RLS/composite tenant FK; chưa cấp quyền ghi hoặc xây workflow tạo/xác nhận lịch ở nhiệm vụ này. Danh sách lịch chỉ đọc dữ liệu thật, rỗng khi chưa có lịch.

Sourcing `/organization/[id]/sourcing` gồm snapshot application thuộc đúng tenant và projection profile discoverable hiện tại. Snapshot vẫn xem được sau tắt opt-in theo chính sách application hiện có. Filter kỹ năng, quận/tỉnh, vị trí, hình thức, mức lương tối đa cùng đơn vị (VND), Job và trạng thái. Không lấy full_name, liên hệ riêng, CV, avatar path hay điểm vào projection. Điểm xem qua trang application/grading hiện có với RLS theo Job; không tổng hợp điểm từ Job khác. Phân trang server 20 bản ghi, thứ tự ổn định; giới hạn trang và đầu vào. Bộ chọn Job lời mời giới hạn 100 Job published, để tránh tải danh sách vô hạn.

Lời mời chỉ cho profile đang opt-in và Job published của tổ chức verified; test invitation yêu cầu Job bật test. Không mời khi đã ứng tuyển. Unique Job/candidate/loại giúp retry idempotent. Khóa organization và candidate trước khi kiểm quota và ghi để tránh HR gửi đồng thời vượt hạn mức. Inbox `/candidate/invitations` dùng RLS chính chủ; lời mời không tạo application, không khởi động timer, không mở CV. Ứng viên tự xem Job và xác nhận ứng tuyển qua luồng hiện có. Chưa gửi email/push.

Giả định MVP Q-11: 20 lời mời mới/tổ chức/ngày UTC, tối đa 3 lời mời tới một ứng viên trong 30 ngày trên mọi tổ chức. Giá trị nằm trong sourcing_limits chỉ quản trị DB được sửa; client không có quyền đọc/ghi. Tắt discoverable chặn lời mời mới; lời mời đã gửi giữ trong inbox. Bản ghi lời mời lưu người gửi/thời gian làm lịch sử. Cần Product chốt hạn mức, opt-out riêng và retention trước phát hành.

Loading/error dùng boundary chung của App Router; bảng/card có empty state. Dashboard, sourcing, applicants, inbox và lịch có pagination. Không seed dữ liệu production.

Kiểm thử `supabase/tests/sourcing.sql`: whitelist, opt-in, filter, pagination, retry trùng, quota, chặn profile private, tenant isolation, thu hồi membership, inbox chính chủ. Chạy toàn bộ migration/tests bằng PostgreSQL Docker với Auth/Storage stubs; chưa xác minh Supabase HTTP hoặc browser E2E khi thiếu cấu hình Supabase thật.
