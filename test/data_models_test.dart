import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/core/models/promotion.dart';
import 'package:ktgk/core/models/service.dart';
import 'package:ktgk/core/models/shop_settings.dart';
import 'package:ktgk/core/models/staff_shift.dart';

void main() {
  final start = DateTime.parse('2026-10-06T09:00:00+07:00');
  final end = start.add(const Duration(hours: 1));
  Map<String, dynamic> wire(Map<String, dynamic> json) =>
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

  test('All six entities survive actual JSON encoding and decoding', () {
    final user = AppUser(
      id: 'u',
      name: 'Staff',
      email: 's@example.com',
      role: UserRole.staff,
      branchId: 'branch-01',
      isApproved: true,
      createdAt: start,
      averageRating: 4,
      specializedCategoryIds: ['haircut', 'hairWash'],
    );
    expect(AppUser.fromJson(wire(user.toJson())).toJson(), user.toJson());
    expect(user.createdAt.isUtc, isTrue);
    final legacyUser = user.toJson()..remove('specializedCategoryIds');
    legacyUser['specialty'] = 'Haircut';
    expect(AppUser.fromJson(legacyUser).specializedCategoryIds, isEmpty);
    expect(user.copyWith(name: 'New').specializedCategoryIds, [
      'haircut',
      'hairWash',
    ]);
    expect(
      user.copyWith(specializedCategoryIds: []).specializedCategoryIds,
      isEmpty,
    );
    expect(
      () => user.specializedCategoryIds.add('dye'),
      throwsUnsupportedError,
    );
    expect(user.copyWith(averageRating: null).averageRating, isNull);
    final service = Service(
      id: 's',
      name: 'Shave',
      category: ServiceCategory.shaving,
      durationMinutes: 30,
      priceVnd: 80000,
    );
    expect(Service.fromJson(wire(service.toJson())).toJson(), service.toJson());
    expect(service.copyWith(isActive: false).isActive, isFalse);
    final appointment = Appointment(
      branchId: 'branch-01',
      id: 'a',
      customerId: 'c',
      staffId: 'u',
      serviceIds: ['s'],
      serviceNamesSnapshot: ['Shave'],
      startAt: start,
      endAt: end,
      totalPriceVnd: 80000,
    );
    expect(
      Appointment.fromJson(wire(appointment.toJson())).toJson(),
      appointment.toJson(),
    );
    expect(
      appointment.copyWith(status: AppointmentStatus.cancelled).blocksTime,
      isFalse,
    );
    expect(() => appointment.serviceIds.add('other'), throwsUnsupportedError);
    final shift = StaffShift(
      id: 'shift',
      staffId: 'u',
      startAt: start,
      endAt: end,
    );
    expect(StaffShift.fromJson(wire(shift.toJson())).toJson(), shift.toJson());
    expect(shift.copyWith(staffId: 'other').staffId, 'other');
    final settings = ShopSettings(
      branchId: 'branch-01',
      openingMinute: 480,
      closingMinute: 1200,
      closedWeekdays: [7],
      closedDates: ['2026-10-06'],
    );
    expect(
      ShopSettings.fromJson(wire(settings.toJson())).toJson(),
      settings.toJson(),
    );
    expect(settings.copyWith(closedDates: []).closedDates, isEmpty);
    const promo = Promotion(
      id: 'p',
      title: 'Offer',
      subtitle: 'Welcome',
      imageUrl: '',
    );
    expect(Promotion.fromJson(wire(promo.toJson())).toJson(), promo.toJson());
    expect(promo.copyWith(isActive: false).isActive, isFalse);
  });

  test('Invalid intervals, snapshots and calendar dates are rejected', () {
    expect(
      () => StaffShift(id: 's', staffId: 'u', startAt: end, endAt: start),
      throwsArgumentError,
    );
    expect(
      () => Appointment(
        branchId: 'branch-01',
        id: 'a',
        customerId: 'c',
        staffId: 'u',
        serviceIds: ['s'],
        serviceNamesSnapshot: [],
        startAt: start,
        endAt: end,
        totalPriceVnd: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => ShopSettings(
        branchId: 'branch-01',
        openingMinute: 480,
        closingMinute: 1200,
        closedDates: ['2026-02-30'],
      ),
      throwsArgumentError,
    );
    expect(
      () => ShopSettings(
        branchId: 'branch-01',
        openingMinute: 1200,
        closingMinute: 480,
      ),
      throwsArgumentError,
    );
  });
}
