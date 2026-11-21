# Danh mục mã biển báo TTX — V1 (tạm thời)

**Nguồn:** Chủ dữ liệu cung cấp ý nghĩa các mã vào ngày 21/11/2026.
Đây là bảng phân loại để **hiển thị** dữ liệu đã thu thập trong TTX Driver Pro,
không phải danh mục quy chuẩn giao thông có hiệu lực pháp lý.

**Tệp đối chiếu:** `ttx_traffic_signs.sqlite`, 21.090.304 byte,
SHA-256 `a8dc5b6f3b09546604a395d3236a9a9b12872cc81162e86db9f2a878e5319ec7`.
Bảng `traffic_signs` có 151.228 vị trí. Không chỉnh sửa tệp này để đặt tên mã;
ứng dụng chỉ giải mã trong `lib/src/traffic_signs/domain/traffic_sign_catalog.dart`.

## Bảng mã được người cung cấp dữ liệu xác nhận tạm thời

| Mã `sign_type_code` | Tên hiển thị | Số bản ghi trong tệp |
|---:|---|---:|
| 1 | Biển báo tốc độ (số trên biển từ `value_raw` > 0) | 39.269 |
| 2 | Vào khu dân cư | 13.387 |
| 3 | Hết khu dân cư | 11.579 |
| 4 | Camera giao thông | 28.466 |
| 5 | Cấm vượt | 4.441 |
| 6 | Hết cấm vượt | 2.030 |
| 10 | Camera AI | 1.549 |
| 32 | Đèn đỏ | 23.572 |
| 36 | Cấm ô tô rẽ phải | 302 |
| 38 | Cấm rẽ trái và quay đầu | 15 |
| 40 | Cấm rẽ trái | 945 |
| 50 | Cấm dừng/đỗ | 6.295 |
| 51 | Cấm dừng/đỗ | 9.967 |

**Lưu ý mã 50 và 51:** chưa đủ căn cứ để xác định mã nào là
“cấm dừng” và mã nào là “cấm đỗ”; cả hai được đặt chung nhãn
**Cấm dừng/đỗ** đến khi có phân biệt cụ thể của chủ dữ liệu.

## Ý nghĩa của giá trị thô

- `value_raw` là một số nguyên được lưu nguyên dạng cho **mọi mã loại**.
- Với **mã loại 1**, 38.757 bản ghi có `value_raw > 0`; đây là số ghi
  trên biển tốc độ tại vị trí theo xác nhận của người thu thập dữ liệu.
  Trên chính tập này, `speed_kmh_inferred == value_raw` cho cả 38.757 bản ghi.
- 512 bản ghi mã loại 1 có `value_raw = 0`: **không hiển thị** biển tốc độ
  `0 km/h` và không đoán một giới hạn mới.
- Có **29 bản ghi thuộc các mã khác** có `value_raw > 0`. Chỉ coi đây
  là thuộc tính thô cần rà soát, không hiển thị thành giới hạn tốc độ.
- Nhãn tốc độ từ `value_raw` trên map là **số ghi ở dữ liệu biển**,
  khác với giới hạn đang áp dụng cho đoạn đường. Chưa kiểm tra phạm vi
  áp dụng, biển mới/mất, hướng hiệu lực, khung giờ và làn đường.
- Không dùng bảng này để kích hoạt cảnh báo quá tốc độ, dẫn đường theo
  luật, điều khiển xe, quyết định mức phạt hoặc tính cước taxi.

## Nguyên tắc phát triển tiếp

1. Mã chưa được xác nhận giữ tên `Chưa xác định (mã N)`; không suy đoán.
2. Thêm mã vào `TrafficSignCatalog.knownCodes`, kèm tên và nhãn ngắn map.
3. Bổ sung test vào `test/traffic_sign_catalog_test.dart` và kiểm thử
   chi tiết trên cả FlutterMap 2D / MapLibre 3D.
4. Nếu ý nghĩa cấm dừng/cấm đỗ, hướng biển, hiệu lực tốc độ hoặc phạm vi
   áp dụng được bổ sung, ghi rõ nguồn và phiên bản mới; không ghi đè âm thầm.
5. Tệp SQLite của chủ dữ liệu được dùng **read-only**; không làm thay đổi
   RTree, hệ thống GPS ghi chuyến, tính cước hay chính sách biển đảo TTX-VN-MAP-01.
6. Trên Android thiếu native SQLite RTree, tiếp tục dùng đường
   fallback chỉ đọc theo tọa độ; cùng bộ mã V1 cho cả hai chế độ.

**Trạng thái:** Provisional V1 — đợi chủ dữ liệu bổ sung các mã khác.
