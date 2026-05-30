import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/purchase_service.dart';
import 'package:dharma_ai/screens/subscription_paywall_screen.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';

class OfflineLibraryScreen extends ConsumerStatefulWidget {
  const OfflineLibraryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OfflineLibraryScreen> createState() => _OfflineLibraryScreenState();
}

class _OfflineLibraryScreenState extends ConsumerState<OfflineLibraryScreen> {
  // Offline downloads local simulation states
  final Map<String, String> _downloadStatus = {
    'gita': 'Downloaded',
    'upanishads': 'Download',
    'vedas': 'Download',
    'audio': 'Download',
  };

  final Map<String, double> _downloadProgress = {
    'gita': 1.0,
    'upanishads': 0.0,
    'vedas': 0.0,
    'audio': 0.0,
  };

  Future<void> _triggerDownload(String key, bool isPremiumLocked) async {
    if (isPremiumLocked) {
      _showPremiumPrompt();
      return;
    }

    setState(() {
      _downloadStatus[key] = 'Downloading';
      _downloadProgress[key] = 0.05;
    });

    // Simulate byte progress
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        setState(() {
          _downloadProgress[key] = i * 0.1;
        });
      }
    }

    if (mounted) {
      setState(() {
        _downloadStatus[key] = 'Downloaded';
        _downloadProgress[key] = 1.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${key.toUpperCase()} downloaded to local storage vessel.'),
          backgroundColor: SacredTheme.primary,
        ),
      );
    }
  }

  void _showPremiumPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SacredTheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SacredTheme.radiusMd)),
        title: Text(
          'Premium Feature',
          style: GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.bold, color: SacredTheme.primary),
        ),
        content: Text(
          'Downloading advanced books and audio volumes for offline reading requires a Sadhaka Premium Membership path.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: SacredTheme.outline)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubscriptionPaywallScreen()),
              );
            },
            child: const Text('VIEW PATHS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTier = ref.watch(purchaseProvider);
    final isPremium = activeTier != SubscriptionTier.free; // both sadhaka & annual unlock downloads
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SacredTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Offline Library', style: textTheme.headlineMedium?.copyWith(fontSize: 20)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: SacredTheme.marginEdge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Offline Wisdom Library',
                style: textTheme.headlineMedium?.copyWith(
                  color: SacredTheme.meditativeIndigo,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Download scriptures, translations, and audio summaries directly to your device storage to seek wisdom even without a network vessel.',
                style: textTheme.bodyMedium,
              ),
              const FadingDivider(height: 28),

              // Gita download card
              _buildDownloadTile(
                title: 'Bhagavad Gita (Complete)',
                size: '4.2 MB',
                itemKey: 'gita',
                isPremiumLocked: false, // Free tier gets Gita offline
              ),
              const SizedBox(height: 12),

              // Upanishads download card
              _buildDownloadTile(
                title: 'Principal Upanishads (Vol 1)',
                size: '6.8 MB',
                itemKey: 'upanishads',
                isPremiumLocked: !isPremium,
              ),
              const SizedBox(height: 12),

              // Vedas download card
              _buildDownloadTile(
                title: 'Vedas Selections (Rig & Yajur)',
                size: '12.4 MB',
                itemKey: 'vedas',
                isPremiumLocked: !isPremium,
              ),
              const SizedBox(height: 12),

              // Audio Pack download card
              _buildDownloadTile(
                title: 'Daily Audio Summaries Pack',
                size: '22.1 MB',
                itemKey: 'audio',
                isPremiumLocked: !isPremium,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadTile({
    required String title,
    required String size,
    required String itemKey,
    required bool isPremiumLocked,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final status = _downloadStatus[itemKey]!;
    final progress = _downloadProgress[itemKey]!;

    return Card(
      color: SacredTheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isPremiumLocked ? Icons.lock : Icons.download_done,
                  color: isPremiumLocked ? SacredTheme.outline : SacredTheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      Text('Size: $size', style: textTheme.labelSmall),
                    ],
                  ),
                ),
                _buildDownloadButton(itemKey, status, isPremiumLocked),
              ],
            ),
            if (status == 'Downloading') ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: SacredTheme.surfaceContainerHighest,
                color: SacredTheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(String key, String status, bool isPremiumLocked) {
    if (isPremiumLocked) {
      return TextButton.icon(
        icon: const Icon(Icons.star, size: 12, color: SacredTheme.templeGold),
        label: const Text('PREMIUM', style: TextStyle(color: SacredTheme.templeGold, fontSize: 11, fontWeight: FontWeight.bold)),
        onPressed: _showPremiumPrompt,
      );
    }

    switch (status) {
      case 'Downloaded':
        return TextButton.icon(
          icon: const Icon(Icons.check, size: 12, color: SacredTheme.primary),
          label: const Text('CACHED', style: TextStyle(color: SacredTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
          onPressed: null,
        );
      case 'Downloading':
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: SacredTheme.primary),
        );
      default:
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: Size.zero,
          ),
          onPressed: () => _triggerDownload(key, isPremiumLocked),
          child: const Text('DOWNLOAD'),
        );
    }
  }
}
