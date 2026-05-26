import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLangKey = 'selected_language';
const _supported = ['ar', 'fr'];

final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) => SharedPreferences.getInstance());

final languageProvider =
    StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  final saved = prefs?.getString(_kLangKey);
  final deviceCode = PlatformDispatcher.instance.locale.languageCode;
  final defaultCode = _supported.contains(deviceCode) ? deviceCode : 'ar';
  return LanguageNotifier(prefs, Locale(saved ?? defaultCode));
});

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier(this._prefs, Locale initial) : super(initial);

  final SharedPreferences? _prefs;

  void setLanguage(String languageCode) {
    _prefs?.setString(_kLangKey, languageCode);
    state = Locale(languageCode);
  }
}
