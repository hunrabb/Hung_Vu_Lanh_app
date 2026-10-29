# ✂️ Ứng dụng Đặt lịch & Quản lý Chuỗi Spa/Barbershop

Ứng dụng di động toàn diện giúp khách hàng tìm dịch vụ, chọn thợ và đặt lịch thuận tiện. Đồng thời, hệ thống cung cấp không gian vận hành theo từng chi nhánh, quản lý nhân sự và báo cáo doanh thu chặt chẽ cho Quản lý cơ sở và Chủ chuỗi.

> Dự án gồm ứng dụng Flutter tại thư mục gốc và RESTful API NestJS trong thư mục `backend/`.

## 📑 Mục lục

- [Tính năng nổi bật](#-tính-năng-nổi-bật)
- [Vai trò và phạm vi dữ liệu](#-vai-trò-và-phạm-vi-dữ-liệu)
- [Công nghệ sử dụng](#-công-nghệ-sử-dụng)
- [Cấu trúc dự án](#-cấu-trúc-dự-án)
- [Yêu cầu môi trường](#-yêu-cầu-môi-trường)
- [Cài đặt và khởi chạy](#-cài-đặt-và-khởi-chạy)
- [Kiểm thử](#-kiểm-thử)
- [Quy trình làm việc nhóm](#-quy-trình-làm-việc-nhóm)
- [Quy tắc bảo mật](#-quy-tắc-bảo-mật)

## 🌟 Tính năng nổi bật

### 🔐 Xác thực và phân quyền đa tầng

- Bốn vai trò: **Boss**, **Manager**, **Staff** và **Customer**.
- JWT được kiểm tra cùng trạng thái tài khoản, vai trò, chi nhánh và `tokenVersion` trong cơ sở dữ liệu.
- Manager chỉ được truy cập dữ liệu thuộc chi nhánh mình quản lý; Boss có phạm vi toàn chuỗi.
- Staff mới do Manager tạo phải được Boss duyệt và cấp mật khẩu trước khi đăng nhập.

### 📅 Booking Engine thông minh

- Customer chọn chi nhánh, dịch vụ, thợ phù hợp chuyên môn, ngày và khung giờ trống.
- Slot được tính từ giờ mở cửa, ca làm việc, ngày nghỉ, đơn nghỉ phép và các lịch hiện có.
- Tự động ẩn giờ trong quá khứ và chỉ cho phép dịch vụ nằm trọn trong một ca làm việc.
- Chống đặt trùng bằng transaction Firestore và kiểm tra xung đột tại backend.
- Hỗ trợ lịch khách hàng và lịch **Walk-in** do Manager tạo tại cửa hàng.

### 📊 Dashboard và báo cáo

- Doanh thu ngày/tháng và số lịch theo trạng thái.
- Sổ cái lịch hẹn toàn chuỗi, có bộ lọc theo cơ sở, thời gian và trạng thái.
- Bảng xếp hạng doanh thu cơ sở và hiệu suất Staff.
- Tạm tính hoa hồng Staff từ các lịch `completed`.
- Báo cáo cá nhân cho Staff: số ca, khách hàng và doanh số.
- Dữ liệu tiền VNĐ được giữ chính xác bằng `BIGINT`/chuỗi, tránh sai số số thực.

### 👥 Quản lý nhân sự và cơ sở

- CRUD chi nhánh và catalog dịch vụ dùng chung toàn chuỗi.
- Manager tạo hồ sơ Staff chờ duyệt; Boss duyệt hoặc từ chối.
- Quản lý ca làm việc và đơn xin nghỉ theo đúng chi nhánh.
- Theo dõi lịch hẹn với các trạng thái `pending`, `confirmed`, `completed`, `cancelled` và `noShow`.
- Bảo vệ lịch khách đã đặt khi sửa hoặc xóa ca làm việc.

## 🧭 Vai trò và phạm vi dữ liệu

| Vai trò | Phạm vi chính |
| --- | --- |
| **Boss** | Toàn chuỗi, chi nhánh, catalog, phê duyệt Staff, sổ cái và hoa hồng |
| **Manager** | Nhân sự, lịch hẹn, cấu hình và doanh thu của một chi nhánh |
| **Staff** | Ca làm, lịch được giao, khách hàng và doanh số cá nhân |
| **Customer** | Chọn chi nhánh, đặt/hủy lịch và xem lịch sử cá nhân |

## 🛠 Công nghệ sử dụng

### Mobile

- **Flutter** và **Dart**
- **Provider / ChangeNotifier** cho state management
- Package `http` để gọi RESTful API
- `flutter_secure_storage` để lưu JWT trên thiết bị
- Kiến trúc feature-first trong `lib/features/`

### Backend

- **NestJS** và **TypeScript**
- RESTful API với JWT, Passport và bcrypt
- **Cloud Firestore** qua Firebase Admin SDK
- Transaction và kiểm tra quyền/xung đột tại server
- Schema document: `backend/FIRESTORE_NOSQL_SCHEMA.md`

## 🗂 Cấu trúc dự án

```text
.
├── lib/                    # Ứng dụng Flutter
│   ├── core/               # Models, network, routing, security
│   ├── features/           # Auth, Booking, Boss, Manager, Staff...
│   └── shared/             # Widgets dùng chung
├── test/                   # Unit và widget tests Flutter
├── backend/                # NestJS RESTful API
│   ├── src/                # Modules, controllers, services, entities
│   └── test/               # Backend tests
├── .vscode/launch.example.json
└── pubspec.yaml
```

## ✅ Yêu cầu môi trường

- Flutter SDK tương thích Dart `^3.13.1`
- Android Studio hoặc VS Code có Flutter/Dart extensions
- Node.js `>= 22.12.0`
- Firebase project có Cloud Firestore
- Quyền truy cập backend qua Google ADC hoặc service account ngoài repository

Kiểm tra môi trường Flutter:

```bash
flutter doctor
```

## 🚀 Cài đặt và khởi chạy

### Bước 1 — Clone repository

```bash
git clone https://github.com/hunrabb/Hung_Vu_Lanh_app.git
cd Hung_Vu_Lanh_app
```

### Bước 2 — Cài đặt Backend

```bash
cd backend
npm install
```

Tạo file môi trường từ template:

```powershell
# Windows PowerShell
Copy-Item .env.example .env
```

```bash
# macOS/Linux
cp .env.example .env
```

Cập nhật `backend/.env` theo Firebase project và thông tin xác thực của máy bạn:

```dotenv
FIREBASE_PROJECT_ID=mobileapp-db88e
FIRESTORE_DATABASE_ID=(default)
GOOGLE_APPLICATION_CREDENTIALS=C:/path/outside/repository/service-account.json
PORT=3000
JWT_SECRET=replace_with_a_random_secret_of_at_least_32_characters
JWT_TTL_SECONDS=1800
```

Khởi chạy API ở chế độ phát triển:

```bash
npm run start:dev
```

Kiểm tra API:

```text
GET http://localhost:3000/api/branches
```

> Xem [hướng dẫn Firestore](backend/FIRESTORE_RUNTIME.md) để cấu hình, kiểm thử và triển khai.

### Bước 3 — Cài đặt Frontend Flutter

Mở terminal mới và quay lại thư mục gốc repository:

```bash
cd ..
flutter pub get
```

### Bước 4 — Cấu hình mạng

Copy file launch template:

```powershell
# Windows PowerShell, chạy tại thư mục gốc repository
Copy-Item .vscode/launch.example.json .vscode/launch.json
```

```bash
# macOS/Linux
cp .vscode/launch.example.json .vscode/launch.json
```

Chọn cấu hình phù hợp:

- **Android Emulator:** dùng `http://10.0.2.2:3000/api`.
- **Điện thoại qua USB:** dùng `http://localhost:3000/api`, sau đó tạo tunnel:

  ```bash
  adb reverse tcp:3000 tcp:3000
  ```

- **Điện thoại qua Wi-Fi:** thay `[ĐIỀN_IP_CỦA_BẠN]` trong `launch.json` bằng IPv4 cục bộ của máy chạy backend, ví dụ `192.168.1.10`. Điện thoại và máy tính phải cùng mạng.

Trên Windows, xem IPv4 bằng:

```powershell
ipconfig
```

### Bước 5 — Chạy ứng dụng

1. Khởi động Android Emulator hoặc kết nối thiết bị.
2. Đảm bảo NestJS đang chạy tại cổng `3000`.
3. Chọn profile phù hợp trong **Run and Debug** của VS Code.
4. Nhấn `F5`.

Có thể chạy trực tiếp bằng terminal:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

## 🧪 Kiểm thử

Kiểm tra Flutter:

```bash
flutter analyze --no-pub
flutter test --no-pub
```

Kiểm tra Backend:

```bash
cd backend
npm test
```

Live test Firestore: `npm run test:firestore:live` trong `backend/`. Test tạo namespace riêng và dọn dữ liệu sau khi chạy.

## 🤝 Quy trình làm việc nhóm

Không code trực tiếp trên `main`. Mỗi task cần một branch riêng và một Pull Request.

### 1. Đồng bộ code mới nhất

```bash
git checkout main
git pull origin main
```

### 2. Tạo branch theo task

```bash
git checkout -b feature/ui-skeleton
```

Quy ước tên branch gợi ý:

- `feature/...` — tính năng mới
- `fix/...` — sửa lỗi
- `refactor/...` — cải tổ code không đổi nghiệp vụ
- `docs/...` — tài liệu
- `test/...` — kiểm thử

### 3. Commit thay đổi

```bash
git add .
git commit -m "feat: add booking slot selector"
```

Ưu tiên Conventional Commits: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.

### 4. Push branch và tạo Pull Request

```bash
git push -u origin feature/ui-skeleton
```

Tạo Pull Request vào `main`, mô tả thay đổi, kết quả test và ảnh UI nếu có. Ít nhất một thành viên khác review trước khi merge.

## 🔒 Quy tắc bảo mật

- Không commit `.env`, service account JSON, JWT secret hoặc signing keys.
- Không sửa `.gitignore` để đưa credential lên repository.
- Dùng `.env.example` và `.vscode/launch.example.json` làm template.
- Flutter truy cập dữ liệu qua NestJS API; Firebase Admin credentials chỉ ở backend.
- Nếu credential từng bị push, phải thu hồi/đổi ngay; xóa file khỏi commit mới không xóa bí mật khỏi lịch sử Git.

---

📌 Tài liệu kiến trúc và tiến độ chi tiết: `PROJECT_CONTEXT.md`, `BACKEND_ROADMAP.md` và `CHAIN_IMPLEMENTATION_PLAN.md`.
