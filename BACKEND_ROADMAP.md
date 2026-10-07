# Backend Implementation Roadmap — Chain Management

**Phê duyệt: 07/10/2026.** NestJS/TypeORM/pg, Aiven PostgreSQL, TLS CA,
`synchronize: false`. Mọi DDL chạy qua migration được duyệt. Flutter còn dùng mock.

## Quyết định đã chốt

1. Không có ca làm thì không có slot; không fallback toàn bộ giờ mở cửa.
2. Bổ sung `staff_shifts.branch_id`, giữ Branch snapshot của ca.
3. Dùng `auth_credentials.token_version` thu hồi JWT, không tạo Sessions.
4. Không Refresh Token trong giai đoạn này. JWT access mặc định 30 phút.

## Nguyên tắc chung

- Boss là `superAdmin`, quản lý toàn chuỗi; Staff/Manager gắn Branch; Customer
  chọn cơ sở lúc đặt, không ghi Branch vào profile.
- API xác thực JWT rồi đọc lại role/Branch/approval trong DB. Không tin actor,
  customerId, role, Branch hoặc giá do form tự khai. Quyền nằm trong Guards và Service.
- Không thêm bảng doanh thu/hoa hồng/khách hàng của Staff. Tiền nguyên VNĐ;
  timestamp UTC, ngày nghiệp vụ Hà Nội. Không bật synchronize/auto-migration.
- Xóa mềm Customer/Staff độc lập, không làm giảm báo cáo. Catalog chung do Boss ghi.

## Giai đoạn 1 — Auth và phân quyền đa tầng

**Tiến độ:** đã triển khai, build + 6 tests local pass, live Aiven test Auth/Guards
pass; 18 credential seed approved đã chuyển bcrypt. Flutter chưa nối Auth API.

Module Auth dùng @nestjs/jwt, Passport JWT, bcrypt, DTO validation, giới hạn login.

| API | Chức năng |
| --- | --- |
| POST /api/auth/register | Chỉ Customer, Branch NULL |
| POST /api/auth/login | Credential + approval → JWT |
| GET /api/auth/me | Profile hiện tại, không hash |
| PATCH /api/auth/password | Kiểm tra mật khẩu cũ, bcrypt mới, tăng token_version |
| POST /api/auth/logout | Tăng token_version, thu hồi mọi token của tài khoản |

JwtAuthGuard mặc định bảo vệ route; Public chỉ cho register/login và directory
Branches/Categories/Services. RolesGuard và Roles decorator map boss → superAdmin.
Users pending chỉ Boss; Users branch chỉ Boss/Manager, Manager phải đúng Branch.
Service kiểm tra lại quyền, không coi branch path là authorization.

JWT chỉ HS256, secret server, issuer/audience và TTL; validate chữ ký/exp rồi so
role, Branch, approval và token_version với DB. Đổi role/Branch/thu hồi approval
chặn token cũ. Đổi mật khẩu/logout tăng version trong transaction, không refresh.

Hash seed hiện scrypt: verify scrypt rồi rehash bcrypt khi login thành công, ghi
có lock/so sánh hash cũ để không ghi đè password change đồng thời. Không thể bcrypt
compare scrypt hoặc hash lại chuỗi hash thành mật khẩu. Password mới bcrypt cost12,
ít nhất8 ký tự và tối đa72 byte UTF-8, không NUL. Seed password ngắn vẫn được login.

Nghiệm thu: token giả/hết hạn/stale bị chặn; không nâng role qua register;
Manager A không đọc B; Staff pending không login; không log/serialize hash/token.

## Giai đoạn 2 — Onboarding và CRUD theo quyền

**Tiến độ:** đã triển khai Users onboarding + Branch/Service/Category CRUD và
settings patch. Build +8 tests local pass; live Aiven test tạo/sửa/duyệt/reject,
approve race200/409, Staff login, tenant boundaries/FK rollback pass. Dữ liệu thử
được dọn, seed giữ nguyên. Hướng dẫn: backend/PHASE2_TESTING.md. Category IDs vẫn
giới hạn6 enum bởi CHECK; mở rộng IDs cần migration/Flutter model riêng.

