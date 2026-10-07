class Promotion {
  const Promotion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.isActive = true,
  });

  final String id, title, subtitle, imageUrl;
  final bool isActive;

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
    id: json['id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    imageUrl: json['imageUrl'] as String,
    isActive: json['isActive'] as bool? ?? true,
  );

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
