import 'dart:io';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/screens/login_screen.dart';
import 'package:donapos_mobile/screens/config_screen.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:flutter/material.dart';
import 'package:donapos_mobile/config.dart';
import 'package:donapos_mobile/utils_storage.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/widgets/database_migration_dialog.dart';
import 'package:donapos_mobile/sync_service.dart';
import 'package:donapos_mobile/utils_scaler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Jenis error koneksi yang lebih spesifik
enum _ErrorType { noInternet, serverUnreachable, notConfigured, other }

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  double _progress = 0.05;
  String _status = 'MEMULAI SISTEM...';
  bool _failed = false;
  bool _isFirstTime = false;
  _ErrorType _errorType = _ErrorType.other;
  final ApiService _apiService = ApiService();
  int _retryCount = 0;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCheck());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ScreenScaler.init(context);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }
  
  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startCheck() async {
    if (!mounted) return;
    setState(() {
      _failed = false;
      _progress = 0.05;
      _status = 'MEMULAI SISTEM...';
    });

    try {
      await _smoothProgress(0.05, 0.2, 800);

      if (mounted) setState(() { _status = 'MEMERIKSA PENYIMPANAN...'; });
      await StorageUtils.checkStorageAndWarn(context);
      await _smoothProgress(0.2, 0.3, 400);

      if (mounted) setState(() { _status = 'PERIKSA VERSI DATABASE...'; });
      final dbHelper = DatabaseHelper.instance;
      bool migrationNeeded = await dbHelper.isMigrationNeeded();
      if (migrationNeeded && mounted) {
        int oldV = await dbHelper.getLocalVersion();
        int newV = DatabaseHelper.schemaVersion;
        final success = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => DatabaseMigrationDialog(oldVersion: oldV, newVersion: newV),
        );
        if (success != true) {
          _retryCount++;
          _setError(_ErrorType.other, 'MIGRASI DATABASE GAGAL\nHUBUNGI TIM SUPPORT');
          return;
        }
      }
      await _smoothProgress(0.3, 0.4, 400);

      if (await _apiService.isDemo()) {
        await _smoothProgress(0.4, 1.0, 500);
        if (mounted) _navNext();
        return;
      }

      final baseUrl = await _apiService.getBaseUrl();
      if (baseUrl.isEmpty) {
        // User baru: tampilkan Welcome Screen, bukan error
        if (mounted) setState(() => _isFirstTime = true);
        return;
      }

      if (mounted) setState(() { _status = 'MEMERIKSA KONEKSI...'; });

      final internetOk = await _hasInternet();
      if (!internetOk) {
        _retryCount++;
        _setError(_ErrorType.noInternet, 'TIDAK ADA INTERNET\nPERIKSA WIFI ATAU DATA SELULER');
        return;
      }

      if (mounted) setState(() { _status = 'MENGHUBUNGI SERVER...'; });
      bool serverOk = await _apiService.checkConnection();
      if (!mounted) return;

      if (serverOk) {
        _retryCount = 0;
        await _smoothProgress(0.4, 0.8, 800);
        if (mounted) setState(() { _status = 'MEMVERIFIKASI DATA...'; });
        await _smoothProgress(0.8, 1.0, 400);
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _navNext();
      } else {
        _retryCount++;
        _setError(_ErrorType.serverUnreachable, 'SERVER TIDAK MERESPON\nPERIKSA ALAMAT SERVER ATAU HUBUNGI ADMIN');
      }
    } catch (e) {
      _retryCount++;
      _setError(_ErrorType.other, 'TERJADI KESALAHAN\n${e.toString().split('\n').first}');
    }
  }

  void _setError(_ErrorType type, String message) {
    if (!mounted) return;
    setState(() {
      _failed = true;
      _errorType = type;
      _status = _retryCount >= 3
          ? 'PERCOBAAN HABIS (3×)\n${_errorHint(type)}'
          : message;
    });
  }

  String _errorHint(_ErrorType type) {
    switch (type) {
      case _ErrorType.noInternet:     return 'COBA MODE OFFLINE ATAU PERIKSA INTERNET';
      case _ErrorType.serverUnreachable: return 'KONFIGURASI SERVER ATAU MODE OFFLINE';
      case _ErrorType.notConfigured:  return 'SETUP SERVER DIPERLUKAN';
      default:                         return 'LANJUT MODE OFFLINE';
    }
  }

  Future<void> _smoothProgress(double from, double to, int durationMs) async {
    const int steps = 10;
    int msPerStep = durationMs ~/ steps;
    double inc = (to - from) / steps;
    for (int i = 1; i <= steps; i++) {
      if (!mounted || _failed) return;
      setState(() { _progress = from + (inc * i); });
      await Future.delayed(Duration(milliseconds: msPerStep));
    }
  }

  void _navNext() {
    if (!mounted) return;
    SyncService().startPeriodicSync();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _startDemoMode() async {
    setState(() { _isFirstTime = false; _status = 'MEMPERSIAPKAN DEMO...'; });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_demo_mode', true);
      await DatabaseHelper.instance.restoreDemoSnapshot();
      if (mounted) _navNext();
    } catch (e) {
      if (mounted) {
        showAppModal(context, title: 'GAGAL', message: 'Tidak dapat memulai demo: $e', isError: true);
        setState(() => _isFirstTime = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MetroColors.primary, Color(0xFF001F3F)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height,
                  ),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 48.sc, vertical: 40.sc),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildLogo(),
                          SizedBox(height: 56.sc),
                          _isFirstTime ? _buildWelcomeSection() : _buildStatusSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Footer
            Positioned(
              bottom: 20.sc, left: 0, right: 0,
              child: Center(child: DonaposFooter(textColor: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Welcome message
        Container(
          padding: EdgeInsets.symmetric(horizontal: 24.sc, vertical: 16.sc),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12.sc),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Icon(Icons.waving_hand_rounded, color: Colors.amber, size: 32.sc),
              SizedBox(height: 12.sc),
              Text(
                'SELAMAT DATANG!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.sc,
                ),
              ),
              SizedBox(height: 8.sc),
              Text(
                'Sistem Point of Sale untuk\nRestoran, Kafe & F&B',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 32.sc),

        // Primary CTA: Aktivasi
        SizedBox(
          width: 280.sc,
          child: ElevatedButton.icon(
            icon: Icon(Icons.rocket_launch_rounded, size: 22.sc),
            label: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.sc),
              child: Column(
                children: [
                  Text('AKTIVASI PERANGKAT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, letterSpacing: 1.sc)),
                  SizedBox(height: 2.sc),
                  Text('Butuh kode dari admin / backoffice DonaPOS', style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w500, color: Colors.white70)),
                ],
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: MetroColors.primary,
              elevation: 8,
              shadowColor: Colors.black38,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.sc)),
            ),
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConfigScreen()),
              );
              if (res == true && mounted) {
                _retryCount = 0;
                setState(() => _isFirstTime = false);
                _startCheck();
              }
            },
          ),
        ),

        SizedBox(height: 16.sc),

        // Secondary CTA: Demo
        SizedBox(
          width: 280.sc,
          child: OutlinedButton.icon(
            icon: Icon(Icons.play_circle_outline_rounded, size: 22.sc),
            label: Padding(
              padding: EdgeInsets.symmetric(vertical: 14.sc),
              child: Column(
                children: [
                  Text('COBA MODE DEMO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, letterSpacing: 1.sc)),
                  SizedBox(height: 2.sc),
                  Text('Jelajahi fitur tanpa setup', style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white38, width: 1.5.sc),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.sc)),
            ),
            onPressed: _startDemoMode,
          ),
        ),

      ],
    );
  }

  Widget _buildLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RotationTransition(
          turns: _rotationController,
          child: Container(
            padding: EdgeInsets.all(16.sc),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1.5.sc),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              width: 90.sc,
              height: 90.sc,
              fit: BoxFit.contain,
            ),
          ),
        ),
        SizedBox(height: 20.sc),
        Text(
          'DONAPOS',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 36.sp,
            fontWeight: FontWeight.w900,
            color: MetroColors.white,
            letterSpacing: 5.sc,
          ),
        ),
        Text(
          'Edisi FnB Plus',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.sp,
            color: Colors.white70,
            letterSpacing: 2.sc,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.sc),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.sc, vertical: 4.sc),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(20.sc),
          ),
          child: Text(
            'VERSI: ${AppConfig.appVersion}',
            style: TextStyle(
              fontSize: 10.sp,
              color: MetroColors.white,
              letterSpacing: 1.sc,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    if (!_failed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 5.sc,
            width: 220.sc,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(3.sc),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 220.sc * _progress,
                decoration: BoxDecoration(
                  color: MetroColors.white,
                  borderRadius: BorderRadius.circular(3.sc),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.6),
                      blurRadius: 8.sc,
                      spreadRadius: 1.sc,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 18.sc),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MetroColors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5.sc,
            ),
          ),
        ],
      );
    }

    final sisaCoba = 3 - _retryCount;
    final bisaRetry = sisaCoba > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildErrorBox(),
        SizedBox(height: 20.sc),
        if (bisaRetry)
          MetroButton(
            label: 'COBA LAGI ($sisaCoba tersisa)',
            color: MetroColors.white,
            textColor: MetroColors.primary,
            onPressed: _startCheck,
          )
        else
          MetroButton(
            label: 'LANJUTKAN MODE OFFLINE',
            color: MetroColors.white,
            textColor: MetroColors.primary,
            onPressed: _navNext,
          ),
        SizedBox(height: 10.sc),
        MetroButton(
          label: 'KONFIGURASI SERVER',
          color: Colors.white24,
          textColor: MetroColors.white,
          onPressed: () async {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConfigScreen()),
            );
            if (res == true && mounted) {
              _retryCount = 0;
              _startCheck();
            }
          },
        ),
        if (bisaRetry) ...[
          SizedBox(height: 8.sc),
          TextButton(
            onPressed: _navNext,
            child: Text(
              'MASUK MODE OFFLINE',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10.sp,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white54,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorBox() {
    final icon     = _errorIcon(_errorType);
    final color    = _errorColor(_errorType);
    final subtitle = _errorSubtitle(_errorType);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.sc, vertical: 16.sc),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.6), width: 1.5.sc),
        borderRadius: BorderRadius.circular(10.sc),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20.sc),
              SizedBox(width: 8.sc),
              Flexible(
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            SizedBox(height: 8.sc),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 10.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _errorIcon(_ErrorType type) {
    switch (type) {
      case _ErrorType.noInternet:        return Icons.signal_wifi_off_rounded;
      case _ErrorType.serverUnreachable: return Icons.cloud_off_rounded;
      case _ErrorType.notConfigured:     return Icons.settings_ethernet_rounded;
      default:                            return Icons.error_outline_rounded;
    }
  }

  Color _errorColor(_ErrorType type) {
    switch (type) {
      case _ErrorType.noInternet:        return Colors.orangeAccent;
      case _ErrorType.serverUnreachable: return MetroColors.error;
      case _ErrorType.notConfigured:     return Colors.amberAccent;
      default:                            return MetroColors.error;
    }
  }

  String _errorSubtitle(_ErrorType type) {
    switch (type) {
      case _ErrorType.noInternet:
        return 'Internet tidak tersedia.\nAktifkan WiFi atau data seluler, lalu coba lagi.';
      case _ErrorType.serverUnreachable:
        return 'Internet tersedia, tapi server ERP tidak merespon.\nPeriksa alamat server di Konfigurasi.';
      case _ErrorType.notConfigured:
        return 'Aplikasi belum dihubungkan ke server.\nTekan "Konfigurasi Server" untuk memulai setup.';
      default:
        return '';
    }
  }
}
