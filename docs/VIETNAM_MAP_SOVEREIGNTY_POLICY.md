# TTX-VN-MAP-01 — Quy tắc bắt buộc về bản đồ (theo yêu cầu chủ sản phẩm)

## Quy tắc cứng của dự án

Đối với **mọi bản đồ, tile, kết quả tìm kiếm địa lý, hình xem trước và ảnh chụp/xuất ra ngoài** của TTX Driver Pro:

- Sử dụng cách ghi **Hoàng Sa (Việt Nam)**, **Trường Sa (Việt Nam)** và **Biển Đông**.
- Không phát hành tên gọi hoặc ranh giới thể hiện các tuyên bố chủ quyền cạnh tranh mà chủ sản phẩm không chấp thuận.
- Khi thay đổi nguồn dữ liệu, URL tile, style, bộ lọc tên, geocoder, lớp biên giới, ảnh chụp hoặc đường xuất bản, **bắt buộc chạy kiểm thử chủ quyền**.
- Không tự tạo ranh giới đảo/quần đảo từ điểm neo nhãn. Ranh giới thực tế phải đến từ nguồn dữ liệu đã kiểm định độc lập.

Đây là **chính sách hiển thị của sản phẩm**, không phải sự xác nhận độc lập về giải quyết tranh chấp quốc tế.

## Các lớp bảo vệ đã thêm

1. `lib/src/ui/vietnam_map_sovereignty.dart` là điểm duy nhất chứa URL nguồn nền bản đồ, cách ghi nhãn chuẩn và bộ lọc tên do ứng dụng kiểm soát.
2. 2D raster có lớp nhãn neo Hoàng Sa, Trường Sa, Biển Đông; 3D MapLibre dựng một GeoJSON nguồn nhãn và lớp symbol trên style. Những điểm này **chỉ dùng để đặt nhãn xấp xỉ**, không phải tọa độ ranh giới.
3. Kết quả tên đường do ứng dụng dựng thông qua `VietnamMapSovereignty.approvedLabel()`; các cách ghi không duyệt được chuẩn hóa hoặc bị từ chối.
4. `test/vietnam_map_sovereignty_test.dart` kiểm tra nhãn, bản địa hóa tên, câu chữ ranh giới bị loại bỏ, GeoJSON không chứa polygon giả và nguồn nền.
5. `python3 tool/check_map_sovereignty.py` **luôn chạy trước Flutter tests trong GitHub Actions**, kiểm tra không có đường URL tile/style mới đi vòng qua chính sách.
6. `python3 tool/check_map_sovereignty.py --publish` là cổng **fail-closed** trước khi phát hành bản đồ/hình ảnh hoặc cung cấp dịch vụ ra bên ngoài. Chạy riêng để xác định các phần chưa có bằng chứng kiểm định.

## Giới hạn thực tế và điều kiện để công bố đạt

App hiện sử dụng OSM raster từ `tile.openstreetmap.org` và OpenFreeMap vector Dark/Liberty. Các ảnh raster là pixel đã vẽ sẵn; một lớp nhãn Flutter không thể xóa ranh giới hoặc nhãn tranh chấp bên trong ảnh. Tương tự, symbol lớp trên MapLibre không bảo đảm loại bỏ mọi hình học hoặc tên của tile vector bên dưới. Vì vậy **chưa xác nhận các nhà cung cấp này đáp ứng chính sách cho toàn bộ tile và mức zoom**.

`docs/VIETNAM_MAP_PUBLICATION_EVIDENCE.json` cố ý đánh dấu `approved_for_external_publication: false`. Cổng `--publish` sẽ **trả lỗi** cho đến khi hoàn tất kiểm định thực tế ở tất cả bốn nhóm:

- **Raster**: xem trực tiếp từng quần đảo và toàn vùng Biển Đông, nhiều mức zoom, ban ngày/ban đêm, kiểm tra chữ/đường tranh chấp nhúng trong pixel.
- **Vector/style**: kiểm tra cả hai style và các tile hành chính/biên giới thực, tên đối tượng/nhãn đa ngôn ngữ, bật/tắt 2D/3D và cả khi mất mạng/chuyển fallback.
- **Tìm kiếm**: thử dữ liệu geocoder thực, dữ liệu địa danh nhập từ bên ngoài và kiểm tra mọi đường render kết quả; chưa có cơ chế tự xác nhận tất cả API tương lai.
- **Ảnh/đầu ra**: xem ảnh chụp màn hình, hóa đơn có bản đồ, thumbnails, ảnh chia sẻ và mọi quy trình xuất bản; đối chiếu điểm nhạy cảm và không chứa nhãn/ranh giới ngoài chính sách.

Mỗi nhóm cần ghi `passed`, người kiểm định, thời gian UTC và SHA-256 của bằng chứng được lưu an toàn, sau đó người có thẩm quyền xác nhận `approved_for_external_publication`. Các thông tin này **không thay thế** công việc xem ảnh/đọc dữ liệu. Không tự đánh dấu đạt bằng test giả hoặc chỉ vì build xanh.

## Quy trình bắt buộc sau MỌI chỉnh sửa bản đồ

```bash
python3 tool/check_map_sovereignty.py
python3 -m unittest discover -s tool -p 'test_map_sovereignty_gate.py'
flutter test test/vietnam_map_sovereignty_test.dart
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
# Khi chuẩn bị phát hành dữ liệu/bản đồ/ảnh ra ngoài:
python3 tool/check_map_sovereignty.py --publish
```

Không đưa bản build vào đường **phát hành bên ngoài** khi cổng `--publish` chưa đạt; không gọi một artifact kiểm thử đã build thành công là “đã kiểm định chủ quyền”.

## Quản trị repository

`.github/workflows/flutter-debug.yml` chạy cổng nguồn tại mỗi push/PR. Để chặn merge ở cấp máy chủ, chủ repository cũng phải đặt bước kiểm tra này thành **required status check trong GitHub Branch Protection/Rulesets**, và áp dụng tương tự cho mọi nhánh phát hành. CI/code chỉ có thể kiểm tra những thứ có thể quan sát; việc bắt buộc review, kiểm định nguồn ảnh và ngăn tải lên ngoài GitHub còn cần quản trị release và bằng chứng người kiểm tra.

Không xóa, sửa hoặc đổi tên các cổng kiểm soát để né test. Khi có yêu cầu thay nhà cung cấp, chỉ thực hiện nếu kiểm thử nguồn và kiểm định dữ liệu thực tế được cập nhật trước khi phát hành.
