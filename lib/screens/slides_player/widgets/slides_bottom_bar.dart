import 'package:flutter/material.dart';

import '../slides_player_constants.dart';
import 'nav_button.dart';

class SlidesBottomBar extends StatelessWidget {
  const SlidesBottomBar({
    super.key,
    required this.currentIndex,
    required this.totalSlides,
    required this.onPrev,
    required this.onNext,
    required this.onGoTo,
  });

  final int currentIndex;
  final int totalSlides;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(int) onGoTo;

  bool get _isFirst => currentIndex == 0;
  bool get _isLast => currentIndex == totalSlides - 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kSlideSurface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          NavButton(
            icon: Icons.arrow_back_rounded,
            label: 'Prev',
            enabled: !_isFirst,
            onTap: onPrev,
          ),
          Expanded(child: _buildDotIndicator()),
          NavButton(
            icon: Icons.arrow_forward_rounded,
            label: 'Next',
            enabled: !_isLast,
            isPrimary: true,
            onTap: onNext,
          ),
        ],
      ),
    );
  }

  Widget _buildDotIndicator() {
    if (totalSlides > 11) {
      return Center(
        child: Text(
          '${currentIndex + 1} / $totalSlides',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalSlides, (i) {
            final active = i == currentIndex;
            final near = (i - currentIndex).abs() <= 2;
            return GestureDetector(
              onTap: () => onGoTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 22 : (near ? 7 : 5),
                height: active ? 7 : (near ? 7 : 5),
                decoration: BoxDecoration(
                  color: active
                      ? kSlidePrimary
                      : near
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
