import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_money.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/booking_arguments.dart';
import '../../../core/theme/salon_assets.dart';
import '../../auth/application/auth_controller.dart';
import '../../booking/application/api_appointment_provider.dart';
import '../application/service_provider.dart';

class CustomerServicesScreen extends StatefulWidget {
  const CustomerServicesScreen({
    super.key,
    this.arguments = const ServiceArguments(),
  });
  final ServiceArguments arguments;
  @override
  State<CustomerServicesScreen> createState() => _CustomerServicesScreenState();
}

class _CustomerServicesScreenState extends State<CustomerServicesScreen> {
  bool _loading = false;
  String? _error;
  String _query = '';
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted || !context.read<AuthController>().isRemote) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<ApiAppointmentProvider>().catalog();
    } catch (_) {
      if (mounted) _error = 'Không tải được dịch vụ. Vui lòng thử lại.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _book(String id) => Navigator.pushNamed(
    context,
    AppRoutes.booking,
    arguments: BookingArguments(
      branchId: widget.arguments.branchId,
      serviceId: id,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<AuthController>().isRemote;
    final services = remote
        ? context.watch<ApiAppointmentProvider>().services
        : context
              .watch<ServiceProvider>()
              .services
              .map(
                (s) => <String, dynamic>{
                  'id': s.id,
                  'name': s.name,
                  'categoryId': s.categoryId,
                  'price': s.priceVnd.toString(),
                  'duration': s.durationMinutes,
                  'isActive': s.isActive,
                },
              )
              .toList();
    final visible = services
        .where(
          (s) =>
              s['isActive'] == true &&
              s['categoryId'] != 'shaving' &&
              (s['name'] as String).toLowerCase().contains(
                _query.toLowerCase(),
              ) &&
              (widget.arguments.categoryId == null ||
                  s['categoryId'] == widget.arguments.categoryId),
        )
        .toList();
    final selected = visible
        .where((s) => s['id'] == widget.arguments.serviceId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(selected?['name'] as String? ?? 'Dịch vụ & kiểu tóc'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.arguments.serviceId == null) ...[
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    labelText: 'Tìm dịch vụ',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Thử lại')),
              ],
              if (!_loading && visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Chưa có dịch vụ trong danh mục này.'),
                ),
              if (selected != null)
                ..._detail(selected)
              else
                ...visible.map(
                  (s) => Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.services,
                        arguments: ServiceArguments(
                          branchId: widget.arguments.branchId,
                          categoryId: widget.arguments.categoryId,
                          serviceId: s['id'] as String,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                _image(s['categoryId'] as String?),
                                width: 80,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(ApiMoney.formatVnd(s['price'])),
                                  Text('${s['duration']} phút'),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Xem quy trình & mẫu',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _image(String? category) => switch (category) {
    'haircut' => SalonAssets.crop,
    'perm' => SalonAssets.layer,
    'dye' => SalonAssets.classic,
    _ => SalonAssets.interior,
  };
  List<Widget> _detail(Map<String, dynamic> s) {
    final category = s['categoryId'] as String?;
    final steps = switch (category) {
      'haircut' => [
        'Tư vấn kiểu phù hợp với khuôn mặt và chất tóc.',
        'Cắt, chỉnh đường nét và kiểm tra độ cân đối.',
        'Sấy, tạo kiểu và hướng dẫn chăm sóc tại nhà.',
      ],
      'perm' => [
        'Kiểm tra tình trạng tóc, tư vấn độ xoăn.',
        'Tạo phom và xử lý uốn theo chất tóc.',
        'Hoàn thiện, hướng dẫn giữ nếp và chăm sóc.',
      ],
      'dye' => [
        'Tư vấn màu và kiểm tra tình trạng tóc/da đầu.',
        'Chuẩn bị, chia tóc và thực hiện màu phù hợp.',
        'Xả, dưỡng và hướng dẫn duy trì màu.',
      ],
      'hairWash' => [
        'Tư vấn nhu cầu và sản phẩm phù hợp.',
        'Làm sạch tóc, chăm sóc da đầu nhẹ nhàng.',
        'Xả sạch, sấy và hoàn thiện.',
      ],
      _ => [
        'Trao đổi nhu cầu và vùng cần thư giãn.',
        'Thực hiện chăm sóc với lực phù hợp.',
        'Nghỉ ngơi và hướng dẫn chăm sóc sau buổi hẹn.',
      ],
    };
    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          _image(category),
          height: 260,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.5),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        s['name'] as String,
        style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        children: [
          Chip(label: Text(ApiMoney.formatVnd(s['price']))),
          Chip(
            avatar: const Icon(Icons.schedule, size: 18),
            label: Text('${s['duration']} phút'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      const Text(
        'Cách thức thực hiện',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      ...steps.indexed.map(
        (step) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${step.$1 + 1}. ${step.$2}',
            style: const TextStyle(height: 1.6),
          ),
        ),
      ),
      const Text(
        'Quy trình tham khảo; chuyên viên sẽ tư vấn theo tình trạng thực tế.',
        style: TextStyle(fontSize: 12, color: Colors.brown),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => _book(s['id'] as String),
        icon: const Icon(Icons.calendar_month_outlined),
        label: const Text('Đặt dịch vụ này'),
      ),
      const SizedBox(height: 24),
      const Text(
        'Mẫu tham khảo',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      const Text('Ảnh minh họa · Chọn mẫu để bắt đầu đặt lịch'),
      const SizedBox(height: 14),
      if (['haircut', 'perm', 'dye'].contains(category))
        ...[
          (SalonAssets.crop, 'Mohican'),
          (SalonAssets.layer, 'Layer uốn'),
          (SalonAssets.classic, 'Side part'),
        ].map(
          (style) => Card(
            child: InkWell(
              onTap: () => _book(s['id'] as String),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      style.$1,
                      height: 230,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.6),
                    ),
                  ),
                  ListTile(
                    title: Text(style.$2),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => _book(s['id'] as String),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        Image.asset(SalonAssets.interior, height: 220, fit: BoxFit.cover),
    ];
  }
}
