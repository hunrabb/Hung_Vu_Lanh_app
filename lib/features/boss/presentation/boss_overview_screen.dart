import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_money.dart';
import '../../auth/application/auth_controller.dart';
import '../../booking/presentation/api_appointments_screen.dart' show labels;
import '../../reports/application/report_provider.dart';

/// Boss "Tổng quan" tab for the live API.
///
/// Reads the same `boss/dashboard` and `boss/leaderboards` reports (and the same
/// query) the previous screen read; only the presentation changed.
class BossOverviewScreen extends StatefulWidget {
  const BossOverviewScreen({super.key});
  @override
  State<BossOverviewScreen> createState() => _BossOverviewScreenState();
}

abstract final class _Lux {
  static const primary = Color(0xFF594333);
  static const secondary = Color(0xFFA88B55);
  static const background = Color(0xFFF8F6F2);
  static const surface = Colors.white;
  static const text = Color(0xFF302B27);
  // Darkened from the brand #898178 (3.8:1) so secondary text reaches WCAG AA
  // on white (5.5:1) and on the page background (5.1:1).
  static const muted = Color(0xFF70685F);
  static const border = Color(0xFFE8E2D9);
  static const tint = Color(0xFFF3EDE2);
  static const onPrimarySoft = Color(0xFFE6D9C0);
  static const positive = Color(0xFF3E6B4A);
  static const negative = Color(0xFF9A3D32);
  static const radius = 16.0;
  static const shadow = [
    BoxShadow(color: Color(0x0F302B27), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const figures = [FontFeature.tabularFigures()];
}

class _Layout {
  _Layout(double width)
    : gutter = width >= 1000
          ? 32
          : width >= 600
          ? 24
          : 16,
      gap = width >= 600 ? 20 : 16,
      heroRow = width >= 700,
      statColumns = width >= 700 ? 4 : 2,
      rankRow = width >= 900,
      headerRow = width >= 900,
      wide = width >= 700;
  final double gutter, gap;
  final bool heroRow, rankRow, headerRow, wide;
  final int statColumns;
}

Map<String, dynamic>? _asMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;
List<Map<String, dynamic>> _asRows(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e),
      ]
    : const [];
int? _asInt(Object? v) => v is num ? v.toInt() : null;
BigInt? _asMoney(Object? v) {
  if (v == null) return null;
  try {
    return ApiMoney.bigInt(v);
  } on FormatException {
    return null;
  }
}

String _grouped(BigInt n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);
String _num(int? v) => v == null ? '—' : _grouped(BigInt.from(v));
String _vnd(BigInt? v) => v == null ? '—' : '${_grouped(v)} VND';

/// Report instants are UTC; the business runs on Hanoi time (UTC+7).
DateTime? _hanoi(Object? v) => v is String
    ? DateTime.tryParse(v)?.toUtc().add(const Duration(hours: 7))
    : null;
String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class _BossOverviewScreenState extends State<BossOverviewScreen>
    with AutomaticKeepAliveClientMixin<BossOverviewScreen> {
  static const _dashboardPath = 'boss/dashboard';
  static const _boardPath = 'boss/leaderboards';
  static const _previewRows = 5;

  String? _branch;
  int _seenRevision = -1;
  bool _allBranches = false, _allStaff = false, _allUpcoming = false;

  @override
  bool get wantKeepAlive => true;

  Map<String, String> get _query => {'branchId': ?_branch};

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
    final p = context.read<ReportProvider>(), query = _query;
    await p.load(_dashboardPath, query, force: force);
    if (!mounted) return;
    await p.load(_boardPath, query, force: force);
  }

