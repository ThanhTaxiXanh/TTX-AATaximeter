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
