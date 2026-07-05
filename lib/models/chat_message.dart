class ChatMessage {
  final String id;
  final String text;
  final String role; // 'user' or 'assistant'
  final DateTime timestamp;
  final List<String>? verseCitations; // List of Verse IDs cited in the answer
  final bool isGuruMode;
  final String? feedbackId; // Supabase ai_feedback row ID — set after response logs

  const ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    required this.timestamp,
    this.verseCitations,
    required this.isGuruMode,
    this.feedbackId,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    String? role,
    DateTime? timestamp,
    List<String>? verseCitations,
    bool? isGuruMode,
    String? feedbackId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      verseCitations: verseCitations ?? this.verseCitations,
      isGuruMode: isGuruMode ?? this.isGuruMode,
      feedbackId: feedbackId ?? this.feedbackId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'role': role,
      'timestamp': timestamp.toIso8601String(),
      'verseCitations': verseCitations,
      'isGuruMode': isGuruMode,
      // feedbackId is session-only; not persisted to local storage
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      role: json['role'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      verseCitations: json['verseCitations'] != null
          ? List<String>.from(json['verseCitations'] as Iterable)
          : null,
      isGuruMode: json['isGuruMode'] as bool? ?? false,
    );
  }
}
