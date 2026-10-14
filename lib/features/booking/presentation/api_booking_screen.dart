import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_money.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/application/auth_controller.dart';
import '../../workspace/presentation/workspace_screen.dart' show stamp, hanoi;
import '../application/api_appointment_provider.dart';
import 'booking_layout.dart';
import 'booking_calendar.dart';

const bookingConflict =
    'Khung giờ này vừa có người đặt, vui lòng chọn giờ khác!';

class ApiBookingScreen extends StatefulWidget {
  const ApiBookingScreen({
    super.key,
    this.walkIn = false,
    this.initialBranchId,
    this.initialServiceId,
  });
  final bool walkIn;
  final String? initialBranchId;
  final String? initialServiceId;
  @override
  State<ApiBookingScreen> createState() => _ApiBookingScreenState();
}

class _ApiBookingScreenState extends State<ApiBookingScreen> {
  String? _branch, _service, _staff, _start, _error;
  List<Map<String, dynamic>> _people = [], _slots = [];
  bool _loading = true, _sending = false;
  int _selection = 0;
  late DateTime _date;
  final _contact = TextEditingController();
  @override
  void initState() {
    super.initState();
    _branch = widget.initialBranchId;
    _service = widget.initialServiceId;
    final now = hanoi(DateTime.now());
    _date = DateTime(now.year, now.month, now.day);
    Future.microtask(_init);
  }

