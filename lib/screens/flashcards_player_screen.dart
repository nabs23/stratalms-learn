import 'dart:math' as math;
import 'package:flutter/material.dart';

class FlashcardsPlayerScreen extends StatefulWidget {
  const FlashcardsPlayerScreen({
    super.key,
    required this.activityTitle,
    required this.flashcards,
  });

  final String activityTitle;
  final List<Map<String, dynamic>> flashcards;

  @override
  State<FlashcardsPlayerScreen> createState() => _FlashcardsPlayerScreenState();
}

class _FlashcardsPlayerScreenState extends State<FlashcardsPlayerScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isAnimating = false;

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
    _flipAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _currentCard => widget.flashcards[_currentIndex];

  bool get _isFirst => _currentIndex == 0;
  bool get _isLast => _currentIndex == widget.flashcards.length - 1;

  void _flip() {
    if (_isAnimating) return;

    setState(() {
      _isAnimating = true;
      _isFlipped = !_isFlipped;
    });

    if (_isFlipped) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  void _goTo(int index) {
    if (_isAnimating) return;

    _flipController.reset();
    setState(() {
      _currentIndex = index;
      _isFlipped = false;
      _isAnimating = false;
    });
  }

  void _goPrevious() {
    if (!_isFirst) _goTo(_currentIndex - 1);
  }

  void _goNext() {
    if (!_isLast) _goTo(_currentIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.activityTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Text(
              '${_currentIndex + 1} / ${widget.flashcards.length}',
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
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: GestureDetector(
                onTap: _flip,
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final angle = _flipAnimation.value * math.pi;
                    final showFront = angle < math.pi / 2;

                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      alignment: Alignment.center,
                      child: Transform(
                        transform: Matrix4.identity()
                          ..rotateY(showFront ? 0 : -math.pi),
                        alignment: Alignment.center,
                        child: _buildCard(showFront),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildCard(bool showFront) {
    final question = _currentCard['question']?.toString() ?? '';
    final answer = _currentCard['answer']?.toString() ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: showFront
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              showFront ? 'Question' : 'Answer',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: showFront
                    ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)
                    : Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              showFront ? question : answer,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: showFront
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              showFront ? 'Tap to reveal answer' : 'Tap to show question',
              style: TextStyle(
                fontSize: 12,
                color: showFront
                    ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4)
                    : Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isFirst || _isAnimating ? null : _goPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Previous'),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _isAnimating ? null : _flip,
              icon: const Icon(Icons.flip_rounded),
              label: Text(_isFlipped ? 'Show Question' : 'Reveal Answer'),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _isLast || _isAnimating ? null : _goNext,
              label: const Text('Next'),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
