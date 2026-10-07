import 'package:flutter/material.dart';

import '../application/user_provider.dart';
import '../../../core/models/app_user.dart';

class OwnProfileDialog extends StatefulWidget {
  const OwnProfileDialog({super.key, required this.users, required this.user});
  final UserProvider users;
  final AppUser user;
  @override
  State<OwnProfileDialog> createState() => _OwnProfileDialogState();
}

class _OwnProfileDialogState extends State<OwnProfileDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _email = TextEditingController(text: widget.user.email);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _address = TextEditingController(text: widget.user.address);
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    try {
      widget.users.updateOwnProfile(
        expectedUserId: widget.user.id,
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        address: _address.text,
      );
      Navigator.pop(context);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } on ArgumentError {
      setState(() => _error = 'Thông tin không hợp lệ.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Thông tin cá nhân'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in [
                (label: 'Họ tên', c: _name),
                (label: 'Email', c: _email),
                (label: 'Số điện thoại', c: _phone),
                (label: 'Địa chỉ', c: _address),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: f.c,
                    decoration: InputDecoration(labelText: f.label),
                    validator: (v) =>
                        f.c == _name && (v?.trim().isEmpty ?? true)
                        ? 'Vui lòng nhập họ tên.'
                        : f.c == _email &&
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(v?.trim() ?? '')
                        ? 'Email không hợp lệ.'
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

class OwnPasswordDialog extends StatefulWidget {
  const OwnPasswordDialog({
    super.key,
    required this.users,
    required this.userId,
  });
  final UserProvider users;
  final String userId;
  @override
  State<OwnPasswordDialog> createState() => OwnPasswordDialogState();
}

class OwnPasswordDialogState extends State<OwnPasswordDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _error;
  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    try {
      widget.users.changeOwnPassword(
        _old.text,
        _new.text,
        expectedUserId: widget.userId,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu.')));
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } on ArgumentError {
      setState(
        () => _error = 'Mật khẩu mới phải khác mật khẩu cũ và không để trống.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Đổi mật khẩu'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in [
              (label: 'Mật khẩu cũ', controller: _old),
              (label: 'Mật khẩu mới', controller: _new),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  controller: field.controller,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(labelText: field.label),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Vui lòng nhập mật khẩu.'
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
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _save, child: const Text('Lưu')),
    ],
  );
}
