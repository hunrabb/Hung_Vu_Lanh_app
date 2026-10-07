import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../reports/presentation/api_report_screen.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/appointment.dart';
import '../../auth/application/auth_controller.dart';
import '../../booking/application/appointment_provider.dart';
import '../../users/application/user_provider.dart';
import '../../users/presentation/user_names.dart';

String staffMoney(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}đ';

class StaffRevenueSummary extends StatelessWidget {
  const StaffRevenueSummary({super.key, required this.provider});
  final AppointmentProvider provider;
  @override
  Widget build(BuildContext context) {
    final daily = provider.ownCompletedAppointments(month: false);
    final monthly = provider.ownCompletedAppointments(month: true);
    int total(List<Appointment> rows) =>
        rows.fold<int>(0, (sum, a) => sum + a.totalPriceVnd);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E7), Color(0xFFFFE7AD)],
        ),
        border: Border.all(color: const Color(0xFFEBC978)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18BA871E),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFA86B08),
                size: 30,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Doanh số cá nhân',
                  style: TextStyle(
                    color: Color(0xFF513509),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (final metric in [
            (label: 'Doanh số hôm nay', value: total(daily)),
            (label: 'Doanh số tháng này', value: total(monthly)),
          ]) ...[
            Text(
              metric.label,
              style: const TextStyle(color: Color(0xFF735426)),
            ),
            const SizedBox(height: 6),
            Text(
              staffMoney(metric.value),
              style: const TextStyle(
                color: Color(0xFF513509),
                fontWeight: FontWeight.w800,
                fontSize: 27,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            '${monthly.length} ca hoàn thành trong tháng',
            style: const TextStyle(color: Color(0xFF735426)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Doanh thu dịch vụ, không phải tiền lương hoặc hoa hồng thực nhận.',
            style: TextStyle(color: Color(0xFF735426), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class StaffEarningsScreen extends StatelessWidget {
  const StaffEarningsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().isRemote) {
      return const ApiReportScreen(kind: ReportKind.staffEarnings);
    }
    final staff = context.watch<AuthController>().currentUser;
    if (staff?.role != UserRole.staff ||
        staff?.isApproved != true ||
        staff?.branchId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Vui lòng đăng nhập tài khoản Staff đã duyệt.'),
        ),
      );
    }
    final provider = context.watch<AppointmentProvider>();
    final users = context.watch<UserProvider>();
    final rows = provider.ownCompletedAppointments();
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Thu nhập của tôi'),
        backgroundColor: const Color(0xFFFAFAFA),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: rows.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StaffRevenueSummary(provider: provider),
                const Text(
                  'Chi tiết ca đã hoàn thành',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty) const Text('Chưa có ca hoàn thành.'),
              ],
            );
          }
          final a = rows[index - 1];
          final local = a.startAt.toUtc().add(const Duration(hours: 7));
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.serviceNamesSnapshot.join(' + '),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${local.day}/${local.month}/${local.year} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a.customerId == 'walk-in'
                        ? a.customerName
                        : visibleUserName(users, a.customerId, 'Khách hàng'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Doanh số: ${staffMoney(a.totalPriceVnd)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF247565),
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
