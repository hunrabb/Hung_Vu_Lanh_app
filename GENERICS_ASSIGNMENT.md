# Bài thực hành Generics trong ứng dụng Barbershop & Spa

## Câu 1 — Entities: thuộc tính chung, phương thức chung và kế thừa

Mã lớp cha: `lib/core/models/base_entity.dart`.

```dart
abstract class BaseEntity<Id> {
  const BaseEntity({required this.id});
  final Id id;

  bool hasSameIdentity(BaseEntity<Id> other) =>
      runtimeType == other.runtimeType && id == other.id;

  Map<String, dynamic> toJson() => {'id': id};
}

abstract class NamedEntity<Id> extends BaseEntity<Id> {
  const NamedEntity({
    required super.id,
    required this.name,
    this.description = '',
  });

  final String name;
  final String description;

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    return name.toLowerCase().contains(normalized) ||
        description.toLowerCase().contains(normalized);
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'name': name,
    if (description.isNotEmpty) 'description': description,
  };
}
```

`Id` là tham số kiểu dữ liệu: có thể là `String`, `int` hoặc kiểu khác.
Ứng dụng dùng ID chuỗi nên các model cụ thể kế thừa với `<String>`.

Ví dụ thật trong `lib/core/models/branch.dart`:

```dart
class Branch extends NamedEntity<String> {
  const Branch({
    required super.id,
    required super.name,
    super.description,
    required this.address,
    required this.phone,
  });
  final String address, phone;
  // fromJson, toJson và copyWith bổ sung các trường riêng của Branch.
}
```

| Lớp con | Lớp cha | Đặc điểm kế thừa |
|---|---|---|
| `AppUser`, `Service`, `Branch` | `NamedEntity<String>` | `id`, `name`, `description`, `hasSameIdentity`, `matchesQuery`, phần JSON chung |
| `Promotion` | `NamedEntity<String>` | Tên/miêu tả ánh xạ từ `title`/`subtitle`; JSON vẫn dùng các khóa cũ |
| `Appointment`, `StaffShift`, `ShopSettings` | `BaseEntity<String>` | `id`, kiểm tra định danh và phần JSON chung |
| `LeaveRequest`, `Conversation`, `ChatMessage` | `BaseEntity<String>` | `id`, kiểm tra định danh; ghi đè JSON với dữ liệu riêng |

Các model không có tên/miêu tả trong nghiệp vụ chỉ kế thừa `BaseEntity`.
`TimeSlot` là khoảng thời gian, không có ID nên vẫn là value object riêng.

Ví dụ đa hình:

```dart
final List<NamedEntity<String>> entities = [service, branch, user];
final result = entities.where((entity) => entity.matchesQuery('wash'));
```

Các lớp con gọi `super.toJson()` để tái sử dụng trường chung. `copyWith` và
`fromJson` của AppUser/Service/Branch giữ lại `description`. Miêu tả mặc định
rỗng và được bỏ khỏi JSON khi rỗng, để dữ liệu cũ tiếp tục hoạt động.
Đây là thuộc tính model Dart; chưa bổ sung cột/API lưu miêu tả trên backend.
Các ràng buộc riêng về tiền nguyên, UTC, role và danh sách bất biến vẫn giữ nguyên.

## Câu 2 — Screens/Layouts: layout generic và kế thừa

Mã lớp cha: `lib/shared/widgets/entity_list_screen.dart`.

```dart
abstract class EntityListScreen<T extends BaseEntity<String>>
    extends StatelessWidget {
  const EntityListScreen({super.key});

  List<T> items(BuildContext context);
  Widget buildItem(BuildContext context, T item);
  // Các điểm tùy chỉnh: buildHeader, buildAppBar,
  // buildFloatingActionButton, listPadding, backgroundColor, useSafeArea.
  // build() ở lớp cha dựng Scaffold + DataList<T> dùng chung.
}
```

`T` là model của mỗi dòng. Giới hạn `extends BaseEntity<String>` đảm bảo
layout chỉ nhận model có định danh chuỗi. Lớp cha có `build()` hoàn chỉnh;
các màn hình con kế thừa cách dựng bố cục, ghi đè các phần đặc thù.

Hai trang thực tế đã chuyển đổi:

```dart
class ServiceCatalogScreen extends EntityListScreen<Service> { ... }
class BossBranchesScreen extends EntityListScreen<Branch> { ... }
```

| Trang | Dữ liệu | Phần ghi đè |
|---|---|---|
| `ServiceCatalogScreen` | `List<Service>` từ `ServiceProvider` | AppBar, số dịch vụ, thẻ dịch vụ, nút thêm theo quyền Boss |
| `BossBranchesScreen` | `List<Branch>` từ `BranchProvider` | Số cơ sở/trạng thái rỗng, thẻ cơ sở, nút thêm, padding/nền của workspace |

Các file:
- `lib/features/catalog/presentation/service_catalog_screen.dart`
- `lib/features/boss/presentation/boss_branches_screen.dart`
- `lib/shared/widgets/data_list.dart`

`DataList<T>` dựng danh sách theo model và callback vẽ item. `EntityListScreen<T>`
là lớp cha bố cục mà các trang **kế thừa bằng extends**. Như vậy có cả generic
widget dùng lại và generic layout được kế thừa, đúng hai khái niệm trong đề.
Các hộp thoại thêm/sửa/xóa, phân quyền, Provider và named routes vẫn giữ nguyên.

## Kiểm tra và trình bày

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Test mới `test/entity_inheritance_test.dart` kiểm tra ID khác kiểu, phân biệt
model cùng ID, tìm theo tên/miêu tả, giữ miêu tả khi sao chép/JSON và tương thích
JSON Promotion. Các test giao diện hiện có kiểm tra cập nhật danh sách và CRUD.

Khi trình bày: mở lớp cha entity → một model kế thừa → lớp cha layout → hai
màn hình kế thừa. Chỉ ra `Id`, `T`, `extends`, `super` và `@override`.

Tham khảo được giao: https://nglthu.github.io/flutter_docs/docs/generic_class
Link chưa truy cập được trong phiên triển khai; phần này dựa trên yêu cầu Câu 1,
Câu 2 người dùng cung cấp, không khẳng định trùng toàn bộ ví dụ trên trang học.

## Bổ sung — Hàm generic `<T>`

File `lib/core/utils/collection_utils.dart`:

```dart
T? findFirst<T>(Iterable<T> items, bool Function(T item) matches) {
  for (final item in items) {
    if (matches(item)) return item;
  }
  return null;
}
```

`<T>` được khai báo ngay sau tên hàm, nên đây là **hàm generic**.
Hàm nhận danh sách và điều kiện kiểu `T`, trả về `T?`. Không tìm thấy thì trả
`null`; tìm thấy thì dừng ngay, không duyệt tiếp phần tử phía sau.

Ví dụ với dữ liệu của ứng dụng:

```dart
final AppUser? user = findFirst<AppUser>(users, (user) => user.id == 'customer-01');
final Service? service = findFirst<Service>(services, (service) => service.id == 'service-01');
```

Hàm đang dùng thực tế trong `MemoryStore.getById`, từ đó phục vụ repository
người dùng/dịch vụ/cơ sở; `ApiAppointmentProvider` dùng hàm để tìm lịch hẹn và
tra tên cơ sở. Các kiểm tra phân quyền và phiên đăng nhập giữ nguyên.

Phân biệt: `MemoryStore<T, Id>` là lớp generic; `findFirst<T>` là hàm generic.
