import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _orderedSlides = List<Map<String, dynamic>>.from(widget.slides)
      ..sort((a, b) => ((a['order'] ?? 0) as int).compareTo((b['order'] ?? 0) as int));
  }

  Map<String, dynamic> get _currentSlide => _orderedSlides[_currentIndex];

  bool get _isFirst => _currentIndex == 0;
  bool get _isLast => _currentIndex == _orderedSlides.length - 1;

  void _goTo(int index) {
    setState(() {
      _currentIndex = index;
      _revealedAnswers.clear();
    });
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
          _buildNavigation(context),
        ],
      ),
    );
  }

  Widget _buildSlideContent(Map<String, dynamic> slide) {
    final type = slide['slide_type']?.toString() ?? 'TITLE_CARD';
    final imageUrl = slide['image_url']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        if (imageUrl != null && imageUrl.isNotEmpty)
          const SizedBox(height: 20),
        switch (type) {
          'TITLE_CARD' => _buildTitleCard(slide),
          'TEXT_AND_IMAGE' => _buildTextAndImage(slide),
          'MULTIPLE_CHOICE_QUIZ' => _buildMultipleChoice(slide),
          'SUMMARY' => _buildSummary(slide),
          _ => _buildTitleCard(slide),
        },
      ],
    );
  }

  Widget _buildTitleCard(Map<String, dynamic> slide) {
    final title = slide['title_card_title']?.toString();
    final subtitle = slide['title_card_subtitle']?.toString();

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          if (title != null && title.isNotEmpty)
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.2),
            ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextAndImage(Map<String, dynamic> slide) {
    final title = slide['text_and_image_title']?.toString();
    final text = slide['text_and_image_text']?.toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
            ),
          if (text != null && text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultipleChoice(Map<String, dynamic> slide) {
    final question = slide['multiple_choice_question']?.toString() ?? '';
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
          Text(
            question,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
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
                      child: Text(label, style: const TextStyle(fontSize: 14, height: 1.4)),
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
                    child: Text(
                      explanation,
                      style: TextStyle(fontSize: 13, color: Colors.blue[900], height: 1.4),
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
    final title = slide['summary_title']?.toString();
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
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
                      child: Text(
                        point,
                        style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5),
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
        child: Row(
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
      ),
    );
  }
}
