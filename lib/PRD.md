# PRODUCT REQUIREMENTS DOCUMENT (PRD) - CHAIN MANAGEMENT BARBERSHOP/SPA

**Cập nhật định hướng: 07/10/2026.** Sản phẩm chuyển từ đặt lịch một cửa hàng
sang **Hệ thống Quản lý Chuỗi Cửa Hàng (Chain Management)**.
Chi tiết schema, phân quyền, onboarding và hiện trạng code nằm trong
[PROJECT_CONTEXT.md](../PROJECT_CONTEXT.md). Quyết định Pivot mới thay thế luồng
Admin một cửa hàng trước đây. Đợt 1 đã cập nhật Models, roles, seed và routing;
Đợt 2 đã phân quyền Providers theo phiên/chi nhánh/quyền sở hữu. Đợt 3 đã nối Home/Booking/History theo Branch và Auth session.
Chuỗi chỉ hoạt động tại Hà Nội. Đợt 4 đã chuyển workspace Manager theo Branch,
tuyển dụng hồ sơ pending không mật khẩu và catalog chỉ đọc. Đợt 5 đã có workspace
Boss: tổng quan chuỗi, sổ lịch, hoa hồng tạm tính, Branch/catalog CRUD và duyệt/
từ chối Staff. Hoa hồng mặc định 30% có thể chỉnh trong UI, chưa lưu hoặc chi trả.
Không tích hợp Zalo hoặc backend ở đợt này.

Backend mới tại `backend/` dùng NestJS, TypeORM, pg và @nestjs/config; có
GET /api/branches, TLS Aiven với CA/rejectUnauthorized=true và synchronize=false.
Flutter đã nối Auth/Boss onboarding (Phần1), ca làm/nghỉ phép (Phần2), Booking và
Appointments API (Phần3 Giai đoạn6), với slots server/409/actions/phân trang;
Dashboard/Reports Manager/Boss và earnings/profile-stats Staff đã nối Phần4,
VND string/BigInt có dấu phẩy và biểu đồ/ranking/loading/error từ dữ liệu server;
các features khác
vẫn mock, xem ../FLUTTER_API_PART1.md. Backend đã triển khai JWT/Guards,
onboarding/CRUD, ca làm/nghỉ phép, AppointmentsModule và ReportsModule theo
BACKEND_ROADMAP.md. Báo cáo completed-only theo ngày Hà Nội, tiền dạng string;
không lưu bảng doanh thu/hoa hồng và không nhân đôi tổng khi lịch có nhiều dịch vụ.
Booking kiểm tra ca thực tế, nghỉ approved, chuyên môn và cấu hình cơ sở; transaction
khóa Staff và dùng EXCLUDE PostgreSQL chống double-booking. Không bật synchronize.

Manager Dashboard chỉ giữ Doanh thu hôm nay, Lịch hôm nay, Lịch đã hủy.
“Báo cáo Doanh số” riêng theo cơ sở có tổng Hôm nay/Tháng này, giao dịch completed
hôm nay và xếp hạng doanh thu thợ trong tháng. Toàn bộ dữ liệu phái sinh từ
Appointments, không thêm bảng/cột; giữ kiểm tra quyền trong Provider.

Staff có các tab Lịch làm việc, Khách hàng, Thu nhập, Hồ sơ. Thu nhập hiển thị
doanh số dịch vụ completed hôm nay/tháng này và lịch sử ca của đúng Staff/Branch
trong phiên. Khách hàng có thẻ doanh số cá nhân; xóa mềm lịch trình không giảm
báo cáo. Chưa tính lương/hoa hồng thực nhận vì tỷ lệ Boss chưa được lưu dùng chung.

## 1. TỔNG QUAN & RÀNG BUỘC KỸ THUẬT (CONSTRAINTS)
- **Tech Stack:** Flutter (Dart).
- **Ràng buộc:** Máy phát triển có dung lượng thấp và cấu hình hạn chế. BẮT BUỘC ưu tiên kiến trúc siêu nhẹ (Lightweight), tối giản việc sử dụng 3rd-party packages, ưu tiên code thuần và giữ code sạch, phân hệ rõ ràng.
- **State Management:** Ưu tiên giải pháp nhẹ nhàng, ít boilerplate (đề xuất: `Provider`).
- **Design System:** Nền xám nhạt (`grey[50]`), Card trắng bo góc đổ bóng nhẹ. Nút bấm và icon dùng màu nâu đậm hoặc màu nhấn. Không gian rộng rãi.

