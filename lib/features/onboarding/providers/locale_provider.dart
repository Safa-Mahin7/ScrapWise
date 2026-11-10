import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

/// Provides the currently selected [Locale].
/// Null means system default is used.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    // Load saved locale asynchronously; start with null (system default).
    _loadSavedLocale();
    return null;
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final tag = prefs.getString(AppConstants.prefLocale);
    if (tag != null) {
      state = Locale(tag);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLocale, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
