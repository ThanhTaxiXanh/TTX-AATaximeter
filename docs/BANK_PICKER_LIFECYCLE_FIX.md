# Ngăn lỗi màn đỏ khi chọn ngân hàng

Lỗi thiết bị người dùng gửi: Flutter framework assertion _dependents.isEmpty is not true.

## Mã đã rà soát
- Trước: BankAccountsDialog gọi showDialog(BankAccountEditor). Trong editor lại gọi showModalBottomSheet để tìm ngân hàng và tạo một TextEditingController cục bộ. Ngay sau await showModalBottomSheet, controller bị dispose. Khi animation pop vẫn chưa hoàn tất, giao diện có thể còn phụ thuộc widget/overlay; assertion có thể là triệu chứng.
- Sau: không tạo bottom sheet thứ ba khi tìm ngân hàng. BankAccountEditor hiển thị tìm kiếm/lọc/danh sách ngân hàng ngay trong cùng AlertDialog. Search, number và owner controllers thuộc State và được dispose đúng lúc State dispose, không ngay khi Navigator vừa trả kết quả.
- BankAccountsDialog chấp nhận BankCatalog được truyền trong kiểm thử, tránh network và path-provider; production nạp snapshot offline ngay.
- Widget tests: mở quản lý -> thêm tài khoản -> tìm tên -> chọn -> nhập tên/số -> lưu -> đóng, lặp 2 lần; và hủy tìm kiếm khi ô nhập còn focus. Kiểm tra không có bottom sheet thứ ba và không có ngoại lệ framework.

Chưa thể khẳng định đây là nguyên nhân duy nhất chỉ từ ảnh; cần thử APK thực tế. Nếu vẫn còn lỗi, thu thập full Flutter stacktrace từ adb logcat.

APK debug đã tăng versionCode lên 8 để đảm bảo cài đặt bản vá mới thay cho APK cũ.