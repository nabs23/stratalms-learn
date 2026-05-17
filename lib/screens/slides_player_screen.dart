import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../utils/responsive.dart';

enum _ImageFitMode { cover, contain, fill }

class SlidesPlayerScreen extends StatefulWidget {
  const SlidesPlayerScreen({
    super.key,
    required this.activityTitle,
    required this.slides,
  });

  final String activityTitle;
  final List<Map<String, dynamic>> slides;

  @override
  State<SlidesPlayerScreen> createState() => _SlidesPlayerScreenState();
}

class _SlidesPlayerScreenState extends State<SlidesPlayerScreen>
    with SingleTickerProviderStateMixin {
  late final List<Map<String, dynamic>> _orderedSlides;
  late final PageController _pageController;
  int _currentIndex = 0;
  final Set<int> _revealedAnswers = {};
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isAudioPlaying = false;
  bool _autoAdvanceOnAudioEnd = false;
  bool _isAudioEnabled = true;
  bool _showScript = false;
  _ImageFitMode _imageFitMode = _ImageFitMode.contain;

  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;

  late final AnimationController _slideAnimController;

  static const _primaryColor = Color(0xFF6366F1);
  static const _surfaceColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _orderedSlides = List<Map<String, dynamic>>.from(widget.slides)
      ..sort(
        (a, b) =>
            ((a['order'] ?? 0) as int).compareTo((b['order'] ?? 0) as int),
      );

    _pageController = PageController();

    _slideAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isAudioPlaying = state.playing);

      if (state.processingState == ProcessingState.completed) {
        if (_autoAdvanceOnAudioEnd && _isAudioEnabled && !_isLast) {
          Future<void>.delayed(const Duration(seconds: 2), () {
            if (!mounted || _isLast) return;
            _goTo(_currentIndex + 1);
          });
        }
      }
    });

    _audioPlayer.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _audioPosition = position);
    });

    _audioPlayer.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() => _audioDuration = duration ?? Duration.zero);
    });

    _syncAudioForCurrentSlide(autoplay: _isAudioEnabled);
  }

  Map<String, dynamic> get _currentSlide => _orderedSlides[_currentIndex];
  String? get _currentAudioUrl => _currentSlide['audio_url']?.toString();
  bool get _hasAudio => (_currentAudioUrl ?? '').isNotEmpty;
  bool get _isFirst => _currentIndex == 0;
  bool get _isLast => _currentIndex == _orderedSlides.length - 1;

  String? get _slideImageUrl {
    final raw = _currentSlide['image_url']?.toString();
    return _resolveUrl(raw);
  }

  bool get _hasImage {
    final url = _slideImageUrl;
    return url != null && url.isNotEmpty;
  }

  Future<void> _syncAudioForCurrentSlide({required bool autoplay}) async {
    final audioUrl = _resolveUrl(_currentAudioUrl);

    await _audioPlayer.stop();
    _audioPosition = Duration.zero;
    _audioDuration = Duration.zero;

    if (!autoplay || audioUrl == null || audioUrl.isEmpty) {
      if (mounted) setState(() => _isAudioPlaying = false);
      return;
    }

    try {
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAudioPlaying = false);
    }
  }

  Future<void> _toggleAudioEnabled() async {
    setState(() => _isAudioEnabled = !_isAudioEnabled);

    if (!_isAudioEnabled) {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
          _audioPosition = Duration.zero;
        });
      }
      return;
    }

    await _syncAudioForCurrentSlide(autoplay: true);
  }

  Future<void> _togglePlayPause() async {
    if (!_hasAudio || !_isAudioEnabled) return;

    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
      return;
    }

    if (_audioPlayer.audioSource == null) {
      final audioUrl = _resolveUrl(_currentAudioUrl);
      if (audioUrl == null || audioUrl.isEmpty) return;
      await _audioPlayer.setUrl(audioUrl);
    }

    await _audioPlayer.play();
  }

  void _cycleImageFitMode() {
    setState(() {
      _imageFitMode = switch (_imageFitMode) {
        _ImageFitMode.cover => _ImageFitMode.contain,
        _ImageFitMode.contain => _ImageFitMode.fill,
        _ImageFitMode.fill => _ImageFitMode.cover,
      };
    });
  }

  BoxFit get _imageFit => switch (_imageFitMode) {
    _ImageFitMode.cover => BoxFit.cover,
    _ImageFitMode.contain => BoxFit.contain,
    _ImageFitMode.fill => BoxFit.fill,
  };

  String _durationLabel(Duration value) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60);
    final s = value.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String? _resolveUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) return trimmed;
    final base = Uri.parse(AppConstants.baseUrl);
    if (trimmed.startsWith('//')) return '${base.scheme}:$trimmed';
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return base.resolve(path).toString();
  }

  Future<void> _openMarkdownLink(String href) async {
    final resolved = _resolveUrl(href) ?? href;
    final uri = Uri.tryParse(resolved);
    if (uri == null) return;
    await launchUrl(uri);
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= _orderedSlides.length) return;

    HapticFeedback.lightImpact();

    setState(() {
      _currentIndex = index;
      _revealedAnswers.clear();
      _imageFitMode = _ImageFitMode.contain;
      _showScript = false;
    });

    _slideAnimController
      ..reset()
      ..forward();

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );

    await _syncAudioForCurrentSlide(autoplay: _isAudioEnabled);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pageController.dispose();
    _slideAnimController.dispose();
    super.dispose();
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final progress = (_currentIndex + 1) / _orderedSlides.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(progress),
            Expanded(
              child: isTablet ? _buildTabletLayout() : _buildPhoneLayout(),
            ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(double progress) {
    return Container(
      color: _surfaceColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.activityTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1B4B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Slide ${_currentIndex + 1} of ${_orderedSlides.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildHeaderActions(),
              ],
            ),
          ),
          _buildProgressBar(progress),
        ],
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasAudio) ...[
          _HeaderIconButton(
            icon: _isAudioEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            active: _isAudioEnabled,
            onTap: _toggleAudioEnabled,
            tooltip: _isAudioEnabled ? 'Mute audio' : 'Unmute audio',
          ),
          const SizedBox(width: 4),
          _HeaderIconButton(
            icon: _isAudioPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            active: _isAudioEnabled,
            onTap: _isAudioEnabled ? _togglePlayPause : null,
            tooltip: _isAudioPlaying ? 'Pause' : 'Play',
          ),
          const SizedBox(width: 4),
          _HeaderIconButton(
            icon: Icons.fast_forward_rounded,
            active: _autoAdvanceOnAudioEnd,
            onTap: _isAudioEnabled
                ? () => setState(
                      () => _autoAdvanceOnAudioEnd = !_autoAdvanceOnAudioEnd,
                    )
                : null,
            tooltip: _autoAdvanceOnAudioEnd
                ? 'Disable auto-advance'
                : 'Auto-advance',
          ),
        ],
        if (_hasImage) ...[
          const SizedBox(width: 4),
          _HeaderIconButton(
            icon: Icons.fit_screen_rounded,
            active: false,
            onTap: _cycleImageFitMode,
            tooltip: 'Cycle image fit',
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar(double progress) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return LinearProgressIndicator(
          value: value,
          minHeight: 3,
          backgroundColor: const Color(0xFFE8E8F0),
          valueColor: const AlwaysStoppedAnimation<Color>(_primaryColor),
        );
      },
    );
  }

  // ─── Layouts ────────────────────────────────────────────────────────────────

  Widget _buildPhoneLayout() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _orderedSlides.length,
            itemBuilder: (context, index) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 40,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [_buildSlideContent(_orderedSlides[index])],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        _buildAudioPanel(),
      ],
    );
  }

  Widget _buildTabletLayout() {
    final slide = _currentSlide;
    final type = slide['slide_type']?.toString() ?? 'TITLE_CARD';
    final imageUrl = _slideImageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    if (type == 'TEXT_AND_IMAGE' && hasImage) {
      return Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 10, 8),
                    child: _buildImageCard(imageUrl),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(10, 20, 20, 8),
                    child: _buildTextAndImageContent(slide),
                  ),
                ),
              ],
            ),
          ),
          _buildAudioPanel(),
        ],
      );
    }

    // Other slide types: constrained full-width
    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: _buildSlideContent(slide),
              ),
            ),
          ),
        ),
        _buildAudioPanel(),
      ],
    );
  }

  // ─── Slide Content ──────────────────────────────────────────────────────────

  Widget _buildSlideContent(Map<String, dynamic> slide) {
    final type = slide['slide_type']?.toString() ?? 'TITLE_CARD';
    final imageUrl = _resolveUrl(slide['image_url']?.toString());
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    if (type == 'TEXT_AND_IMAGE') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasImage) ...[
            _buildImageCard(imageUrl),
            const SizedBox(height: 16),
          ],
          _buildTextAndImageContent(slide),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasImage) ...[
          _buildImageCard(imageUrl),
          const SizedBox(height: 16),
        ],
        switch (type) {
          'TITLE_CARD' => _buildTitleCard(slide),
          'MULTIPLE_CHOICE_QUIZ' => _buildMultipleChoice(slide),
          'SUMMARY' => _buildSummary(slide),
          _ => _buildTitleCard(slide),
        },
      ],
    );
  }

  Widget _buildImageCard(String imageUrl) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFFEEEEF8),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            imageUrl,
            fit: _imageFit,
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
                    color: _primaryColor,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTitleCard(Map<String, dynamic> slide) {
    final title = slide['title_card_title']?.toString().trim();
    final subtitle = slide['title_card_subtitle']?.toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title.isNotEmpty)
            _buildMarkdown(
              title,
              paragraphStyle: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1B4B),
                height: 1.25,
              ),
            ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildMarkdown(
              subtitle,
              paragraphStyle: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextAndImageContent(Map<String, dynamic> slide) {
    final title = slide['text_and_image_title']?.toString().trim();
    final text = slide['text_and_image_text']?.toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title.isNotEmpty) ...[
            _buildMarkdown(
              title,
              paragraphStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1B4B),
                height: 1.3,
              ),
            ),
            if (text != null && text.isNotEmpty) const SizedBox(height: 14),
          ],
          if (text != null && text.isNotEmpty)
            _buildMarkdown(
              text,
              selectable: true,
              paragraphStyle: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoice(Map<String, dynamic> slide) {
    final question =
        slide['multiple_choice_question']?.toString().trim() ?? '';
    final options = (slide['multiple_choice_options'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final explanation = slide['multiple_choice_explanation']?.toString();
    final isRevealed = _revealedAnswers.contains(_currentIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'QUIZ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _primaryColor,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMarkdown(
                question,
                paragraphStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E1B4B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              ...options.map((option) {
                final label = option['option']?.toString() ?? '';
                final isCorrect = option['is_correct'] == true;

                Color bgColor;
                Color borderColor;
                Color textColor;
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildMarkdown(
                            label,
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
              }),
              const SizedBox(height: 6),
              if (!isRevealed)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () =>
                        setState(() => _revealedAnswers.add(_currentIndex)),
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
                        child: _buildMarkdown(
                          explanation,
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

  Widget _buildSummary(Map<String, dynamic> slide) {
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
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null && title.isNotEmpty) ...[
                _buildMarkdown(
                  title,
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
                          color: _primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMarkdown(
                          point,
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

  // ─── Audio Panel ────────────────────────────────────────────────────────────

  Widget _buildAudioPanel() {
    final script = _currentSlide['script']?.toString();
    final hasScript = script != null && script.isNotEmpty;

    if (!_hasAudio && !hasScript) return const SizedBox.shrink();

    final durationMs = _audioDuration.inMilliseconds;
    final positionMs = _audioPosition.inMilliseconds;
    final sliderMax = durationMs <= 0 ? 1.0 : durationMs.toDouble();
    final sliderValue =
        positionMs.clamp(0, durationMs <= 0 ? 1 : durationMs).toDouble();
    final progressFraction =
        durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasAudio) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _isAudioEnabled ? _togglePlayPause : null,
                    child: Icon(
                      _isAudioPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      size: 36,
                      color: _isAudioEnabled
                          ? _primaryColor
                          : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                            activeTrackColor: _primaryColor,
                            inactiveTrackColor: const Color(0xFFE2E2F0),
                            thumbColor: _primaryColor,
                            overlayColor: _primaryColor.withOpacity(0.15),
                          ),
                          child: Slider(
                            value: sliderValue,
                            max: sliderMax,
                            onChanged: _isAudioEnabled && durationMs > 0
                                ? (v) => _audioPlayer.seek(
                                      Duration(milliseconds: v.round()),
                                    )
                                : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _durationLabel(_audioPosition),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                height: 3,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: progressFraction,
                                    backgroundColor: const Color(0xFFE2E2F0),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      _primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                _durationLabel(_audioDuration),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasScript) ...[
            InkWell(
              onTap: () => setState(() => _showScript = !_showScript),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, _hasAudio ? 10 : 12, 16, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 15,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showScript ? 'Hide script' : 'Show script',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showScript
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
            if (_showScript)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: _buildMarkdown(
                  script,
                  paragraphStyle: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey[700],
                    height: 1.55,
                  ),
                ),
              ),
          ] else
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ─── Bottom Bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      color: _surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.arrow_back_rounded,
            label: 'Prev',
            enabled: !_isFirst,
            onTap: () => _goTo(_currentIndex - 1),
          ),
          Expanded(child: _buildDotIndicator()),
          _NavButton(
            icon: Icons.arrow_forward_rounded,
            label: 'Next',
            enabled: !_isLast,
            isPrimary: true,
            onTap: () => _goTo(_currentIndex + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildDotIndicator() {
    final total = _orderedSlides.length;

    if (total > 11) {
      return Center(
        child: Text(
          '${_currentIndex + 1} / $total',
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
          children: List.generate(total, (i) {
            final active = i == _currentIndex;
            final near = (i - _currentIndex).abs() <= 2;
            return GestureDetector(
              onTap: () => _goTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 22 : (near ? 7 : 5),
                height: active ? 7 : (near ? 7 : 5),
                decoration: BoxDecoration(
                  color: active
                      ? _primaryColor
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

  // ─── Markdown ────────────────────────────────────────────────────────────────

  Widget _buildMarkdown(
    String data, {
    TextStyle? paragraphStyle,
    bool selectable = false,
  }) {
    return MarkdownBody(
      data: data,
      selectable: selectable,
      imageBuilder: (uri, title, alt) {
        final resolvedImageUrl = _resolveUrl(uri.toString());
        if (resolvedImageUrl == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              resolvedImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, error, __) {
                debugPrint('Markdown image error ($resolvedImageUrl): $error');
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
      onTapLink: (text, href, title) {
        if (href != null && href.isNotEmpty) _openMarkdownLink(href);
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: paragraphStyle ??
            TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.55),
      ),
    );
  }

  // ─── Decoration ─────────────────────────────────────────────────────────────

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _surfaceColor,
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
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
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
                ? const Color(0xFF6366F1).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active
                ? const Color(0xFF6366F1)
                : onTap != null
                    ? Colors.grey[600]
                    : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6366F1);
    final color = enabled
        ? (isPrimary ? primaryColor : const Color(0xFF374151))
        : Colors.grey[300]!;
    final bg = enabled
        ? (isPrimary
              ? primaryColor.withOpacity(0.08)
              : Colors.grey[100]!)
        : Colors.grey[50]!;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: isPrimary
              ? [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(icon, size: 16, color: color),
                ]
              : [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}
