import 'package:flutter/material.dart';

import '../../slides_player_constants.dart';
import '../slide_markdown.dart';

class SlideSummary extends StatelessWidget {
  const SlideSummary({
    super.key,
    required this.slide,
    required this.resolveUrl,
  });

  final Map<String, dynamic> slide;
  final String? Function(String?) resolveUrl;

  @override
  Widget build(BuildContext context) {
    final title = slide['summary_title']?.toString().trim();
    final points = (slide['summary_points'] as List<dynamic>? ?? [])
        .map((p) => p.toString())
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'SUMMARY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF10B981),
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
                  ),
                ),
                if (points.isNotEmpty) const SizedBox(height: 18),
              ],
              ...points.map(
                (point) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: kSlidePrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SlideMarkdown(
                          point,
                          resolveUrl: resolveUrl,
                          paragraphStyle: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[800],
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
