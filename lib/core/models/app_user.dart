enum UserRole { superAdmin, manager, staff, customer }

const _unset = Object();

/// Public profile only. Credentials and JWT belong to authentication services.
class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required DateTime createdAt,
    this.loyaltyPoints = 0,
    List<String> specializedCategoryIds = const [],
    this.averageRating,
    this.isFeatured = false,
    this.branchId,
    this.phone,
    this.address,
    bool? isApproved,
  }) : createdAt = createdAt.toUtc(),
       isApproved = isApproved ?? (role == UserRole.customer),
       specializedCategoryIds = List.unmodifiable(
         specializedCategoryIds.toSet(),
       ) {
    if (loyaltyPoints < 0 ||
        (averageRating != null &&
            (!averageRating!.isFinite ||
                averageRating! < 0 ||
                averageRating! > 5))) {
      throw ArgumentError('Invalid points or rating.');
    }
    if ((role == UserRole.staff || role == UserRole.manager) &&
        (branchId == null || branchId!.trim().isEmpty)) {
      throw ArgumentError('Staff and Manager require branchId.');
    }
  }

  final String id, name, email;
  final UserRole role;
  final DateTime createdAt;
  final int loyaltyPoints;
  final List<String> specializedCategoryIds;
  final double? averageRating;
  final bool isFeatured;
  final String? branchId, phone, address;
  final bool isApproved;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    role: UserRole.values.byName(
      json['role'] == 'boss' ? 'superAdmin' : json['role'] as String,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    loyaltyPoints: json['loyaltyPoints'] as int? ?? 0,
    specializedCategoryIds: List<String>.from(
      json['specializedCategoryIds'] as List? ?? const [],
    ),
    averageRating: (json['averageRating'] as num?)?.toDouble(),
    isFeatured: json['isFeatured'] as bool? ?? false,
    branchId: json['branchId'] as String?,
    phone: json['phone'] as String?,
    address: json['address'] as String?,
    isApproved: json['isApproved'] as bool?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.name,
    'createdAt': createdAt.toIso8601String(),
    'loyaltyPoints': loyaltyPoints,
    'specializedCategoryIds': specializedCategoryIds.toList(),
    'averageRating': averageRating,
    'isFeatured': isFeatured,
    'branchId': branchId,
    'phone': phone,
    'address': address,
    'isApproved': isApproved,
  };

  // Sentinel distinguishes omitted values from explicitly clearing with null.
  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    DateTime? createdAt,
    int? loyaltyPoints,
    List<String>? specializedCategoryIds,
    Object? averageRating = _unset,
    bool? isFeatured,
    Object? branchId = _unset,
    Object? phone = _unset,
    Object? address = _unset,
    bool? isApproved,
  }) => AppUser(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    role: role ?? this.role,
    createdAt: createdAt ?? this.createdAt,
    loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
    specializedCategoryIds:
        specializedCategoryIds ?? this.specializedCategoryIds,
    averageRating: identical(averageRating, _unset)
        ? this.averageRating
        : (averageRating as num?)?.toDouble(),
    isFeatured: isFeatured ?? this.isFeatured,
    branchId: identical(branchId, _unset) ? this.branchId : branchId as String?,
    phone: identical(phone, _unset) ? this.phone : phone as String?,
    address: identical(address, _unset) ? this.address : address as String?,
    isApproved: isApproved ?? this.isApproved,
  );
}
