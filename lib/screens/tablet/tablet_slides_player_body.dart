import 'package:flutter/material.dart';

import '../slides_player/widgets/slide_content.dart';
import '../slides_player/widgets/slide_types/slide_image_card.dart';
import '../slides_player/widgets/slide_types/slide_text_and_image.dart';
import '../slides_player/widgets/slides_audio_panel.dart';
import '../slides_player/slides_audio_controller.dart';

class TabletSlidesPlayerBody extends StatelessWidget {
  const TabletSlidesPlayerBody({
    super.key,
    required this.currentSlide,
    required this.currentIndex,
    required this.audio,
    required this.hasAudio,
    required this.imageFit,
    required this.revealedAnswers,
    required this.resolveUrl,
    required this.onReveal,
  });

  final Map<String, dynamic> currentSlide;
  final int currentIndex;
  final SlidesAudioController audio;
  final bool hasAudio;
  final BoxFit imageFit;
  final Set<int> revealedAnswers;
  final String? Function(String?) resolveUrl;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final type = currentSlide['slide_type']?.toString() ?? 'TITLE_CARD';
    final imageUrl = resolveUrl(currentSlide['image_url']?.toString());
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    if (type == 'TEXT_AND_IMAGE' && hasImage) {
      return Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 10, 8),
                    child: SlideImageCard(
                      imageUrl: imageUrl,
                      imageFit: imageFit,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(10, 20, 20, 8),
                    child: SlideTextAndImage(
                      slide: currentSlide,
                      resolveUrl: resolveUrl,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildAudioPanel(),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: SlideContent(
                  slide: currentSlide,
                  resolveUrl: resolveUrl,
                  imageFit: imageFit,
                  isRevealed: revealedAnswers.contains(currentIndex),
                  onReveal: onReveal,
                ),
              ),
            ),
          ),
        ),
        _buildAudioPanel(),
      ],
    );
  }

  Widget _buildAudioPanel() {
    return SlidesAudioPanel(
      audio: audio,
      hasAudio: hasAudio,
      script: currentSlide['script']?.toString(),
      resolveUrl: resolveUrl,
    );
  }
}
