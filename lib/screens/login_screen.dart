import 'package:flutter/foundation.dart' show kIsWeb;
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

    // Web: main.dart navigated here after a blocked Google OAuth attempt
    // (not-registered or already-registered). The session is still live, so we
    // sign out under isNewUserOnboarding guard, then display the error message.
    if (pendingGoogleAuthError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        isNewUserOnboarding = true; // block auth listener during signOut
        await ref.read(authProvider.notifier).signOut();
        if (!mounted) { isNewUserOnboarding = false; return; }
        isNewUserOnboarding = false;
        final key = pendingGoogleAuthError!;
        pendingGoogleAuthError = null;
        setState(() => _errorMessage = AppTranslations.get(key, ref.read(languageProvider)));
      });
    }
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
      setState(() => _errorMessage = AppTranslations.get('authErrorFillFields', ref.read(languageProvider)));
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
        final lang = ref.read(languageProvider);
        final msg = r.error!.startsWith('t:')
            ? AppTranslations.get(r.error!.substring(2), lang)
            : r.error!;
        // If already registered, switch to sign-in so they can log in directly.
        final alreadyExists = r.error == 't:authEmailAlreadyRegistered';
        setState(() {
          _errorMessage = msg;
          if (alreadyExists) _isSignUp = false;
        });
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
      isNewUserOnboarding = true;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PersonalizeScreen()),
        (route) => false,
      );
    } else {
      final error = await auth.signIn(email, password);
      if (!mounted) return;
      if (error != null) {
        // Only update state on failure — on success the auth listener navigates
        // us away and calling setState on a departing widget triggers
        // "dirty widget in wrong build scope" + _dependents.isEmpty assertions.
        // Sentinel codes (prefix 't:') are looked up in AppTranslations.
        final lang = ref.read(languageProvider);
        final msg = error.startsWith('t:')
            ? AppTranslations.get(error.substring(2), lang)
            : error;
        setState(() { _isLoading = false; _errorMessage = msg; });
        return;
      }
      // Success: DharmaApp.ref.listen handles routing to HomeShell.
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    if (kIsWeb) {
      // On web, signInWithOAuth() redirects the browser immediately — widget
      // state (_isSignUp) is lost after the page reloads. We encode the intent
      // in the redirectTo URL (?googleIntent=signup|signin) so main.dart can
      // apply the full 4-case routing logic after the OAuth redirect completes.
      await ref.read(authProvider.notifier).signInWithGoogle(webIsSignUp: _isSignUp);
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Android: native account picker — block the global auth listener and apply
    // the full 4-case (isNewUser × _isSignUp) routing logic inline.
    isNewUserOnboarding = true;
    final result = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!mounted) {
      isNewUserOnboarding = false;
      return;
    }
    if (result.error != null) {
      isNewUserOnboarding = false;
      // 'cancelled' = user dismissed the Google picker — no error to show.
      if (result.error != 'cancelled') {
        setState(() { _isLoading = false; _errorMessage = result.error; });
      } else {
        setState(() => _isLoading = false);
      }
      return;
    }
    if (!mounted) {
      isNewUserOnboarding = false;
      return;
    }
    // Route based on (isNewUser × _isSignUp) — four cases:
    if (result.isNewUser && _isSignUp) {
      // New account from sign-up form → create profile then go to onboarding.
      await ref.read(authProvider.notifier).createGoogleProfile();
      if (!mounted) { isNewUserOnboarding = false; return; }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PersonalizeScreen()),
        (route) => false,
      );
    } else if (result.isNewUser && !_isSignUp) {
      // Unregistered Google account on sign-in form → block and warn.
      await ref.read(authProvider.notifier).signOut();
      if (!mounted) { isNewUserOnboarding = false; return; }
      isNewUserOnboarding = false;
      setState(() {
        _isLoading = false;
        _errorMessage = AppTranslations.get('authGoogleNotRegistered', ref.read(languageProvider));
      });
    } else if (!result.isNewUser && _isSignUp) {
      // Existing Google user on sign-up form → block and warn.
      await ref.read(authProvider.notifier).signOut();
      if (!mounted) { isNewUserOnboarding = false; return; }
      isNewUserOnboarding = false;
      setState(() {
        _isLoading = false;
        _errorMessage = AppTranslations.get('authGoogleAlreadyRegistered', ref.read(languageProvider));
      });
    } else {
      // Existing user on sign-in form → HomeShell.
      isNewUserOnboarding = false;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    }
  }

  Future<void> _forgotPassword() async {
    // Push a dedicated route instead of showDialog. Flutter 3.22's showDialog
    // wraps content in _ModalScope which adds a FocusScope InheritedWidget; on
    // the user-branch build, that scope's debugDeactivated() fires before all
    // dependents finish cleanup → _dependents.isEmpty assertion crash. A pushed
    // route has none of these dialog-specific lifecycle issues.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ForgotPasswordScreen(initialEmail: _emailController.text.trim()),
      ),
    );
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
                    label: Text(AppTranslations.get(
                      _isSignUp ? 'authBeginWithGoogle' : 'authContinueGoogle',
                      lang,
                    )),
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

// Separate screen for password reset — avoids showDialog's _ModalScope
// FocusScope lifecycle crash on Flutter 3.22 (user-branch).
class _ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String initialEmail;
  const _ForgotPasswordScreen({required this.initialEmail});

  @override
  ConsumerState<_ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<_ForgotPasswordScreen> {
  late final TextEditingController _controller;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final lang = ref.read(languageProvider);
    final email = _controller.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = AppTranslations.get('fpInvalidEmail', lang));
      return;
    }
    setState(() { _sending = true; _error = null; });
    final error = await ref.read(authProvider.notifier).resetPassword(email);
    if (!mounted) return;
    if (error != null) {
      setState(() { _sending = false; _error = error; });
    } else {
      setState(() { _sending = false; _sent = true; });
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.read(languageProvider);
    final textTheme = Theme.of(context).textTheme;

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
                const SizedBox(height: 32),
                Text(
                  AppTranslations.get('fpTitle', lang),
                  style: GoogleFonts.newsreader(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: SacredTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppTranslations.get('fpBody', lang),
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                Text(
                  AppTranslations.get('authEmail', lang),
                  style: textTheme.labelSmall?.copyWith(color: SacredTheme.primary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  enabled: !_sending && !_sent,
                  decoration: const InputDecoration(
                    hintText: 'your@email.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 18, color: SacredTheme.onSurfaceVariant),
                  ),
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
                if (_sent) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SacredTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                      border: Border.all(color: SacredTheme.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      AppTranslations.get('fpSent', lang),
                      style: textTheme.bodySmall?.copyWith(color: SacredTheme.primary),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_sending || _sent) ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(AppTranslations.get('fpSend', lang)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppTranslations.get('fpCancel', lang),
                      style: textTheme.labelLarge?.copyWith(color: SacredTheme.outline),
                    ),
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
