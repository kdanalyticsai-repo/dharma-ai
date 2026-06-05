class CommunityComment {
  final String id;
  final String? userId; // author's account id — used to decide "You" vs others
  final String authorName;
  final String authorAvatar; // single initial letter
  final String content;
  final DateTime timestamp;

  const CommunityComment({
    required this.id,
    this.userId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.timestamp,
  });
}
