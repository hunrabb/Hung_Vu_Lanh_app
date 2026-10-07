import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_user.dart';
import '../../catalog/application/service_provider.dart';
import '../../users/application/user_provider.dart';
import '../application/appointment_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../../branches/application/branch_provider.dart';
import 'api_booking_screen.dart';

class CustomerBookingScreen extends StatefulWidget {
  const CustomerBookingScreen({
    super.key,
    this.walkIn = false,
    this.initialBranchId,
  });
  final bool walkIn;
  final String? initialBranchId;
  @override
  State<CustomerBookingScreen> createState() => _CustomerBookingScreenState();
}

class _CustomerBookingScreenState extends State<CustomerBookingScreen> {
  String? _serviceId, _staffId;
  late String? _branchId = widget.initialBranchId;
  DateTime? _date, _start;
  String? _error;
  final _contact = TextEditingController();

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  String _time(DateTime instant) {
    final local = instant.toUtc().add(const Duration(hours: 7));
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final today = context.read<AppointmentProvider>().today;
    final date = await showDatePicker(
      context: context,
      initialDate: _date != null && !_date!.isBefore(today) ? _date! : today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      setState(() {
        _date = date;
        _start = null;
        _error = null;
      });
    }
  }

  void _book() {
    final user = context.read<AuthController>().currentUser;
    final branchId = widget.walkIn ? user?.branchId : _branchId;
    if (user == null ||
        branchId == null ||
        context.read<BranchProvider>().getById(branchId) == null ||
        (!widget.walkIn && user.role != UserRole.customer)) {
      setState(() => _error = 'Vui lòng đăng nhập và chọn cơ sở hợp lệ.');
      return;
    }
    if (widget.walkIn && _contact.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập Tên / SĐT Khách hàng.');
      return;
    }
    if (widget.walkIn &&
        context.read<AuthController>().currentUser?.role != UserRole.manager) {
      setState(() => _error = 'Chỉ Manager được tạo lịch nhanh.');
      return;
    }
    try {
      context.read<AppointmentProvider>().book(
        customerId: widget.walkIn ? 'walk-in' : user.id,
        branchId: branchId,
        customerName: widget.walkIn ? _contact.text : '',
        staffId: _staffId!,
        serviceId: _serviceId!,
        startAt: _start!,
      );
      setState(() {
        _start = null;
        _error = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đặt lịch thành công!')));
      if (widget.walkIn) Navigator.pop(context);
    } on StateError catch (error) {
      setState(() {
        _start = null;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().isRemote) {
      return ApiBookingScreen(
        walkIn: widget.walkIn,
        initialBranchId: widget.initialBranchId,
      );
    }
    final branches = context.watch<BranchProvider>().branches;
    final user = context.watch<AuthController>().currentUser;
    final requestedBranch = widget.walkIn ? user?.branchId : _branchId;
    final branchId = branches.any((b) => b.id == requestedBranch)
        ? requestedBranch
        : null;
    final services = context
        .watch<ServiceProvider>()
        .services
        .where((s) => s.isActive)
        .toList();
    final booking = context.watch<AppointmentProvider>();
    final serviceId = services.any((s) => s.id == _serviceId)
        ? _serviceId
        : null;
    final categoryId = serviceId == null
        ? null
        : services.firstWhere((s) => s.id == serviceId).categoryId;
    final staff = context
        .watch<UserProvider>()
        .users
        .where(
          (u) =>
              u.role == UserRole.staff &&
              u.isApproved &&
              u.branchId == branchId &&
              categoryId != null &&
              u.specializedCategoryIds.contains(categoryId),
        )
        .toList();
    final staffId = staff.any((s) => s.id == _staffId) ? _staffId : null;
    final date = _date ?? booking.today;
    final slots = serviceId != null && staffId != null
        ? booking.availableSlots(
            staffId: staffId,
            serviceId: serviceId,
            date: date,
            branchId: branchId,
          )
        : [];
    final selected = slots.any((slot) => slot.start == _start);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(widget.walkIn ? 'Tạo lịch nhanh' : 'Đặt lịch'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('branch-$branchId'),
              initialValue: branchId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cơ sở tại Hà Nội'),
              items: branches
                  .map(
                    (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                  )
                  .toList(),
              onChanged: widget.walkIn
                  ? null
                  : (value) => setState(() {
                      _branchId = value;
                      _staffId = null;
                      _start = null;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 20),
            if (widget.walkIn) ...[
              TextField(
                controller: _contact,
                decoration: const InputDecoration(
                  labelText: 'Tên / SĐT Khách hàng',
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (services.isEmpty) const Text('Chưa có dịch vụ đang hoạt động.'),
            DropdownButtonFormField<String>(
              key: ValueKey('service-$serviceId'),
              initialValue: serviceId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Dịch vụ'),
              items: services
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        '${s.name} · ${s.durationMinutes} phút',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: branchId == null
                  ? null
                  : (value) => setState(() {
                      _serviceId = value;
                      _staffId = null;
                      _start = null;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 20),
            if (branchId == null)
              const Text('Vui lòng chọn cơ sở trước.')
            else if (serviceId == null)
              const Text('Chọn dịch vụ trước khi chọn thợ.')
            else if (staff.isEmpty)
              const Text('Chưa có nhân viên phù hợp với dịch vụ này.'),
            DropdownButtonFormField<String>(
              key: ValueKey('staff-$serviceId-$staffId'),
              initialValue: staffId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Chọn thợ'),
              items: staff
                  .map(
                    (u) => DropdownMenuItem(value: u.id, child: Text(u.name)),
                  )
                  .toList(),
              onChanged: branchId == null || serviceId == null || staff.isEmpty
                  ? null
                  : (value) => setState(() {
                      _staffId = value;
                      _start = null;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text('${date.day}/${date.month}/${date.year}'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Giờ trống (giờ Việt Nam)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (serviceId == null || staffId == null)
              const Text('Chọn dịch vụ và thợ để xem giờ trống.')
            else if (slots.isEmpty)
              const Text('Không còn giờ trống trong ngày này.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots
                    .map<Widget>(
                      (slot) => ChoiceChip(
                        label: Text(
                          '${_time(slot.start)} – ${_time(slot.end)}',
                        ),
                        selected: slot.start == _start,
                        onSelected: (value) => setState(() {
                          _start = value ? slot.start : null;
                          _error = null;
                        }),
                      ),
                    )
                    .toList(),
              ),
            if (serviceId != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Tổng tiền: ${services.firstWhere((s) => s.id == serviceId).priceVnd}đ',
                ),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: selected && serviceId != null && staffId != null
                  ? _book
                  : null,
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
  }
}
