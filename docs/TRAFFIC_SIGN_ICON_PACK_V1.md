# TTX Driver Pro — kiểm kê icon giao thông V1

**Nguồn trực tiếp từ chủ dữ liệu:** `traffic_signs.zip`, SHA-256
`ba106dffbdbf7a9f811963812d9a557fbba8196a73f6fc86e1bdf4df8b2e8d22`.
Gói gồm **26 tệp PNG chính** và 26 file `__MACOSX/._*` metadata.
Các icon được kiểm tra trực quan trước khi đối chiếu với danh mục loại biển
do người cung cấp xác nhận ngày 21/11/2026.

## 8 đối chiếu đủ căn cứ triển khai

| sign_type_code | Loại theo V1 | Tên PNG đã kiểm tra |
|---:|---|---|
| 2 | Vào khu dân cư | `residential_area_start.png` |
| 3 | Hết khu dân cư | `residential_area_end.png` |
| 5 | Cấm vượt | `no_overtaking_start.png` |
| 6 | Hết cấm vượt | `no_overtaking_end.png` |
| 32 | Đèn đỏ | `traffic_light.png` (biểu tượng cảnh báo đèn tín hiệu, **tạm dùng**, không phải hình biểu tượng đèn đỏ độc lập) |
| 36 | Cấm ô tô rẽ phải | `no_car_right_turn.png` |
| 38 | Cấm rẽ trái và quay đầu | `no_left_turn_and_uturn.png` |
| 40 | Cấm rẽ trái | `no_left_turn.png` |

Ảnh PNG được chuyển thành bản 64x64, 32 màu, lưu nhúng trong
`lib/src/traffic_signs/presentation/traffic_sign_icon_pack.dart` để làm
marker nhẹ, hoạt động khi offline, không cần quyền lưu trữ bên ngoài.

**2D**: dùng `Image.memory` theo mã loại biển, giữ nguyên sự kiện chạm.
**MapLibre 3D/vector**: đăng ký PNG trong style sau khi lớp che biển đảo hoàn
tất; vẽ qua symbol layer dưới nhãn `Hoàng Sa (Việt Nam)`,
`Trường Sa (Việt Nam)`. Nếu MapLibre native không hỗ trợ icon động, vẫn
hiển thị marker chữ/vòng tròn cũ; lỗi icon không được làm mất biển báo.
**Cụm**: vẫn hiển thị số lượng; không dùng 1 icon cụ thể làm đại diện sai.

## Những icon chưa đủ căn cứ để gán mã

Giữ nguyên trong bộ ZIP và chờ chủ dữ liệu xác nhận mã tương ứng:

`no_motorcars`, `no_car_left_turn`, `no_left_or_right_turn`,
`end_speed_restriction`, `tunnel`, `no_straight`, `no_entry`,
`no_parking`, `no_stopping_and_parking`,
`no_straight_and_right_turn`, `end_all_restrictions`,
`no_right_turn_and_uturn`, `toll_booth`, `no_horn`,
`no_car_uturn`, `no_right_turn`, `no_straight_and_left_turn`,
`no_uturn`.

- **Mã 50/51**: chủ dữ liệu đã xác nhận chung là *cấm dừng/đỗ*,
  nhưng chưa xác định tách riêng. Không gán `no_parking` hay
  `no_stopping_and_parking` cho 50/51 khi chưa rõ.
- **Mã 1**: số biển tốc độ tiếp tục vẽ từ `value_raw` trên vòng đỏ; không
  ghép nhầm `end_speed_restriction` là biển tốc độ cụ thể.
- **Mã 4/10**: gói ZIP không có icon camera giao thông/camera AI tương ứng,
  giữ nhãn CAM/AI.
- **Mã chưa biết**: vẫn dùng ký hiệu chưa xác định, không suy diễn.

## Quy tắc an toàn và nghiệm thu

Dữ liệu `ttx_traffic_signs.sqlite` giữ nguyên byte và SHA-256. Chỉ thay
đổi lớp hiển thị; không kích hoạt giới hạn pháp lý, quy tắc giao thông,
thu phí taxi hoặc cảnh báo tự động dựa vào nhận dạng còn tạm thời.
Cần nghiệm thu icon 2D/MapLibre trên Xiaomi Redmi Note 12 Pro vì MapLibre
native Android từng có trường hợp không render `addImage` thành công.

Bắt buộc chạy unit tests, flutter analyze, CI và TTX-VN-MAP-01 trước
khi phân phối. `python3 tool/check_map_sovereignty.py --publish` vẫn
yêu cầu bằng chứng độc lập trước phát hành bản đồ công khai.
