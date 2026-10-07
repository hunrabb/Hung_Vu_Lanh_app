# PROJECT CONTEXT — Hệ thống Quản lý Chuỗi Cửa Hàng

**Cập nhật:** 07/10/2026 · **Dự án:** `C:\learnFlutter\ktgk`

Tài liệu này ghi nhận nghiệp vụ đã chốt và hiện trạng triển khai để làm căn cứ cho
các bước tiếp theo. Đọc cùng `lib/PRD.md`, `AGENTS.md` và code liên quan trước khi sửa.
Kế hoạch theo từng đợt, kết quả rà soát và tiêu chí nghiệm thu nằm trong
[CHAIN_IMPLEMENTATION_PLAN.md](CHAIN_IMPLEMENTATION_PLAN.md). Ba quyết định bổ sung
đã được duyệt: email cho tất cả vai trò, catalog chung do Boss quản lý, từ chối xóa
hồ sơ pending và không lưu lịch sử.
Các quyết định Pivot dưới đây thay thế định hướng một cửa hàng và quyền Admin cũ.
**Đợt 1–5 đã triển khai nền tảng chuỗi, phân quyền application, Customer theo Branch,
workspace Manager và workspace Boss với phê duyệt. Backend NestJS đã triển khai
Giai đoạn 1–5 và kiểm thử Aiven thật. Flutter đã nối Auth, onboarding Boss,
ca làm/nghỉ phép, Booking/Appointments và Dashboard/Reports API. Một số CRUD/
settings/account forms còn mock như ghi rõ ở Phần4.**

### Flutter API Phần1 — 07/10/2026

**Fix timeout Login07/10/2026:** Analyzer CLI C:\flutter xác nhận No issues found,
không tái hiện314 lỗi source. Redmi USB bị mất adb reverse, backend vẫnHTTP200;
tạo lại tunnel và Login từ Redmi trả200. VSCode root C:\learnFlutter và folder
ktgk có USB profile+preLaunchTask gọi tool/prepare_usb_api.ps1 (adb reverse + API
health check). SDK workspace cố định C:\flutter. USB localhost, emulator10.0.2.2.
API client debug log chỉ host/path, không token/credentials. 15 tests Auth/routing/
Reports pass; Problems IDE còn cũ cần Dart: Restart Analysis Server, không bỏ guard.

**Phần4:** Reports UI nối Manager dashboard/revenue, Boss dashboard/leaderboards/
ledger/commissions, Staff earnings/profile-stats/customers. Money string/BigInt
format1,500,000 VND, charts từ tỷ lệBigInt, loading/error/retry/empty/filter/paging.
Cache session/query và invalidation theo appointment mutation; báo cáo không
đọc metrics mock. Catalog/Branch CRUD/settings/recruitment/account forms khác
chưa migrate. Hướng dẫn FLUTTER_API_PART4.md. 110 tests pass +1 live opt-in skipped;
live thật báo cáo completed/30% commission pass, không build APK mới.

**Phần3:** ApiBookingRepository/ApiAppointmentProvider và Booking/Ledger UI đã nối.
Catalog/branch cho booking là API; eligible staff/slots server, body bỏ identity/
giá/thời lượng, Customer và Manager walk-in, exact409 Snackbar+refresh/reset slot.
Customer/Staff/Manager/Boss lịch hẹn GET API có status/pagination; cancel/complete/
noShow/hide independent refresh; Home upcoming dùng API. Tiền giữ string/BigInt,
session/load/request guards. Reports và Staff analytics khác vẫn mock. Hướng dẫn:
FLUTTER_API_PART3.md. Hồi quy108 tests pass +1 live opt-in skipped, analyzer sạch.
Live đầy đủ đã pass concurrency1 lịch thắng/409, cancel/walk-in/complete/noShow,
cleanup fixture. Build APK Phần3 chưa chạy do lệnh bị từ chối; thay đổi chỉ Dart.

**Phần2:** WorkspaceRepository/Provider và UI đã nối ca làm/nghỉ phép API.
Staff Hồ sơ gửi khoảng nghỉ+lý do và xem đơn riêng; Manager tab Nhân viên duyệt
và xem lịch sử snapshot server; Boss có Workspace toàn chuỗi. Ca làm CRUD ở
Workspace, Staff có icon xem ca riêng. Names/Staff dropdown từ API, UTC+7→UTC,
loading/busy/409 Snackbar, session/branch/load epochs và refresh sau ghi. Không
đổi backend/schema/package. Live Staff gửi→Manager duyệt→Staff xem và CRUD ca pass;
phân biệt Shifts API với các thẻ Appointments vẫn mock. Xem FLUTTER_API_PART2.md.
Phần2 nghiệm thu: analyzer sạch, 106 tests pass +1 live mặc định skipped; live
chạy riêng pass và cleanup, APK debug localhost USB build thành công.

- Runtime BarbershopApp dùng API Auth mặc định; tests mock chọn useMock:true rõ ràng.
  http Client, secure token storage, smart Base URL/override; protected401 clear
  session và stack kể cả modal. Giữ race guards/dispose và không fallback mock.
- Boss PendingStaffProvider lấy hàng chờ và tên cơ sở từ API; approve/reject,
  busy state, conflict409 refresh, session epoch chống responses sau logout.
  AppUser.fromJson map boss alias; ApiMoney parse BigInt/safeInt tránh mất tiền Web.
- Live Flutter HTTP đã kiểm tra Manager tạo fixture → Boss duyệt → Staff login,
  không duyệt seed. APK debug build thành công. Các màn khác chưa chuyển API;
  Phần1 ban đầu không sửa backend; đợt fix kết nối sau đã bật CORS (xem dưới).
- Mock seed hiện có3 Branch, chỉ2 cơ sở có nhân sự/settings sẵn; giữ dữ liệu hiện
  có, chỉnh fixture tests tránh count2 cố định. Xem FLUTTER_API_PART1.md.
- Kết quả Phần1: 104 tests pass, 1 live test opt-in skipped trong suite mặc định;
  live test chạy riêng pass, analyzer sạch, APK debug build thành công. Chưa có
  emulator đang bật để test UI trực tiếp trên Android.

- Fix kết nối07/10/2026: backend listen PORT trên 0.0.0.0, enableCors(); Android
  usesCleartextTraffic=true, giữ HTTP domains 10.0.2.2/localhost/127.0.0.1.
  Thiết bị thực tế là Redmi USB, không phải Emulator. Đã cấu hình adb reverse3000;
  dùng API_BASE_URL=http://localhost:3000/api khi chạy trên USB, giữ default10.0.2.2
  cho Emulator. VSCode profile tại ktgk/.vscode/launch.json; cần chạy app lại.
- Xác minh fix mạng: Login từ chính Redmi qua adb reverse trả HTTP200; CORS
  preflight204, listener0.0.0.0:3000. Ban đầu không có server lắng nghe ở cổng3000.

### Backend NestJS — 07/10/2026

- Giai đoạn5 ReportsModule: role/scope theo phiên; Manager cơ sở, Boss toàn chuỗi
  hoặc Branch chọn, Staff ID+cơ sở hiện tại. SUM trực tiếp appointments completed,
  service items enrich bằng JSON subquery, không nhân đôi tiền; money/numeric cast
  text. Kỳ start_at theo ngày Hà Nội, bounds UTC [from,to), response read snapshot
  REPEATABLE READ; hidden vẫn tính. Không thêm bảng/cột/package.
- Hoa hồng Boss tạm tính30%, floor nguyên VNĐ trên tổng Staff. Ranking toàn chuỗi
  gộp Staff ID kể cả khi chuyển cơ sở, giữ tags Branch lịch sử. Profile stats có
  completed tháng, reviews, customer visits/LTV; walk-in NULL không gộp thành khách.
  Build+23 tests pass, live hai service items/BIGINT/timezone/scopes/transfer pass.
  Hướng dẫn: backend/PHASE5_TESTING.md. Flutter API adapters còn ở Giai đoạn6.

