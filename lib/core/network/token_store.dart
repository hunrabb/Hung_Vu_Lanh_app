import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenPersistence {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureTokenPersistence implements TokenPersistence {
  SecureTokenPersistence({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'ktgk_access_token';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Serial storage prevents an old login write from surviving a following logout.
class TokenStore {
  TokenStore(this._persistence);
  final TokenPersistence _persistence;
  Future<void> _pending = Future.value();
  int _revision = 0;
  int get revision => _revision;
  Future<T> _serial<T>(Future<T> Function() action) {
    final task = _pending.then((_) => action());
    _pending = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  Future<String?> read() => _serial(_persistence.read);
  Future<int> write(String token, {required bool Function() isCurrent}) {
    final revision = ++_revision;
    return _serial(() async {
      if (isCurrent()) {
        await _persistence.write(token);
        if (!isCurrent()) await _persistence.clear();
      }
      return revision;
    });
  }

  Future<void> clearIf(String token, {required int expectedRevision}) =>
      _serial(() async {
        final value = await _persistence.read();
        if (_revision == expectedRevision && value == token) {
          _revision++;
          await _persistence.clear();
        }
      });

  Future<void> clear() {
    _revision++;
    return _serial(_persistence.clear);
  }
}
