import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  static final SettingsController instance = SettingsController._internal();
  
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  bool _isDarkMode = true;
  bool _mistakesLimitEnabled = true;
  bool _highlightIdenticalEnabled = true;
  bool _mascotEnabled = true;

  bool get isInitialized => _isInitialized;
  bool get isDarkMode => _isDarkMode;
  bool get mistakesLimitEnabled => _mistakesLimitEnabled;
  bool get highlightIdenticalEnabled => _highlightIdenticalEnabled;
  bool get mascotEnabled => _mascotEnabled;

  SettingsController._internal() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs.getBool('isDarkMode') ?? true;
    _mistakesLimitEnabled = _prefs.getBool('mistakesLimitEnabled') ?? true;
    _highlightIdenticalEnabled = _prefs.getBool('highlightIdenticalEnabled') ?? true;
    _mascotEnabled = _prefs.getBool('mascotEnabled') ?? true;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (!_isInitialized) return;
    _isDarkMode = value;
    await _prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  Future<void> setMistakesLimit(bool value) async {
    if (!_isInitialized) return;
    _mistakesLimitEnabled = value;
    await _prefs.setBool('mistakesLimitEnabled', value);
    notifyListeners();
  }

  Future<void> setHighlightIdentical(bool value) async {
    if (!_isInitialized) return;
    _highlightIdenticalEnabled = value;
    await _prefs.setBool('highlightIdenticalEnabled', value);
    notifyListeners();
  }

  Future<void> setMascotEnabled(bool value) async {
    if (!_isInitialized) return;
    _mascotEnabled = value;
    await _prefs.setBool('mascotEnabled', value);
    notifyListeners();
  }
}
