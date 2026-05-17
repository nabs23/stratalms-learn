import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_constants.dart';
import '../../utils/responsive.dart';
import 'slides_audio_controller.dart';
import 'slides_player_constants.dart';
import 'widgets/slide_content.dart';
import 'widgets/slide_types/slide_image_card.dart';
import 'widgets/slide_types/slide_text_and_image.dart';
import 'widgets/slides_audio_panel.dart';
import 'widgets/slides_bottom_bar.dart';
import 'widgets/slides_header.dart';

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
  // ─── Slide state ────────────────────────────────────────────────────────────

  late final List<Map<String, dynamic>> _orderedSlides;
  late final PageController _pageController;
  late final AnimationController _slideAnimController;

  int _currentIndex = 0;
  final Set<int> _revealedAnswers = {};
  _ImageFitMode _imageFitMode = _ImageFitMode.contain;

  // ─── Audio ──────────────────────────────────────────────────────────────────

  late final SlidesAudioController _audio;

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> get _currentSlide => _orderedSlides[_currentIndex];
  bool get _hasAudio => (_currentSlide['audio_url']?.toString() ?? '').isNotEmpty;
  bool get _hasImage {
    final url = _resolveUrl(_currentSlide['image_url']?.toString());
    return url != null && url.isNotEmpty;
  }
  bool get _isLast => _currentIndex == _orderedSlides.length - 1;

  BoxFit get _imageFit => switch (_imageFitMode) {
        _ImageFitMode.cover => BoxFit.cover,
        _ImageFitMode.contain => BoxFit.contain,
        _ImageFitMode.fill => BoxFit.fill,
      };

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

  String? get _currentAudioUrl =>
      _resolveUrl(_currentSlide['audio_url']?.toString());

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

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

    _audio = SlidesAudioController();
    _audio.onCompleted = _handleAudioCompleted;
    _audio.addListener(() {
      if (mounted) setState(() {});
    });

    _audio.syncForSlide(_currentAudioUrl, autoplay: true);
  }

  void _handleAudioCompleted() {
    if (_audio.autoAdvance && !_isLast) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isLast) _goTo(_currentIndex + 1);
      });
    }
  }

  @override
  void dispose() {
    _audio.dispose();
    _pageController.dispose();
    _slideAnimController.dispose();
    super.dispose();
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= _orderedSlides.length) return;
    HapticFeedback.lightImpact();

    setState(() {
      _currentIndex = index;
      _revealedAnswers.clear();
      _imageFitMode = _ImageFitMode.contain;
    });

    _slideAnimController
      ..reset()
      ..forward();

    unawaited(_pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    ));

    await _audio.syncForSlide(_currentAudioUrl, autoplay: _audio.isEnabled);
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIndex + 1) / _orderedSlides.length;

    return Scaffold(
      backgroundColor: kSlideBackground,
      body: SafeArea(
        child: Column(
          children: [
            SlidesHeader(
              activityTitle: widget.activityTitle,
              currentIndex: _currentIndex,
              totalSlides: _orderedSlides.length,
              progress: progress,
              hasAudio: _hasAudio,
              hasImage: _hasImage,
              isAudioEnabled: _audio.isEnabled,
              isAudioPlaying: _audio.isPlaying,
              autoAdvance: _audio.autoAdvance,
              onClose: () => Navigator.of(context).pop(),
              onToggleAudio: () =>
                  _audio.toggleEnabled(_currentAudioUrl),
              onTogglePlayPause: () =>
                  _audio.togglePlayPause(_currentAudioUrl),
              onToggleAutoAdvance: _audio.toggleAutoAdvance,
              onCycleImageFit: () => setState(() {
                _imageFitMode = switch (_imageFitMode) {
                  _ImageFitMode.cover => _ImageFitMode.contain,
                  _ImageFitMode.contain => _ImageFitMode.fill,
                  _ImageFitMode.fill => _ImageFitMode.cover,
                };
              }),
            ),
            Expanded(
              child: Responsive.isTablet(context)
                  ? _buildTabletLayout()
                  : _buildPhoneLayout(),
            ),
            SlidesBottomBar(
              currentIndex: _currentIndex,
              totalSlides: _orderedSlides.length,
              onPrev: () => _goTo(_currentIndex - 1),
              onNext: () => _goTo(_currentIndex + 1),
              onGoTo: _goTo,
            ),
          ],
        ),
      ),
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
                  final slide = _orderedSlides[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 40,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SlideContent(
                            slide: slide,
                            resolveUrl: _resolveUrl,
                            imageFit: _imageFit,
                            isRevealed: _revealedAnswers.contains(index),
                            onReveal: () =>
                                setState(() => _revealedAnswers.add(index)),
                          ),
                        ],
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
    final imageUrl = _resolveUrl(slide['image_url']?.toString());
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
                    child: SlideImageCard(
                      imageUrl: imageUrl,
                      imageFit: _imageFit,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(10, 20, 20, 8),
                    child: SlideTextAndImage(
                      slide: slide,
                      resolveUrl: _resolveUrl,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildAudioPanel(),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: SlideContent(
                  slide: slide,
                  resolveUrl: _resolveUrl,
                  imageFit: _imageFit,
                  isRevealed: _revealedAnswers.contains(_currentIndex),
                  onReveal: () =>
                      setState(() => _revealedAnswers.add(_currentIndex)),
                ),
              ),
            ),
          ),
        ),
        _buildAudioPanel(),
      ],
    );
  }

  Widget _buildAudioPanel() {
    return SlidesAudioPanel(
      audio: _audio,
      hasAudio: _hasAudio,
      script: _currentSlide['script']?.toString(),
      resolveUrl: _resolveUrl,
    );
  }
}
