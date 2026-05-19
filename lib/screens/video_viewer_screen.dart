import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

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
  WebViewController? _webViewController;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
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

  String? get _muxPlaybackId {
    if (widget.videoUrl.startsWith('mux://')) {
      final cleanUrl = widget.videoUrl.replaceFirst('mux://', '');
      return cleanUrl.split('?').first;
    }
    return null;
  }

  bool get _isMux => _muxPlaybackId != null;

  @override
  void initState() {
    super.initState();
    if (_isYouTube) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
          ),
        )
        ..loadRequest(Uri.parse(_youTubeEmbedUrl!));
    } else if (_isMux) {
      _initVideoPlayer('https://stream.mux.com/$_muxPlaybackId.m3u8');
    } else if (widget.videoUrl.startsWith('http')) {
      _initVideoPlayer(widget.videoUrl);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initVideoPlayer(String url) async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await _videoPlayerController!.initialize();
      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Video Player Initialization Error: $e');
      // Allow fallback if initialization fails
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(
      _isMux ? 'https://stream.mux.com/$_muxPlaybackId.m3u8' : widget.videoUrl,
    );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isYouTube) {
      return _buildYouTubePlayer();
    }
    
    if (_chewieController != null) {
      return _buildChewiePlayer();
    }
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return _buildExternalFallback();
  }

  Widget _buildYouTubePlayer() {
    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: WebViewWidget(controller: _webViewController!),
          ),
        ),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
      ],
    );
  }

  Widget _buildChewiePlayer() {
    return Center(
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _buildExternalFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_outline_rounded, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            const Text(
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
