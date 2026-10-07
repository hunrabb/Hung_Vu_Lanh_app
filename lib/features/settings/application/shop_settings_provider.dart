import 'package:flutter/material.dart';

import '../../../core/mock/chain_seed.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/shop_settings.dart';
import '../../../core/security/access_scope.dart';

class ShopSettingsProvider extends ChangeNotifier {
  factory ShopSettingsProvider({
    ShopSettings? settings,
    AccessScope? access,
    bool Function(String)? branchExists,
  }) => ShopSettingsProvider._(
    settings,
    access ?? AccessScope(() => null),
    branchExists,
  );
  ShopSettingsProvider._(
    ShopSettings? settings,
    this._access,
    this._branchExists,
  ) {
    for (final item in ChainSeed.settings()) {
      _settings[item.branchId] = item;
    }
    if (settings != null) _settings[settings.branchId] = settings;
    _access.addListener(notifyListeners);
  }
  final AccessScope _access;
  final bool Function(String)? _branchExists;
  final Map<String, ShopSettings> _settings = {};
  String get currentBranchId => _access.currentUser?.branchId ?? 'branch-01';
  Map<String, ShopSettings> get settingsByBranch => Map.unmodifiable({
    for (final item in branchSettings) item.branchId: item,
  });
  List<ShopSettings> get branchSettings => List.unmodifiable(
    _settings.values.where(
      (s) =>
          _access.currentUser?.role != UserRole.manager &&
              _access.currentUser?.role != UserRole.staff ||
          s.branchId == currentBranchId,
    ),
  );
  ShopSettings getSettings(String branchId) {
    final actor = _access.currentUser;
    if ((actor?.role == UserRole.manager || actor?.role == UserRole.staff) &&
        actor!.branchId != branchId) {
      throw UnauthorizedException();
    }
    return _settings[branchId] ??
        (throw StateError('Branch settings not found.'));
  }

  ShopSettings? getByBranchId(String id) => getSettings(id);
  ShopSettings get settings => getSettings(currentBranchId);
  TimeOfDay get openTime => TimeOfDay(
    hour: settings.openingMinute ~/ 60,
    minute: settings.openingMinute % 60,
  );
  TimeOfDay get closeTime => TimeOfDay(
    hour: (settings.closingMinute ~/ 60) % 24,
    minute: settings.closingMinute % 60,
  );
  List<String> get closedDates => settings.closedDates;
  void updateSettings(ShopSettings value) {
    _access.requireBranch(value.branchId, write: true);
    if (_branchExists != null && !_branchExists(value.branchId)) {
      throw StateError('Branch not found.');
    }
    if (!_settings.containsKey(value.branchId)) {
      throw StateError('Branch settings not found.');
    }
    _settings[value.branchId] = value;
    notifyListeners();
  }

  void ensureBranch(String id) {
    _access.requireBoss();
    if (_settings.containsKey(id)) return;
    _settings[id] = ShopSettings(
      id: 'settings-$id',
      branchId: id,
      openingMinute: 480,
      closingMinute: 1200,
    );
    notifyListeners();
  }

  void removeBranch(String id) {
    _access.requireBoss();
    if (_settings.remove(id) != null) notifyListeners();
  }

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  bool isClosedOn(DateTime date, {String? branchId}) {
    final value = getSettings(branchId ?? currentBranchId);
    return value.closedDates.contains(_key(date)) ||
        value.closedWeekdays.contains(date.weekday);
  }

  void updateWorkingHours(TimeOfDay open, TimeOfDay close, {String? branchId}) {
    final id = branchId ?? currentBranchId;
    _access.requireBranch(id, write: true);
    final value = getSettings(id);
    final next = value.copyWith(
      openingMinute: open.hour * 60 + open.minute,
      closingMinute: close.hour * 60 + close.minute,
    );
    if (next.openingMinute != value.openingMinute ||
        next.closingMinute != value.closingMinute) {
      updateSettings(next);
    }
  }

  void addClosedDate(DateTime date, {String? branchId}) {
    final id = branchId ?? currentBranchId;
    _access.requireBranch(id, write: true);
    final value = getSettings(id);
    final key = _key(date);
    if (!value.closedDates.contains(key)) {
      updateSettings(
        value.copyWith(closedDates: [...value.closedDates, key]..sort()),
      );
    }
  }

  void removeClosedDate(DateTime date, {String? branchId}) {
    final id = branchId ?? currentBranchId;
    _access.requireBranch(id, write: true);
    final value = getSettings(id);
    final key = _key(date);
    if (value.closedDates.contains(key)) {
      updateSettings(
        value.copyWith(
          closedDates: value.closedDates.where((s) => s != key).toList(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _access.removeListener(notifyListeners);
    super.dispose();
  }
}
