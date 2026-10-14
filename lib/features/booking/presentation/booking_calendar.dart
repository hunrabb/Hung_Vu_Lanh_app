import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class BookingCalendar extends StatefulWidget {
  const BookingCalendar({
    super.key,
    required this.date,
    required this.today,
    required this.onChanged,
    this.enabled = true,
  });
  final DateTime date, today;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;
  @override
  State<BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<BookingCalendar> {
  late DateTime _month = widget.date;
  @override
  void didUpdateWidget(covariant BookingCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) _month = widget.date;
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !widget.enabled,
    child: Theme(
      data: Theme.of(context).copyWith(
        datePickerTheme: DatePickerThemeData(
          todayForegroundColor: const WidgetStatePropertyAll(AppTheme.ink),
          todayBackgroundColor: const WidgetStatePropertyAll(Color(0xFFEDE3D7)),
          todayBorder: const BorderSide(color: AppTheme.primary, width: 2),
          dayStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Tháng ${_month.month}/${_month.year}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          CalendarDatePicker(
            key: ValueKey(widget.date),
            initialDate: widget.date.isBefore(widget.today)
                ? widget.today
                : widget.date,
            currentDate: widget.today,
            firstDate: widget.today,
            lastDate: widget.today.add(const Duration(days: 365)),
            onDateChanged: widget.onChanged,
            onDisplayedMonthChanged: (month) => setState(() => _month = month),
          ),
          const Text(
            'Ngày hiện tại được tô đậm · Giờ Việt Nam',
            style: TextStyle(fontSize: 12, color: Color(0xFF817368)),
          ),
        ],
      ),
    ),
  );
}
