import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ktgk/core/data/memory_store.dart';
import 'package:ktgk/core/utils/collection_utils.dart';
import 'package:ktgk/core/network/api_client.dart';
import 'package:ktgk/core/network/token_store.dart';

import 'api_integration_test.dart' show MemoryTokens, json;

void main() {
  test('generic function preserves type and stops at the first match', () {
    var visited = 0;
    final int? number = findFirst<int>([1, 2, 3], (value) {
      visited++;
      return value >= 2;
    });
    expect(number, 2);
    expect(visited, 2);
    final String? word = findFirst<String>([
      'one',
      'two',
    ], (value) => value == 'two');
    expect(word, 'two');
    expect(findFirst<int>([], (_) => true), isNull);
    expect(findFirst<int>([1, 2], (value) => value == 3), isNull);
  });
  test('store preserves order, snapshots and data when preparation fails', () {
    final store = MemoryStore<({String id, int value}), String>(
      idOf: (row) => row.id,
    );
    store.add((id: 'first', value: 1));
    store.add((id: 'second', value: 2));
    final snapshot = store.getAll();
    expect(() => snapshot.clear(), throwsUnsupportedError);
    expect(() => store.add((id: 'first', value: 3)), throwsStateError);
    expect(
      () => store.update((
        id: 'first',
        value: 4,
      ), prepare: (_) => throw ArgumentError()),
      throwsArgumentError,
    );
    expect(
      () => store.add((
        id: 'third',
        value: 3,
      ), prepare: (_) => throw ArgumentError()),
      throwsArgumentError,
    );
    expect(store.getById('first')?.value, 1);
    expect(store.getById('third'), isNull);
    store.update((id: 'first', value: 5));
    expect(store.getAll().map((row) => row.id), ['first', 'second']);
    expect(snapshot.first.value, 1);
    store.delete('first');
    expect(store.getById('first'), isNull);
    expect(() => store.update((id: 'missing', value: 0)), throwsStateError);
    expect(() => store.delete('missing'), throwsStateError);
  });
  test('store supports non-string identities without model inheritance', () {
    final store = MemoryStore<({int id, String name}), int>(
      idOf: (row) => row.id,
    );
    store.add((id: 42, name: 'Example'));
    expect(store.getById(42)?.name, 'Example');
    store.delete(42);
    expect(store.getAll(), isEmpty);
  });
  test(
    'typed API decoding preserves authentication, request body and errors',
    () async {
      final tokens = TokenStore(MemoryTokens());
      await tokens.write('session', isCurrent: () => true);
      var calls = 0;
      final api = ApiClient(
        tokens: tokens,
        client: MockClient((request) async {
          calls++;
          if (calls == 1) {
            expect(request.method, 'PATCH');
            expect(request.headers['Authorization'], 'Bearer session');
            expect(jsonDecode(request.body), {'value': 7});
            return json({'value': 7});
          }
          if (calls == 2) {
            expect(request.headers.containsKey('Authorization'), false);
            return json([
              {'value': 1},
              {'value': 2},
            ]);
          }
          return json({'message': 'Conflict'}, 409);
        }),
      );
      addTearDown(api.close);
      final value = await api.requestObject<int>(
        'PATCH',
        'example',
        decode: (row) => row['value'] as int,
        body: {'value': 7},
      );
      expect(value, 7);
      final values = await api.requestList<int>(
        'GET',
        'example',
        authenticated: false,
        decode: (row) => row['value'] as int,
      );
      expect(values, [1, 2]);
      await expectLater(
        api.requestObject<int>(
          'GET',
          'example',
          decode: (row) => row['value'] as int,
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
    },
  );
}