- Giai đoạn 4: AppointmentsModule có directory Staff theo chuyên môn, slots theo
  ca/ngày Hà Nội/cấu hình/nghỉ approved/lịch bận; Customer đặt bằng identity phiên,
  Manager walk-in Branch phiên. Transaction settings → Staff FOR UPDATE → catalog
  khóa theo ID; giá BIGINT server và service snapshots cùng commit. 23P01 trả 409;
  retry giới hạn 40P01/40001. Không thêm schema, synchronize vẫn false.
- Lịch query theo role/branch/ownership có pagination; cancel/complete/noShow theo
  state machine; hai cờ ẩn độc lập không làm mất báo cáo. Chi tiết:
  backend/PHASE4_TESTING.md. Flutter giữ mock, không sửa UI ở giai đoạn này.
- Kiểm tra Giai đoạn4: build +20 tests pass; test live hai booking đồng thời
  201/409, đúng1 row. Leave race, EXCLUDE, rollback items, BIGINT, specialty stale
  và soft hide pass. localhost directory/slots/ledger200, seed70 ca giữ nguyên.
  ShopSettings.closedDates chuẩn hóa DATE[] thành calendar string; seed script
  đọc ::text[] để không bỏ sót ngày nghỉ do pg trả Date object.
- Hồi quy Giai đoạn2/3 chạy song song pass. Branch DELETE khóa settings trước
  Branch, tránh đảo khóa với shift/leave inserts; cơ sở còn tham chiếu trả409.

- Giai đoạn2 theo BACKEND_ROADMAP.md đã có Manager POST/PATCH Staff (ép Branch
  từ profile phiên, pending và no credential), Boss approve/reject có khóa Staff
  và transaction, bcrypt cost12 ngoài transaction. Duyệt đôi trả200/409.
- Branch/Service/Category POST/PATCH/DELETE chỉ Boss, GET vẫn public. Settings
  PATCH Boss/Manager đúng Branch. Service tái kiểm tra actor/role/Branch/version
  trong transaction; DTO whitelist, reject null/empty/mass assignment, tiền BIGINT.
- DELETE pending chặn credential/appointment/shift/leave; không lưu lịch sử tuyển
  dụng. FK RESTRICT 23001 và23503 trả409, rollback settings nếu Branch còn refs.
  POST catalog dùng INSERT, không save/upsert làm ghi đè ID cũ. Category giữ six IDs.
- Build+8 tests local pass; test Aiven đầy đủ CRUD/onboarding/concurrency/DTO/tenant
  pass, dọn riêng Staff/Branch/Service/Shift/Appointment thử. Chi tiết curl/Postman
  ở backend/PHASE2_TESTING.md. synchronize=false; không thêm migration Giai đoạn2.

- Roadmap được duyệt ở BACKEND_ROADMAP.md. Giai đoạn1 AuthModule đã có register
  customer-only, login, me, password, logout; JWT HS256/issuer/audience/30 phút,
  no refresh. Guards mặc định và service kiểm tra role/Branch; boss alias map
  superAdmin. Users pending Boss-only; Branch route Manager đúng cơ sở hoặc Boss.
- Migration004 đã chạy: auth_credentials.token_version và staff_shifts.branch_id,
  không bật synchronize. Logout/password tăng version và thu hồi toàn bộ token
  của tài khoản; role/Branch/approval mới trong DB chặn JWT cũ.
- Đã verify 18 tài khoản approved seed bằng scrypt và chuyển bcrypt cost12 qua
  login; pending5 vẫn không credential. Password mới tối đa72 byte UTF-8, không
  NUL. Secret JWT chỉ trong .env. DTO không nhận role/approval/Branch register.
- Build và 6 tests local pass; test Aiven đủ Auth/password/logout + tenant guards
  pass, Customer thử được xóa sau test. Hướng dẫn Postman/cURL: backend/AUTH_TESTING.md.

- Seed Aiven mở rộng đã thực thi: 4 cơ sở Hà Nội, 23 Users (1 superAdmin toàn
  chuỗi, 4 Manager, 10 Staff approved, 5 pending, 3 Customer), 6 categories và
  20 dịch vụ 50.000–1.500.000đ/15–120 phút. Mỗi cơ sở 1 Manager; Staff approved
  phân bổ 3/3/2/2, pending 2/1/1/1. Pending không có credential.
- Các ID category vẫn tương thích enum Flutter; tên hiển thị được chuyên nghiệp
  hóa, Combo VIP thuộc dịch vụ haircut. Không sửa CHECK/schema để tạo ID lạ.
  API pending HTTP 200 đủ 5 dòng, services HTTP 200 đủ 20; seed chạy lại không
  thêm bản ghi trùng. Branch/category sample labels được upsert; user/password/
  approval/service hiện có được giữ. Flutter chưa chuyển sang API hoặc label mới.

- Đã thực thi database/003_seed_mock_data.sql trên Aiven qua backend/seed-data.cjs:
  branch-01, Boss superAdmin toàn chuỗi (Branch NULL), Manager admin-01 cơ sở 1,
  Staff staff-06 pending và 3 dịch vụ. Categories có 6 dòng từ schema cũ.
  Approved Boss/Manager có scrypt hash trong auth_credentials; Staff pending
  không có credential. Đây là dữ liệu mẫu, chưa triển khai AuthModule/JWT.
  Seed idempotent ON CONFLICT DO NOTHING, transaction và kiểm tra ID/email;
  không overwrite password/approval/data đã sửa. Không thay schema/synchronize.

- Đã bổ sung UsersModule/CategoriesModule/ServicesModule với Entities, Services,
  Controllers và forFeature registration. GET /api/users/pending lọc staff +
  is_approved=false; /api/users/branch/:branchId chỉ Staff thuộc Branch truyền vào.
  /api/categories và /api/services đọc catalog chung (gồm trạng thái active).
- Đã inspect metadata Aiven thật: services dùng price_vnd BIGINT và duration_minutes
  INTEGER; TypeORM map sang price (JSON string giữ chính xác), duration (number),
  categoryId/isActive. User map branchId/isApproved/createdAt sang cột snake_case.
- synchronize=false, không chạy DDL/seed. Build thành công, 4 tests pass; smoke
  Aiven thật cả 5 route HTTP 200: Branches/Users/Services rỗng, Categories 6 dòng.
  Users endpoints chưa có JWT/guard; filter branch không thay authorization phiên.

- Project tại `backend/`, NestJS + @nestjs/typeorm + typeorm + pg + @nestjs/config.
  AppModule dùng forRootAsync/ConfigService, DB_HOST/PORT/NAME/USER/PASSWORD;
  kiểm tra env bắt buộc và port hợp lệ. CA thật đặt `backend/ca.pem`.
- SSL rejectUnauthorized=true, đọc fs.readFileSync('./ca.pem').toString(); chạy
  lệnh từ root backend. synchronize/dropSchema/migrationsRun đều false.
- BranchesModule map public.branches với id/name/address/phone TEXT. Service
  findAll dùng Repository.find, chọn bốn field công khai và order name/id.
  Global prefix api: GET /api/branches trả JSON array; chưa có endpoint ghi/JWT.
- Đã npm install, lưu package-lock; npm test build TS và 2 tests pass (HTTP route
  với repository mock + validate env). Install cuối báo 0 vulnerabilities.
  Chưa có .env/CA/credentials thật nên chưa chạy truy vấn Aiven end-to-end.

### Chuẩn bị Aiven — 07/10/2026

- Thiết kế PostgreSQL ở `database/001_core_postgresql.sql`, phần feature hiện có
  ở `002_existing_features_postgresql.sql`; mapping đầy đủ Models và các khác biệt
  so với mock nằm trong `database/README.md`. Chưa chạy DDL trên Aiven, chưa đổi Dart.
- Category hiện là enum, dùng đúng sáu ID; SQL có bảng categories và bảng liên kết
  chuyên môn/dịch vụ trong lịch. Walk-in đổi thành FK customer NULL + snapshot,
  API map lại customerId='walk-in'. Settings PK theo Branch, tiền BIGINT, UTC timestamps.
