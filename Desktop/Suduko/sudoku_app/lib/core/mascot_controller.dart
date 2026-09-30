import 'dart:async';

import 'package:flutter/foundation.dart';

enum MascotMood { idle, thinking, happy, mistake, hint, win }

extension MascotMoodAsset on MascotMood {
  String get assetPath {
    switch (this) {
      case MascotMood.idle:
        return 'assets/images/mascot/mascot_idle.png';
      case MascotMood.thinking:
        return 'assets/images/mascot/mascot_thinking.png';
      case MascotMood.happy:
        return 'assets/images/mascot/mascot_happy.png';
      case MascotMood.mistake:
        return 'assets/images/mascot/mascot_mistake.png';
      case MascotMood.hint:
        return 'assets/images/mascot/mascot_hint.png';
      case MascotMood.win:
        return 'assets/images/mascot/mascot_win.png';
    }
  }
}

class MascotController extends ChangeNotifier {
  MascotMood _mood = MascotMood.idle;
  bool _isCellSelected = false;
  Timer? _revertTimer;
  Timer? _speechTimer;
  bool _isLocked = false; // Locked on game won or game over
  int _streak = 0;
  String? _speechText = "Let's solve this!";

  MascotMood get mood => _mood;
  String get assetPath => _mood.assetPath;
  String? get speechText => _speechText;
  int get streak => _streak;

  void setMood(MascotMood newMood, {Duration? duration}) {
    if (_isLocked && newMood != MascotMood.idle) return;

    _revertTimer?.cancel();
    _revertTimer = null;
    _mood = newMood;
    notifyListeners();

    if (duration != null) {
      _revertTimer = Timer(duration, () {
        if (!_isLocked) {
          _mood = _isCellSelected ? MascotMood.thinking : MascotMood.idle;
          notifyListeners();
        }
      });
    }
  }

  void onCellSelected(bool isSelected) {
    _isCellSelected = isSelected;
    if (_revertTimer != null || _isLocked) return;

    final target = isSelected ? MascotMood.thinking : MascotMood.idle;
    if (_mood != target) {
      _mood = target;
      notifyListeners();
    }
  }

  void onCorrectMove({Duration duration = const Duration(milliseconds: 1400)}) {
    _streak++;
    _showSpeech(_streak >= 3 ? 'Streak x$_streak!' : 'Nice spot!');
    setMood(MascotMood.happy, duration: duration);
  }

  void onMistake({Duration duration = const Duration(milliseconds: 1800)}) {
    _streak = 0;
    _showSpeech('Oops, take your time!');
    setMood(MascotMood.mistake, duration: duration);
  }

  void onHintUsed({Duration duration = const Duration(milliseconds: 2200)}) {
    _showSpeech('Try this clue!');
    setMood(MascotMood.hint, duration: duration);
  }

  void onTapped() {
    _showSpeech(_tapMessages[_streak % _tapMessages.length]);
    setMood(MascotMood.happy, duration: const Duration(milliseconds: 900));
  }

  void dismissSpeech() {
    _speechTimer?.cancel();
    _speechTimer = null;
    _speechText = null;
    notifyListeners();
  }

  void onGameWon() {
    _revertTimer?.cancel();
    _revertTimer = null;
    _isLocked = true;
    _showSpeech('Puzzle solved!');
    _mood = MascotMood.win;
    notifyListeners();
  }

  void onGameOver() {
    _revertTimer?.cancel();
    _revertTimer = null;
    _isLocked = true;
    _streak = 0;
    _showSpeech('Good try!');
    _mood = MascotMood.mistake;
    notifyListeners();
  }

  void reset() {
    _revertTimer?.cancel();
    _revertTimer = null;
    _speechTimer?.cancel();
    _speechTimer = null;
    _isLocked = false;
    _isCellSelected = false;
    _streak = 0;
    _speechText = "Let's solve this!";
    _mood = MascotMood.idle;
    notifyListeners();
  }

  void _showSpeech(String text) {
    _speechTimer?.cancel();
    _speechText = text;
    _speechTimer = Timer(const Duration(milliseconds: 2500), () {
      _speechText = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _revertTimer?.cancel();
    _speechTimer?.cancel();
    super.dispose();
  }
}

const _tapMessages = ["I'm cheering for you!", 'High five!', 'You got this!'];
