import '../../../core/security/access_scope.dart';

import 'package:flutter/foundation.dart';

import '../../../core/models/app_user.dart';
import '../data/mock_user_repository.dart';
import '../../auth/data/mock_auth_repository.dart';
import 'leave_request.dart';

class UserProvider extends ChangeNotifier {
  factory UserProvider(
    MockUserRepository repository, {
    MockAuthRepository? auth,
    AccessScope? access,
    bool Function(String customerId, AppUser actor)? canReadCustomer,
    bool Function(String)? branchExists,
    bool Function(String)? hasAppointments,
    String? Function(String)? branchName,
  }) => UserProvider._(
    repository,
    auth ?? MockAuthRepository(),
    access ?? AccessScope(() => null),
    canReadCustomer,
    branchExists,
    hasAppointments,
    branchName,
  );
  UserProvider._(
    this._repository,
    this._auth,
    this._access,
    this._canReadCustomer,
    this._branchExists,
    this._hasAppointments,
    this._branchName,
  ) {
    _access.addListener(notifyListeners);
  }
  final MockUserRepository _repository;
  MockAuthRepository _auth;
  final AccessScope _access;
  final bool Function(String, AppUser)? _canReadCustomer;
  final bool Function(String)? _branchExists;
  final bool Function(String)? _hasAppointments;
  final String? Function(String)? _branchName;
  // Lazily initialize so a retained Provider also works after hot reload.
  Map<String, Set<String>>? _dayOffsStore;
  Map<String, Set<String>> get _dayOffs => _dayOffsStore ??= {};
  List<LeaveRequest>? _leaveStore;
  List<LeaveRequest> get _leaves {
    if (_leaveStore != null) return _leaveStore!;
    final rows = <LeaveRequest>[];
    // Retained providers can still contain dates from the former local-only flow.
    for (final entry in (_dayOffsStore ?? <String, Set<String>>{}).entries) {
      final staff = _repository.getById(entry.key);
      if (staff?.role != UserRole.staff || staff?.branchId == null) continue;
      for (final date in entry.value) {
        rows.add(
          LeaveRequest(
            id: 'legacy-${staff!.id}-$date',
            staffId: staff.id,
            staffName: staff.name,
            branchId: staff.branchId!,
            date: date,
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
    }
    return _leaveStore = rows;
  }

  List<LeaveRequest> get leaveRequests {
    final actor = _access.requireUser();
    if (actor.role != UserRole.staff &&
        actor.role != UserRole.manager &&
        actor.role != UserRole.superAdmin) {
      throw UnauthorizedException();
    }
    final rows =
        _leaves
            .where(
              (r) =>
                  actor.role == UserRole.superAdmin ||
                  (actor.role == UserRole.manager
                      ? r.branchId == actor.branchId
                      : r.staffId == actor.id),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(rows);
  }

  void reviewLeave(
    String id, {
    required bool approved,
    required String expectedManagerId,
    String note = '',
  }) {
    final manager = _access.requireUser();
    if (manager.role != UserRole.manager || manager.id != expectedManagerId) {
      throw UnauthorizedException();
    }
    final index = _leaves.indexWhere((r) => r.id == id);
    if (index < 0) throw StateError('Yêu cầu không còn tồn tại.');
    final request = _leaves[index];
    if (request.branchId != manager.branchId) throw UnauthorizedException();
    final reviewer = _repository.getById(manager.id);
    if (reviewer?.role != UserRole.manager ||
        reviewer?.branchId != request.branchId) {
      throw UnauthorizedException();
    }
    if (request.status != LeaveStatus.pending) {
      throw StateError('Yêu cầu đã được xử lý.');
    }
    _leaves[index] = request.reviewed(
      status: approved ? LeaveStatus.approved : LeaveStatus.rejected,
      managerId: manager.id,
      managerName: reviewer!.name,
      branchName: _branchName?.call(request.branchId),
      at: DateTime.now().toUtc(),
      note: note.trim(),
    );
    notifyListeners();
  }

  bool isStaffOff(String staffId, String branchId, DateTime date) {
    _access.requireUser();
    final staff = getById(staffId);
    if (staff?.branchId != branchId) throw UnauthorizedException();
    final key = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).toIso8601String().substring(0, 10);
    return _leaves.any(
      (r) =>
          r.staffId == staffId &&
          r.branchId == branchId &&
          r.date == key &&
          r.status == LeaveStatus.approved,
    );
  }

  void updateOwnProfile({
    required String expectedUserId,
    required String name,
    required String email,
    required String phone,
    required String address,
  }) {
    final actor = _access.requireUser();
    if (actor.id != expectedUserId) throw UnauthorizedException();
    final old = _repository.getById(actor.id);
    if (old == null) throw StateError('Tài khoản không còn tồn tại.');
    final updated = old.copyWith(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      address: address.trim(),
    );
    _auth.validateProfileUpdate(updated);
    _repository.update(updated);
    _auth.updateProfile(updated);
    notifyListeners();
  }

  AppUser _ownStaff({String? expectedUserId}) {
    final actor = _access.requireUser();
    if (actor.role != UserRole.staff ||
        !actor.isApproved ||
        actor.branchId == null ||
        (expectedUserId != null && actor.id != expectedUserId)) {
      throw UnauthorizedException();
    }
    return actor;
  }

  void changeOwnPassword(
    String oldPassword,
    String newPassword, {
    required String expectedUserId,
  }) {
    final staff = _access.requireUser();
    if (staff.id != expectedUserId) throw UnauthorizedException();
    _auth.changePassword(staff.id, oldPassword, newPassword);
    notifyListeners();
  }

  List<String> get ownDayOffs {
    final staff = _ownStaff();
    return List.unmodifiable((_dayOffs[staff.id] ?? {}).toList()..sort());
  }

  void requestDayOff(DateTime date, {required String expectedUserId}) {
    final staff = _ownStaff(expectedUserId: expectedUserId);
    final local = DateTime.now().toUtc().add(const Duration(hours: 7));
    final day = DateTime.utc(date.year, date.month, date.day);
    if (day.isBefore(DateTime.utc(local.year, local.month, local.day))) {
      throw ArgumentError('Không thể chọn ngày đã qua.');
    }
    final key = day.toIso8601String().substring(0, 10);
    if (_leaves.any(
      (r) =>
          r.staffId == staff.id &&
          r.date == key &&
          r.status != LeaveStatus.rejected,
    )) {
      return;
    }
    _leaves.add(
      LeaveRequest(
        id: 'leave-${DateTime.now().microsecondsSinceEpoch}-${_leaves.length}',
        staffId: staff.id,
        staffName: staff.name,
        branchId: staff.branchId!,
        date: key,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    (_dayOffs[staff.id] ??= {}).add(key);
    notifyListeners();
  }

  AppUser _view(AppUser item, AppUser actor) {
    if (item.role == UserRole.staff &&
        item.id != actor.id &&
        (actor.role == UserRole.customer || actor.role == UserRole.staff)) {
      return item.copyWith(email: '', phone: null, address: null);
    }
    return item;
  }

  List<AppUser> get users {
    final actor = _access.currentUser;
    if (actor == null) return const [];
    _access.requireUser();
    if (actor.role == UserRole.superAdmin) return _repository.getAll();
    return List.unmodifiable(
      _repository
          .getAll()
          .where(
            (u) =>
                u.id == actor.id ||
                (u.role == UserRole.staff &&
                    (actor.role == UserRole.manager
                        ? u.branchId == actor.branchId
                        : u.isApproved &&
                              (actor.role != UserRole.staff ||
                                  u.branchId == actor.branchId))),
          )
          .map((item) => _view(item, actor)),
    );
  }

  List<AppUser> getStaff({String? branchId}) {
    final actor = _access.requireUser();
    if (actor.role == UserRole.manager || actor.role == UserRole.staff) {
      if (branchId != null && branchId != actor.branchId) {
        throw UnauthorizedException();
      }
      branchId = actor.branchId;
    }
    return List.unmodifiable(
      users.where(
        (u) =>
            u.role == UserRole.staff &&
            (branchId == null || u.branchId == branchId),
      ),
    );
  }

  AppUser? getById(String id) {
    final actor = _access.requireUser();
    final item = _repository.getById(id);
    if (item == null) return null;
    if (actor.role == UserRole.superAdmin || actor.id == id) return item;
    if (item.role == UserRole.staff &&
        (actor.role == UserRole.manager
            ? item.branchId == actor.branchId
            : item.isApproved &&
                  (actor.role != UserRole.staff ||
                      item.branchId == actor.branchId))) {
      return _view(item, actor);
    }
    if (item.role == UserRole.customer &&
        (_canReadCustomer?.call(id, actor) ?? false)) {
      return item;
    }
    throw UnauthorizedException();
  }

  void _validateWrite(AppUser item, {AppUser? previous}) {
    final actor = _access.requireUser();
    if (item.branchId != null &&
        _branchExists != null &&
        !_branchExists(item.branchId!)) {
      throw StateError('Branch not found.');
    }
    if (actor.role == UserRole.superAdmin) return;
    if (actor.role != UserRole.manager ||
        item.role != UserRole.staff ||
        item.branchId != actor.branchId ||
        (previous != null &&
            (previous.role != UserRole.staff ||
                previous.branchId != actor.branchId ||
                previous.isApproved != item.isApproved)) ||
        (previous == null && item.isApproved)) {
      throw UnauthorizedException();
    }
  }

  void add(AppUser item) {
    _validateWrite(item);
    _repository.add(item);
    notifyListeners();
  }

  /// Recruitment creates a profile only; approval/credentials belong to Boss.
  AppUser createStaffProfile({
    required String name,
    required String email,
    required String phone,
    required String address,
    required List<String> specializedCategoryIds,
  }) {
    final manager = _access.requireUser();
    if (manager.role != UserRole.manager) throw UnauthorizedException();
    if (name.trim().isEmpty ||
        phone.trim().isEmpty ||
        address.trim().isEmpty ||
        specializedCategoryIds.isEmpty ||
        specializedCategoryIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError('Thông tin tuyển dụng không đầy đủ.');
    }
    final base = 'staff-${DateTime.now().microsecondsSinceEpoch}';
    var id = base;
    var suffix = 0;
    while (_repository.getById(id) != null) {
      id = '$base-${++suffix}';
    }
    final item = AppUser(
      id: id,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      address: address.trim(),
      role: UserRole.staff,
      branchId: manager.branchId,
      isApproved: false,
      specializedCategoryIds: specializedCategoryIds,
      createdAt: DateTime.now().toUtc(),
    );
    _auth.validateProfileUpdate(item);
    add(item);
    return _repository.getById(id)!;
  }

  void update(AppUser item) {
    _validateWrite(item, previous: getById(item.id));
    _auth.validateProfileUpdate(item);
    _repository.update(item);
    _auth.updateProfile(_repository.getById(item.id)!);
    notifyListeners();
  }

  void approveStaff(String id, String password) {
    _access.requireBoss();
    final pending = _repository.getById(id);
    if (pending == null ||
        pending.role != UserRole.staff ||
        pending.isApproved) {
      throw StateError('Hồ sơ không còn chờ duyệt.');
    }
    final approved = pending.copyWith(isApproved: true);
    _validateWrite(approved, previous: pending);
    _auth.validateAccount(approved, password);
    try {
      _auth.addStaffCredentials(approved, password);
      _repository.update(approved);
    } catch (_) {
      _auth.revokeCredentialsOnly(id);
      rethrow;
    }
    notifyListeners();
  }

  void rejectPendingStaff(String id) {
    _access.requireBoss();
    final pending = _repository.getById(id);
    if (pending == null ||
        pending.role != UserRole.staff ||
        pending.isApproved) {
      throw StateError('Hồ sơ không còn chờ duyệt.');
    }
    if (_auth.hasCredentials(id) ||
        _hasAppointments == null ||
        _hasAppointments(id)) {
      throw StateError(
        'Không thể xóa hồ sơ có credential/lịch hoặc chưa kiểm tra được lịch.',
      );
    }
    _repository.delete(id);
    notifyListeners();
  }

  void delete(String id) {
    final item = getById(id);
    if (item == null) throw StateError('User not found.');
    _validateWrite(item, previous: item);
    _repository.delete(id);
    _auth.removeCredentials(id);
    notifyListeners();
  }

  void createStaff(
    AppUser item,
    String password, {
    required AppUser actor,
    MockAuthRepository? auth,
  }) {
    _access.requireBoss();
    if (actor.id != _access.requireUser().id ||
        actor.role != UserRole.superAdmin ||
        item.role != UserRole.staff) {
      throw StateError('Chỉ Boss được cấp tài khoản nhân viên.');
    }
    final normalized = item.copyWith(email: item.email.trim().toLowerCase());
    _validateWrite(normalized);
    final authentication = auth ?? _auth;
    authentication.validateAccount(normalized, password);
    _repository.add(normalized);
    try {
      authentication.addStaffCredentials(
        _repository.getById(item.id)!,
        password,
      );
    } catch (_) {
      _repository.delete(item.id);
      rethrow;
    }
    _auth = authentication;
    notifyListeners();
  }

  @override
  void dispose() {
    _access.removeListener(notifyListeners);
    super.dispose();
  }
}
