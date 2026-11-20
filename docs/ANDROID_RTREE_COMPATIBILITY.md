# Android: lỗi `no such module: rtree` khi nhập biển báo

## Nguyên nhân đã xác định

Trên thiết bị Android có thư viện SQLite không kích hoạt module RTree,
truy vấn `SELECT sign_id FROM traffic_sign_rtree LIMIT 1` trả về:

```text
DatabaseException(no such module: rtree (code 1 SQLITE_ERROR))
```

Đây là lỗi **khả năng của SQLite native trên thiết bị**, không phải
tệp GeoJSON hay SQLite do người dùng nhập sai.

Tệp chính vẫn là `ttx_traffic_signs.sqlite` với SHA-256
`a8dc5b6f3b09546604a395d3236a9a9b12872cc81162e86db9f2a878e5319ec7`,
21.090.304 byte, 151.228 bản ghi biển báo và 151.228 bản ghi chỉ mục RTree.

## Sửa chữa trong ứng dụng

1. Giữ nguyên SHA-256, kiểm tra metadata, `PRAGMA quick_check`, số hàng
   `traffic_signs` và bảng vật lý `traffic_sign_rtree_rowid`.
2. Thử truy vấn RTree bằng `SELECT sign_id FROM traffic_sign_rtree LIMIT 1`.
3. Nếu **đúng** lỗi `no such module: rtree`: vẫn chấp nhận tệp đã xác minh
   nhưng chọn truy vấn bounding box trực tiếp từ bảng `traffic_signs`
   theo `longitude BETWEEN ? AND ?`, `latitude BETWEEN ? AND ?`.
4. Mọi lỗi khác (schema hỏng, thiếu bảng, metadata sai, checksum sai)
   phải tiếp tục chặn dữ liệu, không được tự bỏ qua.
5. Giữ nguyên lọc mã biển, tốc độ suy ra, danh sách biển riêng, gom cụm
   và bất biến tổng số biển bằng tổng số cụm. Không ghi/sửa SQLite gốc.
6. Luồng nhập vẫn chỉ thay dữ liệu lớp biển báo, **không can thiệp** cơ sở
   dữ liệu chuyến hay thuật toán tính cước.

## Kiểm tra trên Xiaomi Redmi Note 12 Pro

- Cài **TTX Driver Pro QA** có mã gói `.qa` từ workflow PR #12 sau khi
  Flutter tests, analyze, APK build và kiểm tra gói QA đều `success`.
- Chọn **Nhập SQLite từ điện thoại**, cấp quyền chọn tệp trong Android.
- **Kỳ vọng:** không còn `no such module: rtree`, nút **Hiển thị biển báo**
  bật được, bản đồ 2D và MapLibre đều hiển thị biển / cụm.
- Mở nhiều mức zoom và lọc biển theo loại, theo tốc độ suy ra.
- Kiểm tra chuyển 2D/3D, offline (không có nền đường offline), GPS và cước.
- Ghi lại `SQLite: N truy vấn · p50 X ms · p95 Y ms` để đánh giá hiệu năng
  **trên chính thiết bị**, không suy ra tốc độ Android từ CI/Linux.
- Nếu RTree không có, truy vấn có thể chậm hơn. Đây là đường khôi phục chức
  năng an toàn, không phải cam kết thông lượng của chỉ mục không gian.

## Điều kiện chặn phát hành

Cần kết quả thực tế trên thiết bị, kiểm định dữ liệu biển báo và cổng
TTX-VN-MAP-01 trước khi tuyên bố bản đồ đủ điều kiện phát hành.
Biển tốc độ suy ra không phải giá trị giới hạn tốc độ pháp lý.