- Auth credential/hash ở server, approval + credential cùng transaction; không
  thêm Sessions hoặc bảng doanh thu. FK lịch sử RESTRICT thay hard-delete mock;
  dịch vụ đã dùng chuyển isActive=false. Chuyển role do Boss qua transaction,
  xử lý liên kết chuyên môn/credential và giữ nguyên ID/Branch lịch lịch sử.
- Stack đã chọn: Flutter `http` → HTTPS/JWT API → NestJS TypeORM/pg → Aiven TLS
  verify-full/CA. Không kết nối DB bằng credential quản trị trong Flutter.
  FK/CHECK không thay backend authorization; SQL chưa có RLS/policy đã triển khai.

### Tài khoản Manager và phê duyệt nghỉ phép — 07/10/2026

**Kiểm tra:** toàn bộ 96 tests pass, analyze sạch; có test form tài khoản,
phê duyệt/ghi chú/lịch sử và ngăn Manager đọc/duyệt chéo cơ sở.

- Cài đặt Manager mở OwnProfileDialog cho tên/email/SĐT/địa chỉ và
  OwnPasswordDialog kiểm tra mật khẩu cũ. Provider chỉ cập nhật tài khoản phiên,
  giữ nguyên role/branch/approval/chuyên môn và kiểm tra email duy nhất Users/Auth.
- Dialog mật khẩu dùng chung Staff/Manager, kho Auth chung và không ghi mật khẩu
  vào profile/JSON. Login dùng ngay email/mật khẩu mới; phiên hiện tại giữ nguyên.
- Staff xin nghỉ tạo LeaveRequest pending trong state UserProvider trên RAM.
  Record giữ Staff ID/tên, Branch snapshot, ngày, thời điểm gửi. Những ngày local
  từ luồng cũ được chuyển pending khi Provider được giữ qua hot reload.
- Tab Nhân viên của Manager có form Duyệt/Từ chối và Lịch sử phê duyệt.
  Form/card dùng tông kem–nâu, viền mảnh, bóng tối giản, chữ vừa và khoảng cách
  thoáng theo quiet luxury; nút duyệt nâu đậm, hành động phụ trung tính.
  Chỉ Manager đúng Branch được xử lý; kiểm tra lại ID phiên khi xác nhận dialog,
  từ chối xử lý lần hai. Lịch sử giữ quyết định, Manager ID/tên snapshot,
  reviewedAt UTC và ghi chú, không bị ghi đè khi Staff gửi lại sau từ chối.
  Người xử lý hiển thị tên Manager và tên cơ sở snapshot tại lúc duyệt; đổi tên
  tài khoản/cơ sở sau này không sửa lịch sử. Provider lấy tên từ profile thật,
  không nhận tên người duyệt từ form và không hiển thị ID nội bộ thay cho tên.
- Staff xem trạng thái yêu cầu riêng; Manager chỉ cơ sở mình. Customer không
  đọc hồ sơ nghỉ phép; chỉ tra cứu availability công khai. Ngày approved chặn
  availableSlots và xác nhận booking mới; pending/rejected không chặn.
- Ca đã đặt không tự hủy khi duyệt nghỉ. Chưa có Backend/persistence; yêu cầu và
  lịch sử mất khi restart. Không thêm bảng DB; LeaveRequest là record RAM nội bộ.

### Staff Dashboard & Analytics — 07/10/2026

**Hồ sơ động:** kiểm tra bản mới toàn bộ 94 tests pass, analyze sạch; có test
review/JSON, xác thực mật khẩu cũ, ID phiên đổi khi thao tác, DatePicker và logout.

- Hồ sơ Staff dùng profile/session thật và completed tháng hiện tại. Đánh giá
  trung bình phái sinh từ completed có isReviewed=true/rating hợp lệ; không dùng
  averageRating hardcode trên AppUser, không có dữ liệu thì hiện Chưa có đánh giá.
- Appointment có bool isReviewed=false và int? rating (1–5); reviewed bắt buộc
  có rating, JSON cũ mặc định chưa review. Getter isReviewed dùng backing nullable
  và mặc định false cho object RAM cũ sau hot reload; dayOffs khởi tạo lazy.
  Đây chỉ là fields hiển thị, chưa có luồng Customer gửi review.
- UserProvider.changeOwnPassword kiểm tra phiên Staff, ID khi mở dialog và mật
  khẩu cũ trong cùng MockAuthRepository dùng để login. Không ghi mật khẩu vào
  profile/JSON; mật khẩu mới cập nhật login, không đổi ID hay đăng xuất phiên.
- Xin nghỉ phép nay tạo pending và đi qua Manager duyệt trong UserProvider,
  chống trùng/past date; xem quy tắc phê duyệt phía trên. Provider kiểm tra lại
  ID phiên sau DatePicker để tránh ghi cho phiên khác.

**Kiểm tra:** toàn bộ 91 tests pass; analyze sạch. Test Staff Earnings dùng phiên
thợ ở Branch 2 để kiểm tra identity, ngày/tháng, xóa mềm và cập nhật doanh số.

- StaffMain có bốn tab với nhãn/icon: Lịch làm việc, Khách hàng, Thu nhập, Hồ sơ.
  Tab lịch giữ chia ca sắp tới/đã kết thúc, Divider và ẩn ca có xác nhận.
- Schedule không còn fallback staff-01. Schedule/Customers/Earnings lấy Staff
  approved, ID và Branch từ phiên; query giữ ownership và phạm vi trong Provider.
- StaffEarningsScreen (“Thu nhập của tôi”) hiển thị doanh số hôm nay/tháng này,
  số ca completed tháng này và chi tiết lịch sử completed theo thời gian mới nhất.
  Có ngày/giờ Việt Nam, snapshot dịch vụ, tên khách và tiền nguyên VNĐ.
- Đây là doanh thu dịch vụ của thợ, không phải lương/hoa hồng thực nhận. Tỷ lệ
  Boss hiện chỉ tạm tính trong state UI nên không áp 30% giả vào Staff. Không thêm
  trường/bảng hay cấu hình hoa hồng. Tab Khách hàng có thẻ doanh số cá nhân chung.
  Thẻ dùng gradient vàng champagne, chữ nâu đậm và biểu tượng cúp thành tựu.
- AppointmentProvider.ownCompletedAppointments không nhận staffId từ form;
  xác định phiên Staff đã duyệt, lọc branch/ownership/status. month=false: hôm nay;
  true: tháng hiện tại; null: toàn lịch sử. Kết quả immutable, khoảng nửa mở UTC+7.
- Cờ ẩn không loại ca khỏi doanh số/LTV/báo cáo; chỉ làm gọn lịch trình. Không
  thay Branch của lịch lịch sử theo Branch hiện tại của hồ sơ Staff.

### Cải tiến quản trị doanh số Manager — 07/10/2026

**Kiểm tra:** toàn bộ 89 tests pass; analyze sạch. Hai test báo cáo mới dùng
Auth session thật, dữ liệu hai Branch và ranh giới tháng theo múi giờ Việt Nam.

- Dashboard giữ đúng ba chỉ số: Doanh thu hôm nay, Lịch hôm nay, Lịch đã hủy;
  Bố cục hiệu suất là một panel viền mảnh: doanh thu toàn chiều ngang phía trên,
  số lịch/đã hủy chia đôi phía dưới; tông kem–nâu quiet luxury, không ô trống.
  bỏ Thợ rảnh và truy vấn tính thợ rảnh. “Báo cáo Doanh số” là nút lớn toàn chiều
  ngang, tông kem–nâu với viền mảnh, chữ rõ và mũi tên nhỏ, ngay dưới Tạo lịch
  nhanh; không nằm trong Thao tác nhanh. Tránh gradient/màu nổi/icon trang trí.
- Route `/manager/revenue` được guard theo role Manager. ManagerRevenueScreen
  lấy tên cơ sở/branchId từ Auth session, không có bộ chọn cơ sở khác.
