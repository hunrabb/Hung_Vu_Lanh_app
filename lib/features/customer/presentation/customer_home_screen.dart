import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/models/appointment.dart';
import '../../../core/models/promotion.dart';
import '../../booking/application/appointment_provider.dart';
import '../../booking/presentation/api_appointments_screen.dart';
import '../../users/application/user_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../settings/application/shop_settings_provider.dart';
import '../../users/presentation/user_names.dart';
import '../../branches/application/branch_provider.dart';
import '../../../core/models/branch.dart';
import '../../booking/application/api_appointment_provider.dart';

// Home reads booking data; marketing stays separate from booking prices.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    super.key,
    this.promotions = const [
      Promotion(
        id: 'member',
        title: 'Giảm giá 20%\ncho thành viên mới',
        subtitle: 'Khởi đầu hành trình chăm sóc của bạn.',
        imageUrl: '',
      ),
      Promotion(
        id: 'care',
        title: 'Thư giãn trọn vẹn\nvới combo chăm sóc',
        subtitle: 'Một khoảng nghỉ, một diện mạo mới.',
        imageUrl: '',
      ),
    ],
  });
  final List<Promotion> promotions;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static const _ink = Color(0xFF1A1A1A);
  static const _gold = Color(0xFFD4AF37);
  static const _muted = Color(0xFF757575);
  static final _softShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  int _promoIndex = 0;
  String? _branchId;

  static const _categories = [
    (name: 'Cắt tóc', icon: Icons.content_cut),
    (name: 'Gội đầu', icon: Icons.water_drop_outlined),
    (name: 'Uốn', icon: Icons.waves),
    (name: 'Nhuộm', icon: Icons.palette_outlined),
    (name: 'Massage', icon: Icons.spa_outlined),
    (name: 'Cạo râu', icon: Icons.face_outlined),
  ];
  static const _barbers = [
    (name: 'Alex', initials: 'AL', rating: '4.8', specialty: 'Fade & styling'),
    (name: 'Minh', initials: 'MI', rating: '4.9', specialty: 'Layer & uốn'),
    (name: 'Daniel', initials: 'DA', rating: '4.8', specialty: 'Classic cuts'),
    (
      name: 'Linh',
      initials: 'LI',
      rating: '4.9',
      specialty: 'Color specialist',
    ),
  ];
  static const _styles = [
    (
      name: 'Mohican chéo',
      detail: 'Gọn gàng · Cá tính',
      icon: Icons.bolt_outlined,
    ),
    (name: 'Layer uốn', detail: 'Tự nhiên · Bồng bềnh', icon: Icons.waves),
    (
      name: 'Classic side part',
      detail: 'Lịch lãm · Tinh tế',
      icon: Icons.auto_awesome,
    ),
  ];

  // Preview actions for features not yet implemented.
  void _preview(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? get _validBranchId => context.read<AuthController>().isRemote
      ? (context.read<ApiAppointmentProvider>().branches.any(
              (b) => b['id'] == _branchId,
            )
            ? _branchId
            : null)
      : context.read<BranchProvider>().getById(_branchId ?? '')?.id;
  bool get _closedToday =>
      !context.read<AuthController>().isRemote &&
      _validBranchId != null &&
      context.read<ShopSettingsProvider>().isClosedOn(
        context.read<AppointmentProvider>().today,
        branchId: _validBranchId,
      );
  void _openBooking() {
    if (!_closedToday) {
      Navigator.of(context)
          .pushNamed(AppRoutes.booking, arguments: _validBranchId);
    }
  }

  String _hour(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  void _cancel(Appointment appointment) {
    try {
      context.read<AppointmentProvider>().cancel(appointment.id);
      _preview('Đã hủy lịch hẹn.');
    } on StateError catch (error) {
      _preview(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopSettingsProvider>();
    final remote = context.watch<AuthController>().isRemote;
    final branches = remote
        ? context
              .watch<ApiAppointmentProvider>()
              .branches
              .map(Branch.fromJson)
              .toList()
        : context.watch<BranchProvider>().branches;
    final branchId = branches.any((b) => b.id == _branchId) ? _branchId : null;
    final configuration = remote || branchId == null
        ? null
        : shop.getSettings(branchId);
    final closedToday =
        !remote &&
        branchId != null &&
        shop.isClosedOn(
          context.read<AppointmentProvider>().today,
          branchId: branchId,
        );
    final customerId = context.watch<AuthController>().currentUser?.id;
    if (customerId == null) {
      return const Center(child: Text('Vui lòng đăng nhập.'));
    }
    final upcoming =
        context
            .watch<AppointmentProvider>()
            .getByCustomerId(customerId)
            .where(
              (a) =>
                  a.status == AppointmentStatus.pending ||
                  a.status == AppointmentStatus.confirmed,
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final appointment = upcoming.isEmpty ? null : upcoming.first;
    final staffName = appointment == null
        ? ''
        : visibleUserName(
            context.watch<UserProvider>(),
            appointment.staffId,
            'Nhân viên',
          );
    final promotions = widget.promotions.where((p) => p.isActive).toList();
    final name = context.select<AuthController, String>(
      (auth) => auth.currentUser?.name ?? 'bạn',
    );
    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (closedToday) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8D5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Hôm nay cửa hàng tạm nghỉ. Hẹn gặp lại bạn vào ngày mai!',
                      style: TextStyle(
                        color: Color(0xFF9A4513),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                _header(name),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('home-branch-$branchId'),
                  initialValue: branchId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Cơ sở tại Hà Nội',
                  ),
                  items: branches
                      .map(
                        (b) =>
                            DropdownMenuItem(value: b.id, child: Text(b.name)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _branchId = value),
                ),
                const SizedBox(height: 12),
                if (configuration != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EFE9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Giờ hoạt động: ${_hour(configuration.openingMinute)} - ${_hour(configuration.closingMinute)}',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 28),
                _search(),
                const SizedBox(height: 28),
                CustomButton(
                  key: const ValueKey('primary-booking'),
                  label: 'Đặt lịch ngay',
                  onPressed: closedToday ? null : _openBooking,
                ),
                const SizedBox(height: 28),
                if (context.watch<AuthController>().isRemote)
                  const ApiUpcomingHome(),
                if (!context.watch<AuthController>().isRemote &&
                    appointment != null) ...[
                  _appointment(appointment, staffName),
                  const SizedBox(height: 32),
                ],
                if (promotions.isNotEmpty) ...[
                  _section('Dành riêng cho bạn', 'Ưu đãi thành viên'),
                  const SizedBox(height: 18),
                  _promotions(promotions),
                  const SizedBox(height: 32),
                ],
                _section(
                  'Dịch vụ',
                  'Chăm sóc theo cách của bạn',
                  action: 'Xem tất cả',
                  onTap: () =>
                      _preview('Danh sách dịch vụ đang được xây dựng.'),
                ),
                const SizedBox(height: 18),
                _categoryList(),
                const SizedBox(height: 32),
                _section(
                  'Thợ nổi bật',
                  'Những đôi tay bạn có thể tin tưởng',
                  action: 'Khám phá',
                  onTap: () => _preview('Danh sách thợ hiện là dữ liệu mẫu.'),
                ),
                const SizedBox(height: 18),
                _barberList(),
                const SizedBox(height: 32),
                _section('Một diện mạo mới', 'Kiểu tóc thịnh hành'),
                const SizedBox(height: 18),
                _inspiration(),
                const SizedBox(height: 28),
                const Center(
                  child: Text(
                    'DÀNH THỜI GIAN CHO CHÍNH MÌNH',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: _muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(String name) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CHÀO MỪNG TRỞ LẠI',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2,
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Xin chào, $name!',
              style: const TextStyle(
                fontSize: 27,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hôm nay, hãy dành một chút thời gian cho bạn.',
              style: TextStyle(fontSize: 13, height: 1.6, color: _muted),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5E5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Điểm thưởng: 150⭐',
                style: TextStyle(
                  color: Color(0xFF866D20),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: IconButton(
          tooltip: 'Thông báo',
          onPressed: () =>
              _preview('Bạn chưa có thông báo mới. Đây là giao diện mẫu.'),
          icon: const Badge(
            smallSize: 7,
            backgroundColor: _gold,
            child: Icon(Icons.notifications_none_rounded, color: _ink),
          ),
        ),
      ),
    ],
  );

  Widget _search() => TextField(
    textInputAction: TextInputAction.search,
    onSubmitted: (_) =>
        _preview('Tìm kiếm sẽ được kết nối với danh sách dịch vụ ở bước sau.'),
    decoration: InputDecoration(
      hintText: 'Tìm kiếm dịch vụ, thợ cắt...',
      hintStyle: const TextStyle(fontSize: 13, color: _muted),
      prefixIcon: const Icon(Icons.search_rounded, color: _muted),
      filled: true,
      fillColor: const Color(0xFFF2F2F2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _gold),
      ),
    ),
  );

  Widget _appointment(Appointment appointment, String staffName) {
    final local = appointment.startAt.toUtc().add(const Duration(hours: 7));
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_available_outlined, color: _gold, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lịch hẹn sắp tới',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            appointment.serviceNamesSnapshot.join(' + '),
            style: const TextStyle(
              fontSize: 21,
              color: _ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                '$time · ${local.day}/${local.month}/${local.year}',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
              Text(
                'Thợ: $staffName',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _cancel(appointment),
            style: TextButton.styleFrom(foregroundColor: _muted),
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    String subtitle, {
    String? action,
    VoidCallback? onTap,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: _muted, height: 1.5),
            ),
          ],
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: _muted),
          child: Text(action, style: const TextStyle(fontSize: 11)),
        ),
    ],
  );

  Widget _promotions(List<Promotion> promotions) => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        SizedBox(
          // Thêm chỗ cho tiêu đề xuống dòng trên điện thoại nhỏ.
          height: constraints.maxWidth < 340 ? 330 : 280,
          child: PageView(
            onPageChanged: (index) => setState(() => _promoIndex = index),
            children: promotions
                .map(
                  (promotion) => _promo(
                    'ƯU ĐÃI THÀNH VIÊN',
                    promotion.title,
                    promotion.subtitle,
                    const Color(0xFF1A1A1A),
                    const Color(0xFF454545),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            promotions.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: _promoIndex == index ? 22 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: _promoIndex == index ? _gold : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _promo(
    String eyebrow,
    String title,
    String subtitle,
    Color start,
    Color end,
  ) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 2),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        colors: [start, end],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                eyebrow,
                style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: 2,
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 24),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            height: 1.2,
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFFCBCBCB),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: _ink,
          ),
          onPressed: _closedToday ? null : _openBooking,
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('Đặt lịch ngay'),
        ),
      ],
    ),
  );

  Widget _categoryList() => SizedBox(
    height: 116,
    child: ListView.separated(
      clipBehavior: Clip.none,
      scrollDirection: Axis.horizontal,
      itemCount: _categories.length,
      separatorBuilder: (_, _) => const SizedBox(width: 18),
      itemBuilder: (context, index) {
        final category = _categories[index];
        return SizedBox(
          width: 76,
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _softShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _preview(category.name),
                    child: Icon(category.icon, size: 25, color: _ink),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                category.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: _ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _barberList() => SizedBox(
    height: 224,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _barbers.length,
      separatorBuilder: (_, _) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final barber = _barbers[index];
        return SizedBox(
          width: 164,
          child: _portraitCard(
            title: barber.name,
            subtitle: barber.specialty,
            rating: barber.rating,
            placeholder: Text(
              barber.initials,
              style: const TextStyle(
                fontSize: 38,
                letterSpacing: -1,
                fontWeight: FontWeight.w300,
                color: Color(0xFF8E8E8E),
              ),
            ),
            onTap: () => _preview('${barber.name} - ${barber.specialty}'),
          ),
        );
      },
    ),
  );

  Widget _inspiration() => SizedBox(
    height: 268,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _styles.length,
      separatorBuilder: (_, _) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final style = _styles[index];
        return SizedBox(
          width: 188,
          child: _portraitCard(
            title: style.name,
            subtitle: style.detail,
            placeholder: Icon(
              style.icon,
              size: 48,
              color: const Color(0xFF929292),
            ),
            onTap: () => _preview(style.name),
          ),
        );
      },
    ),
  );

  // Neutral image placeholder with a bottom scrim keeps the name readable.
  Widget _portraitCard({
    required String title,
    required String subtitle,
    required Widget placeholder,
    required VoidCallback onTap,
    String? rating,
  }) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: _softShadow,
    ),
    child: Material(
      color: const Color(0xFFE8E8E8),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF1F1F1), Color(0xFFC6C6C6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: placeholder,
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xDD000000)],
                  stops: [0.3, 1],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            if (rating != null)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: _gold, size: 13),
                      const SizedBox(width: 3),
                      Text(
                        rating,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 12,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      letterSpacing: -0.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFD6D6D6),
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
