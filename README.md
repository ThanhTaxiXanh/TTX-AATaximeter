# TTX AATaximeter

Ứng dụng đồng hồ tính cước taxi bằng Flutter/Dart, **tái triển khai độc lập** dựa trên đặc tả hành vi đã khảo sát từ APK Taximeter Pro được cung cấp. Đây không phải mã nguồn Kotlin dịch ngược nguyên bản.

## Tiến độ
- **Đã có:** báo cáo phân tích APK, máy trạng thái đồng hồ cước, biểu giá phân đoạn, phí chờ/BOT/phụ thu/giảm giá, giá cố định, unit tests, giao diện MVP và GPS foreground.
- **Chưa có/không tuyên bố hoạt động:** Android Auto host, lưu SQLite lâu dài, toàn bộ settings/QR/LED/MP3/biên lai hoàn chỉnh, đảm bảo tính cước khi app chạy nền, APK release đã ký.
- Các con số trong `TariffConfig.demo()` là **minh họa**, không phải biểu giá mặc định đã đối chiếu được từ APK gốc.

## Xây dựng
Repo chưa check-in thư mục Android do không có Flutter SDK trong môi trường khảo sát. Trên GitHub Actions sẽ chạy `flutter create . --platforms=android --project-name ttx_aataximeter --org vn.thanhtaxixanh` rồi chèn quyền GPS trước khi test/build debug. Trên máy có Flutter tương thích có thể chạy tương tự.

```bash
flutter create . --platforms=android --project-name ttx_aataximeter --org vn.thanhtaxixanh
python3 tool/bootstrap_android.py
flutter pub get
flutter test
flutter build apk --debug
```

Xem `docs/REVERSE_ENGINEERING_REPORT.md` về bằng chứng và lộ trình.

## Android Auto
Flutter/Dart làm domain/shared application logic. Android Auto phải bổ sung `CarAppService` + `Session` + `Screen` **bằng Kotlin** theo Android for Cars App Library, không thể render Flutter widget tự do lên host như điện thoại. Giữ chính sách tương thích và an toàn cho người lái.

Không đính kèm APK gốc, tài sản âm thanh/ảnh QR của tác giả gốc hay dữ liệu cá nhân.

## Bằng chứng video giao diện Taximeter Pro (04/11/2026)
Đã xem hai video tham chiếu màn hình dọc 720×1600 và lập bảng thời gian, giá cước, hành vi và ma trận mức tương đồng ở [VIDEO_UI_REFERENCE.md](docs/VIDEO_UI_REFERENCE.md). Preset 4 chỗ trong mã lấy từ màn hình video (12.000đ mở cửa/0,5km, 14.500đ/km, 30.000đ/giờ chờ). Unit test `15km → 222.000đ` đối chiếu với video; **không** khẳng định chứng nhận pháp lý. Giao diện bổ sung vòng cung tốc độ, các nút BOT, báo giá có lộ trình, Car Mode/HUD trên điện thoại. Bản ghi không có hình ảnh Android Auto thật.

## P1: biên lai, SQLite, VietQR và cấu hình (đang kiểm thử)
- Hoàn tất chuyến → lưu vào SQLite (migrate lịch sử cũ từ SharedPreferences một lần) → hiển thị biên lai theo video.
- Lịch sử đầy đủ với KPI doanh thu/km/số chuyến, xem biên lai, thay đổi lựa chọn phương thức thanh toán và xóa sau xác nhận.
- VietQR theo tài khoản do người dùng tự nhập (mã BIN, tài khoản, chủ tài khoản). Nút `Tạo mã VietQR` mới tải ảnh từ img.vietqr.io và gửi thông tin thanh toán tới nhà cung cấp; **không xác nhận tiền đã nhận**.
- Biểu giá/GPS mở rộng và lưu cấu hình, preset khác xe 4 chỗ thiếu một số ngưỡng nên gắn nhãn **chưa đủ thông số**.
- **Giới hạn quan trọng:** chuyến đang chạy chưa khôi phục sau khi app bị kill; GPS chưa có foreground service; SQLite là bước cải tiến lưu chuyến kết thúc, không phải giải pháp an toàn kế toán tuyệt đối. Chưa triển khai Android Auto native.

## Giai đoạn phục hồi chuyến và native Kotlin (đang kiểm thử)
- `TripSessionSnapshot` chứa biểu giá nguyên gốc, tổng cước, trạng thái chuyến và lộ trình; mỗi 3 giây tạo checkpoint vào SQLite. Khi app bị đưa xuống nền hoặc khởi động lại, phiên tính cước được **tạm ngắt** và yêu cầu tài xế tiếp tục. Khoảng thời gian không có GPS tin cậy không tự tạo phí chờ/km.
- Chuyến kết thúc và xóa snapshot được commit **cùng một SQLite transaction**, giảm rủi ro mất chuyến khi bị đóng bất ngờ.
- Native bridge `MainActivity.kt` đồng bộ trạng thái hiển thị tới `CarStateStore`; `TtxCarAppService`, `TtxCarScreen` chuẩn bị Car App Library 1.7.0 và **chưa đăng ký service** vì đồng hồ cước độc lập không có danh mục Android Auto đã xác nhận. Xem `docs/ANDROID_AUTO_ARCHITECTURE.md`.
- Chưa thể tính cước liên tục khi ứng dụng không được cấp foreground location service; bản này ưu tiên không thu phí sai hơn là giả lập đường đi trong thời gian mất tín hiệu.

## Giai đoạn 0.3: GPS Foreground Service (thử nghiệm Android)
- Dùng `geolocator_android.AndroidSettings(foregroundNotificationConfig: ...)` để khởi động foreground service **loại `location`** do plugin Geolocator quản lý. Có thông báo liên tục và wakelock khi chuyến đang hoạt động; không tạo thêm GPS service Kotlin thứ hai.
- Chỉ xin quyền từ màn hình đang hiển thị, trước khi bắt đầu/tiếp tục chuyến. Không tự yêu cầu `ACCESS_BACKGROUND_LOCATION` hay tự khởi động dịch vụ mới khi đã vào nền.
- Khi hoàn tất chuyến hủy subscription, dừng FGS theo cơ chế Geolocator. Không lấy mẫu vị trí sai số lớn, nhảy GPS hoặc cũ làm tín hiệu đáng tin cậy. Mất tín hiệu quá ngưỡng tạm ngắt và yêu cầu tiếp tục thủ công.
- Chưa bảo đảm dịch vụ tiếp tục chạy sau **force stop/process kill** hoặc chính sách tiết kiệm pin của OEM. SQLite phục hồi ở trạng thái tạm ngắt, không tự cộng thời gian hoặc km không quan sát được.
- Chưa kiểm chứng trên điện thoại Android thật; kiểm thử màn hình tắt, chuyển app, quyền GPS, MIUI battery saver, vùng GPS yếu, cả khi kết nối Android Auto.
