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

        // Which of these posts has the current user already liked? (so the
        // heart shows filled and toggling un-likes correctly).
        final uid = SupabaseSync.userId;
        Set<String> myLikes = {};
        if (uid != null) {
          try {
            final likeRows =
                await client.from('post_likes').select('post_id').eq('user_id', uid);
            myLikes = (likeRows as List).map((r) => r['post_id'] as String).toSet();
          } catch (e) {
            debugPrint('post_likes load error: $e');
          }
        }

        // Always use Supabase data when configured — even an empty list.
        // This replaces seed posts with real community posts.
        state = (rows as List).map((r) => CommunityPost(
              id: r['id'] as String,
              userId: r['user_id'] as String?,
              authorName: r['author_name'] as String,
              authorAvatar: r['author_avatar'] as String,
              content: r['content'] as String,
              timestamp: DateTime.parse(r['created_at'] as String),
              likes: r['likes_count'] as int? ?? 0,
              isLikedByMe: myLikes.contains(r['id'] as String),
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

  // Resolve the signed-in user's display name + avatar letter from their
  // profile (falls back to a generic Seeker).
  Future<(String, String)> _currentAuthor(dynamic client, String? uid) async {
    if (client != null && uid != null) {
      try {
        final profile = await client
            .from('profiles')
            .select('full_name')
            .eq('id', uid)
            .maybeSingle();
        final name = profile?['full_name'] as String? ?? '';
        if (name.isNotEmpty) {
          return (name, name[0].toUpperCase());
        }
      } catch (_) {}
    }
    return ('Seeker', 'S');
  }

  Future<void> addPost(String content) async {
    if (content.trim().isEmpty) return;

    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    final (authorName, authorAvatar) = await _currentAuthor(client, uid);

    final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final newPost = CommunityPost(
      id: tempId,
      userId: uid,
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

  // ── Like (persisted per-user, shared across everyone) ────────
  // Optimistically flips the heart, then records it in post_likes. A DB trigger
  // updates sangha_posts.likes_count so the post's author — and every other
  // seeker — sees the reaction. Reverts the optimistic change if the write fails.

  Future<void> toggleLike(String postId) async {
    // Capture the pre-toggle state to know whether to add or remove the like.
    final existing = state.firstWhere(
      (p) => p.id == postId,
      orElse: () => CommunityPost(
          id: '', authorName: '', authorAvatar: '', content: '',
          timestamp: DateTime.now(), likes: 0, isLikedByMe: false),
    );
    if (existing.id.isEmpty) return;
    final wasLiked = existing.isLikedByMe;

    void apply(bool liked) {
      state = state.map((post) {
        if (post.id != postId) return post;
        return post.copyWith(
          likes: (post.likes + (liked ? 1 : -1)).clamp(0, 1 << 31),
          isLikedByMe: liked,
        );
      }).toList();
    }

    apply(!wasLiked); // optimistic

    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    // Local/offline posts (not yet in the DB) stay local-only.
    if (client == null || uid == null || postId.startsWith('local_')) return;

    try {
      if (wasLiked) {
        await client.from('post_likes').delete().eq('post_id', postId).eq('user_id', uid);
      } else {
        await client.from('post_likes').insert({'post_id': postId, 'user_id': uid});
      }
    } catch (e) {
      debugPrint('toggleLike error: $e');
      apply(wasLiked); // revert on failure
    }
  }

  // ── Gift post ────────────────────────────────────────────────

  Future<void> logGift(String friendName) async {
    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    const giftLabel = 'Subscription Gifted 🎁';
    final content = 'Gifted a Sadhaka (Premium) monthly pass to seeker $friendName.';
    // Store the gifter's real name + id (NOT the literal "You (Seeker)"), so
    // the feed can show "You" only to the gifter and the real name to others.
    final (authorName, authorAvatar) = await _currentAuthor(client, uid);

    final giftPost = CommunityPost(
      id: 'local_gift_${DateTime.now().millisecondsSinceEpoch}',
      userId: uid,
      authorName: authorName,
      authorAvatar: authorAvatar,
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
          'author_name': authorName,
          'author_avatar': authorAvatar,
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
