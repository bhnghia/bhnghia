# Triển khai và vận hành V.E.T.T MVP

## Trạng thái 04/11/2026

Chưa deploy. Không có credential Supabase/Vercel/SMTP/domain trong môi trường hoặc connector quản trị các dịch vụ này. Remote Git là bhnghia/bhnghia; lúc bắt đầu chuẩn bị, checkout nhánh work và mã Next.js/migrations/docs còn untracked. Người dùng sau đó đã yêu cầu đưa mã lên GitHub; bản bàn giao dùng nhánh riêng để review, không tự merge master. Không import Vercel project, mua dịch vụ, đổi DNS hoặc chạy SQL trên production.

## Môi trường và biến

| Scope | App | Database/Auth/Storage | Quy tắc |
| --- | --- | --- | --- |
| Local | localhost:3000 | Supabase local đầy đủ hoặc dev project riêng đã có | .env.local; không dùng production data/key; SQL stubs không phải Supabase local runtime |
| Staging | Vercel project staging + domain riêng được bảo vệ | Supabase staging riêng | SMTP sandbox/recipient test; dữ liệu test |
| Production | Vercel project production + domain chính | Supabase production riêng | secrets chỉ người vận hành được sửa |

Preview chỉ dùng staging, không cấp secrets cho fork không tin cậy. Vercel Production của **project staging** vẫn đặt VETT_DEPLOY_ENV=staging. Chọn Node.js 24 như local/CI; xác minh hỗ trợ trong dashboard. Không tự tạo tài khoản/project trả phí, người quản lý kiểm chi phí và quota trước khi cấp quyền.

| Biến | Scope | Giá trị cần kiểm |
| --- | --- | --- |
| NEXT_PUBLIC_SUPABASE_URL | build/runtime public | HTTPS đúng project môi trường |
| NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY | build/runtime public | publishable hoặc legacy anon |
| SUPABASE_SERVICE_ROLE_KEY | chỉ server | secret/legacy service_role cùng project, chỉ dùng API ký CV sau authorization |
| VETT_DEPLOY_ENV | preflight | local/staging/production |
| VETT_APP_ORIGIN | preflight | origin canonical; **không tự đặt Supabase Site URL** |
| VETT_EXPECTED_PROJECT_REF | preflight | lấy từ registry môi trường độc lập, khớp hostname Supabase |

Preflight không gọi service. Legacy JWT được đọc role/ref, không verify signature; opaque sb_* key phải kiểm live đúng project. Guard hiện nhắm hosted ref.supabase.co, custom domain cần review guard. Thay NEXT_PUBLIC_* yêu cầu rebuild. Không log secrets hoặc truyền chúng qua shell history. SMTP/DB/GitHub secrets không đặt ở NEXT_PUBLIC_*. Gitignore chặn .env* trừ example, .vercel và DB dumps.

## GitHub và Vercel

1. Review file untracked, secret scan và diff; commit/push khi người dùng cho phép. Giữ phần C++ cũ. Bản local chưa chứng minh remote chứa ứng dụng.
2. Bật branch protection, required checks VETT checks, review PR và bảo vệ environment production. Workflow CI không deploy/migrate, không nhận secrets.
3. Import đúng repo bằng tài khoản đã có: root directory là root repo, Next.js, Node 24, install/build theo vercel.json. Chọn production branch đã thống nhất (yêu cầu ban đầu master; checkout hiện work).
4. Scope env trước build, Preview Protection, giới hạn quyền team. Chạy staging trước, lưu commit SHA/deployment ID/migration manifest/kết quả smoke; không gắn domain chính cho bản chưa duyệt.

## Migrations, RLS và Storage

13 migrations theo thứ tự tên từ 20261104000100 đến 20261105001000. Sinh SHA-256 manifest, đối chiếu history target trước apply; không chạy lại file đã áp dụng. Một số migration có ALTER/DROP constraint/unique và không bọc transaction ngoài; dữ liệu cũ hoặc partial migration có thể gây lỗi. Kiểm duplicate attempt/application, grade/attempt, lịch active/application; rehearsal bản sao được phép, dừng nếu checksum lịch sử khác. Không sửa migration đã chạy production để ép khớp.

Supabase CLI phải pin version trước vận hành. `migration list`, `db push --dry-run` chỉ lập kế hoạch trên project đã chọn rõ, không thay rehearsal staging. SQL pending và backup phải được review; `db push` thực cần phê duyệt production riêng. Không migrate trong GitHub CI/Vercel build. Không dùng SQL bootstrap/tests trên DB thật.

