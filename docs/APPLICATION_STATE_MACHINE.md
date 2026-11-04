# Application State Machine

| Trạng thái nguồn | Đích | Người thực hiện |
| --- | --- | --- |
| Chưa có hồ sơ, job đang published | submitted (không test) / test_pending (có test) | Candidate xác minh email |
| submitted | under_review | HR đúng org |
| test_pending | test_submitted | Bộ xử lý test tin cậy sau nộp bài |
| test_submitted | under_review | Bộ xử lý test xác nhận chấm hoàn tất |
| under_review | interview_invited / rejected | HR đúng org, quyết định thủ công |

Hai trạng thái cuối là terminal trong phạm vi MVP này. `interview_invited` là ý định mời và thông điệp ứng viên xem được; chưa tạo lịch, gửi email hoặc cấp CV. Module phỏng vấn sẽ bổ sung các bước đó. Không có AI tự động loại.

Một candidate có một application/job, kể cả đã bị từ chối; retry Apply trả ID cũ và không thay snapshot/trạng thái. Unique constraint xử lý concurrent requests; job khóa SHARE khi apply, khóa UPDATE khi đóng nên transaction thắng trước quyết định có nhận hồ sơ mới hay không. HR review khóa application, so expected state, update và audit cùng transaction. Retry cùng target là no-op, không tạo audit trùng; quyết định khác từ state cũ bị từ chối.

Mặc định MVP mới: đóng job chỉ ngừng nhận ứng tuyển mới, không hủy ứng tuyển đang có. Test và review đang tiến hành vẫn hoàn tất, không tự từ chối hay reset timer. Q-02 về retry/deadline test vẫn chưa chốt. Lưu Job riêng tư độc lập hoàn toàn, không đòi match hai chiều.

Candidate đọc hồ sơ/audit của mình; HR đọc và quyết định trong org có membership hiện tại. Không cấp quyền UPDATE application trực tiếp. Trigger bảo vệ cạnh chuyển trạng thái và không cho đổi tenant, candidate, job hoặc Profile Card snapshot. Audit append-only với actor, trạng thái cũ/mới, thời điểm; không chép CV, điểm hoặc nội dung nhạy cảm vào log.

Điểm nối `application_test_event` không cấp EXECUTE cho anon/authenticated và không có API client. Migration `20261105000400_microtest.sql` bổ sung bank, snapshot, player và chấm bài. RPC nội bộ chốt attempt, cập nhật điểm và phát sự kiện trong cùng transaction; chỉ đặt `review_ready_at` khi chấm đủ. Job bật test được publish khi bank hợp lệ. Xem [MICROTEST.md](MICROTEST.md).

Trang `/applications`, `/applications/[id]`, `/organization/[id]/applicants` cung cấp danh sách, chi tiết, snapshot card, trạng thái và lịch sử. Các lỗi/empty dùng giao diện tiếng Việt và boundary hiện có. Chưa có Supabase project để E2E bằng token/HTTP thật; SQL regression sử dụng Auth/Storage stub của harness PostgreSQL.
