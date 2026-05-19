import 'package:flutter/material.dart';

import '../slides_player_constants.dart';
import 'header_icon_button.dart';

class SlidesHeader extends StatelessWidget {
  const SlidesHeader({
    super.key,
    required this.activityTitle,
    required this.currentIndex,
    required this.totalSlides,
    required this.progress,
    required this.hasAudio,
    required this.hasImage,
    required this.isAudioEnabled,
    required this.isAudioPlaying,
    required this.autoAdvance,
    required this.onClose,
    required this.onToggleAudio,
    required this.onTogglePlayPause,
    required this.onToggleAutoAdvance,
    required this.onCycleImageFit,
  });

  final String activityTitle;
  final int currentIndex;
  final int totalSlides;
  final double progress;

  final bool hasAudio;
  final bool hasImage;
  final bool isAudioEnabled;
  final bool isAudioPlaying;
  final bool autoAdvance;

  final VoidCallback onClose;
  final VoidCallback onToggleAudio;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleAutoAdvance;
  final VoidCallback onCycleImageFit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kSlideSurface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                  tooltip: 'Close',
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activityTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1B4B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Slide ${currentIndex + 1} of $totalSlides',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActions(context),
              ],
            ),
          ),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final actions = <Widget>[
      if (hasAudio) ...[
        HeaderIconButton(
          icon: isAudioEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          active: isAudioEnabled,
          onTap: onToggleAudio,
          tooltip: isAudioEnabled ? 'Mute audio' : 'Unmute audio',
        ),
        const SizedBox(width: 4),
        HeaderIconButton(
          icon: isAudioPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          active: isAudioEnabled,
          onTap: isAudioEnabled ? onTogglePlayPause : null,
          tooltip: isAudioPlaying ? 'Pause' : 'Play',
        ),
        const SizedBox(width: 4),
        HeaderIconButton(
          icon: Icons.fast_forward_rounded,
          active: autoAdvance,
          onTap: isAudioEnabled ? onToggleAutoAdvance : null,
          tooltip: autoAdvance ? 'Disable auto-advance' : 'Auto-advance',
        ),
      ],
      if (hasImage) ...[
        const SizedBox(width: 4),
        HeaderIconButton(
          icon: Icons.fit_screen_rounded,
          active: false,
          onTap: onCycleImageFit,
          tooltip: 'Cycle image fit',
        ),
      ],
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.42),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: actions,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return LinearProgressIndicator(
          value: value,
          minHeight: 3,
          backgroundColor: const Color(0xFFE8E8F0),
          valueColor: const AlwaysStoppedAnimation<Color>(kSlidePrimary),
        );
      },
    );
  }
}
