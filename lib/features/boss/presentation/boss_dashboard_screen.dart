import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_controller.dart';
import '../../reports/presentation/api_report_screen.dart';

import '../../booking/application/appointment_provider.dart';
import '../../branches/application/branch_provider.dart';
import '../../users/application/user_provider.dart';
import '../application/boss_reports.dart';
import 'boss_widgets.dart';

class BossDashboardScreen extends StatefulWidget {
  const BossDashboardScreen({super.key});
  @override
  State<BossDashboardScreen> createState() => _BossDashboardScreenState();
}

class _BossDashboardScreenState extends State<BossDashboardScreen>
    with AutomaticKeepAliveClientMixin<BossDashboardScreen> {
  @override
  bool get wantKeepAlive => true;
  String? _branchId;
  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().isRemote) {
      return const ApiReportScreen(kind: ReportKind.bossDashboard);
    }
    super.build(context);
    final booking = context.watch<AppointmentProvider>();
    final branches = context.watch<BranchProvider>();
    final users = context.watch<UserProvider>();
    final branchId = branches.getById(_branchId ?? '')?.id;
    final rows = booking.getAppointments(branchId: branchId);
    final month = BossReports.period(rows, booking.nowUtc, month: true);
    final daily = BossReports.totals(BossReports.period(rows, booking.nowUtc));
    final monthly = BossReports.totals(month);
    final metrics = [
      (
        label: 'Doanh thu hôm nay',
        value: bossMoney(daily.revenue),
        icon: Icons.payments_outlined,
      ),
      (
        label: 'Doanh thu tháng này',
        value: bossMoney(monthly.revenue),
        icon: Icons.trending_up,
      ),
      (
        label: 'Lịch hẹn hôm nay',
        value: '${daily.appointments}',
        icon: Icons.today_outlined,
      ),
      (
        label: 'Lịch hẹn tháng này',
        value: '${monthly.appointments}',
        icon: Icons.calendar_month_outlined,
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        BossPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tổng hành dinh',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: bossInk,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Một góc nhìn rõ ràng cho toàn chuỗi.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              BossBranchFilter(
                value: branchId,
                onChanged: (id) => setState(() => _branchId = id),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: metrics
                .map(
                  (m) => SizedBox(
                    width: constraints.maxWidth < 370
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: BossPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(m.icon, color: bossAccent),
                          const SizedBox(height: 16),
                          Text(
                            m.label,
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            m.value,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: bossInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        _ranking(
          'Cơ sở dẫn đầu tháng',
          BossReports.rankings(month),
          (id) => branches.getById(id)?.name ?? 'Cơ sở đã xóa',
          false,
        ),
        _ranking(
          'Thợ phục vụ nhiều nhất tháng',
          BossReports.rankings(month, byStaff: true),
          (id) => users.getById(id)?.name ?? 'Thợ không còn hoạt động',
          true,
        ),
        const Text(
          'Doanh thu chỉ tính ca hoàn thành. Số lịch gồm mọi trạng thái.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _ranking(
    String title,
    List<BossRanking> rows,
    String Function(String) name,
    bool staff,
  ) => BossPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: bossInk,
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Text('Chưa có ca hoàn thành trong tháng.')
        else
          ...rows
              .take(5)
              .toList()
              .asMap()
              .entries
              .map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: entry.key == 0
                        ? const Color(0xFFFFE9AA)
                        : const Color(0xFFEAF3F0),
                    child: entry.key == 0
                        ? const Icon(
                            Icons.emoji_events_outlined,
                            color: Color(0xFF9B741E),
                          )
                        : Text('${entry.key + 1}'),
                  ),
                  title: Text(name(entry.value.id)),
                  subtitle: Text(
                    staff
                        ? '${entry.value.count} ca hoàn thành'
                        : bossMoney(entry.value.revenue),
                  ),
                ),
              ),
      ],
    ),
  );
}
