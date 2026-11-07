# TTX DRIVER PRO — Bản đồ và trung tâm cài đặt 0.9.14+34

## Yêu cầu từ ba ảnh người dùng cung cấp

1. Bản đồ 3D tối quá đen, đường khó phân biệt và tên đường gần như không thấy.
2. Bản đồ sáng cần hiển thị tên đường, bỏ menu ở góc trái, menu ba chấm ở góc phải, và nút la bàn trong bản đồ. Thay ô đánh dấu xanh bằng thanh tên đường đang đi.
3. Toàn bộ mục cấu hình phải chuyển sang một màn hình Cài đặt chuyên nghiệp, dễ tìm và sử dụng bằng một nút bánh răng.

## Thay đổi mã nguồn thực tế

- `lib/src/ui/road_label_style.dart`: chọn chính xác các lớp tên đường
  `highway_name_other`, `highway_name_motorway` của OpenFreeMap Dark và
  `highway-name-*` của Liberty. Trước đây chỉ có chữ được đổi cách xoay nhưng
  Dark vẫn dùng màu xám gần như đen. Bản mới nâng màu chữ, kích thước và viền.
- `lib/src/ui/drive_map_3d.dart`: khi MapLibre đã tải style, đổi nền Dark
  sang xanh đen, tăng tương phản của các lớp đường chính, nhỏ và cao tốc. Giữ
  nguyên các lớp POI, biển chỉ dẫn, tàu, dữ liệu route và mũi tên GPS.
  Tên đường được căn theo màn hình bằng `text-pitch-alignment: viewport`
  và `text-rotation-alignment: viewport`.
- `lib/src/ui/nearest_road_name.dart`: truy vấn local vector tile
  `openmaptiles/transportation_name` qua `querySourceFeatures`, tìm
  đoạn đường có tên gần điểm GPS thật nhất (tối đa khoảng 42m), ưu tiên tên
  tiếng Việt và chọn hướng phù hợp nếu đang di chuyển. Chu kỳ không quá
  một lần mỗi 6 giây, không gửi tọa độ đến dịch vụ reverse geocoding.
  Nếu không có dữ liệu đường có tên thì thông báo đang xác định, không
  đoán tên đường.
- `lib/src/ui/dashboard_map.dart`: thêm thanh tên đường ở dưới góc phải,
  tránh bảng tốc độ bên trái; bỏ nút la bàn và giữ chế độ sáng/tối, vị trí
  xe, zoom. Tùy chọn hiển thị tên đường có thể bật/tắt.
- `lib/src/ui/driver_pro_settings_screen.dart`: trang Cài đặt mới, có
  tìm kiếm, nhóm Xe & hồ sơ, Thanh toán, Cước phí, Bản đồ & điều hướng,
  Sao lưu & phục hồi, Quyền & hệ thống; chuyển toàn bộ các tác vụ menu cũ
  vào đây. Nhóm bản đồ có lựa chọn 2D/3D, sáng/tối, hiển thị tên đường,
  tự động 3D, góc nghiêng và chỉnh lời chào.
- `lib/main.dart`: loại bỏ hamburger và ba chấm khỏi màn hình chính; dùng
  một nút bánh răng để mở trang cài đặt. Giữ nguyên các thao tác cũ thông
  qua các callback, không sao chép lại logic nghiệp vụ.
- `lib/src/domain/dashboard_preferences.dart`: thêm trường
  `showCurrentRoadName`, mặc định bật kể cả với file JSON cấu hình cũ.

## Giới hạn và thử nghiệm cần thực hiện

- Tên đường bản đồ vector phụ thuộc OpenStreetMap: nếu đoạn đường chưa được
  gắn tên hoặc tile chưa tải, không thể hiển thị tên chính xác. Bản đồ 2D
  raster thuần không cung cấp lớp GeoJSON để truy vấn tên; thanh tên đường
  sẽ hiển thị trạng thái chờ thay vì trả về tên không kiểm chứng.
- Không có thao tác nào dùng dữ liệu tên đường/nhãn để sửa quãng đường tính
  cước, tốc độ GPS, bản ghi SQLite, hành trình hoặc VietQR.
- Độ mượt và độ đọc của các lớp MapLibre phải được kiểm tra trên Android
  thật cả ngày và đêm, khi xoay 90/180/270 độ và ở các mức zoom thực tế.
- Kiểm tra bảng giá, thanh toán VietQR, sao lưu/nhập .ttxbackup, GPS và
  khởi động lại ứng dụng sau khi thay đổi cấu hình.
- APK vẫn ở trạng thái thử nghiệm; không gỡ bản cũ đang chứa dữ liệu quan
  trọng nếu Android không cho cập nhật do khác chữ ký.

## Bảo vệ repository

Chỉ commit trên `feature/flutter-taximeter-foundation`; PR #1 để Draft.
Không merge hoặc sửa nhánh `main`.
