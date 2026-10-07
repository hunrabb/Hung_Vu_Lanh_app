import '../../users/presentation/account_dialogs.dart';
import '../../users/application/leave_request.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_routes.dart';
import '../../auth/application/auth_controller.dart';
import '../../users/application/user_provider.dart';
import '../../../core/utils/category_labels.dart';
import '../../../core/models/app_user.dart';
import '../../booking/application/appointment_provider.dart';
import '../../workspace/presentation/workspace_screen.dart';
import '../../reports/presentation/api_profile_stats.dart';

class StaffProfileScreen extends StatelessWidget {
  const StaffProfileScreen({super.key});

  Future<void> _requestLeave(BuildContext context, String staffId) async {
    if (context.read<AuthController>().isRemote) {
      await showLeaveForm(context);
      return;
    }
    final users = context.read<UserProvider>();
    final local = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime(local.year, local.month, local.day);
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    try {
      users.requestDayOff(date, expectedUserId: staffId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu nghỉ cho quản lý.')),
      );
    } on StateError catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } on ArgumentError {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ngày nghỉ không hợp lệ.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    if (user?.role != UserRole.staff ||
        user?.isApproved != true ||
        user?.branchId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Vui lòng đăng nhập tài khoản Staff đã duyệt.'),
        ),
      );
    }
    final users = context.watch<UserProvider>();
    final profile = context.watch<AuthController>().isRemote
        ? user!
        : users.getById(user!.id);
    final appointments = context.watch<AppointmentProvider>();
    final remote = context.watch<AuthController>().isRemote;
    final count = remote
        ? 0
        : appointments.ownCompletedAppointments(month: true).length;
    final rating = remote ? null : appointments.ownAverageRating;
    final requests = remote ? <LeaveRequest>[] : users.leaveRequests;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFFAFAFA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Hồ sơ nhân viên',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFF30251F),
                child: Icon(Icons.person, size: 42, color: Color(0xFFE6CCAA)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              profile?.name ?? user.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Thông tin hồ sơ nhân viên',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF757575), fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              'Chuyên môn: ${categoryLabels(profile?.specializedCategoryIds ?? [])}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF757575), fontSize: 13),
            ),
            const SizedBox(height: 22),
            if (remote) const ApiProfileStats(),
            if (!remote)
              Row(
                children: [
                  Expanded(
                    child: _StatisticCard(
                      value: '$count',
                      label: 'Tổng số ca tháng này',
                      icon: Icons.event_available_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatisticCard(
                      value: rating?.toStringAsFixed(1) ?? 'Chưa có đánh giá',
                      label: 'Đánh giá trung bình',
                      icon: Icons.star_outline,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 22),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF594536),
                    ),
                    title: const Text(
                      'Đổi mật khẩu',
                      style: TextStyle(fontSize: 14),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          OwnPasswordDialog(users: users, userId: user.id),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.event_busy_outlined,
                      color: Color(0xFF594536),
                    ),
                    title: const Text(
                      'Xin nghỉ phép',
                      style: TextStyle(fontSize: 14),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _requestLeave(context, user.id),
                  ),
                ],
              ),
            ),
            if (requests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yêu cầu nghỉ phép của tôi',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: requests.map((request) {
                        final key = request.date;
                        final date = DateTime.parse(key);
                        return Chip(
                          label: Text(
                            '${date.day}/${date.month}/${date.year} - ${leaveLabel(request.status)}',
                          ),
                        );
                      }).toList(),
                    ),
                    const Text(
                      'Ngày được duyệt sẽ chặn lịch mới. Các ca đã đặt vẫn giữ nguyên.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
                    ),
                  ],
                ),
              ),
            if (remote) const ApiLeavePanel(own: true),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB94747),
                  side: const BorderSide(color: Color(0xFFE0B7B7)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  context.read<AuthController>().signOut();
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
                },
                icon: const Icon(Icons.logout, size: 19),
                label: const Text('Đăng xuất'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 116),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFD4AF37), size: 20),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF757575),
            fontSize: 10,
            height: 1.3,
          ),
        ),
      ],
    ),
  );
}
