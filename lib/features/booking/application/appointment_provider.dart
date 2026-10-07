import '../../../core/security/access_scope.dart';

import 'package:flutter/foundation.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/appointment.dart';
import '../../../core/models/shop_settings.dart';
import '../../../core/models/time_slot.dart';
import '../../catalog/application/service_provider.dart';
import '../../users/application/user_provider.dart';
import '../data/mock_appointment_repository.dart';
import '../../settings/application/shop_settings_provider.dart';

enum StaffCustomerSort { mostVisits, highestSpending, mostRecent }

typedef StaffCustomerStats = ({
  String customerId,
  int visits,
  int totalSpendingVnd,
  DateTime lastVisitAt,
  bool isInactive,
});

typedef StaffRevenueStats = ({
  String staffId,
  int completedCount,
  int revenueVnd,
});

class AppointmentProvider extends ChangeNotifier {
  AppointmentProvider(
    this._repository, {
    required this.services,
    required this.users,
    ShopSettings? settings,
    ShopSettingsProvider? shopSettings,
    DateTime Function()? clock,
    AccessScope? access,
  }) : _clock = clock ?? DateTime.now,
       _access = access ?? AccessScope(() => null),
       _settingsProvider =
           shopSettings ??
           ShopSettingsProvider(settings: settings, access: access),
       _ownsSettings = shopSettings == null {
    _settingsProvider.addListener(notifyListeners);
    _access.addListener(notifyListeners);
  }

  final MockAppointmentRepository _repository;
  final AccessScope _access;
  final ServiceProvider services;
  final UserProvider users;
  final ShopSettingsProvider _settingsProvider;
  final bool _ownsSettings;
  ShopSettings get settings => _settingsProvider.settings;

  @override
  void dispose() {
    _settingsProvider.removeListener(notifyListeners);
    _access.removeListener(notifyListeners);
    if (_ownsSettings) _settingsProvider.dispose();
    super.dispose();
  }

  final DateTime Function() _clock;
  int _nextId = 0;
  List<Appointment> get appointments => getAppointments();
  List<Appointment> getAppointments({String? branchId}) {
    final actor = _access.currentUser;
    if (actor == null) return const [];
    if (actor.role == UserRole.manager || actor.role == UserRole.staff) {
      _access.requireUser();
      if (branchId != null && branchId != actor.branchId) {
        throw UnauthorizedException();
      }
      branchId = actor.branchId;
    }
    return List.unmodifiable(
      _repository.getAll().where(
        (a) =>
            (branchId == null || a.branchId == branchId) &&
            (actor.role != UserRole.customer || a.customerId == actor.id) &&
            (actor.role != UserRole.staff || a.staffId == actor.id),
      ),
    );
  }

  List<Appointment> getByStaffId(String id, {String? branchId}) {
    final actor = _access.requireUser();
    if (actor.role == UserRole.customer ||
        (actor.role == UserRole.staff && actor.id != id)) {
      throw UnauthorizedException();
    }
    users.getById(
      id,
    ); // Manager cross-branch staff query must fail even if no appointments.
    return List.unmodifiable(
      getAppointments(branchId: branchId).where((a) => a.staffId == id),
    );
  }

  List<Appointment> getByCustomerId(String id, {String? branchId}) {
    final actor = _access.requireUser();
    if (actor.role == UserRole.customer && actor.id != id) {
      throw UnauthorizedException();
    }
    return List.unmodifiable(
      getAppointments(branchId: branchId).where((a) => a.customerId == id),
    );
  }

  int revenue({String? branchId, DateTime? date}) =>
      getAppointments(branchId: branchId)
          .where(
            (a) =>
                a.status == AppointmentStatus.completed &&
                (date == null || _sameDay(a.startAt, date)),
          )
          .fold(0, (sum, a) => sum + a.totalPriceVnd);
  int countAppointments({String? branchId, DateTime? date}) =>
      getAppointments(branchId: branchId)
          .where((a) => date == null || _sameDay(a.startAt, date))
          .length;

  /// Completed transactions for the current Vietnam day/month, scoped by session.
  List<Appointment> completedTransactions({
    String? branchId,
    bool month = false,
  }) {
    final actor = _access.requireUser();
    if (actor.role != UserRole.manager && actor.role != UserRole.superAdmin) {
      throw UnauthorizedException();
    }
    return _completedInPeriod(
      getAppointments(branchId: branchId),
      month: month,
    );
  }

  /// Identity is resolved from the live Staff session, never supplied by the UI.
  List<Appointment> ownCompletedAppointments({bool? month}) {
    final actor = _access.requireUser();
    if (actor.role != UserRole.staff ||
        !actor.isApproved ||
        actor.branchId == null) {
      throw UnauthorizedException();
    }
    return _completedInPeriod(
      getByStaffId(actor.id, branchId: actor.branchId),
      month: month,
    );
  }

