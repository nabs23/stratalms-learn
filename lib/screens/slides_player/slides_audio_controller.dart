import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Owns the [AudioPlayer] and exposes reactive state via [ChangeNotifier].
/// The screen is responsible for resolving audio URLs before passing them in.
class SlidesAudioController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool _isEnabled = true;
  bool _autoAdvance = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _loadedUrl;
  int _syncId = 0;

  bool get isPlaying => _isPlaying;
  bool get isEnabled => _isEnabled;
  bool get autoAdvance => _autoAdvance;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get loadedUrl => _loadedUrl;

  /// Called when the current audio track finishes naturally.
  VoidCallback? onCompleted;

  SlidesAudioController() {
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
      if (state.processingState == ProcessingState.completed) {
        onCompleted?.call();
      }
    });

    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });
  }

  /// Switches to [audioUrl] for the current slide.
  ///
  /// Immediately resets all playback state so stale position/duration from
  /// the previous slide cannot bleed through, then loads and optionally plays
  /// the new URL if [autoplay] is true.
  Future<void> syncForSlide(String? audioUrl, {required bool autoplay}) async {
    final syncId = ++_syncId;

    _loadedUrl = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();

    try {
      await _player.stop();
      await _player.seek(Duration.zero);
    } catch (_) {}

    if (!autoplay || audioUrl == null || audioUrl.isEmpty) return;

    if (syncId != _syncId) return; // navigated away while waiting

    try {
      await _player.setUrl(audioUrl);
      if (syncId != _syncId) return;
      _loadedUrl = audioUrl;
      await _player.play();
    } catch (_) {
      if (syncId == _syncId) {
        _isPlaying = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleEnabled(String? audioUrl) async {
    _isEnabled = !_isEnabled;
    notifyListeners();

    if (!_isEnabled) {
      await _player.stop();
      _isPlaying = false;
      _position = Duration.zero;
      notifyListeners();
      return;
    }

    await syncForSlide(audioUrl, autoplay: true);
  }

  Future<void> togglePlayPause(String? audioUrl) async {
    if (!_isEnabled || audioUrl == null || audioUrl.isEmpty) return;

    if (_loadedUrl != audioUrl) {
      // Different URL than what's loaded — hard-reset then load the new one.
      try {
        await _player.stop();
        await _player.seek(Duration.zero);
      } catch (_) {}
      
      try {
        await _player.setUrl(audioUrl);
        _loadedUrl = audioUrl;
      } catch (_) {
        return;
      }
    }

    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seekTo(Duration position) => _player.seek(position);

  void toggleAutoAdvance() {
    _autoAdvance = !_autoAdvance;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
