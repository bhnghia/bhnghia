# Vai trò và quyền truy cập

Ma trận là baseline quyền tối thiểu **đề xuất** từ M/H; Product cần duyệt chi tiết Q-12. `Own` là chính chủ; `Org` là membership hợp lệ của đúng organization; `Public` chỉ là projection đã lọc. `Admin` không tự động xem mọi CV hoặc identity ẩn danh nếu không có tác vụ được ủy quyền.

| Tài nguyên / hành động | Candidate | Recruiter | Org Admin | Moderator | Platform Admin / Public |
| --- | --- | --- | --- | --- | --- |
| Profile private/chỉnh sửa | Own | Không | Không | Không | Theo quy trình hỗ trợ được audit / Không |
| Profile public discoverable | Own | Đọc khi opt-in hoặc application đúng job | Như recruiter | Không cần mặc định | Không cần mặc định / public projection theo cài đặt |
| CV gốc | Own | Chỉ tải qua grant hợp lệ của Org/job sau accept + consent | Cùng điều kiện, nếu quyền tuyển dụng | Không | Không mặc định / Không |
| Org, chi nhánh, thành viên | Không | Đọc/ghi theo quyền Org | Quản lý Org; không tự verified | Không | Admin xét duyệt verification / public chỉ thông tin đã duyệt |
| Job | Đọc published | Tạo/sửa trong Org theo state | Quản lý trong Org | Tạm ẩn khi scam khẩn | Điều hành review / public đọc published |
| Saved job | Own | Không | Không | Không | Không / Không |
| Application | Own | Đọc job thuộc Org | Theo quyền tuyển dụng Org | Chỉ khi xử lý vụ việc | Chỉ tác vụ được audit / Không |
| Bank/answer key | Không | Soạn và quản lý job thuộc Org | Theo quyền tuyển dụng | Không | Không mặc định / Không |
| Attempt/grade | Own theo policy hiển thị điểm | Đọc/chấm job thuộc Org; không sửa điểm MCQ | Theo quyền tuyển dụng | Không | Chỉ điều tra được audit / Không |
| Invitation/appointment | Own | Job thuộc Org | Theo quyền tuyển dụng | Chỉ vụ việc | Chỉ vụ việc / Không |
| Incident/evidence/appeal | Bên liên quan và phần được phép | Bên liên quan trong Org | Bên liên quan trong Org | Xử lý được phân công | Giám sát / chỉ warning đã duyệt |
| Forum post/comment | Tạo/xem public | Tạo/xem public; official khi verified + đại diện | Tương tự theo membership | Kiểm duyệt, thấy identity khi cần | Audit / public chỉ projection |
| Audit logs | Không | Không | Xem sự kiện Org được phép **[đề xuất]** | Sự kiện moderation liên quan | Theo nhiệm vụ / Không |

## Cơ chế cưỡng chế

- Auth xác định user; role nền tảng và org membership lấy từ DB qua quyền được bảo vệ. Không tin `organization_id`, `official`, `verified`, `score` hoặc `author_id` do client gửi.
- RLS bật trên mọi bảng chứa dữ liệu người dùng. `USING` bảo vệ SELECT/UPDATE/DELETE; `WITH CHECK` bảo vệ INSERT/UPDATE. Với bảng theo tenant, policy kiểm tra membership *và* quan hệ job/application thuộc cùng org; composite FK bảo vệ liên kết chéo tenant.
- Bảng đáp án test nằm ngoài quyền đọc candidate, kể cả join hoặc view. Attempt chỉ trả câu hỏi snapshot đã phát; grading server/DB kiểm đáp án, không nhận điểm từ client.
- CV/ĐKKD private Storage. Signed URL chỉ được tạo qua server sau kiểm quyền hiện tại, TTL ngắn; revoke/expiry chặn cấp URL mới. Không dùng public bucket. Service-role chỉ trong server runtime, không nằm client hoặc route trả ra ngoài.
- Anonymous forum: API/search/public view bỏ `author_id`, email, dấu vết định danh và metadata truy vết; bảng mapping nội bộ cho moderator được audit. Nhãn official được tính server từ verified organization và membership có quyền.
- Report và evidence private ngay cả khi warning được công bố. Warning là bản tóm tắt đã moderator duyệt, không phải view trực tiếp của report. Bị báo cáo có quyền phản hồi/appeal theo policy Q-07.
- Tất cả thao tác đổi quyền, verify, suspend, cấp/thu hồi CV, tải CV, chấm tự luận, ẩn job, xác nhận incident, phát warning được ghi audit. Quyền ghi audit không cho client sửa/xóa.

## Kiểm thử quyền bắt buộc

Tạo dữ liệu hai org A/B, một candidate tắt discoverable và các token thật tương ứng. Thử SELECT/INSERT/UPDATE, Storage download và join trực tiếp qua API/SQL theo RLS; không chỉ kiểm UI. Xác nhận: A không đọc B; candidate không thấy answer key; user không tự cấp membership/admin; revoke/expiry chặn tải; forum public không lộ identity; incident pending không lộ; ba report cùng một bên không đủ cảnh báo. Dùng migration test để kiểm default `discoverable=false` và avatar hidden.
