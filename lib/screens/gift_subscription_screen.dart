import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/community_provider.dart';
import 'package:dharma_ai/providers/auth_provider.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/config/payment_config.dart';
import 'package:dharma_ai/services/razorpay_service.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';

class GiftSubscriptionScreen extends ConsumerStatefulWidget {
  const GiftSubscriptionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GiftSubscriptionScreen> createState() => _GiftSubscriptionScreenState();
}

class _GiftSubscriptionScreenState extends ConsumerState<GiftSubscriptionScreen> {
  final TextEditingController _friendNameController = TextEditingController();
  bool _isProcessing = false;

  // Gift plans (keys must match the server PLANS table).
  static const Map<String, Map<String, String>> _plans = {
    'monthly': {'label': 'Sadhaka Premium — Monthly', 'price': '₹101'},
    'quarterly': {'label': 'Sadhaka Premium — Quarterly', 'price': '₹201'},
    'annual': {'label': 'Sadhaka Annual', 'price': '₹501'},
  };
  String _selectedPlan = 'monthly';

  String get _giftLabel => _plans[_selectedPlan]!['label']!;
  String get _giftPrice => _plans[_selectedPlan]!['price']!;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleGiftPurchase() async {
    if (!kIsWeb || !PaymentConfig.isConfigured) {
      _snack('Gifting is available on the web app (dharma.kdaanalytics.com).');
      return;
    }
    final user = ref.read(authUserProvider).valueOrNull;
    if (user == null) {
      _snack(AppTranslations.get('giftSignIn', ref.read(languageProvider)));
      return;
    }

    setState(() => _isProcessing = true);
    String? code;
    String? error;
    try {
      code = await RazorpayService().giftCheckout(
        plan: _selectedPlan,
        userId: user.id,
        email: user.email,
        name: user.userMetadata?['full_name'] as String?,
      );
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (code != null) {
      final friend = _friendNameController.text.trim();
      ref.read(communityProvider.notifier).logGift(friend.isEmpty ? 'a friend' : friend);
      _showGiftCodeDialog(code);
    } else if (error != null) {
      _snack(error);
    }
    // code == null && error == null  →  payment cancelled; do nothing.
  }

  void _showGiftCodeDialog(String code) {
    final friend = _friendNameController.text.trim();
    final shareText =
        'I\'ve gifted you a DharmaAI Sadhaka Premium pass! 🙏\n\n'
        'Redeem this code in the app (Profile → Redeem a Gift Code):\n\n$code\n\n'
        'https://dharma.kdaanalytics.com';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SacredTheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusMd)),
        title: Text(
          'Gift Pass Ready 🎁',
          style: GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.bold, color: SacredTheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              friend.isEmpty
                  ? 'Share this code with your friend. They redeem it in the app under Profile → Redeem a Gift Code.'
                  : 'Share this code with $friend. They redeem it under Profile → Redeem a Gift Code.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SacredTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                border: Border.all(color: SacredTheme.templeGold.withOpacity(0.5)),
              ),
              child: Center(
                child: SelectableText(
                  code,
                  style: GoogleFonts.robotoMono(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: SacredTheme.primary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(AppTranslations.get('giftCopy', ref.read(languageProvider))),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      _snack(AppTranslations.get('giftCopied', ref.read(languageProvider)));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('WhatsApp'),
                    onPressed: () => launchUrl(
                      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(shareText)}'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(AppTranslations.get('giftDone', ref.read(languageProvider))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _friendNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lang = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SacredTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(AppTranslations.get('giftScreenTitle', lang), style: textTheme.headlineMedium?.copyWith(fontSize: 20)),
      ),
      body: MandalaBackground(
        scale: 0.9,
        alignment: Alignment.center,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  AppTranslations.get('giftShareTitle', lang),
                  style: textTheme.headlineMedium?.copyWith(color: SacredTheme.headingColor(context)),
                ),
                const SizedBox(height: 6),
                Text(
                  "Gift a fellow seeker a Sadhaka Premium pass. After payment you'll receive a code to share — they redeem it in the app to unlock Premium.",
                  style: textTheme.bodyMedium,
                ),
                const FadingDivider(height: 28),

                // Recipient name (optional — used in the Sangha announcement)
                TextField(
                  controller: _friendNameController,
                  decoration: InputDecoration(
                    labelText: "RECIPIENT NAME (OPTIONAL)",
                    labelStyle: textTheme.labelSmall?.copyWith(color: SacredTheme.outline),
                    hintText: AppTranslations.get('giftRecipientHint', lang),
                    filled: true,
                    fillColor: SacredTheme.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusDefault)),
                  ),
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),

                // Plan selector
                DropdownButtonFormField<String>(
                  value: _selectedPlan,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: AppTranslations.get('giftPlanLabel', lang),
                    labelStyle: textTheme.labelSmall?.copyWith(color: SacredTheme.outline),
                    filled: true,
                    fillColor: SacredTheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SacredTheme.radiusDefault)),
                  ),
                  style: textTheme.bodyLarge,
                  items: _plans.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text('${e.value['label']}  •  ${e.value['price']}'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedPlan = v);
                  },
                ),
                const SizedBox(height: 24),

                // Price summary
                Card(
                  color: SacredTheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_giftLabel, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        Text(_giftPrice, style: textTheme.bodyLarge?.copyWith(color: SacredTheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handleGiftPurchase,
                    child: _isProcessing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(AppTranslations.get('giftPayButton', lang)),
                  ),
                ),
                const SizedBox(height: SacredTheme.safeAreaBottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
