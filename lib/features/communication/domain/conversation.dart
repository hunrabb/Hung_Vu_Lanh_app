class Conversation {
  const Conversation({
    required this.id,
    required this.customerId,
    required this.staffId,
    this.appointmentId,
  });
  final String id;
  final String customerId;
  final String staffId;
  final String? appointmentId;
}
