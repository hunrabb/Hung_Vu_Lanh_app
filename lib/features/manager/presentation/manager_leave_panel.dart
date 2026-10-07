import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../users/application/user_provider.dart';
import '../../users/application/leave_request.dart';
import '../../auth/application/auth_controller.dart';
import '../../branches/application/branch_provider.dart';
import '../../workspace/presentation/workspace_screen.dart';

class ManagerLeavePanel extends StatelessWidget {
  const ManagerLeavePanel({super.key});
  static const _ink = Color(0xFF30251F);
  static const _muted = Color(0xFF817368);
  static const _line = Color(0xFFE7E0D6);
  ButtonStyle get _primary => FilledButton.styleFrom(
    backgroundColor: _ink,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );
  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().isRemote) return const ApiLeavePanel();
    final users = context.watch<UserProvider>();
    final rows = users.leaveRequests;
    final pending = rows.where((r) => r.status == LeaveStatus.pending).toList();
    final history = rows.where((r) => r.status != LeaveStatus.pending).toList()
      ..sort((a, b) => b.reviewedAt!.compareTo(a.reviewedAt!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Xin nghỉ phép (${pending.length} chờ duyệt)',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: _ink,
          ),
        ),
        if (pending.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Không có yêu cầu nghỉ chờ duyệt.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          ),
        ...pending.map((r) => _card(context, r, users)),
        const Divider(height: 32, color: _line),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          iconColor: _muted,
          collapsedIconColor: _muted,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text('Lịch sử phê duyệt (${history.length})'),
          children: [
            if (history.isEmpty)
              const ListTile(title: Text('Chưa có lịch sử phê duyệt.')),
            ...history.map((r) => _card(context, r, users)),
          ],
        ),
      ],
    );
  }

  Widget _card(BuildContext context, LeaveRequest r, UserProvider users) {
    final date = DateTime.parse(r.date);
    return Card(
      margin: const EdgeInsets.only(top: 14),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.staffName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: _ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Ngày nghỉ: ${date.day}/${date.month}/${date.year} · ${leaveLabel(r.status)}',
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
            if (r.reviewedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Người xử lý: ${r.reviewedByName ?? 'Manager'} · ${r.reviewedBranchName ?? context.watch<BranchProvider>().getById(r.branchId)?.name ?? 'Cơ sở không còn hoạt động'}',
              ),
              Text(
                'Thời điểm: ${r.reviewedAt!.toUtc().add(const Duration(hours: 7)).toString().substring(0, 16)}',
              ),
              if (r.note.isNotEmpty) Text('Ghi chú: ${r.note}'),
            ],
            if (r.status == LeaveStatus.pending) ...[
              const Divider(height: 32, color: _line),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    style: _primary,
                    onPressed: () => _review(context, r, users, true),
                    child: const Text('Duyệt nghỉ'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: _muted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onPressed: () => _review(context, r, users, false),
                    child: const Text('Từ chối nghỉ'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    LeaveRequest request,
    UserProvider users,
    bool approved,
  ) async {
    final managerId = context.read<AuthController>().currentUser!.id;
    var note = '';
    final decision = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFFFAF8F4),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: _line),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: _ink,
          letterSpacing: -0.4,
        ),
        title: Text(approved ? 'Duyệt nghỉ phép' : 'Từ chối nghỉ phép'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.staffName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ngày nghỉ: ${DateTime.parse(request.date).day}/${DateTime.parse(request.date).month}/${DateTime.parse(request.date).year}',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextField(
                onChanged: (value) => note = value,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(color: _ink, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tùy chọn)',
                  labelStyle: TextStyle(color: _muted, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.all(16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: _line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFF8E7657)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (approved)
                const Text(
                  'Chặn lịch mới ngày nghỉ; các ca đã đặt vẫn giữ nguyên.',
                  style: TextStyle(fontSize: 12, color: _muted, height: 1.6),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _muted),
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: _primary,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    final text = note;
    if (decision != true || !context.mounted) return;
    try {
      users.reviewLeave(
        request.id,
        approved: approved,
        expectedManagerId: managerId,
        note: text,
      );
    } on StateError catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
