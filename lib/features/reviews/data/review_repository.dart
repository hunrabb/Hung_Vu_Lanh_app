import '../../auth/application/auth_controller.dart';
import '../../booking/data/mock_appointment_repository.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/appointment.dart';

class ReviewRepository {
  ReviewRepository(this.auth, this.appointments, {this.onStaffReview});
  final void Function(String id, int rating)? onStaffReview;
  final AuthController auth;
  final MockAppointmentRepository appointments;
  final List<Map<String, dynamic>> _reviews = [];
  Future<Map<String, dynamic>> list(
    String target,
    String targetId, {
    int page = 1,
  }) async {
    if (auth.isRemote) {
      final query = Uri(
        queryParameters: {
          'target': target,
          'targetId': targetId,
          'page': '$page',
        },
      ).query;
      return Map<String, dynamic>.from(
        await auth.apiRepository!.client.request(
          'GET',
          'reviews?$query',
          authenticated: false,
        ) as Map,
      );
    }
    final items = _reviews
        .where((r) => r['target'] == target && r['targetId'] == targetId)
        .toList()
        .reversed
        .toList();
    return {
      'count': items.length,
      'average': items.isEmpty
          ? 0
          : items.fold<int>(0, (sum, r) => sum + (r['rating'] as int)) /
                items.length,
      'items': items.skip((page - 1) * 20).take(20).toList(),
    };
  }

  Future<void> submit(
    String appointmentId,
    String target,
    int rating,
    String comment,
  ) async {
    final user = auth.currentUser;
    if (user?.role != UserRole.customer ||
        !['branch', 'staff'].contains(target) ||
        rating < 1 ||
        rating > 5 ||
        comment.length > 1000) {
      throw StateError('Thông tin đánh giá không hợp lệ.');
    }
    if (auth.isRemote) {
      await auth.apiRepository!.client.request(
        'POST',
        'appointments/${Uri.encodeComponent(appointmentId)}/reviews',
        body: {
          'target': target,
          'rating': rating,
          if (comment.trim().isNotEmpty) 'comment': comment.trim(),
        },
      );
      return;
    }
    final item = appointments
        .getAll()
        .where((a) => a.id == appointmentId)
        .firstOrNull;
    if (item == null ||
        item.customerId != user!.id ||
        item.status != AppointmentStatus.completed) {
      throw StateError('Chỉ được đánh giá lịch của bạn đã hoàn thành.');
    }
    if (_reviews.any(
      (r) => r['appointmentId'] == appointmentId && r['target'] == target,
    )) {
      throw StateError('Bạn đã đánh giá đối tượng này cho lịch hẹn này.');
    }
    if (target == 'staff') {
      if (onStaffReview != null) {
        onStaffReview!(appointmentId, rating);
      } else {
        appointments.reviewStaff(appointmentId, rating);
      }
    }
    _reviews.add({
      'appointmentId': appointmentId,
      'target': target,
      'targetId': target == 'branch' ? item.branchId : item.staffId,
      'rating': rating,
      'comment': comment.trim(),
      'customerName': user.name,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
