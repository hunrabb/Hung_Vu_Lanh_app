import '../models/app_user.dart';

import 'package:flutter/foundation.dart';

class UnauthorizedException extends StateError {
  UnauthorizedException([super.message = 'Access denied.']);
}

/// Resolves the live session on every call; never trusts an actor supplied by a form.
class AccessScope extends ChangeNotifier {
  factory AccessScope(AppUser? Function() currentUser, {Listenable? changes}) =>
      AccessScope._(currentUser, changes);
  AccessScope._(this._currentUser, this._changes) {
    _changes?.addListener(notifyListeners);
  }
  final Listenable? _changes;
  @override
  void dispose() {
    _changes?.removeListener(notifyListeners);
    super.dispose();
  }

  final AppUser? Function() _currentUser;
  AppUser? get currentUser => _currentUser();
  AppUser requireUser() {
    final user = currentUser;
    if (user == null || (user.role == UserRole.staff && !user.isApproved)) {
      throw UnauthorizedException();
    }
    return user;
  }

  void requireBoss() {
    if (requireUser().role != UserRole.superAdmin) {
      throw UnauthorizedException();
    }
  }

  void requireBranch(String branchId, {bool write = false}) {
    final user = requireUser();
    if (user.role == UserRole.superAdmin) return;
    if (user.role == UserRole.manager && user.branchId == branchId) return;
    if (!write && user.role == UserRole.staff && user.branchId == branchId) {
      return;
    }
    throw UnauthorizedException();
  }
}
