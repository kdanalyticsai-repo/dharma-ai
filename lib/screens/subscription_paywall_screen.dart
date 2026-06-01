import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/purchase_service.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';

class SubscriptionPaywallScreen extends ConsumerStatefulWidget {
  const SubscriptionPaywallScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SubscriptionPaywallScreen> createState() => _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends ConsumerState<SubscriptionPaywallScreen> {
  bool _isProcessing = false;
  bool _isProcessingAnnual = false;

  Future<void> _handlePurchase() async {
    setState(() => _isProcessing = true);
    final success = await ref.read(purchaseProvider.notifier).buySadhaka();
    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: SacredTheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusMd)),
            title: Text(
              'Welcome, Sadhaka',
              style: GoogleFonts.newsreader(fontSize: 24, fontWeight: FontWeight.bold, color: SacredTheme.primary),
            ),
            content: Text(
              'Your access level has been upgraded to Sadhaka Premium. May your spiritual path be blessed with clarity.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close paywall screen
                },
                child: const Text('ENTER SACRED SPACE'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleAnnualPurchase() async {
    setState(() => _isProcessingAnnual = true);
    final success = await ref.read(purchaseProvider.notifier).buyAnnual();
    if (mounted) {
      setState(() => _isProcessingAnnual = false);
      if (success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: SacredTheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusMd)),
            title: Text(
              'Welcome, Sadhaka',
              style: GoogleFonts.newsreader(fontSize: 24, fontWeight: FontWeight.bold, color: SacredTheme.primary),
            ),
            content: Text(
              'Your annual Sadhaka Premium path is now active. May this year bring you deep wisdom and inner peace.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('ENTER SACRED SPACE'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTier = ref.watch(purchaseProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: SacredTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: MandalaBackground(
        scale: 0.9,
        alignment: Alignment.center,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge),
            child: Column(
              children: [
                const SizedBox(height: 12),
                
                // Head Title
                Text(
                  'Choose Your Path',
                  style: textTheme.headlineLarge?.copyWith(
                    color: SacredTheme.headingColor(context),
                    fontSize: 32,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose a membership level to align with your personal sadhana requirements.',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const FadingDivider(height: 32),

                // Tier 1: Free Card
                _buildTierCard(
                  context,
                  title: 'Free Seeker',
                  price: '₹0 / Month',
                  benefits: [
                    'Standard Bhagavad Gita Reader',
                    '11 daily AI Scripture Scholar prompts',
                    'Offline access to all Gita verses',
                  ],
                  isActive: activeTier == SubscriptionTier.free,
                  button: OutlinedButton(
                    onPressed: activeTier == SubscriptionTier.free ? null : () => ref.read(purchaseProvider.notifier).downgrade(),
                    child: Text(activeTier == SubscriptionTier.free ? 'ACTIVE PATH' : 'SELECT FREE'),
                  ),
                ),

                const SizedBox(height: 16),

                // Tier 2: Monthly Premium (Sadhaka) Card
                _buildTierCard(
                  context,
                  title: 'Sadhaka Premium',
                  price: '₹201 / Month',
                  badge: 'MONTHLY',
                  benefits: [
                    'Access all scriptures (Upanishads, Vedas)',
                    'Unlimited AI-powered Chat Scholar',
                    'Unlimited introspective AI Guru counseling',
                    'Background Audio Wisdom streaming player',
                    'Full offline downloads library',
                    'Offline access to all Gita verses',
                    'Sangha community pass gifting actions',
                  ],
                  isActive: activeTier == SubscriptionTier.sadhaka,
                  isPremiumHighlight: true,
                  button: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SacredTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: activeTier == SubscriptionTier.sadhaka
                        ? null
                        : _isProcessing ? null : _handlePurchase,
                    child: _isProcessing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(activeTier == SubscriptionTier.sadhaka ? 'ACTIVE PREMIUM PATH' : 'EMBARK ON PREMIUM PATH'),
                  ),
                ),

                const SizedBox(height: 16),

                // Tier 3: Annual Premium Card
                _buildTierCard(
                  context,
                  title: 'Sadhaka Annual',
                  price: '₹1100 / Year',
                  badge: 'BEST VALUE',
                  benefits: [
                    'Everything in Sadhaka Premium',
                    'Best value — save ₹1,312 vs monthly',
                    'Exclusive annual seeker badge',
                    '3× longer AI Guru session memory',
                  ],
                  isActive: activeTier == SubscriptionTier.annual,
                  isPremiumHighlight: true,
                  isAnnual: true,
                  button: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SacredTheme.templeGold,
                      foregroundColor: SacredTheme.deepMeditativeIndigo,
                    ),
                    onPressed: activeTier == SubscriptionTier.annual
                        ? null
                        : _isProcessingAnnual ? null : _handleAnnualPurchase,
                    child: _isProcessingAnnual
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(activeTier == SubscriptionTier.annual ? 'ACTIVE ANNUAL PATH' : 'EMBARK ON ANNUAL PATH'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard(
    BuildContext context, {
    required String title,
    required String price,
    required List<String> benefits,
    required bool isActive,
    bool isPremiumHighlight = false,
    bool isAnnual = false,
    String? badge,
    String? savingsLabel,
    required Widget button,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final borderColor = isAnnual ? SacredTheme.templeGold : isPremiumHighlight ? SacredTheme.templeGold : SacredTheme.outlineVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isPremiumHighlight ? SacredTheme.deepMeditativeIndigo : SacredTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(SacredTheme.radiusLg),
        border: Border.all(color: borderColor, width: isPremiumHighlight ? 1.5 : 0.5),
        boxShadow: isPremiumHighlight
            ? [BoxShadow(color: SacredTheme.primary.withOpacity(0.08), blurRadius: 20, spreadRadius: 2)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: textTheme.headlineMedium?.copyWith(
                  color: isPremiumHighlight ? SacredTheme.templeGold : SacredTheme.primary,
                  fontSize: 22,
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SacredTheme.templeGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: SacredTheme.templeGold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                price,
                style: textTheme.labelLarge?.copyWith(
                  color: isPremiumHighlight ? Colors.white.withOpacity(0.8) : SacredTheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
              if (savingsLabel != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                  ),
                  child: Text(
                    savingsLabel,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.greenAccent),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          
          // Benefits list
          ...benefits.map((benefit) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check,
                    color: isPremiumHighlight ? SacredTheme.templeGold : SacredTheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      benefit,
                      style: textTheme.bodyMedium?.copyWith(
                        color: isPremiumHighlight ? Colors.white.withOpacity(0.9) : SacredTheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: button),
        ],
      ),
    );
  }
}
