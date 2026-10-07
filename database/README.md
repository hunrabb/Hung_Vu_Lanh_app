# Chuẩn bị migration sang Aiven PostgreSQL

Ngày rà soát: 07/10/2026. Đây là thiết kế cho database mới, chưa chạy trên Aiven,
chưa thay Mock Repository hoặc thêm dependency Flutter. SQL dùng PostgreSQL,
không chạy nguyên bản trên MySQL. Chạy `001_core_postgresql.sql` trước, rồi
`002_existing_features_postgresql.sql` để giữ đầy đủ các feature đang có.

## Các model đã quét

Nguồn chính là `lib/core/models/`. Các file domain trong auth/catalog/booking/
schedule chỉ re-export model chính. Không có `category.dart`; danh mục hiện là
enum `ServiceCategory`, nhãn ở `core/utils/category_labels.dart`.

| Dart model | Fields thực tế | SQL |
| --- | --- | --- |
| Branch | id, name, address, phone: String | branches, TEXT |
| AppUser | id/name/email: String; role: UserRole; createdAt: DateTime UTC; loyaltyPoints: int; specializedCategoryIds: List<String>; averageRating: double?; isFeatured/isApproved: bool; branchId/phone/address: String? | users + staff_specializations |
| Service | id/name: String; category: ServiceCategory; categoryId: getter category.name; durationMinutes/priceVnd: int; isActive: bool | services + categories |
| Appointment | id/branchId/customerId/staffId/customerName: String; serviceIds/serviceNamesSnapshot: List<String>; startAt/endAt: getter UTC từ TimeSlot; totalPriceVnd: int; status: AppointmentStatus; isHiddenByCustomer/isHiddenByStaff/isReviewed: bool; rating: int? | appointments + appointment_services |
| ShopSettings | id/branchId: String; openingMinute/closingMinute: int; closedWeekdays: List<int>; closedDates: List<String> yyyy-MM-dd | shop_settings; SMALLINT, SMALLINT[], DATE[] |
| StaffShift | id/staffId: String; startAt/endAt: getter UTC từ TimeSlot | staff_shifts (002) |
| Promotion | id/title/subtitle/imageUrl: String; isActive: bool | promotions (002) |
| TimeSlot | start/end: DateTime UTC; duration: getter Duration; overlaps: method | start_at/end_at, không có bảng riêng |
| LeaveRequest | id/staffId/staffName/branchId/date/note: String; createdAt: DateTime; status: LeaveStatus; reviewedBy/reviewedByName/reviewedBranchName: String?; reviewedAt: DateTime? | staff_leave_requests (002) |

Conversation và ChatMessage đã đọc nhưng thuộc communication ngoài scope core;
không tạo bảng chat. Không có entity doanh thu, hoa hồng, khách hàng của Staff
hoặc Sessions. Những số liệu đó vẫn phái sinh từ appointments.

## Quyết định mapping cần giữ

- ID dùng TEXT để nhận dữ liệu mock hiện tại; backend phát ID mới, không dùng
  microseconds từ client làm nguồn cấp ID production.
- Enum role giữ nguyên `superAdmin/manager/staff/customer`, status giữ `noShow`.
  Categories giữ đúng sáu enum ID, gồm `hairWash`. Thêm category mới sẽ cần đổi
  enum Dart và CHECK SQL cùng đợt; không tạo catalog tự do khi UI chưa hỗ trợ.
- Catalog/giá chung toàn chuỗi. Chuyên môn Staff dùng bảng liên kết có FK tới
  categories; không JSON-array không kiểm tra tham chiếu.
- Appointment nhiều dịch vụ dùng appointment_services. `position` giữ thứ tự;
  backend trả `serviceIds`/`serviceNamesSnapshot` theo position. Snapshot tên và
  tổng tiền giữ nguyên khi catalog đổi tên/giá. Chưa thêm snapshot giá từng item
  vì model hiện chỉ có tổng giá lịch, không có đơn giá mỗi dịch vụ.
