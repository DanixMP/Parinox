import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

const _prefsKey = 'parinox_app_settings_v1';

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return AppSettings.defaults;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(map);
    } catch (_) {
      return AppSettings.defaults;
    }
  }

  Future<void> patch(AppSettings Function(AppSettings) mutate) async {
    final current = state.valueOrNull ?? AppSettings.defaults;
    final next = mutate(current);
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(next.toJson()));
  }

  Future<void> reset() async {
    state = const AsyncData(AppSettings.defaults);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

ThemeMode themeModeFromSettings(AppSettings s) => switch (s.theme) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
