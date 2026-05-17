import 'package:flutter/material.dart';

const Color kSlidePrimary = Color(0xFF6366F1);
const Color kSlideSurface = Colors.white;
const Color kSlideBackground = Color(0xFFF5F6FA);

BoxDecoration slideCardDecoration() {
  return BoxDecoration(
    color: kSlideSurface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0xFFEEEEF8), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
