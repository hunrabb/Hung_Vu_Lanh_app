# Kế hoạch chuyển đổi sang Chain Management

**Ngày rà soát:** 07/10/2026 · **Phạm vi:** dự án `ktgk`

Kế hoạch dựa trên Models, routing, wiring trong app.dart, Auth/User/Booking/Settings
providers và repositories, các màn hình liên quan và test hiện tại. Đọc cùng
[PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) và [PRD](lib/PRD.md).
Kế hoạch ban đầu chỉ cập nhật tài liệu. Đợt 1–2 đã được triển khai ngày 07/10/2026;
không nối database hoặc thiết kế lại UI. Xem tiến độ trong PROJECT_CONTEXT.md.
Mốc kiểm tra gần nhất trước Pivot là analyze sạch và 66 test pass; đó là kiểm tra
mô hình một cửa hàng, chưa chứng minh quyền truy cập đa chi nhánh.

## 1. Kết quả rà soát

| Khu vực | Hiện trạng trong code | Cần chuyển đổi |
| --- | --- | --- |
| Models | Sáu entity, UserRole customer/staff/admin; không branchId/isApproved/phone/address | Thêm Branch và các trường/role đã chốt |
| Auth | Admin tạo Staff có mật khẩu ngay; credential/profile đã đồng bộ | Manager chỉ tạo hồ sơ, Boss mới duyệt/cấp mật khẩu; chặn Staff chưa duyệt |
| Routing | `/admin`, `/admin/services`, guards theo ba role | Route Boss riêng, Manager riêng; kiểm tra branch và approval |
| Users | CRUD và truy vấn danh sách chung toàn app | Query/mutation có phạm vi và quyền; Manager không sửa người ở Branch khác |
| Booking | Đã lọc chuyên môn, ngày nghỉ, giờ đã qua, trùng lịch; chưa có branch | Thêm branch vào mọi bước, chỉ chọn Staff approved cùng cơ sở |
| Customer | Home/history/booking dùng customer-01 | Dùng currentUser.id; chọn Branch trước khi đặt |
| Settings | Một ShopSettingsProvider giữ một cấu hình | Kho cấu hình theo Branch, cập nhật có phạm vi |
| Dashboard | Thống kê từ toàn bộ Appointments của ngày | Manager lọc Branch, Boss xem toàn chuỗi/theo Branch |
| Staff | Schedule lấy Staff hiện tại nhưng còn fallback staff-01; stats đã phái sinh | Bỏ fallback ở app, thêm branch/approval/ownership vào đọc và ghi |
| Boss | Chưa có code/màn hình | Quản lý Branch, hàng chờ với Duyệt/Từ chối |
| Backend | RAM, chưa có Auth thật/JWT/database | Chỉ tích hợp sau khi mock chuỗi được kiểm thử |

Các phần nên giữ: UTC và khoảng nửa mở, giá/tên snapshot, chuyên môn theo category,
slot engine, UI card, thống kê phái sinh, cờ xóa mềm độc lập, listener cấu hình và
kho Auth/profile dùng chung. Không viết lại toàn app hoặc thêm package kiến trúc.

## 2. Ba quyết định đã được chốt

Các lựa chọn sau đã được người dùng duyệt ngày 07/10/2026 và là căn cứ để code.

| Quyết định | Phương án đã chốt | Hệ quả triển khai |
| --- | --- | --- |
| Định danh đăng nhập | Email cho tất cả vai trò | Form tuyển dụng thêm email bắt buộc; giữ email trên AppUser |
| Catalog dịch vụ/giá | Chung toàn chuỗi, Boss quản lý | Manager chỉ đọc; Service không cần branchId |
| Từ chối Staff | Xóa hồ sơ chờ, không giữ lịch sử | Không thêm trạng thái rejected hoặc bảng lịch sử từ chối |

Email được trim/lowercase và kiểm tra duy nhất trên kho Users/Auth, kể cả hồ sơ
pending. SĐT giữ dạng String và dùng liên hệ thủ công, không dùng đăng nhập.
Customer Register tiếp tục chỉ tạo Customer.

Từ chối: chỉ Boss được xóa hồ sơ pending chưa có credential/lịch, hỏi xác nhận
và không mở rộng việc hard-delete nhân sự đã phục vụ. Không lưu lịch sử từ chối,
không tự thêm bảng Approval hoặc isRejected.

Cách bootstrap Boss/Manager thật sẽ chốt khi chọn backend. Trong mock, seed tường
minh một Boss và Manager cho từng cơ sở; không tự nâng quyền mọi tài khoản admin cũ.

