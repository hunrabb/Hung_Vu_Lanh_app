import '../../../core/models/appointment.dart';

class MockAppointmentRepository {
  MockAppointmentRepository({
    Iterable<Appointment>? initialData,
    DateTime? now,
  }) {
    for (final item in initialData ?? _seed(now ?? DateTime.now())) {
      create(item);
    }
  }

  static List<Appointment> _seed(DateTime now) {
    final local = now.toUtc().add(const Duration(hours: 7));
    final midnight = DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).subtract(const Duration(hours: 7));
    Appointment demo(String id, int hour, AppointmentStatus status) =>
        Appointment(
          branchId: 'branch-01',
          id: id,
          customerId: 'customer-01',
          staffId: 'staff-01',
          serviceIds: ['service-01'],
          serviceNamesSnapshot: ['Combo Cắt + Gội'],
          startAt: midnight.add(Duration(hours: hour)),
          endAt: midnight.add(Duration(hours: hour, minutes: 45)),
          totalPriceVnd: 150000,
          status: status,
        );
    return [
      demo('appointment-demo-completed', 9, AppointmentStatus.completed),
      demo('appointment-demo-confirmed', 10, AppointmentStatus.confirmed),
    ];
  }

  final List<Appointment> _items = [];
  List<Appointment> getAll() => List.unmodifiable(_items);
  List<Appointment> getByStaffId(String id) =>
      List.unmodifiable(_items.where((item) => item.staffId == id));
  List<Appointment> getByCustomerId(String id) =>
      List.unmodifiable(_items.where((item) => item.customerId == id));

  // Check and insert synchronously in one RAM operation; no await between them.
  void create(Appointment item) {
    if (_items.any((other) => other.id == item.id)) {
      throw StateError('ID lịch hẹn đã tồn tại.');
    }
    if (item.blocksTime &&
        _items.any(
          (other) =>
              other.staffId == item.staffId &&
              other.blocksTime &&
              other.slot.overlaps(item.slot),
        )) {
      throw StateError('Khung giờ đã có người đặt. Vui lòng chọn giờ khác.');
    }
    _items.add(item);
  }

  bool cancel(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) throw StateError('Không tìm thấy lịch hẹn.');
    final item = _items[index];
    if (item.status == AppointmentStatus.cancelled) return false;
    if (item.status != AppointmentStatus.pending &&
        item.status != AppointmentStatus.confirmed) {
      throw StateError('Không thể hủy lịch đã kết thúc.');
    }
    _items[index] = item.copyWith(status: AppointmentStatus.cancelled);
    return true;
  }

  bool hideAppointmentFromCustomer(String appointmentId) {
    final index = _items.indexWhere((item) => item.id == appointmentId);
    if (index < 0) throw StateError('Không tìm thấy lịch hẹn.');
    final item = _items[index];
    if (item.status == AppointmentStatus.pending ||
        item.status == AppointmentStatus.confirmed) {
      throw StateError('Chỉ có thể xóa lịch sử đã kết thúc.');
    }
    if (item.isHiddenByCustomer) return false;
    _items[index] = item.copyWith(isHiddenByCustomer: true);
    return true;
  }

  bool updateStaffStatus(String id, AppointmentStatus status) {
    if (status != AppointmentStatus.completed &&
        status != AppointmentStatus.noShow) {
      throw ArgumentError('Staff may only complete or mark no-show.');
    }
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) throw StateError('Không tìm thấy lịch hẹn.');
    final item = _items[index];
    if (item.status == status) return false;
    if (item.status != AppointmentStatus.confirmed) {
      throw StateError('Chỉ có thể cập nhật lịch đã xác nhận.');
    }
    _items[index] = item.copyWith(status: status);
    return true;
  }

  bool hideAppointmentFromStaff(String appointmentId) {
    final index = _items.indexWhere((item) => item.id == appointmentId);
    if (index < 0) throw StateError('Không tìm thấy lịch hẹn.');
    final item = _items[index];
    if (item.status == AppointmentStatus.pending ||
        item.status == AppointmentStatus.confirmed) {
      throw StateError('Chỉ có thể ẩn ca đã kết thúc.');
    }
    if (item.isHiddenByStaff) return false;
    _items[index] = item.copyWith(isHiddenByStaff: true);
    return true;
  }
}
