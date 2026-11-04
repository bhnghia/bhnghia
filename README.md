# V.E.T.T frontend

Nền giao diện tiếng Việt cho V.E.T.T, xây bằng Next.js App Router, TypeScript strict, Tailwind CSS 4, các component theo cấu trúc shadcn/ui, Lucide, Zod và React Hook Form.

## Chạy local

Yêu cầu Node.js 24 (`.nvmrc`) và npm. Sao chép `.env.example` sang `.env.local`, điền cấu hình dev riêng; không dùng production key. Trong thư mục repository:

```bash
npm ci
npm run dev
```

Mở `http://localhost:3000`. Kiểm tra trước khi bàn giao:

```bash
npm run lint
npm run typecheck
npm run build
```

Build dùng Webpack vì môi trường cloud hiện không cho Turbopack mở cổng nội bộ để xử lý CSS. `npm run dev` dùng Next.js mặc định. Các route hiện có: `/`, `/login`, `/register`, `/candidate`, `/organization`.

Xác thực SSR dùng hai biến public Supabase. Riêng API ký CV yêu cầu `SUPABASE_SERVICE_ROLE_KEY` chỉ ở server và chỉ ký sau khi kiểm session/consent. SMTP cấu hình trong Supabase Dashboard; không đưa secrets vào frontend.

## Triển khai và rollback

Trạng thái: **chưa deploy**. Đọc [DEPLOYMENT](docs/DEPLOYMENT.md), [RELEASE_CHECKLIST](docs/RELEASE_CHECKLIST.md), [QA_REPORT](docs/QA_REPORT.md) trước khi phát hành. Thiếu credential/domain/SMTP và bằng chứng staging thật.

```bash
node --env-file=.env.local scripts/deploy/check-env.mjs
node --test scripts/deploy/check-env.test.mjs
node scripts/deploy/migration-manifest.mjs
npm test
bash supabase/test-support/run.sh
```

Preflight chỉ kiểm cấu trúc biến/project ref, không in giá trị và không xác thực credential thật. Manifest chỉ đọc migrations và tính SHA-256. SQL harness dùng Docker tạm với Auth/Storage stubs, không chạy lên database thật.

`vercel.json` chạy preflight trước build; không tự migrate. `.github/workflows/ci.yml` chạy các gate local, chưa có deploy step. `scripts/deploy/audit-readonly.sql` dành cho connection được chọn rõ ràng và chỉ đọc RLS/grants/bucket/backlog. `scheduler-install.sql` là template **ghi DB**, phải review/phê duyệt trước production.

Sau khi có deployment đã duyệt: `SMOKE_BASE_URL=https://your-approved-host node scripts/deploy/smoke.mjs`. Local chưa có Supabase dùng `--public-only`. Các bước live Auth/Storage/E2E vẫn cần chạy riêng.

Rollback app bằng deployment **production** tốt trước đó sau khi kiểm tương thích schema; không promote staging build chứa staging URL/key sang production. Database rollback dùng forward fix hoặc restore được phê duyệt, không chạy down migration hay `supabase db reset` trên production. Runbook chi tiết và rủi ro upload Vercel nằm trong DEPLOYMENT.md.
