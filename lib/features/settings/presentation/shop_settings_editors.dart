import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/shop_settings_provider.dart';

class WorkingHoursDialog extends StatefulWidget {
  const WorkingHoursDialog({super.key, required this.provider});
  final ShopSettingsProvider provider;
  @override
  State<WorkingHoursDialog> createState() => _WorkingHoursDialogState();
}

class _WorkingHoursDialogState extends State<WorkingHoursDialog> {
  late final String _branchId = widget.provider.currentBranchId;
  late TimeOfDay _open = widget.provider.openTime;
  late TimeOfDay _close = widget.provider.closeTime;
  String? _error;

  Future<void> _pick(bool opening) async {
    final time = await showTimePicker(
      context: context,
      initialTime: opening ? _open : _close,
    );
    if (!mounted || time == null) return;
    setState(() {
      if (opening) {
        _open = time;
      } else {
        _close = time;
      }
      _error = null;
    });
  }

  void _save() {
    try {
      widget.provider.updateWorkingHours(_open, _close, branchId: _branchId);
      Navigator.pop(context);
    } on ArgumentError {
      setState(
        () => _error = 'Giờ đóng cửa phải sau giờ mở cửa trong cùng ngày.',
      );
    } on StateError catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Giờ hoạt động'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Giờ mở cửa'),
            subtitle: Text(_open.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: () => _pick(true),
          ),
          ListTile(
            title: const Text('Giờ đóng cửa'),
            subtitle: Text(_close.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: () => _pick(false),
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
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _save, child: const Text('Lưu')),
    ],
  );
}

class ClosedDatesScreen extends StatelessWidget {
  const ClosedDatesScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final provider = context.read<ShopSettingsProvider>();
    final branchId = provider.currentBranchId;
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (date == null || !context.mounted) return;
    try {
      provider.addClosedDate(date, branchId: branchId);
    } on StateError catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShopSettingsProvider>();
    final dates = provider.closedDates;
    final branchId = provider.currentBranchId;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(title: const Text('Cấu hình ngày nghỉ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm ngày nghỉ'),
      ),
      body: dates.isEmpty
          ? const Center(child: Text('Chưa có ngày nghỉ cụ thể.'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = DateTime.parse(dates[index]);
                return Card(
                  child: ListTile(
                    title: Text('${date.day}/${date.month}/${date.year}'),
                    leading: const Icon(Icons.event_busy_outlined),
                    trailing: IconButton(
                      tooltip: 'Xóa ngày nghỉ ${dates[index]}',
                      onPressed: () {
                        try {
                          provider.removeClosedDate(date, branchId: branchId);
                        } on StateError catch (error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.message)),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
