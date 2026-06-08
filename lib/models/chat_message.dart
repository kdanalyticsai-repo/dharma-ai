class ChatMessage {
  final String id;
  final String text;
  final String role; // 'user' or 'assistant'
  final DateTime timestamp;
  final List<String>? verseCitations; // List of Verse IDs cited in the answer
  final bool isGuruMode;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    required this.timestamp,
    this.verseCitations,
    required this.isGuruMode,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    String? role,
    DateTime? timestamp,
    List<String>? verseCitations,
    bool? isGuruMode,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      verseCitations: verseCitations ?? this.verseCitations,
      isGuruMode: isGuruMode ?? this.isGuruMode,
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