## 2. KIẾN TRÚC THƯ MỤC (FEATURE-FIRST ARCHITECTURE)
Bắt buộc tổ chức mã nguồn trong `lib/` theo từng tính năng, không chia theo layer.
- `lib/core/`: Chứa hằng số, cấu hình, routing, utils, theme.
- `lib/shared/`: Chứa các UI widgets dùng chung (CustomButton, CustomTextField...).
- `lib/features/`: Chứa các module tính năng độc lập (ví dụ: `auth/`, `booking/`, `manager/`, `boss/`, `staff/`).

## 3. CÁC MODULE HỆ THỐNG CỐT LÕI (CORE MODULES)
Thay vì chỉ chia theo Role, hệ thống được cấu trúc thành các Module độc lập:
- **Module 1 - Auth & Routing:** Đăng nhập/đăng ký và điều hướng theo 4 vai trò: Super Admin (Boss), Manager, Staff, Customer. Register public chỉ tạo Customer. Staff phải được Boss duyệt và cấp credential trước khi đăng nhập.
- **Module 2 - Catalog & Services:** Catalog dịch vụ/giá dùng chung toàn chuỗi, Boss quản lý CRUD; Manager chỉ đọc. Chuyên môn Staff được chọn theo danh mục.
- **Module 3 - Booking Engine (Lõi đặt lịch):** Customer chọn Branch trước; lọc Staff đúng Branch, đã duyệt và đúng chuyên môn; lấy cấu hình giờ/ngày nghỉ của cơ sở; tạo lịch và chống double-booking.
- **Module 4 - Schedule Workspace:** Không gian làm việc của Staff để nhận lịch trong ngày và cập nhật trạng thái ca làm.
- **Module 5 - Manager Dashboard:** Phát triển từ Admin Dashboard hiện tại; chỉ thao tác dữ liệu doanh thu, lịch, nhân sự và cấu hình của Branch được phân công.
- **Module 6 - Boss Dashboard & Branch Management:** Quản lý Branch toàn chuỗi, Dashboard riêng, hàng chờ Staff và cấp mật khẩu khi duyệt.

## 3A. SCHEMA VÀ ONBOARDING SAU PIVOT

- Thêm `Branch`: `id`, `name` (ví dụ `dhung.cơ sở 1`), `address`, `phone`.
- Thêm `branchId` vào AppUser (bắt buộc cho Staff/Manager), Appointment và ShopSettings. Mỗi Branch có một cấu hình cửa hàng.
- AppUser bổ sung SĐT/địa chỉ cho hồ sơ Staff và `isApproved`; chuyên môn giữ `specializedCategoryIds`.
- Manager tạo hồ sơ Staff gồm Tên, Email, SĐT, Địa chỉ, Chuyên môn tại Branch mình, `isApproved = false`, không có mật khẩu. Email bắt buộc/duy nhất; mọi vai trò đăng nhập bằng email.
- Boss xem hồ sơ chờ toàn chuỗi, duyệt và nhập mật khẩu cấp phát; chỉ bật `isApproved = true` khi credential Auth đã được tạo thành công.
- Thẻ “Nhân viên chờ duyệt” chỉ có **Duyệt** (dialog cấp mật khẩu) và **Từ chối** (xác nhận rồi xóa hồ sơ pending chưa có credential/lịch, không giữ lịch sử từ chối).
- Sau khi Boss bấm “Duyệt” và nhập mật khẩu cấp phát trên hệ thống, quy trình trên ứng dụng kết thúc khi thao tác thành công. Việc liên hệ và gửi mật khẩu cho nhân viên sẽ do Boss thao tác thủ công bên ngoài (tự mở Zalo/gọi điện thoại).
- Hủy yêu cầu deep link Zalo, package `url_launcher` và nút “Liên hệ Zalo”. Không gửi tin nhắn từ app hoặc lưu mật khẩu plaintext trong hồ sơ/log.
- Không thêm login bằng SĐT, bảng Approval, trạng thái rejected hoặc branchId trên Service. Kế hoạch chuyển đổi theo đợt nằm trong [CHAIN_IMPLEMENTATION_PLAN.md](../CHAIN_IMPLEMENTATION_PLAN.md).
- Backend phải kiểm tra quyền theo role/branch/ownership, không chỉ lọc giao diện. Không thêm bảng Sessions hoặc bảng tuyển dụng.