## 3. Thứ tự các đợt code

Mỗi đợt phải giữ app biên dịch/chạy được và có test tương ứng. Không chuyển sang
backend khi quyền/cô lập dữ liệu trong mock chưa được xác nhận.

### Đợt 1 — Models, role, seed và routing nền tảng

**Đã triển khai:** model/schema, bốn role, hai Branch, seed approved/pending,
Boss placeholder, Manager route và khóa Manager cấp credential. UI/phân vùng dữ
liệu đầy đủ của các đợt sau vẫn chưa triển khai.

**Files chính:** core/models/{branch,app_user,appointment,shop_settings}.dart,
core/routing/, app.dart, các switch/guards dùng UserRole.admin và fixture test.

- Branch gồm id/name/address/phone; thêm branchId đúng ba entity đã chốt.
- AppUser thêm phone/address/isApproved; giữ specializedCategoryIds và credentials
  riêng Auth. Giữ các field hiện dùng, không sinh model song song.
- Role thành superAdmin/manager/staff/customer. Chuyển enum, guards, Auth và các
  switch cùng đợt; không chỉ thay enum rồi để API quyền admin cũ tiếp tục hoạt động.
- Seed ít nhất hai Branch, một Boss, hai Manager, Staff approved/pending ở cả hai
  Branch và lịch mẫu có branchId khớp. ShopSettings có một bản ghi mỗi Branch.
- Route Manager mở shell hiện có; route Boss có shell nền tảng riêng, sẽ hoàn thiện
  ở đợt 5. Luồng tạo Staff có mật khẩu cũ phải bị khóa đối với Manager ngay khi đổi role.
- Legacy JSON thiếu branch không được âm thầm gán Branch A hoặc approved=true.
  Migration dữ liệu cũ phải tường minh; mock RAM có thể reset seed sau thay đổi.

**Nghiệm thu:** JSON/copyWith giữ đầy đủ field; Staff/Manager thiếu branch bị từ chối;
bốn role điều hướng đúng; Customer không tự chọn quyền; Staff pending không vào workspace.

### Đợt 2 — Kho Branch và phạm vi truy cập thống nhất

**Đã triển khai application:** Branch CRUD có quyền Boss, query/mutation Users và
Appointments theo phiên/branch/ownership, catalog Boss-only, Map cấu hình theo
Branch và cập nhật phạm vi khi phiên thay đổi. Màn hình chọn Branch và onboarding
vẫn thuộc các đợt sau; mock repositories chỉ là storage nội bộ.

**Files chính:** features/branches/{data,application}/; users/, booking/, settings/;
app.dart; một helper kiểm tra quyền nhỏ trong core nếu cần tái sử dụng.

- MockBranchRepository/BranchProvider CRUD; kiểm tra khóa tham chiếu trước xóa Branch.
- Bổ sung query lịch/nhân sự theo Branch; dùng danh tính phiên hiện tại khi xác
  định phạm vi Manager, không tin branchId do form gửi lên.
- Mọi thao tác ghi phải kiểm tra quyền ở Provider/application: không chỉ lọc UI.
  cancel/complete/noShow/hide phải kiểm tra cả chủ sở hữu, branch và trạng thái.
- ServiceProvider giữ catalog chung, nhưng thêm/sửa/xóa dịch vụ chỉ cho Boss;
  Manager và Customer đọc dữ liệu cần thiết, không có quyền ghi catalog.
- Boss có truy vấn toàn chuỗi; Manager chỉ có cơ sở mình; Staff chỉ dữ liệu phục vụ
  của mình trong cơ sở; Customer chỉ lịch cá nhân dù đặt ở nhiều Branch.
- ShopSettingsProvider chuyển từ một cấu hình sang kho keyed by branchId, có
  get/update theo Branch. Không khởi tạo lại AppointmentRepository khi đổi Branch.
- Theo dõi cập nhật role/branch/approval của user đang đăng nhập để guard và hành
  động không tiếp tục dùng quyền từ snapshot phiên đã cũ.

**Nghiệm thu:** gọi trực tiếp Provider với Manager A để sửa Branch B phải thất bại;
Boss đọc được cả hai; thay giờ/ngày nghỉ A không đổi cấu hình B; logout giữ đúng cơ chế.

### Đợt 3 — Booking và luồng Customer theo Branch

**Đã triển khai:** Home chọn cơ sở bằng state UI; Booking lọc Branch/approval/chuyên môn, reset thợ/giờ; history hiển thị cơ sở, dùng ID phiên thật. Chuỗi chỉ hoạt động tại Hà Nội; seed địa chỉ mẫu Cầu Giấy/Đống Đa.

