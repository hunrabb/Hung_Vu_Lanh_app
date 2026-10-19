/// Shared identity for plain Dart domain models. Id can be String, int, etc.
abstract class BaseEntity<Id> {
  const BaseEntity({required this.id});
  final Id id;

  bool hasSameIdentity(BaseEntity<Id> other) =>
      runtimeType == other.runtimeType && id == other.id;

  Map<String, dynamic> toJson() => {'id': id};
}

/// Common fields and behavior for entities with a display name.
abstract class NamedEntity<Id> extends BaseEntity<Id> {
  const NamedEntity({
    required super.id,
    required this.name,
    this.description = '',
  });
  final String name;
  final String description;

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    return name.toLowerCase().contains(normalized) ||
        description.toLowerCase().contains(normalized);
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'name': name,
    if (description.isNotEmpty) 'description': description,
  };
}