- `customerId='walk-in'` đổi thành `customer_id=NULL`, giữ customer_name là tên/
  SĐT khách vãng lai. API đọc đổi NULL về `'walk-in'` để không làm gãy Dart model.
  Không tạo một user giả dùng chung cho khách vãng lai.
- TIMESTAMPTZ lưu instant, API trả ISO-8601 UTC; báo cáo/ngày nghỉ dùng lịch
  `Asia/Ho_Chi_Minh`. Tiền BIGINT nguyên VNĐ, không float. Giờ cửa hàng giữ phút
  0–1440 để biểu diễn được đóng cửa 24:00; weekday là 1–7 như Dart.
- ShopSettings PK là branch_id (một cấu hình mỗi cơ sở). `id='default'` không
  unique toàn chuỗi vì model cho phép cùng ID ở nhiều cơ sở.
- API phải map snake_case → camelCase: đặc biệt `category_id` → `category`,
  `leave_date` → `date`, arrays ngày SQL → chuỗi yyyy-MM-dd. Không truyền trực
  tiếp SELECT * vào các fromJson hiện tại.
- Users.average_rating là field marketing có sẵn, không phải số liệu profile
  Staff; profile vẫn AVG(rating) trên completed/is_reviewed và bỏ cờ xóa mềm.

## Ràng buộc và transaction

001 có PK/FK, email lowercase/unique, role/Branch, rating 1–5, thời gian dương,
giá không âm. Customer/Boss không có branch; Staff/Manager bắt buộc có branch.
IsApproved mặc định TRUE phù hợp Customer; tạo Staff pending phải truyền FALSE.
Manager/Boss/Customer luôn approved; đây là ràng buộc chặt hơn constructor Dart.

auth_credentials tách khỏi profile, chứa **hash** do backend tạo/verify, không
plaintext. Approved và credential phải đồng nhất khi COMMIT. Register/bootstrap
Boss/Manager ghi user + hash cùng transaction. Pending Staff chỉ có profile;
Boss duyệt INSERT credential + UPDATE approval trong một transaction. Thu hồi
Staff xóa credential + đặt approved=false cùng transaction. Không dùng hash
giả của mật khẩu seed để đăng nhập production.

EXCLUDE btree_gist bảo vệ trùng lịch đồng thời theo Staff + khoảng `[start,end)`:
pending/confirmed/completed chặn thời gian, cancelled/noShow không chặn, đúng
TimeSlot hiện tại. Khung liền kề được phép. Appointment + items ghi cùng
transaction; constraint deferred bắt buộc có ít nhất một item.

Trigger kiểm tra role/Branch/approval của Staff lúc tạo hoặc thay thông tin đặt
lịch; Customer FK phải là Customer. Thay trạng thái/ẩn lịch không ép lịch sử
phải theo Branch mới của Staff. Đổi Branch không tự cập nhật lịch cũ.

Các FK lịch sử dùng RESTRICT: không xóa Branch/User/Service còn tham chiếu. Với
dịch vụ đã phục vụ, dùng is_active=false. Khác mock hiện tại, backend phải báo
lỗi rõ khi UI yêu cầu hard-delete User/Service đã có lịch. Khi Boss đổi role khỏi
Staff, xóa liên kết chuyên môn trước trong cùng transaction; không sửa role/Branch
hoặc ID trên lịch lịch sử. Endpoint đổi role vẫn phải do Boss thực hiện.

002 lưu lịch sử nghỉ phép thực tế, không bỏ tính năng đang có. Quyết định chỉ
pending → approved/rejected, snapshot Staff/Manager/cơ sở và ngày gửi bất biến;
history đã quyết định không cập nhật. Gửi lại sau rejected tạo record ID mới.
Không grant DELETE lịch sử cho tài khoản API. StaffShift chỉ giữ model hiện có;
chưa biến nó thành điều kiện bắt buộc của slot engine.

## Quyền truy cập: backend bắt buộc

CHECK/FK/role trong dữ liệu **không xác thực người gọi API**. Ví dụ SQL biết
reviewed_by là Manager cùng cơ sở, nhưng không biết ID đó có phải người đang
đăng nhập. Backend lấy actor từ JWT đã verify, đọc lại role/Branch/approval
trong users; không tin role/branch_id/customer_id/reviewed_by từ form.

