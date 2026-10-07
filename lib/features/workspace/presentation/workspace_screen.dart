import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/staff_shift.dart';
import '../../../core/network/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../../users/application/leave_request.dart';
import '../application/workspace_provider.dart';

const _ink = Color(0xFF30251F), _line = Color(0xFFE7E0D6);
DateTime hanoi(DateTime value) => value.toUtc().add(const Duration(hours: 7));
String stamp(DateTime value) {
  final d = hanoi(value);
  return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

DateTime hanoiInstant(DateTime date, TimeOfDay time) => DateTime.utc(
  date.year,
  date.month,
  date.day,
  time.hour,
  time.minute,
).subtract(const Duration(hours: 7));
void message(BuildContext c, String text) {
  if (c.mounted) {
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(text)));
  }
}

Future<bool> workspaceAction(
  BuildContext c,
  Future<void> Function() action, {
  String? conflict,
}) async {
  try {
    await action();
    return true;
  } on ApiException catch (e) {
    if (!c.mounted) return false;
    message(
      c,
      e.statusCode == 409
          ? (conflict ??
                'Dữ liệu đã được xử lý hoặc trùng thời gian. Danh sách đã cập nhật.')
          : e.message,
    );
  } catch (_) {
    if (!c.mounted) return false;
    message(c, 'Không thể xử lý yêu cầu. Vui lòng thử lại.');
  }
  return false;
}

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      backgroundColor: const Color(0xFFFAF8F4),
      appBar: AppBar(
        title: const Text('Ca làm & Nghỉ phép'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Ca làm'),
            Tab(text: 'Nghỉ phép'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          const _ShiftList(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ApiLeavePanel(
              own:
                  context.read<AuthController>().currentUser?.role ==
                  UserRole.staff,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ShiftList extends StatelessWidget {
  const _ShiftList();
  @override
  Widget build(BuildContext c) {
    final p = c.watch<WorkspaceProvider>();
    final actor = c.watch<AuthController>().currentUser;
    return RefreshIndicator(
      onRefresh: p.refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (actor?.role == UserRole.superAdmin && p.branches.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: p.branchId,
              items: p.branches.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: p.loading
                  ? null
                  : (id) {
                      if (id != null) {
                        workspaceAction(c, () => p.selectBranch(id));
                      }
                    },
              decoration: const InputDecoration(labelText: 'Cơ sở'),
            ),
          Text(
            p.branches[p.branchId] ?? 'Lịch ca của tôi',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: p.loading ? null : p.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Cập nhật'),
              ),
              const Spacer(),
              if (p.canManage)
                FilledButton.icon(
                  onPressed: p.loading
                      ? null
                      : () => showDialog<void>(
                          context: c,
                          builder: (_) => _RangeDialog(provider: p),
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm ca'),
                ),
            ],
          ),
          if (p.loading) const LinearProgressIndicator(),
          if (p.error != null)
            Text(p.error!, style: const TextStyle(color: Colors.red)),
          if (!p.loading && p.shifts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Chưa có ca làm việc.'),
            ),
          ...p.shifts.map(
            (s) => Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: _line),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.staff
                              .where((u) => u.id == s.staffId)
                              .firstOrNull
                              ?.name ??
                          (actor?.id == s.staffId ? actor?.name : null) ??
                          s.staffId,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text('${stamp(s.startAt)} → ${stamp(s.endAt)}'),
                    if (p.busy(s.id)) const LinearProgressIndicator(),
                    if (p.canManage)
                      Row(
                        children: [
                          TextButton(
                            onPressed: p.busy(s.id)
                                ? null
                                : () => showDialog<void>(
                                    context: c,
                                    builder: (_) =>
                                        _RangeDialog(provider: p, shift: s),
                                  ),
                            child: const Text('Sửa ca'),
                          ),
                          TextButton(
                            onPressed: p.busy(s.id)
                                ? null
                                : () async {
                                    final yes = await showDialog<bool>(
                                      context: c,
                                      builder: (d) => AlertDialog(
                                        title: const Text('Xóa ca làm?'),
                                        content: const Text(
                                          'Ca có lịch khách sẽ không thể xóa.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(d, false),
                                            child: const Text('Hủy'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(d, true),
                                            child: const Text('Xóa'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (yes == true && c.mounted) {
                                      await workspaceAction(
                                        c,
                                        () => p.deleteShift(s.id),
                                        conflict: 'Không thể xóa ca: ca đã có lịch khách hoặc dữ liệu đang xung đột.',
                                      );
                                    }
                                  },
                            child: const Text('Xóa ca'),
                          ),
                        ],
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

class ApiLeavePanel extends StatelessWidget {
  const ApiLeavePanel({super.key, this.own = false});
  final bool own;
  @override
  Widget build(BuildContext c) {
    final p = c.watch<WorkspaceProvider>();
    final rows = [...p.leaves]
      ..sort((a, b) {
        final priority = (a.status == LeaveStatus.pending ? 0 : 1).compareTo(
          b.status == LeaveStatus.pending ? 0 : 1,
        );
        return priority != 0 ? priority : b.createdAt.compareTo(a.createdAt);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                own ? 'Đơn nghỉ của tôi' : 'Duyệt nghỉ phép',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),
            IconButton(
              onPressed: p.loading ? null : p.refresh,
              icon: const Icon(Icons.refresh),
            ),
            if (own)
              TextButton(
                onPressed: p.busy('newLeave') ? null : () => showLeaveForm(c),
                child: const Text('Gửi đơn'),
              ),
          ],
        ),
        if (p.loading) const LinearProgressIndicator(),
        if (p.error != null) Text(p.error!),
        if (!p.loading && rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Chưa có đơn nghỉ phép.'),
          ),
        ...rows.map(
          (r) => Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.staffName} · ${leaveLabel(r.status)}',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(p.branches[r.branchId] ?? r.branchId),
                  Text('${stamp(r.startAt!)} → ${stamp(r.endAt!)}'),
                  Text('Lý do: ${r.reason}'),
                  if (r.reviewedAt != null)
                    Text(
                      'Người xử lý: ${r.reviewedByName ?? '—'} · ${r.reviewedBranchName ?? '—'}\n${stamp(r.reviewedAt!)}${r.note.isEmpty ? '' : '\nGhi chú: ${r.note}'}',
                    ),
                  if (p.busy(r.id)) const LinearProgressIndicator(),
                  if (!own && r.status == LeaveStatus.pending)
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final approve in [true, false])
                          TextButton(
                            onPressed: p.busy(r.id)
                                ? null
                                : () => _decision(c, p, r, approve),
                            child: Text(
                              approve ? 'Duyệt nghỉ' : 'Từ chối nghỉ',
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _decision(
    BuildContext c,
    WorkspaceProvider p,
    LeaveRequest r,
    bool approve,
  ) async {
    var note = '';
    final text = await showDialog<String>(
      context: c,
      builder: (d) => AlertDialog(
        title: Text(approve ? 'Duyệt nghỉ phép' : 'Từ chối nghỉ phép'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${r.staffName}\n${stamp(r.startAt!)} → ${stamp(r.endAt!)}'),
            TextField(
              onChanged: (value) => note = value,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (không bắt buộc)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, note),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (text != null && c.mounted) {
      await workspaceAction(
        c,
        () => p.decide(r.id, approve, text),
        conflict: 'Đơn đã được xử lý ở phiên khác. Danh sách đã cập nhật.',
      );
    }
  }
}

Future<void> showLeaveForm(BuildContext c) => showDialog<void>(
  context: c,
  builder: (_) =>
      _RangeDialog(provider: c.read<WorkspaceProvider>(), leave: true),
);

class _RangeDialog extends StatefulWidget {
  const _RangeDialog({required this.provider, this.shift, this.leave = false});
  final WorkspaceProvider provider;
  final StaffShift? shift;
  final bool leave;
  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late DateTime _from, _to;
  TimeOfDay _open = const TimeOfDay(hour: 8, minute: 0),
      _close = const TimeOfDay(hour: 17, minute: 0);
  String? _staff;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final now = hanoi(DateTime.now());
    _from = DateTime(now.year, now.month, now.day + 1);
    _to = _from;
    final s = widget.shift;
    if (s != null) {
      final from = hanoi(s.startAt), to = hanoi(s.endAt);
      _from = DateTime(from.year, from.month, from.day);
      _to = DateTime(to.year, to.month, to.day);
      _open = TimeOfDay(hour: from.hour, minute: from.minute);
      _close = TimeOfDay(hour: to.hour, minute: to.minute);
      _staff = s.staffId;
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start, bool clock) async {
    if (clock) {
      final t = await showTimePicker(
        context: context,
        initialTime: start ? _open : _close,
      );
      if (t != null && mounted) {
        setState(() {
          if (start) {
            _open = t;
          } else {
            _close = t;
          }
        });
      }
    } else {
      final now = hanoi(DateTime.now());
      final d = await showDatePicker(
        context: context,
        initialDate: start ? _from : _to,
        firstDate: widget.leave
            ? DateTime(now.year, now.month, now.day)
            : DateTime(2020),
        lastDate: DateTime(now.year + 3),
      );
      if (d != null && mounted) {
        setState(() {
          if (start) {
            _from = d;
          } else {
            _to = d;
          }
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    final start = hanoiInstant(_from, _open), end = hanoiInstant(_to, _close);
    if (!end.isAfter(start) ||
        end.difference(start) > const Duration(days: 31)) {
      message(context, 'Khoảng thời gian phải hợp lệ và tối đa 31 ngày.');
      return;
    }
    setState(() => _saving = true);
    final ok = await workspaceAction(
      context,
      () => widget.leave
          ? widget.provider.requestLeave(start, end, _reason.text)
          : widget.provider.saveShift(
              _staff!,
              start,
              end,
              id: widget.shift?.id,
            ),
      conflict: widget.leave ? 'Đơn nghỉ trùng với đơn đã gửi hoặc đã duyệt.' : 'Không thể sửa/thêm ca: đã có lịch khách hoặc trùng thời gian ca khác.',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      message(
        context,
        widget.leave ? 'Đã gửi yêu cầu nghỉ cho quản lý.' : 'Đã lưu ca làm.',
      );
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext c) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        widget.leave
            ? 'Xin nghỉ phép'
            : widget.shift == null
            ? 'Thêm ca làm'
            : 'Sửa ca làm',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.leave && widget.shift == null)
                DropdownButtonFormField<String>(
                  initialValue: _staff,
                  items: widget.provider.staff
                      .map(
                        (u) =>
                            DropdownMenuItem(value: u.id, child: Text(u.name)),
                      )
                      .toList(),
                  onChanged: _saving ? null : (id) => _staff = id,
                  validator: (v) =>
                      v == null ? 'Chọn nhân viên đã duyệt.' : null,
                  decoration: const InputDecoration(labelText: 'Nhân viên'),
                ),
              for (final start in [true, false])
                Wrap(
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => _pick(start, false),
                      child: Text(
                        '${start ? 'Từ' : 'Đến'}: ${(start ? _from : _to).day}/${(start ? _from : _to).month}/${(start ? _from : _to).year}',
                      ),
                    ),
                    TextButton(
                      onPressed: _saving ? null : () => _pick(start, true),
                      child: Text((start ? _open : _close).format(c)),
                    ),
                  ],
                ),
              if (widget.leave)
                TextFormField(
                  controller: _reason,
                  enabled: !_saving,
                  maxLength: 1000,
                  decoration: const InputDecoration(labelText: 'Lý do nghỉ'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Vui lòng nhập lý do.'
                      : null,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(c),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Gửi / Lưu'),
        ),
      ],
    ),
  );
}
