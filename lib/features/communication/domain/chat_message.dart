import '../../../core/models/base_entity.dart';

class ChatMessage extends BaseEntity<String> {
  ChatMessage({
    required super.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required DateTime sentAt,
  }) : sentAt = sentAt.toUtc();
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'conversationId': conversationId,
    'senderId': senderId,
    'text': text,
    'sentAt': sentAt.toIso8601String(),
  };
}
