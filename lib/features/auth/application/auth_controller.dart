import 'package:flutter/foundation.dart';

import 'dart:async';

import '../../../core/models/app_user.dart';
import '../../../core/network/api_client.dart';
import '../data/api_auth_repository.dart';

import '../data/mock_auth_repository.dart';
import '../../users/application/user_provider.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository, {this.apiRepository}) {
    _repository?.users?.addListener(_onProfilesChanged);
    apiRepository?.client.onUnauthorized = () => _clearSession(revoke: false);
  }
  void _onProfilesChanged() {
    if (_isDisposed || _currentUser == null) return;
    if (currentUser == null) {
      signOut();
      return;
    }
    notifyListeners();
  }

  final MockAuthRepository? _repository;
  final ApiAuthRepository? apiRepository;
  bool get isRemote => apiRepository != null;

  /// Internal account creation never replaces the Boss's current login session.
  AppUser createStaffAccount({
    required String email,
    required String password,
    required String name,
    required String branchId,
    List<String> specializedCategoryIds = const [],
    required UserProvider users,
  }) {
    if (_repository == null ||
        _isDisposed ||
        _isLoading ||
        currentUser?.role != UserRole.superAdmin) {
      throw StateError('Chỉ Boss đang đăng nhập được cấp tài khoản nhân viên.');
    }
    final base = 'staff-${DateTime.now().microsecondsSinceEpoch}';
    var id = base;
    var suffix = 0;
    while (users.getById(id) != null) {
      id = '$base-${++suffix}';
    }
    final user = AppUser(
      id: id,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      role: UserRole.staff,
      branchId: branchId,
      isApproved: true,
      createdAt: DateTime.now().toUtc(),
      specializedCategoryIds: specializedCategoryIds,
    );
    users.createStaff(user, password, actor: currentUser!, auth: _repository);
    return users.getById(id)!;
  }

  // null nghĩa là chưa đăng nhập; chỉ controller được thay đổi các trạng thái.
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Đánh dấu yêu cầu hiện tại để bỏ qua kết quả cũ sau đăng xuất/dispose.
  int _requestId = 0;
  bool _isDisposed = false;

  AppUser? get currentUser {
    final snapshot = _currentUser;
    if (snapshot == null) return null;
    final user = _repository?.users == null
        ? snapshot
        : _repository!.users!.getById(snapshot.id);
    if (user?.role == UserRole.staff && user?.isApproved != true) return null;
    return user;
  }

  bool get isAuthenticated => currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Trả về true khi đăng nhập thành công, false khi thất bại hoặc bị hủy.
  Future<bool> signIn({required String email, required String password}) async {
    // Không nhận thêm yêu cầu trong khi đang đăng nhập.
    if (_isDisposed || _isLoading) return false;

    final requestId = ++_requestId;
    _isLoading = true;
    _errorMessage = null;
    _currentUser = null;
    notifyListeners();

    try {
      // Chạy repository đồng bộ ở lượt xử lý tiếp theo, không thêm độ trễ giả.
      AppUser? user;
      if (apiRepository != null) {
        final session = await apiRepository!.login(
          email: email,
          password: password,
        );
        if (_isDisposed || requestId != _requestId) return false;
        final tokenRevision = await apiRepository!.commit(
          session,
          () => !_isDisposed && requestId == _requestId,
        );
        if (_isDisposed || requestId != _requestId) {
          await apiRepository!.client.tokens.clearIf(
            session.accessToken,
            expectedRevision: tokenRevision,
          );
          return false;
        }
        user = session.user;
      } else {
        user = await Future<AppUser?>(
          () => _repository!.signIn(email: email, password: password),
        );
      }

      if (_isDisposed || requestId != _requestId) return false;

      _currentUser = user;
      if (user == null) {
        _errorMessage = 'Email hoặc mật khẩu không đúng.';
      }
      return user != null;
    } on ApiException catch (error) {
      if (!_isDisposed && requestId == _requestId) {
        _errorMessage = error.statusCode == 401
            ? 'Email hoặc mật khẩu không đúng.'
            : error.message;
      }
      return false;
    } catch (_) {
      // Lỗi ngoài dự kiến được chuyển thành thông báo cho người dùng.
      if (!_isDisposed && requestId == _requestId) {
        _errorMessage = 'Không thể đăng nhập. Vui lòng thử lại.';
      }
      return false;
    } finally {
      // Kết thúc loading và báo cho các widget đang lắng nghe cập nhật.
      if (!_isDisposed && requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Đăng ký thành công đồng thời tạo phiên đăng nhập cho Customer mới.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (_isDisposed || _isLoading) return false;

    final requestId = ++_requestId;
    _isLoading = true;
    _errorMessage = null;
    _currentUser = null;
    notifyListeners();

    try {
      AppUser? user;
      if (apiRepository != null) {
        final session = await apiRepository!.register(
          name: name,
          email: email,
          password: password,
        );
        if (_isDisposed || requestId != _requestId) return false;
        final tokenRevision = await apiRepository!.commit(
          session,
          () => !_isDisposed && requestId == _requestId,
        );
        if (_isDisposed || requestId != _requestId) {
          await apiRepository!.client.tokens.clearIf(
            session.accessToken,
            expectedRevision: tokenRevision,
          );
          return false;
        }
        user = session.user;
      } else {
        user = await Future<AppUser?>(() {
          // Hủy trước khi ghi dữ liệu nếu phiên đã bị đăng xuất/dispose.
          if (_isDisposed || requestId != _requestId) return null;
          return _repository!.register(
            name: name,
            email: email,
            password: password,
          );
        });
      }
      if (_isDisposed || requestId != _requestId) return false;
      _currentUser = user;
      return user != null;
    } on ApiException catch (error) {
      if (!_isDisposed && requestId == _requestId) {
        _errorMessage = error.message;
      }
      return false;
    } on MockAuthException catch (error) {
      // Giữ nguyên thông báo cụ thể như email đã được sử dụng.
      if (!_isDisposed && requestId == _requestId) {
        _errorMessage = error.message;
      }
      return false;
    } catch (_) {
      if (!_isDisposed && requestId == _requestId) {
        _errorMessage = 'Không thể đăng ký. Vui lòng thử lại.';
      }
      return false;
    } finally {
      // Luôn kết thúc loading cho yêu cầu còn hiệu lực.
      if (!_isDisposed && requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Xóa phiên và lỗi; kết quả đăng nhập đang chờ sẽ không khôi phục phiên.
  Future<void> restoreSession() async {
    if (!isRemote || _isDisposed || _isLoading) return;
    final id = ++_requestId;
    _isLoading = true;
    notifyListeners();
    try {
      final user = await apiRepository!.restore();
      if (!_isDisposed && id == _requestId) _currentUser = user;
    } on ApiException catch (error) {
      if (!_isDisposed && id == _requestId) _errorMessage = error.message;
    } catch (_) {
      if (!_isDisposed && id == _requestId) {
        _errorMessage = 'Không thể khôi phục phiên đăng nhập.';
      }
    } finally {
      if (!_isDisposed && id == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void signOut() => _clearSession();
  void _clearSession({bool revoke = true}) {
    if (_isDisposed) return;
    _requestId++;
    _currentUser = null;
    _isLoading = false;
    _errorMessage = null;
    if (isRemote) unawaited(apiRepository!.logout(revoke: revoke));
    notifyListeners();
  }

  @override
  void dispose() {
    _repository?.users?.removeListener(_onProfilesChanged);
    if (isRemote) apiRepository!.client.onUnauthorized = null;
    // Không thông báo cập nhật sau khi Provider giải phóng controller.
    _isDisposed = true;
    _requestId++;
    super.dispose();
  }
}
