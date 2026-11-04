# Checklist phát hành

## Gate đã có bằng chứng local

- [x] Lint, typecheck, production build chạy đạt.
- [x] 19 unit tests đạt; giới hạn đọc upload có regression.
- [x] Migration hardening 010 chạy trên PostgreSQL test, giữ nguyên dữ liệu cũ.
- [x] Regression quyền/RLS, anonymous projection, vote, timer, consent và count 12 tháng đạt trong SQL harness.
- [x] Chromium public journeys: 20 checks tại mobile/tablet/desktop, upload cross-origin 403.

## Bắt buộc trước production

- [ ] Review/commit/push mã V.E.T.T hiện còn untracked; GitHub CI thực chạy và branch protection được bật.
- [ ] `check-env.mjs` đạt với env thật đúng project và scope; kiểm live key cùng Supabase project, không chỉ cấu trúc.
- [ ] Vercel project/Node 24/domain/HTTPS/SMTP/redirect allowlist được cấu hình và có bằng chứng test delivery.
- [ ] Giải quyết giới hạn payload Vercel so với CV 5 MiB: duyệt thay đổi size hoặc luồng private signed upload, chạy smoke file boundary trên staging.
- [ ] Review SHA-256 manifest 13 migrations, DB history, dữ liệu trùng và backup; phê duyệt riêng mọi thay đổi production database.

- [ ] Thiết lập Supabase staging tách production, apply toàn bộ migrations theo thứ tự, backup/restore rehearsal.
- [ ] Cấu hình URL/publishable key và secret ký CV chỉ server; kiểm không có secret trong client bundle/log.
- [ ] Tạo user test candidate, hai org HR, revoked HR, moderator; chạy signup/verify/login/logout/recovery/session expiry thật.
- [ ] Chạy direct PostgREST và Storage HTTP với JWT từng vai trò: cross-tenant, expired/revoked token, anonymous, service key không dùng client.
- [ ] E2E candidate profile → save → apply → test → HR review → interview → consent → signed download → revoke; không consent và hết hạn phải chặn.
- [ ] E2E sourcing invite, notification read/link, Community anonymous/official replies, moderation/report/appeal với dữ liệu staging thật.
- [ ] Kiểm responsive authenticated dashboard/player/dialog/calendar ở 375/768/1440 và keyboard/screen reader.
- [ ] Cấu hình worker/cron cho reminders và timeout, kiểm retry/dead letter, dedupe khi nhiều worker cùng chạy.
- [ ] Cấu hình Auth CAPTCHA/rate limits, upload/gateway request/concurrency quotas, abuse alerting và dependency advisory scan.
- [ ] Chốt scan/quarantine PDF, re-encode image hoặc quyết định rủi ro có người chịu trách nhiệm.
- [ ] Chốt policy TTL CV, xem trước Micro-test, đối tác độc lập, SLA/retention/appeal và gỡ safety hold; bootstrap moderator qua quản trị có audit.
- [ ] Sửa pagination các lists còn mở; chạy EXPLAIN ANALYZE và load test có SLO trên dữ liệu đại diện.
- [ ] Rà soát CSP/security headers, log redaction (CV URL, token, evidence), quyền truy cập audit và kế hoạch ứng phó sự cố.
- [ ] Hoàn thiện moderator đọc lý do report Community và trạng thái xử lý; xác nhận không có kết luận tự động công khai.
- [ ] Người phụ trách release duyệt các Medium/Low còn mở trong QA_REPORT.md và lưu bằng chứng staging.

Không coi SQL Auth/Storage stubs là xác nhận Supabase thật. Chỉ đánh dấu gate hoàn thành khi có log/artifact chạy tương ứng; checklist này không tự cho phép deploy.
