import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_user.dart';
import '../../../core/utils/category_labels.dart';
import '../../branches/application/branch_provider.dart';
import '../../users/application/user_provider.dart';
import 'boss_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../application/pending_staff_provider.dart';
import '../../../core/network/api_client.dart';

class BossPendingStaffScreen extends StatelessWidget {
  const BossPendingStaffScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserProvider>();
    final branches = context.watch<BranchProvider>();
    final pending = context.watch<AuthController>().isRemote
        ? context.watch<PendingStaffProvider>()
        : null;
    final rows =
        pending?.rows ??
        users.users
            .where((u) => u.role == UserRole.staff && !u.isApproved)
            .toList();
    final content = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${rows.length} hồ sơ chờ duyệt',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        if (pending?.isLoading == true) const LinearProgressIndicator(),
        if (pending?.error != null)
          BossPanel(
            child: Column(
              children: [
                Text(pending!.error!),
                TextButton(
                  onPressed: pending.refresh,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        if (rows.isEmpty &&
            pending?.isLoading != true &&
            pending?.error == null)
          const BossPanel(child: Text('Đã xử lý hết hồ sơ chờ duyệt.')),
        ...rows.map(
          (u) => BossPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BossTag(
                  pending?.branchNames[u.branchId] ??
                      branches.getById(u.branchId!)?.name ??
                      'Cơ sở ${u.branchId}',
                ),
                const SizedBox(height: 12),
                Text(
                  u.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(u.email),
                Text(u.phone ?? 'Chưa có SĐT'),
                Text(u.address ?? 'Chưa có địa chỉ'),
                const SizedBox(height: 8),
                if (u.specializedCategoryIds.isNotEmpty)
                  Text(categoryLabels(u.specializedCategoryIds)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: pending?.isBusy(u.id) == true
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (_) => _ApprovalDialog(
                                users: users,
                                user: u,
                                pending: pending,
                              ),
                            ),
                      icon: const Icon(Icons.check),
                      label: const Text('Duyệt'),
                    ),
                    OutlinedButton(
                      onPressed: pending?.isBusy(u.id) == true
                          ? null
                          : () async {
                              final yes = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Từ chối hồ sơ?'),
                                  content: Text('Xóa hồ sơ chờ của ${u.name}?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Hủy'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Từ chối'),
                                    ),
                                  ],
                                ),
                              );
                              if (yes == true && context.mounted) {
                                if (pending != null) {
                                  try {
                                    await pending.decide(u.id);
                                  } on ApiException catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.statusCode == 409
                                                    ? 'Hồ sơ đã được xử lý. Danh sách đã cập nhật.'
                                                    : e.message,
                                              ),
                                            ),
                                          );
                                    }
                                  }
                                } else {
                                  await bossAction(
                                    context,
                                    () => users.rejectPendingStaff(u.id),
                                  );
                                }
                              }
                            },
                      child: const Text('Từ chối'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return pending == null
        ? content
        : RefreshIndicator(onRefresh: pending.refresh, child: content);
  }
}

class _ApprovalDialog extends StatefulWidget {
  const _ApprovalDialog({
    required this.users,
    required this.user,
    this.pending,
  });
  final UserProvider users;
  final AppUser user;
  final PendingStaffProvider? pending;
  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _submitting = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    if (_submitting || !_form.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (widget.pending != null) {
        await widget.pending!.decide(widget.user.id, password: _password.text);
      } else {
        widget.users.approveStaff(widget.user.id, _password.text);
      }
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.statusCode == 409
              ? 'Hồ sơ đã được duyệt ở phiên khác. Danh sách đã cập nhật.'
              : e.message;
        });
      }
    } on StateError catch (e) {
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } on ArgumentError {
      setState(() {
        _submitting = false;
        _error = 'Mật khẩu không hợp lệ.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Duyệt ${widget.user.name}'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            enabled: !_submitting,
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Mật khẩu cấp phát'),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Vui lòng nhập mật khẩu.'
                : null,
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _submitting ? null : _approve,
        child: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Duyệt'),
      ),
    ],
  );
}
