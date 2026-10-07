# AuthModule — Postman/cURL

Base URL: `http://localhost:3000/api`. JWT access token 1800 giây, không refresh.
Register/Login public; các route khác cần `Authorization: Bearer <accessToken>`.
Sau đổi mật khẩu/logout, mọi token của tài khoản bị thu hồi; đăng nhập lại.

| Method/path | Body | Kết quả |
| --- | --- | --- |
| POST /auth/register | name, email, password | 201 Customer + accessToken |
| POST /auth/login | email, password | 200 accessToken + user |
| GET /auth/me | Không | 200 profile hiện tại |
| PATCH /auth/password | oldPassword, newPassword | 200, token cũ 401 |
| POST /auth/logout | Không | 200, mọi token cũ 401 |
| GET /users/pending | Boss token | 200, 5 pending seed |
| GET /users/branch/branch-01 | Boss/Manager cơ sở1 | 200 |

Postman: Body → raw → JSON; login sample:

```json
{"email":"boss@example.com","password":"boss123"}
```

Copy `accessToken` sang Authorization → Bearer Token. Không thêm role/branchId
vào Register: DTO sẽ trả400. Password mới ít nhất8 ký tự, không NUL, tối đa72
byte UTF-8, khác password cũ; login seed ngắn vẫn được hỗ trợ.

cURL (bash):

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"boss@example.com","password":"boss123"}'
curl http://localhost:3000/api/users/pending \
  -H 'Authorization: Bearer <accessToken>'
```

PowerShell:

```powershell
$login = Invoke-RestMethod -Uri 'http://localhost:3000/api/auth/login' -Method Post -ContentType 'application/json' -Body (@{email='boss@example.com';password='boss123'} | ConvertTo-Json)
$headers = @{Authorization = "Bearer $($login.accessToken)"}
Invoke-RestMethod -Uri 'http://localhost:3000/api/auth/me' -Headers $headers
Invoke-RestMethod -Uri 'http://localhost:3000/api/users/pending' -Headers $headers
```

Test roles: Boss boss@example.com/boss123; Manager admin@example.com/admin123
(branch-01); manager2@example.com/manager123 (branch-02); Staff
staff@exampler.com/staff123; Customer customer@example.com/customer123.
Pending pending@example.com không có credential → login401.
Manager pending403; Manager1 truy cập branch-02 nhận403; thiếu token401.

`npm test`: build + tests local. `node test-auth-live.cjs`: test Aiven thật,
đăng nhập/migrate 18 seed, tạo một Customer thử rồi xóa đúng Customer đó,
test password/logout/revocation và tenant boundaries; không in tokens/hashes.
Seed password nào đã đổi phải cập nhật test fixture thay vì reset người dùng.

DDL được phê duyệt ở database/004_auth_and_shift_scope.sql đã chạy trên Aiven;
không có schema synchronization. JWT_SECRET được tạo ngẫu nhiên trong .env,
không ghi vào Git. Mật khẩu/hash/JWT không thuộc response profile hoặc log.
Login/register rate limit20 request/phút/IP trong RAM, phạm vi một instance.
Giai đoạn2 (Boss approve/reject) chưa triển khai; AuthModule không tự duyệt Staff.
