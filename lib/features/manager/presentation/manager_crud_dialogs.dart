import '../../../core/utils/category_labels.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/security/access_scope.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/service.dart';
import '../../catalog/application/service_provider.dart';
import '../../users/application/user_provider.dart';

// Local IDs only; the real backend will provide its own ID strategy.
String _newId(String prefix, bool Function(String) exists) {
  final base = '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  var id = base;
  var suffix = 0;
  while (exists(id)) {
    id = '$base-${++suffix}';
  }
  return id;
}

Future<void> confirmManagerDelete(
  BuildContext context,
  String name,
  VoidCallback delete,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Xác nhận xóa'),
      content: Text('Bạn có muốn xóa "$name"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    delete();
  } on UnauthorizedException catch (error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.message)));
  } on StateError {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Dữ liệu không còn tồn tại.')));
  }
}

/// Profile and catalog editors share a small form; Providers enforce permission.
class ManagerCrudDialog extends StatefulWidget {
  const ManagerCrudDialog.service({
    super.key,
    required ServiceProvider provider,
    this.service,
  }) : serviceProvider = provider,
       userProvider = null,
       user = null;
  const ManagerCrudDialog.staff({
    super.key,
    required UserProvider provider,
    this.user,
  }) : userProvider = provider,
       serviceProvider = null,
       service = null;

  final ServiceProvider? serviceProvider;
  final UserProvider? userProvider;
  final Service? service;
  final AppUser? user;

  @override
  State<ManagerCrudDialog> createState() => _ManagerCrudDialogState();
}

class _ManagerCrudDialogState extends State<ManagerCrudDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final Set<String> _specializedCategories;
  late final TextEditingController _price;
  late final TextEditingController _duration;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late ServiceCategory _category;
  String? _error;
  bool get _isService => widget.serviceProvider != null;
  bool get _isEditing => widget.service != null || widget.user != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.service?.name ?? widget.user?.name,
    );
    _email = TextEditingController(text: widget.user?.email);
    _phone = TextEditingController(text: widget.user?.phone);
    _address = TextEditingController(text: widget.user?.address);
    _specializedCategories = Set.of(widget.user?.specializedCategoryIds ?? []);
    _price = TextEditingController(text: widget.service?.priceVnd.toString());
    _duration = TextEditingController(
      text: widget.service?.durationMinutes.toString(),
    );
    _category = widget.service?.category ?? ServiceCategory.haircut;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _price,
      _duration,
      _phone,
      _address,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Vui lòng nhập thông tin.' : null;

  String? _number(String? value, {required bool positive}) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);
    if (!RegExp(r'^\d+$').hasMatch(text) ||
        number == null ||
        number < (positive ? 1 : 0)) {
      return positive
          ? 'Nhập số nguyên lớn hơn 0.'
          : 'Nhập số nguyên không âm.';
    }
    return null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (!_isService && _specializedCategories.isEmpty) {
      setState(() => _error = 'Vui lòng chọn ít nhất một chuyên môn.');
      return;
    }
    try {
      if (_isService) {
        final provider = widget.serviceProvider!;
        final existing = widget.service;
        final item =
            existing?.copyWith(
              name: _name.text.trim(),
              category: _category,
              priceVnd: int.parse(_price.text.trim()),
              durationMinutes: int.parse(_duration.text.trim()),
            ) ??
            Service(
              id: _newId('service', (id) => provider.getById(id) != null),
              name: _name.text.trim(),
              category: _category,
              priceVnd: int.parse(_price.text.trim()),
              durationMinutes: int.parse(_duration.text.trim()),
            );
        if (existing == null) {
          provider.add(item);
        } else {
          provider.update(item);
        }
      } else {
        final provider = widget.userProvider!;
        final existing = widget.user;
        final email = _email.text.trim().toLowerCase();
        if (provider.users.any(
          (user) => user.id != existing?.id && user.email == email,
        )) {
          setState(() => _error = 'Email đã được sử dụng.');
          return;
        }
        if (existing == null) {
          provider.createStaffProfile(
            email: email,
            name: _name.text,
            phone: _phone.text,
            address: _address.text,
            specializedCategoryIds: _specializedCategories.toList(),
          );
        } else {
          provider.update(
            existing.copyWith(
              name: _name.text.trim(),
              email: email,
              phone: _phone.text.trim(),
              address: _address.text.trim(),
              specializedCategoryIds: _specializedCategories.toList(),
            ),
          );
        }
      }
      Navigator.pop(context);
    } on UnauthorizedException catch (error) {
      setState(() => _error = error.message);
    } on StateError {
      setState(() => _error = 'Dữ liệu đã thay đổi. Vui lòng kiểm tra lại.');
    } on ArgumentError {
      setState(() => _error = 'Thông tin không hợp lệ. Vui lòng kiểm tra lại.');
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    FormFieldValidator<String>? validator,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: number
          ? TextInputType.number
          : controller == _email
          ? TextInputType.emailAddress
          : TextInputType.text,
      validator: validator ?? _required,
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${_isEditing ? 'Sửa' : 'Thêm'} ${_isService ? 'dịch vụ' : 'nhân viên'}',
    ),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_isService ? 'Tên dịch vụ' : 'Tên nhân viên', _name),
              if (_isService) ...[
                DropdownButtonFormField<ServiceCategory>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Danh mục'),
                  items: ServiceCategory.values
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(categoryLabel(category)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) _category = value;
                  },
                ),
                const SizedBox(height: 16),
                _field(
                  'Giá (VND)',
                  _price,
                  number: true,
                  validator: (value) => _number(value, positive: false),
                ),
                _field(
                  'Thời lượng (phút)',
                  _duration,
                  number: true,
                  validator: (value) => _number(value, positive: true),
                ),
              ] else ...[
                _field(
                  'Email',
                  _email,
                  validator: (value) =>
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Vui lòng nhập email hợp lệ.',
                ),
                _field('Số điện thoại', _phone),
                _field('Địa chỉ', _address),
                if (!_isEditing) const Text('Hồ sơ mới sẽ chờ Boss duyệt.'),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Chuyên môn'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: context
                      .watch<ServiceProvider>()
                      .services
                      .map((s) => s.category)
                      .toSet()
                      .map(
                        (category) => FilterChip(
                          label: Text(categoryLabel(category)),
                          selected: _specializedCategories.contains(
                            category.name,
                          ),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _specializedCategories.add(category.name);
                            } else {
                              _specializedCategories.remove(category.name);
                            }
                            _error = null;
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
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
