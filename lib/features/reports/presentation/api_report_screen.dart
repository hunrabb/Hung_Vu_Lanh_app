import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_money.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/application/auth_controller.dart';
import '../../booking/presentation/customer_booking_screen.dart';
import '../../booking/presentation/api_appointments_screen.dart';
import '../../workspace/presentation/workspace_screen.dart' show stamp;
import '../application/report_provider.dart';

enum ReportKind {
  managerDashboard,
  managerRevenue,
  bossDashboard,
  bossLedger,
  bossCommissions,
  staffEarnings,
  staffCustomers,
}

class ApiReportScreen extends StatefulWidget {
  const ApiReportScreen({
    super.key,
    required this.kind,
    this.onAddStaff,
    this.onManageServices,
  });
  final ReportKind kind;
  final VoidCallback? onAddStaff, onManageServices;
  @override
  State<ApiReportScreen> createState() => _ApiReportScreenState();
}

class _ApiReportScreenState extends State<ApiReportScreen> {
  String? _branch, _status, _from, _to;
  int _page = 1, _seenRevision = -1;
  String get _path => switch (widget.kind) {
    ReportKind.managerDashboard => 'manager/dashboard',
    ReportKind.managerRevenue => 'manager/revenue',
    ReportKind.bossDashboard => 'boss/dashboard',
    ReportKind.bossLedger => 'boss/appointments',
    ReportKind.bossCommissions => 'boss/commissions',
    ReportKind.staffEarnings => 'staff/me/earnings',
    ReportKind.staffCustomers => 'staff/me/profile-stats',
  };
  bool get _boss => widget.kind.name.startsWith('boss');
  Map<String, String> get _query => {
    if (_boss && _branch != null) 'branchId': _branch!,
    if (_status != null && widget.kind == ReportKind.bossLedger)
      'status': _status!,
    if (widget.kind != ReportKind.bossDashboard &&
        widget.kind != ReportKind.managerDashboard) ...{
      'from': ?_from,
      'to': ?_to,
      'page': '$_page',
      'limit': '50',
    },
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
    final p = context.read<ReportProvider>(), path = _path, query = _query;
    await p.load(path, query, force: force);
    if (!mounted) return;
    if (widget.kind == ReportKind.bossDashboard) {
      await p.load('boss/leaderboards', query, force: force);
    }
    if (widget.kind == ReportKind.managerDashboard) {
      await p.load('manager/revenue', {}, force: force);
    }
  }

  void _changed() {
    setState(() => _page = 1);
    Future.microtask(() => _load(force: true));
  }

