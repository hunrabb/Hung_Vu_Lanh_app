import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/core/models/base_entity.dart';
import 'package:ktgk/core/models/branch.dart';
import 'package:ktgk/core/models/service.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/core/models/promotion.dart';

class _Example extends NamedEntity<int> {
  const _Example({required super.id, required super.name});
}

void main() {
  test('generic identities distinguish types and allow integer IDs', () {
    const first = _Example(id: 1, name: 'First');
    const renamed = _Example(id: 1, name: 'Renamed');
    expect(first.hasSameIdentity(renamed), true);
    expect(first.hasSameIdentity(const _Example(id: 2, name: 'Second')), false);
    expect(first.toJson(), {'id': 1, 'name': 'First'});
    final service = Service(
      id: 'same',
      name: 'Service',
      category: ServiceCategory.haircut,
      durationMinutes: 30,
      priceVnd: 100000,
    );
    const branch = Branch(
      id: 'same',
      name: 'Branch',
      address: 'Address',
      phone: '090',
    );
    expect(service.hasSameIdentity(branch), false);
  });
  test('named entities inherit search and preserve optional descriptions in copies and JSON', () {
    final service = Service(
      id: 's',
      name: 'Haircut',
      description: 'Relaxing wash',
      category: ServiceCategory.haircut,
      durationMinutes: 30,
      priceVnd: 100000,
    );
    const branch = Branch(
      id: 'b',
      name: 'Branch',
      description: 'Central location',
      address: 'Address',
      phone: '090',
    );
    final user = AppUser(
      id: 'u',
      name: 'Customer',
      description: 'Regular visitor',
      email: 'u@example.com',
      role: UserRole.customer,
      createdAt: DateTime.utc(2026),
    );
    final List<NamedEntity<String>> entities = [service, branch, user];
    expect(
      entities.where((entity) => entity.matchesQuery(' WASH ')).single,
      same(service),
    );
    expect(entities.every((entity) => entity.matchesQuery('')), true);
    expect(
      Service.fromJson(service.copyWith(priceVnd: 200000).toJson()).description,
      service.description,
    );
    expect(
      Branch.fromJson(branch.copyWith(phone: '091').toJson()).description,
      branch.description,
    );
    expect(
      AppUser.fromJson(user.copyWith(name: 'Updated').toJson()).description,
      user.description,
    );
    expect(
      service.copyWith(description: '').toJson().containsKey('description'),
      false,
    );
  });
  test(
    'promotion inherits named fields while preserving its existing wire keys',
    () {
      const promo = Promotion(
        id: 'p',
        title: 'Offer',
        subtitle: 'Welcome',
        imageUrl: '',
      );
      final NamedEntity<String> entity = promo;
      expect(entity.name, 'Offer');
      expect(entity.description, 'Welcome');
      expect(entity.matchesQuery('welcome'), true);
      expect(promo.toJson(), {
        'id': 'p',
        'title': 'Offer',
        'subtitle': 'Welcome',
        'imageUrl': '',
        'isActive': true,
      });
    },
  );
}
