import '../../auth/application/auth_controller.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_user.dart';
import '../../../core/utils/category_labels.dart';
import '../../users/application/user_provider.dart';
import 'manager_crud_dialogs.dart';
import 'manager_leave_panel.dart';

import '../../workspace/presentation/workspace_screen.dart';

class ManagerStaffScreen extends StatelessWidget {
  const ManagerStaffScreen({super.key});

  void _edit(BuildContext context, [AppUser? user]) {
    final provider = context.read<UserProvider>();
    showDialog<void>(
      context: context,
      builder: (_) => ManagerCrudDialog.staff(provider: provider, user: user),
    );
  }

  void _delete(BuildContext context, AppUser user) {
    final provider = context.read<UserProvider>();
    confirmManagerDelete(context, user.name, () => provider.delete(user.id));
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AuthController>().currentUser;
    if (manager?.role != UserRole.manager || manager?.branchId == null) {
      return const Center(child: Text('Phiên Manager không hợp lệ.'));
    }
    final staff = context.watch<UserProvider>().getStaff(
      branchId: manager!.branchId,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFFAFAFA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Quản lý Nhân viên',
          style: TextStyle(
            fontSize: 22,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin-add-staff',
        tooltip: 'Thêm nhân viên',
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 2,
        onPressed: () => _edit(context),
        child: const Icon(Icons.person_add),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          itemCount: staff.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đội ngũ của bạn',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '${staff.length} nhân viên',
                      style: TextStyle(color: Color(0xFF757575), fontSize: 12),
                    ),
                    const ManagerLeavePanel(),
                    if (context.watch<AuthController>().isRemote)
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const WorkspaceScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('Quản lý ca làm'),
                      ),
                  ],
                ),
              );
            }
            final person = staff[index - 1];
            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                minTileHeight: 108,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                horizontalTitleGap: 12,
                minLeadingWidth: 36,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFF2F2F2),
                  child: Text(
                    person.name.isEmpty ? '?' : person.name.substring(0, 1),
                    style: const TextStyle(color: Color(0xFF1A1A1A)),
                  ),
                ),
                title: Text(
                  person.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    '${categoryLabels(person.specializedCategoryIds)}\n${person.isApproved ? 'Đã duyệt' : 'Chờ Boss duyệt'}',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: Color(0xFF757575),
                    ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Sửa ${person.name}',
                      icon: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Color(0xFF757575),
                      ),
                      onPressed: () => _edit(context, person),
                    ),
                    IconButton(
                      tooltip: 'Xóa ${person.name}',
                      icon: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Color(0xFFB94747),
                      ),
                      onPressed: () => _delete(context, person),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
