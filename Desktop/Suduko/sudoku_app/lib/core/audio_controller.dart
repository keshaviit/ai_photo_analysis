import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioController {
  static final AudioController instance = AudioController._internal();

  final AudioPlayer _clickPlayer = AudioPlayer();
  final AudioPlayer _placePlayer = AudioPlayer();
  final AudioPlayer _errorPlayer = AudioPlayer();
  final AudioPlayer _victoryPlayer = AudioPlayer();
  final AudioPlayer _mascotEntrancePlayer = AudioPlayer();
  final AudioPlayer _mascotLandingPlayer = AudioPlayer();
  final AudioPlayer _mascotTapPlayer = AudioPlayer();
  final AudioPlayer _mascotStreakPlayer = AudioPlayer();
  final AudioPlayer _mascotBubblePlayer = AudioPlayer();

  bool _isSoundEnabled = true;
  late final Future<void> _initFuture;

  bool get isSoundEnabled => _isSoundEnabled;

  AudioController._internal() {
    _initFuture = _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isSoundEnabled = prefs.getBool('sound_enabled') ?? true;

    await Future.wait([
      _clickPlayer.setAsset('assets/audio/click.wav'),
      _placePlayer.setAsset('assets/audio/place.wav'),
      _errorPlayer.setAsset('assets/audio/error.wav'),
      _victoryPlayer.setAsset('assets/audio/victory.wav'),
      _mascotEntrancePlayer.setAsset('assets/audio/place.wav'),
      _mascotLandingPlayer.setAsset('assets/audio/click.wav'),
      _mascotTapPlayer.setAsset('assets/audio/click.wav'),
      _mascotStreakPlayer.setAsset('assets/audio/victory.wav'),
      _mascotBubblePlayer.setAsset('assets/audio/click.wav'),
    ]);

    await Future.wait([
      _mascotEntrancePlayer.setVolume(0.45),
      _mascotLandingPlayer.setVolume(0.7),
      _mascotTapPlayer.setVolume(0.75),
      _mascotStreakPlayer.setVolume(0.8),
      _mascotBubblePlayer.setVolume(0.35),
    ]);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _isSoundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', enabled);
  }

  Future<void> playClick() async {
    if (!_isSoundEnabled) return;
    HapticFeedback.lightImpact();
    await _play(_clickPlayer);
  }

  Future<void> playPlace() async {
    if (!_isSoundEnabled) return;
    HapticFeedback.mediumImpact();
    await _play(_placePlayer);
  }

  Future<void> playError() async {
    if (!_isSoundEnabled) return;
    HapticFeedback.heavyImpact();
    await _play(_errorPlayer);
  }

  Future<void> playVictory() async {
    if (!_isSoundEnabled) return;
    HapticFeedback.heavyImpact();
    await _play(_victoryPlayer);
  }

  Future<void> playMascotEntrance() async {
    if (!_isSoundEnabled) return;
    await _play(_mascotEntrancePlayer);
  }

  Future<void> playMascotLanding() async {
    if (!_isSoundEnabled) return;
    HapticFeedback.lightImpact();
    await _play(_mascotLandingPlayer);
  }

  Future<void> playMascotTap() async {
    if (!_isSoundEnabled) return;
    HapticFeedback.selectionClick();
    await _play(_mascotTapPlayer);
  }

  Future<void> playMascotStreak() async {
    if (!_isSoundEnabled) return;
    HapticFeedback.mediumImpact();
    await _play(_mascotStreakPlayer);
  }

  Future<void> playMascotBubble() async {
    if (!_isSoundEnabled) return;
    await _play(_mascotBubblePlayer);
  }

  Future<void> _play(AudioPlayer player) async {
    try {
      await _initFuture;
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {
      // Audio should never interrupt gameplay if an asset is unavailable.
    }
  }
}
