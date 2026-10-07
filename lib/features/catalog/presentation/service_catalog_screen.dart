import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/service.dart';
import '../../../core/models/app_user.dart';
import '../../auth/application/auth_controller.dart';
import '../../catalog/application/service_provider.dart';
import '../../manager/presentation/manager_crud_dialogs.dart';

class ServiceCatalogScreen extends StatelessWidget {
  const ServiceCatalogScreen({super.key, this.readOnly = true});
  final bool readOnly;

  IconData _icon(ServiceCategory category) => switch (category) {
    ServiceCategory.haircut => Icons.content_cut,
    ServiceCategory.hairWash => Icons.water_drop_outlined,
    ServiceCategory.perm => Icons.waves,
    ServiceCategory.dye => Icons.palette_outlined,
    ServiceCategory.massage => Icons.spa_outlined,
    ServiceCategory.shaving => Icons.face_outlined,
  };

  String _price(int value) =>
      '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]}.')}đ';

  void _edit(BuildContext context, [Service? service]) {
    final provider = context.read<ServiceProvider>();
    showDialog<void>(
      context: context,
      builder: (_) =>
          ManagerCrudDialog.service(provider: provider, service: service),
    );
  }

  void _delete(BuildContext context, Service service) {
    final provider = context.read<ServiceProvider>();
    confirmManagerDelete(
      context,
      service.name,
      () => provider.delete(service.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit =
        !readOnly &&
        context.watch<AuthController>().currentUser?.role ==
            UserRole.superAdmin;
    final services = context.watch<ServiceProvider>().services;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFFAFAFA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Quản lý Dịch vụ',
          style: TextStyle(
            fontSize: 22,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              heroTag: 'admin-add-service',
              tooltip: 'Thêm dịch vụ',
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              elevation: 2,
              onPressed: () => _edit(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                '${services.length} dịch vụ · Chăm sóc & tạo kiểu',
                style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
              ),
            ),
            ...services.map(
              (service) => Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _icon(service.category),
                                  size: 24,
                                  color: const Color(0xFFD4AF37),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  service.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canEdit)
                            IconButton(
                              tooltip: 'Sửa ${service.name}',
                              onPressed: () => _edit(context, service),
                              icon: const Icon(
                                Icons.edit,
                                size: 19,
                                color: Color(0xFF757575),
                              ),
                            ),
                          if (canEdit)
                            IconButton(
                              tooltip: 'Xóa ${service.name}',
                              onPressed: () => _delete(context, service),
                              icon: const Icon(
                                Icons.delete,
                                size: 19,
                                color: Color(0xFFB94747),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 18,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _price(service.priceVnd),
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF238260),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 14,
                                color: Color(0xFF757575),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${service.durationMinutes} phút',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF757575),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
