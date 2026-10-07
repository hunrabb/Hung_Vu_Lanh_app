import 'package:flutter/foundation.dart';

import '../../../core/models/app_user.dart';
import '../../../core/network/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../data/api_pending_staff_repository.dart';

class PendingStaffProvider extends ChangeNotifier {
  PendingStaffProvider(this._repository, this._auth) {
    _auth.addListener(_sessionChanged);
    _sessionChanged();
  }
  final ApiPendingStaffRepository _repository;
  final AuthController _auth;
  List<AppUser> _rows = [];
  Map<String, String> _branches = {};
  bool _loading = false, _disposed = false;
  int _epoch = 0;
  int _sessionEpoch = 0;
  String? _owner, _error;
  final Set<String> _busy = {};
  List<AppUser> get rows => List.unmodifiable(_rows);
  Map<String, String> get branchNames => Map.unmodifiable(_branches);
  bool get isLoading => _loading;
  String? get error => _error;
  bool isBusy(String id) => _busy.contains(id);
  void _sessionChanged() {
    final user = _auth.currentUser;
    final id = user?.role == UserRole.superAdmin ? user?.id : null;
    if (id == _owner) return;
    _owner = id;
    _epoch++;
    _sessionEpoch++;
    _rows = [];
    _branches = {};
    _busy.clear();
    _loading = false;
    _error = null;
    notifyListeners();
    if (id != null) Future.microtask(refresh);
  }

  Future<void> refresh() async {
    if (_disposed || _auth.currentUser?.role != UserRole.superAdmin) return;
    _owner = _auth.currentUser!.id;
    final epoch = ++_epoch;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _repository.fetch();
      final branches = await _repository.branches();
      if (_disposed || epoch != _epoch) return;
      _rows = rows;
      _branches = branches;
    } on ApiException catch (e) {
      if (!_disposed && epoch == _epoch) _error = e.message;
    } catch (_) {
      if (!_disposed && epoch == _epoch) {
        _error = 'Không tải được hồ sơ. Vui lòng thử lại.';
      }
    } finally {
      if (!_disposed && epoch == _epoch) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> decide(String id, {String? password}) async {
    if (_disposed || _auth.currentUser?.role != UserRole.superAdmin) {
      throw const ApiException(403, 'Phiên Boss không hợp lệ.');
    }
    if (!_busy.add(id)) return;
    final owner = _auth.currentUser!.id, sessionEpoch = _sessionEpoch;
    notifyListeners();
    try {
      if (password != null) {
        await _repository.approve(id, password);
      } else {
        await _repository.reject(id);
      }
      if (!_disposed &&
          _sessionEpoch == sessionEpoch &&
          _auth.currentUser?.id == owner) {
        _rows = _rows.where((u) => u.id != id).toList();
        await refresh();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 409 &&
          !_disposed &&
          _sessionEpoch == sessionEpoch &&
          _auth.currentUser?.id == owner) {
        await refresh();
      }
      rethrow;
    } finally {
      if (!_disposed && _sessionEpoch == sessionEpoch) {
        _busy.remove(id);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _auth.removeListener(_sessionChanged);
    super.dispose();
  }
}
