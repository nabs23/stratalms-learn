import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// A thin wrapper around [MarkdownBody] that handles link taps and
/// inline image rendering with relative-URL resolution.
class SlideMarkdown extends StatelessWidget {
  const SlideMarkdown(
    this.data, {
    super.key,
    this.paragraphStyle,
    this.selectable = false,
    this.resolveUrl,
  });

  final String data;
  final TextStyle? paragraphStyle;
  final bool selectable;

  /// Converts a raw URL string (possibly relative) to an absolute URL.
  final String? Function(String?)? resolveUrl;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: selectable,
      imageBuilder: (uri, title, alt) {
        final resolved = resolveUrl?.call(uri.toString()) ?? uri.toString();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              resolved,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        );
      },
      onTapLink: (text, href, title) async {
        if (href == null || href.isEmpty) return;
        final resolved = resolveUrl?.call(href) ?? href;
        final uri = Uri.tryParse(resolved);
        if (uri != null) await launchUrl(uri);
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: paragraphStyle ??
            TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.55),
      ),
    );
  }
}
