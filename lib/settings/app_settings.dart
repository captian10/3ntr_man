import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static double volume = 1.0; // 0..1

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    volume = prefs.getDouble('volume') ?? 1.0;
  }

  static Future<void> saveVolume(double v) async {
    volume = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('volume', v);
  }
}