Chạy audit read-only qua connection đã kiểm project, ví dụ `psql service=vett-staging-audit -f scripts/deploy/audit-readonly.sql`. Dùng pg_service.conf/pgpass được bảo vệ, không in DSN. Script kiểm RLS, grants, bucket, backlog; người vận hành phải review policy dump và test JWT hai tenant thật. Đây không phải chứng nhận toàn bộ RLS đúng.

candidate-cv phải private, PDF 5 MiB; organization-logos **cố ý public** cho logo PNG/JPEG/WebP 2 MiB. Không lưu CV/giấy tờ vào logo bucket. Không tạo public URL CV. Bucket ĐKKD chưa triển khai; Safety evidence hiện là text. Backup Storage metadata không bao gồm file bytes.

**Blocker cần giải quyết trên Vercel:** CV hiện cho phép file 5 MiB/multipart 6 MiB, còn Vercel Functions thường giới hạn payload khoảng 4.5 MB. Kiểm limit runtime/plan thực; file hợp lệ có thể bị từ chối trước route. Chọn giảm size có Product duyệt hoặc upload trực tiếp private Storage bằng token có ownership, validate/quarantine. Chưa tự đổi rule, chưa khẳng định upload 5 MiB chạy trên Vercel.

## SMTP, verification và redirects

Trong từng Supabase project, bật Confirm email. Cấu hình custom SMTP qua provider đã có: host/port/TLS, From address/domain, credentials, SPF/DKIM/DMARC, quota, bounce/complaint. Không bật bắt buộc CAPTCHA trước khi UI hỗ trợ truyền token (hiện chưa nối).

Site URL bằng VETT_APP_ORIGIN. Allowed Redirect URLs chỉ các URL cụ thể: https://CANONICAL_HOST/auth/confirm, /reset-password, /onboarding. Local tương ứng localhost:3000 chỉ ở dev project. Không wildcard *.vercel.app trong production; preview dùng staging canonical hoặc hostname cụ thể được review.

Templates tương thích callback hiện có:

```html
<!-- Signup -->
<a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=signup">Xác minh tài khoản</a>
<!-- Recovery -->
<a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=recovery">Đặt lại mật khẩu</a>
```

Test staging: signup → email thật → OTP một lần → SSR cookie/protected route; link sai/hết hạn/reused từ chối; recovery/resend; mobile email client; SMTP link tracking không phá token; callback không sang môi trường khác. Route chỉ fixed redirects, không nhận next tùy ý. Chưa xác minh SMTP delivery/DNS vì thiếu cấu hình.

## Domain và HTTPS

Chọn canonical domain, thêm vào Vercel, đặt DNS record đúng dashboard cung cấp, không giả định IP/CNAME. Kiểm certificate issued, HTTPS, redirect www/apex một chiều, cookie Secure và mixed content. Cập nhật Site URL sau khi domain ổn định. HSTS nền tảng/domain phải được kiểm thực trước tăng includeSubDomains. App đã cấu hình nosniff, DENY frame, no-referrer, Permissions-Policy; CSP nonce vẫn mở.

## Rate limiting cơ bản

Cấu hình đề xuất dưới đây **chưa áp dụng trên dịch vụ**. Dùng Supabase Auth rate limits và Vercel Firewall/rate rules nếu plan hiện có hỗ trợ; nếu cần nâng gói phải có quyết định chi phí hoặc dùng gateway đã có. Không dùng counter RAM serverless để giả lập quota toàn cục.

| Target | Baseline staging đề xuất | Xác minh |
| --- | --- | --- |
| Auth signup/login/recovery/resend | Provider defaults rồi điều chỉnh theo SMTP quota | burst 429/Retry-After, cooldown, không khóa nhầm NAT |
| POST upload CV/logo | 10/phút/IP | multipart hợp lệ, Origin sai 403 |
| GET API CV | 30/phút/IP | kiểm consent mọi lần, không cache signed URL |
| POST Server Actions | 120/phút/IP | không chặn lưu Micro-test bình thường |

Quotas DB hiện có: sourcing 20/org/ngày + 3/candidate/30 ngày; Community 10 nội dung/giờ; Safety 5 report/ngày. Chúng không thay HTTP quota. Supabase REST trực tiếp bỏ qua Vercel WAF; org creation và các RPC chưa có quota vẫn là risk mở. Ghi rule ID/threshold/thời điểm kiểm thử, không log tokens/IP dài hạn khi chưa có retention policy.

