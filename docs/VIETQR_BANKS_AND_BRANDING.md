# TTX AATaximeter 0.7 — VietQR, ngân hàng và thương hiệu QR

## Chuyển khoản
- Chỉ dùng Tiền mặt hoặc Chuyển khoản trên hóa đơn. Khi chọn Chuyển khoản, QR hiển thị ngay bên trong hóa đơn.
- Hóa đơn chỉ hiển thị Trạm thu phí và số tiền theo hàng ngang, kể cả số tiền bằng 0.
- Đã bỏ bảng giá BOT riêng. Nhập phí BOT thủ công khi đang chạy chuyến; không tự tính dựa trên GPS.

## Ngân hàng VietQR
- Danh sách 76 mã BIN trong assets/data/vietqr_banks.json, snapshot VietQR v2 ngày 2026-11-04.
- Khi có kết nối Internet, chương trình có thể cập nhật và lưu JSON trong thư mục ứng dụng mỗi 24 giờ; khi offline vẫn dùng snapshot.
- Lọc theo tên ngân hàng/BIN; mục transferSupported=0 vẫn hiện để tra cứu nhưng không cho chọn tài khoản chuyển tiền.
- Có thể lưu tối đa 15 tài khoản và chọn một tài khoản mặc định; bản cũ ttx_vietqr_account_v1 được di chuyển vào BankBook.
- Tên chủ tài khoản và số tài khoản là dữ liệu do tài xế nhập, không được tự xác minh bằng API.

## Tạo QR
- QR tạo cục bộ từ EMVCo/NAPAS với CRC16; qr_flutter vẽ nền trắng, chấm đen, error correction H.
- Tải một logo tròn nhỏ ở giữa QR và một logo thương hiệu lớn bên dưới bằng FilePicker. Hỗ trợ PNG/JPG/JPEG/WebP/GIF/BMP/SVG, giữ alpha nếu tệp có nền trong suốt.
- Hai logo nằm trong kho ứng dụng, không gửi ra máy chủ VietQR.
- Để tránh khó quét: logo trung tâm nhỏ, chừa khoảng trắng quanh QR, kiểm tra với vài ứng dụng ngân hàng khác nhau trước khi dùng thật.
- QR không chứng minh đã nhận tiền. Cần tự kiểm tra biến động số dư của đúng ngân hàng.

Nguồn: https://api.vietqr.io/v2/banks ; https://pub.dev/packages/emv_qr_builder ; https://pub.dev/packages/qr_flutter ; https://pub.dev/packages/file_picker