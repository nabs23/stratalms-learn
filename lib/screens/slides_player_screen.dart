import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';

enum _ViewMode { both, text, image }

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

class _SlidesPlayerScreenState extends State<SlidesPlayerScreen> {
  late final List<Map<String, dynamic>> _orderedSlides;
  int _currentIndex = 0;
  final Set<int> _revealedAnswers = {};
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isAudioPlaying = false;
  bool _autoAdvanceOnAudioEnd = false;
  bool _isAudioEnabled = true;
  _ViewMode _viewMode = _ViewMode.both;
  _ImageFitMode _imageFitMode = _ImageFitMode.contain;

  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _orderedSlides = List<Map<String, dynamic>>.from(widget.slides)
      ..sort((a, b) => ((a['order'] ?? 0) as int).compareTo((b['order'] ?? 0) as int));

    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAudioPlaying = state.playing;
      });

      if (state.processingState == ProcessingState.completed) {
        if (_autoAdvanceOnAudioEnd && _isAudioEnabled && !_isLast) {
          Future<void>.delayed(const Duration(seconds: 3), () {
            if (!mounted || _isLast) {
              return;
            }

            _goTo(_currentIndex + 1);
          });
        }
      }
    });

    _audioPlayer.positionStream.listen((position) {
      if (!mounted) {
        return;
      }

      setState(() {
        _audioPosition = position;
      });
    });

    _audioPlayer.durationStream.listen((duration) {
      if (!mounted) {
        return;
      }

      setState(() {
        _audioDuration = duration ?? Duration.zero;
      });
    });

    _syncAudioForCurrentSlide(autoplay: _isAudioEnabled);
  }

  Map<String, dynamic> get _currentSlide => _orderedSlides[_currentIndex];
  String? get _currentAudioUrl => _currentSlide['audio_url']?.toString();
  bool get _hasAudio => (_currentAudioUrl ?? '').isNotEmpty;
  bool get _canToggleViewMode =>
      (_currentSlide['slide_type']?.toString() == 'TEXT_AND_IMAGE') &&
      ((_currentSlide['image_url']?.toString() ?? '').isNotEmpty);
  bool get _canToggleImageFit => _canToggleViewMode;

  bool get _isFirst => _currentIndex == 0;
  bool get _isLast => _currentIndex == _orderedSlides.length - 1;

  Future<void> _syncAudioForCurrentSlide({required bool autoplay}) async {
    final audioUrl = _resolveUrl(_currentAudioUrl);

    await _audioPlayer.stop();
    _audioPosition = Duration.zero;
    _audioDuration = Duration.zero;

    if (!autoplay || audioUrl == null || audioUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
        });
      }

      return;
    }

    try {
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAudioPlaying = false;
      });
    }
  }

  Future<void> _toggleAudioEnabled() async {
    setState(() {
      _isAudioEnabled = !_isAudioEnabled;
    });

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

  Future<void> _togglePlayPauseAudio() async {
    if (!_hasAudio || !_isAudioEnabled) {
      return;
    }

    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
      return;
    }

    if (_audioPlayer.audioSource == null) {
      final audioUrl = _resolveUrl(_currentAudioUrl);

      if (audioUrl == null || audioUrl.isEmpty) {
        return;
      }

      await _audioPlayer.setUrl(audioUrl);
    }

    await _audioPlayer.play();
  }

  void _cycleViewMode() {
    if (!_canToggleViewMode) {
      return;
    }

    setState(() {
      if (_viewMode == _ViewMode.both) {
        _viewMode = _ViewMode.text;
        return;
      }

      if (_viewMode == _ViewMode.text) {
        _viewMode = _ViewMode.image;
        return;
      }

      _viewMode = _ViewMode.both;
    });
  }

  void _cycleImageFitMode() {
    if (!_canToggleImageFit) {
      return;
    }

    setState(() {
      if (_imageFitMode == _ImageFitMode.cover) {
        _imageFitMode = _ImageFitMode.contain;
        return;
      }

      if (_imageFitMode == _ImageFitMode.contain) {
        _imageFitMode = _ImageFitMode.fill;
        return;
      }

      _imageFitMode = _ImageFitMode.cover;
    });
  }

  IconData get _viewModeIcon {
    if (_viewMode == _ViewMode.text) {
      return Icons.text_fields_rounded;
    }

    if (_viewMode == _ViewMode.image) {
      return Icons.image_rounded;
    }

    return Icons.view_sidebar_rounded;
  }

  BoxFit get _imageFit {
    switch (_imageFitMode) {
      case _ImageFitMode.cover:
        return BoxFit.cover;
      case _ImageFitMode.contain:
        return BoxFit.contain;
      case _ImageFitMode.fill:
        return BoxFit.fill;
    }
  }

  String _durationLabel(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String? _resolveUrl(String? rawUrl) {
    if (rawUrl == null) {
      return null;
    }

    final trimmed = rawUrl.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(trimmed);

    if (parsed != null && parsed.hasScheme) {
      return trimmed;
    }

    final base = Uri.parse(AppConstants.baseUrl);

    if (trimmed.startsWith('//')) {
      return '${base.scheme}:$trimmed';
    }

    final normalizedPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';

    return base.resolve(normalizedPath).toString();
  }

  Future<void> _openMarkdownLink(String href) async {
    final resolved = _resolveUrl(href) ?? href;
    final uri = Uri.tryParse(resolved);

    if (uri == null) {
      return;
    }

    await launchUrl(uri);
  }

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

        if (resolvedImageUrl == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              resolvedImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) {
                debugPrint('Image load error ($resolvedImageUrl): $error');
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      },
      onTapLink: (text, href, title) {
        if (href != null && href.isNotEmpty) {
          _openMarkdownLink(href);
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: paragraphStyle ??
            TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
              height: 1.5,
            ),
      ),
    );
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= _orderedSlides.length) {
      return;
    }

    setState(() {
      _currentIndex = index;
      _revealedAnswers.clear();
      _viewMode = _ViewMode.both;
      _imageFitMode = _ImageFitMode.contain;
    });

    await _syncAudioForCurrentSlide(autoplay: _isAudioEnabled);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.activityTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Text(
              '${_currentIndex + 1} / ${_orderedSlides.length}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _orderedSlides.length,
            backgroundColor: Colors.grey[200],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildSlideContent(_currentSlide),
            ),
          ),
          _buildAudioPanel(),
          _buildNavigation(context),
        ],
      ),
    );
  }

  Widget _buildSlideContent(Map<String, dynamic> slide) {
    final type = slide['slide_type']?.toString() ?? 'TITLE_CARD';
    final imageUrl = _resolveUrl(slide['image_url']?.toString());

    if (type == 'TEXT_AND_IMAGE') {
      return _buildTextAndImage(slide);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty)
          Container(
            height: 280,
            width: double.infinity,
            decoration: _cardDecoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) {
                  debugPrint('Slide image load error ($imageUrl): $error');
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        if (imageUrl != null && imageUrl.isNotEmpty)
          const SizedBox(height: 20),
        switch (type) {
          'TITLE_CARD' => _buildTitleCard(slide),
          'MULTIPLE_CHOICE_QUIZ' => _buildMultipleChoice(slide),
          'SUMMARY' => _buildSummary(slide),
          _ => _buildTitleCard(slide),
        },
      ],
    );
  }

  Widget _buildTitleCard(Map<String, dynamic> slide) {
    final title = slide['title_card_title']?.toString().trim();
    final subtitle = slide['title_card_subtitle']?.toString().trim();

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          if (title != null && title.isNotEmpty)
            _buildMarkdown(
              title,
              paragraphStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.2),
            ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildMarkdown(
              subtitle,
              paragraphStyle: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextAndImage(Map<String, dynamic> slide) {
    final title = slide['text_and_image_title']?.toString().trim();
    final text = slide['text_and_image_text']?.toString().trim();
    final imageUrl = _resolveUrl(slide['image_url']?.toString());
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final showImage = hasImage && (_viewMode == _ViewMode.both || _viewMode == _ViewMode.image);
    final showText = _viewMode == _ViewMode.both || _viewMode == _ViewMode.text;

    return Column(
      children: [
        if (showImage)
          Container(
            height: 280,
            width: double.infinity,
            decoration: _cardDecoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: _imageFit,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        if (showImage && showText)
          const SizedBox(height: 16),
        if (showText)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title.isNotEmpty)
                  _buildMarkdown(
                    title,
                    paragraphStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
                  ),
                if (text != null && text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildMarkdown(
                    text,
                    selectable: true,
                    paragraphStyle: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAudioPanel() {
    final script = _currentSlide['script']?.toString();

    if (!_hasAudio && (script == null || script.isEmpty)) {
      return const SizedBox.shrink();
    }

    final durationMs = _audioDuration.inMilliseconds;
    final positionMs = _audioPosition.inMilliseconds;
    final sliderMax = durationMs <= 0 ? 1.0 : durationMs.toDouble();
    final sliderValue = positionMs.clamp(0, durationMs <= 0 ? 1 : durationMs).toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasAudio) ...[
            Row(
              children: [
                const Icon(Icons.graphic_eq_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: sliderValue,
                    max: sliderMax,
                    onChanged: _isAudioEnabled && durationMs > 0
                        ? (value) {
                            _audioPlayer.seek(Duration(milliseconds: value.round()));
                          }
                        : null,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_durationLabel(_audioPosition), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(_durationLabel(_audioDuration), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
          if (script != null && script.isNotEmpty) ...[
            if (_hasAudio)
              const SizedBox(height: 8),
            _buildMarkdown(
              script,
              paragraphStyle: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.45),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultipleChoice(Map<String, dynamic> slide) {
    final question = slide['multiple_choice_question']?.toString().trim() ?? '';
    final options = (slide['multiple_choice_options'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final explanation = slide['multiple_choice_explanation']?.toString();
    final isRevealed = _revealedAnswers.contains(_currentIndex);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMarkdown(
            question,
            paragraphStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 16),
          ...options.asMap().entries.map((entry) {
            final option = entry.value;
            final label = option['option']?.toString() ?? '';
            final isCorrect = option['is_correct'] == true;
            Color? bgColor;
            Color? borderColor;
            if (isRevealed) {
              bgColor = isCorrect ? Colors.green[50] : Colors.red[50];
              borderColor = isCorrect ? Colors.green[300] : Colors.red[200];
            } else {
              bgColor = Colors.grey[100];
              borderColor = Colors.grey[300];
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMarkdown(
                        label,
                        paragraphStyle: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                    if (isRevealed)
                      Icon(
                        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 18,
                        color: isCorrect ? Colors.green[600] : Colors.red[400],
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          if (!isRevealed)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() => _revealedAnswers.add(_currentIndex)),
                child: const Text('Reveal Answer'),
              ),
            ),
          if (isRevealed && explanation != null && explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMarkdown(
                      explanation,
                      paragraphStyle: TextStyle(fontSize: 13, color: Colors.blue[900], height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary(Map<String, dynamic> slide) {
    final title = slide['summary_title']?.toString().trim();
    final points = (slide['summary_points'] as List<dynamic>? ?? [])
        .map((p) => p.toString())
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title.isNotEmpty)
            _buildMarkdown(
              title,
              paragraphStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...points.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMarkdown(
                        point,
                        paragraphStyle: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.withOpacity(0.16)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildNavigation(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton.outlined(
                  onPressed: _isFirst ? null : () => _goTo(_currentIndex - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Previous',
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_orderedSlides.length, (i) {
                      final active = i == _currentIndex;
                      return GestureDetector(
                        onTap: () => _goTo(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                IconButton.outlined(
                  onPressed: _isLast ? null : () => _goTo(_currentIndex + 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Next',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  onPressed: _hasAudio ? _toggleAudioEnabled : null,
                  icon: Icon(
                    _isAudioEnabled ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  ),
                  tooltip: _isAudioEnabled ? 'Disable audio' : 'Enable audio',
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  onPressed: (_hasAudio && _isAudioEnabled) ? _togglePlayPauseAudio : null,
                  icon: Icon(_isAudioPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  tooltip: _isAudioPlaying ? 'Pause' : 'Play',
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  onPressed: _canToggleViewMode ? _cycleViewMode : null,
                  icon: Icon(_viewModeIcon),
                  tooltip: 'Cycle view mode',
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  onPressed: _canToggleImageFit ? _cycleImageFitMode : null,
                  icon: const Icon(Icons.fit_screen_rounded),
                  tooltip: 'Cycle image fit',
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  onPressed: (_hasAudio && _isAudioEnabled)
                      ? () => setState(() => _autoAdvanceOnAudioEnd = !_autoAdvanceOnAudioEnd)
                      : null,
                  icon: Icon(
                    Icons.fast_forward_rounded,
                    color: _autoAdvanceOnAudioEnd ? Theme.of(context).colorScheme.primary : null,
                  ),
                  tooltip: _autoAdvanceOnAudioEnd
                      ? 'Disable auto next on audio end'
                      : 'Enable auto next on audio end',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
