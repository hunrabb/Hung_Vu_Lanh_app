import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../branches/application/branch_provider.dart';

const bossInk = Color(0xFF182A29);
const bossAccent = Color(0xFF247565);
String bossMoney(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}đ';
String bossDate(DateTime value) {
  final local = value.toUtc().add(const Duration(hours: 7));
  return '${local.day}/${local.month}/${local.year} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class BossBranchFilter extends StatelessWidget {
  const BossBranchFilter({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String? value;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    final branches = context.watch<BranchProvider>().branches;
    final selected = branches.any((b) => b.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('boss-branch-$selected'),
      initialValue: selected ?? '',
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Phạm vi báo cáo',
        prefixIcon: Icon(Icons.storefront_outlined),
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('Toàn chuỗi')),
        ...branches.map(
          (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
        ),
      ],
      onChanged: (id) => onChanged(id == '' ? null : id),
    );
  }
}

class BossPanel extends StatelessWidget {
  const BossPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE7ECEA)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class BossTag extends StatelessWidget {
  const BossTag(this.label, {super.key, this.icon = Icons.storefront_outlined});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF3F0),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: bossAccent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: bossInk),
          ),
        ),
      ],
    ),
  );
}

Future<void> bossAction(BuildContext context, VoidCallback action) async {
  try {
    action();
  } on StateError catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  } on ArgumentError {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thông tin không hợp lệ.')));
    }
  }
}
