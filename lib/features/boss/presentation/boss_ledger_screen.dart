import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_controller.dart';
import '../../reports/presentation/api_report_screen.dart';

import '../../../core/models/appointment.dart';
import '../../booking/application/appointment_provider.dart';
import '../../branches/application/branch_provider.dart';
import '../../users/application/user_provider.dart';
import 'boss_widgets.dart';

const bossStatuses = {
  AppointmentStatus.pending: 'Đang chờ',
  AppointmentStatus.confirmed: 'Đã xác nhận',
  AppointmentStatus.completed: 'Hoàn thành',
  AppointmentStatus.cancelled: 'Đã hủy',
  AppointmentStatus.noShow: 'Không đến',
};

class BossLedgerScreen extends StatefulWidget {
  const BossLedgerScreen({super.key});
  @override
  State<BossLedgerScreen> createState() => _BossLedgerScreenState();
}

class _BossLedgerScreenState extends State<BossLedgerScreen>
    with AutomaticKeepAliveClientMixin<BossLedgerScreen> {
  @override
  bool get wantKeepAlive => true;
  String? _branchId;
  AppointmentStatus? _status;
  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().isRemote) {
      return const ApiReportScreen(kind: ReportKind.bossLedger);
    }
    super.build(context);
    final branches = context.watch<BranchProvider>();
    final users = context.watch<UserProvider>();
    final rows =
        context
            .watch<AppointmentProvider>()
            .getAppointments(branchId: branches.getById(_branchId ?? '')?.id)
            .where((a) => _status == null || a.status == _status)
            .toList()
          ..sort((a, b) => b.startAt.compareTo(a.startAt));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        BossBranchFilter(
          value: _branchId,
          onChanged: (id) => setState(() => _branchId = id),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tất cả trạng thái'),
              selected: _status == null,
              onSelected: (_) => setState(() => _status = null),
            ),
            ...bossStatuses.entries.map(
              (e) => ChoiceChip(
                label: Text(e.value),
                selected: _status == e.key,
                onSelected: (_) => setState(() => _status = e.key),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('${rows.length} lịch hẹn · Mới nhất trước'),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const BossPanel(child: Text('Không có lịch hẹn phù hợp.')),
        ...rows.map(
          (a) => BossPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    BossTag(
                      branches.getById(a.branchId)?.name ?? 'Cơ sở đã xóa',
                    ),
                    BossTag(
                      users.getById(a.staffId)?.name ??
                          'Thợ không còn hoạt động',
                      icon: Icons.badge_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  a.customerId == 'walk-in'
                      ? a.customerName
                      : users.getById(a.customerId)?.name ?? 'Khách hàng',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(a.serviceNamesSnapshot.join(' + ')),
                const SizedBox(height: 8),
                Text(bossDate(a.startAt)),
                const Divider(height: 28),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    BossTag(
                      bossStatuses[a.status]!,
                      icon: Icons.event_available_outlined,
                    ),
                    Text(
                      'Giá trị lịch: ${bossMoney(a.totalPriceVnd)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: bossInk,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
