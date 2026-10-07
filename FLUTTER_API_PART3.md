# Flutter API Phần3 — Booking và Appointments

Runtime remote dùng ApiBookingRepository/ApiAppointmentProvider. Mock chỉ dùng
ở chế độ test useMock:true. Không đổi schema hoặc thêm package.

## Cách dùng

- Customer: Home → Đặt lịch ngay → cơ sở/dịch vụ/thợ → ngày → slot từ server.
  Chốt lịch POST appointments; customerId/tên/giá/thời lượng do backend quyết định.
- Manager: Tổng quan → Tạo lịch nhanh → Tên/SĐT khách → dịch vụ/thợ/ngày/giờ.
  POST appointments/walk-in không gửi branchId/customerId; backend dùng phiên.
- Customer tab Lịch hẹn và Staff tab Lịch làm việc đã dùng GET appointments.
- Manager: Tổng quan → Quản lý lịch hẹn. Boss: tab Sổ lịch dùng cùng API.
- Lọc status, phân trang50 và Tải thêm; nhóm Sắp tới/Lịch sử. Hủy, complete,
  no-show có xác nhận/busy/refresh. Staff chỉ complete/no-show, Customer chỉ hủy
  lịch của mình; Manager cơ sở mình, Boss toàn chuỗi theo quyền server.
- Xóa lịch sử nối hai API hide/customer và hide/staff, không hard-delete.
- Home Customer dùng lịch sắp tới API, hủy đồng bộ tab Lịch hẹn. Manager upcoming
  dùng API; các metric/revenue/report vẫn chờ phần tiếp theo.

Màn Booking dùng catalog/branch thật; thợ từ branches/:branchId/staff?serviceId,
slots từ booking/available-slots. Không chia giờ trên client. Đổi cơ sở/dịch vụ
reset thợ/slot; đổi ngày reset slot. Request counter bỏ responses lựa chọn cũ.
Loading khóa submit; không tự retry POST. 409 luôn báo:

> Khung giờ này vừa có người đặt, vui lòng chọn giờ khác!

Sau409 bỏ slot đã chọn và tải lại availability. Nếu không có ca/ngày nghỉ/đầy lịch,
server trả slots rỗng; UI hướng dẫn chọn ngày hoặc thợ khác. Hiển thị giờ Hà Nội.
Home không dùng giờ/ngày nghỉ mock để khóa booking thật; settings UI chuyển ở đợt sau.

Tiền được giữ **String** trong ApiAppointment DTO, validate bằng ApiMoney.bigInt;
không cast double/int mất chính xác. Card định dạng VNĐ từ string. Tên dịch vụ
lấy snapshot của appointment_services. Tên thợ lookup directory/roster hợp lệ;
nếu nhân viên không còn trong directory hiện tại, hiển thị ID thay vì đoán tên.

Provider session epochs chống data về sau logout; role/branch/ownership vẫn được
backend kiểm tra. Không truyền Actor/customerId/price trong body. Dashboard
analytics, Staff customers/earnings/profile metrics, catalog CRUD và settings
khác còn mock; chỉ đọc catalog cho booking đã chuyển API.

## Kiểm thử

```powershell
& C:\flutter\bin\flutter.bat test --no-pub
& C:\flutter\bin\flutter.bat analyze --no-pub
& C:\flutter\bin\flutter.bat test --no-pub --dart-define=RUN_LIVE_API_TEST=true test/api_live_test.dart
```

Widget test: server staff/slots, một POST, Snackbar409 đúng câu, bỏ chọn slot,
tải lại và VND vượt safe integer vẫn chính xác. Live tạo fixture có ca, Customer
bắn hai booking cùng slot: một thắng, một409; Shift đã có khách không xóa được,
Staff complete. Luồng mở rộng kiểm tra cancel, walk-in, no-show. Finally cleanup
chỉ appointments/user/shifts/leaves fixture, giữ seed và lịch thật.

Redmi USB giữ adb reverse3000 và
`--dart-define=API_BASE_URL=http://localhost:3000/api` khi chạy app.

Kết quả07/10/2026: analyzer sạch, 108 tests hồi quy pass +1 live opt-in skipped
trong suite mặc định. Live chạy riêng pass cả đặt đồng thời 1 thắng/409, cancel,
walk-in, complete/no-show và cleanup. Lệnh build APK mới bị từ chối; chưa build
artifact Phần3. Thay đổi phần này là Dart, không thêm native plugin/Manifest;
có thể Hot Restart phiên debug đang chạy đúng localhost USB để thử UI mới.
