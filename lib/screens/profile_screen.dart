import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:dharma_ai/services/supabase_sync.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/widgets/legal_footer.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _noteController = TextEditingController();
  bool _isSavingNote = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPersonalNote();
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
                'Sanctuary Settings',
                style: textTheme.headlineSmall?.copyWith(
                  color: SacredTheme.headingColor(context),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.star, color: SacredTheme.templeGold),
                title: const Text('Upgrade Account (Paywall)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SubscriptionPaywallScreen()),
                  );
                },
              ),
              if (isPaid)
                ListTile(
                  leading: const Icon(Icons.card_giftcard, color: SacredTheme.primary),
                  title: const Text('Gift a Wisdom Pass'),
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
                title: const Text('Redeem a Gift Code'),
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
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
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

  static const String _kNoteKey = 'spiritual_journal_note';

  // Load the personal note. Shows the local cache instantly, then pulls the
  // authoritative copy from the user's account so it follows them across any
  // device/browser. If the account has nothing yet but this device does,
  // migrate the local note up to the cloud.
  Future<void> _loadPersonalNote() async {
    final prefs = await SharedPreferences.getInstance();
    final localNote = prefs.getString(_kNoteKey) ?? '';
    if (mounted && _noteController.text.isEmpty) {
      _noteController.text = localNote;
    }

    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    if (client == null || uid == null) return; // offline / signed-out → local only

    try {
      final row = await client
          .from('profiles')
          .select('personal_note')
          .eq('id', uid)
          .maybeSingle();
      final cloudNote = (row?['personal_note'] as String?) ?? '';

      if (cloudNote.isNotEmpty) {
        // Account is the source of truth.
        if (mounted) _noteController.text = cloudNote;
        await prefs.setString(_kNoteKey, cloudNote);
      } else if (localNote.isNotEmpty) {
        // First sync: back up the existing local note to the account.
        await client.from('profiles').update({'personal_note': localNote}).eq('id', uid);
      }
    } catch (_) {
      // Network/Supabase issue → keep the local copy already shown.
    }
  }

  Future<void> _savePersonalNote(String text) async {
    setState(() => _isSavingNote = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNoteKey, text); // offline cache

    bool cloudSaved = false;
    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    if (client != null && uid != null) {
      try {
        await client.from('profiles').update({
          'personal_note': text,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', uid);
        cloudSaved = true;
      } catch (_) {
        cloudSaved = false; // keep local copy; user can retry when online
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _isSavingNote = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cloudSaved
              ? 'Note saved to your account — available on all your devices.'
              : 'Saved on this device. Sign in or reconnect to sync everywhere.'),
          backgroundColor: SacredTheme.primary,
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
    final user = ref.watch(authUserProvider).valueOrNull;
    final fullName = (user?.userMetadata?['full_name'] as String?)?.trim();
    final displayName = (fullName != null && fullName.isNotEmpty) ? fullName : 'Seeker of Truth';
    final avatarLetter = displayName[0].toUpperCase();
    final avatarUrl = (user?.userMetadata?['avatar_url'] ??
        user?.userMetadata?['picture']) as String?;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Sanctuary', style: textTheme.headlineMedium),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: SacredTheme.onSurfaceVariant),
            onPressed: () => _showSanctuarySettings(context, isPaid: isPaid),
          ),
        ],
      ),
      body: MandalaBackground(
        scale: 0.85,
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
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: SacredTheme.primary,
                        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? null
                            : Text(
                                avatarLetter,
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Level: Practitioner', style: textTheme.labelSmall),
                            const SizedBox(height: 6),
                            // Tier badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tier == SubscriptionTier.annual
                                    ? SacredTheme.templeGold.withOpacity(0.2)
                                    : tier == SubscriptionTier.sadhaka
                                        ? SacredTheme.primary.withOpacity(0.12)
                                        : SacredTheme.outlineVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                                border: Border.all(
                                  color: tier == SubscriptionTier.annual
                                      ? SacredTheme.templeGold.withOpacity(0.5)
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
                                      ? SacredTheme.templeGold
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
                                  '${sadhana.streak} Day Streak',
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
                tabs: const [
                  Tab(text: 'SAVED WISDOM'),
                  Tab(text: 'PERSONAL NOTE'),
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
                              'No saved verses yet. Tap the bookmark icon on scripture cards to preserve them in your sanctuary.',
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
                    loading: () => const Center(child: CircularProgressIndicator()),
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
                          'YOUR PERSONAL NOTE',
                          style: textTheme.labelSmall?.copyWith(color: SacredTheme.primary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Write down your reflections, realizations and personal goals. Saved to your account, so it stays with you on every device.',
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        
                        // Journal input
                        TextField(
                          controller: _noteController,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: 'Enter your thoughts here...',
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
                                const Text('SAVE NOTE'),
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
