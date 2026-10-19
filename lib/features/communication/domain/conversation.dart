import '../../../core/models/base_entity.dart';

class Conversation extends BaseEntity<String> {
  const Conversation({
    required super.id,
    required this.customerId,
    required this.staffId,
    this.appointmentId,
  });
  final String customerId;
  final String staffId;
  final String? appointmentId;
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'customerId': customerId,
    'staffId': staffId,
    'appointmentId': appointmentId,
  };
}