- Tổng doanh thu chọn Hôm nay/Tháng này; giao dịch completed liệt kê hôm nay
  với tên khách, thợ, snapshot dịch vụ và giá. Xếp hạng doanh thu thợ là tháng này.
- AppointmentProvider.completedTransactions/monthlyStaffRevenue xử lý khoảng
  nửa mở theo lịch Việt Nam UTC+7, lọc completed và phạm vi phiên. Manager gọi
  Branch khác bị từ chối; API báo cáo chỉ cho Manager/Boss. Cờ ẩn không giảm tiền.
- Báo cáo watch Providers để cập nhật ngay khi hoàn thành ca/đổi phiên; không
  có bảng/cột doanh số mới, không lưu bản sao thống kê hoặc thêm package.

### Tiến độ Đợt 5 — Tổng hành dinh Boss

**Kiểm tra 07/10/2026:** toàn bộ 87 tests pass (7 tests Boss mới);
`flutter analyze --no-pub` sạch. Đã kiểm tra layout 320px và render preview
Dashboard; không thêm package hoặc nối backend.

- BossMainScreen thay placeholder bằng sáu tab: Tổng quan, Sổ lịch, Hoa hồng,
  Cơ sở, Dịch vụ, Phê duyệt; đăng nhập boss@example.com/boss123 vào `/boss`.
  Đăng xuất xóa lịch sử Navigator. Chỉ phiên superAdmin được dựng workspace.
- Tổng quan có bộ lọc toàn chuỗi/cơ sở, bốn metric ngày/tháng và Top 5 cơ sở
  theo doanh thu, Top 5 thợ theo số ca completed. Giữ state bộ lọc khi đổi tab.
- BossReports tính trên Appointments, khoảng nửa mở theo lịch Việt Nam UTC+7,
  tháng hiện tại; doanh thu chỉ completed, số lịch gồm mọi trạng thái. Cờ ẩn của
  Customer/Staff không ảnh hưởng báo cáo. Không tạo bảng doanh thu/hóa đơn mới.
- Sổ lịch dùng snapshot dịch vụ/giá và tag cơ sở/thợ, lọc Branch/trạng thái,
  sắp mới nhất trước. Hóa đơn ở đây là giá trị ca completed, chưa có phát hành
  hóa đơn điện tử, thanh toán hoặc xuất file.
- Hoa hồng phái sinh từ doanh thu completed của từng thợ trong tháng, gồm thợ
  có dữ liệu lịch sử; hiển thị cả thợ approved có 0 ca. Tỷ lệ tạm tính mặc định
  30%, chỉnh 0–100% trong state UI, tiền VNĐ nguyên làm tròn xuống sau tổng hợp.
  Chưa lưu tỷ lệ, chưa có logic chi trả hoặc bảng lương.
- Branch CRUD tái sử dụng BranchProvider: form tên/địa chỉ/SĐT bắt buộc, chặn xóa
  khi còn nhân sự/lịch, Branch mới có cấu hình mặc định. Catalog Boss dùng
  ServiceCatalogScreen(readOnly:false), form CRUD và quyền Provider đã có.
- UserProvider.approveStaff kiểm tra Boss/pending, đăng ký credential vào cùng
  ID trước khi bật approval. Nếu cấp credential hoặc cập nhật profile thất bại,
  thu hồi credential mới mà không xóa hồ sơ chờ; thử lại và double-submit an toàn.
- rejectPendingStaff chỉ Boss, chỉ pending chưa có credential/lịch; thiếu hàm
  kiểm tra lịch thì từ chối xóa. App wiring cung cấp truy vấn kho lịch nội bộ.
  Không lưu lịch sử từ chối. Thẻ chỉ có Duyệt/Từ chối, không liên hệ Zalo.
- App dùng cùng MockAuthRepository cho Auth và UserProvider. Mật khẩu chỉ giữ
  trong kho Auth mock, không nằm trong AppUser/JSON; liên hệ gửi mật khẩu do Boss
  thao tác ngoài ứng dụng. Backend/transaction thật sẽ xử lý ở Giai đoạn 4.

### Tiến độ Đợt 4 — Workspace Manager và tuyển dụng

**Kiểm tra 07/10/2026:** toàn bộ 80 tests pass; 7 tests Dashboard/Manager/Settings
pass sau chỉnh sửa cuối cùng; `flutter analyze --no-pub` không có vấn đề.

- Shell/màn hình nằm trong `lib/features/manager/presentation/`, dùng tên
  ManagerMain/ManagerDashboardScreen/ManagerStaffScreen/ManagerSettingsScreen.
  Routing `/manager` và `/manager/services` dùng tên Manager, đã bỏ alias Admin.
- Dashboard hiển thị “Tổng quan - [Tên cơ sở]” từ BranchProvider theo phiên.
  Lịch hôm nay, doanh thu completed, ca cancelled và thợ rảnh lấy đúng
  branchId của Manager; cờ ẩn Customer/Staff không loại dữ liệu thống kê.
- Form thêm/sửa Staff có tên, email, SĐT, địa chỉ bắt buộc và nhiều chuyên môn;
  không có mật khẩu. Hồ sơ pending hiển thị “Chờ Boss duyệt”.
- UserProvider.createStaffProfile chỉ cho Manager, lấy branchId từ AccessScope,
  tự gán Staff/isApproved=false, chuẩn hóa và kiểm tra email toàn kho Users/Auth.
  Chỉ ghi profile, không cấp credential. Manager không tự duyệt/chuyển Branch.
- ManagerServiceScreen đọc catalog chung, không có nút Thêm/Sửa/Xóa.
  ServiceCatalogScreen trong feature catalog giữ form CRUD tái sử dụng cho Boss
  ở Đợt 5; chỉ hiện khi readOnly=false và phiên Boss. Provider vẫn kiểm tra quyền.
- Walk-in khóa cơ sở theo phiên Manager. Settings dùng phạm vi phiên và dialog
  chốt branchId lúc mở; Provider từ chối thay đổi ngoài cơ sở được phân công.
- Tài khoản Manager mock vẫn dùng email `admin@example.com`/`admin123`
  để giữ fixture đăng nhập; tên profile hiển thị là Manager Demo.
- Cuối Đợt 4 Boss còn là placeholder; Đợt 5 đã nối phê duyệt cùng ID hồ sơ.

### Tiến độ Đợt 3 — Customer theo cơ sở tại Hà Nội

**Kiểm tra 07/10/2026:** flutter analyze sạch; toàn bộ 78 tests pass, gồm 2 test mới dùng Auth session thật cho luồng Branch/Customer.

- Chuỗi chỉ hoạt động tại Hà Nội; seed Cơ sở Cầu Giấy và Cơ sở Đống Đa dùng địa chỉ mẫu. Không thêm bộ chọn tỉnh/thành hay entity địa lý.
- Home giữ lựa chọn Branch trong state UI, không ghi vào hồ sơ Customer. Giờ hoạt động và banner nghỉ đọc cấu hình đúng cơ sở, cập nhật khi Provider thay đổi.
- Home truyền Branch sang Booking qua arguments của route. Booking bắt buộc chọn cơ sở trước dịch vụ/thợ; đổi cơ sở hoặc dịch vụ reset thợ và giờ.
- Chỉ cho chọn Staff đã duyệt, cùng cơ sở và đúng chuyên môn. Slot đọc cấu hình cơ sở; Provider kiểm tra lại quyền sở hữu, Branch và lịch trống khi xác nhận. Walk-in khóa theo Branch của Manager.
- Home/history/booking dùng ID Customer từ Auth session, không fallback customer-01. History giữ lịch cá nhân qua nhiều cơ sở và hiển thị tên cơ sở trên mỗi thẻ.
- Lựa chọn cơ sở không thay đổi phạm vi Manager/Staff và không khởi tạo lại kho lịch. Catalog vẫn dùng chung toàn chuỗi.

### Tiến độ Đợt 2 — Phạm vi truy cập trong application

