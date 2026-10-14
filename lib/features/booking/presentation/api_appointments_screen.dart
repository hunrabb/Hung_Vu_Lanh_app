import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_user.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/application/auth_controller.dart';
import '../../workspace/presentation/workspace_screen.dart'
    show WorkspaceScreen, stamp;
import '../application/api_appointment_provider.dart';
import '../data/api_booking_repository.dart';
import '../application/appointment_permissions.dart';
import 'booking_banner.dart';
import '../../reviews/presentation/reviews_screen.dart';

class ApiAppointmentsScreen extends StatelessWidget {
  const ApiAppointmentsScreen({super.key});
  @override
  Widget build(BuildContext c) {
    final p = c.watch<ApiAppointmentProvider>();
    final user = c.watch<AuthController>().currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        title: Text(
          user?.role == UserRole.staff ? 'Lịch làm việc' : 'Lịch hẹn',
        ),
        actions: [
          if (user?.role == UserRole.staff)
            IconButton(
              tooltip: 'Ca làm của tôi',
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute<void>(
                  builder: (_) => const WorkspaceScreen(),
                ),
              ),
            ),
          IconButton(
            onPressed: p.loading ? null : p.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: p.refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (user?.role == UserRole.customer) ...[
              BookingBanner(
                onBook: () => Navigator.pushNamed(c, AppRoutes.booking),
              ),
              const SizedBox(height: 20),
            ],
            DropdownButtonFormField<String>(
              initialValue: p.status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tất cả')),
                for (final entry in labels.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(appointmentStatusLabel(entry.key, user?.role)),
                  ),
              ],
              onChanged: p.loading
                  ? null
                  : (status) => p.refresh(filter: status, changeFilter: true),
            ),
            if (p.loading) const LinearProgressIndicator(),
            if (p.error != null) Text(p.error!),
            if (!p.loading && p.rows.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Bạn chưa có lịch hẹn nào.'),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Sắp tới',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            ...([...p.rows.where((a) => active(a))]
                  ..sort((a, b) => a.startAt.compareTo(b.startAt)))
                .map((a) => AppointmentApiCard(item: a)),
            const Divider(height: 32),
            const Text(
              'Lịch sử',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            ...p.rows
                .where((a) => !active(a))
                .map((a) => AppointmentApiCard(item: a)),
            if (p.more)
              TextButton(
                onPressed: p.loading ? null : () => p.refresh(next: true),
                child: const Text('Tải thêm'),
              ),
          ],
        ),
      ),
    );
  }
}

const labels = {
  'pending': 'Đang chờ',
  'confirmed': 'Đã xác nhận',
  'completed': 'Hoàn thành',
  'cancelled': 'Đã hủy',
  'noShow': 'Khách không đến',
};
bool active(ApiAppointment a) =>
    a.status == 'pending' || a.status == 'confirmed';

String appointmentStatusLabel(String status, UserRole? role) =>
    status == 'noShow' && role == UserRole.customer
    ? 'Không đến'
    : labels[status] ?? status;

class AppointmentApiCard extends StatelessWidget {
  const AppointmentApiCard({super.key, required this.item});
  final ApiAppointment item;
  Future<void> _act(BuildContext c, String action) async {
    final p = c.read<ApiAppointmentProvider>();
    final yes = await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: const Text('Xác nhận thao tác'),
        content: Text(switch (action) {
          'cancel' => 'Hủy lịch hẹn này?',
          'complete' => 'Hoàn thành ca này?',
          'no-show' => 'Xác nhận khách không đến?',
          _ => 'Ẩn lịch sử này?',
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
    if (yes != true || !c.mounted) return;
    try {
      await p.act(item.id, action);
    } catch (e) {
      if (c.mounted) {
        ScaffoldMessenger.of(c)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = c.watch<ApiAppointmentProvider>();
    final user = c.watch<AuthController>().currentUser;
    final role = user?.role;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE7E0D6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.serviceNames,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            Text(
              'Tổng tiền: ${item.status == 'noShow' ? '0' : item.price.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}đ',
            ),
            Text('Cơ sở: ${p.branchName(item.branchId)}'),
            Text(
              'Thợ: ${item.staffId == user?.id ? user?.name : p.staffNames[item.staffId] ?? item.staffId}',
            ),
            if (role != UserRole.customer) Text('Khách: ${item.customerName}'),
            Text('${stamp(item.startAt)} → ${stamp(item.endAt)}'),
            Chip(
              avatar: Icon(
                active(item) ? Icons.schedule : Icons.event_note_outlined,
                size: 16,
              ),
              label: Text(appointmentStatusLabel(item.status, role)),
            ),
            if (p.busy.contains(item.id)) const LinearProgressIndicator(),
            Wrap(
              spacing: 8,
              children: [
                if (role == UserRole.customer &&
                    item.data['customerId'] == user?.id &&
                    item.status == 'completed')
                  TextButton.icon(
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Đánh giá'),
                    onPressed: () => Navigator.pushNamed(
                      c,
                      AppRoutes.reviews,
                      arguments: ReviewsArguments(
                        branchId: item.branchId,
                        staffId: item.staffId,
                        appointmentId: item.id,
                        branchName: p.branchName(item.branchId),
                        staffName: p.staffNames[item.staffId] ?? 'Thợ cắt',
                      ),
                    ),
                  ),
                if (canActOnAppointment(user, item, 'cancel'))
                  TextButton(
                    onPressed: p.busy.contains(item.id)
                        ? null
                        : () => _act(c, 'cancel'),
                    child: const Text('Hủy lịch'),
                  ),
                if (canActOnAppointment(user, item, 'complete')) ...[
                  TextButton(
                    onPressed: p.busy.contains(item.id)
                        ? null
                        : () => _act(c, 'complete'),
                    child: const Text('Hoàn thành ca'),
                  ),
                  TextButton(
                    onPressed: p.busy.contains(item.id)
                        ? null
                        : () => _act(c, 'no-show'),
                    child: const Text('Khách không đến'),
                  ),
                ],
                if (canActOnAppointment(user, item, 'hide/customer') ||
                    canActOnAppointment(user, item, 'hide/staff'))
                  IconButton(
                    tooltip: 'Ẩn lịch sử',
                    onPressed: p.busy.contains(item.id)
                        ? null
                        : () => _act(
                            c,
                            role == UserRole.customer
                                ? 'hide/customer'
                                : 'hide/staff',
                          ),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ApiUpcomingHome extends StatelessWidget {
  const ApiUpcomingHome({super.key, this.todayOnly = false});
  final bool todayOnly;
  @override
  Widget build(BuildContext c) {
    final p = c.watch<ApiAppointmentProvider>();
    final today = stamp(DateTime.now()).split(' ').first;
    final rows = [
      ...p.upcoming.where(
        (a) => !todayOnly || stamp(a.startAt).split(' ').first == today,
      ),
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
    return Column(
      children: [
        if (rows.isNotEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Lịch hẹn sắp tới',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        if (p.loading) const LinearProgressIndicator(),
        if (p.error != null) Text(p.error!),
        if (rows.isNotEmpty) AppointmentApiCard(item: rows.first),
        if (todayOnly && rows.isEmpty && !p.loading)
          const Text('Không có lịch hẹn nào sắp tới trong hôm nay'),
      ],
    );
  }
}
