import 'base_entity.dart';
import 'time_slot.dart';

class StaffShift extends BaseEntity<String> {
  StaffShift({
    required super.id,
    required this.staffId,
    this.branchId,
    required DateTime startAt,
    required DateTime endAt,
  }) : slot = TimeSlot(start: startAt, end: endAt);

  final String staffId;
  final String? branchId;
  final TimeSlot slot;
  DateTime get startAt => slot.start;
  DateTime get endAt => slot.end;

  factory StaffShift.fromJson(Map<String, dynamic> json) => StaffShift(
    id: json['id'] as String,
    staffId: json['staffId'] as String,
    branchId: json['branchId'] as String?,
    startAt: DateTime.parse(json['startAt'] as String),
    endAt: DateTime.parse(json['endAt'] as String),
  );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'staffId': staffId,
    'branchId': branchId,
    'startAt': startAt.toIso8601String(),
    'endAt': endAt.toIso8601String(),
  };

  StaffShift copyWith({
    String? id,
    String? staffId,
    String? branchId,
    DateTime? startAt,
    DateTime? endAt,
  }) => StaffShift(
    id: id ?? this.id,
    staffId: staffId ?? this.staffId,
    branchId: branchId ?? this.branchId,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
  );
}