| API | Quyền |
| --- | --- |
| POST /api/users/staff | Manager tạo pending tại Branch phiên |
| PATCH /api/users/staff/:id | Manager sửa fields cho phép, cùng Branch |
| POST /api/users/:id/approve | Boss cấp password và duyệt |
| DELETE /api/users/:id/pending | Boss từ chối hồ sơ chưa credential/lịch |
| CRUD /api/branches, /api/services | Boss |
| PATCH /api/branches/:branchId/settings | Boss/Manager đúng Branch |

Hash bcrypt ngoài transaction. Trong transaction khóa Staff FOR UPDATE, kiểm tra
lại pending/Branch/credential; INSERT credential đúng ID + UPDATE approved rồi
COMMIT. Deferred constraint DB bảo vệ cùng transaction. Hai request approve: một
thành công, một409. Không tạo profile ID mới hoặc approved thiếu credential.

Từ chối tuyển dụng xóa pending chưa phục vụ, không lưu rejected/history tuyển dụng.
Boss tự gửi mật khẩu ngoài app; không Zalo/deep link/message API.

## Giai đoạn 3 — Shifts, Settings và Leave Requests

Modules StaffShifts, ShopSettings, LeaveRequests.

**Triển khai 07/10/2026:** StaffShiftsModule và LeaveRequestsModule đã thêm;
migration 005_leave_intervals.sql bổ sung khoảng nghỉ và cho Boss duyệt,
giữ immutable snapshot ở DB. Cấu hình dùng API từ giai đoạn 2.
Hướng dẫn chạy và kiểm thử: [PHASE3_TESTING.md](backend/PHASE3_TESTING.md).
Build và 11 tests local pass; live Phase 3 và hồi quy Phase 2 pass. Đã seed
70 ca cho 10 Staff approved (21/21/14/14 theo bốn cơ sở), API localhost trả 200.

| API | Chức năng |
| --- | --- |
| GET/POST /api/branches/:branchId/shifts | Manager/Boss xem, tạo ca |
| PATCH/DELETE /api/shifts/:id | Quyền Branch, kiểm tra lịch đã đặt |
| GET /api/staff/me/shifts | Staff xem ca riêng |
| POST/GET /api/staff/me/leave-requests | Staff gửi khoảng nghỉ/lý do, xem đơn riêng |
| GET /api/leave-requests | Scope theo phiên |
| POST /api/leave-requests/:id/decision | Manager cùng Branch hoặc Boss |

Seed ca qua backend/seed-staff-shifts.cjs cho 7 ngày tới. branch_id là snapshot,
migration không tự đoán Branch lịch sử khi có ca cũ thiếu mapping.
Pending/rejected không chặn slot; approved chặn lịch mới, không tự hủy ca đã đặt.
Lưu immutable quyết định, Manager ID/tên/Branch snapshot, thời điểm, ghi chú.

## Giai đoạn 4 — Booking Engine

AppointmentsModule đã triển khai. Hướng dẫn API và test đồng thời:
[PHASE4_TESTING.md](backend/PHASE4_TESTING.md). Không thêm migration/DDL;
giữ ràng buộc EXCLUDE có sẵn. Flutter chưa nối API.

**Kiểm tra 07/10/2026:** build +20 tests local pass; live Booking pass, hai
request cùng slot trả201/409 và đúng1 row. Race approved leave chặn booking sau
quyết định; kiểm tra rollback items, BIGINT và scope/state/soft hide pass.
Đã sửa mapping PostgreSQL DATE[] về calendar string để ngày đóng cửa có hiệu lực.
Server localhost:3000 directory/slots/ledger trả200; seed70 ca giữ nguyên,
fixture Staff/Service Giai đoạn4 đã dọn.
Hồi quy Phase2 và Phase3 chạy song song pass sau khi Branch DELETE được đồng bộ
thứ tự khóa settings → Branch để tránh đảo khóa với thao tác lịch.

