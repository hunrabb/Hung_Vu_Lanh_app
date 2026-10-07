# Flutter API Phần4 — Dashboard và báo cáo

ReportRepository/ReportProvider đọc API theo session, không fallback mock.
Không thêm package, bảng/cột hoặc thay backend. Tiền String → BigInt để validate,
format trực tiếp với dấu phẩy: **1,500,000 VND**. Biểu đồ thanh dùng tỷ lệ nguyên
BigInt chuẩn hóa0–1000; không chuyển số tiền lớn sang double.

## UI đã nối

- Manager Tổng quan: GET manager/dashboard, tên cơ sở từ API; doanh thu ngày,
  lịch/ca hủy, doanh thu tháng và upcoming. Top Staff tháng/biểu đồ dùng
  manager/revenue. Giữ CTA Tạo lịch nhanh/Báo cáo Doanh số và thao tác nhanh.
- Manager Báo cáo Doanh số: chọn khoảng ngày, tổng completed revenue, ledger
  phân trang và ranking Staff; không truyền branchId, server dùng profile phiên.
- Boss Tổng quan: dashboard + leaderboards, lọc toàn chuỗi/từng cơ sở, doanh thu
  ngày/tháng, lịch ngày/tháng, top cơ sở và Staff/biểu đồ.
- Boss Sổ lịch: GET boss/appointments, filter cơ sở/status/kỳ và phân trang;
  mỗi giao dịch có tên thợ/cơ sở/dịch vụ snapshot.
- Boss Hoa hồng: GET boss/commissions, 30% **tạm tính** do server tính, lọc/kỳ/
  phân trang. Bỏ slider mock; không coi đây là tiền lương đã chi trả.
- Staff Thu nhập: GET staff/me/earnings, doanh số ngày/tháng và ca completed.
- Staff Hồ sơ: GET staff/me/profile-stats, completed tháng/đánh giá/khách phục vụ.
  Tab Khách hàng cũng dùng profile-stats customers/LTV/visits/lastVisit từ API.

Mỗi vùng có loading, lỗi + Thử lại, empty state, nút Cập nhật và pull refresh.
Cache theo endpoint/query và session; đổi role/branch/logout bỏ response cũ.
Booking/cancel/complete/no-show/hide phát mutation signal làm báo cáo đang mở
tải lại. Các client khác bấm Cập nhật để đọc thay đổi mới, chưa có realtime sockets.

Kỳ from/to là ngày Hà Nội, bao gồm cả ngày cuối, tối đa366 ngày (backend contract).
Không suy diễn doanh thu từ trang ledger đang xem: dùng aggregate server toàn kỳ.
Revenue chỉ completed; hidden vẫn tính; walk-in không gộp thành một customer.
Người chuyển cơ sở có tags lịch sử; tiền được tính theo branch snapshot lịch hẹn.

## Chạy thử

Hot Restart phiên debug Redmi dùng localhost USB. Boss: boss@example.com / boss123
→ Tổng quan, Sổ lịch, Hoa hồng. Nếu doanh thu0 thì kỳ/cơ sở đó chưa có completed
trong DB; app hiển thị đúng0, không tạo doanh thu seed giả. Hoàn thành một lịch
trong kỳ trên Staff rồi Cập nhật Boss để đối soát. Backend cần chạy cổng3000.

```powershell
& C:\flutter\bin\flutter.bat analyze --no-pub
& C:\flutter\bin\flutter.bat test --no-pub
& C:\flutter\bin\flutter.bat test --no-pub --dart-define=RUN_LIVE_API_TEST=true test/api_live_test.dart
```

Tests mới: format BigInt vượt safe integer, filter Boss đúng query, API error/retry,
invalidation sau mutation và logout. Live kiểm tra earnings/profile/revenue,
Boss dashboard/leaderboard/ledger/commission sau completed, cleanup fixture.

## Phạm vi còn lại

Report/Booking/Shifts/Leave/Auth/onboarding đã nối. Catalog/Branch CRUD, Manager
form tuyển dụng, settings cửa hàng và một số form thông tin/đổi mật khẩu vẫn dùng
mock từ các đợt trước; không tuyên bố toàn bộ ứng dụng đã bỏ mock. Không build APK
mới trong phần này; lần trước người dùng đã từ chối bước build. Các thay đổi là Dart.

Kết quả07/10/2026: 110 tests pass +1 live opt-in skipped trong suite mặc định;
live chạy riêng pass toàn luồng cùng báo cáo/hoa hồng, fixture dọn sau test.