  void _selectBranch(String? id) {
    setState(() {
      _branch = id;
      _allBranches = _allStaff = _allUpcoming = false;
    });
    Future.microtask(() => _load(force: true));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.watch<ReportProvider>();
    final dash = p.state(_dashboardPath, _query);
    final board = p.state(_boardPath, _query);
    final userName = context.watch<AuthController>().currentUser?.name ?? '';
    return Material(
      color: _Lux.background,
      child: SafeArea(
        child: RefreshIndicator(
          color: _Lux.primary,
          onRefresh: () => _load(force: true),
          child: LayoutBuilder(
            builder: (context, box) {
              final layout = _Layout(box.maxWidth);
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  layout.gutter,
                  20,
                  layout.gutter,
                  32,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _sections(
                          p,
                          dash,
                          board,
                          layout,
                          userName,
                        ),
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

  List<Widget> _sections(
    ReportProvider p,
    ReportState dash,
    ReportState board,
    _Layout layout,
    String userName,
  ) {
    final d = dash.data;
    final gap = SizedBox(height: layout.gap);
    return [
      _header(p, d, layout, userName, dash.loading),
      SizedBox(
        height: layout.gap,
        child: Align(
          alignment: Alignment.center,
          child: dash.loading || board.loading
              ? const LinearProgressIndicator(
                  minHeight: 2,
                  color: _Lux.secondary,
                  backgroundColor: _Lux.border,
                )
              : null,
        ),
      ),
      if (dash.error != null) ...[
        _ErrorCard(
          message: dash.error!,
          onRetry: () => _load(force: true),
        ),
        gap,
      ],
      if (d == null && dash.loading) ..._skeleton(layout),
      if (d != null) ..._content(p, d, board, layout, gap),
    ];
  }

  // ---------------------------------------------------------------- header

  Widget _header(
    ReportProvider p,
    Map<String, dynamic>? d,
    _Layout layout,
    String userName,
    bool loading,
  ) {
    final branchName = _branch == null ? null : p.branchNames[_branch];
    final month = _hanoi(_asMap(_asMap(d?['periods'])?['month'])?['from']);
    final today = _hanoi(_asMap(_asMap(d?['periods'])?['day'])?['from']);
    final greeting = userName.isEmpty ? null : 'Xin chào, $userName';
    final period = [
      if (month != null) 'Tháng ${month.month}/${month.year}',
      if (today != null) 'Hôm nay ${today.day}/${today.month}',
    ].join('  ·  ');
    const subtitleStyle = TextStyle(fontSize: 14, color: _Lux.muted);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _branch == null
              ? 'Tổng quan toàn chuỗi'
              : (branchName ?? 'Tổng quan chi nhánh'),
          style: TextStyle(
            fontSize: layout.wide ? 30 : 24,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: _Lux.text,
          ),
        ),
        if (greeting != null || period.isNotEmpty) ...[
          const SizedBox(height: 6),
          // On narrow screens keep the greeting and the period on separate
          // lines so neither is broken mid-phrase.
          if (layout.wide)
            Text(
              [?greeting, if (period.isNotEmpty) period].join('  ·  '),
              style: subtitleStyle,
            )
          else ...[
            if (greeting != null) Text(greeting, style: subtitleStyle),
            if (period.isNotEmpty) Text(period, style: subtitleStyle),
          ],
        ],
      ],
    );
    final filter = _branchFilter(p);
    final refresh = SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: loading ? null : () => _load(force: true),
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Cập nhật'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _Lux.primary,
          backgroundColor: _Lux.surface,
          side: const BorderSide(color: _Lux.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
    if (layout.headerRow) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: titleBlock),
          const SizedBox(width: 16),
          SizedBox(width: 280, child: filter),
          const SizedBox(width: 12),
          refresh,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titleBlock,
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: filter),
            const SizedBox(width: 12),
            refresh,
          ],
        ),
      ],
    );
  }

  Widget _branchFilter(ReportProvider p) {
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return DropdownButtonFormField<String>(
      key: ValueKey(_branch),
      initialValue: _branch,
      isExpanded: true,
      icon: const Icon(Icons.expand_more, color: _Lux.muted),
      style: DefaultTextStyle.of(context).style.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _Lux.text,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: _Lux.surface,
        prefixIcon: const Icon(
          Icons.storefront_outlined,
          size: 20,
          color: _Lux.primary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: outline(_Lux.border),
        enabledBorder: outline(_Lux.border),
        focusedBorder: outline(_Lux.primary, 1.5),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Toàn chuỗi')),
        for (final b in p.branchNames.entries)
          DropdownMenuItem(
            value: b.key,
            child: Text(b.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _selectBranch,
    );
  }

  // --------------------------------------------------------------- content

  List<Widget> _content(
    ReportProvider p,
    Map<String, dynamic> d,
    ReportState board,
    _Layout layout,
    Widget gap,
  ) {
    final today = _asMap(d['today']) ?? const <String, dynamic>{};
    final month = _asMap(d['month']) ?? const <String, dynamic>{};
    final prev = _asMap(d['previousMonth']);
    final monthStart = _hanoi(_asMap(_asMap(d['periods'])?['month'])?['from']);
    final monthLabel = monthStart == null
        ? null
        : 'Tháng ${monthStart.month}/${monthStart.year}';
    final monthCard = _MonthRevenueCard(
      month: month,
      prev: prev,
      label: monthLabel,
    );
    final todayCard = _TodayCard(today: today);
    final stats = _grid([
      _StatTile(
        icon: Icons.calendar_month_outlined,
        label: 'Lịch hẹn',
        value: _num(_asInt(month['appointmentCount'])),
        caption: _prevCaption(prev, 'appointmentCount'),
      ),
      _StatTile(
        icon: Icons.task_alt_outlined,
        label: 'Ca hoàn thành',
        value: _num(_asInt(month['completedCount'])),
        caption: _prevCaption(prev, 'completedCount'),
      ),
      _StatTile(
        icon: Icons.people_outline,
        label: 'Khách hàng',
        value: _num(_asInt(month['customerCount'])),
        caption: _prevCaption(prev, 'customerCount'),
      ),
      _StatTile(
        icon: Icons.directions_walk_outlined,
        label: 'Lượt vãng lai',
        value: _num(_asInt(month['walkInCount'])),
        caption: _prevCaption(prev, 'walkInCount'),
      ),
    ], layout.statColumns, layout.gap);

    final branches = _asRows(board.data?['branches']);
    final staff = _asRows(board.data?['staff']);
    final branchRank = _rankingCard(
      title: 'Top cơ sở theo doanh thu',
      icon: Icons.storefront_outlined,
      board: board,
      rows: branches,
      expanded: _allBranches,
      onToggle: () => setState(() => _allBranches = !_allBranches),
      value: (r) => _asMoney(r['revenueVnd']) ?? BigInt.zero,
      name: (r) => '${r['branchName'] ?? r['branchId'] ?? '—'}',
      subtitle: (r) => '${_num(_asInt(r['completedCount']))} ca hoàn thành',
      trailing: (r) => _vnd(_asMoney(r['revenueVnd'])),
    );
    final staffRank = _rankingCard(
      title: 'Top nhân viên theo số ca',
      icon: Icons.workspace_premium_outlined,
      board: board,
      rows: staff,
      expanded: _allStaff,
      onToggle: () => setState(() => _allStaff = !_allStaff),
      value: (r) => BigInt.from(_asInt(r['completedCount']) ?? 0),
      name: (r) => '${r['staffName'] ?? r['staffId'] ?? '—'}',
      subtitle: (r) => _asRows(r['branches'])
          .map((b) => '${b['branchName'] ?? b['branchId']}')
          .join(', '),
      trailing: (r) => '${_num(_asInt(r['completedCount']))} ca',
    );

    return [
      layout.heroRow
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: monthCard),
                  SizedBox(width: layout.gap),
                  Expanded(flex: 2, child: todayCard),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [monthCard, gap, todayCard],
            ),
      gap,
      Row(
        children: [
          const Expanded(
            child: Text(
              'Thống kê tháng này',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _Lux.text,
              ),
            ),
          ),
          if (monthLabel != null)
            Text(
              monthLabel,
              style: const TextStyle(fontSize: 13.5, color: _Lux.muted),
            ),
        ],
      ),
      const SizedBox(height: 12),
      stats,
      gap,
      layout.rankRow
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: branchRank),
                  SizedBox(width: layout.gap),
                  Expanded(child: staffRank),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [branchRank, gap, staffRank],
            ),
      gap,
      _upcomingCard(d, layout),
      const SizedBox(height: 16),
      const Text(
        'Doanh thu chỉ tính các ca đã hoàn thành. Số lịch hẹn gồm mọi trạng thái.',
        style: TextStyle(fontSize: 12.5, color: _Lux.muted),
      ),
    ];
  }

  String? _prevCaption(Map<String, dynamic>? prev, String key) {
    final v = _asInt(prev?[key]);
    return v == null ? null : 'Tháng trước: ${_num(v)}';
  }

  Widget _grid(List<Widget> items, int columns, double gap) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += columns) {
      final slice = items.sublist(i, math.min(i + columns, items.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) SizedBox(width: gap),
                Expanded(
                  child: j < slice.length ? slice[j] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
      if (i + columns < items.length) rows.add(SizedBox(height: gap));
    }
    return Column(children: rows);
  }

  // -------------------------------------------------------------- rankings

  Widget _rankingCard({
    required String title,
    required IconData icon,
    required ReportState board,
    required List<Map<String, dynamic>> rows,
    required bool expanded,
    required VoidCallback onToggle,
    required BigInt Function(Map<String, dynamic>) value,
    required String Function(Map<String, dynamic>) name,
    required String Function(Map<String, dynamic>) subtitle,
    required String Function(Map<String, dynamic>) trailing,
  }) {
    final shown = expanded ? rows : rows.take(_previewRows).toList();
    final values = rows.map(value).toList();
    final top = values.isEmpty ? BigInt.zero : values.reduce(
      (a, b) => a > b ? a : b,
    );
    Widget body;
    if (board.error != null && rows.isEmpty) {
      body = _InlineNote(
        icon: Icons.error_outline,
        text: board.error!,
        action: 'Thử lại',
        onAction: () => _load(force: true),
      );
    } else if (board.data == null) {
      body = const _SkeletonLines(count: 4);
    } else if (rows.isEmpty) {
      body = const _InlineNote(
        icon: Icons.leaderboard_outlined,
        text: 'Chưa có dữ liệu xếp hạng.',
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _RankRow(
              rank: i + 1,
              name: name(shown[i]),
              subtitle: subtitle(shown[i]),
              trailing: trailing(shown[i]),
              fraction: top == BigInt.zero
                  ? 0
                  : (values[i] * BigInt.from(1000) ~/ top).toInt() / 1000,
            ),
          ],
          if (rows.length > _previewRows) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onToggle,
                style: TextButton.styleFrom(foregroundColor: _Lux.primary),
                child: Text(
                  expanded ? 'Thu gọn' : 'Xem tất cả (${rows.length})',
                ),
              ),
            ),
          ],
        ],
      );
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: title, icon: icon),
          const SizedBox(height: 20),
          body,
        ],
      ),
    );
  }

  // -------------------------------------------------------------- upcoming

  Widget _upcomingCard(Map<String, dynamic> d, _Layout layout) {
    final rows = _asRows(d['upcoming']);
    final shown = _allUpcoming ? rows : rows.take(6).toList();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Lịch hẹn sắp tới hôm nay',
            icon: Icons.event_outlined,
            badge: rows.isEmpty ? null : '${rows.length}',
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const _InlineNote(
              icon: Icons.event_available_outlined,
              text: 'Không còn lịch hẹn nào sắp tới trong hôm nay.',
            )
          else ...[
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: _Lux.border),
              _AppointmentRow(row: shown[i], compact: !layout.wide),
            ],
            if (rows.length > 6) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _allUpcoming = !_allUpcoming),
                style: TextButton.styleFrom(foregroundColor: _Lux.primary),
                child: Text(
                  _allUpcoming ? 'Thu gọn' : 'Xem tất cả (${rows.length})',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _skeleton(_Layout layout) => [
    const _SkeletonCard(height: 190),
    SizedBox(height: layout.gap),
    const _SkeletonCard(height: 120),
    SizedBox(height: layout.gap),
    const _SkeletonCard(height: 260),
  ];
}

