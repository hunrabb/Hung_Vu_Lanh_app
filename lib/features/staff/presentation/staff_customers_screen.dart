import '../../users/presentation/user_names.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../reports/presentation/api_report_screen.dart';

import '../../../core/models/app_user.dart';
import '../../auth/application/auth_controller.dart';
import '../../booking/application/appointment_provider.dart';
import '../../users/application/user_provider.dart';
import 'staff_earnings_screen.dart';

class StaffCustomersScreen extends StatefulWidget {
  const StaffCustomersScreen({super.key});

  @override
  State<StaffCustomersScreen> createState() => _StaffCustomersScreenState();
}

class _StaffCustomersScreenState extends State<StaffCustomersScreen> {
  StaffCustomerSort _sort = StaffCustomerSort.mostRecent;
  String _label(StaffCustomerSort sort) => switch (sort) {
    StaffCustomerSort.mostVisits => 'Ghé nhiều nhất',
    StaffCustomerSort.highestSpending => 'Chi tiêu cao nhất',
    StaffCustomerSort.mostRecent => 'Gần đây nhất',
  };
  String _money(int value) =>
      '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]}.')}đ';

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().isRemote) {
      return const ApiReportScreen(kind: ReportKind.staffCustomers);
    }
    final staff = context.watch<AuthController>().currentUser;
    final provider = context.watch<AppointmentProvider>();
    final valid =
        staff?.role == UserRole.staff &&
        staff!.isApproved &&
        staff.branchId != null;
    final customers = valid
        ? provider.staffCustomerStats(
            staff.id,
            branchId: staff.branchId,
            sort: _sort,
          )
        : <StaffCustomerStats>[];
    final users = context.watch<UserProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFFAFAFA),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Khách hàng của tôi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          PopupMenuButton<StaffCustomerSort>(
            tooltip: 'Sắp xếp',
            initialValue: _sort,
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (_) => StaffCustomerSort.values
                .map(
                  (value) =>
                      PopupMenuItem(value: value, child: Text(_label(value))),
                )
                .toList(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (valid) StaffRevenueSummary(provider: provider),
            const Text(
              'Danh sách khách hàng của bạn',
              style: TextStyle(color: Color(0xFF757575)),
            ),
            const SizedBox(height: 18),
            Text('Sắp xếp: ${_label(_sort)}'),
            const SizedBox(height: 12),
            if (customers.isEmpty) const Text('Chưa có khách hàng đã phục vụ.'),
            ...customers.map((customer) {
              final id = customer.customerId;
              final name = visibleUserName(users, id, 'Khách hàng');
              final date = customer.lastVisitAt.add(const Duration(hours: 7));
              return Card(
                key: ValueKey(id),
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFAF5E5),
                    child: Text(name.isEmpty ? '?' : name.substring(0, 1)),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lần ghé gần nhất: ${date.day}/${date.month}/${date.year}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF757575),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tổng chi tiêu: ${_money(customer.totalSpendingVnd)}',
                        style: const TextStyle(
                          color: Color(0xFF594536),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        customer.isInactive
                            ? 'Đã lâu chưa quay lại'
                            : 'Hoạt động',
                        style: TextStyle(
                          color: customer.isInactive
                              ? Colors.deepOrange
                              : const Color(0xFF238260),
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${customer.visits} lần',
                    style: const TextStyle(color: Color(0xFF594536)),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