| API | Chức năng |
| --- | --- |
| GET /api/branches/:branchId/staff?serviceId=... | Approved, cùng Branch, đúng chuyên môn |
| GET /api/booking/available-slots | Query Branch/Staff/dịch vụ/ngày |
| POST /api/appointments | Customer, identity phiên |
| POST /api/appointments/walk-in | Manager, Branch phiên, customer NULL |
| GET /api/appointments | Scope role/Branch/ownership |
| POST /api/appointments/:id/cancel | Hủy theo state machine |
| POST /api/appointments/:id/complete, /no-show | Staff/Manager đúng quyền |
| Endpoint ẩn Customer/Staff | Hai cờ độc lập |

Slots = giao giờ cửa hàng và hợp các ca Staff, trừ nghỉ/đóng cửa/giờ đã qua/lịch
bận. Gộp ca liên tiếp/chồng nhau; dịch vụ phải nằm trọn interval liên tục, không
vượt giờ nghỉ. Nhiều dịch vụ: mọi category phải phù hợp, server tính thời lượng,
giá và snapshots. GET slots chỉ tham khảo, POST luôn kiểm tra lại.

Transaction POST: xác thực → khóa settings/Staff → đọc lại approval, specialty,
shifts, leave, busy intervals, active catalog → INSERT appointment và items → commit.
Khóa Staff row FOR UPDATE: không chỉ khóa appointments đang có vì lịch trống
không có row để khóa. Booking, sửa shifts và approve leave dùng cùng quy ước lock.
Thống nhất thứ tự settings → Staff IDs → service IDs → appointment/leave rows.

DB EXCLUDE USING gist là lớp cuối, Staff + [start,end), chặn pending/confirmed/
completed; cancelled/noShow không chặn, adjacent hợp lệ. 23P01 trả409;
40P01/40001 retry toàn transaction có giới hạn/jitter, không retry overlap vô hạn.
Nghiệm thu: concurrent cùng slot chỉ một booking; race approve-leave và booking
không làm lọt lịch mới; stale slot/giá/approval được kiểm tra lại.

## Giai đoạn 5 — Dashboard/Reporting

**Triển khai 07/10/2026:** ReportsModule có Manager dashboard/revenue, Boss
dashboard/leaderboards/ledger/commission, Staff earnings/profile-stats (bao gồm
customers/LTV). Build +23 tests pass; live Aiven kiểm tra ngày Hà Nội, hai service
items không nhân đôi tổng, tiền BIGINT, scope/role, hidden/reviews/walk-in và
Staff chuyển Branch pass. Không migration/package/schema mới. Hướng dẫn API:
[PHASE5_TESTING.md](backend/PHASE5_TESTING.md).
Server localhost:3000 đã xác minh cả8 endpoint HTTP200; fixture Users/Appointments
Giai đoạn5 đều0 sau cleanup, seed70 ca giữ nguyên. Giai đoạn6 còn nối Flutter API
và nghiệm thu toàn luồng, không coi ứng dụng Flutter đã bỏ mock.

| API | Nội dung |
| --- | --- |
| GET /api/manager/dashboard | Doanh thu ngày, lịch, ca hủy, sắp tới |
| GET /api/manager/revenue | Ngày/tháng, completed ledger, ranking Staff |
| GET /api/boss/dashboard?branchId=... | Toàn chuỗi/theo Branch |
| GET /api/boss/leaderboards | Cơ sở doanh thu/Staff số ca |
| GET /api/boss/appointments | Master ledger lọc Branch/status |
| GET /api/boss/commissions | Tạm tính, chưa chi trả |
| GET /api/staff/me/earnings, /customers, /profile-stats | Cá nhân, LTV, visits, review |

Revenue chỉ completed, kỳ theo start_at/ngày phục vụ như app hiện tại. Tính
bounds Hà Nội thành UTC, query [from,to) để dùng index. Soft-hidden vẫn tính.
Không SUM sau JOIN service items gây nhân đôi tiền. Walk-in NULL không gộp mọi
khách thành một người trong LTV. Manager Branch từ phiên, Staff ID từ phiên,
Boss mới chọn Branch. Tiền BIGINT/numeric trả dạng string để giữ chính xác.

## Giai đoạn 6 — Flutter và nghiệm thu

