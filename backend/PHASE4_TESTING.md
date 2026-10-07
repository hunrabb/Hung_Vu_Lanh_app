# Giai đoạn 4 — Booking Engine

NestJS dùng database Aiven hiện có; không migration mới, không synchronize.
Giữ SSL CA/rejectUnauthorized=true. Flutter vẫn dùng mock trong giai đoạn này.

## API

| API | Quyền / dữ liệu |
| --- | --- |
| GET /api/branches/:branchId/staff?serviceId=... | Public; chỉ ID/tên/cơ sở của Staff approved, đúng chuyên môn |
| GET /api/booking/available-slots | Public; branchId, staffId, date, serviceIds |
| POST /api/appointments | Customer; customerId và tên lấy từ phiên |
| POST /api/appointments/walk-in | Manager; Branch lấy từ phiên, customerId NULL |
| GET /api/appointments | JWT; Customer riêng, Staff riêng, Manager cơ sở, Boss toàn chuỗi |
| POST /api/appointments/:id/cancel | Customer sở hữu, Manager đúng cơ sở, Boss |
| POST /api/appointments/:id/complete hoặc /no-show | Manager đúng cơ sở hoặc Staff sở hữu cùng cơ sở |
| POST /api/appointments/:id/hide/customer hoặc /hide/staff | Chủ sở hữu tương ứng, chỉ lịch đã kết thúc |

GET appointments trả array có danh sách services/snapshot tên. Query tùy chọn:
branchId, status, from, to, page=1, limit=50 (tối đa 100). Timestamp from/to có
offset/Z; khoảng [from,to). Manager/Staff truyền Branch khác bị 403. Cờ ẩn chỉ
lọc view Customer/Staff tương ứng, Manager/Boss vẫn có lịch để báo cáo.

## Kiểm tra bằng Postman/cURL

Đăng nhập POST `/api/auth/login`, body `{ "email": "customer@example.com",
"password": "customer123" }`; lấy accessToken làm Bearer token.
Manager Cầu Giấy: admin@example.com / admin123; Boss: boss@example.com / boss123.

Lấy ID dịch vụ active từ GET `/api/services`, rồi gọi:

```bash
curl 'http://localhost:3000/api/branches/branch-01/staff?serviceId=<SERVICE_ID>'

curl 'http://localhost:3000/api/booking/available-slots?branchId=branch-01&staffId=<STAFF_ID>&date=<YYYY-MM-DD>&serviceIds=<SERVICE_ID_1>,<SERVICE_ID_2>'
```

Ngày là ngày Hà Nội, chọn ngày có ca seed trong 7 ngày tiếp theo. Response:

```json
{
  "totalDurationMinutes": 75,
  "totalPriceVnd": "130000",
  "slots": [{ "startAt": "2033-06-20T01:00:00.000Z", "endAt": "2033-06-20T02:15:00.000Z" }]
}
```

Ví dụ response chỉ minh họa định dạng; không dùng ngày này nếu chưa tạo ca.
POST `/api/appointments`, chọn startAt từ slots vừa nhận:

```json
{
  "branchId": "branch-01",
  "staffId": "<STAFF_ID>",
  "serviceIds": ["<SERVICE_ID_1>", "<SERVICE_ID_2>"],
  "startAt": "<START_AT_FROM_SLOTS>"
}
```

Walk-in: POST `/api/appointments/walk-in` với token Manager, **không branchId**:

```json
{
  "staffId": "<STAFF_ID>",
  "serviceIds": ["<SERVICE_ID>"],
  "startAt": "<START_AT_FROM_SLOTS>",
  "customerName": "Nguyễn An / 0901234567"
}
```

Tên/SĐT walk-in lưu trong customer_name hiện có; không thêm bảng/cột.
Không gửi customerId, giá, thời lượng, status hay role. DTO từ chối fields lạ,
dịch vụ trùng/thiếu, timestamp thiếu offset; startAt phải đúng phút.

## Transaction và thuật toán

- Ngày nghiệp vụ Hà Nội UTC+7; DB timestamp UTC. Không có ca thì không có slot.
- Hợp các ca chồng/liền kề, giao giờ cửa hàng; trừ khoảng bận và nghỉ approved.
  Không vắt qua khoảng nghỉ giữa ca. Ngày đóng cửa trả slots rỗng.
- Slot grid chia theo tổng thời lượng; POST kiểm tra nằm trọn khoảng liên tục
  còn trống, không ép đúng grid GET vì lịch bận có thể làm thay đổi grid.
- POST transaction khóa settings FOR SHARE → Staff FOR UPDATE → services
  FOR SHARE theo ID tăng dần. Đọc lại approval/branch/specialty/shifts/leave/busy,
  tính giá BIGINT và duration, INSERT lịch cùng service items rồi COMMIT.
- Xung đột Staff kiểm tra toàn bộ Branch; không dùng branchId để né trùng lịch.
- EXCLUDE gist `[start,end)` là rào chắn cuối; 23P01 → 409. Các request cùng Staff
  được tuần tự hóa trên một row ổn định, kể cả lúc chưa có lịch nào.
- 40P01/40001 retry toàn transaction tối đa 3 lần, có jitter; hết lượt trả 503.
  Không retry overlap hoặc lỗi kết nối có kết quả commit chưa xác định.
- Approved leave và sửa ca khóa cùng Staff row. Nếu booking thắng trước duyệt
  nghỉ, giữ lịch đã đặt; nếu duyệt thắng trước, booking bị chặn. Không tự hủy lịch.
- Giá trả string; tổng tiền/tên dịch vụ snapshot giữ nguyên khi catalog đổi.
- Booking mới confirmed. Cancel chỉ pending/confirmed; complete/noShow chỉ
  confirmed. Lịch kết thúc không mở lại; sai transition trả 409. Thời điểm thao tác
  complete/noShow hiện theo hành động vận hành, chưa áp hạn chế theo giờ kết thúc.
- Không có reschedule, gửi review hoặc tính giảm giá.

## Test chống double-booking

```bash
npm test
node test-phase4-live.cjs
```

Script tạo Staff/Service/Shift tạm bằng API, bắn hai POST cùng slot bằng
Promise.all, kiểm tra **201 + 409** và **đúng 1 row** trong database. Test thêm
ca nghỉ giữa buổi, đa dịch vụ, lịch liền kề, EXCLUDE 23P01, rollback lịch thiếu
items, scope/ownership/state, approved leave và race, BIGINT, catalog/chuyên môn
stale, hai cờ ẩn độc lập. Fixture được dọn trong finally transaction; seed giữ nguyên.

Kết quả 07/10/2026: build +20 tests local pass, live Phase4 PASS; hai request
201/409, đúng1 row, leave race trong lần test này trả409 cho booking.
Hồi quy Phase2/3 chạy song song pass. Branch DELETE khóa settings trước Branch
để cùng quy ước với calendar writers. Server directory/slots/ledger HTTP200,
70 ca seed vẫn còn. Đã sửa DATE[] hydration để ngày nghỉ cụ thể có hiệu lực.

Kiểm tra server hiện đang chạy: `node test-phase4-live.cjs --verify-server`.

Nguồn quy ước khóa:
[PostgreSQL row locks](https://www.postgresql.org/docs/current/explicit-locking.html),
[TypeORM transactions](https://typeorm.io/docs/advanced-topics/transactions/).
