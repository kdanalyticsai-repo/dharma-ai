import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/screens/scripture_chat_screen.dart';
import 'package:dharma_ai/screens/guru_chat_screen.dart';

class ChatParentScreen extends ConsumerStatefulWidget {
  const ChatParentScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatParentScreen> createState() => _ChatParentScreenState();
}

class _ChatParentScreenState extends ConsumerState<ChatParentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lang = ref.watch(languageProvider);

    return Scaffold(
      body: MandalaBackground(
        scale: 0.85,
        child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SacredTheme.marginEdge, 14, SacredTheme.marginEdge, 0),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 20, color: SacredTheme.templeGold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppTranslations.get('aiSpiritualGuide', lang),
                      style: textTheme.headlineLarge?.copyWith(
                        color: SacredTheme.headingColor(context),
                        fontSize: 22,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Beautiful Tab Switcher ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: SacredTheme.marginEdge),
              child: Row(
                children: [
                  _buildTab(
                    index: 0,
                    icon: Icons.menu_book_rounded,
                    label: AppTranslations.get('tabScriptureScholar', lang),
                    isSelected: _selectedIndex == 0,
                  ),
                  const SizedBox(width: 12),
                  _buildTab(
                    index: 1,
                    icon: Icons.self_improvement_rounded,
                    label: AppTranslations.get('tabAiGuruMode', lang),
                    isSelected: _selectedIndex == 1,
                  ),
                ],
              ),
            ),

            // ── Mode subtitle ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SacredTheme.marginEdge, 10, SacredTheme.marginEdge, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  _selectedIndex == 0
                      ? 'Verse-grounded answers with citations'
                      : 'Empathetic spiritual counsel & guidance',
                  key: ValueKey(_selectedIndex),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: SacredTheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Tab Views ─────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  ScriptureChatScreen(),
                  GuruChatScreen(),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() => _selectedIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: 72,
          decoration: isSelected
              ? BoxDecoration(
                  color: SacredTheme.accentFill(context),
                  borderRadius: BorderRadius.circular(SacredTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: SacredTheme.accentFill(context).withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                )
              : BoxDecoration(
                  color: SacredTheme.headingColor(context).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(SacredTheme.radiusLg),
                  border: Border.all(
                    color: SacredTheme.headingColor(context).withOpacity(0.2),
                    width: 1.0,
                  ),
                ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected
                    ? SacredTheme.templeGold
                    : SacredTheme.headingColor(context).withOpacity(0.6),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : SacredTheme.headingColor(context).withOpacity(0.7),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
