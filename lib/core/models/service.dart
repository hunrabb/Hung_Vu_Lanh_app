enum ServiceCategory { haircut, massage, hairWash, perm, dye, shaving }

class Service {
  Service({
    required this.id,
    required this.name,
    required this.category,
    required this.durationMinutes,
    required this.priceVnd,
    this.isActive = true,
  }) {
    if (durationMinutes <= 0 || priceVnd < 0) {
      throw ArgumentError('Duration must be positive and price non-negative.');
    }
  }

  final String id, name;
  final ServiceCategory category;

  /// Stable category ID, shared with Staff.specializedCategoryIds.
  String get categoryId => category.name;
  final int durationMinutes, priceVnd;
  final bool isActive;

  factory Service.fromJson(Map<String, dynamic> json) => Service(
    id: json['id'] as String,
    name: json['name'] as String,
    category: ServiceCategory.values.byName(json['category'] as String),
    durationMinutes: json['durationMinutes'] as int,
    priceVnd: json['priceVnd'] as int,
    isActive: json['isActive'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'durationMinutes': durationMinutes,
    'priceVnd': priceVnd,
    'isActive': isActive,
  };

  Service copyWith({
    String? id,
    String? name,
    ServiceCategory? category,
    int? durationMinutes,
    int? priceVnd,
    bool? isActive,
  }) => Service(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    priceVnd: priceVnd ?? this.priceVnd,
    isActive: isActive ?? this.isActive,
  );
}
