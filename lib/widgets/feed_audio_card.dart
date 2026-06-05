import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dharma_ai/theme/theme.dart';
import 'package:dharma_ai/data/audio_tracks.dart';
import 'package:dharma_ai/providers/language_provider.dart';
import 'package:dharma_ai/providers/purchase_provider.dart';
import 'package:dharma_ai/services/purchase_service.dart';
import 'package:dharma_ai/screens/audio_wisdom_screen.dart';

// Which chapter is featured on the Feed. Random on app launch (rotates like the
// Daily Reflection); the shuffle button picks another.
final dailyAudioIndexProvider =
    StateProvider<int>((ref) => Random().nextInt(bgAudioTracks.length));

/// "Audio of the Day" — one Bhagavad Gita chapter, playable inline by everyone
/// (a free taste). "Explore all 18 chapters" routes free users to upgrade.
class FeedAudioCard extends ConsumerStatefulWidget {
  const FeedAudioCard({Key? key}) : super(key: key);

  @override
  ConsumerState<FeedAudioCard> createState() => _FeedAudioCardState();
}

class _FeedAudioCardState extends ConsumerState<FeedAudioCard> {
  final AudioPlayer _player = AudioPlayer();
  int? _loadedIndex;
  bool _buffering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(ref.read(dailyAudioIndexProvider));
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load(int index, {bool autoplay = false}) async {
    if (_loadedIndex == index) return;
    _loadedIndex = index;
    if (mounted) setState(() => _buffering = true);
    try {
      await _player.setUrl(bgAudioTracks[index].audioUrl);
      // Start playing as soon as it's ready so shuffle is one smooth action
      // (the player streams while it buffers the rest of the 28 MB file).
      if (autoplay && mounted) _player.play();
    } catch (e) {
      debugPrint('feed audio load error: $e');
    }
    if (mounted) setState(() => _buffering = false);
  }

  void _shuffle() {
    final wasPlaying = _player.playing;
    final n = bgAudioTracks.length;
    final cur = ref.read(dailyAudioIndexProvider);
    int next = Random().nextInt(n);
    if (n > 1) {
      while (next == cur) {
        next = Random().nextInt(n);
      }
    }
    ref.read(dailyAudioIndexProvider.notifier).state = next;
    _load(next, autoplay: wasPlaying);
  }

  void _openAll() {
    // AudioWisdomScreen self-gates: free users see the upgrade prompt, paid
    // users get the full 18-chapter player.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AudioWisdomScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lang = ref.watch(languageProvider);
    final tier = ref.watch(purchaseProvider);
    final index = ref.watch(dailyAudioIndexProvider);
    final track = bgAudioTracks[index];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SacredTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(SacredTheme.radiusLg),
        border: Border.all(color: SacredTheme.templeGold.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              const Icon(Icons.headphones_rounded, size: 16, color: SacredTheme.primary),
              const SizedBox(width: 6),
              Text(
                AppTranslations.get('audioWisdomTitle', lang).toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: SacredTheme.primary,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _shuffle,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.shuffle_rounded, size: 18, color: SacredTheme.outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Play button + title/progress
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _playButton(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.localizedTitle(lang.code),
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: SacredTheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.localizedYoga(lang.code)} · ${track.narrator}',
                      style: textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _progress(textTheme),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // Explore all → upgrade (free) / full player (paid)
          InkWell(
            onTap: _openAll,
            borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        tier == SubscriptionTier.free ? Icons.lock_outline_rounded : Icons.library_music_outlined,
                        size: 15,
                        color: SacredTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppTranslations.get('audioExploreAll', lang),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: SacredTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, size: 14, color: SacredTheme.primary),
                ],
              ),
            ),
          ),

          // Attribution (required by the temple's permission terms)
          const SizedBox(height: 8),
          _credit(),
        ],
      ),
    );
  }

  Widget _credit() {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: SacredTheme.templeGold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(SacredTheme.radiusSm),
        border: Border.all(color: SacredTheme.templeGold.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            'ऑडियो सौजन्य',
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: SacredTheme.primary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'श्री राधे-कृष्ण मंदिर, दरवेशपुर (उत्तर प्रदेश)',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansDevanagari(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SacredTheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
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
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: SacredTheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _playButton() {
    if (_buffering) {
      return const SizedBox(
        width: 52, height: 52,
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: SacredTheme.primary))),
      );
    }
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;
        final done = snap.data?.processingState == ProcessingState.completed;
        return IconButton(
          iconSize: 52,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            done ? Icons.replay_circle_filled
                 : playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: SacredTheme.primary,
          ),
          onPressed: () {
            if (done) {
              _player.seek(Duration.zero);
              _player.play();
            } else {
              playing ? _player.pause() : _player.play();
            }
          },
        );
      },
    );
  }

  Widget _progress(TextTheme textTheme) {
    return StreamBuilder<Duration?>(
      stream: _player.durationStream,
      builder: (context, dSnap) {
        final total = dSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, pSnap) {
            var pos = pSnap.data ?? Duration.zero;
            if (pos > total) pos = total;
            return SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Column(
                children: [
                  Slider(
                    activeColor: SacredTheme.primary,
                    inactiveColor: SacredTheme.outlineVariant,
                    value: pos.inMilliseconds.toDouble().clamp(0, total.inMilliseconds == 0 ? 1 : total.inMilliseconds.toDouble()),
                    max: total.inMilliseconds == 0 ? 1.0 : total.inMilliseconds.toDouble(),
                    onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pos), style: textTheme.labelSmall),
                        Text(total == Duration.zero ? '--:--' : _fmt(total), style: textTheme.labelSmall),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
