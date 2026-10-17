import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_user.dart';
import '../../auth/application/auth_controller.dart';

class CustomerProfileDialog extends StatefulWidget {
  const CustomerProfileDialog({super.key, required this.user});
  final AppUser user;
  @override
  State<CustomerProfileDialog> createState() => _CustomerProfileDialogState();
}

class _CustomerProfileDialogState extends State<CustomerProfileDialog> {
  final _form = GlobalKey<FormState>();
  late final _fields = [
    TextEditingController(text: widget.user.name),
    TextEditingController(text: widget.user.email),
    TextEditingController(text: widget.user.phone),
    TextEditingController(text: widget.user.address),
  ];
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    if (auth.currentUser?.id != widget.user.id) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await auth.updateOwnProfile(
      name: _fields[0].text,
      email: _fields[1].text,
      phone: _fields[2].text,
      address: _fields[3].text,
    );
    if (!mounted) return;
    if (auth.currentUser?.id != widget.user.id) {
      Navigator.pop(context);
      return;
    }
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = auth.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Chỉnh sửa hồ sơ'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _fields.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: _fields[i],
                      enabled: !_busy,
                      maxLength: [120, 254, 30, 500][i],
                      keyboardType: i == 1
                          ? TextInputType.emailAddress
                          : i == 2
                          ? TextInputType.phone
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: [
                          'Họ tên',
                          'Email',
                          'Số điện thoại',
                          'Địa chỉ',
                        ][i],
                      ),
                      validator: (value) =>
                          i == 0 && (value?.trim().isEmpty ?? true)
                          ? 'Vui lòng nhập họ tên.'
                          : i == 1 &&
                                !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(value?.trim() ?? '')
                          ? 'Email không hợp lệ.'
                          : null,
                    ),
                  ),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Lưu hồ sơ'),
        ),
      ],
    ),
  );
}
