import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../users/application/user_provider.dart';
import 'manager_crud_dialogs.dart';

import 'manager_dashboard_screen.dart';
import 'manager_staff_screen.dart';
import 'manager_service_screen.dart';
import 'manager_settings_screen.dart';

class ManagerMain extends StatefulWidget {
  const ManagerMain({super.key, this.initialIndex = 0})
    : assert(initialIndex >= 0 && initialIndex < 4);
  final int initialIndex;

  @override
  State<ManagerMain> createState() => _ManagerMainState();
}

class _ManagerMainState extends State<ManagerMain> {
  late int _selectedIndex = widget.initialIndex;
  void _addStaff() {
    setState(() => _selectedIndex = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedIndex != 1) return;
      final provider = context.read<UserProvider>();
      showDialog<void>(
        context: context,
        builder: (_) => ManagerCrudDialog.staff(provider: provider),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFAFA),
    // Only the selected tab is built; each screen owns its AppBar and actions.
    body: switch (_selectedIndex) {
      1 => const ManagerStaffScreen(),
      2 => const ManagerServiceScreen(),
      3 => const ManagerSettingsScreen(),
      _ => ManagerDashboardScreen(
        onAddStaff: _addStaff,
        onManageServices: () => setState(() => _selectedIndex = 2),
      ),
    },
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
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
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Tổng quan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.badge_outlined),
          activeIcon: Icon(Icons.badge),
          label: 'Nhân viên',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.spa_outlined),
          activeIcon: Icon(Icons.spa),
          label: 'Dịch vụ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Cài đặt',
        ),
      ],
    ),
  );
}
