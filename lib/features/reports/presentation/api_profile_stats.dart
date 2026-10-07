import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/report_provider.dart';

class ApiProfileStats extends StatefulWidget {
  const ApiProfileStats({super.key});
  @override
  State<ApiProfileStats> createState() => _ApiProfileStatsState();
}

class _ApiProfileStatsState extends State<ApiProfileStats> {
  int _revision = -1;
  static const _query = {'page': '1', 'limit': '50'};
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = context.watch<ReportProvider>();
    if (_revision != p.revision) {
      _revision = p.revision;
      Future.microtask(() {
        if (mounted) p.load('staff/me/profile-stats', _query);
      });
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = c.watch<ReportProvider>(),
        s = p.state('staff/me/profile-stats', _query),
        d = s.data;
    if (s.error != null) {
      return Column(
        children: [
          Text(s.error!),
          TextButton(
            onPressed: () =>
                p.load('staff/me/profile-stats', _query, force: true),
            child: const Text('Thử lại'),
          ),
        ],
      );
    }
    if (d == null || s.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Card(
      color: const Color(0xFFFFF8E7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng số ca tháng này: ${(d['monthly'] as Map)['completedCount']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              'Đánh giá trung bình: ${d['averageRating'] == null ? 'Chưa có đánh giá' : (d['averageRating'] as num).toStringAsFixed(1)}',
            ),
            Text(
              'Khách đã phục vụ: ${d['registeredCustomerCount']} · Ca vãng lai: ${d['walkInCompletedCount']}',
            ),
            TextButton(
              onPressed: () =>
                  p.load('staff/me/profile-stats', _query, force: true),
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }
}
