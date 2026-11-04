# QA và Security Review V.E.T.T MVP

Ngày rà soát: 04/11/2026. Kết luận: chưa đủ bằng chứng để phê duyệt production. Không phát hiện Critical qua phạm vi kiểm tra này; điều đó không phải chứng nhận không còn lỗ hổng. Đã sửa hai phát hiện High trong phạm vi an toàn, không thay kiến trúc ứng dụng.

## Bằng chứng chạy

- `npm run lint`, `npm run typecheck`, `npm run build`: đạt sau sửa. Hai lượt đầu typecheck phát hiện kiểu HeadersInit trong test mới; đã sửa và chạy lại đạt.
- `npm test`: 19 tests đạt, gồm 3 test mới cho multipart hợp lệ, thiếu/giả Content-Length, vượt giới hạn và body sai định dạng. Node còn cảnh báo MODULE_TYPELESS_PACKAGE_JSON (Low).
- `bash supabase/test-support/run.sh`: toàn bộ migrations và 13 SQL suites chạy đạt trên PostgreSQL 17. Auth/Storage là schema stubs, không phải Supabase HTTP/token thật. Hành trình mới qa_user_journey.sql chạy đạt: save riêng tư → apply idempotent → HR review → đề xuất lịch → xác nhận không chia sẻ CV → inbox notifications → từ chối tải CV → thu hồi membership chặn đọc application. Fixtures chỉ nằm trong transaction rollback, không seed production.
- `PLAYWRIGHT_MODULE=/opt/codex/runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright node tests/e2e/public-journeys.mjs`: Chromium thật, 20 checks đạt. Trang chủ/login/register/forgot-password ở 375/768/1440 px: HTTP 200, h1, không overflow ngang; email sai bị native validation từ chối; callback sai loại trở về login; hai upload API chặn Origin khác bằng 403. Không giả lập đăng nhập thành công.
- 12 screenshot ở `/tmp/vett-qa-screenshots`, đã xem ảnh login 375 px. Ảnh và dữ liệu tạm không phải artifact bền vững khi thay môi trường. Chạy lại script để tái tạo. Script dùng Playwright có sẵn trong môi trường; máy khác cần cài Playwright và chỉ định CHROMIUM_PATH nếu cần.

## Phát hiện và phân loại

| ID | Mức | Bằng chứng / ảnh hưởng | Trạng thái |
| --- | --- | --- | --- |
| QA-01 | High | Hai upload route gọi request.formData trước kiểm size; request vượt giới hạn có thể chiếm bộ nhớ không cần thiết. | Đã sửa: đọc stream giới hạn 6 MiB CV/3 MiB logo trước parse, giữ giới hạn file 5/2 MiB. Test thiếu/giả Content-Length và payload lớn đạt. Reverse proxy và concurrency limit vẫn cần cấu hình. |
| QA-02 | High | safety_count lấy min số nhóm và số đối tác: A có 3 nhóm, B/C dùng nhóm chung vẫn đạt 3 sai. | Đã sửa migration 010: loại partner có ánh xạ nhóm không nhất quán, đếm nhóm của partner nhất quán. Regression chứng minh công thức cũ trả 3, mới trả 1. Cần moderator xử lý dữ liệu nhóm mâu thuẫn; không tự xóa lịch sử. |
| QA-03 | Medium | RPC read_candidate_card cũ chỉ kiểm tồn tại membership, không kiểm verified email như sourcing. | Đã siết dùng is_org_member. Các checks RLS/profile regression đạt; chưa kiểm token revoked trên Supabase thật. |
| QA-04 | Medium | public_jobs tải toàn bộ rồi filter phía app; organization panel và một số lists không có pagination. Sourcing ILIKE/recursive community readability có thể chậm khi lớn. | Mở: cần query pagination, EXPLAIN ANALYZE và load test dữ liệu đại diện. Đã thêm index author/time và report/audit lookup, chưa chứng minh SLO. |
| QA-05 | Medium | Chưa có rate limit toàn cục cho auth/API/signing; org creation/upload metadata có thể bị spam. Rate limit từng module không thay thế gateway. | Mở: cấu hình Supabase Auth CAPTCHA/rate limits, gateway/IP/user quotas, Storage quotas. Không khẳng định chống DoS. |
| QA-06 | Medium | PDF chỉ kiểm magic bytes; ảnh chỉ kiểm chữ ký đầu; không AV/re-encode. Có thể chứa nội dung độc hại hợp lệ. | Mở: quarantine/scan hoặc quy trình chấp nhận rủi ro trước chia sẻ file thật. Bucket private và authorization không thay AV. |
| QA-07 | Medium | Micro-test trả prompt các câu tương lai ngay khi issued; cửa sổ ghi vẫn do server chặn. | Mở: Product cần chốt quyền xem trước; nếu yêu cầu không được xem sớm, phải phát từng câu và kiểm thử đồng hồ/reconnect UI. |
| QA-08 | Medium | Scheduler reminder/test timeout chưa được cài; trạng thái có thể cập nhật muộn khi không ai mở trang. | Mở: cài worker/cron, kiểm retry/dead letter/monitoring. |
| QA-09 | Medium | Chưa hỗ trợ đổi/hủy lịch confirmed; gỡ safety hold còn qua quản trị; TTL CV/independent partner/SLA chưa chốt. | Mở: hạn chế nghiệp vụ đã ghi docs, cần quyết định trước release. |
| QA-10 | Medium | Moderator Community thấy số report nhưng chưa có UI đọc chi tiết lý do report; report result/appeal Community chưa đầy đủ. | Mở: cần hoàn thiện workflow trước vận hành moderation thực. |
| QA-11 | Low | Nhiều UI hiển thị status tiếng Anh, form Safety yêu cầu mã UUID; một số Zod parse lỗi đi vào boundary chung. | Mở: chuẩn hóa nhãn, contextual links, field errors. |
| QA-12 | Low | next.config chưa cấu hình CSP/headers bảo vệ bổ sung. | Mở: thiết kế CSP tương thích Next nonce, kiểm third-party assets và deployment headers. Không chứng minh XSS chỉ dựa CSP. |

