import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/branch.dart';
import '../../branches/application/branch_provider.dart';
import 'boss_widgets.dart';

class BossBranchesScreen extends StatelessWidget {
  const BossBranchesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BranchProvider>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _BranchDialog(provider: provider),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Thêm cơ sở'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Text('${provider.branches.length} cơ sở · Hà Nội'),
          const SizedBox(height: 16),
          if (provider.branches.isEmpty)
            const BossPanel(child: Text('Chưa có cơ sở.')),
          ...provider.branches.map(
            (b) => BossPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BossTag(b.name),
                  const SizedBox(height: 16),
                  Text(b.address),
                  const SizedBox(height: 8),
                  Text(b.phone),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Sửa'),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) =>
                              _BranchDialog(provider: provider, branch: b),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Xóa'),
                        onPressed: () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Xóa cơ sở?'),
                              content: Text(b.name),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Hủy'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );
                          if (yes == true && context.mounted) {
                            await bossAction(
                              context,
                              () => provider.delete(b.id),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchDialog extends StatefulWidget {
  const _BranchDialog({required this.provider, this.branch});
  final BranchProvider provider;
  final Branch? branch;
  @override
  State<_BranchDialog> createState() => _BranchDialogState();
}

class _BranchDialogState extends State<_BranchDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.branch?.name);
  late final _address = TextEditingController(text: widget.branch?.address);
  late final _phone = TextEditingController(text: widget.branch?.phone);
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    try {
      final item = Branch(
        id:
            widget.branch?.id ??
            'branch-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        address: _address.text.trim(),
        phone: _phone.text.trim(),
      );
      if (widget.branch == null) {
        widget.provider.add(item);
      } else {
        widget.provider.update(item);
      }
      Navigator.pop(context);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } on ArgumentError {
      setState(() => _error = 'Thông tin không hợp lệ.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.branch == null ? 'Thêm cơ sở' : 'Sửa cơ sở'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in [
                (label: 'Tên cơ sở', controller: _name),
                (label: 'Địa chỉ', controller: _address),
                (label: 'Số điện thoại', controller: _phone),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: f.controller,
                    decoration: InputDecoration(labelText: f.label),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Vui lòng nhập thông tin.'
                        : null,
                  ),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
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