- AccessScope lấy người dùng hiện tại từ AuthController ở mỗi lần gọi, không tin
  role/branch/actor do form gửi lên. Thiếu phiên mặc định từ chối ghi; UnauthorizedException
  là lỗi StateError chuyên biệt để các UI hiện có xử lý được.
- App dùng chung raw repositories, AccessScope và các Provider. MockUserRepository
  thông báo thay đổi; Auth/Scope làm mới role/branch và đăng xuất khi profile bị xóa
  hoặc Staff bị thu hồi approval. Provider nghe Scope để không giữ phạm vi cũ.
- MockBranchRepository/BranchProvider có CRUD: Boss mới được ghi, danh sách Branch
  được đọc chung. Không xóa Branch còn nhân sự/lịch; Branch mới có cấu hình mặc định.
- UserProvider.users/getStaff/getById được phân quyền: Manager chỉ Staff cùng Branch,
  truy vấn branch khác hoặc sửa/xóa Staff khác cơ sở bị từ chối. Manager không tự
  đổi role, branch hay approval; chỉ tạo profile pending qua API add (form onboarding
  mới vẫn thuộc Đợt 4). Customer không đọc hồ sơ Customer khác; tên khách phục vụ
  của Staff/Manager chỉ được tra cứu khi có lịch liên quan trong đúng phạm vi.
- AppointmentProvider query/revenue/count/LTV được lọc branch/ownership. Manager
  chỉ cancel/complete/noShow trong cơ sở mình; Staff chỉ thao tác lịch của mình;
  Customer chỉ đọc/cancel/ẩn lịch cá nhân. Kiểm tra xảy ra trước khi repository ghi.
- Available slots đọc lịch bận nội bộ không qua bộ lọc lịch cá nhân của Customer,
  để vẫn chống trùng với khách khác; cấu hình lấy theo Branch của Staff. Walk-in
  của Manager phải dùng Staff cùng cơ sở; customerId giả mạo bị từ chối.
- ServiceProvider: catalog đọc chung, chỉ Boss add/update/delete.
- ShopSettingsProvider giữ Map keyed by branchId. Manager đọc/ghi cơ sở mình;
  Boss ghi mọi cơ sở; Staff chỉ đọc cơ sở mình, Customer đọc giờ/ngày nghỉ công khai.
  Listener đồng bộ cấu hình sang Booking, không reset kho lịch khi đổi phạm vi.
- Các mock repository còn là storage nội bộ; UI phải dùng Provider đã gắn Scope,
  không truy cập raw repository để bỏ qua quyền. Backend sẽ phải thực thi quyền
  server-side khi chuyển Giai đoạn 4; lớp mock này không thay thế bảo mật server.
- Fixture domain/UI cũ có phiên Boss test được khai báo rõ, không có chế độ mặc
  định bỏ qua quyền trong production. Test quyền mới dùng AuthController thật
  trong mock với Manager/Boss/Staff/Customer và hai Branch.
- Roster Staff công khai cho Customer/các đồng nghiệp không trả email, SĐT và
  địa chỉ riêng; API đọc profile khác Branch của Manager vẫn ném lỗi quyền.
- Kiểm tra bản cuối Đợt 2: analyze sạch, toàn bộ 76 test pass, gồm 6 test phân
  quyền trực tiếp và các kiểm tra hồi quy UI/Booking/Auth.
- Branch selector Customer và UI Manager/Boss đầy đủ vẫn thuộc các đợt sau.

### Tiến độ Đợt 1 — 07/10/2026

- Branch có JSON/copyWith; ChainSeed cung cấp branch-01/branch-02 và cấu hình riêng.
- AppUser có branchId/phone/address/isApproved, bốn role mới; Staff/Manager bắt
  buộc có branchId. Customer mặc định approved, Staff mặc định chưa approved.
- Appointment/ShopSettings có branchId bắt buộc; JSON cũ thiếu branch không được
  gán mặc định. Mọi lịch mẫu khớp branch của Staff.
- Boss vào /boss (BossMainScreen placeholder); Manager vào /manager (shell Admin
  cũ giữ nguyên UI). Tên constant adminDashboard/adminServices giữ làm alias code
  cho route Manager; không còn UserRole.admin.
- Manager không được gọi API cấp credential trực tiếp. Staff chưa duyệt bị chặn
  Login, guards và danh sách thợ Booking. UI tuyển dụng/Boss approval sẽ làm sau.
- Seed có Boss, hai Manager, Customer và Staff approved/pending ở cả hai Branch.
  Cấu hình seed theo Branch đã có; UI Settings hiện vẫn chỉnh cấu hình branch-01,
  chưa có selector hay phân vùng quyền đầy đủ (Đợt 2).
- Tài khoản mock: boss@example.com/boss123; admin@example.com/admin123 là Manager
  branch-01; manager2@example.com/manager123 là Manager branch-02;
  staff@exampler.com/staff123 là Staff approved branch-01;
  an@example.com/staff123 là Staff approved branch-02. Staff pending không có
  credential mặc định. Customer vẫn customer@example.com/customer123.
- Không thiết kế lại UI hiện có, không cài package hoặc nối backend. Các mô tả
  “hiện trạng trước Pivot” ở mục 7 là baseline lịch sử; phần tiến độ này ưu tiên.
- Kiểm tra Đợt 1: analyze sạch, toàn bộ 70 test pass; 5 test nền tảng Chain kiểm
  tra model/seed/approval và guards Boss/Manager cũng pass khi chạy bổ sung.

## 1. Định hướng hệ thống và ràng buộc kiến trúc

- Sản phẩm chuyển từ ứng dụng đặt lịch một cửa hàng sang **Hệ thống Quản lý Chuỗi
  Cửa Hàng (Chain Management)** cho Barbershop/Spa.
- Một hệ thống có nhiều chi nhánh; Boss quản lý toàn chuỗi, Manager vận hành một
  chi nhánh, Staff phục vụ tại chi nhánh được phân công.
- Customer chọn chi nhánh trước khi chọn dịch vụ, thợ và khung giờ.
- Giữ Flutter/Dart, Provider/ChangeNotifier, Navigator và kiến trúc feature-first.
- Máy phát triển hạn chế: ít package, model/serialization viết tay, không dùng
  công cụ sinh code hoặc thêm bảng chỉ để lưu dữ liệu có thể tính từ Appointments.
- Schema phẳng, liên kết bằng ID; giữ tiền VNĐ kiểu `int`, thời điểm lịch hẹn UTC,
  hiển thị và xác định ngày kinh doanh theo giờ Việt Nam (UTC+7).
- Giao diện giữ nền xám nhạt, card trắng bo góc và màu nâu/vàng nhấn.

## 2. Schema mục tiêu sau Pivot

Thêm `Branches` vào sáu nhóm dữ liệu đã có: `Users`, `Services`, `Appointments`,
`StaffShifts`, `ShopSettings`, `Promotions`. Không thêm bảng Sessions, tuyển dụng,
lịch sử khách hàng hoặc doanh thu trong phạm vi hiện tại.

### 2.1. Branch — Chi nhánh (entity mới)

| Field | Kiểu Dart | Quy tắc / mục đích |
| --- | --- | --- |
| `id` | String | ID duy nhất, dùng làm khóa liên kết |
| `name` | String | Tên chi nhánh, ví dụ `dhung.cơ sở 1` |
| `address` | String | Địa chỉ chi nhánh |
| `phone` | String | SĐT liên hệ; dùng String để giữ số 0 đầu |

Boss quản lý danh sách chi nhánh. Chi nhánh đã có nhân sự/lịch hẹn phải được xử lý
tham chiếu trước khi xóa; không tự xóa dây chuyền dữ liệu lịch sử.

### 2.2. AppUser — Tài khoản và hồ sơ

Giữ `id`, `name`, `email`, `role`, `createdAt`, `loyaltyPoints`,
`specializedCategoryIds`, `averageRating`, `isFeatured` đang có trong code.
Thay đổi mục tiêu:

