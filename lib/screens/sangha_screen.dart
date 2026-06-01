import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/models/community_post.dart';
import 'package:dharma_ai/providers/community_provider.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/purchase_service.dart';
import 'package:dharma_ai/screens/subscription_paywall_screen.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/providers/language_provider.dart';

class SanghaScreen extends ConsumerStatefulWidget {
  const SanghaScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SanghaScreen> createState() => _SanghaScreenState();
}

class _SanghaScreenState extends ConsumerState<SanghaScreen> {
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _giftFriendController = TextEditingController();

  void _showGiftDialog(BuildContext context) {
    final currentLanguage = ref.read(languageProvider);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: SacredTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SacredTheme.radiusMd),
          ),
          title: Text(
            AppTranslations.get('giftWisdomPassTitle', currentLanguage),
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: SacredTheme.headingColor(context),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get('giftWisdomPassDesc', currentLanguage),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _giftFriendController,
                decoration: InputDecoration(
                  labelText: AppTranslations.get('friendNameLabel', currentLanguage),
                  hintText: 'e.g. Ramesh, Anand',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SacredTheme.radiusDefault),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _giftFriendController.clear();
                Navigator.pop(context);
              },
              child: Text(
                AppTranslations.get('cancelBtn', currentLanguage),
                style: const TextStyle(color: SacredTheme.outline),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final friend = _giftFriendController.text;
                if (friend.trim().isNotEmpty) {
                  // Log the gift in the community feed
                  ref.read(communityProvider.notifier).logGift(friend);
                  _giftFriendController.clear();
                  Navigator.pop(context);
                  
                  // Show success snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${AppTranslations.get('giftSuccessPrefix', currentLanguage)} $friend${AppTranslations.get('giftSuccessSuffix', currentLanguage)}'),
                      backgroundColor: SacredTheme.deepSaffron,
                    ),
                  );
                }
              },
              child: Text(AppTranslations.get('giftPassBtn', currentLanguage)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _postController.dispose();
    _giftFriendController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(communityProvider);
    final tier = ref.watch(purchaseProvider);
    final isPaid = tier != SubscriptionTier.free;
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
                        if (isPaid) {
                          _showGiftDialog(context);
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()));
                        }
                      },
                    ),
                  ],
                ),
              ),
              const FadingDivider(height: 12),

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
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: SacredTheme.marginEdge, vertical: 8),
                        itemCount: posts.length,
                        itemBuilder: (context, index) =>
                            CommunityPostCard(post: posts[index]),
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
    final timeString = _formatTimeAgo(post.timestamp);

    // Resolve displayed names
    String displayName = post.authorName;
    if (post.authorName == 'You (Seeker)') {
      displayName = AppTranslations.get('youSeeker', currentLanguage);
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
                  
                  // Comment button (prompt/placeholder)
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppTranslations.get('commentSyncMsg', currentLanguage)),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.mode_comment_outlined, size: 18, color: SacredTheme.outline),
                          const SizedBox(width: 6),
                          Text(
                            AppTranslations.get('replyBtn', currentLanguage),
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
