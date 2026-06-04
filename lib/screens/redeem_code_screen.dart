import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/auth_provider.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/razorpay_service.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';

class RedeemCodeScreen extends ConsumerStatefulWidget {
  const RedeemCodeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RedeemCodeScreen> createState() => _RedeemCodeScreenState();
}

class _RedeemCodeScreenState extends ConsumerState<RedeemCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isProcessing = false;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _redeem() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _snack(AppTranslations.get('redeemEnterCode', ref.read(languageProvider)));
      return;
    }
    final user = ref.read(authUserProvider).valueOrNull;
    if (user == null) {
      _snack(AppTranslations.get('redeemSignIn', ref.read(languageProvider)));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final res = await RazorpayService().redeem(code: code, userId: user.id);
      // Reflect the new subscription in the app.
      final plan = res['plan'] as String? ?? 'monthly';
      await ref.read(purchaseServiceProvider).setLocalPlan(plan);
      await ref.read(purchaseProvider.notifier).refresh();
      ref.invalidate(activePlanProvider);
      ref.invalidate(subscriptionEndProvider);

      if (!mounted) return;
      setState(() => _isProcessing = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: SacredTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusMd)),
          title: Text(
            '${AppTranslations.get('pwWelcomeSadhaka', ref.read(languageProvider))} 🙏',
            style: GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.bold, color: SacredTheme.primary),
          ),
          content: Text(
            AppTranslations.get('redeemSuccessBody', ref.read(languageProvider)),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(AppTranslations.get('pwEnterSacredSpace', ref.read(languageProvider))),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
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
        title: Text(AppTranslations.get('redeemTitle', lang), style: textTheme.headlineMedium?.copyWith(fontSize: 20)),
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
                  AppTranslations.get('redeemReceivedGift', lang),
                  style: textTheme.headlineMedium?.copyWith(color: SacredTheme.headingColor(context)),
                ),
                const SizedBox(height: 6),
                Text(
                  AppTranslations.get('redeemDescription', lang),
                  style: textTheme.bodyMedium,
                ),
                const FadingDivider(height: 28),

                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: AppTranslations.get('redeemCodeLabel', lang),
                    labelStyle: textTheme.labelSmall?.copyWith(color: SacredTheme.outline),
                    hintText: 'DHARMA-XXXX-XXXX',
                    filled: true,
                    fillColor: SacredTheme.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusDefault)),
                  ),
                  style: GoogleFonts.robotoMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: SacredTheme.onSurface,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _redeem,
                    child: _isProcessing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(AppTranslations.get('redeemButton', lang)),
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
