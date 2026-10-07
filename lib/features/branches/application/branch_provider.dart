import 'package:flutter/foundation.dart';

import '../../../core/models/branch.dart';
import '../../../core/security/access_scope.dart';
import '../../users/data/mock_user_repository.dart';
import '../../booking/data/mock_appointment_repository.dart';
import '../../settings/application/shop_settings_provider.dart';
import '../data/mock_branch_repository.dart';

class BranchProvider extends ChangeNotifier {
  BranchProvider(
    this._repository, {
    required this.access,
    required this.users,
    required this.appointments,
    required this.settings,
  });
  final MockBranchRepository _repository;
  final AccessScope access;
  final MockUserRepository users;
  final MockAppointmentRepository appointments;
  final ShopSettingsProvider settings;
  List<Branch> get branches => _repository.getAll();
  Branch? getById(String id) => _repository.getById(id);
  void add(Branch item) {
    access.requireBoss();
    _repository.add(item);
    settings.ensureBranch(item.id);
    notifyListeners();
  }

  void update(Branch item) {
    access.requireBoss();
    _repository.update(item);
    notifyListeners();
  }

  void delete(String id) {
    access.requireBoss();
    if (users.getAll().any((u) => u.branchId == id) ||
        appointments.getAll().any((a) => a.branchId == id)) {
      throw StateError('Chi nhánh còn nhân sự hoặc lịch hẹn.');
    }
    _repository.delete(id);
    settings.removeBranch(id);
    notifyListeners();
  }
}
