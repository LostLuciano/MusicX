import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/studio_settings.dart';

class StudioSettingsService {
  static const String _settingsKey = 'studio_settings';

  Future<StudioSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? settingsJson = prefs.getString(_settingsKey);

    if (settingsJson != null) {
      final Map<String, dynamic> data = jsonDecode(settingsJson);
      return StudioSettings.fromJson(data);
    }

    // Return default settings
    return const StudioSettings();
  }

  Future<void> saveSettings(StudioSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final String settingsJson = jsonEncode(settings.toJson());
    await prefs.setString(_settingsKey, settingsJson);
  }

  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
  }
}
