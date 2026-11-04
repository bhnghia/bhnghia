# PRD — V.E.T.T MVP

## Nguồn và phạm vi

Tài liệu này tổng hợp `VETT_CODEX_MASTER_PROMPT.md` (M) và `VETT_HOP_NHAT_LOGIC.md` (H), được cung cấp kèm yêu cầu ngày 04/11/2026. Repo hiện là bài tập C++/Visual Studio, chưa có ứng dụng V.E.T.T. Ký hiệu **Chốt (M/H)** là quy tắc nêu rõ trong nguồn; **Đề xuất** là thiết kế để triển khai, cần xác nhận nếu ảnh hưởng nghiệp vụ. Các điểm chưa rõ có mã Q trong [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md). Đây là đặc tả sản phẩm, chưa phải xác nhận tuân thủ pháp luật.

## Mục tiêu và ranh giới

Nền tảng tuyển dụng dựa trên kỹ năng ở Việt Nam: ứng viên kiểm soát hồ sơ/CV, doanh nghiệp quản lý tuyển dụng theo tổ chức, bài test tùy chọn, phỏng vấn có đồng ý, cộng đồng có kiểm duyệt và báo cáo an toàn hai chiều. MVP đầu tiên phải chứng minh luồng ứng tuyển không có test với cô lập dữ liệu giữa hai doanh nghiệp; các phân hệ khác được bổ sung theo milestone.

**Chốt (M):** không thu phí ứng viên/giữ giấy tờ gốc trong nội dung job; không có match hai chiều từ thao tác lưu job; không lọc theo tuổi, giới, tôn giáo, dân tộc, tình trạng hôn nhân; không tự động loại ứng viên bằng AI. Thanh toán, ML chấm ứng viên, theo dõi thiết bị nằm ngoài MVP.

## Vai trò

- Candidate: tạo hồ sơ, khám phá/lưu/ứng tuyển, làm test, quản lý lịch và CV, đăng cộng đồng, báo cáo.
- Recruiter: thành viên một hoặc nhiều tổ chức, quản lý job/test/ứng tuyển và lời mời trong phạm vi được cấp.
- Organization Admin: quản lý thành viên, thông tin tổ chức và yêu cầu xác minh; không tự cấp badge.
- Moderator: kiểm duyệt nội dung/sự cố, xử lý kháng nghị trong phạm vi được cấp.
- Platform Admin: xác minh doanh nghiệp, cấu hình chính sách, phân quyền nền tảng và audit. **Đề xuất:** tách nhiệm vụ xác minh và xử lý tố cáo theo quyền chi tiết.

## B2C: hồ sơ và tìm việc

**Chốt (M/H):** xác minh email; Profile Card một lớp gồm tên/tên rút gọn, avatar mặc định ẩn, trường/năm học tùy chọn, nơi ở cấp quận-huyện/thành phố, việc và hình thức mong muốn, lương kỳ vọng kèm đơn vị, 3–5 kỹ năng, bio tối đa 30 từ. `discoverable=false` mặc định, bật/tắt được; không công khai liên hệ, CV gốc hoặc điểm test. Upload CV vào kho private; AI parse, nếu có, chỉ gợi ý và phải được ứng viên xác nhận.

**Chốt (M):** Job Card lớp 1 gồm logo/tên/badge đã xác minh, tiêu đề, địa điểm, dải lương với đơn vị và gross/net, hình thức, ba kỹ năng, lưu riêng tư và ứng tuyển. Lớp 2 có địa chỉ chi nhánh, JD, yêu cầu, quyền lợi, cam kết không thu phí/giữ giấy tờ gốc, thông tin test. Saved jobs chỉ ứng viên thấy. Job công bố khi tổ chức đủ điều kiện và trường bắt buộc hợp lệ; cảnh báo lương tối thiểu dùng bảng luật version do admin cấu hình, không suy đoán mức cố định hay chặn khi thiếu dữ kiện so sánh.

## B2B: tổ chức và tuyển dụng

