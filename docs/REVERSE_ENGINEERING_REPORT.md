# Báo cáo phân tích tĩnh Taximeter Pro APK — 04/11/2026

## 1. Phạm vi và phương pháp
Mẫu: `Taximeter Pro_v1.2_20261103.apk` (27 MB); SHA-256 `ba4e1653f12c38ae3290e7f4cf502383bac6cb4e1f696b117a356b2ebb4fd940`.
Đã mở ZIP, giải mã nhị phân AndroidManifest/XML, phân tích 11 DEX (bảng class, method, chuỗi, tham chiếu gọi hàm), kiểm tra tài nguyên và truy vết các lớp có tên `com.example`. Chưa thực thi APK trên Android, chưa có ảnh chụp màn hình thật, chưa quan sát lưu lượng mạng/SQLite runtime. Đây là reverse-engineering tĩnh, KHÔNG phải khẳng định ứng dụng đã qua kiểm thử động.

## 2. Metadata và nền tảng
- Manifest package: `com.aistudio.taximeter.vtknqa`; `versionCode=1`, `versionName=1.0` (khác `v1.2` trong tên file).
- minSdk 24; targetSdk 36; compileSdk 36; `android:debuggable=true`; `android:allowBackup=true`; `android:usesCleartextTraffic=true`.
- Kotlin + Jetpack Compose; Room database; SharedPreferences; Google Fused Location Provider; Android for Cars App Library.
- Quyền: Internet, GPS chính xác/gần đúng, foreground service/location, wake lock, vibrate, Car Navigation/Map template/surface.
- Dịch vụ Android Auto: `com.example.car.TaximeterCarAppService`, `TaximeterCarSession`, `TaximeterMainCarScreen`; intent categories NAVIGATION và POI; `res/xml/automotive_app_desc.xml` chỉ ra `template`.
- Tài nguyên: `loi_chao.mp3`, `ket_thuc.mp3`, `hello.wav`, `videoplayback.mp4`, ảnh QR cộng đồng/ủng hộ và biểu tượng. Không đưa nguyên nội dung/asset sở hữu trí tuệ của APK vào repo mới.

## 3. Bản đồ kiến trúc APK
```text
MainActivity / MainAppContent
  ├─ DashboardScreen: TopGpsStatusBar, DigitalSpeedometer, FareDisplayCard,
  │  MeterControls, QuickTollButtons, LiveCurrentRoadCard, BottomFooterToolbar
  ├─ TariffSettingsScreen: PresetCard, PaymentQrSettingsCard,
  │  TripSoundSettingsCard, LedBannerStore, VehicleRegistrationDialog
  └─ TripHistoryScreen: TripHistoryItem, Receipt
        ↓
TaximeterViewModel → TripManager → TripState / TariffConfig
                   ├─ LocationTracker → GpsData
                   ├─ GpsTrackingApiService → GpsTelemetryPayload (tùy chọn)
                   ├─ TaximeterRepository → Room/SQLite (trips, tariff_config)
                   └─ TripSoundManager → audio + Android TTS
Android Auto Host → TaximeterCarAppService → Session → MainCarScreen
                   ↘ cùng TripManager / TripState
```

## 4. Điều hướng và giao diện
**Luồng có chứng cứ lớp/chuỗi:** đồng ý điều khoản `TermsConsentDialog`; khai báo biển số/loại xe `VehicleRegistrationDialog`; dashboard `DashboardScreen`; các nút chân trang `Mã QR | Bao giá | Lịch sử | Cài đặt`; màn hình cài biểu giá `TariffSettingsScreen`; màn hình lịch sử `TripHistoryScreen`.

**Dashboard:** thanh trạng thái GPS/chuyển mô phỏng; đồng hồ tốc độ km/h; khung số tiền cước; quãng đường/thời gian chờ/thời gian chạy; thẻ tên đường; bắt đầu/tạm dừng/tiếp tục/kết thúc; thêm phí BOT; HUD và Car Mode; LED marquee. Có nhãn lập trình Compose `dashboard_screen`, `current_road_name_card`, `bottom_footer_toolbar`, `simulation_switch`, tuy nhiên chưa xác minh pixel, kích cỡ và trạng thái hiển thị trực tiếp.

