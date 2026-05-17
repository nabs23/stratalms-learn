import 'package:flutter/material.dart';

import 'slide_types/slide_image_card.dart';
import 'slide_types/slide_multiple_choice.dart';
import 'slide_types/slide_summary.dart';
import 'slide_types/slide_text_and_image.dart';
import 'slide_types/slide_title_card.dart';

/// Routes a slide data map to the correct slide-type widget.
class SlideContent extends StatelessWidget {
  const SlideContent({
    super.key,
    required this.slide,
    required this.resolveUrl,
    required this.imageFit,
    required this.isRevealed,
    required this.onReveal,
  });

  final Map<String, dynamic> slide;
  final String? Function(String?) resolveUrl;
  final BoxFit imageFit;
  final bool isRevealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final type = slide['slide_type']?.toString() ?? 'TITLE_CARD';
    final imageUrl = resolveUrl(slide['image_url']?.toString());
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    if (type == 'TEXT_AND_IMAGE') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasImage) ...[
            SlideImageCard(imageUrl: imageUrl, imageFit: imageFit),
            const SizedBox(height: 16),
          ],
          SlideTextAndImage(slide: slide, resolveUrl: resolveUrl),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasImage) ...[
          SlideImageCard(imageUrl: imageUrl, imageFit: imageFit),
          const SizedBox(height: 16),
        ],
        switch (type) {
          'TITLE_CARD' => SlideTitleCard(slide: slide, resolveUrl: resolveUrl),
          'MULTIPLE_CHOICE_QUIZ' => SlideMultipleChoice(
              slide: slide,
              isRevealed: isRevealed,
              onReveal: onReveal,
              resolveUrl: resolveUrl,
            ),
          'SUMMARY' => SlideSummary(slide: slide, resolveUrl: resolveUrl),
          _ => SlideTitleCard(slide: slide, resolveUrl: resolveUrl),
        },
      ],
    );
  }
}