**Chốt (M/H):** thành viên có thể thuộc nhiều tổ chức; mọi job, test, application và lịch theo `organization_id`. Tổ chức có trạng thái `pending/verified/rejected/suspended`; badge chỉ sau kiểm duyệt MST và ĐKKD, không tự cấp khi nhập MST. Recruiter thấy ứng tuyển của job thuộc tổ chức mình và chỉ tìm hồ sơ bật discoverable. Có thể gửi lời mời, nhưng không tự mở CV hay ép đồng ý. Insights Community chỉ gồm nội dung công khai có tag tổ chức và dữ liệu tổng hợp, không tiết lộ tác giả ẩn danh.

## Ứng tuyển và Micro-test

**Chốt (M/H):** job không bật test: Apply tạo application và chia sẻ Profile Card, không kèm CV gốc. Job bật test: Apply tạo `test_pending`, bắt đầu attempt, nộp thành `test_submitted`, chấm trắc nghiệm bằng đáp án chính xác, tự luận do HR chấm tay trước `under_review`. Bank mỗi job bật test có ít nhất 10 trắc nghiệm tình huống; mỗi attempt chọn ngẫu nhiên 3 câu. Số câu ngắn **chưa chốt**: M và H nêu 0–3, H cũng ghi nguồn TXT nói 1–3 (Q-01). Câu ngắn tối đa 300 ký tự. Mỗi câu có min/max seconds hợp lệ, tổng thời gian hiển thị trước khi bắt đầu. Min time không phải bằng chứng chống gian lận. Snapshot câu hỏi/version/thứ tự và deadline đặt ở server; không lộ đáp án; chống thi lại theo policy cần xác nhận. Điểm chỉ recruiter thuộc tổ chức sở hữu job xem.

## Phỏng vấn và CV consent

**Chốt (M/H):** lời mời/lịch cần ứng viên chấp nhận. Chấp nhận lịch không đồng nghĩa chia sẻ CV; cần hành động đồng ý riêng của ứng viên. Quyền CV phải gắn tổ chức, job/application, hết hạn và thu hồi; thông báo rõ rằng bản tải trước khi thu hồi không thể lấy lại. Hai bên phản hồi kết quả phỏng vấn. Khảo sát gửi sáng hôm sau theo giờ Việt Nam qua tác vụ chống trùng. Thời hạn CV và các mốc giờ chưa chốt (Q-04, Q-05).

## Community và Trust & Safety

**Chốt (M/H):** post/comment có tag tổ chức/vai trò, tìm kiếm, vote một lần mỗi người/mục, bookmark, report, soft delete, queue kiểm duyệt và audit. Ẩn danh đối với công chúng; danh tính nội bộ chỉ người có quyền truy vết. Trả lời nhãn official chỉ khi tổ chức `verified` và người trả lời có quyền đại diện. Cáo buộc chưa xác minh không tự công khai.

**Chốt (M/H):** ứng viên và doanh nghiệp đều có thể báo cáo sự cố; bên bị báo cáo được phản hồi, nộp chứng cứ và khiếu nại. Report private; chỉ báo cáo đã xác nhận từ ít nhất ba đối tác độc lập trong 12 tháng mới là điều kiện xem xét cảnh báo, và moderator phải duyệt trước khi đăng bản tóm tắt có phản hồi. Scam khẩn có thể tạm ẩn job sớm với audit và appeal. Tiêu chí độc lập đối với báo cáo doanh nghiệp, chống lạm dụng, danh mục và thời hạn xử lý chưa chốt (Q-06–Q-08).

## Tiêu chí nghiệm thu theo sản phẩm

1. Ứng viên chưa opt-in không xuất hiện trong tìm kiếm; URL public không đọc được CV/ĐKKD.
2. Token của tổ chức A không đọc được ứng tuyển/điểm/CV của B; FK chéo tenant bị từ chối.
3. Lưu job không tạo notification/match cho recruiter.
4. Ứng tuyển không test không có attempt; bật test phát đúng ba MCQ và số câu ngắn theo quyết định Q-01; khóa đáp án không xuất ra client.
5. Deadline, đáp án trắc nghiệm và điểm do server kiểm soát; tự luận do HR chấm.
6. CV grant chỉ sau accept và consent riêng; revoke/expiry chặn lượt tải tiếp theo.
7. Nhãn official, ẩn danh forum, vote unique và report chưa duyệt được kiểm tra bằng token/quyền thực.
8. Ba report cùng một bên không biến thành ba đối tác; khiếu nại có trạng thái; phân quyền admin không tự leo thang.
