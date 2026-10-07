class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
  });
  final String id, name, address, phone;
  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    phone: json['phone'] as String,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'phone': phone,
  };
  Branch copyWith({String? id, String? name, String? address, String? phone}) =>
      Branch(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        phone: phone ?? this.phone,
      );
}