## Phạm vi 14 nhóm

| Nhóm | Bằng chứng / giới hạn |
| --- | --- |
| Auth/session/RBAC/RLS | Đọc SSR getUser, proxy cookie refresh, grants/RPC; SQL auth_authorization/identity_isolation. Session expiry, OTP/recovery/email thực chưa chạy. |
| Candidate privacy | profile_privacy + unit public projection: opt-in mặc định OFF, private fields không có trên card. Storage policy chỉ chính chủ. |
| Job/save/apply | jobs_publish_save/application_states; unique apply, saved riêng, transitions và tenant FK. |
| Micro-test | microtest.sql: timer server, câu chưa mở/hết giờ, snapshot, nộp trùng, chấm viết; keys/score không trả candidate. Chưa load/race nhiều connection. |
| Sourcing/score | sourcing/recruitment_isolation: opt-in, tenant và revoked HR; grade theo application/Job. |
| Interview | interview_consent: revision, xác nhận riêng consent, request đổi lịch. UI confirmed lifecycle còn hạn chế. |
| CV/Storage | private bucket, authorization trước server signing; secret chỉ server route. Link cũ còn tối đa 30s sau revoke, bản đã tải không thu hồi. Chưa kiểm Storage HTTP thật. |
| Notifications | notifications.sql: dedupe, own read, target authorization; cron chưa cài. |
| Community | community.sql: pending, anonymity projection, spoof badge bị chặn, vote/save privacy, hidden ancestry. Không public author mapping. |
| Reports/appeals | trust_safety: 12 tháng, duplicate, appeal exclusion, unauthorized detail, group regression; kiểm độc lập phụ thuộc moderator. |
| Responsive | Chromium public pages 3 widths đạt; dashboard/player/dialog/table có login chưa kiểm browser. |
| Validation/states | unit schemas và E2E email invalid; root error/loading, empty states qua code. Không đánh dấu toàn bộ state matrix đã E2E. |
| Performance | review query/index, build thành công; không có benchmark latency/concurrency, kế hoạch query hoặc volume production. |
| Abuse/IDOR/XSS/CSRF/upload | SQL negative permissions, text JSX không thấy dangerouslySetInnerHTML, callback fixed redirects, upload Origin checks chạy HTTP thật; bounded body tests. Server Actions dựa Next origin checks, chưa pentest thực với token. |

## Dịch vụ và việc chưa kiểm thử

Môi trường không có biến SUPABASE URL/publishable/service role được cấu hình. Không kiểm thử account/email delivery, session refresh bằng cookie thật, direct PostgREST JWT, Storage upload/download/signed URL expiry hoặc revoke race thực. Không chạy authenticated browser journeys và không dùng dữ liệu giả để tuyên bố đạt backend thật. Không có kết quả dependency advisory scan hoặc external penetration test. Production release bị chặn cho tới khi hoàn thành các mục liên quan trong RELEASE_CHECKLIST.md.
