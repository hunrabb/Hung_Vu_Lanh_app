import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schedula Spa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _DashboardColors.teal),
        scaffoldBackgroundColor: _DashboardColors.canvas,
        fontFamily: 'Arial',
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 26),
                    _buildSectionTitle('Tổng quan hôm nay', 'Báo cáo chi tiết'),
                    const SizedBox(height: 16),
                    _buildOverviewGrid(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Thao tác nhanh', null),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      'Lịch hẹn sắp tới',
                      'Xem tất cả',
                      badge: '3',
                    ),
                    const SizedBox(height: 16),
                    _AppointmentCard(
                      name: 'Nguyễn Thảo My',
                      service: 'Chăm sóc da chuyên sâu 90p',
                      time: '10:30 - 12:00',
                      staff: 'Lan Anh (Giường 02)',
                      status: 'Đang diễn ra',
                      accent: _DashboardColors.teal,
                      icon: Icons.phone_in_talk_outlined,
                    ),
                    const SizedBox(height: 16),
                    _AppointmentCard(
                      name: 'Trần Minh Quân',
                      service: 'Cắt gội & Phục hồi tóc keratin',
                      time: '13:00 - 14:00',
                      staff: 'Quốc Bảo (Ghế 01)',
                      status: 'Sắp tới',
                      accent: _DashboardColors.blue,
                      icon: Icons.chat_bubble_outline,
                    ),
                    const SizedBox(height: 16),
                    _AppointmentCard(
                      name: 'Lê Hoàng Yến',
                      service: 'Combo Nail & Spa dưỡng ẩm',
                      time: '14:30 - 15:45',
                      staff: 'Thanh Trúc',
                      status: 'Đã xác nhận',
                      accent: _DashboardColors.muted,
                      icon: Icons.phone_outlined,
                    ),
                    const SizedBox(height: 32),
                    _buildCapacityCard(),
                  ],
                ),
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _DashboardColors.teal,
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2223B9C1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'S',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Schedula.',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: _DashboardColors.ink,
            ),
          ),
        ),
        _HeaderIcon(icon: Icons.notifications_none_rounded, hasDot: true),
        const SizedBox(width: 14),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _DashboardColors.blue, width: 2),
          ),
          alignment: Alignment.center,
          child: const Text(
            'SPA',
            style: TextStyle(
              color: _DashboardColors.tealDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const PositionedPlaceholder(),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String? action, {String? badge}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _DashboardColors.ink,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _DashboardColors.mint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: _DashboardColors.tealDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (action != null)
          Text(
            action,
            style: const TextStyle(
              color: _DashboardColors.tealDark,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildOverviewGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        _StatCard(
          label: 'Doanh thu',
          value: '8.450.000',
          suffix: 'đ',
          note: 'Hôm qua: 7.500.000đ',
          tag: '↑ 12%',
          accent: _DashboardColors.mint,
        ),
        _StatCard(
          label: 'Lịch hẹn',
          value: '16',
          suffix: 'lịch hẹn',
          note: '12 đã hoàn thành/xác nhận',
          tag: '4 chờ duyệt',
          accent: _DashboardColors.peach,
        ),
        _StatCard(
          label: 'Khách hàng mới',
          value: '+6',
          suffix: 'khách',
          note: 'Mục tiêu tuần: 85%',
        ),
        _StatCard(
          label: 'Đánh giá dịch vụ',
          value: '4.9',
          suffix: '★',
          note: 'Từ 128 đánh giá',
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (Icons.add, 'Đặt lịch', true),
      (Icons.person_add_alt_1_outlined, 'Thêm khách', false),
      (Icons.business_center_outlined, 'Dịch vụ', false),
      (Icons.payments_outlined, 'Thanh toán', false),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions
          .map(
            (action) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Container(
                      height: 74,
                      decoration: BoxDecoration(
                        color: action.$3 ? _DashboardColors.teal : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: action.$3
                              ? Colors.transparent
                              : _DashboardColors.border,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0D17324D),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        action.$1,
                        color: action.$3
                            ? Colors.white
                            : _DashboardColors.tealDark,
                        size: action.$3 ? 38 : 30,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      action.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: action.$3
                            ? _DashboardColors.ink
                            : _DashboardColors.navy,
                        fontWeight: action.$3
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCapacityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _DashboardColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A17324D),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Công suất phục vụ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _DashboardColors.ink,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '5/8 kỹ thuật viên đang bận',
                      style: TextStyle(color: _DashboardColors.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _DashboardColors.mint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '62.5% công suất',
                  style: TextStyle(
                    color: _DashboardColors.tealDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 13,
                    child: ColoredBox(color: Color(0xFF10B981)),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 13,
                    child: ColoredBox(color: _DashboardColors.blue),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 13,
                    child: ColoredBox(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Legend(color: Color(0xFF10B981), text: 'Đang phục vụ (2)'),
              _Legend(color: _DashboardColors.blue, text: 'Chờ phục vụ (3)'),
              _Legend(color: Color(0xFFCBD5E1), text: 'Đang rảnh (3)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final items = [
      (Icons.dashboard_rounded, 'Dashboard'),
      (Icons.access_time_rounded, 'Schedule'),
      (Icons.calendar_month_outlined, 'Calendar'),
      (Icons.person_outline, 'Profile'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _DashboardColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.asMap().entries.map((entry) {
          final selected = entry.key == _selectedTab;
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = entry.key),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  entry.value.$1,
                  color: selected
                      ? _DashboardColors.tealDark
                      : _DashboardColors.navy,
                  size: 28,
                ),
                const SizedBox(height: 5),
                Text(
                  entry.value.$2,
                  style: TextStyle(
                    color: selected
                        ? _DashboardColors.tealDark
                        : _DashboardColors.navy,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DashboardColors {
  static const teal = Color(0xFF16B8BA);
  static const tealDark = Color(0xFF008F8C);
  static const blue = Color(0xFF08ACD1);
  static const canvas = Color(0xFFF7F9FB);
  static const ink = Color(0xFF111827);
  static const navy = Color(0xFF526681);
  static const muted = Color(0xFF91A3BB);
  static const border = Color(0xFFE4EBF2);
  static const mint = Color(0xFFDDF8EF);
  static const peach = Color(0xFFFFF3DE);
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, this.hasDot = false});
  final IconData icon;
  final bool hasDot;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF7F9FC),
          border: Border.all(color: _DashboardColors.border),
        ),
        child: Icon(icon, color: _DashboardColors.navy, size: 27),
      ),
      if (hasDot)
        Positioned(
          top: 11,
          right: 12,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEF476F),
            ),
          ),
        ),
    ],
  );
}

class PositionedPlaceholder extends StatelessWidget {
  const PositionedPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.note,
    this.tag,
    this.accent,
  });
  final String label, value, suffix, note;
  final String? tag;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _DashboardColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A17324D),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _DashboardColors.navy,
                    fontSize: 15,
                  ),
                ),
              ),
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    tag!,
                    style: TextStyle(
                      color: accent == _DashboardColors.peach
                          ? const Color(0xFFE88700)
                          : _DashboardColors.tealDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: _DashboardColors.ink,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                suffix,
                style: const TextStyle(color: _DashboardColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: TextStyle(
              color: note.startsWith('Mục')
                  ? _DashboardColors.tealDark
                  : _DashboardColors.muted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.name,
    required this.service,
    required this.time,
    required this.staff,
    required this.status,
    required this.accent,
    required this.icon,
  });
  final String name, service, time, staff, status;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A17324D),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 7,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _DashboardColors.ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: accent == _DashboardColors.muted
                                  ? _DashboardColors.navy
                                  : _DashboardColors.tealDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F7FA),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            color: _DashboardColors.tealDark,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      service,
                      style: const TextStyle(
                        color: _DashboardColors.tealDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Divider(height: 1, color: _DashboardColors.border),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          size: 18,
                          color: _DashboardColors.tealDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: const TextStyle(color: _DashboardColors.navy),
                        ),
                        const Spacer(),
                        const Text(
                          'KTV: ',
                          style: TextStyle(color: _DashboardColors.muted),
                        ),
                        Flexible(
                          child: Text(
                            staff,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _DashboardColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Text(
        text,
        style: const TextStyle(color: _DashboardColors.navy, fontSize: 13),
      ),
    ],
  );
}
