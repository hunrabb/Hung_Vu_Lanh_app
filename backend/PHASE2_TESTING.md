# Giai đoạn2 — Onboarding và CRUD

Base URL `http://localhost:3000/api`. Đăng nhập `/auth/login`, dùng
`Authorization: Bearer <accessToken>` cho các request ghi. Postman Body raw JSON.

## Manager tạo → Boss duyệt → Staff đăng nhập

Manager admin@example.com/admin123: POST `/users/staff`:

```json
{"name":"Nguyễn Văn Hòa","email":"hoa.new@example.com","phone":"0901234567","address":"Hà Nội","specializedCategoryIds":["haircut","hairWash"]}
```

Response201 có id, role staff, branchId lấy từ Manager, isApproved=false;
không credential. Không gửi password/role/branchId/branch_id/isApproved, extra
fields sẽ400. PATCH `/users/staff/:id` cùng shape nhưng fields tùy chọn; Manager
cùng Branch mới được sửa, không thay role/Branch/approval. Empty/null update400.

Boss boss@example.com/boss123: POST `/users/<staffId>/approve`:

```json
{"password":"Staff123!"}
```

Response200 cùng ID, approved=true. Hash bcrypt cost12 ngoài transaction, khóa
Staff và INSERT credential + UPDATE approval cùng transaction. Hai request cạnh
tranh: một200, một409. Staff login hoa.new@example.com/Staff123! →200.

```bash
curl -X POST http://localhost:3000/api/users/staff \
  -H 'Authorization: Bearer <managerToken>' -H 'Content-Type: application/json' \
  -d '{"name":"Nguyễn Văn Hòa","email":"hoa.new@example.com","phone":"0901234567","address":"Hà Nội","specializedCategoryIds":["haircut","hairWash"]}'
curl -X POST http://localhost:3000/api/users/<staffId>/approve \
  -H 'Authorization: Bearer <bossToken>' -H 'Content-Type: application/json' \
  -d '{"password":"Staff123!"}'
```

DELETE `/users/:id/pending`: chỉ Boss, chỉ pending chưa credential/appointment/
shift/leave history. Thành công200, không lịch sử tuyển dụng; referenced/approved409.

## Catalog/cơ sở

GET branches/services/categories public. POST/PATCH/DELETE chỉ Boss; Service
kiểm tra lại profile/role/Branch/token_version trong transaction, không chỉ Guard.

| Route | Body |
| --- | --- |
| POST /branches; PATCH /branches/:id | name/address/phone |
| POST /services; PATCH /services/:id | name/categoryId/price/duration/isActive |
| POST /categories | id/name |
| PATCH /categories/:id | name |

POST201 không ghi đè ID đã có (409). UUID server cấp cho Branch/Service; Category
giữ đúng six enum IDs: haircut/perm/dye/hairWash/massage/shaving. CHECK DB đang
giới hạn six IDs đã seed: thêm ID mới cần migration/Flutter model riêng, không
sửa schema tự động. PATCH bỏ field chưa cung cấp; null không clear NOT NULL.

Price nhận safe integer hoặc chuỗi nguyên VND0..BIGINT max, response string;
duration1–1440 phút; isActive boolean. Phone8–15 chữ số, dấu + tùy chọn đầu chuỗi.
DELETE referenced trả409 (23503/23001); service đã dùng nên PATCH isActive=false.
Branch tạo có settings08:00–20:00; delete settings cùng transaction, rollback
nếu Branch còn nhân sự/lịch/shift/leave reference. Không xóa cascade lịch sử.

PATCH `/branches/:branchId/settings`: Boss hoặc Manager đúng Branch:

```json
{"openingMinute":480,"closingMinute":1200,"closedWeekdays":[7],"closedDates":["2030-01-02"]}
```

Opening<closing được kiểm tra với cấu hình hiện tại. Ngày thực yyyy-MM-dd,
weekdays1–7, không trùng. Đây là shop_settings; metadata name/address/phone Branch
thuộc PATCH /branches/:id chỉ Boss. Không tạo API shift/booking ở Giai đoạn2.

`npm test`: build/DTO/service permissions/read regression.
`node test-phase2-live.cjs`: Aiven test dùng record thử, kiểm tra concurrency,
login/rollback/tenant và cleanup đúng IDs tạo, khôi phục category label sau test.
Không thay approval/password của năm pending seed để giữ dữ liệu onboarding.
