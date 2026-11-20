# TTX Driver Pro — cài bản QA song song trên Android (Giai đoạn 7)

> **Bản thử nghiệm, không phải bản phát hành cho hành khách hoặc chạy thương mại.**
> Không cần máy tính, USB debugging, root hay bật Tùy chọn nhà phát triển.

## Vì sao phải có bản QA riêng?

Các APK cũ có cùng Android applicationId với ứng dụng taxi gốc, trong khi
chữ ký build GitHub Actions không được bảo đảm trùng bản đang cài. Android
có thể từ chối cập nhật; việc gỡ bản đang dùng để cài APK mới có thể làm
mất dữ liệu chuyến và thiết lập.

CI hiện tạo hai biến thể sau với **applicationId QA riêng**:

- Bản taxi chính (không sửa): `vn.thanhtaxixanh.ttx_aataximeter`
- **Bản thử nghiệm QA**: `vn.thanhtaxixanh.ttx_aataximeter.qa`
- Nhãn launcher của QA: **TTX Driver Pro QA**.

Android cấp thư mục dữ liệu riêng cho mỗi định danh; bộ cài QA không ghi đè
ứng dụng chính. Cả hai APK QA debug và ARM64 đều phải vượt qua kiểm tra
`aapt dump badging` trên **tệp APK đã build**, không chỉ cấu hình Gradle.
Package `.qa` là dấu nhận diện kênh thử nghiệm; nó không xác nhận bản đồ
hoặc hệ thống tính cước đủ điều kiện phát hành.

## Cài trên Xiaomi Redmi Note 12 Pro bằng điện thoại

1. Vào repo GitHub, tab **Actions**, chọn workflow mới nhất
   **Flutter isolated QA Debug/ARM64 APK** thuộc PR #11, bảo đảm dấu
   `success` và commit đúng.
2. Chọn **Artifacts** rồi tải `ttx-driver-pro-qa-arm64-test-only`
   (hoặc `ttx-driver-pro-qa-debug` nếu ARM64 không phù hợp).
   GitHub có thể yêu cầu đăng nhập để tải artifact.
3. Trong **Tệp/Quản lý tập tin**, giải nén ZIP; chạm APK bên trong.
   Nếu Android hỏi, chỉ cho phép cài từ nguồn mà bạn vừa sử dụng và xác minh.
4. Trước khi xác nhận cài, kiểm tra ứng dụng hiển thị tên
   **TTX Driver Pro QA**. Không cho phép bất kỳ hộp thoại nào yêu cầu
   gỡ bỏ bản taxi chính.
5. Sau khi cài, bạn phải thấy hai biểu tượng/ứng dụng khác nhau.
   Mở bản QA để thử; dữ liệu/chuyến của bản chính không được tự động chia sẻ.
6. Nhập riêng `ttx_traffic_signs.sqlite` từ trình chọn tệp trong QA.
   File phải đúng 21.090.304 byte, SHA-256:
   `a8dc5b6f3b09546604a395d3236a9a9b12872cc81162e86db9f2a878e5319ec7`.

## An toàn khi cập nhật, xóa và đo hiệu năng

- Chữ ký test-only có thể thay đổi giữa các workflow/runner. Nếu Android
  từ chối cập nhật APK QA, chỉ được gỡ **TTX Driver Pro QA**; **không**
  gỡ ứng dụng taxi chính. Sao lưu kết quả kiểm thử và cấu hình QA trước.
- Dùng gói `arm64` cho máy ARM64 khi tương thích để giảm dung lượng; đây
  vẫn là **APK test-only**, không phải bản phát hành ký chính thức.
- Bật/tắt mạng, chuyển 2D/3D, pan/zoom để đo p50/p95 SQLite và kiểm tra
  nhãn Hoàng Sa/Trường Sa. p95 SQLite **không** đại diện cho FPS hay thời
  gian định vị GPS.
- Dùng tuyến/chuyến thử nghiệm, không dùng QA để thu tiền thực tế.
- Bản đồ 2D không có tile nền chỉ biểu diễn tọa độ GPS/biển báo, **không**
  phải bản đồ đường bộ/navigating offline.
- Chính sách TTX-VN-MAP-01 và cổng `--publish` vẫn **chưa được duyệt
  phát hành**. Không chia sẻ công khai ảnh/bản đồ thử nghiệm trước kiểm định.

## Chốt bằng chứng nghiệm thu

Ghi commit SHA, GitHub Actions run ID, trạng thái hai build, thiết bị,
Android version, số liệu p50/p95 và đánh giá các bước trong
`docs/PHASE6_OFFLINE_SIGN_REFERENCE_ACCEPTANCE.md`.
Đừng đánh dấu nghiệm thu thiết bị cho đến khi đã thực sự chạy trên máy.
