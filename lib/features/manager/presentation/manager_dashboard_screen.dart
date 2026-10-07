import '../../auth/application/auth_controller.dart';
import '../../branches/application/branch_provider.dart';
import '../../../core/routing/app_routes.dart';
import '../../users/presentation/user_names.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/appointment.dart';
import '../../../core/models/app_user.dart';
import '../../booking/application/appointment_provider.dart';
import '../../booking/presentation/api_appointments_screen.dart';
import '../../booking/application/api_appointment_provider.dart';
import '../../reports/presentation/api_report_screen.dart';
import '../../users/application/user_provider.dart';

import '../../../shared/widgets/custom_button.dart';
import '../../booking/presentation/customer_booking_screen.dart';

// Dashboard derives metrics from the shared appointment store.
class ManagerDashboardScreen extends StatelessWidget {
  const ManagerDashboardScreen({
    super.key,
    this.onAddStaff,
    this.onManageServices,
  });
  final VoidCallback? onAddStaff, onManageServices;

  static const _ink = Color(0xFF1A1A1A);
  static const _muted = Color(0xFF757575);
  static const _gold = Color(0xFFD4AF37);
  String _money(int value) =>
      '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]}.')}đ';
  String _time(DateTime value) {
    final local = value.add(const Duration(hours: 7));
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _preview(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$label: chức năng đang được xây dựng.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().isRemote) {
      return ApiReportScreen(
        kind: ReportKind.managerDashboard,
        onAddStaff: onAddStaff,
        onManageServices: onManageServices,
      );
    }
    // Ngày hiển thị theo múi giờ Việt Nam, không phụ thuộc múi giờ máy chạy.
    final booking = context.watch<AppointmentProvider>();
    final users = context.watch<UserProvider>();
    final manager = context.watch<AuthController>().currentUser;
    if (manager?.role != UserRole.manager || manager?.branchId == null) {
      return const Center(child: Text('Phiên Manager không hợp lệ.'));
    }
    final branchId = manager!.branchId!;
    final branch = context.watch<BranchProvider>().getById(branchId);
    if (branch == null) {
      return const Center(child: Text('Cơ sở không còn hoạt động.'));
    }
    final today = booking.today;
    final start = today.subtract(const Duration(hours: 7));
    final end = start.add(const Duration(days: 1));
    final items = booking
        .getAppointments(branchId: branchId)
        .where((a) => !a.startAt.isBefore(start) && a.startAt.isBefore(end))
        .toList();
    final revenue = items
        .where((a) => a.status == AppointmentStatus.completed)
        .fold<int>(0, (sum, a) => sum + a.totalPriceVnd);
    final cancelled = items
        .where((a) => a.status == AppointmentStatus.cancelled)
        .length;
    final upcoming =
        items
            .where(
              (a) =>
                  a.status == AppointmentStatus.pending ||
                  a.status == AppointmentStatus.confirmed,
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final appointments = upcoming.map((a) {
      final name = a.customerId == 'walk-in'
          ? a.customerName
          : visibleUserName(users, a.customerId, 'Khách hàng');
      return (
        initial: name.isEmpty ? '?' : name.substring(0, 1),
        title: '$name - ${a.serviceNamesSnapshot.join(' + ')}',
        time: '${_time(a.startAt)} - ${_time(a.endAt)}',
        staff: visibleUserName(users, a.staffId, 'Nhân viên'),
      );
    }).toList();
    final stats = [
      (label: 'Doanh thu', value: _money(revenue)),
      (label: 'Lịch hôm nay', value: '${items.length} lịch'),
      (label: 'Lịch đã hủy', value: '$cancelled ca'),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng quan - ${branch.name}',
                            style: TextStyle(
                              fontSize: 28,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Hôm nay, ${today.day} Tháng ${today.month}',
                            style: const TextStyle(fontSize: 14, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Thông báo',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () => _preview(context, 'Thông báo'),
                      icon: const Badge(
                        backgroundColor: _gold,
                        smallSize: 6,
                        child: Icon(Icons.notifications_outlined, color: _ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                CustomButton(
                  label: 'Tạo lịch nhanh',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => const CustomerBookingScreen(walkIn: true),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (context.watch<AuthController>().isRemote)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ApiAppointmentsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.event_note_outlined),
                    label: const Text('Quản lý lịch hẹn'),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pushNamed(AppRoutes.managerRevenue),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF3EEE6),
                      foregroundColor: const Color(0xFF30251F),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 26,
                      ),
                      side: const BorderSide(color: Color(0xFFE1D6C6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Báo cáo Doanh số',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Tổng quan kinh doanh của cơ sở',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF817368),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          size: 20,
                          color: Color(0xFF8E7657),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Thao tác nhanh',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _action(
                        context,
                        'Thêm nhân viên',
                        Icons.person_add_outlined,
                        onAddStaff,
                      ),
                      const SizedBox(width: 10),
                      _action(
                        context,
                        'Quản lý',
                        Icons.spa_outlined,
                        onManageServices,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Hiệu suất hôm nay',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Một góc nhìn nhanh về cửa hàng của bạn.',
                  style: TextStyle(fontSize: 12, color: _muted, height: 1.5),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE7E0D6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stats[0].label,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF817368),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                stats[0].value,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -1,
                                  color: Color(0xFF30251F),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE7E0D6)),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var index = 1; index < 3; index++) ...[
                              if (index == 2)
                                const VerticalDivider(
                                  width: 1,
                                  color: Color(0xFFE7E0D6),
                                ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stats[index].label,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF817368),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          stats[index].value,
                                          style: const TextStyle(
                                            fontSize: 23,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF30251F),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lịch hẹn sắp tới',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: _ink,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      context.watch<AuthController>().isRemote
                          ? '${context.watch<ApiAppointmentProvider>().upcoming.where((a) => a.startAt.toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 10) == DateTime.now().toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 10)).length} lịch'
                          : '${appointments.length} lịch',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Các lượt phục vụ tiếp theo trong ngày.',
                  style: TextStyle(fontSize: 12, color: _muted, height: 1.5),
                ),
                const SizedBox(height: 18),
                if (context.watch<AuthController>().isRemote)
                  const ApiUpcomingHome(todayOnly: true),
                if (!context.watch<AuthController>().isRemote &&
                    appointments.isEmpty)
                  const Text('Không có lịch hẹn nào sắp tới trong hôm nay'),
                if (!context.watch<AuthController>().isRemote)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: ListView.builder(
                      itemCount: appointments.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final appointment = appointments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              horizontalTitleGap: 10,
                              minLeadingWidth: 32,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFFF2F2F2),
                                child: Text(
                                  appointment.initial,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              title: Text(
                                appointment.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: _ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  appointment.time,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    height: 1.5,
                                    color: _muted,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                constraints: const BoxConstraints(maxWidth: 70),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F2F2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Thợ: ${appointment.staff}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback? action,
  ) => ActionChip(
    avatar: Icon(icon, size: 17, color: const Color(0xFF8B7125)),
    label: Text(label),
    labelStyle: const TextStyle(
      color: _ink,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    backgroundColor: const Color(0xFFFAF5E5),
    side: BorderSide.none,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    onPressed: action,
  );
}
