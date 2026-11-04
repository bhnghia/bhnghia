# Kế hoạch triển khai MVP có thể kiểm thử

## Baseline

Repo `bhnghia/bhnghia` hiện ở commit `4d409b5`, chỉ có solution C++/Python Visual Studio và một chương trình console; không có README, Next.js/package.json, migrations, test, CI hay `.env.example`. Công việc hiện tại chỉ tạo tài liệu. Không chạy app/test V.E.T.T vì chưa có mã nguồn. Tài liệu đính kèm không phải bằng chứng hệ thống đã tồn tại.

## Nguyên tắc thực hiện

Mỗi milestone kết thúc bằng luồng chạy được và kiểm thử quyền bằng token thật. Không thay quy tắc chốt; các Q liên quan được duyệt trước khi phát hành tính năng đó. Dữ liệu production không dùng mock. Migration có rollback/kiểm tra idempotency; không công khai bảng private. Dùng Next.js App Router, TS strict, Tailwind/shadcn/ui, Supabase Auth/PostgreSQL/Storage/RLS, Zod. Cấu hình secrets qua môi trường, không commit giá trị.

| Mốc | Thứ tự file/migration/screen chính | Điều kiện nghiệm thu |
| --- | --- | --- |
| M0 — nền tảng | `package.json`, TS/Next/Tailwind config, shadcn components, `.env.example`, Supabase local config, CI, `src/lib/supabase/{server,client}`, migration 001 auth/profile/org nền; `/login` | `lint`, `typecheck`, Vitest, migration và CI chạy; secrets không vào client; repo C++ giữ nguyên. |
| M1 — B2C/B2B lõi | migration 002 `profiles/candidate_profiles/skills/privacy/cv`; 003 `organizations/members/verifications/branches`; 004 `jobs/job_skills/saved_jobs/applications`; screens profile editor, org onboarding, job create/list/detail, apply, recruiter inbox | Candidate opt-in profile; verified badge do admin; Apply không test gửi card, không CV; A không đọc B; saved job riêng, không tạo match. Playwright E2E hai org + RLS/Storage test. |
| M2 — Micro-test | migration 005 bank/questions/attempt/snapshot/answers/grades; screens cấu hình bank, preflight, test, chấm tự luận | Bank ≥10, phát 3 MCQ, số tự luận theo Q-01; deadline/đáp án server, retry/mất mạng theo Q-02; concurrent apply và duplicate submit an toàn; test RLS không lộ key. |
| M3 — Sourcing/phỏng vấn/CV | migration 006 invitations/appointments/grants/notifications; screens discoverable search, invitation/calendar, consent/revoke; cron survey idempotent | Candidate tắt discoverable không hiện; accept không tự cấp CV; consent riêng mới cấp grant; expire/revoke chặn tải mới; survey chỉ một lần đúng thời điểm Q-05. |
| M4 — Community | migration 007 posts/comments/votes/bookmarks/reports, moderation action/audit; screens forum/search/report/official reply, moderation queue | Anonymous public payload không có ID; vote unique; official chỉ verified representative; nội dung tố cáo qua duyệt. |
| M5 — Trust & Safety | migration 008 incidents/responses/appeals/warnings, audit; screens report, phản hồi/appeal, admin queue, cảnh báo | Pending private; scam có thể tạm ẩn job có log; ba đối tác độc lập theo Q-06, moderator duyệt mới public; quyền phản hồi/appeal. |
| M6 — hardening | Rate limits, logging/observability, backup/restore drill, accessibility, security review, deployment config | CI đầy đủ, Playwright các luồng chính, RLS/Storage regression, kiểm bàn phím/mobile, checklist deploy. |

## Cổng quyết định

Q-03/Q-08 cần trước khi mở job public; Q-01/Q-02 trước M2; Q-04/Q-05/Q-10/Q-11 trước M3; Q-13 trước M4; Q-06/Q-07 trước khi có warning công khai. Có thể xây schema và test bảo mật trước khi chốt copy/quy trình, nhưng không phát hành hành vi còn mơ hồ. Cần kiểm tra phiên bản API/gói hiện hành lúc bắt đầu code.

## Lệnh dự kiến sau khi có ứng dụng

`npm ci`, `npm run lint`, `npm run typecheck`, `npm test`, migration + RLS integration test và `npx playwright test`; tên script chính xác phải được xác lập trong M0. Chưa lệnh nào trong số này được chạy cho V.E.T.T ở lượt tài liệu này. Mỗi mốc ghi file thay đổi, lệnh chạy, test đạt/trượt và rủi ro còn lại.
