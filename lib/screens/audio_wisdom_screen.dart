import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/widgets/mandala_background.dart';
import 'package:dharma_ai/widgets/fading_divider.dart';
import 'package:dharma_ai/widgets/lotus_painter.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/purchase_service.dart';
import 'package:dharma_ai/screens/subscription_paywall_screen.dart';
import 'package:dharma_ai/data/audio_tracks.dart';

class AudioWisdomScreen extends ConsumerStatefulWidget {
  const AudioWisdomScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AudioWisdomScreen> createState() => _AudioWisdomScreenState();
}

class _AudioWisdomScreenState extends ConsumerState<AudioWisdomScreen> {
  late AudioPlayer _audioPlayer;
  int _selectedTrackIndex = 0;
  bool _isBuffering = false;
  // Real track lengths, fetched from the audio metadata (replaces estimates).
  final Map<int, Duration> _durations = {};

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initTrack(_selectedTrackIndex, play: false);

    _audioPlayer.processingStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isBuffering = state == ProcessingState.buffering ||
              state == ProcessingState.loading;
        });
      }
    });

    _loadDurations();
  }

  // Fetch each track's true duration (metadata only) so the UI never shows a
  // hardcoded estimate. Runs in the background; durations fill in as they load.
  Future<void> _loadDurations() async {
    for (int i = 0; i < bgAudioTracks.length; i++) {
      try {
        final probe = AudioPlayer();
        final d = await probe.setUrl(bgAudioTracks[i].audioUrl);
        if (d != null && mounted) setState(() => _durations[i] = d);
        await probe.dispose(); // awaited inside this try → its error is caught here
      } catch (_) {
        // skip tracks that fail to probe
      }
    }
  }

  Future<void> _initTrack(int index, {required bool play}) async {
    try {
      setState(() {
        _selectedTrackIndex = index;
        _isBuffering = true;
      });
      await _audioPlayer.setUrl(bgAudioTracks[index].audioUrl);
      if (play) await _audioPlayer.play();
    } catch (e) {
      debugPrint('Audio load error: $e');
    } finally {
      if (mounted) setState(() => _isBuffering = false);
    }
  }

  @override
  void dispose() {
    // just_audio on web can reject dispose() with UnimplementedError; swallow it.
    _audioPlayer.dispose().catchError((Object _) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lang = ref.watch(languageProvider);
    final tier = ref.watch(purchaseProvider);
    final track = bgAudioTracks[_selectedTrackIndex];

    // ── Premium gate ──────────────────────────────────────────
    if (tier == SubscriptionTier.free) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: SacredTheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(AppTranslations.get('audioWisdomTitle', lang),
              style: textTheme.headlineMedium?.copyWith(fontSize: 20)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.headphones, size: 72,
                    color: SacredTheme.templeGold.withOpacity(0.5)),
                const SizedBox(height: 24),
                Text(AppTranslations.get('audioWisdomTitle', lang),
                    style: textTheme.headlineMedium
                        ?.copyWith(color: SacredTheme.headingColor(context)),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  AppTranslations.get('audioGateBody', lang),
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.star),
                    label: Text(AppTranslations.get('upgradeToUnlock', lang)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SacredTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SubscriptionPaywallScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Main player (paid users) ──────────────────────────────
    return Scaffold(
      body: MandalaBackground(
        scale: 0.9,
        alignment: Alignment.center,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    SacredTheme.marginEdge, 12, SacredTheme.marginEdge, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: SacredTheme.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppTranslations.get('audioWisdomTitle', lang),
                      style: textTheme.headlineLarge
                          ?.copyWith(color: SacredTheme.headingColor(context)),
                    ),
                  ],
                ),
              ),
              const FadingDivider(height: 12),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: SacredTheme.marginEdge),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Cover art
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: SacredTheme.surfaceContainerHighest,
                          borderRadius:
                              BorderRadius.circular(SacredTheme.radiusLg),
                          border: Border.all(
                              color: SacredTheme.templeGold.withOpacity(0.3)),
                        ),
                        child: Center(
                          child: _isBuffering
                              ? const LotusLoadingIndicator(size: 72)
                              : _CoverArt(
                                  chapter: track.chapter,
                                  color: SacredTheme.primary,
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Track title + yoga name
                      Text(
                        track.localizedTitle(lang.code),
                        style: textTheme.headlineMedium?.copyWith(
                          fontSize: 22,
                          color: SacredTheme.headingColor(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${track.localizedYoga(lang.code)}  •  ${track.narrator}',
                        style: textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.chapterLabel,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: SacredTheme.outline),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Progress slider
                      StreamBuilder<Duration?>(
                        stream: _audioPlayer.durationStream,
                        builder: (context, snap) {
                          final total = snap.data ?? Duration.zero;
                          return StreamBuilder<Duration>(
                            stream: _audioPlayer.positionStream,
                            builder: (context, snap2) {
                              var pos = snap2.data ?? Duration.zero;
                              if (pos > total) pos = total;
                              return Column(
                                children: [
                                  Slider(
                                    activeColor: SacredTheme.primary,
                                    inactiveColor: SacredTheme.outlineVariant,
                                    value: pos.inMilliseconds.toDouble(),
                                    max: total.inMilliseconds == 0
                                        ? 1.0
                                        : total.inMilliseconds.toDouble(),
                                    onChanged: (v) => _audioPlayer.seek(
                                        Duration(milliseconds: v.toInt())),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_fmt(pos),
                                            style: textTheme.labelSmall),
                                        Text(
                                          // real duration once loaded; else the
                                          // pre-probed length, else a placeholder
                                          total != Duration.zero
                                              ? _fmt(total)
                                              : _durations[_selectedTrackIndex] != null
                                                  ? _fmt(_durations[_selectedTrackIndex]!)
                                                  : '--:--',
                                          style: textTheme.labelSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 8),

                      // Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 36,
                            icon: const Icon(Icons.skip_previous_outlined,
                                color: SacredTheme.onSurface),
                            onPressed: _selectedTrackIndex > 0
                                ? () => _initTrack(
                                    _selectedTrackIndex - 1,
                                    play: true)
                                : null,
                          ),
                          const SizedBox(width: 20),
                          StreamBuilder<PlayerState>(
                            stream: _audioPlayer.playerStateStream,
                            builder: (context, snap) {
                              final playing = snap.data?.playing ?? false;
                              final done = snap.data?.processingState ==
                                  ProcessingState.completed;
                              if (done) {
                                return IconButton(
                                  iconSize: 64,
                                  icon: const Icon(Icons.replay,
                                      color: SacredTheme.primary),
                                  onPressed: () =>
                                      _audioPlayer.seek(Duration.zero),
                                );
                              }
                              return IconButton(
                                iconSize: 64,
                                icon: Icon(
                                  playing
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  color: SacredTheme.primary,
                                ),
                                onPressed: () =>
                                    playing ? _audioPlayer.pause() : _audioPlayer.play(),
                              );
                            },
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            iconSize: 36,
                            icon: const Icon(Icons.skip_next_outlined,
                                color: SacredTheme.onSurface),
                            onPressed:
                                _selectedTrackIndex < bgAudioTracks.length - 1
                                    ? () => _initTrack(
                                        _selectedTrackIndex + 1,
                                        play: true)
                                    : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Playlist header
                      Row(
                        children: [
                          Text(
                            'ALL 18 CHAPTERS',
                            style: textTheme.labelSmall
                                ?.copyWith(color: SacredTheme.primary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${bgAudioTracks.length} tracks',
                            style: GoogleFonts.inter(
                                fontSize: 10, color: SacredTheme.outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Playlist
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: bgAudioTracks.length,
                        itemBuilder: (context, i) {
                          final t = bgAudioTracks[i];
                          final isSelected = i == _selectedTrackIndex;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Card(
                              color: isSelected
                                  ? SacredTheme.surfaceContainer
                                  : SacredTheme.surfaceContainerLowest,
                              child: ListTile(
                                dense: true,
                                leading: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? SacredTheme.primary
                                        : SacredTheme.outlineVariant
                                            .withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${t.chapter}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : SacredTheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  t.localizedTitle(lang.code),
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? SacredTheme.primary
                                        : SacredTheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  t.localizedYoga(lang.code),
                                  style: textTheme.labelSmall,
                                ),
                                trailing: Text(
                                  _durations[i] != null ? _fmt(_durations[i]!) : '--:--',
                                  style: textTheme.labelSmall,
                                ),
                                onTap: () => _initTrack(i, play: true),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Audio credit (required by the temple's permission terms)
                      _audioCredit(context),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _audioCredit(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SacredTheme.templeGold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(SacredTheme.radiusMd),
        border: Border.all(color: SacredTheme.templeGold.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            'ऑडियो सौजन्य',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: SacredTheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'श्री राधे-कृष्ण मंदिर, दरवेशपुर (उत्तर प्रदेश)',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansDevanagari(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SacredTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _creditLink('Website', 'https://sriradhekrishnmandir.blogspot.com/'),
              const SizedBox(width: 8),
              Text('·', style: textTheme.labelSmall),
              const SizedBox(width: 8),
              _creditLink('Facebook', 'https://www.facebook.com/Sriradhekrishnmandirderveshpur'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _creditLink(String label, String url) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: SacredTheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// Cover art widget showing chapter number
class _CoverArt extends StatelessWidget {
  final int chapter;
  final Color color;
  const _CoverArt({required this.chapter, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(Icons.graphic_eq, size: 44, color: color),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Chapter $chapter',
          style: GoogleFonts.newsreader(
            fontSize: 13,
            color: color.withOpacity(0.7),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