  double? get ownAverageRating {
    final reviewed = ownCompletedAppointments()
        .where((a) => a.isReviewed && a.rating != null)
        .toList();
    return reviewed.isEmpty
        ? null
        : reviewed.fold<int>(0, (sum, a) => sum + a.rating!) / reviewed.length;
  }

  List<Appointment> _completedInPeriod(
    List<Appointment> source, {
    bool? month,
  }) {
    final day = today;
    final start = DateTime.utc(
      day.year,
      day.month,
      month == true ? 1 : day.day,
    ).subtract(const Duration(hours: 7));
    final end =
        (month == true
                ? DateTime.utc(day.year, day.month + 1)
                : DateTime.utc(day.year, day.month, day.day + 1))
            .subtract(const Duration(hours: 7));
    final rows =
        source
            .where(
              (a) =>
                  a.status == AppointmentStatus.completed &&
                  (month == null ||
                      (!a.startAt.isBefore(start) && a.startAt.isBefore(end))),
            )
            .toList()
          ..sort((a, b) {
            final time = b.startAt.compareTo(a.startAt);
            return time != 0 ? time : a.id.compareTo(b.id);
          });
    return List.unmodifiable(rows);
  }

  List<StaffRevenueStats> monthlyStaffRevenue({String? branchId}) {
    final groups = <String, StaffRevenueStats>{};
    for (final a in completedTransactions(branchId: branchId, month: true)) {
      final old = groups[a.staffId];
      groups[a.staffId] = (
        staffId: a.staffId,
        completedCount: (old?.completedCount ?? 0) + 1,
        revenueVnd: (old?.revenueVnd ?? 0) + a.totalPriceVnd,
      );
    }
    final rows = groups.values.toList()
      ..sort((a, b) {
        final amount = b.revenueVnd.compareTo(a.revenueVnd);
        return amount != 0 ? amount : a.staffId.compareTo(b.staffId);
      });
    return List.unmodifiable(rows);
  }

  bool _sameDay(DateTime utc, DateTime day) {
    final local = utc.add(const Duration(hours: 7));
    return local.year == day.year &&
        local.month == day.month &&
        local.day == day.day;
  }

  Appointment _checkWrite(String id, String action) {
    final actor = _access.requireUser();
    final item = _repository.getAll().where((a) => a.id == id).firstOrNull;
    if (item == null) throw StateError('Appointment not found.');
    if (actor.role == UserRole.superAdmin) return item;
    if (action == 'cancel' &&
        actor.role == UserRole.customer &&
        item.customerId == actor.id) {
      return item;
    }
    if (action == 'customerHide' &&
        actor.role == UserRole.customer &&
        item.customerId == actor.id) {
      return item;
    }
    if ((action == 'cancel' || action == 'status') &&
        actor.role == UserRole.manager &&
        item.branchId == actor.branchId) {
      return item;
    }
    if ((action == 'status' || action == 'staffHide') &&
        actor.role == UserRole.staff &&
        item.staffId == actor.id &&
        item.branchId == actor.branchId) {
      return item;
    }
    throw UnauthorizedException();
  }

  List<StaffCustomerStats> staffCustomerStats(
    String staffId, {
    StaffCustomerSort sort = StaffCustomerSort.mostRecent,
    String? branchId,
  }) {
    final groups = <String, StaffCustomerStats>{};
    final now = _clock().toUtc();
    for (final item in getByStaffId(staffId, branchId: branchId)) {
      if (item.status != AppointmentStatus.completed) continue;
      final previous = groups[item.customerId];
      final last = previous != null && previous.lastVisitAt.isAfter(item.endAt)
          ? previous.lastVisitAt
          : item.endAt;
      groups[item.customerId] = (
        customerId: item.customerId,
        visits: (previous?.visits ?? 0) + 1,
        totalSpendingVnd:
            (previous?.totalSpendingVnd ?? 0) + item.totalPriceVnd,
        lastVisitAt: last,
        isInactive: now.difference(last) > const Duration(days: 30),
      );
    }
    final result = groups.values.toList()
      ..sort((a, b) {
        final primary = switch (sort) {
          StaffCustomerSort.mostVisits => b.visits.compareTo(a.visits),
          StaffCustomerSort.highestSpending => b.totalSpendingVnd.compareTo(
            a.totalSpendingVnd,
          ),
          StaffCustomerSort.mostRecent => b.lastVisitAt.compareTo(
            a.lastVisitAt,
          ),
        };
        if (primary != 0) return primary;
        final recent = b.lastVisitAt.compareTo(a.lastVisitAt);
        return recent != 0 ? recent : a.customerId.compareTo(b.customerId);
      });
    return List.unmodifiable(result);
  }

  /// Returned UTC date components represent the Vietnam calendar, not an instant.
  DateTime get nowUtc => _clock().toUtc();

