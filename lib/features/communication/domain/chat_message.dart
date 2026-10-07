class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required DateTime sentAt,
  }) : sentAt = sentAt.toUtc();
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;
}
