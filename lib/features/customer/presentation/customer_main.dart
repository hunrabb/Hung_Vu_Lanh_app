import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_routes.dart';
import '../../auth/application/auth_controller.dart';
import 'customer_home_screen.dart';
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
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A1A))
            .copyWith(
              primary: const Color(0xFF1A1A1A),
              secondary: const Color(0xFFD4AF37),
            ),
      ),
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: const [
            CustomerHomeScreen(),
            CustomerAppointmentsScreen(),
            _ProfileTab(),
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
            showUnselectedLabels: false,
            selectedItemColor: const Color(0xFF1A1A1A),
            unselectedItemColor: const Color(0xFFA0A0A0),
            selectedFontSize: 11,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Trang chủ',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_outlined),
                activeIcon: Icon(Icons.calendar_month),
                label: 'Lịch hẹn',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
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
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Hồ sơ của bạn',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 36),
            const Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person_outline,
                  size: 38,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              user?.name ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star_outline, color: Color(0xFFD4AF37)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Điểm thưởng (mẫu)',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  Text('150', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A1A1A),
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
    );
  }
}
