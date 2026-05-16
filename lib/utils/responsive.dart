import 'package:flutter/material.dart';

class Responsive {
  static const double tabletBreakpoint = 600;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < tabletBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  // Wrapper for constraining max width
  static Widget constrainedWidth({
    required Widget child,
    double maxWidth = 1000,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
