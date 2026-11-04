# Câu hỏi mở và mâu thuẫn cần xác nhận

Q-04 — triển khai Interview/CV Consent dùng mặc định MVP: grant tối đa 7 ngày hoặc 24 giờ sau lịch (mốc sớm hơn), URL tối đa 30 giây, chủ tài khoản thu hồi bất kỳ lúc nào. Các con số cần Product xác nhận trước phát hành; xem INTERVIEW_CONSENT.md. Chưa hỗ trợ đổi/hủy lịch đã confirmed.

Không mục nào dưới đây được coi là quy tắc đã chốt. Mỗi quyết định cần ghi người duyệt, ngày, nguồn và cập nhật PRD/state/test trước khi triển khai hành vi liên quan. Có thể xây phần nền độc lập trước.

| Mã | Điểm chưa rõ / xung đột | Mặc định thiết kế an toàn để tiếp tục | Cần xác nhận |
| --- | --- | --- | --- |
| Q-01 — đã chốt | Nguồn cũ mâu thuẫn 0–3 / 1–3 câu viết. | Người dùng yêu cầu trực tiếp 0–3 trong nhiệm vụ Micro-test ngày 04/11/2026. | Không còn chặn; triển khai 0–3. |
| Q-02 | Số lượt làm lại test, xử lý mất mạng/rời trang và timeout chưa chốt. | Một attempt cho mỗi application; reconnect đọc snapshot và deadline cũ; server từ chối sửa đáp án sau deadline; bản triển khai tự chốt các câu đã lưu khi hết giờ (xem MICROTEST.md). | Product/HR: có retry/đặc cách không; timeout là `expired` hay tự nộp? |
| Q-03 | Bước `pending_review` của job là “nếu cần”; “đủ điều kiện” công bố chưa định nghĩa đầy đủ. | Chưa tự công bố khi tổ chức chưa verified; admin duyệt job theo policy cấu hình. | Điều kiện công bố/duyệt và quyền sửa job đã published? |
| Q-04 | CV grant cần thời hạn nhưng không có TTL và policy xóa/lưu trữ. | TTL ngắn, private bucket; chưa tự động xóa khi chưa có chính sách. | TTL, retention, yêu cầu xóa/đối soát và pháp lý. |
| Q-05 | Khảo sát “sáng hôm sau” và lịch reschedule/no-show thiếu giờ, múi giờ địa điểm, deadline xác nhận. | Lưu UTC, hiển thị Asia/Ho_Chi_Minh, job idempotent; không gửi cho lịch chưa hoàn thành. | Giờ gửi, điều kiện no-show và ai được xác nhận completed. |
| Q-06 | “3 đối tác độc lập” cho report về doanh nghiệp chưa rõ; H nêu không đếm nhiều report từ một ứng viên. | Chưa xuất bản cảnh báo doanh nghiệp tới khi định nghĩa đơn vị độc lập và anti-abuse. | Candidate độc lập theo người, tổ chức từng làm hay tiêu chí khác? |
| Q-07 | Danh mục sự cố, bằng chứng, thời gian phản hồi/appeal, anti-abuse và thời hạn cảnh báo chưa đủ. | Report private và moderator duyệt tay; chỉ tạm ẩn job khẩn có audit. | Chính sách kiểm duyệt và SLA. |
| Q-08 | Nguồn xác minh MST/ĐKKD, quy trình đánh giá và tái xác minh. | Badge chỉ sau admin xác minh thủ công; lưu bằng chứng private. | Nguồn tin cậy, người duyệt và vòng đời suspension. |
| Q-09 | Bảng lương tối thiểu, phiên bản, dữ liệu so sánh giờ/ca/tháng và gross/net. | Chỉ cảnh báo khi đủ dữ kiện; không hardcode mức hay tự động chặn. | Nguồn pháp lý và quy tắc quy đổi. |
| Q-10 | Phạm vi hiển thị profile cho recruiter đã nhận application khi `discoverable=false` hoặc sau rút ứng tuyển. | Application giữ snapshot được chia sẻ tại lúc nộp, chỉ org/job đó truy cập; tìm kiếm công khai vẫn tắt. | Thời gian truy cập và rút/xóa application. |
| Q-11 | Sourcing từ profile công khai có thể gửi lời mời nhưng ràng buộc job, chống spam, khiếu nại chưa rõ. | Yêu cầu job hợp lệ và giới hạn lời mời; không chia sẻ CV. | Hạn mức, opt-out lời mời và luồng report. |
| Q-12 | Quyền chính xác của recruiter so với org admin, moderator so với platform admin chưa được liệt kê. | Quyền tối thiểu theo action trong PERMISSIONS; không cấp quyền bằng client. | Ma trận phân quyền chính thức. |
| Q-13 | Điều khoản community, hiển thị bài có cáo buộc, giữ danh tính ẩn danh, quy trình gỡ/appeal chưa hoàn tất. | Đưa cáo buộc vào queue, không công khai trước duyệt; identity riêng. | Quy định nội dung và pháp lý. |
| Q-14 | Dữ liệu bắt buộc của profile/job, đơn vị tiền, danh mục kỹ năng/vị trí và cách đếm từ tiếng Việt. | Validate theo M ở mức rõ ràng; chưa ép danh mục/logic đếm chưa chốt. | Chuẩn dữ liệu và microcopy. |
| Q-15 | Phạm vi “feedback kết quả phỏng vấn” và quyền xem của hai phía. | Feedback private theo appointment, không công khai trên profile. | Trường dữ liệu, người xem, retention. |

**Mâu thuẫn nguồn:** H là bản diễn giải có nhãn “đề xuất”, không thể tự biến các gợi ý thành quy định. M yêu cầu triển khai Phase 1 trong lượt của tài liệu đó, còn yêu cầu trực tiếp hiện tại chỉ cho phép viết tài liệu; phạm vi hiện tại không có code. “Matching” trong H không bắt buộc, còn M cấm tạo match từ Saved job; kiến trúc MVP không có matching tự động.

## Giả định triển khai Micro-test (04/11/2026)

Yêu cầu hiện tại cho phép xây module, nhưng chưa chốt retry/đặc cách, lịch cố định từng câu và thang điểm viết. Bản triển khai dùng một attempt/application, khung giờ nối tiếp, min_seconds là hướng dẫn, trắc nghiệm 1 điểm/câu và viết 0–5 điểm/câu; tổng là điểm thô, không xếp hạng. Đây là mặc định MVP cần Product xác nhận trước phát hành, không phải quy tắc có sẵn trong tài liệu nguồn. Xem [MICROTEST.md](MICROTEST.md).

## Giả định Sourcing

Q-11: nhiệm vụ hiện tại yêu cầu giới hạn gửi lời mời. Triển khai quota có cấu hình, mặc định 20/tổ chức/ngày UTC và 3/ứng viên/30 ngày; không gửi tự động hàng loạt. Product cần xác nhận các con số, retention và opt-out riêng trước phát hành. Xem RECRUITER_SOURCING.md.
