import '../../../shared/widgets/salon_brand.dart';
import '../../../shared/widgets/profile_identity_card.dart';
import '../../../core/theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_routes.dart';
import '../../auth/application/auth_controller.dart';
import 'customer_home_screen.dart';
import 'customer_profile_dialog.dart';
import 'customer_appointments_screen.dart';

class CustomerMain extends StatefulWidget {
  const CustomerMain({super.key});

  @override
  State<CustomerMain> createState() => _CustomerMainState();
}

class _CustomerMainState extends State<CustomerMain> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Giữ vị trí cuộn và state Home khi chuyển giữa các tab.
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFFAF7F2),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF594536))
            .copyWith(
              primary: const Color(0xFF594536),
              secondary: const Color(0xFFC5A16B),
            ),
      ),
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            TickerMode(
              enabled: _selectedIndex == 0,
              child: const CustomerHomeScreen(),
            ),
            const CustomerAppointmentsScreen(),
            const _ProfileTab(),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              FocusScope.of(context).unfocus();
              setState(() => _selectedIndex = index);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            showUnselectedLabels: true,
            selectedItemColor: const Color(0xFF594536),
            unselectedItemColor: const Color(0xFF81766C),
            selectedFontSize: 11,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: SalonNavIcon(icon: Icons.home_rounded),
                label: 'Trang chủ',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_outlined),
                activeIcon: SalonNavIcon(icon: Icons.calendar_month),
                label: 'Lịch hẹn',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: SalonNavIcon(icon: Icons.person),
                label: 'Hồ sơ',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Hồ sơ của bạn',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Color(0xFF30251F),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Góc riêng của bạn tại Barbershop & Spa.',
                  style: TextStyle(color: Color(0xFF817368), height: 1.5),
                ),
                const SizedBox(height: 24),
                ProfileIdentityCard(
                  name: user?.name ?? '',
                  subtitle: user?.email ?? '',
                  badge: 'KHÁCH HÀNG',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: user == null
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => CustomerProfileDialog(user: user),
                        ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Chỉnh sửa hồ sơ'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Thông tin cá nhân',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.outline),
                  ),
                  child: Column(
                    children: [
                      _ProfileDetail(
                        icon: Icons.phone_outlined,
                        label: 'Số điện thoại',
                        value: user?.phone,
                      ),
                      const Divider(height: 1, indent: 62, endIndent: 18),
                      _ProfileDetail(
                        icon: Icons.location_on_outlined,
                        label: 'Địa chỉ',
                        value: user?.address,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E6D7),
                    border: Border.all(color: const Color(0xFFE4D3BB)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.stars_outlined,
                        color: Color(0xFF8D7353),
                        size: 30,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Điểm thưởng (mẫu)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Thông tin minh họa',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF817368),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '150',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF30251F),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    // Xóa phiên và lịch sử điều hướng, Back không mở lại trang nội bộ.
                    context.read<AuthController>().signOut();
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
                  },
                  icon: const Icon(Icons.logout, size: 19),
                  label: const Text('Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({required this.icon, required this.label, this.value});
  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppTheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF817368), fontSize: 11),
              ),
              const SizedBox(height: 5),
              Text(
                value == null || value!.trim().isEmpty
                    ? 'Chưa cập nhật'
                    : value!,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