// ================================================================== atoms

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = _Lux.surface,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(_Lux.radius),
      border: Border.all(color: color == _Lux.surface ? _Lux.border : color),
      boxShadow: _Lux.shadow,
    ),
    child: child,
  );
}

class _IconChip extends StatelessWidget {
  const _IconChip(this.icon, {this.dark = false});
  final IconData icon;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: dark ? const Color(0x26FFFFFF) : _Lux.tint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, size: 20, color: dark ? Colors.white : _Lux.primary),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon, this.badge});
  final String title;
  final IconData icon;
  final String? badge;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _IconChip(icon),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _Lux.text,
          ),
        ),
      ),
      if (badge != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _Lux.tint,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _Lux.primary,
            ),
          ),
        ),
    ],
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: Container(
      height: 6,
      color: _Lux.tint,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(color: _Lux.secondary),
      ),
    ),
  );
}

class _MoneyText extends StatelessWidget {
  const _MoneyText(this.amount, {required this.size, this.color = _Lux.text});
  final BigInt? amount;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          amount == null ? '—' : _grouped(amount!),
          style: TextStyle(
            fontSize: size,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: color,
            fontFeatures: _Lux.figures,
          ),
        ),
        SizedBox(width: size * 0.25),
        Text(
          'VND',
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w600,
            color: color == _Lux.text ? _Lux.muted : _Lux.onPrimarySoft,
          ),
        ),
      ],
    ),
  );
}

