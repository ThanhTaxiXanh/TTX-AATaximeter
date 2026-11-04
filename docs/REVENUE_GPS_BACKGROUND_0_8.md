# TTX AATaximeter 0.8.0 — Revenue UI & GPS route

## Fix cho GPS gián đoạn khi chuyển app/tắt màn hình
- Trước: watchdog 12s gọi _suspendForGps, cancel subscription của Geolocator và khiến chuyến không thể tự nhận GPS sau khi sóng trở lại.
- Sau: vẫn giữ Geolocator Android foreground service đang đăng ký. Khi thiếu dữ liệu đáng tin, đồng hồ chỉ skipUntrustedInterval, không cộng cước; khi vị trí mới đáng tin cậy xuất hiện, đặt baseline mới.
- Khi service báo lỗi, bị đóng, hoặc process kill: vẫn có thể tạm ngắt an toàn; KHÔNG cam kết đo liên tục sau force-stop hoặc OEM kill. Mở lại khôi phục SQLite ở trạng thái tạm ngắt, cần người dùng chủ động tiếp tục.
- Android permission & FGS existing: ACCESS_FINE_LOCATION/COARSE/BACKGROUND, FOREGROUND_SERVICE_LOCATION, notification foreground và wake lock của geolocator_android. Không đăng ký thêm service GPS Kotlin cạnh tranh trong phiên bản này.
- Vẫn cần thử Xiaomi MIUI/HyperOS thật: bật vị trí chính xác + luôn cho phép, thử không giới hạn pin, thông báo hiển thị, chuyển app, màn hình tắt 5/15/30 phút. Kiểm tra cước/km trước và sau. Thử khi xe dừng với người thao tác; không thao tác khi lái.

## Tuyến GPS
- Chỉ ghi nhận các GPS samples đã qua TaximeterEngine.acceptGps, giảm mật độ mẫu.
- Lưu routePoints (lat,lon,accuracy,speed,time,segment) trong SQLite payload của chuyến và snapshot khôi phục mỗi ~3 giây, không đổi schema SQL. Dữ liệu chuyến cũ vẫn đọc được và có tuyến trống.
- Segment mới khi GPS bị gián đoạn hoặc khi tài xế bấm Tiếp tục, để không nối hai tọa độ thành hành trình giả.
- Dashboard/Chi tiết chuyến: vẽ tuyến bằng PolylineLayer của flutter_map; marker đầu/cuối; bản đồ nền OSM cần Internet, tọa độ lưu offline trên máy. Không tạo ảnh chụp tĩnh hay xuất ảnh PNG trong bản này.

## Doanh Thu
- 4 bộ lọc thời gian local: hôm nay (00:00), tuần (thứ 2), tháng (mùng 1), tất cả.
- 4 thẻ KPI, danh sách lịch sử sắp xếp gần nhất, chi tiết chuyến có bản đồ và nút xem biên lai.
- Chỉ ẩn chuyến thực sự rỗng (totalFare <=0, distanceKm <=0, durationSeconds <=0), vẫn giữ trong SQLite, bao gồm khả năng hiển thị chuyến miễn phí có hành trình.
- Số tiền và quãng đường tính từ TripReceipt đã lưu (không tính lại giá từ GPS khi đọc Doanh Thu).

## Lưu ý / còn hạn chế
- Đây là tăng độ bền luồng hiện tại, CHƯA có engine tính cước độc lập trong native Kotlin. Nếu Android dừng hẳn Flutter isolate/process, tính cước liên tục không được bảo đảm. Không hồi tố cước cho khoảng trống thiếu bằng chứng.
- Không phải đồng hồ taxi có kiểm định đo lường; cần đối chiếu GPS/đồng hồ thương mại trên các tuyến đường thử.
- Xem .github/workflows/flutter-debug.yml để kiểm thử Flutter, Gradle, manifest và tải APK debug.
