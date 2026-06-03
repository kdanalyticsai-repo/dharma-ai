import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/sadhana_provider.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/providers/language_provider.dart';

class SadhanaScreen extends ConsumerWidget {
  const SadhanaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sadhana = ref.watch(sadhanaProvider);
    final notifier = ref.read(sadhanaProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final currentLanguage = ref.watch(languageProvider);

    return Scaffold(
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
                const SizedBox(height: 16),
                
                // Streak header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        AppTranslations.get('sadhanaDashboard', currentLanguage),
                        style: textTheme.headlineMedium?.copyWith(
                          color: SacredTheme.headingColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                      onTap: () => _showStreakInfo(context, sadhana.streak, currentLanguage),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: SacredTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
                          border: Border.all(color: SacredTheme.primary.withOpacity(0.3), width: 0.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department, color: SacredTheme.primary, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${sadhana.streak} ${AppTranslations.get('dayStreakLabel', currentLanguage)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: SacredTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const FadingDivider(height: 24),

                // Custom Lotus Progress Ring Card
                Card(
                  color: SacredTheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        // Custom Painted Lotus Progress Indicator
                        CustomPaint(
                          size: const Size(100, 100),
                          painter: LotusProgressPainter(
                            progress: sadhana.overallProgress,
                            color: SacredTheme.deepSaffron,
                            ringColor: SacredTheme.outlineVariant,
                          ),
                        ),
                        const SizedBox(width: 24),
                        
                        // Percentage and encouragement text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(sadhana.overallProgress * 100).toInt()}% ${AppTranslations.get('completeLabel', currentLanguage)}',
                                style: textTheme.headlineMedium?.copyWith(
                                  color: SacredTheme.primary,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sadhana.overallProgress >= 1.0
                                    ? AppTranslations.get('goalsFulfilled', currentLanguage)
                                    : AppTranslations.get('goalsProgress', currentLanguage),
                                style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: SacredTheme.stackLg),

                // Metrics List
                Text(
                  AppTranslations.get('todaysGoals', currentLanguage),
                  style: textTheme.labelSmall?.copyWith(color: SacredTheme.primary),
                ),
                const SizedBox(height: SacredTheme.stackMd),

                // Goal 1: Meditation
                _buildGoalCard(
                  context,
                  title: AppTranslations.get('meditateBreathe', currentLanguage),
                  progressString: '${sadhana.todayMeditation} / ${sadhana.targetMeditation} ${AppTranslations.get('minsLabel', currentLanguage)}',
                  progress: sadhana.todayMeditation / sadhana.targetMeditation,
                  icon: Icons.self_improvement,
                  action: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => notifier.incrementMeditation(5),
                    child: Text(AppTranslations.get('add5Mins', currentLanguage)),
                  ),
                ),
                const SizedBox(height: SacredTheme.stackSm),

                // Goal 2: Scripture Study
                _buildGoalCard(
                  context,
                  title: AppTranslations.get('versesReadGoal', currentLanguage),
                  progressString: '${sadhana.todayVerses} / ${sadhana.targetVerses} ${AppTranslations.get('versesLabel', currentLanguage)}',
                  progress: sadhana.todayVerses / sadhana.targetVerses,
                  icon: Icons.menu_book_outlined,
                  action: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => notifier.incrementVerses(),
                    child: Text(AppTranslations.get('add1Verse', currentLanguage)),
                  ),
                ),
                const SizedBox(height: SacredTheme.stackSm),

                // Goal 3: Chanting
                _buildGoalCard(
                  context,
                  title: AppTranslations.get('chantingGoal', currentLanguage),
                  progressString: '${sadhana.todayChanting} / ${sadhana.targetChanting} ${AppTranslations.get('beadsLabel', currentLanguage)}',
                  progress: sadhana.todayChanting / sadhana.targetChanting,
                  icon: Icons.grain,
                  action: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => notifier.incrementChanting(10),
                    child: Text(AppTranslations.get('add10Beads', currentLanguage)),
                  ),
                ),

                const SizedBox(height: 24),
                
                // Reset today's progress (with confirmation)
                Center(
                  child: TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: SacredTheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(SacredTheme.radiusMd)),
                          title: Text(
                            AppTranslations.get('resetTodayProgress', currentLanguage),
                            style: GoogleFonts.newsreader(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: SacredTheme.headingColor(ctx)),
                          ),
                          content: Text(
                            AppTranslations.get('resetConfirmBody', currentLanguage),
                            style: Theme.of(ctx).textTheme.bodyMedium,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                AppTranslations.get('cancelBtn', currentLanguage),
                                style: const TextStyle(color: SacredTheme.outline),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                  AppTranslations.get('resetConfirmBtn', currentLanguage)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) notifier.resetToday();
                    },
                    child: Text(
                      AppTranslations.get('resetTodayProgress', currentLanguage),
                      style: GoogleFonts.inter(color: SacredTheme.outline, fontSize: 12),
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

  void _showStreakInfo(BuildContext context, int streak, AppLanguage lang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SacredTheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusMd)),
        title: Row(
          children: [
            const Icon(Icons.local_fire_department, color: SacredTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppTranslations.get('streakInfoTitle', lang),
                style: GoogleFonts.newsreader(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: SacredTheme.headingColor(context),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '🔥 $streak ${AppTranslations.get('dayStreakLabel', lang)}\n\n${AppTranslations.get('streakInfoBody', lang)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.get('streakInfoBtn', lang)),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context, {
    required String title,
    required String progressString,
    required double progress,
    required IconData icon,
    required Widget action,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final double fillPercentage = progress.clamp(0.0, 1.0);

    return Card(
      color: SacredTheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: SacredTheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      Text(progressString, style: textTheme.labelSmall),
                    ],
                  ),
                ),
                action,
              ],
            ),
            const SizedBox(height: 12),
            // Progress Bar
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                color: SacredTheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fillPercentage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: SacredTheme.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter drawing the Lotus Progress Circle
class LotusProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color ringColor;

  LotusProgressPainter({
    required this.progress,
    required this.color,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = size.width / 2;

    // Draw background track ring
    final Paint trackPaint = Paint()
      ..color = ringColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(Offset(cx, cy), radius - 2, trackPaint);

    // Draw progress arc
    final Paint progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final double angle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius - 2),
      -math.pi / 2, // Start at 12 o'clock
      angle,
      false,
      progressPaint,
    );

    // Draw small Lotus shape in the center of the ring
    final Paint lotusPaint = Paint()
      ..color = color.withOpacity(0.1 + (progress * 0.9)) // Fades in as progress increases
      ..style = PaintingStyle.fill;
    
    final Paint lotusStroke = Paint()
      ..color = color.withOpacity(0.3 + (progress * 0.7))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double lr = radius * 0.45; // lotus radius
    
    canvas.save();
    canvas.translate(cx, cy);

    // Draw 4 cardinal petals
    for (int i = 0; i < 4; i++) {
      final double petalAngle = (i * 2 * math.pi) / 4;
      canvas.save();
      canvas.rotate(petalAngle);

      final Path petal = Path();
      petal.moveTo(0, 0);
      petal.quadraticBezierTo(-lr * 0.5, -lr * 0.8, 0, -lr);
      petal.quadraticBezierTo(lr * 0.5, -lr * 0.8, 0, 0);
      
      canvas.drawPath(petal, lotusPaint);
      canvas.drawPath(petal, lotusStroke);
      
      canvas.restore();
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LotusProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.ringColor != ringColor;
  }
}
