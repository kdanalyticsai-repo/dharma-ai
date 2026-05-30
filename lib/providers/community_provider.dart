import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dharma_ai/models/community_post.dart';

class CommunityNotifier extends StateNotifier<List<CommunityPost>> {
  CommunityNotifier() : super([]) {
    _loadSeedPosts();
  }

  void _loadSeedPosts() {
    state = [
      CommunityPost(
        id: 'post_1',
        authorName: 'Aditya Seeker',
        authorAvatar: 'A',
        content: 'Just finished studying Gita Chapter 2 Verse 47. It is such a deep reminder to focus entirely on the quality of our actions and surrender the expectations of success or failure. Completely transformed my work mindset this morning.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        likes: 12,
        isLikedByMe: false,
      ),
      CommunityPost(
        id: 'post_2',
        authorName: 'Sangha Bot',
        authorAvatar: 'S',
        content: 'Gifted a Sadhaka (Premium) annual subscription pass to seeker Anand.',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        likes: 8,
        isLikedByMe: true,
        giftLabel: 'Subscription Gifted 🎁',
      ),
      CommunityPost(
        id: 'post_3',
        authorName: 'Meera Devi',
        authorAvatar: 'M',
        content: 'Had a beautiful introspective session in AI Guru Mode today. Discussing the analogy of the waves on the ocean surface vs. the peaceful silence underneath really helped dissolve my anxiety. Daily sadhana streak is now 12 days!',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        likes: 24,
        isLikedByMe: false,
      ),
    ];
  }

  void addPost(String content) {
    if (content.trim().isEmpty) return;

    final newPost = CommunityPost(
      id: DateTime.now().toString(),
      authorName: 'You (Seeker)',
      authorAvatar: 'U',
      content: content,
      timestamp: DateTime.now(),
      likes: 0,
      isLikedByMe: false,
    );

    state = [newPost, ...state];
  }

  void toggleLike(String postId) {
    state = state.map((post) {
      if (post.id == postId) {
        final newLikeCount = post.isLikedByMe ? post.likes - 1 : post.likes + 1;
        return post.copyWith(
          likes: newLikeCount,
          isLikedByMe: !post.isLikedByMe,
        );
      }
      return post;
    }).toList();
  }

  void logGift(String friendName) {
    final giftPost = CommunityPost(
      id: DateTime.now().toString(),
      authorName: 'You (Seeker)',
      authorAvatar: 'U',
      content: 'Gifted a Sadhaka (Premium) monthly pass to seeker $friendName.',
      timestamp: DateTime.now(),
      likes: 0,
      isLikedByMe: false,
      giftLabel: 'Subscription Gifted 🎁',
    );
    state = [giftPost, ...state];
  }
}

final communityProvider = StateNotifierProvider<CommunityNotifier, List<CommunityPost>>((ref) {
  return CommunityNotifier();
});
