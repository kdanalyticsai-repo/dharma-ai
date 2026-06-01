import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dharma_ai/models/community_post.dart';
import 'package:dharma_ai/services/supabase_sync.dart';

class CommunityNotifier extends StateNotifier<List<CommunityPost>> {
  CommunityNotifier() : super([]) {
    _loadPosts();
  }

  // ── Load ─────────────────────────────────────────────────────

  Future<void> _loadPosts() async {
    final client = SupabaseSync.client;
    if (client != null) {
      try {
        final rows = await client
            .from('sangha_posts')
            .select()
            .order('created_at', ascending: false)
            .limit(50);
        // Always use Supabase data when configured — even an empty list.
        // This replaces seed posts with real community posts.
        state = (rows as List).map((r) => CommunityPost(
              id: r['id'] as String,
              authorName: r['author_name'] as String,
              authorAvatar: r['author_avatar'] as String,
              content: r['content'] as String,
              timestamp: DateTime.parse(r['created_at'] as String),
              likes: r['likes_count'] as int? ?? 0,
              isLikedByMe: false,
              giftLabel: r['gift_label'] as String?,
            )).toList();
        return;
      } catch (e) {
        debugPrint('sangha_posts load error: $e');
      }
    }
    _loadSeedPosts(); // only when Supabase is not configured (dev/offline)
  }

  void _loadSeedPosts() {
    state = [
      CommunityPost(
        id: 'post_1',
        authorName: 'Aditya Seeker',
        authorAvatar: 'A',
        content: 'Just finished studying Gita Chapter 2 Verse 47. Such a deep reminder to focus on the quality of our actions and surrender expectations. Completely transformed my work mindset this morning.',
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
        content: 'Had a beautiful introspective session in AI Guru Mode today. Discussing the waves vs. peaceful silence underneath really helped dissolve my anxiety. Daily sadhana streak is now 12 days!',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        likes: 24,
        isLikedByMe: false,
      ),
    ];
  }

  // ── Add post ─────────────────────────────────────────────────

  Future<void> addPost(String content) async {
    if (content.trim().isEmpty) return;

    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;

    // Read real author name from profile when signed in
    String authorName = 'Seeker';
    String authorAvatar = 'S';
    if (client != null && uid != null) {
      try {
        final profile = await client
            .from('profiles')
            .select('full_name')
            .eq('id', uid)
            .maybeSingle();
        final name = profile?['full_name'] as String? ?? '';
        if (name.isNotEmpty) {
          authorName = name;
          authorAvatar = name[0].toUpperCase();
        }
      } catch (_) {}
    }

    final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final newPost = CommunityPost(
      id: tempId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      timestamp: DateTime.now(),
      likes: 0,
      isLikedByMe: false,
    );
    state = [newPost, ...state];

    if (client != null && uid != null) {
      try {
        final inserted = await client.from('sangha_posts').insert({
          'user_id': uid,
          'author_name': authorName,
          'author_avatar': authorAvatar,
          'content': content,
        }).select().single();
        // Replace temp id with the real DB uuid
        state = state.map((p) =>
            p.id == tempId ? p.copyWith(id: inserted['id'] as String) : p
        ).toList();
      } catch (e) {
        debugPrint('sangha_posts insert error: $e');
      }
    }
  }

  // ── Like (local only — no per-user DB tracking yet) ──────────

  void toggleLike(String postId) {
    state = state.map((post) {
      if (post.id != postId) return post;
      return post.copyWith(
        likes: post.isLikedByMe ? post.likes - 1 : post.likes + 1,
        isLikedByMe: !post.isLikedByMe,
      );
    }).toList();
  }

  // ── Gift post ────────────────────────────────────────────────

  Future<void> logGift(String friendName) async {
    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    const giftLabel = 'Subscription Gifted 🎁';
    final content = 'Gifted a Sadhaka (Premium) monthly pass to seeker $friendName.';

    final giftPost = CommunityPost(
      id: 'local_gift_${DateTime.now().millisecondsSinceEpoch}',
      authorName: 'You (Seeker)',
      authorAvatar: 'U',
      content: content,
      timestamp: DateTime.now(),
      likes: 0,
      isLikedByMe: false,
      giftLabel: giftLabel,
    );
    state = [giftPost, ...state];

    if (client != null && uid != null) {
      try {
        await client.from('sangha_posts').insert({
          'user_id': uid,
          'author_name': 'You (Seeker)',
          'author_avatar': 'U',
          'content': content,
          'is_gift': true,
          'gift_label': giftLabel,
        });
      } catch (e) {
        debugPrint('sangha gift post error: $e');
      }
    }
  }
}

final communityProvider =
    StateNotifierProvider<CommunityNotifier, List<CommunityPost>>(
  (ref) => CommunityNotifier(),
);
