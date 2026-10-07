# Flutter API — Phần 1: Network, Auth và Boss onboarding

Runtime mặc định sử dụng Auth API và PendingStaffProvider. Mock Auth chỉ dùng khi
test tạo `BarbershopApp(useMock: true)`; không fallback mock khi API lỗi.
Giữ Provider/ChangeNotifier và UI hiện có. Không sửa backend trong phần này.

## Chạy Android Emulator

Backend cần đang chạy cổng3000. Từ thư mục `ktgk`:

```powershell
& C:\flutter\bin\flutter.bat pub get
& C:\flutter\bin\flutter.bat devices
& C:\flutter\bin\flutter.bat run -d <emulator-id>
```

Dừng app cũ và chạy lại vì có plugin secure storage mới; hot reload không đủ.
Đăng nhập **boss@example.com / boss123** → Boss Dashboard → tab **Phê duyệt**.
Danh sách đọc `GET /users/pending`; cơ sở lấy tên từ `GET /branches` thật.

### Điện thoại Redmi nối USB (đã xác minh)

Nếu mở VSCode ở C:\learnFlutter: chọn Run and Debug → **ktgk - Redmi USB API**.
Nếu mở riêng folder ktgk: chọn **Flutter - Android USB (localhost API)**.
Stop phiên debug cũ rồi F5; preLaunchTask tự tạo lại adb reverse và kiểm tra API
cổng3000 trước khi launch. Không dùng profile Emulator cho điện thoại thật.
Khi terminal Analyzer sạch nhưng Problems vẫn hiện lỗi cũ, chọn
**Dart: Restart Analysis Server** sau khi lưu file. SDK workspace đã pin C:\flutter.

Không dùng10.0.2.2 trên điện thoại thật. Backend đã khởi động tại0.0.0.0:3000,
CORS bật, ADB reverse3000 đã tạo cho serial3abb8353. Login gọi trực tiếp từ điện
thoại qua USB trả HTTP200. Từ thư mục ktgk, stop phiên Flutter cũ rồi chạy:

```powershell
& C:\flutter\bin\flutter.bat run -d 3abb8353 --dart-define=API_BASE_URL=http://localhost:3000/api
```

Hot Restart không thay launch args/native Manifest; cần stop/run mới. Nếu rút USB
hoặc khởi động lại điện thoại, tạo lại tunnel bằng:

```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" -s 3abb8353 reverse tcp:3000 tcp:3000
```
Nhập mật khẩu cấp phát tối thiểu8 ký tự, tối đa72 bytes UTF-8 theo backend.
Duyệt gọi POST `/users/:id/approve`, refresh và bỏ hồ sơ đã duyệt. 409 thông báo
hồ sơ đã được xử lý và fetch lại. Từ chối cũng nối DELETE `/users/:id/pending`.

## Network/session

- Android mặc định `http://10.0.2.2:3000/api`; iOS/Web/Desktop dùng localhost.
- Có thể override bằng `--dart-define=API_BASE_URL=https://your-api.example/api`.
  Điện thoại thật cần địa chỉ máy chủ reachable; localhost/10.0.2.2 chỉ phục vụ
  các môi trường tương ứng, không tự dò LAN.
- Android có INTERNET permission và HTTP exception chỉ cho emulator/loopback;
  iOS ATS cho localhost. HTTP LAN cần cấu hình dev host riêng hoặc dùng HTTPS.
- Nest đã bật CORS trong đợt fix kết nối07/10/2026, listen IPv4 0.0.0.0 trên PORT.
- Điện thoại Redmi nối USB dùng adb reverse tcp:3000 tcp:3000, sau đó chạy app:
  `flutter run -d 3abb8353 --dart-define=API_BASE_URL=http://localhost:3000/api`.
  10.0.2.2 chỉ dùng Emulator; điện thoại thật không có alias này. Cắm lại USB
  cần tạo reverse lại. VSCode mở folder ktgk có hai profile USB/Emulator riêng.
  Manifest/define thay đổi cần stop và run lại, không chỉ Hot Restart.
- `http.Client` dùng chung, timeout, JSON errors. Mỗi request đọc secure token
  rồi thêm Bearer. Không log password/token; không retry tự động POST duyệt.
- `flutter_secure_storage` lưu accessToken; không lưu password, không refreshToken.
- Startup gọi auth/me xác thực token đã lưu. Logout xóa local ngay, gọi auth/logout
  để thu hồi server. Login kế tiếp chờ logout đang chạy, tránh token_version race.
- Protected401 clear session/token và xóa navigation stack, kể cả khi dialog mở.
  Login401 chỉ báo sai mật khẩu. 401 từ request của phiên cũ không logout phiên mới.
- Canceled/disposed login không lưu token; responses cũ không đưa pending data
  trở lại UI sau logout. Storage operations được tuần tự hóa.
- Role lấy từ profile do API trả: boss/superAdmin → superAdmin; manager/staff/customer
  giữ nguyên. Không tự chọn role hoặc suy đoán role từ email.

Tiền VND: `ApiMoney.bigInt` đọc string chính xác; `safeInt` chỉ chuyển khi trong
phạm vi số nguyên an toàn chung Android/Web. Các adapters tài chính nối ở phần sau.

## Phạm vi chưa chuyển API

Các dashboard metrics, catalog, booking, Staff workspace, Manager recruitment/
settings vẫn dùng Providers mock cũ. Không coi thao tác ở các tab này đã lưu Aiven.
Phần1 chỉ Auth (login/register/me/logout) và Boss pending/approve/reject. Các form
đổi mật khẩu/hồ sơ hiện có chưa chuyển API ở đợt này.

## Kiểm thử

```powershell
& C:\flutter\bin\flutter.bat analyze --no-pub
& C:\flutter\bin\flutter.bat test --no-pub
& C:\flutter\bin\flutter.bat test --no-pub --dart-define=RUN_LIVE_API_TEST=true test/api_live_test.dart
```

Unit/widget tests: base URLs, role aliases, VND BigInt, Bearer/persistence/restore,
login401, stale401, canceled login, approve409+refresh, UI approve và401 khi modal mở.
Live test chạy Flutter HTTP thật: Boss đọc hàng chờ → Manager tạo fixture → Boss
duyệt → Staff login. Chỉ duyệt fixture, giữ nguyên5 hồ sơ seed. Dọn fixture dùng
Node/pg với cấu hình backend riêng ở môi trường test, không đưa DB credential vào
Flutter runtime/APK. Test live mặc định skipped, chỉ bật khi chủ động chạy flag.

Sources: [http](https://pub.dev/packages/http),
[secure storage](https://pub.dev/packages/flutter_secure_storage),
[Android Emulator networking](https://developer.android.com/studio/run/emulator-networking).

**Kết quả:** analyzer sạch; 104 tests hồi quy pass, 1 test live mặc định skipped.
Live flag riêng đã pass toàn luồng onboarding và cleanup. APK debug đã build tại
`build/app/outputs/flutter-apk/app-debug.apk`. Chưa có Android Emulator đang chạy
trong session nên chưa thao tác trực tiếp trên máy ảo; đã test HTTP thật và build.