**Phần4:** Dashboard/Reports Manager/Boss/Staff đã nối UI/API, loading/errors,
money string/BigInt, filter/paging và cache invalidation sau appointment mutation.
110 tests pass +1 live skipped mặc định; live toàn luồng Reports/commission pass.
Hướng dẫn [FLUTTER_API_PART4.md](FLUTTER_API_PART4.md); CRUD/settings khác còn mock.

**Phần3:** Booking và Appointments UI đã nối API, 409 Snackbar/slot reload,
identity server, tiền string, GET status/pagination và actions/cờ ẩn. Catalog đọc
cho Booking đã chuyển, dashboard metrics và analytics chưa nối. Chi tiết:
[FLUTTER_API_PART3.md](FLUTTER_API_PART3.md).
Phần3: analyzer sạch, 108 tests pass +1 live skipped mặc định; live đầy đủ
Customer concurrency/409, cancel, Manager walk-in, Staff complete/no-show pass.
Không build APK mới do lệnh build bị từ chối; source đã sẵn sàng debug/Hot Restart.

**Phần2:** ca làm/nghỉ phép API đã nối; Staff gửi đơn, Manager/Boss quyết định,
snapshot lịch sử, CRUD ca và Staff xem ca. Live Flutter flow pass; hướng dẫn:
[FLUTTER_API_PART2.md](FLUTTER_API_PART2.md). Appointments/Booking UI còn mock.
Phần2: 106 tests pass +1 live opt-in skipped, analyzer sạch; live flow xin nghỉ,
duyệt nghỉ, CRUD/xem ca pass; APK debug USB build thành công.

**Phần1 07/10/2026:** Flutter Core Network/http + secure storage, Auth API mặc định,
restore/me/logout/401, role routing và Boss pending/approve/reject đã nối. Live
Flutter HTTP Manager tạo fixture → Boss duyệt → Staff login pass, fixture dọn và
seed giữ nguyên. Các features khác vẫn mock, chưa nghiệm thu toàn ứng dụng.
Hướng dẫn: [FLUTTER_API_PART1.md](FLUTTER_API_PART1.md).
Phần1: analyzer sạch, 104 Flutter tests pass +1 live opt-in skipped; live chạy riêng
pass, APK debug build thành công. Còn nghiệm thu UI trên emulator khi bật thiết bị.

- API repositories theo feature, giữ Providers/UI; map money strings → Dart int,
  price/duration/categoryId → model fields, nhãn category từ API.
- Validation/401/403/404/409 nhất quán, pagination giới hạn và empty states.
- E2E Manager tạo pending → Boss approve → Staff login → shifts → Customer book
  → complete → báo cáo đúng Branch. Test2Managers/2Customers và concurrent booking.
- Chỉ chốt retention/hard-delete sau khi bảo toàn thống kê. Ngoài scope: chat,
  reschedule, đổi thưởng/giảm giá, gửi review, thanh toán lương.

## Tài khoản seed (không dùng production)

| Vai trò/cơ sở | Email | Password |
| --- | --- | --- |
| Boss toàn chuỗi | boss@example.com | boss123 |
| Manager Cầu Giấy | admin@example.com | admin123 |
| Manager Đống Đa | manager2@example.com | manager123 |
| Manager Hai Bà Trưng | manager3@example.com | manager123 |
| Manager Hà Đông | manager4@example.com | manager123 |
| Staff Cầu Giấy | staff@exampler.com, staff2@example.com, staff3@example.com | staff123 |
| Staff Đống Đa | staff4@example.com, staff5@example.com, staff7@example.com | staff123 |
| Staff Hai Bà Trưng | staff8@example.com, staff9@example.com | staff123 |
| Staff Hà Đông | staff10@example.com, staff11@example.com | staff123 |
| Customer | customer@example.com, customer2@example.com, customer3@example.com | customer123 |
| Pending | pending@example.com, pending12@example.com, pending13@example.com, pending14@example.com, pending15@example.com | Chưa có credential |

## Nguồn kỹ thuật

- https://docs.nestjs.com/security/authorization
- https://docs.nestjs.com/security/authentication
- https://www.postgresql.org/docs/current/explicit-locking.html
- https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