// ============================================================== hero cards

class _MonthRevenueCard extends StatelessWidget {
  const _MonthRevenueCard({
    required this.month,
    required this.prev,
    required this.label,
  });
  final Map<String, dynamic> month;
  final Map<String, dynamic>? prev;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final revenue = _asMoney(month['revenueVnd']);
    final before = _asMoney(prev?['revenueVnd']);
    final hasBaseline = revenue != null && before != null && before > BigInt.zero;
    return _Card(
      color: _Lux.primary,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _IconChip(Icons.trending_up, dark: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Doanh thu tháng này',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (label != null)
                          Text(
                            label!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _Lux.onPrimarySoft,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _MoneyText(revenue, size: 40, color: Colors.white),
            ],
          ),
          const SizedBox(height: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasBaseline) ...[
                Text(
                  'Bằng ${(revenue * BigInt.from(100) ~/ before).toString()}% '
                  'doanh thu tháng trước',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (before != null)
                Text(
                  'Tháng trước: ${_vnd(before)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _Lux.onPrimarySoft,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today});
  final Map<String, dynamic> today;
  @override
  Widget build(BuildContext context) => _Card(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                _IconChip(Icons.payments_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Doanh thu hôm nay',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _Lux.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _MoneyText(_asMoney(today['revenueVnd']), size: 32),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            _MiniStat(
              value: _num(_asInt(today['appointmentCount'])),
              label: 'Lịch hẹn',
            ),
            const _VerticalRule(),
            _MiniStat(
              value: _num(_asInt(today['completedCount'])),
              label: 'Hoàn thành',
            ),
            const _VerticalRule(),
            _MiniStat(
              value: _num(_asInt(today['cancelledCount'])),
              label: 'Đã hủy',
            ),
          ],
        ),
      ],
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _Lux.text,
            fontFeatures: _Lux.figures,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          style: const TextStyle(fontSize: 12.5, color: _Lux.muted),
        ),
      ],
    ),
  );
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: _Lux.border,
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });
  final IconData icon;
  final String label, value;
  final String? caption;
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconChip(icon),
        const SizedBox(height: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: _Lux.text,
              fontFeatures: _Lux.figures,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: _Lux.text,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            style: const TextStyle(fontSize: 12.5, color: _Lux.muted),
          ),
        ],
      ],
    ),
  );
}