| Field | Kiểu Dart | Quy tắc / mục đích |
| --- | --- | --- |
| `role` | UserRole / String trong JSON | `superAdmin`, `manager`, `staff`, `customer` |
| `branchId` | String? | Bắt buộc cho Staff và Manager; tham chiếu `Branch.id` |
| `phone` | String? | Bắt buộc cho hồ sơ Staff mới; dùng liên hệ thủ công ngoài app |
| `address` | String? | Địa chỉ Staff theo form onboarding đã chốt |
| `isApproved` | bool | Staff mới mặc định `false`; chỉ Boss được duyệt |

- Boss quản lý toàn chuỗi và Customer không bị gắn cố định vào một chi nhánh:
  `branchId` của hai vai trò này có thể là `null`.
- Customer lựa chọn chi nhánh trên từng lần đặt lịch; phạm vi lịch hẹn được lưu
  trong `Appointment.branchId`, không ghi đè chi nhánh vào hồ sơ Customer.
- Chuyên môn tiếp tục là `List<String> specializedCategoryIds`, không quay lại
  chuỗi nhập tay. ID danh mục hiện là tên enum của `ServiceCategory`.
- **Không lưu mật khẩu trong AppUser hoặc JSON hồ sơ.** Mật khẩu do kho Auth mock
  hoặc hệ thống Authentication backend quản lý riêng.
- Quy tắc `isApproved` trong Pivot áp dụng cho onboarding Staff. Customer đăng ký
  public vẫn theo luồng Customer; không biến họ thành nhân sự chờ Boss duyệt.

### 2.3. Appointment — Lịch hẹn

Giữ các trường hiện có: `id`, `customerId`, `customerName`, `staffId`, `serviceIds`,
`serviceNamesSnapshot`, `startAt`, `endAt`, `totalPriceVnd`, `status`,
`isHiddenByCustomer`, `isHiddenByStaff`.

| Field mới | Kiểu Dart | Quy tắc |
| --- | --- | --- |
| `branchId` | String | Bắt buộc; chi nhánh tiếp nhận và phục vụ lịch hẹn |

- `Appointment.staffId` phải tham chiếu Staff **đã được duyệt**, thuộc chính
  `Appointment.branchId` và có chuyên môn phù hợp với dịch vụ.
- Manager tạo lịch vãng lai với `customerId = 'walk-in'`, lưu Tên/SĐT vào
  `customerName`; `branchId` lấy từ chi nhánh của Manager.
- Tên dịch vụ và tổng giá vẫn là snapshot tại thời điểm đặt; sửa catalog không
  làm đổi giá hoặc tên trên lịch sử đã đặt.
- Trạng thái giữ `pending`, `confirmed`, `completed`, `cancelled`, `noShow`.

### 2.4. ShopSettings — Cấu hình theo chi nhánh

Giữ `id`, `openingMinute`, `closingMinute`, `closedWeekdays`, `closedDates`.

| Field mới | Kiểu Dart | Quy tắc |
| --- | --- | --- |
| `branchId` | String | Bắt buộc, tham chiếu Branch; một cấu hình cho mỗi chi nhánh |

- `openTime`/`closeTime` là adapter `TimeOfDay` trên Provider; database tiếp tục
  lưu phút tính từ 00:00, không thêm hai trường thời gian trùng ý nghĩa.
- `closedDates` là `List<String>` dạng `yyyy-MM-dd`, tính theo lịch Việt Nam.
- Manager sửa giờ và ngày nghỉ của cơ sở mình; Customer Home và Booking dùng cấu
  hình của chi nhánh đang chọn, không còn cấu hình toàn app duy nhất.

### 2.5. Các entity còn lại và quan hệ

- `Service`: giữ `id`, `name`, `category`, `durationMinutes`, `priceVnd`, `isActive`.
  `categoryId` là getter của `category.name`, không có bảng Category mới.
- `StaffShift`: giữ `id`, `staffId`, `startAt`, `endAt`; hiện chưa nối vào engine.
  Chi nhánh được xác định từ Staff, chưa tự thêm `branchId` trùng lặp vào entity này.
- `Promotion`: giữ `id`, `title`, `subtitle`, `imageUrl`, `isActive`; chỉ marketing.
- Một Branch có nhiều Staff, Manager và Appointments; có một ShopSettings.
- Một Customer có thể có lịch ở nhiều Branch. Một Staff/Manager thuộc một Branch.
- Lịch sử khách và thống kê vẫn được tính từ Appointments, lọc theo chi nhánh và
  nhân viên; các cờ ẩn UI không làm mất dữ liệu thống kê.

**Đã chốt:** catalog dịch vụ và giá dùng chung toàn chuỗi, Boss quản lý CRUD;
Manager chỉ đọc để vận hành. Service không thêm branchId hay bảng trung gian.
Phạm vi ưu đãi chưa chốt; tiếp tục chỉ marketing, không tự thêm branchId cho Promotion.

## 3. Roles & Permissions mục tiêu

| Vai trò | Phạm vi | Quyền chính |
| --- | --- | --- |
| Super Admin (Boss) | Toàn chuỗi | Quản lý Branch và catalog chung, Dashboard riêng, duyệt/từ chối Staff và cấp mật khẩu |
| Manager | Một `branchId` | Manager Dashboard; xem doanh thu/lịch hẹn/thợ của cơ sở; tạo lịch nhanh, cấu hình cơ sở, tạo hồ sơ Staff chờ duyệt |
| Staff | Branch được phân công và dữ liệu phục vụ của mình | Lịch làm việc, completed/noShow, thống kê khách đã phục vụ, ẩn ca đã kết thúc |
| Customer | Dữ liệu cá nhân và Branch đang chọn để đặt lịch | Đăng ký/đăng nhập, chọn Branch/dịch vụ/thợ/giờ, xem/hủy lịch, ẩn lịch sử |

### 3.1. Thay thế quyền Admin cũ

- **Admin Dashboard hiện tại sẽ trở thành Manager Dashboard**, phục vụ vận hành
  một cơ sở. Boss Dashboard là màn hình riêng cần xây dựng.
- Luồng hiện tại “Admin thêm Staff kèm mật khẩu, Staff đăng nhập ngay” bị thay thế
  bằng “Manager tạo hồ sơ → Boss duyệt và cấp mật khẩu”.
- Manager không được tạo Boss/Manager, tự đổi role/branch, tự bật `isApproved`
  hoặc cấp mật khẩu để bỏ qua hàng chờ.
- Role `admin` cũ cần được ánh xạ rõ khi migrate: tài khoản nào là Boss, tài khoản
  nào là Manager và thuộc Branch nào. Không tự coi mọi Admin cũ là Boss.
- Cách tạo/khởi tạo tài khoản Boss và Manager cần được xác định khi triển khai
  Auth backend; không cho chọn các quyền này trên form Register public.

### 3.2. Cô lập dữ liệu theo chi nhánh

- Truy vấn Manager luôn có `branchId` từ danh tính đã xác thực, gồm lịch, doanh thu,
  số ca hủy, thợ và hồ sơ nhân sự chờ duyệt tại cơ sở đó.
- Staff chỉ thao tác lịch của chính mình trong Branch được phân công.
- Customer chỉ xem/hủy/ẩn lịch của mình; không được đổi `branchId` của lịch đã tạo
  để chuyển cơ sở hoặc xem lịch của người khác.
- Boss có truy vấn toàn chuỗi và bộ lọc Branch; Manager không có chế độ toàn chuỗi.
- Backend phải kiểm tra role, chi nhánh, quyền sở hữu và trạng thái phê duyệt cho
  từng thao tác. Lọc UI hoặc route guard không thay thế kiểm tra quyền ở server.
- Định hướng JWT giữ nguyên, không thêm Sessions table. Payload phục vụ điều
  hướng gồm user ID, role và branchId cho nhân sự. Backend xác minh token và quyền
  hiện hành; claim cũ không được dùng để bỏ qua trạng thái chưa duyệt.

## 4. Quy trình tuyển dụng và onboarding Staff

### Bước 1 — Manager tạo hồ sơ tại cơ sở

