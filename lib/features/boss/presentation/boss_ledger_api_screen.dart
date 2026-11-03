import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_money.dart';
import '../../booking/presentation/api_appointments_screen.dart' show labels;
import '../../reports/application/report_provider.dart';
import 'boss_lux.dart';

/// Boss "Sổ lịch" tab for the live API.
///
/// Reads the same `boss/appointments` report, with the same query and paging,
/// as the screen it replaces; only the presentation changed.
class BossLedgerApiScreen extends StatefulWidget {
  const BossLedgerApiScreen({super.key});
  @override
  State<BossLedgerApiScreen> createState() => _BossLedgerApiScreenState();
}

const _weekdays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

List<Map<String, dynamic>> _asRows(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e),
      ]
    : const [];
Map<String, dynamic>? _asMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

/// Report instants are UTC; the business runs on Hanoi time (UTC+7).
DateTime? _hanoi(Object? v) => v is String
    ? DateTime.tryParse(v)?.toUtc().add(const Duration(hours: 7))
    : null;
String _two(int n) => n.toString().padLeft(2, '0');
String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
String _dmy(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
String _money(Object? v) {
  if (v == null) return '—';
  try {
    return ApiMoney.formatVnd(v);
  } on FormatException {
    return '—';
  }
}

/// "yyyy-MM-dd" (what the API takes) -> "dd/MM/yyyy".
String _isoDay(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}

class _Layout {
  _Layout(double width)
    : gutter = width >= 1000
          ? 32
          : width >= 600
          ? 24
          : 16,
      wide = width >= 700,
      table = width >= 900;
  final double gutter;
  final bool wide, table;
}

class _DayGroup {
  _DayGroup(this.day);
  final DateTime? day;
  final rows = <Map<String, dynamic>>[];
}

class _BossLedgerApiScreenState extends State<BossLedgerApiScreen>
    with AutomaticKeepAliveClientMixin<BossLedgerApiScreen> {
  static const _path = 'boss/appointments';
  static const _pageSize = 50;

  String? _branch, _status, _from, _to;
  int _page = 1, _seenRevision = -1;

  @override
  bool get wantKeepAlive => true;

  Map<String, String> get _query => {
    'branchId': ?_branch,
    'status': ?_status,
    'from': ?_from,
    'to': ?_to,
    'page': '$_page',
    'limit': '$_pageSize',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = context.watch<ReportProvider>();
    if (p.revision != _seenRevision) {
      _seenRevision = p.revision;
      Future.microtask(_load);
    }
  }

  Future<void> _load({bool force = false}) async {
    if (!mounted) return;
    await context.read<ReportProvider>().load(_path, _query, force: force);
  }

  void _changed() {
    setState(() => _page = 1);
    Future.microtask(() => _load(force: true));
  }

  void _goToPage(int page) {
    setState(() => _page = page);
    _load(force: true);
  }

  Future<void> _pickDates() async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: BossLux.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null && mounted) {
      _from = range.start.toIso8601String().substring(0, 10);
      _to = range.end.toIso8601String().substring(0, 10);
      _changed();
    }
  }

  String get _dateLabel {
    final from = _from, to = _to;
    if (from == null || to == null) return 'Tháng này';
    final a = _isoDay(from), b = _isoDay(to);
    // Same year: drop it from the first date to keep the button short.
    return from.substring(0, 4) == to.substring(0, 4)
        ? '${a.substring(0, 5)} – $b'
        : '$a – $b';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.watch<ReportProvider>();
    final s = p.state(_path, _query), d = s.data;
    final rows = _asRows(d?['appointments']);
    return Material(
      color: BossLux.background,
      child: SafeArea(
        child: RefreshIndicator(
          color: BossLux.primary,
          onRefresh: () => _load(force: true),
          child: LayoutBuilder(
            builder: (context, box) {
              final layout = _Layout(box.maxWidth);
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  layout.gutter,
                  layout.wide ? 20 : 12,
                  layout.gutter,
                  32,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(p, s, d, rows, layout),
                          SizedBox(height: layout.wide ? 16 : 12),
                          _statusPills(),
                          SizedBox(
                            height: layout.wide ? 16 : 12,
                            child: s.loading
                                ? const Align(
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                      color: BossLux.secondary,
                                      backgroundColor: BossLux.border,
                                    ),
                                  )
                                : null,
                          ),
                          if (s.error != null) ...[
                            LuxErrorCard(
                              message: s.error!,
                              onRetry: () => _load(force: true),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (d == null && s.loading)
                            const _Skeleton()
                          else if (d != null) ..._list(rows, layout),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- header

  Widget _header(
    ReportProvider p,
    ReportState s,
    Map<String, dynamic>? d,
    List<Map<String, dynamic>> rows,
    _Layout layout,
  ) {
    final period = _asMap(d?['period']);
    final from = _hanoi(period?['from']);
    // The API's upper bound is exclusive (start of the next day).
    final to = _hanoi(period?['to'])?.subtract(const Duration(milliseconds: 1));
    final parts = [
      if (from != null && to != null) '${_dmy(from)} – ${_dmy(to)}',
      if (d != null) '${rows.length} lịch hẹn',
      if (d != null && _page > 1) 'Trang $_page',
    ];
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sổ lịch',
          style: TextStyle(
            fontSize: layout.wide ? 30 : 24,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: BossLux.text,
          ),
        ),
        if (parts.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            parts.join('  ·  '),
            style: const TextStyle(fontSize: 14, color: BossLux.muted),
          ),
        ],
      ],
    );
    final branch = LuxBranchFilter(
      value: _branch,
      names: p.branchNames,
      onChanged: (v) {
        _branch = v;
        _changed();
      },
    );
    final dates = OutlinedButton.icon(
      onPressed: _pickDates,
      icon: const Icon(Icons.calendar_month_outlined, size: 18),
      label: Text(_dateLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: luxOutlinedStyle(),
    );
    final onRefresh = s.loading ? null : () => _load(force: true);
    final refresh = OutlinedButton.icon(
      onPressed: onRefresh,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Cập nhật'),
      style: luxOutlinedStyle(),
    );
    // On narrow screens the refresh button keeps only its icon so the date
    // button always has room for its label.
    final refreshIcon = Tooltip(
      message: 'Cập nhật',
      child: OutlinedButton(
        onPressed: onRefresh,
        style: luxOutlinedStyle(),
        child: const Icon(Icons.refresh, size: 20),
      ),
    );
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    if (layout.table && textScale <= 1.3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: title),
          const SizedBox(width: 16),
          SizedBox(width: 260, child: branch),
          const SizedBox(width: 12),
          SizedBox(height: 48, child: dates),
          const SizedBox(width: 12),
          SizedBox(height: 48, child: refresh),
        ],
      );
    }
    if (layout.wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: branch),
              const SizedBox(width: 12),
              SizedBox(height: 48, child: dates),
              const SizedBox(width: 12),
              SizedBox(height: 48, child: refresh),
            ],
          ),
        ],
      );
    }
    // Narrow screens: one AppBar-like row (title left, actions right) with the
    // branch and period moved into a filter sheet, so the list starts higher.
    final filters = _activeFilters;
    final filterButton = Tooltip(
      message: 'Bộ lọc',
      child: OutlinedButton(
        onPressed: () => _openFilters(p.branchNames),
        style: luxOutlinedStyle(),
        child: Badge(
          isLabelVisible: filters > 0,
          label: Text('$filters'),
          backgroundColor: BossLux.primary,
          textColor: Colors.white,
          child: const Icon(Icons.tune, size: 20),
        ),
      ),
    );
    final branchName = _branch == null ? null : p.branchNames[_branch];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Sổ lịch',
                style: TextStyle(
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: BossLux.text,
                ),
              ),
            ),
            SizedBox(height: 48, width: 48, child: filterButton),
            const SizedBox(width: 8),
            SizedBox(height: 48, width: 48, child: refreshIcon),
          ],
        ),
        // Branch (when filtered) first, then period, count and page.
        _MetaLine(
          parts: [
            ?branchName,
            if (from != null && to != null) '${_dmy(from)} – ${_dmy(to)}',
            if (d != null) '${rows.length} lịch hẹn',
            if (d != null && _page > 1) 'Trang $_page',
          ],
        ),
      ],
    );
  }

  /// Filters that live in the sheet (status pills stay visible on the page).
  int get _activeFilters =>
      (_branch != null ? 1 : 0) + (_from != null && _to != null ? 1 : 0);

  Future<void> _openFilters(Map<String, String> names) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BossLux.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bộ lọc',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: BossLux.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(sheet),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const _FieldLabel('Cơ sở'),
              LuxBranchFilter(
                value: _branch,
                names: names,
                onChanged: (v) {
                  _branch = v;
                  _changed();
                  setSheet(() {});
                },
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Kỳ báo cáo'),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _pickDates();
                    if (sheet.mounted) setSheet(() {});
                  },
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(
                    _dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: luxOutlinedStyle(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(sheet),
                style: FilledButton.styleFrom(
                  backgroundColor: BossLux.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Xong'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPills() {
    void select(String? status) {
      _status = status;
      _changed();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          LuxFilterPill(
            label: 'Tất cả',
            selected: _status == null,
            onTap: () => select(null),
          ),
          for (final e in labels.entries) ...[
            const SizedBox(width: 8),
            LuxFilterPill(
              label: e.value,
              selected: _status == e.key,
              onTap: () => select(e.key),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ list

  List<Widget> _list(List<Map<String, dynamic>> rows, _Layout layout) {
    if (rows.isEmpty) {
      return [
        LuxCard(
          child: LuxNote(
            icon: Icons.event_busy_outlined,
            text: 'Chưa có lịch hẹn nào trong kỳ này.',
            hint: _page > 1
                ? 'Trang này không còn dữ liệu.'
                : 'Thử đổi cơ sở, trạng thái hoặc khoảng ngày.',
          ),
        ),
        ..._pager(rows),
      ];
    }
    // Rows arrive newest first; consecutive rows of one Hanoi day form a group.
    final groups = <_DayGroup>[];
    for (final row in rows) {
      final day = _hanoi(row['startAt']);
      final same =
          groups.isNotEmpty &&
          groups.last.day?.year == day?.year &&
          groups.last.day?.month == day?.month &&
          groups.last.day?.day == day?.day;
      if (!same) groups.add(_DayGroup(day));
      groups.last.rows.add(row);
    }
    return [
      for (final g in groups) ...[
        _DayHeader(day: g.day, count: g.rows.length),
        LuxCard(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (var i = 0; i < g.rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: BossLux.border),
                _LedgerRow(row: g.rows[i], table: layout.table),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
      ..._pager(rows),
    ];
  }

  List<Widget> _pager(List<Map<String, dynamic>> rows) {
    final hasNext = rows.length >= _pageSize;
    if (_page <= 1 && !hasNext) return const [];
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _page <= 1 ? null : () => _goToPage(_page - 1),
            icon: const Icon(Icons.chevron_left, size: 20),
            label: const Text('Trước'),
            style: luxOutlinedStyle(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Trang $_page',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BossLux.text,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: hasNext ? () => _goToPage(_page + 1) : null,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right, size: 20),
            label: const Text('Sau'),
            style: luxOutlinedStyle(),
          ),
        ],
      ),
    ];
  }
}

// ================================================================== widgets

/// Muted summary line whose parts are never broken mid-phrase: when it is too
/// long it wraps between parts, and the separator stays with the part before.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.parts});
  final List<String> parts;
  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) return const SizedBox.shrink();
    const style = TextStyle(fontSize: 14, color: BossLux.muted);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            Text(parts[i], style: style),
            if (i < parts.length - 1) const Text('·', style: style),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: BossLux.muted,
      ),
    ),
  );
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.count});
  final DateTime? day;
  final int count;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 10, left: 4, right: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            day == null ? 'Không rõ ngày' : '${_weekdays[day!.weekday - 1]}, ${_dmy(day!)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: BossLux.text,
            ),
          ),
        ),
        Text(
          '$count lịch',
          style: const TextStyle(fontSize: 13.5, color: BossLux.muted),
        ),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: BossLux.tint,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: BossLux.primary,
      ),
    ),
  );
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.row, required this.table});
  final Map<String, dynamic> row;
  final bool table;
  @override
  Widget build(BuildContext context) {
    final start = _hanoi(row['startAt']), end = _hanoi(row['endAt']);
    final status = '${row['status']}';
    final services = _asRows(row['services'])
        .map((s) => '${s['name']}')
        .where((s) => s != 'null' && s.isNotEmpty)
        .join(', ');
    final staff = row['staffName'] == null ? null : '${row['staffName']}';
    final branch = row['branchName'] == null ? null : '${row['branchName']}';
    // The time column grows with the system text size so it never collides
    // with the customer name.
    final timeWidth = MediaQuery.textScalerOf(context).scale(56);

    final time = SizedBox(
      width: timeWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            start == null ? '—' : _hm(start),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: BossLux.primary,
              fontFeatures: BossLux.figures,
            ),
          ),
          if (end != null)
            Text(
              _hm(end),
              style: const TextStyle(fontSize: 12.5, color: BossLux.muted),
            ),
        ],
      ),
    );
    final customer = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          '${row['customerName'] ?? '—'}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: BossLux.text,
          ),
        ),
        if (row['customerId'] == null) const _Tag('Vãng lai'),
      ],
    );
    const mutedStyle = TextStyle(fontSize: 13, color: BossLux.muted);
    final servicesText = services.isEmpty
        ? null
        : Text(services, style: mutedStyle);
    final chip = LuxStatusChip(status: status, label: labels[status] ?? status);
    final price = Text(
      _money(row['totalPriceVnd']),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: BossLux.text,
        fontFeatures: BossLux.figures,
      ),
    );

    if (table) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            time,
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [customer, ?servicesText],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (staff != null)
                    Text(
                      staff,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: BossLux.text,
                      ),
                    ),
                  if (branch != null) Text(branch, style: mutedStyle),
                ],
              ),
            ),
            const SizedBox(width: 16),
            chip,
            const SizedBox(width: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 120),
              child: Align(alignment: Alignment.centerRight, child: price),
            ),
          ],
        ),
      );
    }
    // Staff and branch are separate wrap children, so a long pair breaks
    // between them rather than in the middle of a name.
    final where = Wrap(
      spacing: 6,
      children: [
        if (staff != null) Text(staff, style: mutedStyle),
        if (staff != null && branch != null) const Text('·', style: mutedStyle),
        if (branch != null) Text(branch, style: mutedStyle),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              time,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    customer,
                    if (staff != null || branch != null) where,
                    ?servicesText,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.only(left: timeWidth),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [chip, price],
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      LuxSkeleton(height: 28),
      SizedBox(height: 12),
      LuxSkeleton(height: 150),
      SizedBox(height: 16),
      LuxSkeleton(height: 150),
    ],
  );
}
