# Flutter API Phần2 — Ca làm và nghỉ phép

WorkspaceRepository/WorkspaceProvider đọc và ghi NestJS, không fallback mock.
Không đổi backend/schema hoặc thêm package. Phiên/401 dùng Core Network Phần1.

## Cách test trên app

1. Staff đăng nhập `staff@exampler.com / staff123` → Hồ sơ → Xin nghỉ phép.
   Chọn ngày/giờ bắt đầu/kết thúc, nhập lý do rồi Gửi/Lưu. Đơn chờ hiển thị ngay
   trong Đơn nghỉ của tôi. API tự xác định Staff/Branch từ JWT.
2. Đăng xuất, Manager Cầu Giấy đăng nhập `admin@example.com / admin123` → Nhân viên.
   Mục Duyệt nghỉ phép đọc API của đúng cơ sở. Duyệt nghỉ/Từ chối nghỉ → xác nhận
   ghi chú → refresh. Lịch sử hiển thị snapshot người xử lý/cơ sở/thời điểm từ DB.
3. Đăng nhập lại Staff (hoặc bấm Cập nhật) để thấy quyết định mới.
4. Manager → Nhân viên → Quản lý ca làm. Thêm ca chọn Staff approved từ API,
   chọn khoảng ngày/giờ; sửa/xóa với xác nhận. Ca đã có lịch khách trả409 và
   Snackbar giải thích không thể sửa/xóa; dữ liệu không bị xóa trên client.
5. Staff → icon lịch trên Lịch làm việc → Ca làm để xem GET staff/me/shifts.
6. Boss → icon lịch trên AppBar → Ca làm & Nghỉ phép. Chọn cơ sở để quản lý ca;
   tab Nghỉ phép đọc toàn chuỗi, mỗi card ghi cơ sở. Boss có quyền quyết định.

Ngày/giờ nhập và hiển thị theo Hà Nội UTC+7, gửi ISO UTC. Tối đa31 ngày mỗi
khoảng; lý do bắt buộc. Form ca không cho đổi Staff khi sửa (đúng DTO backend).
Loading/busy chống submit trùng; lỗi mạng/server có Snackbar và nút cập nhật.
409 quyết định bất biến có thông báo và refresh. Logout/dispose/đổi chi nhánh
bỏ responses cũ; các refresh cùng phạm vi được gộp, sau mutation luôn đọc lại.

## API được sử dụng

- GET branches/:branchId/shifts; POST branches/:branchId/shifts;
  PATCH/DELETE shifts/:id; GET staff/me/shifts.
- POST/GET staff/me/leave-requests; GET leave-requests;
  POST leave-requests/:id/decision.
- GET branches và users/branch/:branchId cung cấp tên cơ sở/nhân viên thực tế.

Các thẻ **lịch hẹn khách** trên Staff Schedule là Appointments, khác với StaffShifts.
Booking, appointments, báo cáo, catalog và form tuyển dụng Manager vẫn chưa chuyển
API ở Phần2. Nghỉ approved chặn booking **backend**; UI Customer booking mock cũ
chưa đồng bộ API cho tới đợt tiếp theo. Không coi các thao tác mock đó đã ghi Aiven.

## Kiểm thử

```powershell
& C:\flutter\bin\flutter.bat analyze --no-pub
& C:\flutter\bin\flutter.bat test --no-pub
& C:\flutter\bin\flutter.bat test --no-pub --dart-define=RUN_LIVE_API_TEST=true test/api_live_test.dart
```

Live test tạo fixture Staff, duyệt, xin nghỉ/Manager quyết định, CRUD ca và đọc
ca/đơn từ Staff. Cleanup chỉ fixture, không sửa70 ca seed hoặc đơn thật.
Widget test kiểm tra xóa ca409 có Snackbar, refresh, logout và conversion UTC+7.

Redmi USB: adb reverse tcp:3000 tcp:3000; chạy với
`--dart-define=API_BASE_URL=http://localhost:3000/api` như Phần1.

Kết quả07/10/2026: analyzer sạch; 106 tests pass, 1 live opt-in skipped ở suite
mặc định. Live chạy riêng pass Staff xin nghỉ→Manager duyệt→Staff đọc trạng thái,
CRUD ca→Staff đọc ca. APK debug build với localhost USB thành công.