- Register public chỉ customer. Manager tạo Staff pending ở Branch phiên, không
  cấp mật khẩu/approval. Boss quản lý Branch/catalog và cấp credential.
- Manager query/mutation chỉ Branch mình; Staff chỉ ca/khách/thu nhập của mình;
  Customer chỉ lịch cá nhân và roster Staff công khai đã bỏ email/SĐT/địa chỉ.
- Ẩn lịch không giảm báo cáo; pending/completed/noShow/cancelled theo state machine
  đang có, không cho client tùy ý UPDATE status/review/snapshots/giá.
- Booking kiểm tra specialty, dịch vụ active, thời lượng/giá snapshot do server
  tính, giờ mở/đóng, ngày đóng cửa, giờ quá khứ và leave approved. Những luật này
  không được giả định đã đủ chỉ vì INSERT vượt qua DDL.
- Booking và duyệt nghỉ dùng chung quy ước khóa Staff row `FOR UPDATE` trước khi
  kiểm tra dữ liệu và ghi, chống race đặt lịch trong khi duyệt nghỉ. Giờ/settings
  và catalog cũng cần transaction/lock phù hợp. Lịch đã đặt không tự hủy khi nghỉ.
- Tài khoản migration sở hữu schema; tài khoản API riêng, không superuser/table
  owner, chỉ grant SELECT/INSERT/UPDATE cần thiết; mật khẩu_hash không trả ra API.
  Không coi Aiven DB account hoặc enum UserRole là bốn PostgreSQL login roles.

DDL chưa bật RLS/policies hoặc triển khai backend/JWT. Có thể thêm RLS làm lớp
phòng thủ sau khi chốt backend và trusted session context; không bật policy
giả tin vào biến do client tự đặt. Chưa bật TTL/hard-delete ca phục vụ báo cáo.

## Kết nối đề xuất

Stack được chốt sau thiết kế schema: Flutter → HTTPS API/JWT → NestJS với
@nestjs/typeorm/TypeORM/pg → Aiven PostgreSQL. Scaffold ở `../backend/` hiện có
GET /api/branches; JWT/module nghiệp vụ khác chưa triển khai. Flutter dùng http;
không đưa password DB hoặc driver TCP vào client. Đề xuất backend Dart trước đó
đã được thay bằng NestJS theo yêu cầu người dùng.

Backend kết nối TLS `verify-full`, CA theo Aiven project, pool có giới hạn;
credentials nằm trong env/secret server. Không tắt TLS để bỏ lỗi chứng chỉ.

Nguồn chính thức:
- https://aiven.io/docs/products/postgresql/reference/list-of-extensions
- https://aiven.io/docs/platform/concepts/tls-ssl-certificates
- https://www.postgresql.org/docs/current/ddl-constraints.html
- https://pub.dev/packages/postgres
- https://docs.flutter.dev/cookbook/networking/fetch-data

## Kiểm tra trước deploy

Máy hiện tại chưa có psql/PostgreSQL/Docker trong PATH; chưa chạy DDL trên một
PostgreSQL instance. Cần chạy hai script trên database test mới của Aiven và
kiểm tra transaction register/approval, overlap đồng thời, FKs, walk-in, rename
snapshots, leave và query đúng Branch trước khi chuyển repository app.

Không nhập nguyên seed production: phone/address chi nhánh là dữ liệu mẫu;
pending Staff chưa có credential; ID branch phải được map tường minh. Giữ schema
migration riêng, không dùng DROP/recreate trên database đang có dữ liệu.

Lịch sử nghỉ đã duyệt nếu được export từ RAM phải import bằng job migration có
quyền, kiểm tra FK/CHECK và bảo toàn snapshots/reviewed_at gốc trước khi bật trigger
leave_record (hoặc tạm tắt riêng trigger này trong transaction import rồi bật lại).
Không replay quyết định qua API vì nó sẽ ghi tên/thời điểm hiện tại thay lịch sử.
