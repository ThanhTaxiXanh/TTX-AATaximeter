# Android Auto / Flutter ↔ Kotlin: hiện trạng thử nghiệm (04/11/2026)

## Phân biệt hai giao diện
- **Car Mode và HUD** là giao diện Flutter hiển thị ngay trên điện thoại. Không đồng nghĩa với Android Auto.
- Thư viện Android for Cars App Library cung cấp `CarAppService`, `Session`, `Screen`, template do Android Auto host dựng. Không hỗ trợ render toàn bộ Flutter widget 934×844 tùy ý.
- Danh mục hỗ trợ chính thức `NAVIGATION`, `POI`, `IOT`, `WEATHER`, `MEDIA`, `MESSAGING`, `CALLING`. Đồng hồ tính cước taxi độc lập chưa được xác nhận phù hợp bất kỳ danh mục nào. **Không gắn sai POI/NAVIGATION** chỉ để hiện icon trên xe.
- Ứng dụng không tự động xuất hiện trên Android Auto chỉ vì có class Kotlin.

## Mã nguồn đã chuẩn bị
```text
Flutter TaximeterEngine
    ↓ best-effort MethodChannel: publishState
MainActivity.kt → CarStateStore (SharedPreferences, read-only display)
    ↓ (chưa có Service Manifest declaration)
TtxCarAppService → TtxCarSession → TtxCarScreen (PaneTemplate)
```

`MainActivity.kt` có thể chạy và nhận snapshot trên điện thoại; `TtxCarAppService` và `TtxCarScreen` **được biên dịch** cùng APK nhưng chưa được đăng ký trong manifest. Vì không có car category hợp lệ đã xác minh, hiện tại **chưa có chức năng hiển thị Android Auto**.

Snapshot gồm `status`, `interrupted`, `fareVnd`, `distanceKm`, `elapsedSeconds`, `waitingSeconds`, `speedKmh` và timestamp. Kotlin chỉ hiển thị và cảnh báo dữ liệu cũ quá 15 giây. SQLite là nguồn dữ liệu chuyến, không phải SharedPreferences hiển thị này.

HostValidator dùng allowlist của thư viện (không `ALLOW_ALL_HOSTS_VALIDATOR`); app không đòi quyền sai danh mục. Chưa có điều khiển bắt đầu/kết thúc từ car host.

## Kiểm thử và lộ trình
1. GitHub Actions: `flutter test`, `flutter build apk --debug` phải pass, bao gồm biên dịch Kotlin Android.
2. Android thật: MethodChannel nhận snapshot; app background = tạm ngắt an toàn; app restart = restore tạm ngắt.
3. Chọn phương án tích hợp hợp lệ theo chính sách Android Auto (không sử dụng category sai). Chỉ khi đủ điều kiện mới bổ sung manifest service, `automotive_app_desc.xml` và kiểm thử trên DHU.
4. Hệ thống GPS foreground service độc lập chưa được triển khai; nền không có bảo đảm theo dõi liên tục.
5. UI 934×844/Car Mode Flutter hiện là preview trên điện thoại, không phải screen projection.

Nguồn chính thức:
- https://developer.android.com/jetpack/androidx/releases/car-app
- https://developer.android.com/training/cars/apps/library/set-up-project
- https://developer.android.com/training/cars/apps/navigation

## GPS Foreground Service thử nghiệm (0.3)
`geolocator_android` tự cung cấp location foreground service khi khởi tạo stream với `foregroundNotificationConfig`. Đây là **dịch vụ GPS của plugin**; khác với `TtxCarAppService` Kotlin vẫn chưa được đăng ký Android Auto.
- Khởi động GPS service khi Activity hiển thị, sau khi được người dùng cấp quyền vị trí; trên Android 14+ cần loại foreground service `location` và `FOREGROUND_SERVICE_LOCATION`. `POST_NOTIFICATIONS` chỉ liên quan quyền hiển thị thông báo ở Android 13+, cần đánh giá UX riêng.
- Tệp Android manifest bổ sung `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK`, `ACCESS_FINE_LOCATION` và `ACCESS_COARSE_LOCATION`. Plugin tự merge service declaration.
- Khi chạy nền và tín hiệu còn mới, luồng vị trí vẫn được xử lý bằng cùng một bộ tính cước Dart. Khi không có vị trí tin cậy quá 12 giây hoặc trước khi có fix đầu quá 30 giây, tạm ngắt và checkpoint SQLite. Đây là an toàn giới hạn, không phải cam kết thu cước không mất điểm trong trường hợp hệ thống kill app.
- Không thêm `ACCESS_BACKGROUND_LOCATION` vào manifest bản này: luồng service chỉ bắt đầu từ app visible rồi tiếp tục chạy khi chuyển nền. Không khởi chạy FGS từ nền không có quyền.
- Phải kiểm tra thiết bị thật các trường hợp màn hình tắt, ứng dụng đa nhiệm, tắt GPS, từ chối quyền, hệ thống tiết kiệm pin, FGS notification, ghi trùng vị trí và gián đoạn dài.
- Tài liệu chính thức: https://pub.dev/packages/geolocator ; https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
