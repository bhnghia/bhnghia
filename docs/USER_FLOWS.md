# Luồng người dùng MVP

Mỗi luồng là đặc tả hành vi từ M/H; dấu **[đề xuất]** chỉ cách triển khai hoặc điều kiện chưa được nguồn chốt. Các quyết định còn mở nằm trong [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md).

## 1. Candidate tạo hồ sơ và tìm việc

1. Đăng ký, xác minh email; tạo Profile Card, chọn 3–5 kỹ năng, nhập bio ≤30 từ, thiết lập avatar ẩn và discoverable tắt mặc định.
2. Có thể upload CV private; nếu có AI parse, xem/chỉnh/sửa/xác nhận gợi ý trước khi ghi hồ sơ. Không hiển thị CV gốc hoặc liên hệ trên card public.
3. Xem Job Card hai lớp, lọc theo việc/kỹ năng/địa điểm/hình thức/lương phù hợp; không có bộ lọc phân biệt đối xử.
4. Lưu job: chỉ ghi vào danh sách riêng, không thông báo recruiter. Apply: xem rõ Profile Card nào được chia sẻ; CV không đính kèm.
5. Tắt discoverable bất kỳ lúc nào; ứng tuyển đã gửi cần chính sách lưu snapshot riêng (Q-10).

## 2. Tổ chức đăng job và xử lý ứng tuyển

1. Org admin tạo tổ chức/chi nhánh, nộp MST + ĐKKD private; admin xét duyệt. Badge chỉ khi verified.
2. Recruiter được cấp membership, tạo Job Card hai lớp, công bố khi đủ điều kiện. Trường hợp pending review và điều kiện đầy đủ ở Q-03.
3. Recruiter xem ứng tuyển cho job thuộc org mình; đổi org trong UI phải đổi scope truy vấn. Token org A không đọc được hồ sơ ứng tuyển của B.
4. Recruiter tìm profile `discoverable=true` hoặc xem profile được ứng viên gửi vào job tương ứng; lời mời không mở CV. Chống spam lời mời Q-11.

## 3. Apply với Micro-test tùy chọn

- Không bật test: Apply → tạo application → recruiter thấy Profile Card trong org/job. Không có attempt.
- Bật test: trước công bố cần bank ≥10 MCQ, min/max mỗi câu hợp lệ; trước bắt đầu hiển thị tổng thời gian. Apply → `test_pending`; server phát attempt snapshot gồm 3 MCQ ngẫu nhiên và số câu tự luận theo Q-01; snapshot lưu version/thứ tự/deadline. Client không nhận đáp án.
- Candidate nộp trước deadline → `test_submitted`; server chấm MCQ; HR chấm câu tự luận tối đa 300 ký tự → `under_review`. Không có AI reject. **[Đề xuất]** reconnect tải attempt cũ, không phát câu mới; timeout/retry theo Q-02.

## 4. Lời mời, lịch và CV

1. Recruiter gửi lời mời gắn job/org; candidate nhận lịch proposed và cảnh báo an toàn.
2. Candidate accept, decline hoặc yêu cầu đổi lịch; hai bên có thể cancel theo policy chưa chốt. Accept chỉ xác nhận lịch.
3. Candidate chọn đồng ý chia sẻ CV bằng thao tác riêng, biết org/job, thời hạn và khả năng tải file; server tạo grant. Nếu không đồng ý, recruiter vẫn không đọc CV.
4. Recruiter yêu cầu tải: server kiểm membership, org/job, appointment accepted, grant chưa hết hạn/chưa thu hồi; trả signed URL ngắn hạn và audit. Candidate revoke chặn lượt cấp URL kế tiếp.
5. Sau phỏng vấn, hai bên phản hồi riêng; job idempotent gửi khảo sát sáng hôm sau theo giờ Việt Nam. `no_show_disputed` không tự biến thành sự cố confirmed.

## 5. Community và an toàn

1. User đăng post/comment với tag công ty/vai trò; chọn ẩn danh với công chúng. Search và API public chỉ trả pseudonym, không trả author ID/metadata riêng.
2. Vote/bookmark/report; một vote trên mỗi mục/người. Nội dung cáo buộc chưa xác minh qua hàng đợi kiểm duyệt. Verified org representative có thể trả lời official theo quyền server.
3. Candidate hoặc org báo sự cố, nộp bằng chứng private; bên bị báo cáo được phản hồi/appeal. Moderator duyệt; chưa duyệt không hiện công khai.
4. Khi đủ điều kiện ba đối tác độc lập trong 12 tháng và qua anti-abuse + moderator approval, chỉ hiển thị warning tóm tắt và phản hồi; không lộ chứng cứ. Scam khẩn có thể tạm ẩn job với audit và appeal trước ngưỡng ba.

## Trạng thái giao diện tối thiểu

Mọi màn hình có loading, empty, validation error, permission denied và retry rõ ràng. Job card lớp 2 dùng trang chi tiết/dialog điều hướng bàn phím được; không phụ thuộc hiệu ứng flip. Consent và public/private được gắn nhãn tiếng Việt dễ hiểu. Các nút phải có hành động thực khi milestone tương ứng được phát hành.
