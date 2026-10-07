import '../../../core/models/app_user.dart';
import '../../users/data/mock_user_repository.dart';

// Chỉ dùng để thử nghiệm, không dùng để lưu mật khẩu thực tế.
class MockAuthRepository {
  MockAuthRepository({this.users});
  final MockUserRepository? users;
  // Mỗi repository giữ danh sách riêng, tồn tại trong phiên chạy ứng dụng.
  final _accounts = List<_MockAccount>.of(_sampleAccounts);
  int _nextUserId = 4;

  static final _sampleAccounts = [
    for (final entry in {
      'customer-01': 'customer123',
      'staff-01': 'staff123',
      'admin-01': 'admin123',
      'boss-01': 'boss123',
      'manager-02': 'manager123',
      'staff-05': 'staff123',
    }.entries)
      _MockAccount(
        user: MockUserRepository().getById(entry.key)!,
        password: entry.value,
      ),
  ];

  // Chuẩn hóa email như đăng nhập để tránh tạo tài khoản trùng khác chữ hoa.
  AppUser register({
    required String name,
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (_accounts.any((account) => account.user.email == normalizedEmail) ||
        (users?.getAll().any((user) => user.email == normalizedEmail) ??
            false)) {
      throw const MockAuthException('Email đã được sử dụng');
    }
    if (name.trim().isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedEmail) ||
        password.trim().isEmpty) {
      throw const MockAuthException('Vui lòng nhập đầy đủ thông tin hợp lệ.');
    }

    // Tài khoản tự đăng ký luôn là Customer, không cho chọn quyền Staff/Admin.
    final user = AppUser(
      id: 'user-${_nextUserId++}',
      name: name.trim(),
      email: normalizedEmail,
      role: UserRole.customer,
      createdAt: DateTime.now().toUtc(),
    );
    users?.add(user);
    _accounts.add(_MockAccount(user: user, password: password));
    return user;
  }

  // Trả về người dùng nếu đúng tài khoản; trả về null nếu sai.
  AppUser? signIn({required String email, required String password}) {
    // Bỏ khoảng trắng đầu/cuối và không phân biệt chữ hoa/thường của email.
    final normalizedEmail = email.trim().toLowerCase();

    for (final account in _accounts) {
      // Mật khẩu phải khớp chính xác, có phân biệt chữ hoa/thường.
      if (account.user.email == normalizedEmail &&
          account.password == password) {
        final user = users == null
            ? account.user
            : users!.getById(account.user.id);
        if (user?.role == UserRole.staff && user?.isApproved != true) {
          return null;
        }
        return user;
      }
    }

    return null;
  }

  void validateAccount(AppUser user, String password) {
    if (password.trim().isEmpty) throw ArgumentError('Password is required.');
    if (_accounts.any(
          (account) =>
              account.user.id == user.id ||
              account.user.email == user.email.trim().toLowerCase(),
        ) ||
        (users?.getAll().any(
              (other) =>
                  other.id != user.id &&
                  other.email == user.email.trim().toLowerCase(),
            ) ??
            false)) {
      throw StateError('Email đã được sử dụng.');
    }
  }

  bool hasCredentials(String id) => _accounts.any((a) => a.user.id == id);

  void changePassword(String userId, String oldPassword, String newPassword) {
    final index = _accounts.indexWhere((a) => a.user.id == userId);
    if (index < 0 || _accounts[index].password != oldPassword) {
      throw StateError('Mật khẩu cũ không đúng.');
    }
    if (newPassword.trim().isEmpty || newPassword == oldPassword) {
      throw ArgumentError(
        'Mật khẩu mới phải khác mật khẩu cũ và không để trống.',
      );
    }
    _accounts[index] = _MockAccount(
      user: _accounts[index].user,
      password: newPassword,
    );
  }

  /// Roll back an allocation without deleting the recruitment profile.
  void revokeCredentialsOnly(String id) {
    _accounts.removeWhere((a) => a.user.id == id);
  }

  void addStaffCredentials(AppUser user, String password) {
    if (user.role != UserRole.staff) {
      throw ArgumentError('Staff role required.');
    }
    validateAccount(user, password);
    if (users != null && users!.getById(user.id) == null) users!.add(user);
    _accounts.add(_MockAccount(user: user, password: password));
  }

  void validateProfileUpdate(AppUser user) {
    if (_accounts.any(
          (account) =>
              account.user.id != user.id &&
              account.user.email == user.email.trim().toLowerCase(),
        ) ||
        (users?.getAll().any(
              (other) =>
                  other.id != user.id &&
                  other.email == user.email.trim().toLowerCase(),
            ) ??
            false)) {
      throw StateError('Email đã được sử dụng.');
    }
  }

  void updateProfile(AppUser user) {
    final index = _accounts.indexWhere((account) => account.user.id == user.id);
    if (index >= 0) {
      if (users?.getById(user.id) != null) users!.update(user);
      _accounts[index] = _MockAccount(
        user: user,
        password: _accounts[index].password,
      );
    }
  }

  void removeCredentials(String id) {
    _accounts.removeWhere((account) => account.user.id == id);
    if (users?.getById(id) != null) users!.delete(id);
  }
}

// Lỗi nghiệp vụ có thông báo để controller hiển thị cho người dùng.
class MockAuthException implements Exception {
  const MockAuthException(this.message);
  final String message;
}

// Giữ mật khẩu giả lập riêng, không thêm mật khẩu vào model AppUser.
// Dấu "_" giới hạn lớp này trong file thư viện hiện tại.
class _MockAccount {
  const _MockAccount({required this.user, required this.password});

  final AppUser user;
  final String password;
}
