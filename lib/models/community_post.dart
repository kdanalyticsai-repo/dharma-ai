class CommunityPost {
  final String id;
  final String authorName;
  final String authorAvatar;
  final String content;
  final DateTime timestamp;
  final int likes;
  final bool isLikedByMe;
  final String? giftLabel; // e.g. "Gifted a subscription to seeker Anand"

  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.timestamp,
    required this.likes,
    this.isLikedByMe = false,
    this.giftLabel,
  });

  CommunityPost copyWith({
    String? id,
    String? authorName,
    String? authorAvatar,
    String? content,
    DateTime? timestamp,
    int? likes,
    bool? isLikedByMe,
    String? giftLabel,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      likes: likes ?? this.likes,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      giftLabel: giftLabel ?? this.giftLabel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'likes': likes,
      'isLikedByMe': isLikedByMe,
      'giftLabel': giftLabel,
    };
  }

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] as String,
      authorName: json['authorName'] as String,
      authorAvatar: json['authorAvatar'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      likes: json['likes'] as int,
      isLikedByMe: json['isLikedByMe'] as bool? ?? false,
      giftLabel: json['giftLabel'] as String?,
    );
  }
}
