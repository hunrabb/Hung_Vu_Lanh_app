import '../../../core/network/api_client.dart';
import '../../../core/network/api_money.dart';

class ReportRepository {
  ReportRepository(this.api);
  final ApiClient api;
  Future<Map<String, dynamic>> fetch(
    String path,
    Map<String, String> query,
  ) async {
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final data = Map<String, dynamic>.from(
      await api.request('GET', '$path$suffix') as Map,
    );
    void requiredField(String name, bool Function(dynamic) check) {
      if (!check(data[name])) {
        throw const FormatException('Phản hồi báo cáo không hợp lệ.');
      }
    }

    if (path.endsWith('/dashboard') || path.endsWith('/earnings')) {
      for (final name in ['today', 'month']) {
        requiredField(name, (v) => v is Map && v['revenueVnd'] is String);
        ApiMoney.bigInt(data[name]['revenueVnd']);
      }
    }
    if (path.endsWith('/leaderboards')) {
      requiredField('branches', (v) => v is List);
      requiredField('staff', (v) => v is List);
    }
    if (path.endsWith('/appointments')) {
      requiredField('appointments', (v) => v is List);
    }
    if (path.endsWith('/commissions')) requiredField('staff', (v) => v is List);
    if (path.endsWith('/revenue')) {
      requiredField('revenueVnd', (v) => v is String);
      requiredField('staffRanking', (v) => v is List);
      ApiMoney.bigInt(data['revenueVnd']);
    }
    if (path.endsWith('/revenue') || path.endsWith('/earnings')) {
      requiredField('transactions', (v) => v is List);
    }
    if (path.endsWith('/profile-stats')) {
      requiredField('monthly', (v) => v is Map);
      requiredField('customers', (v) => v is List);
    }
    return data;
  }

  Future<Map<String, String>> branches() async => {
    for (final b
        in await api.request('GET', 'branches', authenticated: false) as List)
      b['id'] as String: b['name'] as String,
  };
}
