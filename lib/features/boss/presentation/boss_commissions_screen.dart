import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_controller.dart';
import '../../reports/presentation/api_report_screen.dart';

import '../../booking/application/appointment_provider.dart';
import '../../branches/application/branch_provider.dart';
import '../../users/application/user_provider.dart';
import '../application/boss_reports.dart';
import 'boss_widgets.dart';

class BossCommissionsScreen extends StatefulWidget {
  const BossCommissionsScreen({super.key});
  @override
  State<BossCommissionsScreen> createState() => _BossCommissionsScreenState();
}

class _BossCommissionsScreenState extends State<BossCommissionsScreen>
    with AutomaticKeepAliveClientMixin<BossCommissionsScreen> {
  @override
  bool get wantKeepAlive => true;
  String? _branchId;
  int _percent = 30;
  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().isRemote) {
      return const ApiReportScreen(kind: ReportKind.bossCommissions);
    }
    super.build(context);
    final booking = context.watch<AppointmentProvider>();
    final branches = context.watch<BranchProvider>();
    final users = context.watch<UserProvider>();
    final branchId = branches.getById(_branchId ?? '')?.id;
    final groups = BossReports.rankings(
      BossReports.period(
        booking.getAppointments(branchId: branchId),
        booking.nowUtc,
        month: true,
      ),
      byStaff: true,
    );
    final byId = {for (final g in groups) g.id: g};
    final ids =
        <String>{
          ...users
              .getStaff(branchId: branchId)
              .where((u) => u.isApproved)
              .map((u) => u.id),
          ...byId.keys,
        }.toList()..sort(
          (a, b) => (users.getById(a)?.name ?? a).compareTo(
            users.getById(b)?.name ?? b,
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        BossBranchFilter(
          value: branchId,
          onChanged: (id) => setState(() => _branchId = id),
        ),
        const SizedBox(height: 16),
        BossPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hoa hồng tạm tính · $_percent%',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Slider(
                value: _percent.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: '$_percent%',
                onChanged: (v) => setState(() => _percent = v.round()),
              ),
              const Text(
                'Tỷ lệ chung cho ca hoàn thành trong tháng. Chỉ đối soát, chưa ghi nhận trả lương.',
              ),
            ],
          ),
        ),
        if (ids.isEmpty)
          const BossPanel(child: Text('Chưa có nhân viên hoặc ca hoàn thành.')),
        ...ids.map((id) {
          final user = users.getById(id);
          final row = byId[id];
          return BossPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Thợ không còn hoạt động',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (user?.branchId != null)
                  BossTag(
                    branches.getById(user!.branchId!)?.name ?? 'Cơ sở đã xóa',
                  ),
                const SizedBox(height: 12),
                Text(
                  '${row?.count ?? 0} ca hoàn thành · Doanh thu ${bossMoney(row?.revenue ?? 0)}',
                ),
                const SizedBox(height: 10),
                Text(
                  'Hoa hồng: ${bossMoney(BossReports.commission(row?.revenue ?? 0, _percent))}',
                  style: const TextStyle(
                    fontSize: 22,
                    color: bossAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