**Files chính:** customer_home_screen.dart, customer_appointments_screen.dart,
customer_booking_screen.dart, appointment_provider.dart, mock_appointment_repository.dart.

- BranchProvider giữ danh sách; state lựa chọn Branch dành cho Customer tách khỏi
  branch của user. Không dùng một selectedBranch toàn app để ghi đè phạm vi Manager.
- Bắt buộc chọn Branch trước dịch vụ/thợ; Staff phải approved, cùng Branch và đúng category.
- Đổi Branch/dịch vụ reset Staff/slot. Home lấy giờ/banner ngày nghỉ của Branch đang chọn.
- availableSlots/book nhận branchId và đọc cấu hình đúng cơ sở. Xác nhận kiểm tra
  lại Branch/approval/chuyên môn/slot; client giả branch hoặc thợ khác cơ sở bị chặn.
- Bỏ customer-01 trong đường chạy thật, dùng currentUser.id. Customer history vẫn
  chứa lịch cá nhân ở nhiều Branch, hiển thị tên cơ sở để phân biệt.
- Chống trùng lịch vẫn theo Staff và thời gian; đổi branchId không được dùng để
  né xung đột của cùng một Staff. Không tự sửa branchId trên lịch lịch sử.

**Nghiệm thu:** Customer A không thấy lịch Customer B; chọn Branch A không thấy Staff B;
Staff pending không được đặt; đổi giờ/ngày nghỉ A cập nhật slot A mà B không thay đổi.

### Đợt 4 — Manager Dashboard và hồ sơ Staff chờ duyệt

**Đã triển khai:** workspace `features/manager/`, tiêu đề tên cơ sở, query theo
phiên/Branch, tuyển dụng qua createStaffProfile không credential, catalog chỉ đọc
và cấu hình theo cơ sở. Dashboard/phê duyệt Boss tiếp tục ở Đợt 5.

**Files chính:** chuyển UI admin/ sang manager/ theo từng phần; dashboard, staff form,
settings và walk-in booking; UserProvider/AuthController.

- Đổi tên shell/màn hình thành Manager, tái sử dụng layout đang hoạt động.
- Metrics, lịch hôm nay và nhân viên chỉ lấy theo Manager.branchId, gồm dữ liệu
  bị ẩn UI trong thống kê. Walk-in luôn gán branch của Manager.
- Form Staff: tên, email, SĐT, địa chỉ, chọn nhiều chuyên môn. Không có ô mật khẩu,
  tự gán pending và branch của Manager.
- Thay API createStaffAccount hiện tại bằng createStaffProfile cho Manager; không
  cấp credential ở đây. Manager không bật approval/đổi role/chuyển cơ sở tùy ý.
- Giờ/ngày nghỉ chỉ sửa được cơ sở mình. Tab dịch vụ chỉ đọc catalog chung;
  chuyển quyền thêm/sửa/xóa dịch vụ sang Boss.

**Nghiệm thu:** Manager tạo hồ sơ xong Staff chưa đăng nhập được/chưa có trong Booking;
không có mật khẩu trong profile/JSON; dashboard A không tính doanh thu B.

### Đợt 5 — Boss Dashboard, Branch CRUD và phê duyệt

**Đã triển khai:** workspace Boss sáu tab, lọc Branch, báo cáo ngày/tháng,
leaderboard, sổ lịch và hoa hồng tạm tính. Hoa hồng mặc định 30%, chỉnh trong UI,
không thêm bảng/logic chi trả. Branch/catalog CRUD và phê duyệt cùng ID hồ sơ,
thử lại cấp credential có rollback; từ chối bảo vệ hồ sơ có lịch/credential.

**Files mới dự kiến:** features/boss/presentation/{boss_main,boss_dashboard_screen,
boss_branches_screen,boss_services_screen,boss_pending_staff_screen}.dart;
application/User/Auth API phê duyệt.

- Boss có tổng quan chuỗi và lọc Branch; CRUD Branch đơn giản, xử lý đúng tham chiếu.
- Tab dịch vụ Boss tái sử dụng form/catalog CRUD hiện có; Manager không còn nút
  thêm/sửa/xóa dịch vụ. Quyền vẫn được kiểm tra ở Provider, không chỉ ẩn nút.
- Thẻ pending chỉ thông tin cần duyệt và hai nút Duyệt/Từ chối, không nút liên hệ.
- Duyệt mở dialog mật khẩu. Credential phải gắn đúng ID profile đang chờ, không
  tạo một Staff mới có ID khác. Chỉ bật approved khi đăng ký credential thành công.
