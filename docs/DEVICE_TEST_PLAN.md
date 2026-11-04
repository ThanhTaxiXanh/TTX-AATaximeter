# Quy trình thử nghiệm TTX AATaximeter GPS nền trên điện thoại Android

**Phiên bản:** 0.3.1 debug, cần build mới nhất PASS.

**Điều kiện:** Bản thử nghiệm chưa được kiểm định làm đồng hồ tính cước thương mại. Dùng một hành trình thử, không thu tiền khách. Không thử thao tác khi đang lái xe; người hỗ trợ thao tác hoặc thử trên xe đang dừng.

## 1. Cài đặt và cấp quyền
1. Trên điện thoại Android tải `app-debug.apk` từ artifact GitHub Actions của PR, giải nén ZIP rồi cài APK.
2. Trong Cài đặt > Ứng dụng > TTX AATaximeter > Quyền: cho phép **Vị trí chính xác khi sử dụng ứng dụng**, và **Thông báo** nếu Android yêu cầu. Không chọn quyền vị trí giả.
3. Bật Vị trí/GPS của hệ thống. Mở app và chỉnh **biểu giá thử**.
4. Nếu dùng Xiaomi MIUI: trong Cài đặt > Ứng dụng > Quản lý ứng dụng > TTX AATaximeter, kiểm tra mục tiết kiệm pin/Battery saver và ưu tiên **Không hạn chế (No restrictions)** nếu có. Tên màn hình có thể khác MIUI 13/14 và HyperOS. Không tắt chế độ bảo vệ hệ thống toàn máy.

## 2. Bảng thử nghiệm tối thiểu
| # | Trình tự | Kết quả mong muốn |
|---|---|---|
| 1 | Bật GPS chính xác, bấm **Bắt đầu** khi app ở màn hình trước | Thông báo liên tục `TTX AATaximeter • Đang tính cước`, trạng thái GPS hiển thị trên app |
| 2 | Khởi đầu tại nơi GPS chưa xác định, đứng yên | Trong khi chưa có fix tin cậy, **không cộng tiền chờ/quãng đường** |
| 3 | Có GPS chính xác, đi một đoạn được phép dừng thử | Km tăng từ từ, không nhảy hàng km tức thời |
| 4 | Chuyển app sang màn hình chính hoặc một app khác, giữ vị trí bật | Thông báo GPS vẫn hiện; không tự tạm ngắt khi GPS có cập nhật đều |
| 5 | Khi đang thử, tắt định vị hệ thống và chờ hơn 12 giây | Chuyến tạm ngắt, không tăng tiền vì khoảng GPS mất |
| 6 | Mở app, bật GPS và nhấn **Tiếp tục** | Hệ thống chờ GPS mới; không cộng quãng đường nhảy trong lúc mất |
| 7 | Khóa màn hình khi có GPS tốt, quan sát một khoảng thời gian | Thông báo vẫn còn; kiểm chứng quãng đường bằng hành trình an toàn |
| 8 | Kết thúc chuyến, kiểm tra thanh thông báo và lịch sử | GPS service ngừng, hóa đơn không bị nhân đôi, lưu SQLite |
| 9 | Từ màn danh sách ứng dụng gần đây, vuốt tắt app giữa chuyến | Nếu hệ thống kill tiến trình, mở lại sẽ ở **tạm ngắt an toàn**, không tự cộng thời gian không quan sát |
| 10 | Thu hồi quyền vị trí giữa chuyến thử | Luồng GPS báo lỗi/tạm ngắt, không tiếp tục cộng cước |

## 3. Cách báo lỗi
Cần ghi phiên bản Android/MIUI, mã bản build (commit SHA), thời gian, quyền vị trí đã cấp, trạng thái màn hình/foreground notification, cước/km trước và sau, và bước số bao nhiêu. **Không gửi video có thông tin cá nhân/tài khoản ngân hàng/biển số chưa được che.**

## 4. Giới hạn đã biết
- Foreground Service không bảo đảm vẫn hoạt động sau Force Stop, hệ thống quá tải hoặc OEM giết tiến trình.
- Dart timer bị giãn thời gian vẫn là khả năng cần kiểm chứng thực tế; nếu luồng vị trí bị gián đoạn, ứng dụng tạm ngắt.
- Nhận `ACCESS_COARSE_LOCATION` thay vì vị trí chính xác có thể gây thời gian chờ GPS rất lâu; cần cấp Fine Location.
- Không có chứng nhận đồng hồ taxi. Không có Android Auto host thực: CarAppService Kotlin vẫn là scaffold chưa đăng ký.
