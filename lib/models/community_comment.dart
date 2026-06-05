class CommunityComment {
  final String id;
  final String? userId; // author's account id — used to decide "You" vs others
  final String authorName;
  final String authorAvatar; // single initial letter
  final String content;
  final DateTime timestamp;
  final int likes;
  final bool isLikedByMe;

  const CommunityComment({
    required this.id,
    this.userId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.timestamp,
    this.likes = 0,
    this.isLikedByMe = false,
  });

  CommunityComment copyWith({int? likes, bool? isLikedByMe}) {
    return CommunityComment(
      id: id,
      userId: userId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      timestamp: timestamp,
      likes: likes ?? this.likes,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }
}
