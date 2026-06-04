import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/auth_provider.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/screens/home_shell.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';

/// Shown after the user follows a password-recovery email link. At this point
/// Supabase has established a temporary recovery session, so we can call
/// updateUser() to set a brand-new password.
class SetNewPasswordScreen extends ConsumerStatefulWidget {
  const SetNewPasswordScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends ConsumerState<SetNewPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pass = _passwordController.text;
    final confirm = _confirmController.text;
    if (pass.length < 6) {
      setState(() => _error = AppTranslations.get('spMinChars', ref.read(languageProvider)));
      return;
    }
    if (pass != confirm) {
      setState(() => _error = AppTranslations.get('spMismatch', ref.read(languageProvider)));
      return;
    }
    setState(() { _isSaving = true; _error = null; });
    final err = await ref.read(authProvider.notifier).updatePassword(pass);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppTranslations.get('spUpdated', ref.read(languageProvider))),
        backgroundColor: SacredTheme.primary,
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lang = ref.watch(languageProvider);
    return Scaffold(
      body: MandalaBackground(
        scale: 1.0,
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  AppTranslations.get('spSetNewPassword', lang),
                  style: GoogleFonts.newsreader(
                    fontSize: 28, fontWeight: FontWeight.bold, color: SacredTheme.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  AppTranslations.get('spSubtitle', lang),
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: AppTranslations.get('spNewPassword', lang),
                    hintText: '••••••••',
                    filled: true,
                    fillColor: SacredTheme.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusDefault)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: SacredTheme.onSurfaceVariant, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: AppTranslations.get('spConfirmPassword', lang),
                    hintText: '••••••••',
                    filled: true,
                    fillColor: SacredTheme.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusDefault)),
                  ),
                  style: textTheme.bodyLarge,
                  onSubmitted: (_) => _isSaving ? null : _save(),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(_error!, style: textTheme.bodySmall?.copyWith(color: Colors.red.shade700)),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(AppTranslations.get('spUpdateButton', lang)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
