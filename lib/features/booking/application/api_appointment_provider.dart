import 'package:flutter/foundation.dart';

import '../../../core/utils/collection_utils.dart';

import '../../auth/application/auth_controller.dart';
import '../data/api_booking_repository.dart';
import 'appointment_permissions.dart';

class ApiAppointmentProvider extends ChangeNotifier {
  ApiAppointmentProvider(this.repo, this.auth) {
    auth.addListener(_session);
    _session();
  }
  final ApiBookingRepository repo;
  final AuthController auth;
  List<ApiAppointment> rows = [];
  List<ApiAppointment> upcoming = [];
  List<Map<String, dynamic>> branches = [], services = [];
  Map<String, String> staffNames = {};
  String? error, status, _owner;
  int page = 1, _epoch = 0, _request = 0;
  bool loading = false, more = false, _disposed = false;
  final Set<String> busy = {};
  final Map<String, ApiAppointment> _created = {};
  void acceptBooking(ApiAppointment item) {
    if (_disposed || auth.currentUser == null) return;
    _created[item.id] = item;
    upcoming = [item, ...upcoming.where((a) => a.id != item.id)];
    if (status == null || item.status == status) {
      rows = [item, ...rows.where((a) => a.id != item.id)];
    }
    recordMutation();
  }

  int mutationVersion = 0;
  void recordMutation() {
    mutationVersion++;
    notifyListeners();
  }

  Future<void>? _catalog;
  void _session() {
    final id = auth.currentUser?.id;
    if (id == _owner) return;
    _owner = id;
    _epoch++;
    _request++;
    rows = [];
    upcoming = [];
    branches = [];
    services = [];
    staffNames = {};
    busy.clear();
    _created.clear();
    _catalog = null;
    error = null;
    loading = false;
    page = 1;
    status = null;
    notifyListeners();
    if (id != null) Future.microtask(refresh);
  }

  Future<void> catalog() => _catalog ??= () async {
    final epoch = _epoch;
    try {
      final b = await repo.directory('branches'),
          s = await repo.directory('services');
      if (!_disposed && epoch == _epoch) {
        branches = b;
        services = s.where((e) => e['isActive'] == true).toList();
        notifyListeners();
      }
    } catch (_) {
      if (epoch == _epoch) _catalog = null;
      rethrow;
    }
  }();
  Future<void> refresh({
    bool next = false,
    String? filter,
    bool changeFilter = false,
  }) async {
    if (_disposed || auth.currentUser == null) return;
    if (next && loading) return;
    if (changeFilter) status = filter;
    final epoch = _epoch, request = ++_request, target = next ? page + 1 : 1;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await catalog();
      final data = await repo.list(target, status: status);
      final pending = await repo.list(1, status: 'pending'),
          confirmed = await repo.list(1, status: 'confirmed');
      final names = <String, String>{};
      final actor = auth.currentUser;
      if (actor?.role.name == 'manager' || actor?.role.name == 'superAdmin') {
        for (final branch in data.map((a) => a.branchId).toSet()) {
          final people = await repo.api.request(
            'GET',
            'users/branch/${Uri.encodeComponent(branch)}',
          ) as List;
          for (final person in people) {
            names[person['id'] as String] = person['name'] as String;
          }
        }
      } else if (actor?.role.name == 'customer') {
        final keys = <String>{};
        for (final row in [...data, ...pending, ...confirmed]) {
          final items = row.data['services'] as List? ?? [];
          if (items.isEmpty) continue;
          final service = items.first['serviceId'] as String;
          final key = '${row.branchId}:$service';
          if (!keys.add(key)) continue;
          try {
            for (final person in await repo.staff(row.branchId, service)) {
              names[person['id'] as String] = person['name'] as String;
            }
          } catch (_) {
            /* Historical inactive services can lack an eligible directory. */
          }
        }
      }
      if (_disposed || epoch != _epoch || request != _request) return;
      final received = [...data, ...pending, ...confirmed];
      for (final item in received) {
        _created.remove(item.id);
      }
      upcoming = [...pending, ...confirmed, ..._created.values];
      staffNames.addAll(names);
      rows = next ? [...rows, ...data] : data;
      rows = [
        ..._created.values.where((a) => status == null || a.status == status),
        ...rows,
      ];
      rows = {for (final item in rows) item.id: item}.values.toList();
      page = target;
      more = data.length == 50;
    } catch (e) {
      if (!_disposed && epoch == _epoch && request == _request) {
        error = e.toString();
      }
    } finally {
      if (!_disposed && epoch == _epoch && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> act(String id, String action) async {
    final item = findFirst<ApiAppointment>([
      ...rows,
      ...upcoming,
    ], (row) => row.id == id);
    if (item == null || !canActOnAppointment(auth.currentUser, item, action)) {
      throw StateError(
        'Bạn không có quyền thực hiện thao tác với lịch hẹn này.',
      );
    }
    if (!busy.add(id)) return;
    final epoch = _epoch;
    notifyListeners();
    try {
      await repo.act(id, action);
      if (_disposed || epoch != _epoch) return;
      _created.remove(id);
      final updated = ApiAppointment({
        ...item.data,
        if (action == 'cancel') 'status': 'cancelled',
        if (action == 'complete') 'status': 'completed',
        if (action == 'no-show') 'status': 'noShow',
      });
      rows = action.startsWith('hide/')
          ? rows.where((a) => a.id != id).toList()
          : rows.map((a) => a.id == id ? updated : a).toList();
      upcoming = upcoming.where((a) => a.id != id).toList();
      recordMutation();
      if (!_disposed && epoch == _epoch) await refresh();
    } finally {
      if (!_disposed && epoch == _epoch) {
        busy.remove(id);
        notifyListeners();
      }
    }
  }

  String branchName(String id) =>
      findFirst<Map<String, dynamic>>(branches, (b) => b['id'] == id)?['name']
          as String? ??
      id;
  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _request++;
    auth.removeListener(_session);
    super.dispose();
  }
}
