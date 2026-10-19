import 'base_entity.dart';

class Branch extends NamedEntity<String> {
  const Branch({
    required super.id,
    required super.name,
    super.description,
    required this.address,
    required this.phone,
  });
  final String address, phone;
  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    address: json['address'] as String,
    phone: json['phone'] as String,
  );
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'address': address,
    'phone': phone,
  };
  Branch copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    String? phone,
  }) => Branch(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    address: address ?? this.address,
    phone: phone ?? this.phone,
  );
}
