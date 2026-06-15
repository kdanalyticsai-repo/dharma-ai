import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/models/chat_message.dart';
import 'package:dharma_ai/models/verse.dart';
import 'package:dharma_ai/providers/chat_provider.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/scripture_provider.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/purchase_service.dart';
import 'package:dharma_ai/screens/search_screen.dart';
import 'package:dharma_ai/screens/subscription_paywall_screen.dart';
import 'package:dharma_ai/widgets/lotus_painter.dart';

class ScriptureChatScreen extends ConsumerStatefulWidget {
  const ScriptureChatScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ScriptureChatScreen> createState() => _ScriptureChatScreenState();
}

class _ScriptureChatScreenState extends ConsumerState<ScriptureChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final has = _textController.text.isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState   = ref.watch(scriptureChatProvider);
    final tier        = ref.watch(purchaseProvider);
    final lang        = ref.watch(languageProvider);
    final dailyCount  = ref.watch(dailyPromptCounterProvider);
    final isFree      = tier == SubscriptionTier.free;
    final limitReached = isFree && dailyCount >= kFreePromptLimit;
    final remaining   = (kFreePromptLimit - dailyCount).clamp(0, kFreePromptLimit);
    final textTheme = Theme.of(context).textTheme;

    // Trigger scroll to bottom on new messages
    ref.listen<ChatState>(scriptureChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length || next.isLoading) {
        _scrollToBottom();
      }
    });

    return Column(
      children: [
        // Chat Messages List
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge, vertical: 16),
            itemCount: chatState.messages.length,
            itemBuilder: (context, index) {
              final message = chatState.messages[index];
              return ScriptureChatBubble(message: message);
            },
          ),
        ),

        // Active Loading State
        if (chatState.isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LotusLoadingIndicator(size: 32),
                const SizedBox(width: 12),
                Text(
                  AppTranslations.get('consultingScriptures', lang),
                  style: const TextStyle(fontStyle: FontStyle.italic, color: SacredTheme.outline),
                ),
              ],
            ),
          ),

        // Free-tier daily limit banner
        if (isFree && !limitReached)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: SacredTheme.templeGold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(SacredTheme.radiusDefault),
              border: Border.all(color: SacredTheme.templeGold.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: SacredTheme.templeGold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppTranslations.get('freePromptsLeft', lang).replaceAll('{n}', '$remaining'),
                    style: GoogleFonts.inter(fontSize: 11, color: SacredTheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen())),
                  child: Text(AppTranslations.get('upgradeBtn', lang), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: SacredTheme.primary)),
                ),
              ],
            ),
          ),

        // Limit-reached paywall banner
        if (limitReached)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SacredTheme.deepMeditativeIndigo,
              borderRadius: BorderRadius.circular(SacredTheme.radiusMd),
              border: Border.all(color: SacredTheme.templeGold.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18, color: SacredTheme.templeGold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppTranslations.get('dailyLimitBanner', lang).replaceAll('{n}', '$kFreePromptLimit'),
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SacredTheme.templeGold,
                    foregroundColor: SacredTheme.deepMeditativeIndigo,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen())),
                  child: Text(AppTranslations.get('upgradeBtn', lang)),
                ),
              ],
            ),
          ),

        // Text Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: SacredTheme.surfaceContainerLow,
            border: Border(
              top: BorderSide(
                color: SacredTheme.outlineVariant.withOpacity(0.5),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                if (_hasText)
                  IconButton(
                    icon: const Icon(Icons.close, color: SacredTheme.primary),
                    tooltip: 'Clear text',
                    onPressed: _textController.clear,
                  ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: !limitReached,
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty && !limitReached) {
                        ref.read(scriptureChatProvider.notifier).sendMessage(val);
                        _textController.clear();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: limitReached ? AppTranslations.get('dailyLimitHint', lang) : AppTranslations.get('chatScripturePlaceholder', lang),
                      hintStyle: textTheme.bodyMedium?.copyWith(color: SacredTheme.outline),
                      filled: true,
                      fillColor: limitReached ? SacredTheme.surfaceContainerHighest : SacredTheme.surfaceContainerLowest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SacredTheme.radiusXl),
                        borderSide: const BorderSide(color: SacredTheme.outlineVariant, width: 0.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SacredTheme.radiusXl),
                        borderSide: BorderSide(color: SacredTheme.headingColor(context), width: 1.0),
                      ),
                    ),
                    style: textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.spa_outlined, color: limitReached ? SacredTheme.outline : SacredTheme.primary),
                  onPressed: limitReached ? null : () {
                    final text = _textController.text;
                    if (text.trim().isNotEmpty) {
                      ref.read(scriptureChatProvider.notifier).sendMessage(text);
                      _textController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ScriptureChatBubble extends ConsumerWidget {
  final ChatMessage message;

  const ScriptureChatBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85, // 85% width limit
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Chat Bubble body
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isUser
                    ? SacredTheme.deepMeditativeIndigo
                    : SacredTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(SacredTheme.radiusDefault),
                  topRight: const Radius.circular(SacredTheme.radiusDefault),
                  bottomLeft: isUser
                      ? const Radius.circular(SacredTheme.radiusDefault)
                      : Radius.zero,
                  bottomRight: isUser
                      ? Radius.zero
                      : const Radius.circular(SacredTheme.radiusDefault),
                ),
                border: isUser
                    ? null
                    : Border.all(color: SacredTheme.outlineVariant.withOpacity(0.5), width: 0.5),
              ),
              child: Stack(
                children: [
                  if (!isUser)
                    Positioned(
                      bottom: -20,
                      right: -20,
                      child: IgnorePointer(
                        child: CustomPaint(
                          size: const Size(60, 60),
                          painter: LotusPainter(
                            color: SacredTheme.templeGold.withOpacity(0.08),
                            animationValue: 0.0,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      message.text,
                      style: textTheme.bodyLarge?.copyWith(
                        fontFamily: 'Be Vietnam Pro',
                        color: isUser ? Colors.white : SacredTheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Citation items (if assistant generated)
            if (!isUser && message.verseCitations != null && message.verseCitations!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: message.verseCitations!.map((id) {
                  return FutureBuilder<Verse?>(
                    future: ref.read(scriptureServiceProvider).getVerseById(id),
                    builder: (context, snapshot) {
                      final verse = snapshot.data;
                      final label = verse != null
                          ? 'Gita ${verse.chapter}.${verse.verseNumber}'
                          : 'Reference';
                      return InkWell(
                        onTap: verse != null
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SingleVerseDetailScreen(verse: verse),
                                  ),
                                );
                              }
                            : null,
                        child: Chip(
                          labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: SacredTheme.surfaceContainer,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bookmark_outline, size: 12, color: SacredTheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: SacredTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                            side: BorderSide.none,
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
