import '../../../core/network/api_client.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/staff_shift.dart';
import '../../users/application/leave_request.dart';

class WorkspaceRepository {
  WorkspaceRepository(this.api);
  final ApiClient api;
  Future<List<StaffShift>> shifts(String? branchId) => api.requestList(
    'GET',
    branchId == null
        ? 'staff/me/shifts'
        : 'branches/${Uri.encodeComponent(branchId)}/shifts',
    decode: StaffShift.fromJson,
  );
  Future<List<LeaveRequest>> leaves(bool own) => api.requestList(
    'GET',
    own ? 'staff/me/leave-requests' : 'leave-requests',
    decode: LeaveRequest.fromJson,
  );
  Future<List<AppUser>> staff(String branchId) async => (await api.requestList(
    'GET',
    'users/branch/${Uri.encodeComponent(branchId)}',
    decode: AppUser.fromJson,
  )).where((user) => user.isApproved).toList();
  Future<Map<String, String>> branches() async => {
    for (final b
        in await api.request('GET', 'branches', authenticated: false) as List)
      b['id'] as String: b['name'] as String,
  };
  Future<void> saveShift(
    String branchId,
    String staffId,
    DateTime start,
    DateTime end, {
    String? id,
  }) async {
    await api.request(
      id == null ? 'POST' : 'PATCH',
      id == null
          ? 'branches/${Uri.encodeComponent(branchId)}/shifts'
          : 'shifts/${Uri.encodeComponent(id)}',
      body: {
        if (id == null) 'staffId': staffId,
        'startAt': start.toUtc().toIso8601String(),
        'endAt': end.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> deleteShift(String id) async {
    await api.request('DELETE', 'shifts/${Uri.encodeComponent(id)}');
  }

  Future<void> requestLeave(DateTime start, DateTime end, String reason) async {
    await api.request(
      'POST',
      'staff/me/leave-requests',
      body: {
        'startAt': start.toUtc().toIso8601String(),
        'endAt': end.toUtc().toIso8601String(),
        'reason': reason.trim(),
      },
    );
  }

  Future<void> decide(String id, bool approved, String note) async {
    await api.request(
      'POST',
      'leave-requests/${Uri.encodeComponent(id)}/decision',
      body: {
        'status': approved ? 'approved' : 'rejected',
        if (note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }
}
