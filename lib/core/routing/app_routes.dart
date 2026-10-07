import '../models/app_user.dart';

abstract final class AppRoutes {
  static const login = '/';
  static const register = '/register';
  static const customerHome = '/customer';
  static const services = '/services';
  static const booking = '/booking';
  static const staffSchedule = '/staff/schedule';
  static const boss = '/boss';
  static const managerDashboard = '/manager';
  static const managerServices = '/manager/services';
  static const managerRevenue = '/manager/revenue';
  static const chat = '/chat';

  static String homeFor(UserRole role) => switch (role) {
    UserRole.customer => customerHome,
    UserRole.staff => staffSchedule,
    UserRole.manager => managerDashboard,
    UserRole.superAdmin => boss,
  };
}
