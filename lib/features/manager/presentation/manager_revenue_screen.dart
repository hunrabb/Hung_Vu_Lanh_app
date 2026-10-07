import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../reports/presentation/api_report_screen.dart';

import '../../../core/models/app_user.dart';
import '../../auth/application/auth_controller.dart';
import '../../booking/application/appointment_provider.dart';
import '../../branches/application/branch_provider.dart';
import '../../users/application/user_provider.dart';
import '../../users/presentation/user_names.dart';

class ManagerRevenueScreen extends StatefulWidget {
  const ManagerRevenueScreen({super.key});
  @override
  State<ManagerRevenueScreen> createState() => _ManagerRevenueScreenState();
}

class _ManagerRevenueScreenState extends State<ManagerRevenueScreen> {
  bool _month = false;
  String _money(int value) =>
      '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}đ';
  String _time(DateTime value) {
    final local = value.toUtc().add(const Duration(hours: 7));
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().isRemote) {
      return const ApiReportScreen(kind: ReportKind.managerRevenue);
    }
    final manager = context.watch<AuthController>().currentUser;
    if (manager?.role != UserRole.manager || manager?.branchId == null) {
      return const Scaffold(
        body: Center(child: Text('Phiên Manager không hợp lệ.')),
      );
    }
    final branchId = manager!.branchId!;
    final branch = context.watch<BranchProvider>().getById(branchId);
    if (branch == null) {
      return const Scaffold(
        body: Center(child: Text('Cơ sở không còn hoạt động.')),
      );
    }
    final booking = context.watch<AppointmentProvider>();
    final users = context.watch<UserProvider>();
    final day = booking.today;
    final total = booking
        .completedTransactions(branchId: branchId, month: _month)
        .fold<int>(0, (sum, a) => sum + a.totalPriceVnd);
    final transactions = booking.completedTransactions(branchId: branchId);
    final ranking = booking.monthlyStaffRevenue(branchId: branchId);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Báo cáo Doanh số'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            branch.name,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${day.day}/${day.month}/${day.year} · Giờ Hà Nội',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Hôm nay'),
                selected: !_month,
                onSelected: (_) => setState(() => _month = false),
              ),
              ChoiceChip(
                label: const Text('Tháng này'),
                selected: _month,
                onSelected: (_) => setState(() => _month = true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF182A29),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng doanh thu ${_month ? 'tháng này' : 'hôm nay'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Text(
                  _money(total),
                  style: const TextStyle(
                    fontSize: 30,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chỉ tính lịch đã hoàn thành',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _heading('Giao dịch hoàn thành hôm nay'),
          if (transactions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Chưa có giao dịch hoàn thành hôm nay.'),
              ),
            ),
          ...transactions.map(
            (a) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.customerId == 'walk-in'
                          ? a.customerName
                          : visibleUserName(users, a.customerId, 'Khách hàng'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_time(a.startAt)} · ${a.serviceNamesSnapshot.join(' + ')}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Thợ: ${visibleUserName(users, a.staffId, 'Nhân viên')}',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _money(a.totalPriceVnd),
                      style: const TextStyle(
                        color: Color(0xFF247565),
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _heading('Doanh thu theo thợ · Tháng ${day.month}/${day.year}'),
          if (ranking.isEmpty) const Text('Chưa có ca hoàn thành trong tháng.'),
          ...ranking.asMap().entries.map(
            (entry) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key + 1}. ${visibleUserName(users, entry.value.staffId, 'Nhân viên')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text('${entry.value.completedCount} ca hoàn thành'),
                    const SizedBox(height: 8),
                    Text(
                      _money(entry.value.revenueVnd),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
