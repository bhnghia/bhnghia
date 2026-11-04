# Micro-test MVP

Migration `20261105000400_microtest.sql` chạy sau application state machine. Không seed câu hỏi production. HR tạo nội dung tình huống phù hợp vị trí; hệ thống kiểm tra cấu trúc, không tự xác nhận chất lượng nội dung.

## Cấu hình và phiên làm bài

HR thuộc tổ chức của Job sửa ngân hàng/cấu hình khi Job draft, paused hoặc pending_review. Bật test cần >=10 câu trắc nghiệm active và đủ 0–3 câu viết được chọn. Mỗi câu trắc nghiệm có 2–6 lựa chọn, đúng một đáp án. HR đặt thời gian min/max từng câu; tổng dự kiến được tính từ các câu được chọn, hiển thị khoảng trước random và tổng chính xác trước bắt đầu.

Ứng viên chuẩn bị đề một lần: server random 3 câu trắc nghiệm không trùng và số câu viết đã chọn. Snapshot lưu nội dung, lựa chọn, đáp án riêng, phiên bản bank, thời gian; thay đổi bank không ảnh hưởng attempt. Chuẩn bị chưa khởi động đồng hồ và chưa gửi nội dung đề. Start idempotent: reconnect không random lại hoặc reset deadline. Một application có tối đa một attempt, chưa có retry/đặc cách.

Khung giờ các câu nối tiếp theo max_seconds, bắt đầu tính bằng clock database; min_seconds là hướng dẫn. Được sửa và lưu đáp án trong khung giờ `[opens_at, deadline)`. Không chuyển sớm khung giờ; nộp sớm toàn bài chỉ khi câu cuối đã mở. UI dùng đồng hồ server để hiển thị; quyền ghi do database quyết định sau khi lấy row lock. Câu viết tối đa 300 ký tự tại database, server validation và UI. Ứng viên phải bấm lưu từng câu, dữ liệu chưa lưu sẽ không được nộp; mất mạng không dừng giờ.

Job đóng không hủy application/attempt có sẵn. Attempt đã chuẩn bị giữ snapshot; nếu chưa chuẩn bị thì dùng cấu hình hợp lệ hiện tại của bank.

## Trạng thái và transaction

`prepared -> issued -> submitted`; `expired` chỉ giữ tương thích dữ liệu cũ. Submit lặp lại không tạo điểm/audit mới. Hết hạn tự chốt các câu đã lưu, đánh dấu auto_submitted; không nhận đáp án muộn. `get_test_player`, `refresh_hr_test` và submit chốt bài quá hạn trong transaction. Nếu không ai mở lại trang, trạng thái lưu có thể vẫn issued cho tới lần xử lý kế tiếp, nhưng đáp án muộn luôn bị từ chối.

Có hàm nội bộ `finish_due_microtests()` cho lịch chạy tin cậy (ví dụ pg_cron do quản trị cấu hình); không cấp execute cho anon/authenticated và không mở API service_role. Chưa cài scheduler trong môi trường này. Cần cấu hình lịch trước khi yêu cầu trạng thái tự cập nhật khi mọi người đã offline.

Trắc nghiệm đúng được 1 điểm, sai/bỏ trống 0. Viết do HR chấm 0–5, không tự chấm câu bỏ trống. Tổng tối đa `3 + 5 × số câu viết`, là điểm thô không phải phần trăm/xếp hạng. Chưa chấm đủ viết: application test_submitted; chấm đủ: under_review. Không có viết thì chuyển under_review ngay sau nộp. HR được sửa điểm viết trước khi chấm đủ; hoàn tất khóa điểm, retry cùng điểm là no-op. Không tự loại hay AI screening.

Các RPC prepare/start/save/submit/grade chạy transaction, khóa hàng attempt để tuần tự hóa ghi đáp án, nộp và chấm. Unique application_id ngăn attempt trùng; unique attempt_id ngăn điểm tổng trùng. Cập nhật attempt, điểm, application và audit chốt cùng transaction. Khi nâng cấp dữ liệu có nhiều attempt/application hoặc nhiều điểm/attempt, unique constraint sẽ dừng migration; cần rà soát dữ liệu thật, không tự xóa lịch sử.

## Quyền và dữ liệu

Bank, snapshot, đáp án ứng viên, điểm tổng, điểm viết và audit có RLS theo tổ chức của Job; kiểm tra membership hiện tại và email xác minh. Ứng viên chỉ đọc projection RPC của application mình, không đọc trực tiếp snapshot/key/grade. Projection không trả đáp án đúng hoặc điểm kể cả sau hoàn tất; chỉ trạng thái chờ chấm/đã chuyển HR. Bảng khóa đáp án không có quyền SELECT cho client. Mọi ghi đi qua RPC kiểm tra quyền; client không sửa timer, trạng thái hay điểm trực tiếp. Không dùng CV gốc trong test.

## Màn hình và kiểm thử

- `/organization/[id]/jobs/[jobId]/test`: ngân hàng, thêm/sửa/ngừng dùng câu, bật/tắt và số câu viết.
- `/applications/[id]/test`: chuẩn bị, xem thời gian, bắt đầu, player và trạng thái kết quả.
- `/organization/[id]/grading/[attemptId]`: HR xem câu trả lời, điểm và chấm viết.

`tests/microtest.test.ts` kiểm tra validation và biên thời gian. `supabase/tests/microtest.sql` kiểm tra ngân hàng tối thiểu, random không trùng, snapshot bất biến, ownership/RLS, không lộ key/điểm, reset timer bị chặn, câu chưa mở/hết giờ, nộp trùng, chấm tay và tự chốt sau khi Job đóng. Harness chạy toàn bộ migration trên PostgreSQL 17 với Auth/Storage stubs; không thay thế Supabase thật hoặc browser E2E.

Các lựa chọn retry, lịch từng câu, thang điểm viết và timeout là mặc định triển khai được công khai trong UI; Product cần xác nhận trước phát hành (Q-02 và phần giả định trong OPEN_QUESTIONS.md). Không có Supabase cấu hình trong môi trường nên chưa xác minh HTTP/Auth/token và trải nghiệm trình duyệt với dữ liệu thật.
