import '../../../core/security/access_scope.dart';

import 'package:flutter/foundation.dart';

import '../../../core/models/service.dart';
import '../data/mock_service_repository.dart';

class ServiceProvider extends ChangeNotifier {
  ServiceProvider(this._repository, {AccessScope? access})
    : _access = access ?? AccessScope(() => null) {
    _access.addListener(notifyListeners);
  }
  final AccessScope _access;
  final MockServiceRepository _repository;
  List<Service> get services => _repository.getAll();
  Service? getById(String id) => _repository.getById(id);

  void add(Service item) {
    _access.requireBoss();
    _repository.add(item);
    notifyListeners();
  }

  void update(Service item) {
    _access.requireBoss();
    _repository.update(item);
    notifyListeners();
  }

  void delete(String id) {
    _access.requireBoss();
    _repository.delete(id);
    notifyListeners();
  }

  @override
  void dispose() {
    _access.removeListener(notifyListeners);
    super.dispose();
  }
}
