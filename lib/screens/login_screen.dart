import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/widgets/rotating_chakra.dart';
import 'package:dharma_ai/providers/auth_provider.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/screens/home_shell.dart';
import 'package:dharma_ai/screens/personalize_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool startInSignUpMode;
  const LoginScreen({Key? key, this.startInSignUpMode = false}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late bool _isSignUp;
  bool _isLoading = false;
  String? _errorMessage;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.startInSignUpMode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _chakraTagline(AppLanguage lang) {
    final h = DateTime.now().hour;
    final key = (h >= 5 && h < 12)
        ? 'chakraDawn'
        : (h >= 12 && h < 17)
            ? 'chakraNoon'
            : (h >= 17 && h < 21)
                ? 'chakraDusk'
                : 'chakraNight';
    return AppTranslations.get(key, lang);
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (_isSignUp && name.isEmpty)) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    final auth = ref.read(authProvider.notifier);

    if (_isSignUp) {
      final r = await auth.signUp(email, password, name,
          langCode: ref.read(languageProvider).code);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (r.error != null) {
        setState(() => _errorMessage = r.error);
        return;
      }
      if (r.needsConfirmation) {
        // Email must be confirmed before there's a session — DON'T enter the
        // app. Switch to sign-in and tell the user to check their inbox.
        setState(() {
          _isSignUp = false;
          _errorMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.get('authConfirmEmailSent', ref.read(languageProvider))),
            backgroundColor: SacredTheme.primary,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
      // Signed in immediately (confirmation off) — new users choose their path.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PersonalizeScreen()),
        (route) => false,
      );
    } else {
      final error = await auth.signIn(email, password);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (error != null) {
        setState(() => _errorMessage = error);
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    final error = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  Future<void> _forgotPassword() async {
    final resetController = TextEditingController(text: _emailController.text.trim());
    final textTheme = Theme.of(context).textTheme;
    final dlang = ref.read(languageProvider);
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          backgroundColor: SacredTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusMd)),
          title: Text(
            AppTranslations.get('fpTitle', dlang),
            style: GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.bold, color: SacredTheme.primary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get('fpBody', dlang),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resetController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'your@email.com',
                  filled: true,
                  fillColor: SacredTheme.surfaceContainerLowest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusSm)),
                ),
                style: textTheme.bodyLarge,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(dialogContext),
              child: Text(AppTranslations.get('fpCancel', dlang), style: const TextStyle(color: SacredTheme.outline)),
            ),
            ElevatedButton(
              onPressed: sending
                  ? null
                  : () async {
                      final email = resetController.text.trim();
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(dialogContext);
                      if (email.isEmpty || !email.contains('@')) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(AppTranslations.get('fpInvalidEmail', dlang))),
                        );
                        return;
                      }
                      setLocal(() => sending = true);
                      final error = await ref.read(authProvider.notifier).resetPassword(email);
                      if (!mounted) return;
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(error ?? AppTranslations.get('fpSent', dlang)),
                          backgroundColor: error == null ? SacredTheme.primary : null,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    },
              child: sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(AppTranslations.get('fpSend', dlang)),
            ),
          ],
        ),
      ),
    );
    resetController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lang = ref.watch(languageProvider);

    return Scaffold(
      body: MandalaBackground(
        scale: 1.0,
        alignment: Alignment.center,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: SacredTheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      RotatingChakra(
                        size: (MediaQuery.of(context).size.width * 0.25)
                            .clamp(80.0, 140.0),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _chakraTagline(lang),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.newsreader(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: SacredTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  _isSignUp
                      ? AppTranslations.get('authBeginPath', lang)
                      : AppTranslations.get('authWelcomeBack', lang),
                  style: textTheme.headlineLarge?.copyWith(color: SacredTheme.headingColor(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSignUp
                      ? AppTranslations.get('authSignupSubtitle', lang)
                      : AppTranslations.get('authLoginSubtitle', lang),
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                if (_isSignUp) ...[
                  _buildField(
                    controller: _nameController,
                    label: AppTranslations.get('authYourName', lang),
                    hint: 'e.g. Arjuna',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                ],

                _buildField(
                  controller: _emailController,
                  label: AppTranslations.get('authEmail', lang),
                  hint: 'your@email.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                _buildField(
                  controller: _passwordController,
                  label: AppTranslations.get('authPassword', lang),
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: SacredTheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),

                if (!_isSignUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _forgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        AppTranslations.get('authForgotPassword', lang),
                        style: textTheme.labelMedium?.copyWith(
                          color: SacredTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: textTheme.bodySmall?.copyWith(color: Colors.red.shade700),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isSignUp
                            ? AppTranslations.get('authCreateAccount', lang)
                            : AppTranslations.get('authSignIn', lang)),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(AppTranslations.get('authOr', lang), style: textTheme.bodySmall?.copyWith(color: SacredTheme.onSurfaceVariant)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 22),
                    label: Text(AppTranslations.get('authContinueGoogle', lang)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: SacredTheme.outlineVariant),
                      foregroundColor: SacredTheme.onSurface,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Center(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isSignUp = !_isSignUp;
                      _errorMessage = null;
                    }),
                    child: RichText(
                      text: TextSpan(
                        style: textTheme.bodyMedium,
                        children: [
                          TextSpan(text: _isSignUp
                              ? AppTranslations.get('authAlreadyPath', lang)
                              : AppTranslations.get('authNewSeeker', lang)),
                          TextSpan(
                            text: _isSignUp
                                ? AppTranslations.get('authSignInLink', lang)
                                : AppTranslations.get('authCreateAccountLink', lang),
                            style: GoogleFonts.inter(
                              color: SacredTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: SacredTheme.primary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: SacredTheme.onSurfaceVariant),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
