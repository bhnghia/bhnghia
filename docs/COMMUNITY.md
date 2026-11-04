# Community MVP

`20261105000800_community.sql` giữ author_id nội bộ, không cấp SELECT bảng gốc cho client. RPC chỉ trả tên hiển thị hoặc “Ẩn danh”, không trả user ID/email. Badge phản hồi chính thức được tính lại theo membership hiện tại và tổ chức verified, không tin badge do client gửi. Tag doanh nghiệp là nhãn tìm kiếm do người dùng nhập, không phải xác nhận đại diện.

Mọi bài/bình luận vào pending trước khi moderator duyệt; đây là mặc định MVP thận trọng để không tự công bố cáo buộc. Moderator do quản trị DB cấp trong community_moderators; không có API tự cấp quyền. Nội dung có pending/visible/hidden/removed. Ẩn cha chặn cả nhánh con ở projection, thao tác duyệt/ẩn/khôi phục có audit. Removed giữ dữ liệu để đối soát, không xóa vật lý. Chính sách thời hạn lưu và appeal vẫn thuộc Q-13.

Ứng viên/HR xác minh email đăng tối đa 10 bài hoặc bình luận mỗi giờ; tối đa 10 report/giờ, khóa profile để chống gửi đồng thời vượt hạn. Unique item/user cho vote và save; vote -1/+1 hoặc xóa bằng 0, thay đổi vote không cộng thêm bản ghi. Saved chỉ chủ tài khoản xem. Report private và unique item/reporter. Bài/bình luận hiển thị như văn bản, không render HTML. Không công khai báo cáo tự động.

UI `/community` có tìm từ khóa, tag, bài của tôi, đã lưu, moderation và phân trang server 20. Bình luận có link mở nhánh để trả lời tiếp. Notifications community_reply chỉ phát khi reply được duyệt; adapter kiểm quyền target hiện tại trước khi mở liên kết. Hàng đợi bao gồm nội dung chưa visible và bài visible có báo cáo. Chưa có quy trình xử lý kết quả report/appeal đầy đủ. Chưa seed moderator production.

Tests community.sql kiểm tra pending, ẩn danh, giả badge, sai quyền moderator, vote trùng, saved riêng và ẩn nhánh con. Harness PostgreSQL Auth/Storage stubs không thay kiểm thử Supabase thật/browser.
