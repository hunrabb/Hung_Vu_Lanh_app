import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/customer/presentation/customer_main.dart';
import '../../features/schedule/presentation/staff_main.dart';
import '../../features/manager/presentation/manager_main.dart';
import '../../features/manager/presentation/manager_revenue_screen.dart';
import 'app_routes.dart';
import '../../features/boss/presentation/boss_main_screen.dart';
import '../../features/booking/presentation/customer_booking_screen.dart';

/// Bảo vệ phiên và vai trò trên UI; backend sau này vẫn cần kiểm tra quyền.
abstract final class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => _GuardedPage(
        routeName: settings.name ?? AppRoutes.login,
        arguments: settings.arguments,
      ),
    );
  }

  static String _destination(String requested, AppUser? user) {
    final isAuthPage =
        requested == AppRoutes.login || requested == AppRoutes.register;
    if (user == null) return isAuthPage ? requested : AppRoutes.login;
    if (user.role == UserRole.staff && !user.isApproved) {
      return isAuthPage ? requested : AppRoutes.login;
    }
    final home = AppRoutes.homeFor(user.role);
    if (isAuthPage) return home;

    // Mỗi vai trò chỉ được vào các trang thuộc phạm vi của mình.
    final requiredRole = switch (requested) {
      AppRoutes.boss => UserRole.superAdmin,
      AppRoutes.customerHome ||
      AppRoutes.services ||
      AppRoutes.booking => UserRole.customer,
      AppRoutes.staffSchedule => UserRole.staff,
      AppRoutes.managerDashboard ||
      AppRoutes.managerServices ||
      AppRoutes.managerRevenue => UserRole.manager,
      _ => null,
    };
    if (requiredRole != null && requiredRole != user.role) return home;
    return requested;
  }

  static Widget _page(String name, Object? arguments) {
    if (name == AppRoutes.boss) return const BossMainScreen();
    if (name == AppRoutes.login) return const LoginScreen();
    if (name == AppRoutes.register) return const RegisterScreen();
    if (name == AppRoutes.customerHome) return const CustomerMain();
    if (name == AppRoutes.booking) {
      return CustomerBookingScreen(
        initialBranchId: arguments is String ? arguments : null,
      );
    }
    if (name == AppRoutes.staffSchedule) return const StaffMain();
    if (name == AppRoutes.managerDashboard) return const ManagerMain();
    if (name == AppRoutes.managerRevenue) return const ManagerRevenueScreen();
    if (name == AppRoutes.managerServices) {
      return const ManagerMain(initialIndex: 2);
    }
    final title = switch (name) {
      AppRoutes.services => 'Services',
      AppRoutes.booking => 'Book an appointment',
      AppRoutes.chat => 'Messages',
      _ => 'Page not found',
    };
    // Các module chưa triển khai vẫn có trang chờ, không phụ thuộc widget cũ.
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFFFAFAFA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Feature implementation coming next.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF757575)),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuardedPage extends StatelessWidget {
  const _GuardedPage({required this.routeName, this.arguments});
  final String routeName;
  final Object? arguments;

  @override
  Widget build(BuildContext context) {
    // Lắng nghe cả thay đổi phiên để trang cũ không lộ ra khi đăng xuất/Back.
    final auth = context.watch<AuthController>();
    final destination = AppRouter._destination(routeName, auth.currentUser);
    if (destination != routeName) {
      // Điều hướng sau build, tránh sửa Navigator trong lúc dựng giao diện.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
          return;
        }
        final currentUser = context.read<AuthController>().currentUser;
        final target = AppRouter._destination(routeName, currentUser);
        if (target != routeName) {
          Navigator.of(context).pushNamedAndRemoveUntil(target, (_) => false);
        }
      });
      // Không hiển thị nội dung bị chặn trong lúc chờ chuyển hướng.
      return const Scaffold(body: SizedBox.shrink());
    }
    return AppRouter._page(routeName, arguments);
  }
}
