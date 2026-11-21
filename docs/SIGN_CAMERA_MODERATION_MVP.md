# TTX Driver Pro — Phân hệ quản lý biển báo & camera (MVP cục bộ)

## Phạm vi thực hiện

Có một màn hình bản đồ riêng **Quản lý biển báo & camera** được mở từ nút
**Báo vị trí** trên bản đồ 2D/3D TTX Driver Pro. Trong FlutterMap 2D, nhấn giữ
một vị trí cũng mở màn hình này với tọa độ vừa chọn.

Màn hình mới hỗ trợ:

- **Thêm** biển báo/camera tại vị trí chọn trên map, nhập mã V1 và giá trị
  thô (nếu có).
- **Sửa** bản ghi gốc theo `sign_id`: đề xuất tọa độ/mã/giá trị mới.
- **Xóa** theo `sign_id`: chỉ tạo đề xuất xóa (không xóa ngay).
- **Báo cáo**: mô tả thực địa bắt buộc và vị trí GPS trên bản đồ.
- **Chờ duyệt**: báo cáo chưa duyệt có biểu tượng màu vàng **chỉ trong màn
  hình quản lý**; KHÔNG xuất hiện trong bản đồ tài xế.
- **Duyệt/Từ chối**: quyết định phải có ghi chú, lưu sự kiện vào nhật ký;
  duyệt mới cập nhật lớp bản đồ tài xế; từ chối không sửa bản đồ.
- **Đã duyệt**: biểu tượng xanh lá trong màn hình quản lý; trên bản đồ
  tài xế chính hiển thị như biển báo/camera theo mã V1 đã chọn.

## Kiến trúc và cách giữ an toàn dữ liệu

```text
ttx_traffic_signs.sqlite     (cơ sở dữ liệu chủ dữ liệu 151.228 vị trí;
  readonly, SHA-256 nguyên vẹn, không ghi/sửa/xóa)
              |
              | đọc tọa độ + bảng gốc
              v
TrafficSignRepository <---------- approved_signs
              |                       ^
              |                       |
    FlutterMap 2D / MapLibre 3D       |
                                      |
                    sign_moderation_v1.sqlite
                      | reports [pending/approved/rejected]
                      | approved_signs [effective rows / tombstones]
                      | review_audit [decisions + timestamps + notes]
```

**Khi phê duyệt:**

- `add`: tạo `sign_id` âm, không trùng ID từ nguồn (giữ nguyên ID=0 hợp lệ).
- `edit`: bản ghi gốc bị ẩn khi truy vấn và được thay bằng bản đã duyệt;
  SQLite gốc hoàn toàn không thay đổi.
- `delete`: ghi *tombstone*, lọc ID gốc ra khỏi truy vấn **trước khi gom
  cụm**. Không thể khôi phục bằng cách đọc nhầm lại các marker gốc.
- Nếu báo cáo cũ cạnh tranh với thay đổi đã được duyệt, xét duyệt thất bại
  bằng kiểm tra phiên bản (optimistic concurrency).
- Tổng số biển báo trong viewport được kiểm tra khớp tổng số của các cụm,
  không tạo hàng chục nghìn widget cùng lúc.
- Hoạt động với cả SQLite RTree và fallback bbox khi Android thiếu RTree.
- Không kết nối dữ liệu phê duyệt với GPS tính cước, lộ trình đã lưu, xử phạt
  hay giới hạn tốc độ pháp lý.

## Hạn chế quan trọng: chỉ là quản trị CỤC BỘ QA

**MVP này KHÔNG cung cấp hệ thống nhận báo cáo từ nhiều tài xế qua mạng.**
Các báo cáo chỉ tồn tại trên thiết bị đã nhập. Chức năng phê duyệt cục bộ
được mặc định **tắt** trong build thông thường. Chỉ các APK **QA** có
`--dart-define=TTX_LOCAL_APPROVAL_QA=true` mới có nút xử lý báo cáo.
Đây là lựa chọn thử nghiệm, **không có xác thực quản trị qua máy chủ**:
bất kỳ ai được phép sử dụng APK QA trên máy này đều có thể bấm duyệt.

Để mở thành hệ thống cho đội xe, cần một backend có:

1. Đăng nhập tài xế và người quản trị, xác thực bằng token và **kiểm tra
   vai trò duyệt ở phía máy chủ** (không thể ủy quyền bằng UI hay PIN lưu máy).