  Future<void> _dates() async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );
    if (range != null && mounted) {
      _from = range.start.toIso8601String().substring(0, 10);
      _to = range.end.toIso8601String().substring(0, 10);
      _changed();
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = c.watch<ReportProvider>(), s = p.state(_path, _query), d = s.data;
    final name = c.watch<AuthController>().currentUser?.name ?? '';
    final title = switch (widget.kind) {
      ReportKind.managerDashboard =>
        'Tổng quan — ${p.branchNames[c.read<AuthController>().currentUser?.branchId] ?? 'Cơ sở của bạn'}',
      ReportKind.managerRevenue => 'Báo cáo Doanh số',
      ReportKind.bossDashboard => 'Tổng quan toàn chuỗi',
      ReportKind.bossLedger => 'Sổ cái',
      ReportKind.bossCommissions => 'Hoa hồng tạm tính 30%',
      ReportKind.staffEarnings => 'Doanh số cá nhân',
      ReportKind.staffCustomers => 'Khách hàng của tôi',
    };
    final body = RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF30251F),
            ),
          ),
          Text(name, style: const TextStyle(color: Color(0xFF817368))),
          Row(
            children: [
              TextButton.icon(
                onPressed: s.loading ? null : () => _load(force: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Cập nhật'),
              ),
              if (widget.kind != ReportKind.managerDashboard &&
                  widget.kind != ReportKind.bossDashboard &&
                  widget.kind != ReportKind.staffCustomers)
                TextButton(
                  onPressed: _dates,
                  child: Text(_from == null ? 'Tháng này' : '$_from → $_to'),
                ),
            ],
          ),
          if (_boss)
            DropdownButtonFormField<String>(
              key: ValueKey(_branch),
              initialValue: _branch,
              decoration: const InputDecoration(labelText: 'Cơ sở'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Toàn chuỗi')),
                for (final b in p.branchNames.entries)
                  DropdownMenuItem(value: b.key, child: Text(b.value)),
              ],
              onChanged: (value) {
                _branch = value;
                _changed();
              },
            ),
          if (widget.kind == ReportKind.bossLedger)
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tất cả')),
                for (final e in labels.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (value) {
                _status = value;
                _changed();
              },
            ),
          if (s.loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (s.error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(s.error!),
                    TextButton(
                      onPressed: () => _load(force: true),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
          if (d != null) ..._content(c, p, d),
          if (widget.kind == ReportKind.managerDashboard) ...[
            FilledButton.icon(
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => const CustomerBookingScreen(walkIn: true),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Tạo lịch nhanh'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(c, AppRoutes.managerRevenue),
              icon: const Icon(Icons.bar_chart),
              label: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Báo cáo Doanh số'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute<void>(
                  builder: (_) => const ApiAppointmentsScreen(),
                ),
              ),
              child: const Text('Quản lý lịch hẹn'),
            ),
            Wrap(
              children: [
                TextButton(
                  onPressed: widget.onAddStaff,
                  child: const Text('Thêm nhân viên'),
                ),
                TextButton(
                  onPressed: widget.onManageServices,
                  child: const Text('Quản lý dịch vụ'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    return widget.kind == ReportKind.managerRevenue
        ? Scaffold(
            appBar: AppBar(title: const Text('Báo cáo Doanh số')),
            body: body,
          )
        : SafeArea(
            child: Material(color: const Color(0xFFFAF8F4), child: body),
          );
  }

  List<Widget> _content(
    BuildContext c,
    ReportProvider p,
    Map<String, dynamic> d,
  ) {
    if (widget.kind == ReportKind.bossLedger) {
      return [
        _ledger(d['appointments'] as List),
        ..._pager(d['appointments'] as List),
      ];
    }
    if (widget.kind == ReportKind.bossCommissions) {
      return [
        const Text('Tạm tính trên doanh thu completed, chưa chi trả.'),
        _ranking(d['staff'] as List, amount: 'commissionVnd'),
        ..._pager(d['staff'] as List),
      ];
    }
    if (widget.kind == ReportKind.staffCustomers) {
      return [
        _metric('Khách có tài khoản', '${d['registeredCustomerCount']}'),
        _metric('Ca khách vãng lai', '${d['walkInCompletedCount']}'),
        for (final row in d['customers'] as List)
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['customerName'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('${row['completedVisits']} lần ghé'),
                Text(
                  'Tổng chi tiêu: ${ApiMoney.formatVnd(row['totalSpentVnd'])}',
                ),
                Text(
                  'Gần nhất: ${stamp(DateTime.parse(row['lastVisitAt'] as String))}',
                ),
              ],
            ),
          ),
        ..._pager(d['customers'] as List),
      ];
    }
    final widgets = <Widget>[];
    if (d['today'] != null) {
      final t = d['today'] as Map, m = d['month'] as Map;
      widgets.addAll([
        _metric('Doanh thu hôm nay', ApiMoney.formatVnd(t['revenueVnd'])),
        Row(
          children: [
            Expanded(
              child: _metric(
                widget.kind == ReportKind.staffEarnings
                    ? 'Ca hoàn thành hôm nay'
                    : 'Lịch hôm nay',
                '${widget.kind == ReportKind.staffEarnings ? t['completedCount'] : t['appointmentCount']}',
              ),
            ),
            Expanded(child: _metric('Đã hủy', '${t['cancelledCount']}')),
          ],
        ),
        _metric('Doanh thu tháng này', ApiMoney.formatVnd(m['revenueVnd'])),
        if (widget.kind == ReportKind.bossDashboard)
          _metric('Lịch tháng này', '${m['appointmentCount']}'),
        _metric('Ca completed tháng này', '${m['completedCount']}'),
      ]);
    }
    if (d['revenueVnd'] != null) {
      widgets.add(
        _metric('Tổng doanh thu', ApiMoney.formatVnd(d['revenueVnd'])),
      );
    }
    if (d['staffRanking'] != null) {
      widgets.add(_ranking(d['staffRanking'] as List));
    }
    if (d['transactions'] != null) {
      widgets.addAll([
        const Text('Giao dịch hoàn thành'),
        _ledger(d['transactions'] as List),
        ..._pager(d['transactions'] as List),
      ]);
    }
    if (d['upcoming'] != null) {
      widgets.addAll([
        const Text('Lịch hẹn sắp tới hôm nay'),
        _ledger(d['upcoming'] as List),
      ]);
    }
    if (widget.kind == ReportKind.bossDashboard) {
      final state = p.state('boss/leaderboards', _query);
      if (state.loading) widgets.add(const LinearProgressIndicator());
      if (state.error != null) widgets.add(Text(state.error!));
      if (state.data != null) {
        widgets.addAll([
          const Text('Top cơ sở theo doanh thu'),
          _ranking(state.data!['branches'] as List),
          const Text('Top Staff theo số ca'),
          _ranking(state.data!['staff'] as List, byCount: true),
        ]);
      }
    }
    if (widget.kind == ReportKind.managerDashboard) {
      final state = p.state('manager/revenue', {});
      if (state.loading) widgets.add(const LinearProgressIndicator());
      if (state.error != null) widgets.add(Text(state.error!));
      if (state.data != null) {
        widgets.addAll([
          const Text('Doanh thu theo Staff · tháng này'),
          _ranking(state.data!['staffRanking'] as List),
        ]);
      }
    }
    return widgets;
  }

  List<Widget> _pager(List rows) => [
    Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _page <= 1
              ? null
              : () {
                  setState(() => _page--);
                  _load(force: true);
                },
          child: const Text('Trước'),
        ),
        Text('Trang $_page'),
        TextButton(
          onPressed: rows.length < 50
              ? null
              : () {
                  setState(() => _page++);
                  _load(force: true);
                },
          child: const Text('Sau'),
        ),
      ],
    ),
  ];
  Widget _panel(Widget child) => Card(
    elevation: 0,
    color: const Color(0xFFFFFDFC),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE7E0D6)),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
  Widget _metric(String label, String value) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF817368))),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: Color(0xFF30251F),
          ),
        ),
      ],
    ),
  );
  Widget _ledger(List rows) => rows.isEmpty
      ? const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Chưa có giao dịch trong kỳ.'),
        )
      : Column(
          children: [
            for (final r in rows)
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r['customerName']} · ${r['staffName']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(r['branchName'] as String),
                    Text(
                      (r['services'] as List).map((s) => s['name']).join(', '),
                    ),
                    Text(stamp(DateTime.parse(r['startAt'] as String))),
                    Text(
                      '${labels[r['status']] ?? r['status']} · ${ApiMoney.formatVnd(r['totalPriceVnd'])}',
                    ),
                  ],
                ),
              ),
          ],
        );
  Widget _ranking(
    List rows, {
    String amount = 'revenueVnd',
    bool byCount = false,
  }) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Chưa có dữ liệu xếp hạng.'),
      );
    }
    final values = rows
        .map(
          (r) => byCount
              ? BigInt.from(r['completedCount'] as int)
              : ApiMoney.bigInt(r[amount]),
        )
        .toList();
    final max = values.reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ${rows[i]['staffName'] ?? rows[i]['branchName']}',
                ),
                Text(
                  byCount
                      ? '${rows[i]['completedCount']} ca'
                      : ApiMoney.formatVnd(rows[i][amount]),
                ),
                if (rows[i]['branches'] != null)
                  Text(
                    (rows[i]['branches'] as List)
                        .map((b) => b['branchName'])
                        .join(', '),
                  ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: max == BigInt.zero
                      ? 0
                      : (values[i] * BigInt.from(1000) ~/ max).toInt() / 1000,
                  color: const Color(0xFFA58B58),
                  backgroundColor: const Color(0xFFF0E9DF),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
