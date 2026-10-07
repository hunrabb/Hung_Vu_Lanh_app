import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

import '../../auth/application/auth_controller.dart';
import '../../booking/application/api_appointment_provider.dart';
import '../data/report_repository.dart';

class ReportState {
  Map<String, dynamic>? data;
  String? error;
  bool loading = false;
}

class ReportProvider extends ChangeNotifier {
  ReportProvider(this.repo, this.auth, this.appointments) {
    auth.addListener(_session);
    appointments.addListener(_appointments);
    _session();
  }
  final ReportRepository repo;
  final AuthController auth;
  final ApiAppointmentProvider appointments;
  final Map<String, ReportState> _states = {};
  final Map<String, int> _requests = {};
  Map<String, String> branchNames = {};
  String? _owner;
  int _epoch = 0, _mutation = -1;
  bool _disposed = false;
  int revision = 0;
  String key(String path, Map<String, String> query) =>
      '$path?${Uri(queryParameters: query).query}';
  ReportState state(String path, Map<String, String> query) =>
      _states.putIfAbsent(key(path, query), ReportState.new);
  void _session() {
    final u = auth.currentUser;
    final owner = u == null ? null : '${u.id}:${u.role.name}:${u.branchId}';
    if (owner == _owner) return;
    _owner = owner;
    _epoch++;
    revision++;
    _states.clear();
    _requests.clear();
    branchNames = {};
    notifyListeners();
  }

  void _appointments() {
    if (_mutation == appointments.mutationVersion) return;
    _mutation = appointments.mutationVersion;
    _epoch++;
    revision++;
    _states.clear();
    _requests.clear();
    notifyListeners();
  }

  Future<void> load(
    String path,
    Map<String, String> query, {
    bool force = false,
  }) async {
    if (_disposed || auth.currentUser == null) return;
    final id = key(path, query), s = state(path, query);
    if (s.loading || (!force && s.data != null)) return;
    final epoch = _epoch, request = (_requests[id] ?? 0) + 1;
    _requests[id] = request;
    s.loading = true;
    s.error = null;
    notifyListeners();
    try {
      final data = await repo.fetch(path, query);
      final names = branchNames.isEmpty ? await repo.branches() : branchNames;
      if (_disposed || epoch != _epoch || _requests[id] != request) return;
      s.data = data;
      branchNames = names;
    } catch (e) {
      if (!_disposed && epoch == _epoch && _requests[id] == request) {
        s.error = e is ApiException
            ? e.message
            : 'Dữ liệu báo cáo không hợp lệ. Vui lòng thử lại.';
      }
    } finally {
      if (!_disposed && epoch == _epoch && _requests[id] == request) {
        s.loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    auth.removeListener(_session);
    appointments.removeListener(_appointments);
    super.dispose();
  }
}
