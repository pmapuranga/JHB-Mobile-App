import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  SettingsProvider(this._prefs) {
    _loadSettings();
  }

  final SharedPreferences _prefs;

  Locale? _locale;
  Locale? get locale => _locale;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  double _fontSize = 16.0;
  double get fontSize => _fontSize;

  double _brightness = 1.0;
  double get brightness => _brightness;

  bool _keepScreenOn = true;
  bool get keepScreenOn => _keepScreenOn;

  BookSortType _sortType = BookSortType.dateAdded;
  BookSortType get sortType => _sortType;

  bool _sortAscending = false;
  bool get sortAscending => _sortAscending;

  void _loadSettings() {
    _locale = const Locale('en');

    final themeIndex = _prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];

    _fontSize = (_prefs.getDouble('font_size') ?? 16.0).clamp(12.0, 24.0);
    _brightness = (_prefs.getDouble('brightness') ?? 1.0).clamp(0.3, 1.0);
    _keepScreenOn = _prefs.getBool('keep_screen_on') ?? true;

    final sortIndex = _prefs.getInt('sort_type') ?? 0;
    _sortType = BookSortType.values[sortIndex];
    _sortAscending = _prefs.getBool('sort_ascending') ?? false;

    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = const Locale('en');
    await _prefs.setString('language_code', 'en');
    await _prefs.remove('country_code');
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    await _prefs.setInt('theme_mode', themeMode.index);
    notifyListeners();
  }

  Future<void> setFontSize(double fontSize) async {
    _fontSize = fontSize.clamp(12.0, 24.0);
    await _prefs.setDouble('font_size', _fontSize);
    notifyListeners();
  }

  Future<void> setBrightness(double brightness) async {
    _brightness = brightness.clamp(0.3, 1.0);
    await _prefs.setDouble('brightness', _brightness);
    notifyListeners();
  }

  Future<void> setKeepScreenOn(bool keepScreenOn) async {
    _keepScreenOn = keepScreenOn;
    await _prefs.setBool('keep_screen_on', keepScreenOn);
    notifyListeners();
  }

  Future<void> setSortType(BookSortType sortType) async {
    _sortType = sortType;
    await _prefs.setInt('sort_type', sortType.index);
    notifyListeners();
  }

  Future<void> setSortAscending(bool ascending) async {
    _sortAscending = ascending;
    await _prefs.setBool('sort_ascending', ascending);
    notifyListeners();
  }

  static const List<Locale> supportedLocales = [
    Locale('en'),
  ];

  static const Map<String, String> languageNames = {
    'en': 'Shona',
  };
}

enum BookSortType {
  name,
  dateAdded,
  progress,
}