**Cài đặt:** tên gói, mở cửa, số km đầu, giá mỗi km, điểm chuyển giá đường dài, giá đường dài, phí chờ/giờ, ngưỡng tốc độ chờ, giới hạn tốc độ cảnh báo, làm tròn 1.000đ, bộ lọc GPS (độ chính xác tối đa, hệ số hiệu chuẩn, thời gian đưa vận tốc về 0); các mẫu giá; VietQR; giới thiệu xe; lời chào/cảm ơn MP3-TTS; màu và nội dung LED. Chứng cứ: `TariffConfig` có 21 tham số/thuộc tính và chuỗi trong `TariffSettingsScreen`.

**Bao giá:** `TripCalculatorDialog` có điểm đón, điểm trả, số km dự kiến, một chiều/hai chiều, mức giảm lượt về (30/50/70%, mặc định hiển thị 50%), phí BOT, đơn giá và nội dung chia sẻ báo giá; `startFlatFareTrip` chạy chuyến giá cố định.

**Kết thúc chuyến:** `TripReceiptDialog` trình bày phí mở cửa, quãng đường, cước km/chờ, BOT, phụ thu/giảm giá, tổng tiền, phương thức thanh toán; chia sẻ và VietQR; `TripHistoryScreen` có tổng doanh thu/số chuyến, xem chi tiết, xóa từng chuyến/xóa tất cả.

**Thanh toán:** `PaymentQrStore.generateQrUrl` dựng `https://img.vietqr.io/image/<BIN>-<account>-compact2.png?amount=<amount>&addInfo=<memo>&accountName=<name>`; danh sách ngân hàng Việt Nam cấu hình; QR theo tổng cước. Chỉ gọi sau khi người dùng cung cấp tài khoản; tránh mặc định thông tin từ APK.

**Âm thanh:** `TripSoundManager` hỗ trợ raw MP3, URI MP3 người dùng và fallback TTS tiếng Việt. Phát khi bắt đầu/kết thúc.

**Đường/GPS:** `RoadNameAnalyzer` kiểm tra, lọc các tiền tố Đường/Phố/QL/TL/Cầu/Hầm/Ngõ...; `LocationTracker` dùng fused location, GPS simulation, watchdog, lọc độ chính xác, hiệu chuẩn; `TripManager` xây nội dung chia sẻ Google Maps.

**Android Auto:** app gốc tạo `CarAppService`, `Session`, `Screen`; hiển thị tiêu đề, LED, biển số/xe, tên đường, GPS, vận tốc/giới hạn, cước, quãng đường, thời gian và trạng thái; các hành động `BẮT ĐẦU CHUYẾN`, `TẠM DỪNG`, `TIẾP TỤC`, `KẾT THÚC`, `CUỐC MỚI`. Đây là Android for Cars native template, **không phải** giao diện Flutter được chiếu nguyên màn hình. Tên `isOverSpeedLimit` chứng minh logic so sánh ngưỡng cấu hình; không chứng minh ứng dụng tự nhận diện biển báo giao thông.

## 5. Mô hình miền
`MeterStatus = IDLE | RUNNING | PAUSED | FINISHED`.
`TariffConfig`: baseFare, baseDistanceKm, perKmRate, longDistanceThresholdKm, longDistancePerKmRate, waitingFeePerHour, waitingSpeedThresholdKmh, speedLimitKmh, roundToThousands, gpsStopTimeoutSeconds, gpsMinAccuracyMeters, gpsCalibrationMultiplier, gpsZeroSpeedThresholdKmh, enableApiTracking, apiTrackingUrl, apiTrackingIntervalSeconds, driverId, enableReverseGeocoding, currency, tariffName.
`TripState`: thời gian, khoảng cách, tốc độ hiện tại/tối đa, phí BOT/phụ thu/giảm, GPS, địa chỉ/tên đường, mode HUD/Car, giá bao, tọa độ, API status.
`TripRecord`: thông tin chuyến, tách từng khoản phí, vị trí đón/trả, thời gian, cách thanh toán.
`GpsTelemetryPayload`: biển số, loại xe, ID tài xế, vị trí, tốc độ, cước hiện tại, quãng đường, thời gian, BOT, trạng thái. API hardcoded tham chiếu `https://taximeter-server.onrender.com/api/gps-track` (không gửi request trong bước kiểm tra).

Hàm `TripState.getDistanceFareAmount` gọi các getter `baseDistanceKm`, `perKmRate`, `longDistanceThresholdKm`, `longDistancePerKmRate`; hàm `getRawTotalFare` gọi mở cửa + cước km + phí chờ; getter `getTotalFare` kiểm tra `roundToThousands`. Điều này xác nhận biểu giá phân đoạn, tuy nhiên các trường hợp sát ngưỡng/làm tròn phải đối chiếu trên APK chạy thực tế. Phiên bản Flutter khởi đầu dùng cách tính mới theo yêu cầu sản phẩm, không tuyên bố tương đương bytecode 100%.

