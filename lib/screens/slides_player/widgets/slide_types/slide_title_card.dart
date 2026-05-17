import 'package:flutter/material.dart';

import '../../slides_player_constants.dart';
import '../slide_markdown.dart';

class SlideTitleCard extends StatelessWidget {
  const SlideTitleCard({
    super.key,
    required this.slide,
    required this.resolveUrl,
  });

  final Map<String, dynamic> slide;
  final String? Function(String?) resolveUrl;

  @override
  Widget build(BuildContext context) {
    final title = slide['title_card_title']?.toString().trim();
    final subtitle = slide['title_card_subtitle']?.toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: slideCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title.isNotEmpty)
            SlideMarkdown(
              title,
              resolveUrl: resolveUrl,
              paragraphStyle: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1B4B),
                height: 1.25,
              ),
            ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 14),
            SlideMarkdown(
              subtitle,
              resolveUrl: resolveUrl,
              paragraphStyle: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
