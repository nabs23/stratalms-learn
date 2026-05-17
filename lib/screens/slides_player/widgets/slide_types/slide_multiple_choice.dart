import 'package:flutter/material.dart';

import '../../slides_player_constants.dart';
import '../slide_markdown.dart';

class SlideMultipleChoice extends StatelessWidget {
  const SlideMultipleChoice({
    super.key,
    required this.slide,
    required this.isRevealed,
    required this.onReveal,
    required this.resolveUrl,
  });

  final Map<String, dynamic> slide;
  final bool isRevealed;
  final VoidCallback onReveal;
  final String? Function(String?) resolveUrl;

  @override
  Widget build(BuildContext context) {
    final question =
        slide['multiple_choice_question']?.toString().trim() ?? '';
    final options = (slide['multiple_choice_options'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final explanation = slide['multiple_choice_explanation']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: kSlidePrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'QUIZ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: kSlidePrimary,
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
              SlideMarkdown(
                question,
                resolveUrl: resolveUrl,
                paragraphStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E1B4B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              ...options.map((option) => _OptionTile(
                    option: option,
                    isRevealed: isRevealed,
                    resolveUrl: resolveUrl,
                  )),
              const SizedBox(height: 6),
              if (!isRevealed)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kSlidePrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onReveal,
                    child: const Text(
                      'Reveal Answer',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              if (isRevealed &&
                  explanation != null &&
                  explanation.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBADEFB)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_rounded,
                        size: 18,
                        color: Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SlideMarkdown(
                          explanation,
                          resolveUrl: resolveUrl,
                          paragraphStyle: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E3A5F),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.isRevealed,
    required this.resolveUrl,
  });

  final Map<String, dynamic> option;
  final bool isRevealed;
  final String? Function(String?) resolveUrl;

  @override
  Widget build(BuildContext context) {
    final label = option['option']?.toString() ?? '';
    final isCorrect = option['is_correct'] == true;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    Widget? trailingIcon;

    if (isRevealed) {
      if (isCorrect) {
        bgColor = const Color(0xFFECFDF5);
        borderColor = const Color(0xFF10B981);
        textColor = const Color(0xFF065F46);
        trailingIcon = const Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: Color(0xFF10B981),
        );
      } else {
        bgColor = const Color(0xFFFFF1F2);
        borderColor = const Color(0xFFFCA5A5);
        textColor = const Color(0xFF7F1D1D);
        trailingIcon = const Icon(
          Icons.cancel_rounded,
          size: 20,
          color: Color(0xFFF87171),
        );
      }
    } else {
      bgColor = const Color(0xFFF9F9FC);
      borderColor = const Color(0xFFE2E2F0);
      textColor = const Color(0xFF374151);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: SlideMarkdown(
                label,
                resolveUrl: resolveUrl,
                paragraphStyle: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: textColor,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              trailingIcon,
            ],
          ],
        ),
      ),
    );
  }
}
