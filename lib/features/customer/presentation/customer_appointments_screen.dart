import '../../users/presentation/user_names.dart';
import '../../branches/application/branch_provider.dart';
import '../../auth/application/auth_controller.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/appointment.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../booking/application/appointment_provider.dart';
import '../../booking/presentation/api_appointments_screen.dart';
import '../../users/application/user_provider.dart';

class CustomerAppointmentsScreen extends StatelessWidget {
  const CustomerAppointmentsScreen({super.key});

  String _status(AppointmentStatus status) => switch (status) {
    AppointmentStatus.pending => 'Chờ xác nhận',
    AppointmentStatus.confirmed => 'Đã xác nhận',
    AppointmentStatus.completed => 'Đã hoàn thành',
    AppointmentStatus.cancelled => 'Đã hủy',
    AppointmentStatus.noShow => 'Không đến',
  };

  bool _upcoming(Appointment item) =>
      item.status == AppointmentStatus.pending ||
      item.status == AppointmentStatus.confirmed;

  void _cancel(BuildContext context, String id) {
    try {
      context.read<AppointmentProvider>().cancel(id);
    } on StateError catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Widget _card(BuildContext context, Appointment item, UserProvider users) {
    final start = item.startAt.add(const Duration(hours: 7));
    final end = item.endAt.add(const Duration(hours: 7));
    String time(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return Card(
      key: ValueKey(item.id),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.serviceNamesSnapshot.join(' + '),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Cơ sở: ${context.watch<BranchProvider>().getById(item.branchId)?.name ?? 'Cơ sở không còn hoạt động'}',
            ),
            const SizedBox(height: 10),
            Text(
              '${start.day}/${start.month}/${start.year} · ${time(start)} – ${time(end)}',
            ),
            const SizedBox(height: 6),
            Text('Thợ: ${visibleUserName(users, item.staffId, 'Nhân viên')}'),
            const SizedBox(height: 6),
            Text('Tổng tiền: ${item.totalPriceVnd}đ'),
            const SizedBox(height: 10),
            Text(
              _status(item.status),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_upcoming(item))
              TextButton(
                onPressed: () => _cancel(context, item.id),
                child: const Text('Hủy lịch'),
              )
            else
              IconButton(
                tooltip: 'Xóa lịch sử',
                onPressed: () => _hide(context, item.id),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _hide(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lịch sử'),
        content: const Text('Bạn có chắc chắn muốn xóa lịch sử này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      context.read<AppointmentProvider>().hideAppointmentFromCustomer(id);
    } on StateError catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().isRemote) {
      return const ApiAppointmentsScreen();
    }
    final customerId = context.watch<AuthController>().currentUser?.id;
    if (customerId == null) {
      return const Center(child: Text('Vui lòng đăng nhập.'));
    }
    final items = context.watch<AppointmentProvider>().getByCustomerId(
      customerId,
    );
    final users = context.watch<UserProvider>();
    final upcoming = items.where(_upcoming).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    // Include noShow so every customer's appointment remains visible in history.
    final history =
        items
            .where((item) => !_upcoming(item) && !item.isHiddenByCustomer)
            .toList()
          ..sort((a, b) => b.startAt.compareTo(a.startAt));
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Lịch hẹn của bạn',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          if (upcoming.isEmpty && history.isEmpty) ...[
            const Icon(
              Icons.calendar_today_outlined,
              size: 52,
              color: Color(0xFFD4AF37),
            ),
            const SizedBox(height: 20),
            const Text('Bạn chưa có lịch hẹn nào', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            CustomButton(
              label: 'Đặt lịch ngay',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.booking),
            ),
          ] else ...[
            Text(
              'Sắp tới (${upcoming.length})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (upcoming.isEmpty) const Text('Không có lịch hẹn sắp tới.'),
            ...upcoming.map((item) => _card(context, item, users)),
            const SizedBox(height: 24),
            Text(
              'Lịch sử (${history.length})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (history.isEmpty) const Text('Chưa có lịch sử lịch hẹn.'),
            ...history.map((item) => _card(context, item, users)),
          ],
        ],
      ),
    );
  }
}
