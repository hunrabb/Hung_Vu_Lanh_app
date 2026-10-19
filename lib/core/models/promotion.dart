import 'base_entity.dart';

class Promotion extends NamedEntity<String> {
  const Promotion({
    required super.id,
    required String title,
    required String subtitle,
    required this.imageUrl,
    this.isActive = true,
  }) : super(name: title, description: subtitle);

  String get title => name;
  String get subtitle => description;
  final String imageUrl;
  final bool isActive;

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
    id: json['id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    imageUrl: json['imageUrl'] as String,
    isActive: json['isActive'] as bool? ?? true,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'imageUrl': imageUrl,
    'isActive': isActive,
  };

  Promotion copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? imageUrl,
    bool? isActive,
  }) => Promotion(
    id: id ?? this.id,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    imageUrl: imageUrl ?? this.imageUrl,
    isActive: isActive ?? this.isActive,
  );
}
