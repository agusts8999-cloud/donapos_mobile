import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global text scale multiplier (1.0 = baseline, up to 1.3 via Admin slider).
class UiTextScale extends ChangeNotifier {
  UiTextScale._();

  static const String _prefsKey = 'ui_text_scale';
  static const double minScale = 1.0;
  static const double maxScale = 1.3;
  static const double step = 0.05;

  static final UiTextScale instance = UiTextScale._();

  double _scale = 1.0;

  double get scale => _scale;

  int get percentLabel => (_scale * 100).round();

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    instance._scale = _clamp(prefs.getDouble(_prefsKey) ?? 1.0);
  }

  static double _clamp(double value) {
    if (value < minScale) return minScale;
    if (value > maxScale) return maxScale;
    return (value / step).round() * step;
  }

  Future<void> setScale(double value) async {
    final clamped = _clamp(value);
    if ((_scale - clamped).abs() < 0.001) return;
    _scale = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, _scale);
  }
}