- Có kiểm tra role Boss, trạng thái pending và chống double-submit. Thử lại sau
  lỗi không tạo tài khoản trùng, không để approved mà thiếu credential.
- Từ chối hỏi xác nhận rồi xóa hồ sơ pending chưa có credential/lịch; không cấp
  credential, không lưu lịch sử từ chối.
- Quy trình trên app kết thúc sau duyệt thành công. Boss tự gửi mật khẩu bên ngoài;
  không url_launcher, deep link, API nhắn tin hoặc bảng trạng thái gửi mật khẩu.

**Nghiệm thu:** Manager không gọi được approve; Staff pending đăng nhập thất bại;
Boss duyệt xong đúng Staff đăng nhập và nhận lịch đúng Branch; duplicate submit an toàn.

### Đợt 6 — Workspace Staff và tính nhất quán báo cáo

**Files chính:** staff_schedule_screen.dart, staff_customers_screen.dart,
staff_profile_screen.dart và các hàm thống kê trong AppointmentProvider.

- Dùng Staff đang đăng nhập + branch + approved; bỏ fallback staff-01 khỏi app.
- Giữ chia ca sắp tới/đã kết thúc, completed/noShow, hiển thị tiền và xóa mềm.
- Customer list/LTV/count/max endAt chỉ lấy dữ liệu đúng Staff/Branch; hidden flags
  không làm thay đổi metrics Manager/Boss.
- Nếu sau này chuyển Staff sang Branch khác, lịch cũ giữ branchId đã phục vụ;
  không đổi lịch lịch sử theo branch hiện tại trên hồ sơ nhân viên.

**Nghiệm thu:** Staff A không hoàn thành/ẩn lịch Staff B; thao tác Staff cập nhật
Customer history và đúng Manager Dashboard; xóa mềm không giảm doanh thu/LTV.

### Đợt 7 — Kiểm thử toàn chuỗi và chuẩn bị backend

- Thay test nghiệp vụ cũ “Admin tạo Staff và đăng nhập ngay” bằng Manager tạo
  pending → Boss duyệt → Staff login. Giữ test slot, specialty, snapshots, UTC,
  cấu hình động, xóa mềm và layout nhỏ còn hợp lệ.
- Một test luồng đầy đủ: Boss tạo Branch → Manager tạo Staff → pending bị chặn →
  Boss duyệt → Customer chọn Branch và đặt → Staff hoàn thành → đúng báo cáo cơ sở.
- Test phủ hai Branch và thao tác trái quyền trực tiếp trên Provider, không chỉ
  test màn hình đã lọc danh sách. Kiểm tra JSON thiếu branch không làm rộng quyền.
- Khóa schema và lựa chọn backend; đưa contract repository nhỏ vào từng feature để
  thay mock bằng backend. Không thêm một framework repository chung nặng nề.
- Chưa bật TTL hoặc hard-delete dữ liệu phục vụ báo cáo khi chưa chốt retention.

**Nghiệm thu:** analyze sạch, test chuỗi và hồi quy pass; không còn hardcode ID ở
luồng thật, không còn đường tạo credential trái quyền hoặc đọc chéo chi nhánh.

### Giai đoạn 4 — Nối database thật

Chỉ bắt đầu sau đợt 7: triển khai quyền ở backend, Auth/JWT và quy trình Boss cấp
credential qua server; query/index theo Branch, kiểm tra xung đột nguyên tử và
migration tường minh. Không đặt khóa quản trị trong Flutter. Đồng bộ approval và
credential phải có xử lý lỗi/retry, vì Auth và database không mặc nhiên là một
transaction. Persistence thay RAM; retention triển khai sau khi bảo toàn thống kê.

## 4. Những việc chưa đưa vào đợt Pivot

Không triển khai Zalo/chat, reschedule, thưởng/giảm giá/đánh giá, xin nghỉ phép,
ca làm chi tiết hoặc nhiều Branch cho cùng một Staff. Không thêm bảng khách hàng
của Staff, doanh thu hoặc tuyển dụng để thay thống kê phái sinh.

## 5. Việc nên code đầu tiên

Ba lựa chọn ở mục 2 đã chốt. Đợt 1–5 đã triển khai. Bước tiếp theo là
**Đợt 6: Workspace Staff và tính nhất quán báo cáo**. Không chỉ
đổi tên Admin thành Manager hoặc thêm bộ lọc UI rồi coi Pivot đã hoàn thành.
