import '../../../core/models/appointment.dart';

typedef BossTotals = ({int revenue, int appointments});
typedef BossRanking = ({String id, int count, int revenue});

/// Reporting uses Vietnam calendar boundaries and never excludes soft-hidden rows.
abstract final class BossReports {
  static List<Appointment> period(
    List<Appointment> rows,
    DateTime now, {
    bool month = false,
  }) {
    final local = now.toUtc().add(const Duration(hours: 7));
    final start = DateTime.utc(
      local.year,
      local.month,
      month ? 1 : local.day,
    ).subtract(const Duration(hours: 7));
    final end =
        (month
                ? DateTime.utc(local.year, local.month + 1)
                : DateTime.utc(local.year, local.month, local.day + 1))
            .subtract(const Duration(hours: 7));
    return rows
        .where((a) => !a.startAt.isBefore(start) && a.startAt.isBefore(end))
        .toList();
  }

  static BossTotals totals(List<Appointment> rows) => (
    appointments: rows.length,
    revenue: rows
        .where((a) => a.status == AppointmentStatus.completed)
        .fold(0, (sum, a) => sum + a.totalPriceVnd),
  );

  static List<BossRanking> rankings(
    List<Appointment> rows, {
    bool byStaff = false,
  }) {
    final groups = <String, BossRanking>{};
    for (final a in rows.where(
      (a) => a.status == AppointmentStatus.completed,
    )) {
      final id = byStaff ? a.staffId : a.branchId;
      final previous = groups[id];
      groups[id] = (
        id: id,
        count: (previous?.count ?? 0) + 1,
        revenue: (previous?.revenue ?? 0) + a.totalPriceVnd,
      );
    }
    return groups.values.toList()..sort((a, b) {
      final value = byStaff
          ? b.count.compareTo(a.count)
          : b.revenue.compareTo(a.revenue);
      return value != 0 ? value : a.id.compareTo(b.id);
    });
  }

  static int commission(int revenue, int percent) {
    if (percent < 0 || percent > 100) {
      throw ArgumentError('Tỷ lệ phải từ 0 đến 100.');
    }
    return revenue * percent ~/ 100;
  }
}
