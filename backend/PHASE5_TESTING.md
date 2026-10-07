# Giai đoạn 5 — Dashboard và báo cáo

ReportsModule không thêm bảng/cột/migration/package. Giữ `synchronize: false`,
SSL CA. Flutter chưa nối API. Tất cả endpoint bên dưới yêu cầu Bearer JWT.

| API | Quyền và nội dung |
| --- | --- |
| GET /api/manager/dashboard | Manager; branch phiên; today/month metrics, lịch sắp tới hôm nay |
| GET /api/manager/revenue?from=2026-10-01&to=2026-10-07 | Manager; tổng kỳ, completed transactions và staffRanking tại cơ sở |
| GET /api/boss/dashboard?branchId=branch-01 | Boss; bỏ branchId để xem toàn chuỗi; today/month metrics |
| GET /api/boss/leaderboards | Boss; Branch theo doanh thu, Staff theo completed count |
| GET /api/boss/appointments | Boss; sổ lịch có tên thợ/cơ sở/dịch vụ snapshot |
| GET /api/boss/commissions | Boss; 30% tổng completed revenue, làm tròn xuống nguyên VNĐ |
| GET /api/staff/me/earnings | Staff; doanh số hôm nay/tháng này và completed transactions |
| GET /api/staff/me/profile-stats | Staff; số completed tháng, reviews và thống kê khách hàng/LTV |

Manager không được truyền branchId vào revenue; Staff không được truyền staffId
hoặc branchId. DTO từ chối scope injection. Dashboard Manager luôn dùng cơ sở phiên,
bỏ qua query chọn cơ sở. Phân quyền kiểm tra cả Guards và ReportsService.

## Ngày, query và response

- `from`, `to` là **ngày Hà Nội YYYY-MM-DD**, bao gồm cả hai ngày.
  Ví dụ from=to=2026-10-07 → UTC `[2026-10-06T17:00Z,2026-10-07T17:00Z)`.
  Phải gửi đủ cặp, đúng lịch và từ≤đến; mỗi kỳ tối đa366 ngày.
- Revenue/leaderboards/ledger/commissions mặc định tháng hiện tại. Dashboard luôn
  dùng hôm nay/tháng này. Earnings today/month cố định; from/to chỉ đổi ledger.
  Profile-stats luôn dùng tháng hiện tại và thống kê khách hàng toàn lịch sử.
- Boss thêm branchId cho mọi báo cáo. `status` chỉ áp dụng ở boss/appointments.
- `page` mặc định1, `limit` mặc định50, tối đa100 cho danh sách giao dịch/khách hàng/
  commissions. Leaderboards lấy top theo limit; ranking Manager tối đa100 Staff.
- Tổng số liệu tính toàn kỳ, không chỉ trang danh sách đang xem.
- Tiền gồm revenueVnd, totalPriceVnd, totalSpentVnd, commissionVnd đều **string**.
  Số ca/khách hàng là number; averageRating number hoặc null nếu chưa có reviews.

Ví dụ dashboard:

```json
{
  "branchId": "branch-01",
  "timezone": "Asia/Ho_Chi_Minh",
  "today": {
    "revenueVnd": "130000",
    "appointmentCount": 3,
    "completedCount": 1,
    "cancelledCount": 1
  },
  "month": {},
  "upcoming": []
}
```

Response thực tế còn có periods với bounds UTC. Upcoming pending/confirmed của
hôm nay, endAt còn phía trước, sắp xếp tăng dần startAt, tối đa100. Ledger trả
branchName/staffName/customerName/services và startAt/endAt UTC.

Hoa hồng là **tạm tính**, floor(tổng doanh thu ×30/100), chưa chi trả và không
biến Staff earnings thành lương thực nhận. Staff earnings trả doanh số dịch vụ.
Ranking/commission toàn chuỗi có một hàng mỗi Staff ID, kèm mảng branches nơi đã
phục vụ; thợ chuyển cơ sở không bị tách thành nhiều hàng. Lịch sử vẫn giữ branch_id.

Profile-stats: monthly metrics; reviewCount/averageRating từ completed reviewed;
registeredCustomerCount, walkInCompletedCount và customers phân trang với
completedVisits/totalSpentVnd/lastVisitAt. Không gộp các walk-in NULL thành một khách.

## Quy tắc tính toán

- Revenue, ranking, commission, LTV chỉ lấy completed và kỳ theo **start_at**.
- Không lọc cờ hidden; ẩn lịch không làm giảm doanh thu/ca/reviews/LTV.
- SUM từ nguồn một dòng mỗi appointment. Service items chỉ làm JSON subquery khi
  dựng ledger; không JOIN nhiều service rows vào SUM.
- Aggregate BIGINT ở PostgreSQL thành numeric, cast text trước JSON; không đưa
  tiền qua JavaScript Number. Commission tính trên tổng rồi làm tròn một lần.
- Mỗi response đọc trong transaction REPEATABLE READ để chỉ số và ledger đồng bộ.
- Không lưu bảng revenue/commission/customer metrics. Không sửa timestamp trong WHERE;
  tính bounds UTC rồi dùng index thời gian có sẵn.

## Test

```bash
npm test
node test-phase5-live.cjs
node test-phase5-live.cjs --verify-server
```

Script live tạo Staff/appointments tạm, mỗi lịch có hai dịch vụ; kiểm tra UTC+7,
completed-only, số lớn hơn Number.MAX_SAFE_INTEGER, 30% chính xác, tenant/role/
identity, soft-hidden, walk-in, reviews/LTV, Staff chuyển cơ sở. Finally transaction
dọn đúng ID fixture, không sửa seed. Chế độ verify-server kiểm tra API cổng3000.

**Kết quả 07/10/2026:** build +23 tests pass; live Aiven PASS, bao gồm Staff
chuyển cơ sở và tổng tiền9007199254821195 không mất chính xác. Cả8 API server
localhost:3000 trả200; fixtures Users/Appointments đều0, seed70 ca còn nguyên.
