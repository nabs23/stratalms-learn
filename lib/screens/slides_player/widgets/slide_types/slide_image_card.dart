import 'package:flutter/material.dart';

import '../../slides_player_constants.dart';

class SlideImageCard extends StatelessWidget {
  const SlideImageCard({
    super.key,
    required this.imageUrl,
    required this.imageFit,
  });

  final String imageUrl;
  final BoxFit imageFit;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFFEEEEF8),
          boxShadow: [
            BoxShadow(
              color: kSlidePrimary.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            imageUrl,
            fit: imageFit,
            errorBuilder: (_, error, __) {
              debugPrint('Image load error ($imageUrl): $error');
              return Container(
                color: const Color(0xFFEEEEF8),
                child: Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                ),
              );
            },
            loadingBuilder: (_, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: const Color(0xFFEEEEF8),
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                    color: kSlidePrimary,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