- Form gồm **Tên, Email, SĐT, Địa chỉ, Chuyên môn** chọn nhiều danh mục.
- Email bắt buộc và duy nhất, chuẩn hóa trim/lowercase; tất cả vai trò đăng nhập
  bằng email. SĐT chỉ phục vụ liên hệ bên ngoài ứng dụng.
- Hệ thống gán `role = staff`, `branchId = Manager.branchId`, `isApproved = false`.
- **Không có ô mật khẩu ở bước này và chưa tạo thông tin đăng nhập có hiệu lực.**
- Hồ sơ xuất hiện trong danh sách nhân sự chờ duyệt của cơ sở/Boss.
- Staff chưa được duyệt không xuất hiện trong Booking và không được đăng nhập
  workspace để thao tác lịch.

### Bước 2 — Boss xem hàng chờ

- Boss Dashboard lấy hồ sơ Staff `isApproved = false` của toàn chuỗi.
- Hiển thị chi nhánh, thông tin liên hệ và chuyên môn để Boss kiểm tra trước khi duyệt.
- Dữ liệu lấy từ Users; không thêm bảng tuyển dụng hoặc bảng Approval riêng.

#### Đặc tả UI thẻ “Nhân viên chờ duyệt”

- Hiển thị tên Staff, chi nhánh, SĐT, địa chỉ và các chuyên môn đã chọn.
- Chỉ có **hai thao tác lõi: “Duyệt” và “Từ chối”**, bố trí gọn ở cuối thẻ.
- **Duyệt:** mở dialog nhập mật khẩu cấp phát, xác nhận rồi chạy Bước 3.
  Lưu thành công thì thẻ rời hàng chờ; lỗi cấp credential giữ nguyên hồ sơ chờ.
- **Từ chối:** mở xác nhận rồi xóa hồ sơ Staff đang chờ, chưa có credential/lịch.
  Không cấp mật khẩu, không bật isApproved và không giữ lịch sử từ chối. Không
  mở rộng thao tác này thành xóa nhân viên đã được duyệt/đã phục vụ; không thêm
  trạng thái rejected, isRejected hoặc bảng lịch sử phê duyệt.
- Không có nút “Liên hệ Zalo”, mở chat, gọi điện hay gửi tin nhắn trên thẻ.
- Đây là đặc tả UI để triển khai; Boss Dashboard chưa tồn tại trong mã nguồn.

### Bước 3 — Boss duyệt và cấp mật khẩu

- Boss chọn Staff, nhập mật khẩu cấp phát và xác nhận duyệt.
- Hệ thống tạo/cập nhật credential trong Auth, liên kết đúng ID hồ sơ Staff,
  role và branch; **chỉ khi cấp credential thành công mới bật `isApproved = true`**.
- Quy trình cần nhất quán, có thể retry mà không tạo hai tài khoản hoặc hồ sơ
  được duyệt nhưng không có credential. Nếu cấp mật khẩu thất bại, giữ trạng thái chờ.
- Staff đăng nhập bằng credential được cấp và vào workspace chi nhánh của mình.

### Bước 4 — Kết thúc trên app, liên hệ thủ công bên ngoài

Sau khi Boss bấm “Duyệt” và nhập mật khẩu cấp phát trên hệ thống, quy trình trên
ứng dụng kết thúc khi phê duyệt/cấp credential thành công. Việc liên hệ và gửi mật
khẩu cho nhân viên sẽ do Boss thao tác thủ công bên ngoài (tự mở Zalo/gọi điện thoại).

- Hủy yêu cầu deep link Zalo và package `url_launcher`; không thêm nút liên hệ
  hoặc theo dõi trạng thái gửi mật khẩu trên Boss Dashboard.
- Không gọi API nhắn tin hoặc tự gửi mật khẩu từ app.
- Không lưu mật khẩu plaintext vào Users, Appointment hoặc log.
- Liên hệ bên ngoài không làm thay đổi kết quả phê duyệt đã lưu trong hệ thống.

**Đã chốt:** mọi vai trò đăng nhập bằng email. Form tuyển dụng có email bắt buộc;
giữ định danh email hiện tại, không suy ra email từ SĐT hoặc thêm login bằng SĐT.

## 5. Luồng Booking sau Pivot

1. Customer chọn Branch; Manager tạo walk-in tại Branch được phân công.
2. Lấy ShopSettings của Branch, dịch vụ hợp lệ theo phạm vi catalog đã chốt.
3. Chọn Staff có role staff, đúng Branch, `isApproved = true` và có
   `specializedCategoryIds` chứa `Service.categoryId`.
4. Chọn ngày/slot theo giờ mở cửa, ngày nghỉ và thời lượng dịch vụ; loại giờ đã qua
   và khoảng bị chiếm. Đổi Branch/dịch vụ phải reset Staff và slot đã chọn.
5. Xác nhận kiểm tra lại Branch, phê duyệt, chuyên môn, cấu hình và xung đột; tạo
   Appointment có branchId và snapshot tên/giá.

Backend phải ngăn double-booking bằng thao tác nguyên tử; kiểm tra slot trên Client
chỉ hỗ trợ UX. Khoảng thời gian vẫn là `[startAt, endAt)`, cho phép hai ca sát nhau.
Trong code hiện tại, `completed` vẫn giữ khoảng đã chiếm, `cancelled/noShow` không
block thời gian. Không thay đổi hợp đồng này ngoài phạm vi quyết định đã chốt.
Đổi cấu hình/ngày nghỉ không tự hủy các lịch đã tạo; cần xử lý vận hành riêng.

## 6. Phạm vi được giữ nguyên và Data Retention Policy

- Điểm thưởng, ưu đãi và đánh giá chỉ có dữ liệu hiển thị; chưa tích/đổi điểm,
  áp dụng giảm giá hoặc gửi đánh giá.
- Customer được hủy lịch; reschedule vẫn hoãn. Xin nghỉ phép duyệt qua Manager
  trên RAM, có lịch sử và chặn slot mới khi approved; chưa có Backend.
- Chat trong app và tích hợp mở/gửi tin nhắn Zalo đều ngoài phạm vi. Boss tự liên
  hệ nhân viên bên ngoài app sau khi cấp credential thành công.
- `isHiddenByCustomer` và `isHiddenByStaff` độc lập, chỉ ẩn lịch sử khỏi UI của vai
  trò tương ứng; không xóa bản ghi hay loại khỏi thống kê Staff/Manager/Boss.
- Client chỉ xóa mềm. Dọn vĩnh viễn lịch quá hạn (ví dụ qua 6 tháng) hoặc đã bị ẩn
  được thực hiện bởi TTL/Cronjob backend ở Giai đoạn 4 sau khi chốt retention.
- Phải bảo toàn dữ liệu/aggregate cần cho báo cáo chi nhánh và toàn chuỗi trước
  hard-delete; ẩn lịch không đồng nghĩa cho phép xóa ngay và làm sai thống kê.

## 7. Hiện trạng code trước khi triển khai Pivot

### 7.1. Những phần đã có

- Ba role hiện tại: `customer`, `staff`, `admin`; chưa có Boss/Manager/branchId.
- Sáu model chính trong `lib/core/models/` có fromJson/toJson/copyWith viết tay.
  TimeSlot là helper, không phải bảng. Feature domain cũ re-export model.
- Root `BarbershopApp` dùng MultiProvider: AuthController, UserProvider,
  ServiceProvider, AppointmentProvider, ShopSettingsProvider. Auth và Users có
  kho dùng chung; dữ liệu và mật khẩu mock chỉ tồn tại trong RAM.
- Admin hiện tại có CRUD dịch vụ/nhân viên, tạo credential Staff ngay, lịch vãng
  lai, Dashboard phái sinh và cài đặt giờ/ngày nghỉ dùng chung toàn app.
- Booking Customer/Admin dùng chung engine, lọc chuyên môn, kiểm tra xung đột khi
  ghi, nghe cấu hình giờ/ngày nghỉ. Customer còn hardcode `customer-01`.