2. Các endpoint đề xuất: `POST /v1/sign-reports`,
   `GET /v1/moderation/reports?status=pending`,
   `POST /v1/moderation/reports/{id}/decision`,
   `GET /v1/signs/approved?since=<revision>`.
3. Một bản ghi báo cáo giữ `report_id` UUID/idempotency key, mã loại,
   giá trị, hướng, tọa độ, ghi chú, nguồn, hình ảnh bằng chứng được quyền
   sử dụng và thời gian thu thập.
4. Kiểm tra quyền truy cập, kiểm soát tần suất gửi (rate limit), nội dung
   ảnh, chống trùng, lịch sử audit không cho người gửi tự xóa.
5. Sử dụng transaction để duyệt + phát hành một `revision`; client chỉ
   đọc thay đổi với `status=approved`, xác minh nguồn khi đồng bộ offline.
6. Chặn người dùng thường gọi endpoint duyệt; thêm cơ chế thu hồi biển
   và xử lý xung đột theo phiên bản.
7. Tối ưu số lượng cập nhật lớn bằng cơ sở dữ liệu không gian ở máy chủ
   (PostGIS hoặc tương đương), thay vì SQL `NOT IN` của bản QA.

**Không được gọi hệ thống QA là đã có máy chủ hoặc phê duyệt từ xa.**

## Kiểm thử trên Xiaomi Redmi Note 12 Pro

1. Chỉ dùng APK `ttx-driver-pro-qa-arm64-test-only` của PR #14 sau khi
   Flutter tests, analyzer, xác minh package `.qa` và build thành công.
   Không gỡ ứng dụng taxi chính.
2. Nhập `ttx_traffic_signs.sqlite` đã đối chiếu trong APK QA.
3. Mở bản đồ, nhấn nút **Báo vị trí**. Chạm/nhấn giữ điểm mới, thử gửi
   **camera giao thông mã 4**, nhập ghi chú.
4. Quay về bản đồ tài xế: vị trí báo cáo **chưa được hiển thị**.
5. Vào màn hình quản lý: chọn báo cáo → **Duyệt**, nhập ghi chú.
   Quay về bản đồ tài xế: điểm camera mới xuất hiện ở đúng tọa độ.
6. Thử gửi mã 10 (camera AI), mã 1 với giá trị `value_raw=80`.
   Chỉ trường mã 1 mới được giải mã thành số biển tốc độ.
7. Chọn `sign_id` gốc cụ thể, gửi **Sửa** (đổi mã/đổi tọa độ).
   Trước duyệt: không thay đổi. Sau duyệt: ID cũ chỉ xuất hiện ở tọa độ mới.
8. Gửi **Xóa** một ID đang có: trước duyệt vẫn hiển thị, sau duyệt biến
   mất khỏi bản đồ và tổng cụm cập nhật. Kiểm tra lại khi mất mạng.
9. Từ chối một báo cáo khác: nó không xuất hiện trên bản đồ chính.
10. Khởi động lại ứng dụng: quyết định đã duyệt/từ chối vẫn còn.
11. Theo dõi p50/p95 SQLite và GPS/tính cước; các thay đổi bản đồ không
    được ghi vào cơ sở dữ liệu chuyến hoặc làm thay đổi cước.

### Tình trạng kỹ thuật và điều kiện phát hành

- Kho dữ liệu bổ sung và màn hình quản lý là **MVP cục bộ**.
- Giới hạn an toàn 750 bản ghi được duyệt trong kho QA trước khi xây hệ thống
  đồng bộ/snapshot; không phải mục tiêu quy mô toàn quốc.
- Các ảnh icon từ ZIP đã được đối chiếu một phần ở PR #13; mã khác vẫn chưa
  được gán ảnh nếu chưa có căn cứ.
- Biển báo và camera do cộng đồng đề xuất là dữ liệu *chưa xác minh thực địa*
  cho đến khi có quy trình kiểm định độc lập; duyệt nội bộ không đồng nghĩa
  hợp pháp hoặc còn hiệu lực.
- Lớp bản đồ quản lý vẫn áp dụng redaction và nhãn biển đảo của dự án.
  Cổng `--publish` vẫn phải có bằng chứng trước bất kỳ phát hành công khai.
- Không thay đổi khóa ký phát hành, dữ liệu ngân hàng, GPS ghi chuyến,
  thuật toán tính cước hoặc `main`.