## 6. Vấn đề/rủi ro cần khắc phục
1. `android:debuggable=true` trong mẫu, **không** phù hợp build release.
2. `usesCleartextTraffic=true` và network security config cho phép HTTP; bản mới chỉ HTTPS mặc định.
3. `TaximeterCarAppService.createHostValidator` có chuỗi `ALLOW_ALL_HOSTS_VALIDATOR`; bản mới phải triển khai xác thực host phù hợp, không sao chép chính sách quá rộng.
4. Telemetry chứa dữ liệu vị trí/biển số, cần opt-in, chính sách xóa dữ liệu, endpoint cấu hình và kiểm soát bảo mật.
5. Thiếu foreground-service đặc thù trong manifest gốc cho việc tính cước khi app bị đưa về nền; cần kiểm thử thực tế mất GPS/kill process/reboot.
6. Category NAVIGATION/POI dùng cho taximeter phải đánh giá tuân thủ Android Auto. Developer Mode không bảo đảm App Library hợp lệ với chính sách nền tảng.
7. Không dùng mặc định các QR, ngân hàng, địa chỉ, số điện thoại, tên người hoặc server của APK gốc.

## 7. Kế hoạch tái triển khai clean-room bằng Flutter/Dart
**P0 (commit nền tảng trong nhánh này):** domain engine thuần Dart, quản lý trạng thái chuyến, tính cước phân đoạn, phí chờ/BOT/phụ thu/giảm giá, bao giá cố định; màn hình Flutter mức MVP; unit tests; mẫu CI tạo Android project và build debug. Biểu giá được gắn nhãn ví dụ, không trích số gốc chưa xác minh.

**P1:** SQLite/Drift, TripRepository, lưu phục hồi chuyến giữa các lần khởi động, màn hình lịch sử thống kê đầy đủ, biểu giá theo preset, biên lai, chia sẻ, VietQR cấu hình, âm thanh/LED, đồ thị kiểm thử GPS, hiệu chuẩn, bộ lọc vị trí và reverse geocoding có giới hạn.

**P2 Android Auto:** Android Kotlin `CarAppService → Session → Screen` theo Android for Cars App Library, đọc và phát sự kiện qua native repository/MethodChannel hoặc EventChannel; Dart xử lý nghiệp vụ, native car host xử lý template/UI và lifecycle. Chỉ dùng category/template được phép, trải nghiệm lái xe tối giản.

**P3:** HUD/mirror, bố cục xe các tỷ lệ (đặc biệt 934×844), chế độ xe kết hợp QR & LED, backup/export, kiểm thử dài giờ, quản lý quyền, phân tích tiêu thụ pin; phát hành APK signed qua Actions.

## 8. Bảng test bắt buộc
- 0 km, đúng tại baseDistance, đúng tại longDistanceThreshold, ngay trước/sau ngưỡng; quãng đường lớn.
- Vận tốc <5km/h, tạm dừng/tiếp tục, đồng hồ khi app nền và khi GPS mất; hiệu chuẩn GPS.
- GPS nhảy 100–500m, vị trí nhiễu thấp, fix cũ, precision kém, tốc độ đột biến, back-to-back fix.
- Bao giá 1/2 chiều, âm tiền/NaN, phí BOT, phụ thu, giảm > tổng tiền, làm tròn 1.000đ.
- Restart app khi RUNNING, lưu theo transaction, hoàn tất và duplicate receipt.
- VietQR tiền/ghi chú UTF-8, không gửi vị trí/tài khoản tới endpoint lạ; không ghi bí mật vào repo.
- Android Auto DHU và xe thật: host, lifecycle, đảo màn hình, đọc được khi lái xe, ràng buộc nền tảng.

## 9. Kết luận mức chắc chắn
**Chắc chắn qua mã/lớp:** kiến trúc, model, route, permission, API endpoint, UI strings/tên composable, các hành động và khả năng Android Auto.
**Cần xác minh động:** vị trí chính xác của controls, hình ảnh theme, mức giá preset thực tế, thời gian chờ có tính khi pause, độ chính xác GPS, behavior khi bị kill, Android Auto host acceptance, tính toán ranh giới từng biểu giá, QR được quét trong xe.
**Không có trong APK:** đầy đủ source Kotlin/Compose gốc, hình ảnh screen runtime, DB người dùng, thông số server hoạt động.
