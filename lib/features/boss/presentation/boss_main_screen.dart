import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_user.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/application/auth_controller.dart';
import '../../catalog/presentation/service_catalog_screen.dart';
import '../../users/application/user_provider.dart';
import 'boss_widgets.dart';
import 'boss_dashboard_screen.dart';
import 'boss_ledger_screen.dart';
import 'boss_commissions_screen.dart';
import 'boss_branches_screen.dart';
import 'boss_pending_staff_screen.dart';
import '../application/pending_staff_provider.dart';
import '../../workspace/presentation/workspace_screen.dart';

class BossMainScreen extends StatelessWidget {
  const BossMainScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.currentUser?.role != UserRole.superAdmin) {
      return const Scaffold(
        body: Center(child: Text('Phiên Boss không hợp lệ.')),
      );
    }
    final pending = auth.isRemote
        ? context.watch<PendingStaffProvider>().rows.length
        : context
              .watch<UserProvider>()
              .users
              .where((u) => u.role == UserRole.staff && !u.isApproved)
              .length;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: bossAccent),
        scaffoldBackgroundColor: const Color(0xFFF3F6F5),
      ),
      child: DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Boss Dashboard',
              style: TextStyle(fontWeight: FontWeight.w800, color: bossInk),
            ),
            actions: [
              if (auth.isRemote)
                IconButton(
                  tooltip: 'Ca làm & Nghỉ phép',
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const WorkspaceScreen(),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Đăng xuất',
                icon: const Icon(Icons.logout),
                onPressed: () {
                  auth.signOut();
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
                },
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(
                  icon: Icon(Icons.space_dashboard_outlined),
                  text: 'Tổng quan',
                ),
                const Tab(
                  icon: Icon(Icons.receipt_long_outlined),
                  text: 'Sổ lịch',
                ),
                const Tab(
                  icon: Icon(Icons.calculate_outlined),
                  text: 'Hoa hồng',
                ),
                const Tab(icon: Icon(Icons.storefront_outlined), text: 'Cơ sở'),
                const Tab(icon: Icon(Icons.spa_outlined), text: 'Dịch vụ'),
                Tab(
                  icon: Badge(
                    isLabelVisible: pending > 0,
                    label: Text('$pending'),
                    child: const Icon(Icons.how_to_reg_outlined),
                  ),
                  text: 'Phê duyệt',
                ),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              BossDashboardScreen(),
              BossLedgerScreen(),
              BossCommissionsScreen(),
              BossBranchesScreen(),
              ServiceCatalogScreen(readOnly: false),
              BossPendingStaffScreen(),
            ],
          ),
        ),
      ),
    );
  }
}
