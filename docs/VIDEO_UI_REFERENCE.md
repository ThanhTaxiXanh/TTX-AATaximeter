# Bản đồ giao diện và luồng thao tác từ video Taximeter Pro

## Nguồn chứng cứ
- Video 1: `94d445e87e3e1db38f40e2e6bceced78.mov`, khoảng **156,87 giây**, khung hình nguồn 720×1600 sau áp dụng xoay thiết bị.
- Video 2: `ec15b3695076afbcd43c215f7b13c864.mov`, khoảng **75,89 giây**, cũng hiển thị 720×1600.
- Thời điểm dưới đây là xấp xỉ ±2 giây, lấy từ các khung hình video; **không** phải log sự kiện hoặc video chạy Android Auto trực tiếp.
- Video có thông tin biển số/tài khoản ngân hàng/địa chỉ. Không commit các ảnh chứa dữ liệu đó và không điền sẵn dữ liệu của người khác vào mã nguồn.

## Video 1 — Khởi tạo và cài đặt (00:00–02:37)
| Thời gian | Đối tượng quan sát | Chi tiết |
|---|---|---|
| 00:04–00:10 | Đồng ý điều khoản/quyền vị trí | Màn giới thiệu và prompt quyền vị trí của Android |
| 00:12–00:22 | Đăng ký thông tin xe | Các lựa chọn Xe 4 Chỗ, Xe 7 Chỗ, Xe 16 Chỗ; biển số bắt buộc; nút Xác nhận |
| 00:30–00:39 | Dashboard | Đồng hồ tốc độ vòng cung, biển giới hạn góc trên, tổng cước, km/thời gian/chờ, BOT, nút chuẩn và báo giá |
| 00:40–00:49 | Biểu giá mẫu | 4 ô preset 2×2; preset hiện tại màu vàng đậm |
| 00:49–01:01 | Hiệu chỉnh GPS | Giảm tốc về 0 sau 1/2/3/5 giây (2 giây đánh dấu chuẩn); thanh tỉ lệ hiệu chỉnh 1,00x; lọc nhiễu GPS 15/25/35/50m (35m đang chọn); chuyển GPS thành tên đường |
| 01:02–01:09 | Tùy chỉnh biểu giá | Các trường mở cửa, km mở cửa, km tiếp, từ km thứ..., giá đường dài, chờ/giờ, ngưỡng chờ, cảnh báo tốc độ, làm tròn 1.000đ |
| 01:09–01:18 | Thông tin xe và bảng LED | Biển số/loại xe; bật LED; nội dung và mẫu câu; chọn màu vàng/đỏ/xanh lá/xanh lam; xem trước dải chữ chạy |
| 01:18–02:02 | VietQR và âm thanh | Chọn ngân hàng, nhập số tài khoản/tên chủ, xem thử QR và lưu; lời chào/cảm ơn dùng âm thanh mẫu, tệp MP3, TTS |
| 02:12–02:35 | Liên kết khác và lưu | Cộng đồng/góp ý, ủng hộ nhà phát triển, nút Lưu cài đặt biểu cước & GPS |

**Preset giá hiển thị trong video** (chỉ dùng để đối chiếu, KHÔNG khẳng định là giá hợp pháp cho mọi xe):
- `Taxi Đô Thị 4 Chỗ`: **12.000đ mở cửa trong 0,5km, 14.500đ/km**; từ km 30 là 12.000đ/km; phí chờ 30.000đ/giờ; ngưỡng 5km/h; giới hạn cảnh báo 80km/h; làm tròn tới 1.000đ.
- `Taxi 7 Chỗ / SUV`: **14.000đ mở cửa, 16.500đ/km** (các trường còn lại chưa thể xác minh từ video).
- `Xe Dịch Vụ / Xe Ghép`: **15.000đ mở cửa, 13.000đ/km**.
- `Sân Bay - Đường Dài`: **20.000đ mở cửa, 12.000đ/km**.
- Giá mở cửa và/km trong danh sách được đọc từ screenshot; không suy luận km mở cửa của ba preset còn lại.

## Video 2 — Quy trình sử dụng (00:00–01:16)
| Thời gian | Màn hình / tương tác | Chi tiết hiển thị |
|---|---|---|
| 00:00 | Dashboard rảnh | Trạng thái XE TRỐNG, đồng hồ km/h, tổng cước 0đ, ba chỉ số, phí BOT +10k/+20k/+35k/+50k và nút sửa |
| 00:04–00:14 | Tính trước cước và lộ trình | Điểm đón, điểm trả, km dự kiến, nút cộng +5/+10/+20/+50/+100km, một chiều/hai chiều, đơn giá, phí BOT; tổng giá bao màu vàng |
| 00:15–00:22 | Hoàn tất chuyến báo giá | Hóa đơn: tên điểm đón/trả, cước vàng, chi tiết phụ phí, lựa chọn tiền mặt/chuyển khoản/thẻ, VietQR, chia sẻ, Xong & khách mới |
| 00:23–00:27 | QR thanh toán | VietQR có số tiền, tên ngân hàng/tài khoản/chủ tài khoản/nội dung và đóng/đã thanh toán |
| 00:30–00:34 | Báo giá mở lại | Có thể sửa lộ trình và mức dự kiến |
| 00:36–00:42 | Lịch sử | Tổng doanh thu/số chuyến/tổng km; từng thẻ chuyến có lộ trình, cước, thời gian và nút chia sẻ/xóa; trạng thái rỗng sau khi xóa |
| 00:46–00:58 | Car Mode trên **điện thoại** | Giao diện riêng: số tốc độ cyan cực lớn, cước màu vàng, 3 ô km/thời gian/chờ, BOT +10/+20/+50 và nút KẾT THÚC đỏ |
| 01:00–01:06 | Dashboard đầy đủ | Thanh trạng thái GPS + Mô phỏng; LED chạy chữ; tên đường; đồng hồ hình cung và biển tốc độ; nhóm điều khiển |
| 01:06–01:14 | HUD kính lái | Lật ngang (mirror) **giao diện điện thoại**, không phải Android Auto |

