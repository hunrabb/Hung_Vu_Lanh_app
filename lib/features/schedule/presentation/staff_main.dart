import 'package:flutter/material.dart';

import '../../staff/presentation/staff_customers_screen.dart';
import '../../staff/presentation/staff_profile_screen.dart';
import '../../staff/presentation/staff_schedule_screen.dart';
import '../../staff/presentation/staff_earnings_screen.dart';

class StaffMain extends StatefulWidget {
  const StaffMain({super.key});

  @override
  State<StaffMain> createState() => _StaffMainState();
}

class _StaffMainState extends State<StaffMain> {
  int _selectedIndex = 0;

  static const _screens = [
    StaffScheduleScreen(),
    StaffCustomersScreen(),
    StaffEarningsScreen(),
    StaffProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFAFA),
    body: IndexedStack(index: _selectedIndex, children: _screens),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 0,
      showUnselectedLabels: true,
      selectedItemColor: const Color(0xFF1A1A1A),
      unselectedItemColor: const Color(0xFFA0A0A0),
      selectedFontSize: 11,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          activeIcon: Icon(Icons.calendar_month),
          label: 'Lịch làm việc',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: 'Khách hàng',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.payments_outlined),
          activeIcon: Icon(Icons.payments),
          label: 'Thu nhập',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Hồ sơ',
        ),
      ],
    ),
  );
}
