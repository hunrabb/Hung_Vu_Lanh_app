import '../../users/presentation/user_names.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/appointment.dart';
import '../../booking/application/appointment_provider.dart';
import '../../users/application/user_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../../../core/models/app_user.dart';
import '../../workspace/presentation/workspace_screen.dart';
import '../../booking/presentation/api_appointments_screen.dart';

class StaffScheduleScreen extends StatelessWidget {
  const StaffScheduleScreen({super.key});

  void _update(BuildContext context, String id, AppointmentStatus status) {
    try {
      context.read<AppointmentProvider>().updateStaffStatus(id, status);
    } on StateError catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _status(AppointmentStatus status) => switch (status) {
    AppointmentStatus.pending => 'Chờ xác nhận',
    AppointmentStatus.confirmed => 'Đã xác nhận',
    AppointmentStatus.completed => 'Đã hoàn thành',
    AppointmentStatus.cancelled => 'Đã hủy',
    AppointmentStatus.noShow => 'Khách không đến',
  };

  bool _upcoming(Appointment item) =>
      item.status == AppointmentStatus.pending ||
      item.status == AppointmentStatus.confirmed;

  String _price(Appointment item) {
    final amount = item.status == AppointmentStatus.noShow
        ? 0
        : item.totalPriceVnd;
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]}.')}đ';
  }

  Future<void> _hide(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ẩn ca làm'),
        content: const Text('Ẩn ca làm này khỏi lịch trình?'),
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
      context.read<AppointmentProvider>().hideAppointmentFromStaff(id);
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
    final provider = context.watch<AppointmentProvider>();
    final users = context.watch<UserProvider>();
    final current = context.watch<AuthController>().currentUser;
    if (current?.role != UserRole.staff ||
        current?.isApproved != true ||
        current?.branchId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Vui lòng đăng nhập tài khoản Staff đã duyệt.'),
        ),
      );
    }
    final staffId = current!.id;
    final day = provider.today;
    final start = day.subtract(const Duration(hours: 7));
    final end = start.add(const Duration(days: 1));
    final items =
        provider
            .getByStaffId(staffId, branchId: current.branchId)
            .where(
              (item) =>
                  !item.isHiddenByStaff &&
                  !item.startAt.isBefore(start) &&
                  item.startAt.isBefore(end),
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    String time(DateTime value) {
      final local = value.add(const Duration(hours: 7));
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    final upcoming = items.where(_upcoming).toList();
    final ended = items.where((item) => !_upcoming(item)).toList();
    Widget card(Appointment item) => Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${time(item.startAt)} – ${time(item.endAt)}',
            style: const TextStyle(
              fontSize: 19,
              color: Color(0xFF30251F),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _status(item.status),
            style: TextStyle(
              color: item.status == AppointmentStatus.completed
                  ? const Color(0xFF238260)
                  : const Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            item.customerId == 'walk-in'
                ? item.customerName
                : visibleUserName(users, item.customerId, 'Khách hàng'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(item.serviceNamesSnapshot.join(' + ')),
          const SizedBox(height: 8),
          Text(
            'Tổng tiền: ${_price(item)}',
            style: const TextStyle(
              color: Color(0xFF238260),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!_upcoming(item))
            IconButton(
              tooltip: 'Ẩn ca làm',
              onPressed: () => _hide(context, item.id),
              icon: const Icon(Icons.delete_outline),
            ),
          if (item.status == AppointmentStatus.confirmed) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      _update(context, item.id, AppointmentStatus.completed),
                  child: const Text('Hoàn thành ca'),
                ),
                TextButton(
                  onPressed: () =>
                      _update(context, item.id, AppointmentStatus.noShow),
                  child: const Text('Khách không đến'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        actions: [
          if (context.watch<AuthController>().isRemote)
            IconButton(
              tooltip: 'Ca làm của tôi',
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const WorkspaceScreen(),
                ),
              ),
            ),
        ],
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFFAFAFA),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Lịch làm việc hôm nay',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${day.day} tháng ${day.month}, ${day.year}',
              style: const TextStyle(color: Color(0xFF757575)),
            ),
            const SizedBox(height: 18),
            if (items.isEmpty) const Text('Hôm nay chưa có lịch hẹn.'),
            Text(
              'Ca sắp tới (${upcoming.length})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (upcoming.isEmpty) const Text('Không có ca sắp tới.'),
            ...upcoming.map(card),
            const Divider(height: 32),
            Text(
              'Ca đã kết thúc (${ended.length})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (ended.isEmpty) const Text('Chưa có ca đã kết thúc.'),
            ...ended.map(card),
          ],
        ),
      ),
    );
  }
}
