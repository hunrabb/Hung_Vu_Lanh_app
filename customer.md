# Customer

## 1. Giới thiệu

Customer là đối tượng đại diện cho khách hàng trong ứng dụng
Schedula. Đối tượng này được sử dụng để lưu trữ và quản lý
thông tin của khách hàng khi khách hàng sử dụng dịch vụ và đặt lịch.

---

## 2. Các thuộc tính

| Thuộc tính | Kiểu dữ liệu | Mô tả |
|---|---|---|
| id | int | Mã định danh của khách hàng |
| fullName | String | Họ và tên khách hàng |
| phone | String | Số điện thoại của khách hàng |
| email | String | Địa chỉ email của khách hàng |
| address | String | Địa chỉ của khách hàng |
| note | String | Ghi chú liên quan đến khách hàng |

---
## 3. Phương thức 
| Phương thức | Kiểu trả về | Mô tả |
|---|---|---|
| updateInfo() | void | Cập nhật thông tin khách hàng |
## 4. Constructor

Class Customer sử dụng constructor để khởi tạo một đối tượng
khách hàng với các thông tin cần thiết.

```dart
Customer({
  required this.id,
  required this.fullName,
  required this.phone,
  required this.email,
  required this.address,
  required this.note,
});