  Future<void> _init() async {
    try {
      await context.read<ApiAppointmentProvider>().catalog();
      if (!mounted) return;
      final p = context.read<ApiAppointmentProvider>();
      if (!p.services.any(
        (s) => s['id'] == _service && s['categoryId'] != 'shaving',
      )) {
        _service = null;
      }
      if (_branch != null && _service != null) await _select();
    } catch (e) {
      if (mounted) _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _selection++;
    _contact.dispose();
    super.dispose();
  }

  Future<void> _select({bool staffChanged = false}) async {
    final token = ++_selection;
    setState(() {
      _start = null;
      _slots = [];
      _error = null;
      _loading = true;
      if (!staffChanged) {
        _staff = null;
        _people = [];
      }
    });
    final p = context.read<ApiAppointmentProvider>();
    final branch = widget.walkIn
        ? context.read<AuthController>().currentUser?.branchId
        : _branch;
    try {
      if (branch != null && _service != null) {
        if (!staffChanged) {
          final people = await p.repo.staff(branch, _service!);
          if (!mounted || token != _selection) return;
          _people = people;
          for (final s in people) {
            p.staffNames[s['id'] as String] = s['name'] as String;
          }
        }
        if (_staff != null) {
          final slots = await p.repo.slots(
            branch,
            _staff!,
            _service!,
            _date.toIso8601String().substring(0, 10),
          );
          if (!mounted || token != _selection) return;
          _slots = slots;
        }
      }
    } catch (e) {
      if (mounted && token == _selection) _error = e.toString();
    } finally {
      if (mounted && token == _selection) setState(() => _loading = false);
    }
  }

  Future<void> _book() async {
    if (_sending || _start == null) return;
    if (widget.walkIn && _contact.text.trim().isEmpty) {
      setState(() => _error = 'Nhập Tên / SĐT khách hàng.');
      return;
    }
    final p = context.read<ApiAppointmentProvider>(),
        auth = context.read<AuthController>();
    final user = auth.currentUser;
    final branch = widget.walkIn ? user?.branchId : _branch;
    final owner = user?.id;
    if (branch == null || owner == null) return;
    final sessionRevision = p.repo.api.tokens.revision;
    bool currentSession() =>
        mounted &&
        auth.currentUser?.id == owner &&
        p.repo.api.tokens.revision == sessionRevision;
    setState(() => _sending = true);
    try {
      final created = await p.repo.book(
        branch: branch,
        staff: _staff!,
        service: _service!,
        start: _start!,
        walkIn: widget.walkIn,
        contact: _contact.text,
      );
      if (!mounted || !currentSession()) return;
      p.acceptBooking(created);
      await p.refresh();
      if (!mounted || !currentSession()) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đặt lịch thành công!')));
      if (widget.walkIn) {
        Navigator.pop(context);
      } else {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.customerHome, (_) => false);
      }
    } on ApiException catch (e) {
      if (!mounted || !currentSession()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.statusCode == 409 ? bookingConflict : e.message),
        ),
      );
      if (e.statusCode == 409) await _select(staffChanged: true);
    } catch (_) {
      if (mounted && currentSession()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể đặt lịch. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (currentSession()) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = c.watch<ApiAppointmentProvider>();
    final branch = widget.walkIn
        ? c.watch<AuthController>().currentUser?.branchId
        : _branch;
    final chosenServices = p.services.where((s) => s['id'] == _service);
    final service = chosenServices.isEmpty ? null : chosenServices.first;
    return BookingLayout(
      walkIn: widget.walkIn,
      price: service == null ? null : ApiMoney.formatVnd(service['price']),
      summary: _start == null ? null : stamp(DateTime.parse(_start!)),
      confirm: FilledButton(
        onPressed: _sending || _loading || _start == null ? null : _book,
        child: _sending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Xác nhận đặt lịch'),
      ),
      children: [
        BookingSection(
          number: '01',
          title: 'Chọn không gian của bạn',
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('branch-$branch'),
              initialValue: p.branches.any((b) => b['id'] == branch)
                  ? branch
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Cơ sở tại Hà Nội',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              items: p.branches
                  .map(
                    (b) => DropdownMenuItem(
                      value: b['id'] as String,
                      child: Text(
                        b['name'] as String,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: widget.walkIn || _sending
                  ? null
                  : (id) {
                      _branch = id;
                      _select();
                    },
            ),
            if (widget.walkIn) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _contact,
                enabled: !_sending,
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
            DropdownButtonFormField<String>(
              initialValue: _service,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Dịch vụ',
                prefixIcon: Icon(Icons.content_cut_outlined),
              ),
              items: p.services
                  .where((s) => s['categoryId'] != 'shaving')
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(
                        '${s['name']} · ${ApiMoney.formatVnd(s['price'])} · ${s['duration']} phút',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: branch == null || _sending
                  ? null
                  : (id) {
                      _service = id;
                      _select();
                    },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              key: ValueKey('staff-$_staff-$_service-$branch'),
              initialValue: _staff,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Chọn thợ',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: _people
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(s['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: _loading || _sending || _service == null
                  ? null
                  : (id) {
                      _staff = id;
                      _select(staffChanged: true);
                    },
            ),
          ],
        ),
        BookingSection(
          number: '03',
          title: 'Ngày & giờ hẹn',
          children: [
            OutlinedButton.icon(
              onPressed: _sending
                  ? null
                  : () async {
                      final today = hanoi(DateTime.now());
                      final day = DateTime(today.year, today.month, today.day);
                      final date = await showDatePicker(
                        context: c,
                        initialDate: _date,
                        firstDate: day,
                        lastDate: day.add(const Duration(days: 365)),
                      );
                      if (date != null && mounted) {
                        _date = date;
                        await _select(staffChanged: true);
                      }
                    },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Ngày: ${_date.day}/${_date.month}/${_date.year}'),
            ),
            const SizedBox(height: 18),
            BookingCalendar(
              date: _date,
              today: DateUtils.dateOnly(hanoi(DateTime.now())),
              enabled: !_sending,
              onChanged: (day) {
                _date = day;
                _select(staffChanged: true);
              },
            ),
            const Text(
              'Giờ trống (giờ Việt Nam)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) BookingNotice(_error!, error: true),
            if (_error != null)
              TextButton(
                onPressed: _sending
                    ? null
                    : () async {
                        await _init();
                        if (mounted && _service != null) {
                          await _select(staffChanged: true);
                        }
                      },
                child: const Text('Thử lại'),
              ),
            if (!_loading && _staff != null && _slots.isEmpty)
              const BookingNotice(
                'Không có khung giờ trống. Hãy chọn ngày hoặc thợ khác.',
              ),
            if (!_loading && _staff == null)
              const BookingNotice('Chọn dịch vụ và thợ để xem giờ trống.'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slots
                  .map(
                    (s) => ChoiceChip(
                      label: Text(
                        stamp(DateTime.parse(s['startAt'] as String)),
                      ),
                      selected: _start == s['startAt'],
                      onSelected: _sending
                          ? null
                          : (_) =>
                                setState(() => _start = s['startAt'] as String),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ],
    );
  }
}
