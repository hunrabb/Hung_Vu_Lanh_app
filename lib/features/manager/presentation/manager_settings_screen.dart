import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_routes.dart';
import '../../auth/application/auth_controller.dart';
import '../../users/application/user_provider.dart';
import '../../users/presentation/account_dialogs.dart';
import '../../settings/application/shop_settings_provider.dart';
import '../../settings/presentation/shop_settings_editors.dart';

class ManagerSettingsScreen extends StatelessWidget {
  const ManagerSettingsScreen({super.key});

  Widget _option(
    BuildContext context,
    String label,
    IconData icon, {
    VoidCallback? onTap,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    leading: Icon(icon, size: 22, color: const Color(0xFF757575)),
    title: Text(
      label,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
    ),
    trailing: const Icon(
      Icons.chevron_right,
      size: 20,
      color: Color(0xFFA0A0A0),
    ),
    onTap:
        onTap ??
        () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('$label: đây là giao diện mẫu.')),
            );
        },
  );

  Widget _group(List<Widget> children) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFAFA),
    appBar: AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFFAFAFA),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'Cài đặt cơ sở',
        style: TextStyle(
          fontSize: 22,
          color: Color(0xFF1A1A1A),
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    ),
    body: SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'TÀI KHOẢN',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _group([
                    _option(
                      context,
                      'Thông tin cá nhân',
                      Icons.person_outline,
                      onTap: () {
                        final user = context.read<AuthController>().currentUser;
                        if (user == null) return;
                        final users = context.read<UserProvider>();
                        showDialog<void>(
                          context: context,
                          builder: (_) => OwnProfileDialog(
                            users: users,
                            user: users.getById(user.id)!,
                          ),
                        );
                      },
                    ),
                    const Divider(
                      height: 1,
                      indent: 18,
                      endIndent: 18,
                      color: Color(0xFFF2F2F2),
                    ),
                    _option(
                      context,
                      'Đổi mật khẩu',
                      Icons.lock_outline,
                      onTap: () {
                        final user = context.read<AuthController>().currentUser;
                        if (user == null) return;
                        showDialog<void>(
                          context: context,
                          builder: (_) => OwnPasswordDialog(
                            users: context.read<UserProvider>(),
                            userId: user.id,
                          ),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 28),
                  const Text(
                    'CỬA HÀNG',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _group([
                    _option(
                      context,
                      'Giờ hoạt động',
                      Icons.schedule_outlined,
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => WorkingHoursDialog(
                          provider: context.read<ShopSettingsProvider>(),
                        ),
                      ),
                    ),
                    const Divider(
                      height: 1,
                      indent: 18,
                      endIndent: 18,
                      color: Color(0xFFF2F2F2),
                    ),
                    _option(
                      context,
                      'Cấu hình ngày nghỉ',
                      Icons.event_busy_outlined,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ClosedDatesScreen(),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB94747),
                        side: const BorderSide(color: Color(0xFFE0B7B7)),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        // Giữ logic đăng xuất: xóa phiên và mọi trang trong lịch sử.
                        context.read<AuthController>().signOut();
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.login,
                          (_) => false,
                        );
                      },
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text('Đăng xuất'),
                    ),
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
