import 'package:flutter/material.dart';

import '../slides_audio_controller.dart';
import '../slides_player_constants.dart';
import 'slide_markdown.dart';

class SlidesAudioPanel extends StatefulWidget {
  const SlidesAudioPanel({
    super.key,
    required this.audio,
    required this.hasAudio,
    required this.script,
    required this.resolveUrl,
  });

  final SlidesAudioController audio;
  final bool hasAudio;

  /// Script text for the current slide, or null/empty if unavailable.
  final String? script;

  final String? Function(String?) resolveUrl;

  @override
  State<SlidesAudioPanel> createState() => _SlidesAudioPanelState();
}

class _SlidesAudioPanelState extends State<SlidesAudioPanel> {
  bool _showScript = false;

  @override
  void didUpdateWidget(SlidesAudioPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Collapse script when the slide changes.
    if (oldWidget.script != widget.script) {
      _showScript = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final script = widget.script;
    final hasScript = script != null && script.isNotEmpty;

    if (!widget.hasAudio && !hasScript) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: widget.audio,
      builder: (context, _) {
        final durationMs = widget.audio.duration.inMilliseconds;
        final positionMs = widget.audio.position.inMilliseconds;
        final sliderMax = durationMs <= 0 ? 1.0 : durationMs.toDouble();
        final sliderValue =
            positionMs.clamp(0, durationMs <= 0 ? 1 : durationMs).toDouble();
        final progressFraction = durationMs > 0
            ? (positionMs / durationMs).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.hasAudio) _buildPlayerRow(sliderMax, sliderValue, positionMs, durationMs, progressFraction),
              if (hasScript) _buildScriptToggle(script, hasScript),
              if (!hasScript) const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerRow(
    double sliderMax,
    double sliderValue,
    int positionMs,
    int durationMs,
    double progressFraction,
  ) {
    final audio = widget.audio;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: audio.isEnabled
                ? () => audio.togglePlayPause(audio.loadedUrl)
                : null,
            child: Icon(
              audio.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              size: 36,
              color: audio.isEnabled ? kSlidePrimary : Colors.grey[400],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: kSlidePrimary,
                    inactiveTrackColor: const Color(0xFFE2E2F0),
                    thumbColor: kSlidePrimary,
                    overlayColor: kSlidePrimary.withOpacity(0.15),
                  ),
                  child: Slider(
                    value: sliderValue,
                    max: sliderMax,
                    onChanged: audio.isEnabled && durationMs > 0
                        ? (v) => audio.seekTo(Duration(milliseconds: v.round()))
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _label(audio.position),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        height: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progressFraction,
                            backgroundColor: const Color(0xFFE2E2F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              kSlidePrimary,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        _label(audio.duration),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildScriptToggle(String script, bool hasScript) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _showScript = !_showScript),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              widget.hasAudio ? 10 : 12,
              16,
              12,
            ),
            child: Row(
              children: [
                Icon(Icons.article_outlined, size: 15, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  _showScript ? 'Hide script' : 'Show script',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  _showScript
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
        if (_showScript)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SlideMarkdown(
              script,
              resolveUrl: widget.resolveUrl,
              paragraphStyle: TextStyle(
                fontSize: 12.5,
                color: Colors.grey[700],
                height: 1.55,
              ),
            ),
          ),
      ],
    );
  }

  String _label(Duration value) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60);
    final s = value.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