- Customer Home có CTA, lịch sắp tới, hủy lịch, giờ hoạt động và banner nghỉ;
  tab lịch hẹn chia sắp tới/lịch sử, có xóa mềm.
- Staff schedule lấy Staff đang đăng nhập (fallback `staff-01` trong mock test),
  lịch hôm nay chia ca sắp tới/đã kết thúc, completed/noShow và ẩn ca. Staff customers
  tính số lần, LTV, max endAt, quá 30 ngày và sắp xếp từ các ca completed.
- MockAppointmentRepository seed completed 09:00–09:45 và confirmed 10:00–10:45
  hôm nay giờ Việt Nam cho `customer-01`, `staff-01`, `service-01`.
- Chuyên môn seed: staff-01 haircut/hairWash; staff-02 dye; staff-03 haircut/perm;
  staff-04 massage; staff-05 hairWash. Staff không có danh mục không được đặt lịch.
- Lần kiểm tra trước Pivot: analyze sạch, **66 test pass**. Kết quả này không xác
  nhận chức năng quản lý chuỗi chưa được triển khai.

### 7.2. Những phần chưa có / phải chuyển đổi

- Chưa có Branch model/repository/provider, branch selector hoặc Boss Dashboard.
- Chưa có branchId/isApproved/phone/address mới trong AppUser và chưa có hàng chờ.
- UI Admin hiện vẫn tạo Staff có mật khẩu ngay; phải thay bằng onboarding mới.
- Chưa có backend, Auth thật, JWT, TTL/Cronjob hoặc shift engine. Deep link Zalo
  đã bị loại khỏi yêu cầu; không có kế hoạch thêm package phục vụ liên hệ.
- Search/thông báo, nội dung thợ/kiểu tóc marketing và một số thống kê Profile
  còn preview/mock; không coi chúng là chức năng backend đã hoàn thành.
- Bản mock mất dữ liệu khi hot restart/đóng app. Role/model/seed thay đổi cần
  khởi tạo lại app, không kỳ vọng hot reload migrate các object đang sống.

### 7.3. Cấu trúc và tài khoản mock hiện tại

| Khu vực | Trách nhiệm |
| --- | --- |
| `lib/main.dart`, `lib/app.dart` | Entry point, root providers, MaterialApp |
| `lib/core/models/`, `core/routing/`, `core/utils/` | Model dùng chung, guards, helpers |
| `lib/shared/widgets/` | Widget tái sử dụng, gồm CustomButton |
| `features/auth/`, `users/`, `catalog/`, `booking/`, `settings/` | Controller/provider/repository và UI theo feature |
| `features/manager/presentation/` | Workspace của Manager theo cơ sở |
| `features/boss/` | Tổng quan chuỗi, sổ lịch, hoa hồng, Branch CRUD, phê duyệt |
| `features/schedule/`, `features/staff/` | Shell/ca làm và workspace Staff |
| `features/customer/` | Home, lịch hẹn, profile |
| `features/communication/domain/` | Entity cũ, ngoài scope core |

Tài khoản mock hiện tại (mật khẩu chỉ dùng kiểm thử):

| Role | Email | Mật khẩu mock |
| --- | --- | --- |
| Customer | `customer@example.com` | `customer123` |
| Staff | `staff@exampler.com` | `staff123` |
| Manager Cầu Giấy | `admin@example.com` | `admin123` |
| Manager Đống Đa | `manager2@example.com` | `manager123` |
| Boss | `boss@example.com` | `boss123` |

Route hiện có: `/`, `/register`, `/customer`, `/booking`, `/services`,
`/staff/schedule`, `/boss`, `/manager`, `/manager/services`, `/chat`.
Boss/Manager/Booking đã hoạt động trên RAM; route services/chat riêng vẫn là
placeholder. Boss quản lý catalog thật qua tab Dịch vụ trong workspace Boss.

## 8. Kế hoạch chuyển đổi trước và trong Giai đoạn 4

1. Định danh email, catalog chung do Boss quản lý và xóa hồ sơ khi từ chối đã chốt.
   Còn cách bootstrap Boss/Manager, phạm vi ưu đãi và backend cần xác định;
   chưa chọn Firebase hay Supabase thay người dùng.
2. Thêm Branch, role mới và các field liên kết/phê duyệt vào Models; cập nhật JSON,
   copyWith, seed và test. Gán dữ liệu một cửa hàng cũ vào Branch cụ thể khi migrate,
   không gán role/chi nhánh mặc định làm rộng quyền.
3. Xây mock BranchProvider, chọn Branch cho Customer; tách ShopSettings theo Branch
   và lọc tất cả repository/query theo role + branch + ownership.
4. Chuyển Admin UI thành Manager UI, bỏ cấp mật khẩu ở form Manager; xây Boss
   Dashboard, danh sách chờ và quy trình duyệt/cấp credential.
5. Nối Booking với Branch và Staff đã duyệt; kiểm tra chuyên môn, xung đột và cấu
   hình đúng cơ sở ở cả UI lẫn Provider.
6. Kiểm tra mock toàn chuỗi: Manager A không xem/sửa Branch B; Staff chưa duyệt
   không đăng nhập/được chọn; Boss duyệt đúng ID; Customer đặt đúng Branch.
7. Ở Giai đoạn 4: nối backend/Auth, phân quyền server, index/query theo Branch,
   kiểm tra xung đột nguyên tử và migrate dữ liệu. Các luồng cấp credential đặc
   quyền phải chạy qua backend, không đặt khóa quản trị trong Flutter.
8. Kiểm tra thẻ hàng chờ chỉ có Duyệt/Từ chối và quy trình kết thúc sau cấp
   credential; liên hệ ngoài app do Boss tự thực hiện. Triển khai retention sau
   khi chốt thời hạn và bảo toàn thống kê.

## 9. Kiểm tra và nguyên tắc cho lần code sau

- Trước mỗi thay đổi, đọc lại file thực tế và test liên quan; tài liệu không thay
  thế việc kiểm tra code hiện hành. Không tự triển khai Pivot chỉ vì đang sửa UI nhỏ.
- Test cần bao phủ phân quyền xuyên chi nhánh, onboarding, role routing, chuyên
  môn, xung đột, cấu hình theo cơ sở, thống kê và xóa mềm không mất dữ liệu.
- Từ `ktgk/`, dùng `C:\flutter\bin\flutter.bat analyze --no-pub` và các test phù hợp
  với `C:\flutter\bin\flutter.bat test --no-pub` khi sửa Dart.
- Không sửa generated build/cache/platform registrant; không thao tác nhầm dự án
  `learn_flutter/` bên cạnh. `FOUNDATION.md` là tài liệu lịch sử, README còn template.

Lần cập nhật 07/10/2026 này chỉ thay đổi tài liệu để chốt hướng triển khai; không
đổi code hay cấu hình backend và không chạy lại Flutter tests.
# Backend Giai đoạn 3 — cập nhật 07/10/2026

NestJS đã có StaffShiftsModule và LeaveRequestsModule, scope tại Guard/Service.
Staff chỉ gửi/xem đơn của mình; Manager quản lý đúng branch phiên; Boss toàn chuỗi.
API ca lưu branch snapshot, chặn sửa/xóa nếu giao lịch pending/confirmed/completed.
Migration `database/005_leave_intervals.sql` đã áp dụng trên Aiven: ngày nghỉ cũ
chuyển thành cả ngày Hà Nội; đơn mới có startAt/endAt/reason. Quyết định pending
→ approved/rejected chỉ một lần; DB lưu ID người xử lý, snapshot tên người xử lý,
tên cơ sở và thời gian. Boss cũng được quyết định, không chỉ Manager.
Không tạo bảng thống kê, không sửa Flutter; giữ synchronize:false và SSL CA.
Approved leave có query khoảng bận cho Booking Engine Giai đoạn 4; không tự hủy
lịch khách đã đặt. Seed 70 ca cho 10 Staff approved, 7 ngày tiếp theo, phân bổ
21/21/14/14 ở bốn cơ sở. Chi tiết API: backend/PHASE3_TESTING.md.

