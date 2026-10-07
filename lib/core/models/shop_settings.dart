/// Opening times and calendar dates are interpreted in Vietnam local time.
class ShopSettings {
  ShopSettings({
    this.id = 'default',
    required this.branchId,
    required this.openingMinute,
    required this.closingMinute,
    List<int> closedWeekdays = const [],
    List<String> closedDates = const [],
  }) : closedWeekdays = List.unmodifiable(closedWeekdays),
       closedDates = List.unmodifiable(closedDates) {
    if (branchId.trim().isEmpty ||
        openingMinute < 0 ||
        closingMinute > 1440 ||
        closingMinute <= openingMinute ||
        closedWeekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError('Invalid opening hours or weekdays.');
    }
    for (final date in closedDates) {
      final parsed = DateTime.tryParse(date);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
          parsed == null ||
          parsed.toIso8601String().substring(0, 10) != date) {
        throw ArgumentError('Closed dates must be valid yyyy-MM-dd dates.');
      }
    }
  }

  final String id;
  final String branchId;
  final int openingMinute, closingMinute;
  final List<int> closedWeekdays;
  final List<String> closedDates;

  factory ShopSettings.fromJson(Map<String, dynamic> json) => ShopSettings(
    id: json['id'] as String,
    branchId: json['branchId'] as String,
    openingMinute: json['openingMinute'] as int,
    closingMinute: json['closingMinute'] as int,
    closedWeekdays: List<int>.from(json['closedWeekdays'] as List? ?? const []),
    closedDates: List<String>.from(json['closedDates'] as List? ?? const []),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'branchId': branchId,
    'openingMinute': openingMinute,
    'closingMinute': closingMinute,
    'closedWeekdays': closedWeekdays.toList(),
    'closedDates': closedDates.toList(),
  };

  ShopSettings copyWith({
    String? id,
    String? branchId,
    int? openingMinute,
    int? closingMinute,
    List<int>? closedWeekdays,
    List<String>? closedDates,
  }) => ShopSettings(
    id: id ?? this.id,
    branchId: branchId ?? this.branchId,
    openingMinute: openingMinute ?? this.openingMinute,
    closingMinute: closingMinute ?? this.closingMinute,
    closedWeekdays: closedWeekdays ?? this.closedWeekdays,
    closedDates: closedDates ?? this.closedDates,
  );
}
