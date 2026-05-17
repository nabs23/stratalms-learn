import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VideoViewerScreen extends StatefulWidget {
  const VideoViewerScreen({
    super.key,
    required this.activityTitle,
    required this.videoUrl,
  });

  final String activityTitle;
  final String videoUrl;

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  WebViewController? _controller;
  bool _isLoading = true;

  String? get _youTubeEmbedUrl {
    final regex = RegExp(
      r'(?:https?://)?(?:www\.)?(?:youtube\.com/(?:[^/\n\s]+/\S+/|(?:v|e(?:mbed)?)/'
      r'|\S*?[?&]v=)|youtu\.be/)([a-zA-Z0-9_-]{11})',
    );
    final match = regex.firstMatch(widget.videoUrl);
    return match != null ? 'https://www.youtube.com/embed/${match.group(1)}' : null;
  }

  bool get _isYouTube => _youTubeEmbedUrl != null;

  @override
  void initState() {
    super.initState();
    if (_isYouTube) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
          ),
        )
        ..loadRequest(Uri.parse(_youTubeEmbedUrl!));
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.activityTitle,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'Open externally',
            onPressed: _openExternally,
          ),
        ],
      ),
      body: _isYouTube ? _buildYouTubePlayer() : _buildExternalFallback(),
    );
  }

  Widget _buildYouTubePlayer() {
    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: WebViewWidget(controller: _controller!),
          ),
        ),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
      ],
    );
  }

  Widget _buildExternalFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline_rounded, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              'This video is hosted externally.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openExternally,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open Video'),
            ),
          ],
        ),
      ),
    );
  }
}
