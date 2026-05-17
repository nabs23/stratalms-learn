import 'package:flutter/material.dart';

import '../slides_player_constants.dart';

class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.active,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active
                ? kSlidePrimary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active
                ? kSlidePrimary
                : onTap != null
                    ? Colors.grey[600]
                    : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}
