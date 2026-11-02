import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// لایه ذخیره‌سازی اپ؛ به‌صورت پیش‌فرض روی حافظه گوشی (SharedPreferences)
class AppStore {
  List<Appt> appointments = [];
  BizSettings settings = BizSettings();

  Future<void> load() async {}
  Future<void> saveAppts() async {}
  Future<void> saveSettings() async {}
}

/// ذخیره‌سازی روی حافظه دستگاه
class SharedPrefsStore extends AppStore {
  static const String _apptsKey = 'nobatyar.appointments.v1';
  static const String _settingsKey = 'nobatyar.settings.v1';

  @override
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawAppts = prefs.getString(_apptsKey);
      if (rawAppts != null && rawAppts.isNotEmpty) {
        final list = jsonDecode(rawAppts) as List<dynamic>;
        appointments =
            list.map((e) => Appt.fromJson(e as Map<String, dynamic>)).toList();
      }
      final rawSettings = prefs.getString(_settingsKey);
      if (rawSettings != null && rawSettings.isNotEmpty) {
        settings =
            BizSettings.fromJson(jsonDecode(rawSettings) as Map<String, dynamic>);
      }
    } catch (_) {
      // در صورت خرابی داده، با حالت خالی ادامه می‌دهیم
    }
  }

  @override
  Future<void> saveAppts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _apptsKey,
        jsonEncode(appointments.map((a) => a.toJson()).toList()),
      );
    } catch (_) {}
  }

  @override
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    } catch (_) {}
  }
}

/// ذخیره‌سازی در حافظه (برای تست)
class MemoryStore extends AppStore {
  MemoryStore({List<Appt>? seed, BizSettings? settings}) {
    appointments = seed ?? [];
    this.settings = settings ?? BizSettings();
  }
}