// ============================================================ list widgets

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.subtitle,
    required this.trailing,
    required this.fraction,
  });
  final int rank;
  final String name, subtitle, trailing;
  final double fraction;
  @override
  Widget build(BuildContext context) {
    final first = rank == 1;
    // With enlarged system text the value no longer fits beside the name
    // without truncating it, so it moves under the name instead.
    final stacked = MediaQuery.textScalerOf(context).scale(14) / 14 > 1.15;
    final nameText = Text(
      name,
      maxLines: stacked ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _Lux.text,
      ),
    );
    final valueText = Text(
      trailing,
      maxLines: 1,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _Lux.text,
        fontFeatures: _Lux.figures,
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: first ? _Lux.primary : _Lux.tint,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: first ? Colors.white : _Lux.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked) ...[
                nameText,
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: valueText,
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: nameText),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: valueText,
                      ),
                    ),
                  ],
                ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: _Lux.muted),
                ),
              ],
              const SizedBox(height: 8),
              _Bar(value: fraction),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.row, required this.compact});
  final Map<String, dynamic> row;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final start = _hanoi(row['startAt']), end = _hanoi(row['endAt']);
    final status = '${row['status']}';
    final services = _asRows(row['services'])
        .map((s) => '${s['name']}')
        .where((s) => s != 'null' && s.isNotEmpty)
        .join(', ');
    final who = '${row['customerName'] ?? '—'}';
    // The time column grows with the system text size so "17:00" never
    // collides with the customer name.
    final timeWidth = MediaQuery.textScalerOf(context).scale(56);
    final where = [
      if (row['staffName'] != null) '${row['staffName']}',
      if (row['branchName'] != null) '${row['branchName']}',
    ].join('  ·  ');
    final price = Text(
      _vnd(_asMoney(row['totalPriceVnd'])),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _Lux.text,
        fontFeatures: _Lux.figures,
      ),
    );
    final chip = _StatusChip(status);
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
              color: _Lux.primary,
              fontFeatures: _Lux.figures,
            ),
          ),
          if (end != null)
            Text(
              _hm(end),
              style: const TextStyle(fontSize: 12.5, color: _Lux.muted),
            ),
        ],
      ),
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          who,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _Lux.text,
          ),
        ),
        if (where.isNotEmpty)
          Text(
            where,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: _Lux.muted),
          ),
        if (services.isNotEmpty)
          Text(
            services,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: _Lux.muted),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [time, Expanded(child: info)],
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
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                time,
                const SizedBox(width: 8),
                Expanded(child: info),
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
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'completed' => (const Color(0xFFE4EEE6), _Lux.positive),
      'cancelled' => (const Color(0xFFF5E3E0), _Lux.negative),
      'pending' => (const Color(0xFFFBF0D9), const Color(0xFF86590B)),
      'noShow' => (const Color(0xFFECE8E2), const Color(0xFF5F5850)),
      _ => (_Lux.tint, _Lux.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        labels[status] ?? status,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// =========================================================== state widgets

class _InlineNote extends StatelessWidget {
  const _InlineNote({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Icon(icon, size: 28, color: _Lux.muted),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _Lux.muted),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: _Lux.primary),
              child: Text(action!),
            ),
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFBF1EF),
      borderRadius: BorderRadius.circular(_Lux.radius),
      border: Border.all(color: const Color(0xFFEBCFCA)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: _Lux.negative),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 14, color: _Lux.text),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(foregroundColor: _Lux.negative),
          child: const Text('Thử lại'),
        ),
      ],
    ),
  );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFEFEAE1),
      borderRadius: BorderRadius.circular(_Lux.radius),
    ),
  );
}

class _SkeletonLines extends StatelessWidget {
  const _SkeletonLines({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < count; i++)
        Container(
          height: 36,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFEAE1),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
    ],
  );
}
