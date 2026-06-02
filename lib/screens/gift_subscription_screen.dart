import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/community_provider.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/purchase_service.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';

class GiftSubscriptionScreen extends ConsumerStatefulWidget {
  const GiftSubscriptionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GiftSubscriptionScreen> createState() => _GiftSubscriptionScreenState();
}

class _GiftSubscriptionScreenState extends ConsumerState<GiftSubscriptionScreen> {
  final TextEditingController _friendNameController = TextEditingController();
  final TextEditingController _friendEmailController = TextEditingController();
  final TextEditingController _giftMessageController = TextEditingController();
  bool _isProcessing = false;

  Future<void> _handleGiftPurchase() async {
    final name = _friendNameController.text;
    final email = _friendEmailController.text;

    if (name.trim().isEmpty || email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide your friend\'s name and email.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    
    // Call service to generate code
    final code = await ref.read(purchaseServiceProvider).purchaseGiftCode(name);
    
    // Log the gift in the Sangha community feed
    ref.read(communityProvider.notifier).logGift(name);

    if (mounted) {
      setState(() => _isProcessing = false);
      
      // Clear inputs
      _friendNameController.clear();
      _friendEmailController.clear();
      _giftMessageController.clear();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: SacredTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusMd)),
          title: Text(
            'Gift Pass Generated',
            style: GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.bold, color: SacredTheme.primary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have successfully purchased a Sadhaka Premium Monthly Pass for $name. An email containing their activation code has been sent.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SacredTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                  border: Border.all(color: SacredTheme.templeGold.withOpacity(0.5)),
                ),
                child: Center(
                  child: SelectableText(
                    code,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: SacredTheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close gift screen
              },
              child: const Text('BACK TO SANGHA'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _friendNameController.dispose();
    _friendEmailController.dispose();
    _giftMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tier = ref.watch(purchaseProvider);
    final isAnnual = tier == SubscriptionTier.annual;
    final giftLabel = isAnnual ? 'Sadhaka Annual Pass' : 'Sadhaka Premium Monthly Pass';
    final giftPrice = isAnnual ? '₹1,499' : '₹199';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SacredTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Gift a Subscription', style: textTheme.headlineMedium?.copyWith(fontSize: 20)),
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
                  'Share the Path of Wisdom',
                  style: textTheme.headlineMedium?.copyWith(
                    color: SacredTheme.headingColor(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Help a fellow seeker study the scriptures and consult the AI spiritual guide by gifting them a $giftLabel ($giftPrice).',
                  style: textTheme.bodyMedium,
                ),
                const FadingDivider(height: 28),

                // Friend's Name
                TextField(
                  controller: _friendNameController,
                  decoration: InputDecoration(
                    labelText: 'RECIPIENT NAME',
                    labelStyle: textTheme.labelSmall?.copyWith(color: SacredTheme.outline),
                    hintText: 'e.g. Ramesh Devi',
                    filled: true,
                    fillColor: SacredTheme.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusDefault)),
                  ),
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),

                // Friend's Email
                TextField(
                  controller: _friendEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'RECIPIENT EMAIL',
                    labelStyle: textTheme.labelSmall?.copyWith(color: SacredTheme.outline),
                    hintText: 'email@seeker.com',
                    filled: true,
                    fillColor: SacredTheme.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusDefault)),
                  ),
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),

                // Optional Message
                TextField(
                  controller: _giftMessageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'GIFT MESSAGE (OPTIONAL)',
                    labelStyle: textTheme.labelSmall?.copyWith(color: SacredTheme.outline),
                    hintText: 'e.g. May this guide you on your journey.',
                    filled: true,
                    fillColor: SacredTheme.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusDefault)),
                  ),
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),

                // Gifting price summary
                Card(
                  color: SacredTheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(giftLabel, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        Text(giftPrice, style: textTheme.bodyLarge?.copyWith(color: SacredTheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Gift Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handleGiftPurchase,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('PURCHASE GIFT PASS'),
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
