import '../../../core/models/app_user.dart';
import '../data/api_booking_repository.dart';

/// Mirrors server role, ownership, branch and status rules for visible actions.
bool canActOnAppointment(AppUser? user, ApiAppointment item, String action) {
  if (user == null) return false;
  final active = item.status == 'pending' || item.status == 'confirmed';
  final ended = const [
    'completed',
    'cancelled',
    'noShow',
  ].contains(item.status);
  final customer =
      user.role == UserRole.customer && item.data['customerId'] == user.id;
  final staff =
      user.role == UserRole.staff &&
      user.isApproved &&
      item.staffId == user.id &&
      item.branchId == user.branchId;
  final manager =
      user.role == UserRole.manager && item.branchId == user.branchId;
  return switch (action) {
    'cancel' =>
      active && (customer || manager || user.role == UserRole.superAdmin),
    'complete' || 'no-show' => item.status == 'confirmed' && (staff || manager),
    'hide/customer' => ended && customer,
    'hide/staff' => ended && staff,
    _ => false,
  };
}
