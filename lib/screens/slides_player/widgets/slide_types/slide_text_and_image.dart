import 'package:flutter/material.dart';

import '../../slides_player_constants.dart';
import '../slide_markdown.dart';

class SlideTextAndImage extends StatelessWidget {
  const SlideTextAndImage({
    super.key,
    required this.slide,
    required this.resolveUrl,
  });

  final Map<String, dynamic> slide;
  final String? Function(String?) resolveUrl;

  @override
  Widget build(BuildContext context) {
    final title = slide['text_and_image_title']?.toString().trim();
    final text = slide['text_and_image_text']?.toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: slideCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title.isNotEmpty) ...[
            SlideMarkdown(
              title,
              resolveUrl: resolveUrl,
              paragraphStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1B4B),
                height: 1.3,
              ),
            ),
            if (text != null && text.isNotEmpty) const SizedBox(height: 14),
          ],
          if (text != null && text.isNotEmpty)
            SlideMarkdown(
              text,
              resolveUrl: resolveUrl,
              selectable: true,
              paragraphStyle: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }
}
