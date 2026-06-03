import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/config/payment_config.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/providers/auth_provider.dart';
import 'package:dharma_ai/services/purchase_service.dart';
import 'package:dharma_ai/services/razorpay_service.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';

class SubscriptionPaywallScreen extends ConsumerStatefulWidget {
  const SubscriptionPaywallScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SubscriptionPaywallScreen> createState() => _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends ConsumerState<SubscriptionPaywallScreen> {
  bool _isProcessing = false;
  bool _isProcessingQuarterly = false;
  bool _isProcessingAnnual = false;

  // Unified purchase: web → Razorpay (real); other platforms → existing flow.
  Future<void> _buyPlan(String plan) async {
    setState(() => _setProcessing(plan, true));
    bool success = false;
    String? error;
    try {
      if (kIsWeb && PaymentConfig.isConfigured) {
        final user = ref.read(authUserProvider).valueOrNull;
        if (user == null) {
          error = 'Please sign in to subscribe.';
        } else {
          success = await RazorpayService().checkout(
            plan: plan,
            userId: user.id,
            email: user.email,
            name: user.userMetadata?['full_name'] as String?,
          );
          if (success) {
            await ref.read(purchaseServiceProvider).setLocalPlan(plan);
            await ref.read(purchaseProvider.notifier).refresh();
            ref.invalidate(activePlanProvider);
          }
        }
      } else {
        final n = ref.read(purchaseProvider.notifier);
        success = plan == 'monthly'
            ? await n.buySadhaka()
            : plan == 'quarterly'
                ? await n.buyQuarterly()
                : await n.buyAnnual();
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    setState(() => _setProcessing(plan, false));
    if (success) {
      _showWelcomeDialog(_planMessage(plan));
    } else if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: SacredTheme.error),
      );
    }
  }

  void _setProcessing(String plan, bool v) {
    if (plan == 'monthly') {
      _isProcessing = v;
    } else if (plan == 'quarterly') {
      _isProcessingQuarterly = v;
    } else {
      _isProcessingAnnual = v;
    }
  }

  String _planMessage(String plan) {
    switch (plan) {
      case 'annual':
        return 'Your annual Sadhaka path is now active. May this year bring you deep wisdom and inner peace.';
      case 'quarterly':
        return 'Your quarterly Sadhaka path is now active. May these months deepen your practice.';
      default:
        return 'Your access level has been upgraded to Sadhaka Premium. May your spiritual path be blessed with clarity.';
    }
  }

  // Shown on the Free card when the user is already premium — replaces the
  // (now removed) downgrade button. One-time plans simply lapse, so we
  // reassure the user it won't auto-renew.
  Widget _premiumStatus(BuildContext context, String? planLabel, DateTime? end) {
    final expired = isSubscriptionExpired(end);
    final text = subscriptionStatusLine(end, planLabel: planLabel) ??
        '${planLabel ?? 'Premium'} active · won\'t auto-renew';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: SacredTheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
        border: Border.all(color: SacredTheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(expired ? Icons.info_outline : Icons.verified_outlined,
              size: 14, color: SacredTheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: SacredTheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWelcomeDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SacredTheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusMd)),
        title: Text(
          'Welcome, Sadhaka',
          style: GoogleFonts.newsreader(fontSize: 24, fontWeight: FontWeight.bold, color: SacredTheme.primary),
        ),
        content: Text(message, style: Theme.of(context).textTheme.bodyLarge),
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

  @override
  Widget build(BuildContext context) {
    final activeTier = ref.watch(purchaseProvider);
    final activePlan = ref.watch(activePlanProvider).valueOrNull ?? 'free';
    final subEnd = ref.watch(subscriptionEndProvider).valueOrNull;
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

                // ── Sadhaka Annual (Recommended) ──────────────────
                _buildTierCard(
                  context,
                  title: 'Sadhaka Annual',
                  price: '₹1499 / Year',
                  badge: 'RECOMMENDED',
                  benefits: [
                    'Everything in Sadhaka Premium',
                    'Best value — save ₹889 vs monthly',
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
                        : _isProcessingAnnual ? null : () => _buyPlan('annual'),
                    child: _isProcessingAnnual
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(activeTier == SubscriptionTier.annual ? 'ACTIVE ANNUAL PATH' : 'EMBARK ON ANNUAL PATH'),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Sadhaka Quarterly ─────────────────────────────
                _buildTierCard(
                  context,
                  title: 'Sadhaka Quarterly',
                  price: '₹499 / 3 Months',
                  badge: 'QUARTERLY',
                  benefits: [
                    'Everything in Sadhaka Premium',
                    'Save ₹98 vs paying monthly',
                    '₹166 / month — an easy commitment',
                  ],
                  isActive: activePlan == 'quarterly',
                  isPremiumHighlight: true,
                  button: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SacredTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: activePlan == 'quarterly'
                        ? null
                        : _isProcessingQuarterly ? null : () => _buyPlan('quarterly'),
                    child: _isProcessingQuarterly
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(activePlan == 'quarterly' ? 'ACTIVE QUARTERLY PATH' : 'EMBARK ON QUARTERLY PATH'),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Sadhaka Premium (Monthly) ─────────────────────
                _buildTierCard(
                  context,
                  title: 'Sadhaka Premium',
                  price: '₹199 / Month',
                  badge: 'MONTHLY',
                  benefits: [
                    'Access all scriptures (Upanishads, Vedas)',
                    'Unlimited AI-powered Chat Scholar',
                    'Unlimited introspective AI Guru counseling',
                    'Background Audio Wisdom player (18 chapters)',
                    'Sangha community pass gifting actions',
                  ],
                  isActive: activePlan == 'monthly',
                  isPremiumHighlight: true,
                  button: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SacredTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: activePlan == 'monthly'
                        ? null
                        : _isProcessing ? null : () => _buyPlan('monthly'),
                    child: _isProcessing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(activePlan == 'monthly' ? 'ACTIVE PREMIUM PATH' : 'EMBARK ON PREMIUM PATH'),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Free Seeker ───────────────────────────────────
                _buildTierCard(
                  context,
                  title: 'Free Seeker',
                  price: '₹0 / Month',
                  benefits: [
                    'Standard Bhagavad Gita Reader',
                    '6 daily AI Scripture Scholar prompts',
                    'Daily sadhana & streak tracker',
                  ],
                  isActive: activeTier == SubscriptionTier.free,
                  button: activeTier != SubscriptionTier.free
                      // Currently subscribed → show "active until …".
                      ? _premiumStatus(
                          context,
                          activeTier == SubscriptionTier.annual
                              ? 'Sadhaka Annual'
                              : activePlan == 'quarterly'
                                  ? 'Sadhaka Quarterly'
                                  : 'Sadhaka Premium',
                          subEnd,
                        )
                      // Lapsed subscription → notify they've defaulted to Free.
                      : isSubscriptionExpired(subEnd)
                          ? _premiumStatus(context, null, subEnd)
                          : OutlinedButton(
                              onPressed: null,
                              child: const Text('ACTIVE PATH'),
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