## Scheduler, backup/restore và monitoring

Sau review/phê duyệt, chạy scheduler-install.sql với pg_cron đã được bật: mỗi phút chạy notification batch 100 và finalize test hết hạn. Template **ghi DB**, chưa chạy. Không cần public cron endpoint hay client service_role. Kiểm cron.job_run_details, pending/due/failed; finish_due_microtests chưa batch nên cần giám sát runtime khi tăng dữ liệu.

Kiểm backup/PITR và retention trong gói đang có; không tự bật trả phí. Ghi RPO/RTO chủ dự án duyệt, vị trí mã hóa, access policy, retention. Backup DB, Auth configuration/templates, Storage file bytes và env metadata (secret trong vault riêng). Nếu dùng pg_dump, chọn connection riêng kiểm project; ví dụ `PGSERVICE=vett-staging-backup pg_dump --format=custom --no-owner --file=/secure-backups/vett-staging.dump`. Managed Auth/Storage schemas/roles cần tuân thủ quyền và hướng dẫn Supabase; không coi dump này là bằng chứng restore đầy đủ.

Restore drill vào môi trường cô lập đã duyệt, đối chiếu counts/constraints/RLS/file checksums, kiểm auth/consent smoke và đo RTO. Clone không gửi email thật/chạy scheduler production. Lưu bằng chứng drill trước đánh dấu restore đạt. Không restore đè production từ lệnh mẫu.

Monitoring: HTTP 5xx/latency, Auth failures/SMTP bounce, DB connections/slow queries, Storage quota/errors, CV denied spikes, cron last success/backlog/dead letter, safety hold/audit. Chọn người trực và kênh thông báo được cho phép, test alert staging. Không log cookies, token_hash, signed URLs, CV/evidence/secrets. Dùng provider logs hiện có trước; dịch vụ thêm cần duyệt quyền/chi phí.

## Release và rollback

Gate: preflight + local checks, staging migrations/read-only audit, authenticated E2E hai tenant, SMTP/HTTPS/bucket thật, rate rules và restore drill. Public local Chromium không đủ để phê duyệt production. Lưu SHA commit, migration manifest/history, deployment ID tốt trước đó, config version, backup ID, change window và người duyệt. Migration được duyệt chạy riêng trước app mới tương thích schema. Smoke: `SMOKE_BASE_URL=https://CANONICAL_HOST node scripts/deploy/smoke.mjs`, sau đó authenticated smoke bằng tài khoản test riêng.

Rollback app: dừng rollout, chọn deployment **production** tốt trước đó và kiểm tương thích schema. Nếu không tương thích, maintenance + forward fix được duyệt. Không promote staging build vì NEXT_PUBLIC_* đã đóng vào bundle. Env/domain rollback theo config version rồi kiểm callback/smoke.

Rollback DB: không down migration tự động, không DROP/RESET. Restore/PITR có thể mất dữ liệu sau mốc backup, cần phê duyệt mốc và ảnh hưởng riêng. Restore clone trước, đối soát Storage/consents/audit rồi chuyển traffic. Dừng scheduler theo job name đã review khi cần; không xóa queue/audit để che lỗi.

## Bằng chứng phiên chuẩn bị

Đã chạy đạt lint, typecheck, production build, 19 unit tests và 2 preflight tests. Preflight với môi trường thật hiện thiếu biến trả exit 1 đúng dự kiến; không có giá trị secret trong log. Manifest kiểm đủ 13 migrations. Docker PostgreSQL chạy đạt 13 SQL suites và audit read-only (RLS/grants/private CV bucket) trên Auth/Storage stubs.

Smoke HTTP trên Next production build local chạy đạt bốn trang public và headers bảo vệ. Chromium chạy lại đạt 20 public browser/HTTP checks ở 375/768/1440 px sau cấu hình headers. Smoke authenticated chưa chạy vì thiếu Supabase. Có một lượt bị hệ thống approval lỗi hạn mức trước khi thực thi, không phải lỗi ứng dụng; sau yêu cầu tiếp tục của người dùng, GitHub và smoke được cho phép chạy lại.

Vercel/Supabase/SMTP/DNS/backup/rate rules live chưa được cấu hình hoặc xác minh. GitHub push là bàn giao mã, không phải deploy. Release checklist vẫn chặn production do thiếu live Auth/Storage/SMTP tests, restore drill, rate rules và vấn đề payload CV trên Vercel.
