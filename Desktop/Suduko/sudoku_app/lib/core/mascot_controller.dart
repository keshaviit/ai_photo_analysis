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
  bool _isLocked = false; // Locked on game won or game over

  MascotMood get mood => _mood;
  String get assetPath => _mood.assetPath;

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
    setMood(MascotMood.happy, duration: duration);
  }

  void onMistake({Duration duration = const Duration(milliseconds: 1800)}) {
    setMood(MascotMood.mistake, duration: duration);
  }

  void onHintUsed({Duration duration = const Duration(milliseconds: 2200)}) {
    setMood(MascotMood.hint, duration: duration);
  }

  void onGameWon() {
    _revertTimer?.cancel();
    _revertTimer = null;
    _isLocked = true;
    _mood = MascotMood.win;
    notifyListeners();
  }

  void onGameOver() {
    _revertTimer?.cancel();
    _revertTimer = null;
    _isLocked = true;
    _mood = MascotMood.mistake;
    notifyListeners();
  }

  void reset() {
    _revertTimer?.cancel();
    _revertTimer = null;
    _isLocked = false;
    _isCellSelected = false;
    _mood = MascotMood.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _revertTimer?.cancel();
    super.dispose();
  }
}
