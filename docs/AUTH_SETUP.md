# Xác thực và phân quyền

Áp dụng migrations theo thứ tự 001 → 003 trên Supabase trước khi chạy Auth. Cấu hình hai biến trong `.env.example`: URL project và publishable key. Không cần service_role. Trong Supabase Auth bật Confirm email, cấu hình Site URL đúng host ứng dụng và redirect allowlist chính xác; bật rate limit/CAPTCHA theo lưu lượng triển khai.

Email template xác minh dùng `{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=signup`; Recovery dùng `{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=recovery`. Không dùng URL redirect tùy ý từ client. Link chỉ dùng một lần, hết hạn theo Supabase.

Profile tạo bởi trigger `auth.users`; không sao chép user metadata thành role. Persona là lựa chọn giao diện, không cấp quyền hệ thống. Tạo tổ chức là RPC nguyên tử: tổ chức pending và membership org_admin của người tạo, không có tham số role; quyền đó chỉ có phạm vi tổ chức mới. Tham gia tổ chức khác cần request và quản trị viên duyệt, chỉ cấp recruiter. Định nghĩa này là cách triển khai đề xuất Q-12; không cấp platform admin/owner qua client.

Mọi protected layout dùng getUser để xác minh với Auth; route org/[id] đọc membership hiện tại mỗi request. Không cache quyền. Database RLS tiếp tục giới hạn dữ liệu; thu hồi membership chặn request tiếp theo. Token đã đăng nhập không chứa quyền org cố định. Quyền org_admin không tự được cấp badge verified.

Chưa có cấu hình Supabase trong môi trường lúc triển khai, nên gửi mail, callback/session refresh và RLS trên Supabase thật cần được kiểm chứng sau khi cung cấp cấu hình. Test access hiện tại là unit test của predicate quyền, không phải bằng chứng E2E hoặc database.
