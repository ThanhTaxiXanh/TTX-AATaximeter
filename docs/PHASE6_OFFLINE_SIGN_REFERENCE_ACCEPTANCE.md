# TTX Driver Pro — Kiểm thử chế độ tham khảo GPS / biển báo offline

Trạng thái: **tính năng để thử nghiệm**, không phải chứng nhận bản đồ nền offline,
bản đồ phát hành hay đồng hồ taxi được kiểm định pháp lý.

## 1. Ranh giới chức năng

- Chế độ **OSM raster** cần kết nối mạng cho tile chưa có sẵn.
- Chế độ **OpenFreeMap vector** cần tải style/tile từ nguồn bên ngoài.
- Chế độ **Chỉ GPS / Biển báo** không tạo TileLayer hoặc MapLibreMap; nó vẽ
  nền trung tính, các điểm GPS/tuyến đã ghi và biển báo đã nhập bằng SQLite/RTree.
- Các nhãn địa lý do ứng dụng quản lý, vùng che biển đảo và HUD cố định vẫn
  hoạt động; bản đồ không sinh ranh giới hoặc đường giao thông giả.
- Biển báo có giá trị `speed_kmh_inferred` là **dữ liệu suy ra**. Không kết nối
  vào giới hạn tốc độ pháp lý, cảnh báo tài xế hoặc tính cước.
- Nếu chưa nhập tệp SQLite hợp lệ, chế độ này không hiển thị biển giả.

## 2. Chuẩn bị trên Android không dùng máy tính

1. Lưu/sao lưu thông tin chuyến, cấu hình và ngân hàng bằng cơ chế backup hiện tại.
2. Chỉ cài APK thử nghiệm vào thiết bị/cấu hình thử nghiệm tương thích chữ ký.
   Không gỡ ứng dụng taxi đang chứa dữ liệu để cài một APK debug có chữ ký khác.
3. Trên GitHub, mở Actions của PR #10 và kiểm tra cả Flutter CI, kiểm thử
   dữ liệu và build APK đã kết thúc với `success`.
4. Tải **đúng** tệp SQLite đã xác minh:
   `ttx_traffic_signs.sqlite`, 21.090.304 byte; SHA-256:
   `a8dc5b6f3b09546604a395d3236a9a9b12872cc81162e86db9f2a878e5319ec7`.
5. Trong bản đồ 2D, mở nút Biển báo và nhập tệp từ trình chọn tệp Android;
   ứng dụng phải kiểm tra checksum, schema và không cần quyền nhà phát triển.

## 3. Quy trình kiểm thử thủ công

### Kết nối mạng và chuyển bản đồ

- Mở ứng dụng ở 2D raster: xác nhận GPS/tính cước vẫn dùng tuyến GPS cũ.
- Chạm nút đổi nền 2D lần thứ nhất: chuyển sang vector.
- Chạm lần thứ hai: chuyển sang chế độ **Chỉ GPS / Biển báo**.
- Tắt Wi-Fi và dữ liệu di động: **không tạo yêu cầu tile mới**, tiếp tục
  zoom/pan, tìm sign_id, chạm biển và phóng to cụm.
- Đọc nhãn rõ ràng `CHỈ GPS / BIỂN BÁO · KHÔNG CÓ BẢN ĐỒ NỀN`.
- Chuyển ngược về raster sau khi bật mạng: không bị kẹt hoặc trùng layer.

### Bản đồ và nhãn biển đảo

- Kiểm tra `Hoàng Sa (Việt Nam)`, `Trường Sa (Việt Nam)` trong HUD,
  cả khi chưa có GPS và mất mạng.
- Di chuyển camera đến vùng nhãn địa lý: xác nhận điểm neo không thay đổi,
  không tạo polygon hoặc ranh giới giả.
- Tắt/bật biển báo và zoom, xoay liên tục: không che mất nhãn địa lý, không
  mất lớp che dữ liệu nền chưa thẩm định.

### Dữ liệu và hiệu năng

- Tổng SQLite: 151.228; tập con tốc độ: 38.757; không trùng theo sign_id.
- Khi zoom toàn quốc, cụm phải có tổng số chính xác, không tạo 151 nghìn
  widget marker.
- Tại zoom đường phố, biển không có tên đã kiểm chứng phải dùng marker
  trung tính và dữ liệu thô; tốc độ suy ra có ký hiệu `~`.
- Đo FPS/p95 frame, bộ nhớ, thời gian truy vấn tại ít nhất một nơi dày đặc.
- Trong lúc đang tính cước, bật/tắt biển liên tục và thực hiện chuyển 2D ↔
  3D nhiều lần. Kiểm tra độ dài GPS, cước và lịch sử không thay đổi ngoài
  dự kiến.

## 4. Điều kiện chặn phát hành

- Test Flutter và analyzer đạt, workflow không bỏ qua lỗi.
- Test thực tế trên Xiaomi Redmi Note 12 Pro: **chưa có bằng chứng** nếu
  chưa được chạy trên thiết bị và lưu kết quả.
- 3D style không tải được khi offline: **không** tuyên bố 3D đã có bản đồ
  offline thực sự. Có thể chuyển sang chế độ tham khảo GPS/biển báo 2D.
- TTX-VN-MAP-01 vẫn phải được thi hành; kiểm định nền bản đồ cần bằng chứng
  và `python3 tool/check_map_sovereignty.py --publish` phải đạt mới được
  xem xét phát hành bên ngoài.
- Không merge nhánh `main` hoặc phát hành APK thương mại trước khi có
  phê duyệt riêng.
