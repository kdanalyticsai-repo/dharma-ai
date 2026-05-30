import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/models/chat_message.dart';
import 'package:dharma_ai/providers/chat_provider.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/purchase_service.dart';
import 'package:dharma_ai/screens/subscription_paywall_screen.dart';
import 'package:dharma_ai/widgets/lotus_painter.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';

class GuruChatScreen extends ConsumerStatefulWidget {
  const GuruChatScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GuruChatScreen> createState() => _GuruChatScreenState();
}

class _GuruChatScreenState extends ConsumerState<GuruChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
    final chatState   = ref.watch(guruChatProvider);
    final tier        = ref.watch(purchaseProvider);
    final lang        = ref.watch(languageProvider);
    final dailyCount  = ref.watch(dailyPromptCounterProvider);
    final isFree      = tier == SubscriptionTier.free;
    final limitReached = isFree && dailyCount >= kFreePromptLimit;
    final remaining   = (kFreePromptLimit - dailyCount).clamp(0, kFreePromptLimit);
    final textTheme = Theme.of(context).textTheme;

    ref.listen<ChatState>(guruChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length || next.isLoading) {
        _scrollToBottom();
      }
    });

    return MandalaBackground(
      scale: 1.0,
      alignment: Alignment.center,
      child: Column(
        children: [
          // Chat bubbles
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge, vertical: 16),
              itemCount: chatState.messages.length,
              itemBuilder: (context, index) {
                final message = chatState.messages[index];
                return GuruChatBubble(message: message);
              },
            ),
          ),

          // Loading indicator
          if (chatState.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const LotusLoadingIndicator(size: 32),
                  const SizedBox(width: 12),
                  Text(
                    AppTranslations.get('listeningDeeply', lang),
                    style: textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: SacredTheme.outline,
                    ),
                  ),
                ],
              ),
            ),

          // Free-tier daily prompt counter
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
                  Text(
                    AppTranslations.get('freePromptsLeft', lang).replaceAll('{n}', '$remaining'),
                    style: GoogleFonts.inter(fontSize: 11, color: SacredTheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen())),
                    child: Text(AppTranslations.get('upgradeBtn', lang), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: SacredTheme.primary)),
                  ),
                ],
              ),
            ),

          // Limit-reached banner
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

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: SacredTheme.surfaceContainerLow.withOpacity(0.9),
              border: Border(top: BorderSide(color: SacredTheme.outlineVariant.withOpacity(0.5), width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.psychology_outlined, color: SacredTheme.outline),
                    tooltip: AppTranslations.get('resetMindTooltip', lang),
                    onPressed: () => ref.read(guruChatProvider.notifier).clearHistory(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !limitReached,
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty && !limitReached) {
                          ref.read(guruChatProvider.notifier).sendMessage(val);
                          _textController.clear();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: limitReached ? AppTranslations.get('dailyLimitHint', lang) : AppTranslations.get('chatGuruPlaceholder', lang),
                        hintStyle: textTheme.bodyMedium?.copyWith(color: SacredTheme.outline),
                        filled: true,
                        fillColor: limitReached ? SacredTheme.surfaceContainerHighest : SacredTheme.surfaceContainerLowest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusXl), borderSide: const BorderSide(color: SacredTheme.outlineVariant, width: 0.5)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusXl), borderSide: const BorderSide(color: SacredTheme.primary, width: 1.0)),
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
                        ref.read(guruChatProvider.notifier).sendMessage(text);
                        _textController.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GuruChatBubble extends StatelessWidget {
  final ChatMessage message;

  const GuruChatBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isUser
                ? SacredTheme.secondary.withOpacity(0.9)
                : SacredTheme.surfaceContainerLowest.withOpacity(0.9),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(SacredTheme.radiusMd),
              topRight: const Radius.circular(SacredTheme.radiusMd),
              bottomLeft: isUser
                  ? const Radius.circular(SacredTheme.radiusMd)
                  : Radius.zero,
              bottomRight: isUser
                  ? Radius.zero
                  : const Radius.circular(SacredTheme.radiusMd),
            ),
            border: isUser
                ? null
                : Border.all(color: SacredTheme.outlineVariant.withOpacity(0.4), width: 0.5),
            boxShadow: isUser
                ? null
                : [
                    BoxShadow(
                      color: SacredTheme.secondary.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
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
                padding: const EdgeInsets.all(18),
                child: Text(
                  message.text,
                  style: textTheme.bodyLarge?.copyWith(
                    color: isUser ? Colors.white : SacredTheme.onSurface,
                    // Make Guru's text feel organic and soothing
                    fontSize: isUser ? 15 : 16,
                    height: 1.5,
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
