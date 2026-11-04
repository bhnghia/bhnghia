# Organization Profile và Job Card

## Phạm vi đã triển khai

- `/organization/[id]`: quản trị viên chỉnh tên, MST, địa chỉ, logo; thêm chi nhánh; xem người quản lý/thành viên. HR hiện tại tạo và quản lý job của tổ chức.
- `/organization/[id]/jobs/new` và `/organization/[id]/jobs/[jobId]`: tạo/sửa nháp, xuất bản, tạm dừng để sửa, đóng job. Tin đang published không sửa trực tiếp; đây là mặc định triển khai cho Q-03.
- `/jobs`, `/jobs/[id]`: Job Card hai lớp dùng `details/summary` truy cập được bằng bàn phím, không phụ thuộc hiệu ứng lật. Logo thật từ bucket riêng, badge từ trạng thái xác minh có quyết định kiểm tra. Bộ lọc sticky có thể thu gọn trên mobile theo ngành/kỹ năng/địa lý/lương/hình thức, không có thuộc tính nhạy cảm.
- `/jobs/saved`: chỉ ứng viên xem. Lưu/bỏ lưu là thao tác idempotent, không tạo match, application hoặc notification cho HR.
- Nút ứng tuyển mở bước xác nhận Profile Card cho job không test. RPC khóa job và kiểm org, snapshot whitelist không có họ tên riêng/CV/điểm, chống gửi trùng theo job/candidate. Policy retention snapshot Q-10 chưa được chốt.

## Xuất bản và cô lập tenant

Áp dụng `20261105000200_organizations_jobs.sql` sau migrations hiện có. RPC kiểm tra membership hiện tại; composite FK job/branch chống gắn chi nhánh tổ chức khác. HR không có quyền ghi thẳng bảng job, skill, bookmark hoặc trạng thái xác minh. Job chỉ public qua projection `public_jobs()` khi published và org verified có quyết định verified. Thay đổi tên/MST/địa chỉ trả org về pending, các job của org lập tức ngừng hiển thị công khai.

Điều kiện xuất bản: chi nhánh, ngành, lương min/max hợp lệ cùng đơn vị và gross/net, hình thức, đúng ba kỹ năng khác nhau, JD/yêu cầu/quyền lợi và cam kết an toàn. Currency MVP là VND. Job thiếu trường vẫn có thể lưu nháp. Migration Micro-test bổ sung ngân hàng: bật test và publish yêu cầu ít nhất 10 trắc nghiệm đang dùng cùng đủ số câu viết đã cấu hình. Xem [MICROTEST.md](MICROTEST.md).

Xác minh dùng `organization_verifications`, danh sách `platform_reviewers` chỉ quản trị database được provision. Sau khi người có trách nhiệm kiểm tra MST/ĐKKD bằng nguồn tin cậy, tài khoản reviewer gọi `review_organization(org, decision, evidence)` với tham chiếu bằng chứng. Hàm không cho HR tự xác minh; Q-08 về nguồn/quy trình xác minh và lưu bằng chứng vẫn cần xác nhận. Chưa có giao diện xét duyệt/evidence upload; không tự động coi MST hợp lệ là verified. Không dùng service_role trên frontend hoặc API thông thường.

Logo là ảnh công khai PNG/JPEG/WebP tối đa 2 MB; bucket này không chứa CV/ĐKKD. Chỉ org_admin upload, magic bytes được kiểm tra server, đường dẫn ràng buộc tổ chức. Chưa có resize/malware scanner hoặc dọn phiên bản logo cũ tự động.

## Tham chiếu lương

`minimum_wage_rules` chứa vùng, khoảng hiệu lực `[valid_from, valid_until)`, đơn vị, gross/net, currency, số tiền và nguồn. Không seed số tiền luật. Người quản trị cần cấu hình bảng và gán `branches.region_code` theo nguồn có thẩm quyền; HR không tự chọn mã vùng luật. Khi chưa có mapping, thiếu dữ kiện, khác đơn vị/basis hoặc khoảng hiệu lực chồng lấn, UI báo chưa đủ dữ liệu và không quy đổi giờ/ca/tháng tùy ý. So sánh chỉ là cảnh báo, không tự chặn publish và không xác nhận tuân thủ pháp luật. Thông báo áp dụng cho bản job đã lưu, theo ngày Việt Nam; Q-09 về nguồn luật và quy đổi vẫn mở.

## Kiểm tra và giới hạn môi trường

`npm run typecheck`, `npm run lint`, `npm run build`, `npm test`. SQL regression: `bash supabase/test-support/run.sh` (Docker local, PostgreSQL 17, network none, tự xóa container). Harness Auth/Storage chỉ mô phỏng DB schema; không thay thế kiểm thử Supabase Auth, Storage HTTP, token thật hoặc E2E trình duyệt.

Chưa có biến cấu hình Supabase trong môi trường nên chưa kiểm chứng các luồng UI/upload bằng project thật. Bộ lọc MVP hiện lọc trên tập tin công khai lấy từ RPC; cần phân trang/truy vấn có giới hạn trước khi mở rộng dữ liệu. Không có dữ liệu mẫu production, giao diện dùng loading/error/empty states hiện có khi không có dữ liệu hay lỗi truy vấn.
