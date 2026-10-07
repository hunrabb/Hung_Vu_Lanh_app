# Giai đoạn 3 — Ca làm và nghỉ phép

Backend giữ `synchronize: false`, SSL xác minh CA. Migration thủ công:
`node migrate-phase3.cjs` (database/005_leave_intervals.sql, sau migration 004).
Migration chuyển ngày nghỉ cũ thành cả ngày Hà Nội, giữ nguyên lịch sử quyết định.

## API và quyền

| API | Quyền |
| --- | --- |
| GET/POST /api/branches/:branchId/shifts | Boss hoặc Manager đúng cơ sở |
| PATCH/DELETE /api/shifts/:id | Boss hoặc Manager đúng cơ sở |
| GET /api/staff/me/shifts | Staff, chỉ ca của mình tại cơ sở hiện tại |
| POST/GET /api/staff/me/leave-requests | Staff, chỉ đơn của mình |
| GET /api/leave-requests | Boss toàn chuỗi, Manager đúng cơ sở |
| POST /api/leave-requests/:id/decision | Boss hoặc Manager đúng cơ sở |
| PATCH /api/branches/:branchId/settings | Boss hoặc Manager đúng cơ sở; giữ API giai đoạn 2 |

Đăng nhập qua POST `/api/auth/login`; dùng `accessToken` trong header
`Authorization: Bearer <token>`. Manager Cầu Giấy: admin@example.com / admin123;
Staff: staff@exampler.com / staff123; Boss: boss@example.com / boss123.

## Ví dụ Postman/cURL

```bash
curl -X POST http://localhost:3000/api/branches/branch-01/shifts \
  -H 'Authorization: Bearer <MANAGER_TOKEN>' -H 'Content-Type: application/json' \
  -d '{"staffId":"staff-01","startAt":"2026-10-20T08:00:00+07:00","endAt":"2026-10-20T20:00:00+07:00"}'

curl -X POST http://localhost:3000/api/staff/me/leave-requests \
  -H 'Authorization: Bearer <STAFF_TOKEN>' -H 'Content-Type: application/json' \
  -d '{"startAt":"2026-10-21T08:00:00+07:00","endAt":"2026-10-21T12:00:00+07:00","reason":"Khám bệnh"}'

curl -X POST http://localhost:3000/api/leave-requests/<REQUEST_ID>/decision \
  -H 'Authorization: Bearer <MANAGER_OR_BOSS_TOKEN>' -H 'Content-Type: application/json' \
  -d '{"status":"approved","note":"Đã xác nhận"}'
```

Có thể dùng `status: rejected`. ID Staff phải lấy từ API Users hoặc Auth/me,
không giả định ID seed nếu đã đổi dữ liệu. Timestamp bắt buộc có Z hoặc offset;
endAt > startAt, mỗi khoảng tối đa 31 ngày. Đơn nghỉ bắt đầu từ hôm nay theo Hà Nội,
endAt phải còn trong tương lai, lý do bắt buộc. Client không gửi role, branchId,
staffId hay người duyệt khi xin nghỉ. Shift PATCH chỉ nhận startAt/endAt.

## Rào chắn dữ liệu

- Chỉ Staff đã duyệt cùng cơ sở được gán ca. Ca chồng nhau bị 409; liền kề hợp lệ.
- Sửa/xóa bất kỳ ca có lịch pending/confirmed/completed giao khoảng cũ trả 409.
  Chính sách bảo thủ: kể cả kéo dài ca đang có khách cũng phải chờ nghiệp vụ sau.
- Khóa transaction theo settings → Staff → shift/leave; xác thực lại phiên khi ghi.
- Đơn pending/approved không được chồng nhau (DB EXCLUDE); rejected không giữ chỗ.
- Quyết định chỉ một lần; DB tự ghi reviewedBy, reviewedByName,
  reviewedBranchName, reviewedAt. Sửa lại trả 409 ở API và bị trigger chặn tại DB.
- Approved nghỉ chặn **booking mới** qua query approvedOverlaps cho Giai đoạn 4;
  không tự hủy lịch khách đã có. Booking Engine chưa triển khai trong giai đoạn này.
- Không có endpoint sửa/xóa lịch sử quyết định.

## Seed và kiểm thử

`node seed-staff-shifts.cjs`: tạo ca 7 ngày tới cho Staff approved theo giờ cửa hàng,
bỏ ngày nghỉ; chạy lại không ghi đè ca đang có hoặc tạo ca giao nhau.

`npm test`: build và test local. `node test-phase3-live.cjs`: test Aiven với dữ liệu
tạm, kiểm tra scope, xung đột ca, lịch khách, duyệt đồng thời, snapshot và immutable.
Dữ liệu test được dọn bằng transaction, không xóa seed. `node test-phase2-live.cjs`
kiểm tra hồi quy onboarding/CRUD.
