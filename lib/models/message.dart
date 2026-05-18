enum MessageType { text, file }

class ChatMessage {
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isMe;
  final MessageType type;
  final double? progress; // 0.0 to 1.0 for file transfers

  ChatMessage({
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isMe,
    this.type = MessageType.text,
    this.progress,
  });

  ChatMessage copyWith({
    String? senderName,
    String? content,
    DateTime? timestamp,
    bool? isMe,
    MessageType? type,
    double? progress,
  }) {
    return ChatMessage(
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      type: type ?? this.type,
      progress: progress ?? this.progress,
    );
  }
}
