import '../../../core/models/service.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_user.dart';
import '../../catalog/application/service_provider.dart';
import '../../users/application/user_provider.dart';
import '../application/appointment_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../../branches/application/branch_provider.dart';
import 'api_booking_screen.dart';
import 'booking_layout.dart';
import 'booking_calendar.dart';
import '../../../core/network/api_money.dart';
import '../../../core/routing/app_routes.dart';

class CustomerBookingScreen extends StatefulWidget {
  const CustomerBookingScreen({
    super.key,
    this.walkIn = false,
    this.initialBranchId,
    this.initialServiceId,
  });
  final bool walkIn;
  final String? initialBranchId;
  final String? initialServiceId;
  @override
  State<CustomerBookingScreen> createState() => _CustomerBookingScreenState();
}

class _CustomerBookingScreenState extends State<CustomerBookingScreen> {
  late String? _serviceId = widget.initialServiceId;
  String? _staffId;
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
      if (widget.walkIn) {
        Navigator.pop(context);
      } else {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.customerHome, (_) => false);
      }
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
        initialServiceId: widget.initialServiceId,
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
        .where((s) => s.isActive && s.category != ServiceCategory.shaving)
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
    return BookingLayout(
      walkIn: widget.walkIn,
      price: serviceId == null
          ? null
          : ApiMoney.formatVnd(
              services.firstWhere((s) => s.id == serviceId).priceVnd.toString(),
            ),
      summary: selected
          ? '${date.day}/${date.month}/${date.year} · ${_time(_start!)}'
          : null,
      confirm: FilledButton(
        onPressed: selected && serviceId != null && staffId != null
            ? _book
            : null,
        child: const Text('Xác nhận'),
      ),
      children: [
        BookingSection(
          number: '01',
          title: 'Chọn không gian của bạn',
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('branch-$branchId'),
              initialValue: branchId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Cơ sở tại Hà Nội',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              items: branches
                  .map(
                    (b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                    ),
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
            if (widget.walkIn) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _contact,
                decoration: const InputDecoration(
                  labelText: 'Tên / SĐT Khách hàng',
                ),
              ),
            ],
          ],
        ),
        BookingSection(
          number: '02',
          title: 'Dịch vụ & chuyên viên',
          children: [
            if (services.isEmpty) const Text('Chưa có dịch vụ đang hoạt động.'),
            DropdownButtonFormField<String>(
              key: ValueKey('service-$serviceId'),
              initialValue: serviceId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Dịch vụ',
                prefixIcon: Icon(Icons.content_cut_outlined),
              ),
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
            if (branchId == null || serviceId == null || staff.isEmpty)
              const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('staff-$serviceId-$staffId'),
              initialValue: staffId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Chọn thợ',
                prefixIcon: Icon(Icons.person_outline),
              ),
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
          ],
        ),
        BookingSection(
          number: '03',
          title: 'Ngày & giờ hẹn',
          children: [
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
            BookingCalendar(
              date: date,
              today: booking.today,
              onChanged: (day) {
                setState(() {
                  _date = day;
                  _start = null;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 12),
            if (serviceId == null || staffId == null)
              const BookingNotice('Chọn dịch vụ và thợ để xem giờ trống.')
            else if (slots.isEmpty)
              const BookingNotice('Không còn giờ trống trong ngày này.')
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
          ],
        ),
        if (_error != null) BookingNotice(_error!, error: true),
      ],
    );
  }
}