## 4. LỘ TRÌNH LÀM VIỆC (BOTTOM-UP WORKFLOW)

### Giai đoạn 1: Dựng Giao Diện (UI/UX) - [✅ ĐÃ HOÀN THÀNH]
*Status: UI nền tảng mô hình một cửa hàng đã có; nhiều luồng đã nối logic RAM.*
- UI Boss, Branch selector và onboarding theo Pivot chưa được xây dựng.

### Giai đoạn 2: Phân Tích Chức Năng & Thiết Kế CSDL - [🚀 ĐANG THỰC HIỆN]
*Status: Models Branch/branchId/phone/address/isApproved và bốn role đã được code; đang tiếp tục chuyển đổi logic chuỗi theo kế hoạch.*
- **Bước 1 (Phân tích Chức năng):** Đọc lại toàn bộ UI hiện có. Bóc tách và liệt kê chi tiết các tính năng cần viết logic dựa trên các thành phần đang hiển thị.
- **Bước 2 (Thiết kế Schema):** Thiết kế CSDL (Tables, Fields, Relationships) dựa trên các tính năng đã chốt.
- **Bước 3 (Data Models):** Chuyển đổi Schema thành các class Data Entity (Entity Models) trong mã nguồn.

### Giai đoạn 3: State Management & Logic Cục Bộ (Mocking) - 
*Status: Viết logic chạy trên RAM (Mock Data).*
- Provider, Mock Repository, Booking Engine, workspace Staff, CRUD Admin và cấu hình động đã hoạt động ở mô hình một cửa hàng.
- Bước tiếp theo: Models/seed cho Branch và role mới, phân vùng dữ liệu, chọn Branch khi Booking, Manager Dashboard và Boss onboarding. Kiểm tra luồng mock toàn chuỗi trước khi nối backend.

### Giai đoạn 4: Tích Hợp Backend (Real Database) - 
*Status: Nối mạng cho ứng dụng.*
- Chọn aiven; nối Auth thực tế/JWT, dữ liệu chuỗi, kiểm tra quyền ở server và chống trùng lịch nguyên tử.
- Migrate dữ liệu cũ về Branch cụ thể, ánh xạ rõ Admin cũ sang Boss/Manager, triển khai luồng duyệt/cấp credential theo tài liệu. Liên hệ nhân viên do Boss thực hiện bên ngoài ứng dụng.
- Chốt TTL/Cronjob trước hard-delete; giữ thống kê chi nhánh/toàn chuỗi và cơ chế xóa mềm trên Client.

### Giai đoạn 5: Hoàn thiện & Mở rộng - [⏳ CHƯA BẮT ĐẦU]
- Xử lý Loading, Error, Empty States.
- Chat trong app, tích hợp Zalo, reschedule và logic thưởng/giảm giá/gửi đánh giá
  vẫn ngoài phạm vi cốt lõi. Xin nghỉ phép tạo pending theo Staff/Branch trên RAM,
  Manager cùng Branch Duyệt/Từ chối và lưu lịch sử người duyệt/thời điểm/ghi chú.
  Ngày approved chặn lịch mới, giữ nguyên ca đã đặt; restart mất state mock.
  Cài đặt Manager có chỉnh thông tin cá nhân và đổi mật khẩu thật qua Provider.
  Profile có đổi mật khẩu và điểm
  trung bình từ các fields isReviewed/rating trên Appointment, không thêm bảng.
