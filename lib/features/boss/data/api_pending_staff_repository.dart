import '../../../core/models/app_user.dart';
import '../../../core/network/api_client.dart';

class ApiPendingStaffRepository {
  ApiPendingStaffRepository(this.client);
  final ApiClient client;
  Future<List<AppUser>> fetch() async =>
      (await client.request('GET', 'users/pending') as List)
          .map((row) => AppUser.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
  Future<Map<String, String>> branches() async => {
    for (final row in await client.request(
      'GET',
      'branches',
      authenticated: false,
    ) as List)
      row['id'] as String: row['name'] as String,
  };
  Future<void> approve(String id, String password) async {
    await client.request(
      'POST',
      'users/${Uri.encodeComponent(id)}/approve',
      body: {'password': password},
    );
  }

  Future<void> reject(String id) async {
    await client.request('DELETE', 'users/${Uri.encodeComponent(id)}/pending');
  }
}
