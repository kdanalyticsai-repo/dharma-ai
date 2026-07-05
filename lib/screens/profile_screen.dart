import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/scripture_provider.dart';
import 'package:dharma_ai/providers/sadhana_provider.dart';
import 'package:dharma_ai/screens/search_screen.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/screens/subscription_paywall_screen.dart';
import 'package:dharma_ai/screens/gift_subscription_screen.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/purchase_service.dart';
import 'package:dharma_ai/screens/redeem_code_screen.dart';
import 'package:dharma_ai/screens/welcome_screen.dart';
import 'package:dharma_ai/providers/auth_provider.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/transliteration_provider.dart';
import 'package:dharma_ai/services/supabase_sync.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/widgets/lotus_painter.dart';
import 'package:dharma_ai/widgets/legal_footer.dart';
import 'package:dharma_ai/widgets/circle_icon_button.dart';
import 'package:dharma_ai/screens/admin_feedback_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _noteController = TextEditingController();
  bool _isSavingNote = false;

  int _avatarTapCount = 0;
  DateTime? _lastAvatarTap;

  void _handleAvatarTap() {
    final now = DateTime.now();
    final isRapid = _lastAvatarTap != null &&
        now.difference(_lastAvatarTap!) <= const Duration(seconds: 2);
    _lastAvatarTap = now;
    _avatarTapCount = isRapid ? _avatarTapCount + 1 : 1;

    if (_avatarTapCount >= 5) {
      _avatarTapCount = 0;
      _lastAvatarTap = null;
      final email = ref.read(authUserProvider).valueOrNull?.email;
      if (email == 'kdanalyticsai@gmail.com') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFeedbackScreen()));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPersonalNote();
  }

  void _showLanguagePicker(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final current = ref.read(languageProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SacredTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(SacredTheme.radiusLg),
          topRight: Radius.circular(SacredTheme.radiusLg),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(AppTranslations.get('profileChooseLanguage', ref.read(languageProvider)),
                    style: textTheme.headlineSmall?.copyWith(color: SacredTheme.headingColor(context))),
              ),
              const SizedBox(height: 8),
              ...AppLanguage.values.map((lang) {
                final selected = lang == current;
                return ListTile(
                  leading: Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? SacredTheme.primary : SacredTheme.outline,
                  ),
                  title: Text(lang.displayName),
                  onTap: () {
                    ref.read(languageProvider.notifier).setLanguage(lang);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final tier = ref.read(purchaseProvider);
    final isPaid = tier != SubscriptionTier.free;
    final planName = tier == SubscriptionTier.annual ? 'Annual Sadhaka' : 'Sadhaka Premium';

    final bodyText = isPaid
        ? 'Your $planName subscription benefits will be lost immediately and cannot be recovered. All your sacred data — sadhana streaks, bookmarks, and personal notes — will also be permanently removed.\n\nAre you sure you want to delete your account?'
        : 'Your sadhana logs, bookmarks, and personal notes will be permanently removed.\n\nYour path of dharma is always here for you — feel free to return and re-register whenever you feel ready.\n\nAre you sure you want to delete your account?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SacredTheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusMd)),
        title: Row(
          children: [
            Icon(
              isPaid ? Icons.workspace_premium : Icons.favorite_border,
              color: isPaid ? SacredTheme.templeGold : SacredTheme.primary,
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text('We\'re Sorry to See You Go')),
          ],
        ),
        content: Text(bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep My Account'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final client = SupabaseSync.client;
    if (client == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: SacredTheme.primary),
      ),
    );

    try {
      await client.rpc('delete_user');
      if (mounted) Navigator.pop(context);
      await ref.read(authProvider.notifier).signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete account. Please try again or contact support@kdaanalytics.com'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showSanctuarySettings(BuildContext context, {required bool isPaid}) {
    final textTheme = Theme.of(context).textTheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // allow the sheet to grow + scroll on small screens
      backgroundColor: SacredTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(SacredTheme.radiusLg),
          topRight: Radius.circular(SacredTheme.radiusLg),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SacredTheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppTranslations.get('sanctuarySettings', ref.read(languageProvider)),
                style: textTheme.headlineSmall?.copyWith(
                  color: SacredTheme.headingColor(context),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.star, color: SacredTheme.templeGold),
                title: Text(AppTranslations.get('profileUpgradeAccount', ref.read(languageProvider))),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SubscriptionPaywallScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.card_giftcard, color: SacredTheme.primary),
                title: Text(AppTranslations.get('profileGiftPass', ref.read(languageProvider))),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GiftSubscriptionScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.redeem, color: SacredTheme.templeGold),
                title: Text(AppTranslations.get('profileRedeemCode', ref.read(languageProvider))),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RedeemCodeScreen()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.translate, color: SacredTheme.primary),
                title: Text(AppTranslations.get('profileLanguage', ref.read(languageProvider))),
                subtitle: Text(ref.read(languageProvider).displayName),
                trailing: const Icon(Icons.chevron_right, color: SacredTheme.outline),
                onTap: () {
                  Navigator.pop(context);
                  _showLanguagePicker(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: Text(AppTranslations.get('profileSignOut', ref.read(languageProvider)), style: const TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                title: const Text('Delete Account', style: TextStyle(color: Colors.redAccent)),
                subtitle: const Text('Permanently remove all your data', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteAccount();
                },
              ),
              const Divider(),
              const LegalFooter(),
              const SizedBox(height: 12),
            ],
          ),
        ),
        );
      },
    );
  }

  // Load the personal note straight from the account — the ONLY source of
  // truth. No local cache: a device-local cache previously leaked notes between
  // users on a shared browser, so the note is now strictly per-account
  // (Supabase row + RLS).
  Future<void> _loadPersonalNote() async {
    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    if (client == null || uid == null) {
      if (mounted) _noteController.text = '';
      return;
    }
    try {
      final row = await client
          .from('profiles')
          .select('personal_note')
          .eq('id', uid)
          .maybeSingle();
      final note = (row?['personal_note'] as String?) ?? '';
      if (mounted) _noteController.text = note;
    } catch (_) {
      // Offline / unreachable → leave empty; the note lives in the account
      // and loads when back online.
    }
  }

  Future<void> _savePersonalNote(String text) async {
    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    if (client == null || uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('profileSignInToSave', ref.read(languageProvider)))),
      );
      return;
    }
    setState(() => _isSavingNote = true);
    bool saved = false;
    try {
      await client.from('profiles').update({
        'personal_note': text,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      saved = true;
    } catch (_) {
      saved = false;
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _isSavingNote = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved
              ? AppTranslations.get('profileNoteSaved', ref.read(languageProvider))
              : AppTranslations.get('profileNoteSaveError', ref.read(languageProvider))),
          backgroundColor: saved ? SacredTheme.primary : null,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedVersesAsync = ref.watch(bookmarkedVersesProvider);
    final sadhana = ref.watch(sadhanaProvider);
    final tier = ref.watch(purchaseProvider);
    final isPaid = tier != SubscriptionTier.free;
    final textTheme = Theme.of(context).textTheme;
    final lang = ref.watch(languageProvider);
    final user = ref.watch(authUserProvider).valueOrNull;
    final fullName = (user?.userMetadata?['full_name'] as String?)?.trim();
    final hasName = fullName != null && fullName.isNotEmpty;
    final rawName = hasName ? fullName : 'Seeker of Truth';
    final nameParts = rawName.trim().split(RegExp(r'\s+'));
    final avatarText = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : rawName.length >= 2
            ? rawName.substring(0, 2).toUpperCase()
            : rawName[0].toUpperCase();
    // Render the name in the selected script (e.g. अर्जुन in Hindi); falls back
    // to the Latin name while the transliteration loads or for English.
    final displayName = (hasName && lang != AppLanguage.english)
        ? (ref.watch(transliteratedNameProvider((name: rawName, lang: lang))).valueOrNull ?? rawName)
        : rawName;
    final avatarUrl = (user?.userMetadata?['avatar_url'] ??
        user?.userMetadata?['picture']) as String?;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(AppTranslations.get('profileMySanctuary', lang), style: textTheme.headlineMedium),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleIconButton(
              icon: Icons.tune_rounded,
              tooltip: 'Settings',
              onPressed: () => _showSanctuarySettings(context, isPaid: isPaid),
            ),
          ),
        ],
      ),
      body: MandalaBackground(
        scale: 0.85,
        centerOverlay: savedVersesAsync.isLoading ? const LotusLoadingIndicator(size: 64) : null,
        child: SafeArea(
        child: Column(
          children: [
            // User Header Profile Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge),
              child: Card(
                color: SacredTheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _handleAvatarTap,
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: SacredTheme.primary,
                          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? null
                              : Text(
                                  avatarText,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(AppTranslations.get('profileLevelPractitioner', lang), style: textTheme.labelSmall),
                            const SizedBox(height: 6),
                            // Tier badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tier == SubscriptionTier.annual
                                    ? SacredTheme.deepGold.withOpacity(0.18)
                                    : tier == SubscriptionTier.sadhaka
                                        ? SacredTheme.primary.withOpacity(0.12)
                                        : SacredTheme.outlineVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                                border: Border.all(
                                  color: tier == SubscriptionTier.annual
                                      ? SacredTheme.deepGold.withOpacity(0.5)
                                      : tier == SubscriptionTier.sadhaka
                                          ? SacredTheme.primary.withOpacity(0.3)
                                          : SacredTheme.outlineVariant,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                tier == SubscriptionTier.annual
                                    ? '✦ Annual Sadhaka'
                                    : tier == SubscriptionTier.sadhaka
                                        ? '★ Sadhaka Premium'
                                        : 'Free Seeker',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: tier == SubscriptionTier.annual
                                      ? SacredTheme.deepGold
                                      : tier == SubscriptionTier.sadhaka
                                          ? SacredTheme.primary
                                          : SacredTheme.outline,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: SacredTheme.primary, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${sadhana.streak} ' + AppTranslations.get('profileDayStreak', lang),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: SacredTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // Tab bar switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge),
              child: TabBar(
                controller: _tabController,
                indicatorColor: SacredTheme.primary,
                labelColor: SacredTheme.primary,
                unselectedLabelColor: SacredTheme.onSurfaceVariant,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: AppTranslations.get('profileSavedWisdom', lang)),
                  Tab(text: AppTranslations.get('profilePersonalNoteTab', lang)),
                ],
              ),
            ),
            const FadingDivider(height: 12),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Bookmarks Tab
                  savedVersesAsync.when(
                    data: (savedVerses) {
                      if (savedVerses.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40.0),
                            child: Text(
                              AppTranslations.get('profileNoSavedVerses', lang),
                              style: textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge, vertical: 16),
                        itemCount: savedVerses.length,
                        itemBuilder: (context, index) {
                          final verse = savedVerses[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Card(
                              child: ListTile(
                                title: Text(
                                  '${verse.bookName} ${verse.chapter}.${verse.verseNumber}',
                                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  verse.translation,
                                  style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w400),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: SacredTheme.primary),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SingleVerseDetailScreen(verse: verse),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, stack) => Center(child: Text('Error loading saved items: $err')),
                  ),

                  // Journal Notes Tab
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.get('profileYourPersonalNote', lang),
                          style: textTheme.labelSmall?.copyWith(color: SacredTheme.primary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppTranslations.get('profileNoteDescription', lang),
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        
                        // Journal input
                        TextField(
                          controller: _noteController,
                          maxLines: 8,
                          maxLength: 5000,
                          decoration: InputDecoration(
                            hintText: AppTranslations.get('profileNoteHint', lang),
                            hintStyle: textTheme.bodyMedium?.copyWith(color: SacredTheme.outline),
                            filled: true,
                            fillColor: SacredTheme.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(SacredTheme.radiusDefault),
                              borderSide: const BorderSide(color: SacredTheme.outlineVariant, width: 0.5),
                            ),
                          ),
                          style: textTheme.bodyLarge?.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        
                        // Save Action Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSavingNote
                                ? null
                                : () => _savePersonalNote(_noteController.text),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isSavingNote) ...[
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Text(AppTranslations.get('profileSaveNote', lang)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
