import 'package:flutter/foundation.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/staff_shift.dart';
import '../../../core/network/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../../users/application/leave_request.dart';
import '../data/workspace_repository.dart';

class WorkspaceProvider extends ChangeNotifier {
  WorkspaceProvider(this.repo, this.auth) {
    auth.addListener(_session);
    _session();
  }
  final WorkspaceRepository repo;
  final AuthController auth;
  List<StaffShift> shifts = [];
  List<LeaveRequest> leaves = [];
  List<AppUser> staff = [];
  Map<String, String> branches = {};
  String? branchId, error, _owner;
  bool loading = false, _disposed = false;
  int _sessionEpoch = 0, _loadEpoch = 0;
  Future<void>? _loadTask;
  String? _loadKey;
  final Set<String> _busy = {};
  bool busy(String id) => _busy.contains(id);
  bool get canManage =>
      auth.currentUser?.role == UserRole.manager ||
      auth.currentUser?.role == UserRole.superAdmin;
  void _session() {
    final u = auth.currentUser;
    final owner = u == null ? null : '${u.id}:${u.role.name}:${u.branchId}';
    if (owner == _owner) return;
    _owner = owner;
    _sessionEpoch++;
    _loadEpoch++;
    shifts = [];
    leaves = [];
    staff = [];
    branches = {};
    _busy.clear();
    error = null;
    loading = false;
    branchId = u?.branchId;
    notifyListeners();
    if (u != null && u.role != UserRole.customer) Future.microtask(refresh);
  }

  Future<void> selectBranch(String id) async {
    if (auth.currentUser?.role != UserRole.superAdmin ||
        !branches.containsKey(id)) {
      throw const ApiException(403, 'Không có quyền chọn cơ sở.');
    }
    branchId = id;
    shifts = [];
    staff = [];
    await refresh();
  }

  Future<void> refresh() {
    final key = '$_sessionEpoch:$branchId';
    if (_loadTask != null && _loadKey == key) return _loadTask!;
    _loadKey = key;
    late final Future<void> task;
    task = Future<void>.microtask(_refresh).whenComplete(() {
      if (identical(_loadTask, task)) _loadTask = null;
    });
    _loadTask = task;
    return task;
  }

  Future<void> _refresh() async {
    final actor = auth.currentUser;
    if (_disposed || actor == null || actor.role == UserRole.customer) return;
    final load = ++_loadEpoch, session = _sessionEpoch;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final names = await repo.branches();
      final branch = actor.role == UserRole.superAdmin
          ? (branchId ?? (names.isEmpty ? null : names.keys.first))
          : actor.branchId;
      final rows = branch == null && actor.role != UserRole.staff
          ? <StaffShift>[]
          : await repo.shifts(actor.role == UserRole.staff ? null : branch);
      final requests = await repo.leaves(actor.role == UserRole.staff);
      final people = actor.role == UserRole.staff || branch == null
          ? <AppUser>[]
          : await repo.staff(branch);
      if (_disposed || session != _sessionEpoch || load != _loadEpoch) return;
      branches = names;
      branchId = branch;
      shifts = rows;
      leaves = requests;
      staff = people;
    } catch (e) {
      if (!_disposed && session == _sessionEpoch && load == _loadEpoch) {
        error = e is ApiException
            ? e.message
            : 'Không tải được lịch làm việc. Vui lòng thử lại.';
      }
    } finally {
      if (!_disposed && session == _sessionEpoch && load == _loadEpoch) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _mutate(String key, Future<void> Function() action) async {
    if (_disposed || auth.currentUser == null) {
      throw const ApiException(401, 'Vui lòng đăng nhập lại.');
    }
    if (!_busy.add(key)) {
      throw const ApiException(409, 'Thao tác đang được xử lý.');
    }
    final session = _sessionEpoch;
    notifyListeners();
    try {
      await action();
      if (!_disposed && session == _sessionEpoch) {
        final pendingLoad = _loadTask;
        if (pendingLoad != null) await pendingLoad;
        if (!_disposed && session == _sessionEpoch) await refresh();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 409 && !_disposed && session == _sessionEpoch) {
        final pendingLoad = _loadTask;
        if (pendingLoad != null) await pendingLoad;
        if (_disposed || session != _sessionEpoch) rethrow;
        await refresh();
      }
      rethrow;
    } finally {
      if (!_disposed && session == _sessionEpoch) {
        _busy.remove(key);
        notifyListeners();
      }
    }
  }

  Future<void> saveShift(
    String staffId,
    DateTime start,
    DateTime end, {
    String? id,
  }) {
    if (!canManage || branchId == null) {
      throw const ApiException(403, 'Không có quyền quản lý ca.');
    }
    final branch = branchId!;
    return _mutate(
      id ?? 'newShift',
      () => repo.saveShift(branch, staffId, start, end, id: id),
    );
  }

  Future<void> deleteShift(String id) {
    if (!canManage) throw const ApiException(403, 'Không có quyền quản lý ca.');
    return _mutate(id, () => repo.deleteShift(id));
  }

  Future<void> requestLeave(DateTime start, DateTime end, String reason) {
    if (auth.currentUser?.role != UserRole.staff) {
      throw const ApiException(403, 'Chỉ Staff được gửi đơn.');
    }
    return _mutate('newLeave', () => repo.requestLeave(start, end, reason));
  }

  Future<void> decide(String id, bool approved, String note) {
    if (!canManage) throw const ApiException(403, 'Không có quyền duyệt đơn.');
    return _mutate(id, () => repo.decide(id, approved, note));
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionEpoch++;
    _loadEpoch++;
    auth.removeListener(_session);
    super.dispose();
  }
}