  DateTime get today {
    final local = _clock().toUtc().add(const Duration(hours: 7));
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// Input year/month/day are interpreted as a Vietnam calendar date.
  List<TimeSlot> availableSlots({
    required String staffId,
    required String serviceId,
    required DateTime date,
    String? branchId,
  }) {
    _access.requireUser();
    final staff = users.getById(staffId);
    if (staff == null || staff.role != UserRole.staff || !staff.isApproved) {
      return const [];
    }
    if (branchId != null && branchId != staff.branchId) {
      throw UnauthorizedException();
    }
    final configuration = _settingsProvider.getSettings(staff.branchId!);
    if (users.isStaffOff(staffId, staff.branchId!, date)) return const [];
    final service = services.getById(serviceId);
    if (service == null ||
        !service.isActive ||
        users.getById(staffId)?.role != UserRole.staff ||
        !users.getById(staffId)!.isApproved ||
        !users
            .getById(staffId)!
            .specializedCategoryIds
            .contains(service.categoryId)) {
      return const [];
    }
    final day = DateTime.utc(date.year, date.month, date.day);
    final key = day.toIso8601String().substring(0, 10);
    if (configuration.closedWeekdays.contains(day.weekday) ||
        configuration.closedDates.contains(key)) {
      return const [];
    }
    final midnight = day.subtract(const Duration(hours: 7));
    final closing = midnight.add(
      Duration(minutes: configuration.closingMinute),
    );
    final duration = Duration(minutes: service.durationMinutes);
    final now = _clock().toUtc();
    final occupied = _repository
        .getByStaffId(staffId)
        .where((item) => item.blocksTime);
    final result = <TimeSlot>[];
    for (
      var start = midnight.add(Duration(minutes: configuration.openingMinute));
      !start.add(duration).isAfter(closing);
      start = start.add(duration)
    ) {
      if (!start.isAfter(now)) continue;
      final slot = TimeSlot(start: start, end: start.add(duration));
      if (!occupied.any((item) => item.slot.overlaps(slot))) result.add(slot);
    }
    return List.unmodifiable(result);
  }

  Appointment book({
    required String customerId,
    required String staffId,
    required String serviceId,
    required DateTime startAt,
    String customerName = '',
    String? branchId,
  }) {
    final actor = _access.requireUser();
    if (actor.role == UserRole.staff ||
        (actor.role == UserRole.customer && customerId != actor.id) ||
        (actor.role == UserRole.manager && customerId != 'walk-in')) {
      throw UnauthorizedException();
    }
    final staff = users.getById(staffId);
    if (staff == null) throw StateError('Staff not found.');
    if (branchId != null && branchId != staff.branchId) {
      throw UnauthorizedException();
    }
    if (actor.role == UserRole.manager && staff.branchId != actor.branchId) {
      throw UnauthorizedException();
    }
    if (customerId.trim().isEmpty) {
      throw ArgumentError('Customer ID is required.');
    }
    if (customerId == 'walk-in' && customerName.trim().isEmpty) {
      throw ArgumentError('Walk-in name/contact is required.');
    }
    final start = startAt.toUtc();
    final local = start.add(const Duration(hours: 7));
    final slots = availableSlots(
      staffId: staffId,
      serviceId: serviceId,
      date: local,
      branchId: branchId ?? staff.branchId,
    );
    if (!slots.any((slot) => slot.start == start)) {
      throw StateError('Khung giờ không còn khả dụng. Vui lòng chọn lại.');
    }
    final service = services.getById(serviceId)!;
    String id;
    do {
      id = 'appointment-${++_nextId}';
    } while (_repository.getAll().any((item) => item.id == id));
    final item = Appointment(
      branchId: users.getById(staffId)!.branchId!,
      id: id,
      customerId: customerId,
      customerName: customerName.trim(),
      staffId: staffId,
      serviceIds: [service.id],
      serviceNamesSnapshot: [service.name],
      startAt: start,
      endAt: start.add(Duration(minutes: service.durationMinutes)),
      totalPriceVnd: service.priceVnd,
      status: AppointmentStatus.confirmed,
    );
    _repository.create(item);
    notifyListeners();
    return item;
  }

  void cancel(String id) {
    _checkWrite(id, 'cancel');
    if (_repository.cancel(id)) notifyListeners();
  }

  void hideAppointmentFromCustomer(String appointmentId) {
    _checkWrite(appointmentId, 'customerHide');
    if (_repository.hideAppointmentFromCustomer(appointmentId)) {
      notifyListeners();
    }
  }

  void updateStaffStatus(String id, AppointmentStatus status) {
    _checkWrite(id, 'status');
    if (_repository.updateStaffStatus(id, status)) notifyListeners();
  }

  void hideAppointmentFromStaff(String appointmentId) {
    _checkWrite(appointmentId, 'staffHide');
    if (_repository.hideAppointmentFromStaff(appointmentId)) notifyListeners();
  }
}
