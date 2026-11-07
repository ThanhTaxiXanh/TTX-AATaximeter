# TTX DRIVER PRO 0.9.15+35 — Tên đường, bản đồ Navy và sao lưu toàn bộ cài đặt

## Căn cứ

Ba ảnh được tài xế cung cấp ngày 07/11/2026 cho thấy tên đường gần GPS đã có
trong thanh xanh (ví dụ Nguyễn Công Hãng), nhưng không được vẽ trực tiếp trên
đường trong bản đồ 3D. Thanh xanh mặc định chiếm chiều ngang quá rộng.
Bản đồ Dark mong muốn có nền navy, mặt đường xanh xám sáng, nhãn tiếng Việt
viền rõ như ảnh thứ ba.

## Bản đồ 3D

- Thêm lớp `ttx-3d-readable-road-names` trực tiếp từ vector tile
  `openmaptiles / transportation_name` ở zoom >=12. Lớp này vẽ tên theo
  đoạn đường (`symbol-placement: line`) ở phía trên hình khối 3D và
  ưu tiên `name:vi`, `name`, `name:nonlatin`, `name:latin`, `ref`.
  Chữ sử dụng font glyph của chính OpenFreeMap, halo tương phản theo theme,
  hướng đọc đúng mặt màn hình trong góc nghiêng (`textPitchAlignment: viewport`)
  và nằm theo đường (`textRotationAlignment: map`).
- Khi tạo lớp tên đường mới thành công, tắt các lớp tên đường gốc có thể
  gây chồng chữ. Không vô tình tắt chính lớp tên đường của TTX; khi tạo
  lớp mới thất bại, giữ lại lớp gốc như fallback.
- Phối màu Dark: nền #1B2B49, khu dân cư cùng tông navy, đường nhỏ
  #7E99B9, đường chính #91A9C9, cao tốc #B1C6DE, water #122A4B.
  Tăng độ rộng đường khi zoom lái xe; nhà 3D giảm opacity để không phủ đường.
  Chỉ cập nhật các lớp Dark có ID khớp chính xác với style được tải.
- Tên đường góc dưới bên phải giờ dùng kích thước nội tại
  `Row(mainAxisSize: min)`, `Flexible(Text)`, giới hạn chiều ngang tối đa
  66% màn hình (không còn Positioned có cả left và right). Tên ngắn
  hiển thị trong thẻ ngắn; tên dài dãn đến giới hạn rồi tối đa hai dòng.
  Lùi thẻ lên để không che ghi công nguồn OSM ở mép dưới bản đồ.
- **Giới hạn:** map labels phụ thuộc tile OpenStreetMap. Đường thiếu tag
  tên hoặc chưa tải glyph/tiles vẫn không có nhãn chính xác; không tự đặt tên.
  Vị trí và tên đường chỉ là trực quan, không tham gia tính cước.

## Sao lưu đầy đủ cấu hình người dùng

`.ttxbackup` gồm:
- SQLite: lịch sử, hóa đơn, tuyến đường GPS, thu phí phát sinh gắn với chuyến.
- **Xe & hồ sơ:** loại xe, hãng xe và biển số đã lưu.
- **Cước phí & chuyến đi:** biểu giá hiện hành và danh sách bảng giá đã cấu hình.
- **Bản đồ & lời chào:** tùy chọn 2D/3D, sáng/tối, góc nghiêng, tên đường,
  lời chào, lời cảm ơn, tự động chuyển 3D khi bắt đầu.
- **HUD:** bổ sung lưu lựa chọn gương HUD vào DashboardPreferences (trước đây
  chỉ là biến UI tạm, nay được ghi khi người dùng bật/tắt).
- **VietQR:** danh bạ tài khoản, tài khoản mặc định và ảnh logo gốc ở giữa/
  dưới QR (trong `.ttxbackup`; JSON riêng chỉ chứa cấu hình/đường dẫn).
- `SettingsBackupBundle.capture` kiểm kê tất cả khóa `ttx_` hiện có.
  Nếu xuất hiện khóa cấu hình mới chưa nằm trong registry, **từ chối xuất**
  thay vì tạo một bản sao gây hiểu lầm là đầy đủ.
- Xuất trước khi hoàn tất mọi lượt lưu DashboardPreferences được xếp hàng,
  tránh lưu tệp chứa cấu hình cũ do người dùng vừa chỉnh slider.
- `SettingsBackupBundle.capturedGroups` và `coverageSummary` hiển thị
  số mục thực tế trong từng nhóm khi kiểm tra `.ttxbackup`.
  Một nhóm chưa có giá trị đã lưu sẽ trở về giá trị mặc định khi cài mới.

**Không sao lưu được quyền hệ thống Android**, việc người dùng đã đọc hướng
dẫn cấp quyền, hoặc dữ liệu của ứng dụng khác. Cache ngân hàng VietQR tải tự
động từ API công cộng không phải cấu hình riêng của tài xế. Tệp không mã hóa:
hạn chế chia sẻ vì chứa số tài khoản ngân hàng và vị trí đi lại.

**Nhập bản sao:** đang theo nguyên tắc *chỉ bổ sung*, không ghi đè cấu hình,
bảng giá hoặc hóa đơn đã tồn tại. Trên cài đặt mới chưa có cấu hình tương ứng,
các khóa trong tệp được nhập; nếu máy đã có cấu hình, hệ thống giữ cấu hình
máy để tránh làm mất dữ liệu. Logo VietQR chỉ bổ sung khi ô logo chưa có.

## Thêm tài khoản ngân hàng

- Đổi nhãn `Số tài khoản / Alias` thành `Số tài khoản`.
- Tên chủ tài khoản nhập bằng `TextCapitalization.characters` và formatter
  viết HOA ký tự sau khi hoàn tất IME composition; khi lưu luôn `toUpperCase`.
- Giá trị ban đầu khi sửa tài khoản cũng hiển thị bằng CHỮ HOA.
- Không thay thông tin ngân hàng, mã BIN, số tài khoản hoặc bộ sinh VietQR.

## Kiểm thử và bàn giao

- `test/road_label_style_test.dart`: màu nền/đường và loại trừ lớp tên
  đường TTX khỏi cơ chế ẩn nhãn gốc.
- `test/settings_backup_bundle_test.dart`: snapshot đủ sáu khóa
  persistent cùng các nhóm, loại trừ quyền Android, từ chối cấu hình
  mới chưa được khai báo.
- `test/dashboard_preferences_test.dart`: kiểm tra HUD mirror và schema
  dashboard cũ.
- `test/bank_picker_lifecycle_widget_test.dart`: nhập tên tiếng Việt chữ
  thường được chuyển thành CHỮ HOA, loại bỏ nhãn Alias.
- Mọi bài kiểm thử cước, GPS, VietQR, backup/restore phải tiếp tục đạt.
- Kiểm tra **trên Android thật**: nét đường và font đường trong 3D sáng/tối,
  xoay camera, độ co dãn card, nhập tên tiếng Việt bằng bàn phím Android,
  tạo và nhập lại bản sao đủ cấu hình/ảnh logo, GPS và số tiền cước.

Chỉ sửa nhánh `feature/flutter-taximeter-foundation` của
`ThanhTaxiXanh/TTX-AATaximeter`. PR #1 vẫn Draft, không merge `main`.
APK CI có thể dùng chữ ký khác bản đang cài: không gỡ ứng dụng cũ đang
chứa dữ liệu nếu chưa có cách bảo vệ/khôi phục tương ứng.
