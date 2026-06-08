import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/models/community_post.dart';
import 'package:dharma_ai/models/community_comment.dart';
import 'package:dharma_ai/providers/community_provider.dart';
import 'package:dharma_ai/screens/gift_subscription_screen.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/auth_provider.dart';

class SanghaScreen extends ConsumerStatefulWidget {
  const SanghaScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SanghaScreen> createState() => _SanghaScreenState();
}

class _SanghaScreenState extends ConsumerState<SanghaScreen> {
  final TextEditingController _postController = TextEditingController();

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(communityProvider);
    final textTheme = Theme.of(context).textTheme;
    final currentLanguage = ref.watch(languageProvider);

    return Scaffold(
      body: MandalaBackground(
        scale: 0.85,
        alignment: Alignment.center,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title + Gifting button
              Padding(
                padding: const EdgeInsets.fromLTRB(SacredTheme.marginEdge, 12, SacredTheme.marginEdge, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppTranslations.get('tabSanghaTitle', currentLanguage),
                      style: textTheme.headlineMedium?.copyWith(
                        color: SacredTheme.headingColor(context),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SacredTheme.primary.withOpacity(0.1),
                        foregroundColor: SacredTheme.primary,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        side: BorderSide(color: SacredTheme.primary.withOpacity(0.3), width: 0.5),
                      ),
                      icon: const Icon(Icons.card_giftcard, size: 14),
                      label: Text(
                        AppTranslations.get('giftPassBtn', currentLanguage),
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        // Gifting buys a pass for someone else (it never
                        // upgrades the buyer), so it's available to everyone —
                        // free users included.
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GiftSubscriptionScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const FadingDivider(height: 12),

              // Purpose / intro
              Padding(
                padding: const EdgeInsets.fromLTRB(SacredTheme.marginEdge, 0, SacredTheme.marginEdge, 4),
                child: Text(
                  AppTranslations.get('sanghaIntro', currentLanguage),
                  style: textTheme.bodyMedium,
                ),
              ),

              // Post composer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge, vertical: 8),
                child: Card(
                  color: SacredTheme.surfaceContainerLowest,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _postController,
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: AppTranslations.get('shareReflectionPlaceholder', currentLanguage),
                              hintStyle: textTheme.bodyMedium?.copyWith(color: SacredTheme.outline),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            style: textTheme.bodyLarge,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.spa, color: SacredTheme.primary),
                          onPressed: () {
                            final text = _postController.text;
                            if (text.trim().isNotEmpty) {
                              ref.read(communityProvider.notifier).addPost(text);
                              _postController.clear();
                              FocusScope.of(context).unfocus();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Posts List
              Expanded(
                child: posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.spa_outlined,
                                size: 48, color: SacredTheme.outlineVariant),
                            const SizedBox(height: 16),
                            Text(
                              'Be the first to share a reflection',
                              style: textTheme.bodyLarge?.copyWith(
                                  color: SacredTheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your wisdom inspires the Sangha.',
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: SacredTheme.primary,
                        onRefresh: () => ref.read(communityProvider.notifier).refresh(),
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: SacredTheme.marginEdge, vertical: 8),
                          itemCount: posts.length,
                          itemBuilder: (context, index) =>
                              CommunityPostCard(post: posts[index]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunityPostCard extends ConsumerWidget {
  final CommunityPost post;

  const CommunityPostCard({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final currentLanguage = ref.watch(languageProvider);
    final currentUid = ref.watch(authUserProvider).valueOrNull?.id;
    final timeString = _formatTimeAgo(post.timestamp);

    // Resolve displayed names. Show "You" ONLY for the current user's own posts
    // (by account id) — never based on the stored name, so other users' posts
    // never appear as "You".
    String displayName = post.authorName;
    if (post.userId != null && post.userId == currentUid) {
      displayName = AppTranslations.get('youSeeker', currentLanguage);
    } else if (post.authorName == 'You (Seeker)' || post.authorName == 'Seeker') {
      // Legacy/anonymous posts stored before this fix → show a generic label.
      displayName = AppTranslations.get('aSeeker', currentLanguage);
    } else if (post.authorName == 'Sangha Bot') {
      displayName = AppTranslations.get('sanghaBot', currentLanguage);
    }

    // Resolve post content text
    String contentText = post.content;
    if (post.id == 'post_1' || post.id == 'post_2' || post.id == 'post_3') {
      contentText = AppTranslations.get(post.id, currentLanguage);
    } else if (post.content.startsWith('Gifted a Sadhaka (Premium) monthly pass to seeker ')) {
      final friendName = post.content.substring('Gifted a Sadhaka (Premium) monthly pass to seeker '.length);
      final cleanFriendName = friendName.endsWith('.') ? friendName.substring(0, friendName.length - 1) : friendName;
      final prefix = AppTranslations.get('giftPostContentPrefix', currentLanguage);
      contentText = '$prefix $cleanFriendName.';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Card(
        color: SacredTheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gifting Banner (if applicable)
              if (post.giftLabel != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: SacredTheme.templeGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                    border: Border.all(color: SacredTheme.templeGold.withOpacity(0.3), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.card_giftcard, size: 14, color: SacredTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${AppTranslations.get('giftPassBtn', currentLanguage)} 🎁',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: SacredTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Author Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: post.giftLabel != null
                        ? SacredTheme.templeGold
                        : SacredTheme.secondary,
                    radius: 18,
                    child: Text(
                      post.authorAvatar,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          timeString,
                          style: textTheme.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Post Content
              Text(
                contentText,
                style: textTheme.bodyLarge?.copyWith(height: 1.4),
              ),
              
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Action buttons (Like, Comment)
              Row(
                children: [
                  // Like action
                  InkWell(
                    onTap: () {
                      ref.read(communityProvider.notifier).toggleLike(post.id);
                    },
                    borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                            color: post.isLikedByMe ? SacredTheme.primary : SacredTheme.outline,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.likes}',
                            style: textTheme.labelSmall?.copyWith(
                              color: post.isLikedByMe ? SacredTheme.primary : SacredTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Comment / reply action — opens the thread
                  InkWell(
                    onTap: () => _openComments(context, post),
                    borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.mode_comment_outlined, size: 18, color: SacredTheme.outline),
                          const SizedBox(width: 6),
                          Text(
                            post.commentsCount > 0
                                ? '${AppTranslations.get('replyBtn', currentLanguage)} · ${post.commentsCount}'
                                : AppTranslations.get('replyBtn', currentLanguage),
                            style: textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openComments(BuildContext context, CommunityPost post) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      showDialog(
        context: context,
        builder: (ctx) {
          final height = MediaQuery.of(ctx).size.height;
          return Dialog(
            backgroundColor: SacredTheme.surface,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: height * 0.78,
                child: _CommentsSheet(post: post, isDialog: true),
              ),
            ),
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: SacredTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _CommentsSheet(post: post),
      );
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m ago';
    }
    return 'just now';
  }
}

// ── Comment thread (bottom sheet or centered dialog) ───────────
class _CommentsSheet extends ConsumerStatefulWidget {
  final CommunityPost post;
  final bool isDialog;
  const _CommentsSheet({required this.post, this.isDialog = false});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  bool _sending = false;
  List<CommunityComment>? _comments; // null = still loading

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ref.read(communityProvider.notifier).loadComments(widget.post.id);
    if (!mounted) return;
    setState(() => _comments = list);
  }

  @override
  void dispose() {
    _controller.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final lang = ref.read(languageProvider);
    setState(() => _sending = true);
    final result =
        await ref.read(communityProvider.notifier).addComment(widget.post.id, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('sanghaReplyError', lang))),
      );
      return;
    }
    _controller.clear();
    FocusScope.of(context).unfocus();
    setState(() => _comments = [...?_comments, result]);
  }

  // Optimistically flip the heart on a reply, then persist. Revert on failure.
  Future<void> _toggleLike(CommunityComment c) async {
    final wasLiked = c.isLikedByMe;
    setState(() {
      _comments = _comments
          ?.map((x) => x.id == c.id
              ? x.copyWith(likes: x.likes + (wasLiked ? -1 : 1), isLikedByMe: !wasLiked)
              : x)
          .toList();
    });
    final ok = await ref
        .read(communityProvider.notifier)
        .toggleCommentLike(c.id, wasLiked);
    if (!ok && mounted) {
      setState(() {
        _comments = _comments
            ?.map((x) => x.id == c.id
                ? x.copyWith(likes: c.likes, isLikedByMe: c.isLikedByMe)
                : x)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lang = ref.watch(languageProvider);
    final currentUid = ref.watch(authUserProvider).valueOrNull?.id;
    final comments = _comments;

    if (widget.isDialog) {
      return _buildContent(context, _listScrollController, textTheme, lang, currentUid, comments);
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, sc) => _buildContent(ctx, sc, textTheme, lang, currentUid, comments),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ScrollController scrollController,
    TextTheme textTheme,
    AppLanguage lang,
    String? currentUid,
    List<CommunityComment>? comments,
  ) {
    return Column(
      children: [
        if (!widget.isDialog) ...[
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: SacredTheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ] else
          const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(
                AppTranslations.get('sanghaRepliesTitle', lang),
                style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: SacredTheme.primary),
              ),
              const SizedBox(width: 8),
              if (widget.post.commentsCount > 0)
                Text('· ${widget.post.commentsCount}', style: textTheme.labelMedium),
              if (widget.isDialog) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: comments == null
              ? const Center(child: CircularProgressIndicator())
              : comments.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          AppTranslations.get('sanghaNoReplies', lang),
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: SacredTheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, i) {
                        final c = comments[i];
                        final isMine = c.userId != null && c.userId == currentUid;
                        final name = isMine
                            ? AppTranslations.get('sanghaYou', lang)
                            : c.authorName;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: SacredTheme.secondary,
                              child: Text(c.authorAvatar,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: textTheme.bodyMedium
                                          ?.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(c.content,
                                      style: textTheme.bodyMedium?.copyWith(height: 1.35)),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _toggleLike(c),
                                    borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            c.isLikedByMe
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            size: 15,
                                            color: c.isLikedByMe
                                                ? SacredTheme.primary
                                                : SacredTheme.outline,
                                          ),
                                          if (c.likes > 0) ...[
                                            const SizedBox(width: 4),
                                            Text('${c.likes}',
                                                style: textTheme.labelSmall?.copyWith(
                                                    color: c.isLikedByMe
                                                        ? SacredTheme.primary
                                                        : SacredTheme.onSurfaceVariant)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
        ),
        const Divider(height: 1),
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: AppTranslations.get('sanghaReplyHint', lang),
                    filled: true,
                    fillColor: SacredTheme.surfaceContainerLow,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: SacredTheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
