import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class ScreenScaler {
  static const double baseWidth = 1340.0;
  static const double baseHeight = 800.0;

  static double _screenWidth = 0.0;
  static double _screenHeight = 0.0;
  static double _scaleFactor = 1.0;
  
  static bool _isManual = false;
  static double _manualScale = 1.0;

  /// Inisialisasi scaler pada setiap screen atau di main app
  static void init(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    _screenWidth = mediaQuery.size.width;
    _screenHeight = mediaQuery.size.height;

    _calculateScale();
  }

  static void _calculateScale() {
    if (_isManual) {
      _scaleFactor = _manualScale;
    } else {
      double scaleWidth = _screenWidth / baseWidth;
      double scaleHeight = _screenHeight / baseHeight;
      _scaleFactor = min(scaleWidth, scaleHeight);
    }
  }

  /// Method utama untuk scaling ukuran
  static double scale(double size) {
    return size * _scaleFactor;
  }

  /// Getters
  static double get scaleFactor => _scaleFactor;
  static bool get isManual => _isManual;
  static double get manualScaleValue => _manualScale;

  /// Update mode scaling (Auto/Manual)
  static Future<void> updateScaling({required bool isManual, double? manualScale}) async {
    _isManual = isManual;
    if (manualScale != null) {
      _manualScale = manualScale;
    }
    _calculateScale();

    // Simpan ke SharedPreferences agar persisten
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('scaling_is_manual', _isManual);
    await prefs.setDouble('scaling_manual_value', _manualScale);
  }

  /// Load pengaturan dari storage
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isManual = prefs.getBool('scaling_is_manual') ?? false;
    _manualScale = prefs.getDouble('scaling_manual_value') ?? 1.0;
    _calculateScale();
  }
}

/// Extension untuk memudahkan penggunaan di UI
/// Contoh: 16.sp (font), 10.sc (padding/margin)
extension ScaleExtension on num {
  double get sp => ScreenScaler.scale(toDouble());
  double get sc => ScreenScaler.scale(toDouble());
}
