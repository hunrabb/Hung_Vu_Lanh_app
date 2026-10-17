import '../../../core/network/api_client.dart';
import '../../../core/network/api_money.dart';

class ApiAppointment {
  ApiAppointment(Map<String, dynamic> value) : data = Map.unmodifiable(value) {
    ApiMoney.bigInt(value['totalPriceVnd']);
  }
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get branchId => data['branchId'] as String;
  String get staffId => data['staffId'] as String;
  String get status => data['status'] as String;
  String get price => data['totalPriceVnd'] as String;
  String get customerName => data['customerName'] as String? ?? '';
  DateTime get startAt => DateTime.parse(data['startAt'] as String).toUtc();
  DateTime get endAt => DateTime.parse(data['endAt'] as String).toUtc();
  String get serviceNames => (data['services'] as List? ?? [])
      .map((s) => s['serviceNameSnapshot'] ?? s['name'])
      .join(', ');
}

class ApiBookingRepository {
  ApiBookingRepository(this.api);
  final ApiClient api;
  Future<List<Map<String, dynamic>>> directory(String path) =>
      api.requestList('GET', path, authenticated: false, decode: (row) => row);
  Future<List<Map<String, dynamic>>> staff(
    String branch,
    String service,
  ) => directory(
    'branches/${Uri.encodeComponent(branch)}/staff?serviceId=${Uri.encodeQueryComponent(service)}',
  );
  Future<List<Map<String, dynamic>>> slots(
    String branch,
    String staff,
    String service,
    String date,
  ) async {
    final query = Uri(
      queryParameters: {
        'branchId': branch,
        'staffId': staff,
        'serviceIds': service,
        'date': date,
      },
    ).query;
    final body = await api.request(
      'GET',
      'booking/available-slots?$query',
      authenticated: false,
    ) as Map;
    return (body['slots'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<ApiAppointment> book({
    required String branch,
    required String staff,
    required String service,
    required String start,
    bool walkIn = false,
    String contact = '',
  }) => api.requestObject(
    'POST',
    walkIn ? 'appointments/walk-in' : 'appointments',
    decode: ApiAppointment.new,
    body: {
      if (!walkIn) 'branchId': branch,
      'staffId': staff,
      'serviceIds': [service],
      'startAt': start,
      if (walkIn) 'customerName': contact.trim(),
    },
  );
  Future<List<ApiAppointment>> list(int page, {String? status}) async {
    final query = Uri(
      queryParameters: {'page': '$page', 'limit': '50', 'status': ?status},
    ).query;
    return api.requestList(
      'GET',
      'appointments?$query',
      decode: ApiAppointment.new,
    );
  }

  Future<void> act(String id, String action) async {
    await api.request(
      'POST',
      'appointments/${Uri.encodeComponent(id)}/$action',
    );
  }
}
