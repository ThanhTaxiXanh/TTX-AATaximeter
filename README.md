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