**Bằng chứng tính giá quan trọng:**
- Báo giá **15,0 km**, đơn giá **14.500đ/km**, preset trên có mở cửa **12.000đ trong 0,5km**. Công thức: `12.000 + (15-0,5)*14.500 = 222.250đ`; làm tròn đến 1.000đ gần nhất = **222.000đ**, trùng giá hiển thị và hóa đơn trong video.
- Không coi 2 chiều = gấp đôi đơn giản: phải kiểm chứng mức giảm lượt về và BOT cho lượt về. Bản mô phỏng có thể triển khai, nhưng phải đánh dấu khác logic đã kiểm chứng.
- Không có chứng cứ quay trực tiếp màn hình Android Auto; video Car Mode và HUD là giao diện điện thoại. Android Auto vẫn là giai đoạn native Kotlin riêng.

## Hệ thống thiết kế tham chiếu
- Tỷ lệ khung hình **720:1600 = 9:20**, tối ưu màn hình dọc Android và co giãn theo tỉ lệ thực.
- Nền gần đen xanh `#080C18`; thẻ xanh than `#111829`; inset `#1B2437`; viền `#2A3756` (màu đều là **ước lượng trực quan**, cần đo mẫu pixel nếu cần khớp 1:1).
- Cước & CTA nổi bật: vàng `#FFB800`; quãng đường/tốc độ Car Mode: cyan `#00D8F0`; nút bắt đầu: xanh `#00DA75`; kết thúc: đỏ `#FF304C`; phụ đề xám `#A0A9BA`.
- Dashboard không có thanh AppBar tiêu chuẩn chiếm chỗ ở đầu màn; ưu tiên cụm GPS/LED/tên đường phía trên vòng cung tốc độ.
- Thanh chức năng cuối có **4 mục**: Mã QR, Bao giá, Lịch sử, Cài đặt; icon đi kèm và màu phân biệt.
- Mở popup dạng **modal bo góc trên nền tối**, số tiền nổi bật vàng; các lựa chọn dạng segmented/chips.
- Car Mode bản gốc trên video là toàn màn hình **điện thoại**, không thể suy diễn là giao diện Android Auto thật.
- HUD lật ngang toàn bộ vùng xem. Cần kiểm tra hai chế độ một cách riêng biệt.

## Ma trận độ tương đồng và triển khai
| Hạng mục | Chứng cứ | Tình trạng MVP nền tảng | Việc cần làm |
|---|---|---|---|
| Đồng hồ tốc độ dạng cung | Video 2 01:01 | Chưa giống | CustomPainter + badge giới hạn |
| Preset 4 ô và biểu giá 4 chỗ | Video 1 00:40–01:05 | Cước demo khác | Khớp preset mẫu, unit test 15km |
| BOT | Video 2 00:00 | 2 chip | 4 chip + nút nhập tùy chỉnh |
| Quote | Video 2 00:10 | Popup số tiền duy nhất | Điểm đi/đến, km, 1/2 chiều, giá/km, phí BOT, xem trước và bắt đầu cuốc |
| Invoice | Video 2 00:18 | Chỉ thông báo kết thúc | Modal chi tiết + phương thức thanh toán |
| History | Video 2 00:36 | Bottom sheet đơn giản | Màn hình riêng, 3 KPI, thẻ chi tiết |
| QR | Video 2 00:24 | Placeholder | VietQR động từ tài khoản tự thiết lập |
| Car Mode điện thoại | Video 2 00:48 | Switch phóng to cước | View toàn màn hình riêng |
| HUD mirror | Video 2 01:08 | Chưa có | Mirror + toggle |
| Onboarding/Settings | Video 1 | Chưa khớp | Dialog đăng ký, đầy đủ phân vùng và lưu |
| Android Auto thực | Chỉ APK (không có trong video) | Chưa có | Native Kotlin + host validation + DHU |

## Kịch bản kiểm thử hồi quy từ video
1. Chọn preset Taxi Đô Thị 4 Chỗ → tổng ở 0km sau bắt đầu chuẩn phải khớp cước mở cửa theo cấu hình.
2. Báo giá 15,0km, 14.500đ/km, 0đ BOT, 1 chiều → **222.000đ**.
3. Xác nhận báo giá, kết thúc → số tiền trên biên lai phải bằng số báo giá nếu không phát sinh phí khác.
4. Đổi phương thức tiền mặt/chuyển khoản/thẻ không làm thay đổi tổng cước.
5. Lịch sử thêm 1 chuyến và có thể xóa; KPI trở về 0 sau khi xóa.
6. QR động chỉ được dùng thông tin tài khoản do người dùng nhập; xác minh số tiền trên QR khớp hóa đơn.
7. Car Mode và HUD là hai route/view riêng, không gây mất trạng thái cuốc khi chuyển chế độ.
8. Vòng cung 0km/h, biển 80km/h, quãng đường cyan; có fallback nếu GPS yếu.

## Lưu ý
Đây là đặc tả từ video và những lớp mã APK đã khảo sát trước đó. Không chép screenshot có thông tin riêng tư lên repo công khai. Khả năng background service, quy tắc 2 chiều, lifecycle Android Auto và tương đương pixel cần kiểm thử tiếp.
