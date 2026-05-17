/**
 * File: config_screen.dart
 * Deskripsi: Layar pengaturan koneksi ke sistem ERP DonaPOS.
 * Update Terakhir: 2026-02-03 15:50 (WIB)
 */

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/widgets/confirm_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:donapos_mobile/config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:donapos_mobile/screens/login_screen.dart';
import 'package:donapos_mobile/sync_service.dart';
import 'package:donapos_mobile/utils_scaler.dart';
import 'package:donapos_mobile/utils/activation_messages.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _isDemoMode = false;
  bool _hasCustomDemo = false;
  bool _useCurrentAsDemo = false;
  bool _isActivated = false;
  final List<Map<String, dynamic>> _logs = []; // Activation Log
  String _serverMode = 'server1';
  int _wizardStep = 0;
  bool _showAdvancedMode = false;
  bool _connectionVerified = false;
  String? _connectionStatusMessage;

  // Controllers
  final _urlController = TextEditingController();
  final _activationCodeController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _locationIdController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _noteController = TextEditingController(); // Added for user note/location name

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  // Mengambil konfigurasi saat ini dari ApiService dan SharedPreferences
  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    String savedUrl = await _apiService.getBaseUrl();
    if (savedUrl.isEmpty || savedUrl == 'https://donapos.serverzone.web.id/public') {
      _serverMode = 'server1';
      _urlController.text = 'https://donapos.serverzone.web.id/public';
    } else if (savedUrl == 'https://app.donapos.biz.id/public' || savedUrl == 'https://donapos.biz.id') {
      _serverMode = 'server2';
      _urlController.text = 'https://app.donapos.biz.id/public';
    } else {
      _serverMode = 'custom';
      _urlController.text = savedUrl;
    }
    _clientIdController.text = await _apiService.getClientId();
    _clientSecretController.text = await _apiService.getClientSecret();
    _locationIdController.text = await _apiService.getLocationId();
    _businessNameController.text = await _apiService.getBusinessName();
    final prefs = await SharedPreferences.getInstance();
    final hasCustom = await DatabaseHelper.instance.hasDemoSnapshot();
    setState(() {
      _isLoading = false;
      _isDemoMode = prefs.getBool('is_demo_mode') ?? false;
      _hasCustomDemo = hasCustom;
      _isActivated = _clientIdController.text.isNotEmpty;
    });
  }

  // Menyimpan data lokal saat ini (Produk, User, dll) sebagai baseline untuk Mode Demo
  Future<void> _captureDemoSnapshot() async {
    bool confirm = await showAppConfirm(
      context,
      title: 'SIMPAN DATA SEBAGAI DEMO?',
      message: 'Seluruh data saat ini (Produk, User, Stok, dll) akan disimpan sebagai "Master Data" untuk Mode Demo.\n\nData lama yang pernah disimpan akan digantikan.',
      confirmLabel: 'SIMPAN SNAPSHOT',
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    await DatabaseHelper.instance.captureDemoSnapshot();
    setState(() {
       _isLoading = false;
       _hasCustomDemo = true;
    });
    
    if (mounted) {
      showAppModal(context, title: 'BERHASIL', message: 'Data berhasil disimpan sebagai baseline demo. Setiap kali Mode Demo diaktifkan, aplikasi akan merestore data ini.');
    }
  }

  // Mengaktifkan atau menonaktifkan Mode Demo (Pelatihan)
  Future<void> _toggleDemoMode(bool val) async {
    bool confirm = await showAppConfirm(
      context,
      title: val ? 'AKTIFKAN MODE DEMO?' : 'MATIKAN MODE DEMO?',
      message: val 
        ? (_useCurrentAsDemo 
             ? 'Data saat ini akan DISIMPAN sebagai data latihan/demo.\nAnda dapat berlatih menggunakan data produk Anda sendiri.'
             : 'Aplikasi akan otomatis merestore database default untuk demo.\nSemua data lokal saat ini akan DIBERSIHKAN.')
        : 'Mode demo akan dimatikan. Koneksi ke server akan kembali normal.',
      confirmLabel: 'YA, LANJUTKAN',
    );

    if (confirm != true) return;

    _addLog('MODE DEMO ${val ? "DIAKTIFKAN" : "DIMATIKAN"}', isInfo: true);
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_demo_mode', val);
    
    if (val) {
      if (_useCurrentAsDemo) {
          _addLog('MENYIMPAN DATA SAAT INI SEBAGAI DEMO...');
          await DatabaseHelper.instance.captureDemoSnapshot();
          _addLog('SNAPSHOT DEMO TERSIMPAN.');
      }
      _addLog('MEMULIHKAN DATABASE DEMO...');
      await DatabaseHelper.instance.restoreDemoSnapshot();
      _addLog('DATABASE DEMO BERHASIL DIPULIHKAN.');
    } else {
      _addLog('MODE NORMAL AKTIF. SILAKAN SYNC ULANG.');
    }
    
    setState(() {
      _isDemoMode = val;
      _isLoading = false;
    });

    if (mounted) {
      showAppModal(context, title: 'MODE BERHASIL DIUBAH', message: 'APLIKASI SEKARANG BERJALAN DALAM ${val ? "MODE DEMO/TRAINING" : "MODE NORMAL"}.');
    }
  }

  void _addLog(String message, {bool isError = false, bool isInfo = false, bool isSuccess = false}) {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    setState(() {
      _logs.insert(0, {
        'time': timeStr,
        'message': message,
        'type': isError ? 'error' : (isSuccess ? 'success' : (isInfo ? 'info' : 'default')),
      });
    });
  }

  Future<void> _openDemoWebsite() async {
    final Uri url = Uri.parse('https://donapos.biz.id');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        showAppModal(context, title: 'GAGAL MEMBUKA LINK', message: 'TIDAK DAPAT MEMBUKA WEBSITE DONAPOS.BIZ.ID\nERROR: $e', isError: true);
      }
    }
  }

  Future<void> _checkUrl() async {
    if (_urlController.text.isEmpty) {
      showAppModal(context, title: 'URL KOSONG', message: 'MOHON ISI BASE URL TERLEBIH DAHULU.', isError: true);
      return;
    }
    
    setState(() => _isLoading = true);
    final result = await _apiService.validateBaseUrl(_urlController.text);
    
    if (!result['valid']) {
      setState(() => _isLoading = false);
      if (mounted) {
        showAppModal(context, title: 'KONEKSI GAGAL', message: result['message'], isError: true);
      }
      return;
    }

    // Advanced Verification: Fetch Business & Location Name
    final locId = _locationIdController.text.trim();
    if (locId.isEmpty) {
      setState(() => _isLoading = false);
      if (mounted) {
        showAppModal(context, title: 'KONEKSI BERHASIL', message: 'SERVER TERHUBUNG.\n(ISI ID LOKASI UNTUK VERIFIKASI NAMA BISNIS)');
      }
      return;
    }

    final detailResult = await _apiService.fetchBusinessLocationInfo(_urlController.text, locId);
    setState(() => _isLoading = false);

    if (mounted) {
      if (detailResult['success']) {
        // Show Advanced Verification Dialog
        _showVerificationDialog(detailResult['business_name'], detailResult['location_name']);
      } else {
        if (detailResult['message'].contains('401') || detailResult['message'].contains('DITOLAK')) {
           showAppModal(
             context, 
             title: 'KONEKSI BERHASIL', 
             message: 'SERVER TERHUBUNG!\n\nNamun Data Nama Bisnis terverifikasi "Terproteksi" (401).\nSilakan lanjutkan setup dan login untuk sinkronisasi data.'
           );
        } else {
           showAppModal(context, title: 'VERIFIKASI GAGAL', message: detailResult['message'], isError: true);
        }
      }
    }
  }

  void _showVerificationDialog(String businessName, String locationName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: MetroColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('VERIFIKASI DATA SERVER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: MetroColors.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SERVER BERHASIL TERHUBUNG. PASTIKAN DATA BERIKUT SUDAH BENAR:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 20),
            _buildVerifyRow('1. NAMA BISNIS', businessName),
            const SizedBox(height: 12),
            _buildVerifyRow('2. NAMA LOKASI/OUTLET', locationName),
            const SizedBox(height: 24),
            const Text('APAKAH ANDA SETUJU DENGAN DATA INI?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: MetroColors.text)),
            const Text('JIKA TIDAK, SILAKAN HUBUNGI VENDOR.', style: TextStyle(fontSize: 10, color: MetroColors.error, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('TIDAK / BATAL', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MetroColors.retailPrimary, 
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
            ),
            onPressed: () {
              setState(() {
                _businessNameController.text = businessName;
                _locationNameController.text = locationName;
              });
              Navigator.pop(ctx);
              showAppModal(context, title: 'DATA DISALIN', message: 'NAMA BISNIS & LOKASI TELAH DIPERBARUI DI FORMULIR.');
            }, 
            child: const Text('YA, SAYA SETUJU', style: TextStyle(fontWeight: FontWeight.w900))
          ),
        ],
      )
    );
  }

  Widget _buildVerifyRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      color: Colors.black.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black38)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(value.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: MetroColors.primary))),
              const Icon(Icons.check_circle, color: MetroColors.retailPrimary, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  void _resetFields() {
    setState(() {
      _urlController.clear();
      _clientIdController.clear();
      _clientSecretController.clear();
      _locationIdController.clear();
      _businessNameController.clear();
      _locationNameController.clear();
    });
    showAppModal(context, title: 'RESET', message: 'FORMULIR KONFIGURASI TELAH DIKOSONGKAN.');
  }

  void _pasteConfig() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _parseAndLoadJson(data!.text!);
    } else {
      _showManualPasteDialog();
    }
  }

  String _normalizedActivationCode() {
    return _activationCodeController.text.replaceAll('-', '').trim().toUpperCase();
  }

  String _serverDisplayLabel() {
    switch (_serverMode) {
      case 'server1':
        return 'Server DonaPOS Utama';
      case 'server2':
        return 'Server DonaPOS Alternatif';
      default:
        return _urlController.text.trim().isEmpty
            ? 'Server kustom'
            : _urlController.text.trim();
    }
  }

  Future<void> _wizardCheckConnection() async {
    if (_urlController.text.trim().isEmpty) {
      showAppModal(
        context,
        title: 'SERVER BELUM DIPILIH',
        message: ActivationMessages.emptyUrl,
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    _addLog('MENGECEK KONEKSI KE SERVER...');
    final result = await _apiService.validateBaseUrl(_urlController.text.trim());
    setState(() {
      _isLoading = false;
      _connectionVerified = result['valid'] == true;
      _connectionStatusMessage = result['message']?.toString();
    });

    if (result['valid'] == true) {
      _addLog('KONEKSI SERVER OK.', isSuccess: true);
    } else {
      _addLog('KONEKSI GAGAL: ${result['message']}', isError: true);
    }

    if (!mounted) return;
    showAppModal(
      context,
      title: result['valid'] == true ? 'KONEKSI BERHASIL' : 'KONEKSI GAGAL',
      message: ActivationMessages.userMessage(_connectionStatusMessage),
      isError: result['valid'] != true,
    );
  }

  Future<void> _wizardNext() async {
    if (_wizardStep == 0) {
      if (_urlController.text.trim().isEmpty) {
        showAppModal(
          context,
          title: 'SERVER BELUM DIPILIH',
          message: ActivationMessages.emptyUrl,
          isError: true,
        );
        return;
      }
      setState(() => _wizardStep = 1);
      return;
    }

    if (_wizardStep == 1) {
      final code = _normalizedActivationCode();
      if (code.length != 9) {
        showAppModal(
          context,
          title: 'KODE BELUM LENGKAP',
          message: ActivationMessages.invalidCodeFormat,
          isError: true,
        );
        return;
      }
      if (!_connectionVerified) {
        showAppModal(
          context,
          title: 'CEK KONEKSI DULU',
          message:
              'Tekan tombol "Cek koneksi" untuk memastikan tablet terhubung ke server sebelum melanjutkan.',
          isError: true,
        );
        return;
      }
      setState(() => _wizardStep = 2);
    }
  }

  void _wizardBack() {
    if (_wizardStep <= 0) return;
    setState(() => _wizardStep -= 1);
  }

  Future<void> _confirmAndActivate() async {
    await _activateByCode(skipConfirm: false);
  }

  Future<void> _activateByCode({bool skipConfirm = false}) async {
    if (_urlController.text.isEmpty || _activationCodeController.text.isEmpty) {
      showAppModal(
        context, 
        title: 'DATA KURANG', 
        message: 'Pilih server dan masukkan kode aktivasi dari admin DonaPOS.', 
        isError: true
      );
      return;
    }

    final code = _normalizedActivationCode();
    if (code.length != 9) {
      showAppModal(
        context,
        title: 'KODE BELUM LENGKAP',
        message: ActivationMessages.invalidCodeFormat,
        isError: true,
      );
      return;
    }

    if (!skipConfirm) {
      final confirm = await showAppConfirm(
        context,
        title: 'LANJUTKAN AKTIVASI?',
        message:
            'Aktivasi akan menghapus data lama di tablet ini dan menghubungkan perangkat ke server bisnis Anda. Lanjutkan?',
        confirmLabel: 'YA, AKTIVASI SEKARANG',
      );
      if (confirm != true) return;
    }

    setState(() => _isLoading = true);
    _addLog('MENGHUBUNGI SERVER AKTIVASI...');

    // Fetch Location Info
    String locationInfo = "Unknown Location";
    String? finalIp;
    
    try {
        // 1. Get IP
        try {
          final ipRes = await http.get(Uri.parse('https://api.ipify.org')).timeout(const Duration(seconds: 3));
          if (ipRes.statusCode == 200) {
            finalIp = ipRes.body;
            locationInfo = finalIp!; 
          }
        } catch (_) {}

        // 2. Get Geolocation
        String latLong = '';
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
             LocationPermission permission = await Geolocator.checkPermission();
             if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
             }
             if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
                  try {
                    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 5));
                    latLong = ' (${position.latitude}, ${position.longitude})';
                  } catch (_) {}
             }
        }
        
        if (finalIp != null) {
          locationInfo = "$finalIp$latLong";
        } else {
          locationInfo = "Unknown IP$latLong";
        }

    } catch (_) {}
    
    // User Note Logic
    String userNote = _noteController.text.trim();
    String sentLocationInfo = locationInfo;
    
    if (userNote.isNotEmpty) {
        sentLocationInfo = "$userNote $locationInfo";
    }

    try {
      final result = await _apiService.activateWithCode(
        _urlController.text.trim(),
        code,
        locationInfo: sentLocationInfo,
        ip: finalIp,
      );

      if (result['success']) {
        final config = result['config'];
        _addLog('AKTIVASI BERHASIL!', isSuccess: true);
        
        // 1. Populate Controllers
        setState(() {
          _clientIdController.text = config['client_id']?.toString() ?? '';
          _clientSecretController.text = config['client_secret']?.toString() ?? '';
          _locationIdController.text = config['location_id']?.toString() ?? '';
          _businessNameController.text = config['business_name']?.toString() ?? '';
          _locationNameController.text = config['location_name']?.toString() ?? '';
        });

        // 2. Simpan Config Dulu (AMAN: Tidak hapus prefs sebelum config baru tersimpan)
        _addLog('MENYIMPAN KONFIGURASI BARU...');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('base_url', _urlController.text.trim());
        await prefs.setString('client_id', config['client_id']?.toString() ?? '');
        await prefs.setString('client_secret', config['client_secret']?.toString() ?? '');
        await prefs.setString('location_id', config['location_id']?.toString() ?? '');
        await prefs.setString('business_name', config['business_name']?.toString() ?? '');
        await prefs.setString('location_name', config['location_name']?.toString() ?? '');
        await prefs.setString('activation_code', _activationCodeController.text.trim());
        await prefs.remove('token'); // Reset token agar login ulang dengan akun baru
        
        if (prefs.getString('default_sale_type') == null) {
             await prefs.setString('default_sale_type', 'dinein');
        }
        _addLog('KONFIGURASI TERSIMPAN.', isSuccess: true);

        // 3. Reset Database (Setelah config aman tersimpan)
        _addLog('MEMBERSIHKAN DATA LAMA...');
        await DatabaseHelper.instance.resetDatabase();
        await Future.delayed(const Duration(milliseconds: 300));

        // 4. Sinkron User
        _addLog('SINKRONISASI USER DARI SERVER...');
        int userCount = 0;

        if (result['users'] is List && (result['users'] as List).isNotEmpty) {
           final List initialUsers = result['users'];
           _addLog('DITEMUKAN ${initialUsers.length} USER DARI RESPON.');
           
           // PENTING: Bersihkan user lama sebelum insert user baru
           await DatabaseHelper.instance.clearUsers();
           
           for (var u in initialUsers) {
              if (u is Map) {
                 try {
                   await DatabaseHelper.instance.insertUser({
                     'id': int.tryParse(u['id']?.toString() ?? '0') ?? 0,
                     'username': u['username']?.toString() ?? 'user_${u['id']}',
                     'first_name': u['first_name']?.toString() ?? 'Unknown',
                     'last_name': u['last_name']?.toString(),
                     'pin': u['service_staff_pin']?.toString(),
                     'profile_image': u['image_url']?.toString(),
                     'is_admin': (u['is_admin'] == true || u['is_admin'] == 1) ? 1 : 0,
                   });
                   userCount++;
                 } catch (e) {
                   _addLog('GAGAL SIMPAN USER ${u['username']}: $e', isError: true);
                 }
              }
           }
           _addLog('BERHASIL SINKRON $userCount USER.', isSuccess: true);
        }
        
        // Fallback or Full Sync if needed
        if (userCount == 0) {
           _addLog('MENCOBA SYNC API PENUH...');
           try {
             bool authSuccess = await _apiService.authenticateClient();
             if (authSuccess) {
                 userCount = await _apiService.syncUsers();
                 _addLog('BERHASIL SINKRON $userCount USER (API FULL).', isSuccess: true);
             } else {
                 _addLog('GAGAL OTENTIKASI KLIEN.', isError: true);
             }
           } catch (e) {
             _addLog('GAGAL SINKRON API: $e', isError: true);
           }
        }

        setState(() => _isLoading = false);

        if (mounted) {
            // Tampilkan dialog 3 pilihan setelah aktivasi berhasil
            if (!mounted) return;
            SyncService().startPeriodicSync();
            _showPostActivationDialog(userCount);
        }

      } else {
        throw result['message'] ?? ActivationMessages.genericFailure;
      }

    } catch (e) {
      setState(() => _isLoading = false);
      _addLog('ERROR: $e', isError: true);
      if (mounted) {
        showAppModal(
          context, 
          title: 'AKTIVASI GAGAL', 
          message: ActivationMessages.userMessage(e.toString()), 
          isError: true
        );
      }
    }
  }

  void _showPostActivationDialog(int userCount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: BoxConstraints(maxWidth: 480.sc),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.sc),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30.sc,
                offset: Offset(0, 10.sc),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 24.sc),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12.sc)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 48.sc),
                    SizedBox(height: 12.sc),
                    Text('AKTIVASI BERHASIL!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18.sp, letterSpacing: 1.5.sc)),
                  ],
                ),
              ),
              // Info
              Padding(
                padding: EdgeInsets.all(20.sc),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.sc),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8.sc),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow('BISNIS', _businessNameController.text),
                          SizedBox(height: 4.sc),
                          _infoRow('LOKASI', _locationNameController.text),
                          SizedBox(height: 4.sc),
                          _infoRow('STAFF', '$userCount orang tersinkronisasi'),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.sc),
                    Text('Pilih langkah selanjutnya:', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.black54)),
                    SizedBox(height: 16.sc),
                    _choiceButton(
                      ctx: ctx,
                      icon: Icons.people_alt_rounded,
                      title: 'MASUK SEBAGAI KASIR',
                      subtitle: 'Disarankan — pilih kasir dan masukkan PIN.',
                      color: MetroColors.secondary,
                      isPrimary: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                    ),
                    SizedBox(height: 10.sc),
                    _choiceButton(
                      ctx: ctx,
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'BUKA PANEL ADMIN',
                      subtitle: 'Sinkronisasi data produk, kategori, dll.',
                      color: MetroColors.primary,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen(showAdminLogin: true)),
                          (route) => false,
                        );
                      },
                    ),
                    SizedBox(height: 10.sc),
                    _choiceButton(
                      ctx: ctx,
                      icon: Icons.power_settings_new_rounded,
                      title: 'TUTUP APLIKASI',
                      subtitle: 'Setup selesai. Buka kembali nanti.',
                      color: Colors.grey.shade600,
                      onTap: () {
                        Navigator.pop(ctx);
                        // Gunakan exit(0) langsung agar tidak ada warning Android
                        Future.delayed(const Duration(milliseconds: 200), () => exit(0));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 60.sc,
          child: Text(label, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.black38)),
        ),
        Expanded(child: Text(value.toUpperCase(), style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: MetroColors.primary))),
      ],
    );
  }

  Widget _choiceButton({
    required BuildContext ctx,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.sc),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.sc, vertical: 14.sc),
          decoration: BoxDecoration(
            color: isPrimary ? color : null,
            border: Border.all(
              color: isPrimary ? color : color.withOpacity(0.3),
              width: isPrimary ? 0 : 1.5,
            ),
            borderRadius: BorderRadius.circular(8.sc),
          ),
          child: Row(
            children: [
              Container(
                width: 40.sc, height: 40.sc,
                decoration: BoxDecoration(
                  color: isPrimary ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.sc),
                ),
                child: Icon(icon, color: isPrimary ? Colors.white : color, size: 22.sc),
              ),
              SizedBox(width: 14.sc),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12.sp,
                        color: isPrimary ? Colors.white : color,
                        letterSpacing: 0.5.sc,
                      ),
                    ),
                    SizedBox(height: 2.sc),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: isPrimary ? Colors.white70 : Colors.black45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isPrimary ? Colors.white70 : color.withOpacity(0.5),
                size: 24.sc,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _uploadConfigFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        _parseAndLoadJson(content);
      }
    } catch (e) {
      showAppModal(
        context, 
        title: 'UPLOAD GAGAL', 
        message: 'GAGAL MEMBACA FILE. JIKA GAGAL, SILAKAN GUNAKAN OPSI PASTE (TEMPEL) TEKS.\nERROR: $e', 
        isError: true
      );
    }
  }

  void _showManualPasteDialog() {
    final pasteController = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: MetroColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('TEMPEL TEKS JSON', style: TextStyle(color: MetroColors.text, fontWeight: FontWeight.w900, letterSpacing: 1)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('SALIN TEKS KONFIGURASI DARI ERP/EMAIL LALU TEMPEL DI SINI:', style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: pasteController,
              maxLines: 6,
              style: const TextStyle(color: MetroColors.primary, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '{ "base_url": "...", ... }',
                hintStyle: const TextStyle(color: Colors.black12),
                fillColor: Colors.black.withOpacity(0.05),
                filled: true,
                border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('BATAL', style: TextStyle(color: Colors.black38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MetroColors.primary, foregroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
            onPressed: () {
              Navigator.pop(c);
              _parseAndLoadJson(pasteController.text);
            }, 
            child: const Text('PROSES DATA', style: TextStyle(fontWeight: FontWeight.w900))
          ),
        ],
      )
    );
  }

  void _parseAndLoadJson(String content) {
    try {
      final Map<String, dynamic> data = json.decode(content);
      setState(() {
        _urlController.text = data['base_url'] ?? _urlController.text;
        _clientIdController.text = data['client_id']?.toString() ?? '';
        _clientSecretController.text = data['client_secret'] ?? '';
        _locationIdController.text = data['location_id']?.toString() ?? '';
        _businessNameController.text = data['business_name'] ?? '';
        _locationNameController.text = data['location_name'] ?? '';
      });
      showAppModal(context, title: 'BERHASIL', message: 'DATA KONFIGURASI BERHASIL DIMUAT KE FORMULIR.');
    } catch (e) {
      showAppModal(
        context, 
        title: 'FORMAT SALAH', 
        message: 'ISI FILE/TEKS TIDAK VALID ATAU RUSAK. JIKA GAGAL, SILAKAN GUNAKAN OPSI PASTE (TEMPEL) TEKS.\nERROR: $e', 
        isError: true
      );
    }
  }

  void _showChangelog() {
  }

  // Menyimpan konfigurasi baru dan membersihkan database lokal untuk sinkronisasi ulang
  Future<void> _finalizeSetup() async {
    if (_urlController.text.isEmpty || _clientIdController.text.isEmpty) {
      showAppModal(context, title: 'DATA KURANG', message: 'MOHON ISI BASE URL DAN CLIENT ID SEBELUM MENYIMPAN.', isError: true);
      return;
    }

    bool confirm = await showAppConfirm(
      context,
      title: 'UPDATE & BERSIHKAN TOTAL?',
      message: 'TINDAKAN INI TIDAK BISA DIBATALKAN: \n1. UPDATE KONEKSI SERVER BARU. \n2. MENGHAPUS SEMUA DATABASE LOKAL. \n3. SELURUH DATA PENJUALAN AKAN HILANG.',
      confirmLabel: 'YA, BERSIHKAN & UPDATE',
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _apiService.saveConfig(
        _urlController.text.trim(),
        _clientIdController.text.trim(),
        _clientSecretController.text.trim(),
        _locationIdController.text.trim(),
        _businessNameController.text.trim(),
        _locationNameController.text.trim(),
      );

      await DatabaseHelper.instance.clearAllData();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('last_sync_time');
      await prefs.remove('initial_cash');
      await prefs.remove('last_user_id');
      await prefs.remove('last_user_name');
      await prefs.setBool('is_cashier_open', false);

      if (!mounted) return;
      await showAppModal(
        context, 
        title: 'KONEKSI DIPERBARUI', 
        message: 'SISTEM TELAH DIKONFIGURASI ULANG. APLIKASI AKAN DIMUAT ULANG.\n\nSILAKAN GUNAKAN AKUN ANDA UNTUK LOGIN KEMBALI.'
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showAppModal(context, title: 'GAGAL MENYIMPAN', message: 'SISTEM GAGAL MENYIMPAN KONFIGURASI. ERROR: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('AKTIVASI PERANGKAT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white, fontSize: 18)),
        backgroundColor: MetroColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 24, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? const Center(child: PowerfulLoader(message: 'MENGONFIGURASI SISTEM...')) 
        : (isLandscape 
            ? Row(
                children: [
                  Expanded(flex: 6, child: _buildActionPanel()),
                  Expanded(flex: 4, child: _buildLogPanel()),
                ],
              )
            : Column(
                children: [
                  Expanded(child: _buildActionPanel()),
                  SizedBox(height: 200, child: _buildLogPanel()),
                ],
              )
          ),
    );
  }

  Widget _buildActionPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoHero(),
          const SizedBox(height: 32),
          if (_isActivated)
            _buildActivatedLockCard()
          else ...[
            _buildActivationWizard(),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showAdvancedMode = !_showAdvancedMode),
                icon: Icon(
                  _showAdvancedMode ? Icons.expand_less : Icons.build_circle_outlined,
                  size: 18,
                ),
                label: Text(
                  _showAdvancedMode
                      ? 'Sembunyikan pengaturan lanjutan'
                      : 'Pengaturan lanjutan (untuk teknisi)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            if (_showAdvancedMode) ...[
              const SizedBox(height: 8),
              _buildAdvancedOptionsSection(),
            ],
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildActivatedLockCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'PERANGKAT TELAH DIAKTIVASI',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: MetroColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Perangkat ini sudah terhubung ke server secara aman. Untuk mencegah kehilangan data akibat perubahan konfigurasi yang tidak disengaja, fitur aktivasi telah dikunci.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          const Text(
            'JIKA ANDA INGIN MENGGANTI KONEKSI ATAU MERESET PERANGKAT, HARAP UNINSTALL APLIKASI DAN INSTALL KEMBALI.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: MetroColors.error),
          ),
        ],
      ),
    );
  }

  Widget _buildActivationWizard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Langkah ${_wizardStep + 1} dari 3',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: MetroColors.primary,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              ...List.generate(3, (i) {
                final active = i <= _wizardStep;
                return Container(
                  width: 28,
                  height: 4,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: active ? MetroColors.primary : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _wizardStep == 0
                ? 'Pilih server bisnis Anda'
                : _wizardStep == 1
                    ? 'Masukkan kode aktivasi'
                    : 'Konfirmasi dan aktivasi',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: MetroColors.text,
            ),
          ),
          const SizedBox(height: 20),
          if (_wizardStep == 0) _buildWizardStep1(),
          if (_wizardStep == 1) _buildWizardStep2(),
          if (_wizardStep == 2) _buildWizardStep3(),
          const SizedBox(height: 24),
          Row(
            children: [
              if (_wizardStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _wizardBack,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('KEMBALI', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              if (_wizardStep > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _wizardStep < 2 ? _wizardNext : _confirmAndActivate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetroColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _wizardStep < 2 ? 'LANJUT' : 'AKTIVASI SEKARANG',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWizardStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih server tempat data bisnis Anda disimpan.',
          style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _serverMode,
          decoration: InputDecoration(
            fillColor: const Color(0xFFF9FAFB),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: 'server1',
              child: Text('Server DonaPOS Utama', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            DropdownMenuItem(
              value: 'server2',
              child: Text('Server DonaPOS Alternatif', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            DropdownMenuItem(
              value: 'custom',
              child: Text('Lainnya (alamat khusus)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
          onChanged: (val) {
            setState(() {
              _serverMode = val!;
              _connectionVerified = false;
              _connectionStatusMessage = null;
              if (_serverMode == 'server1') {
                _urlController.text = 'https://donapos.serverzone.web.id/public';
              } else if (_serverMode == 'server2') {
                _urlController.text = 'https://app.donapos.biz.id/public';
              } else if (_urlController.text ==
                      'https://donapos.serverzone.web.id/public' ||
                  _urlController.text == 'https://app.donapos.biz.id/public') {
                _urlController.text = '';
              }
            });
          },
        ),
        if (_serverMode == 'custom') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            onChanged: (_) => setState(() {
              _connectionVerified = false;
              _connectionStatusMessage = null;
            }),
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'https://alamat-server-anda/public',
              fillColor: const Color(0xFFF9FAFB),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWizardStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Masukkan kode 9 karakter dari admin atau backoffice DonaPOS.',
          style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _activationCodeController,
          inputFormatters: [ActivationCodeFormatter()],
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            color: MetroColors.primary,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'XXX-XXX-XXX',
            hintStyle: TextStyle(color: Colors.grey.shade300),
            fillColor: const Color(0xFFF9FAFB),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _wizardCheckConnection,
            icon: const Icon(Icons.wifi_tethering),
            label: const Text(
              'CEK KONEKSI',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_connectionStatusMessage != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _connectionVerified ? Icons.check_circle : Icons.error_outline,
                color: _connectionVerified ? Colors.green : MetroColors.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ActivationMessages.userMessage(_connectionStatusMessage),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _connectionVerified ? Colors.green.shade800 : MetroColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildWizardStep3() {
    final code = _normalizedActivationCode();
    final masked = code.length >= 3
        ? '${code.substring(0, 3)}-***-***'
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Periksa ringkasan di bawah. Setelah aktivasi, data lama di tablet akan diganti dengan data dari server.',
          style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildSummaryRow('Server', _serverDisplayLabel()),
              const SizedBox(height: 8),
              _buildSummaryRow('Kode aktivasi', masked),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Koneksi',
                _connectionVerified ? 'Sudah dicek — OK' : 'Belum dicek',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'NAMA LOKASI / KETERANGAN PERANGKAT (OPSIONAL)',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1,
            color: Colors.black38,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'Contoh: Kasir Depan, Tablet 2',
            fillColor: const Color(0xFFF9FAFB),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black45,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: MetroColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MetroColors.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MetroColors.error.withOpacity(0.2)),
          ),
          child: const Text(
            'Area ini hanya untuk teknisi. Salah konfigurasi dapat menghapus data penjualan.',
            style: TextStyle(
              color: MetroColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                title: 'MODE DEMO / TRAINING',
                subtitle: 'Latihan tanpa server',
                icon: Icons.model_training,
                color: Colors.orange,
                isActive: _isDemoMode,
                onTap: () => _toggleDemoMode(!_isDemoMode),
                trailing: Switch(
                  value: _isDemoMode,
                  onChanged: _toggleDemoMode,
                  activeColor: Colors.orange,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFeatureCard(
                title: 'INFO DEMO VENDOR',
                subtitle: 'Buka website',
                icon: Icons.auto_awesome,
                color: Colors.blue,
                onTap: _openDemoWebsite,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: MetroColors.error.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetroColors.error.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESET TOTAL',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: MetroColors.error,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Hapus semua data lokal dan reset koneksi manual.',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetroColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: _finalizeSetup,
                icon: const Icon(Icons.delete_forever),
                label: const Text('RESET', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text(
            'KONFIGURASI TEKNIS (MANUAL)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.black.withOpacity(0.02),
              child: Column(
                children: [
                  _buildField('BASE URL', _urlController),
                  const SizedBox(height: 16),
                  _buildField('CLIENT ID', _clientIdController),
                  const SizedBox(height: 16),
                  _buildField('CLIENT SECRET', _clientSecretController),
                  const SizedBox(height: 16),
                  _buildField('LOCATION ID', _locationIdController),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _checkUrl,
                        child: const Text('UJI URL', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      OutlinedButton(
                        onPressed: _pasteConfig,
                        child: const Text('TEMPEL JSON', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      OutlinedButton(
                        onPressed: _uploadConfigFile,
                        child: const Text('IMPORT FILE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      OutlinedButton(
                        onPressed: _resetFields,
                        child: const Text('KOSONGKAN', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.black26,
            child: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 12),
                const Text('ACTIVATION LOG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                const Spacer(),
                if (!_isActivated)
                  GestureDetector(
                    onTap: () => setState(() => _logs.clear()),
                    child: const Text('CLEAR', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _logs.isEmpty 
              ? const Center(child: Text('LOG KOSONG', style: TextStyle(color: Colors.white12, fontWeight: FontWeight.bold, fontSize: 10)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    Color color = Colors.white70;
                    if (log['type'] == 'error') color = Colors.redAccent;
                    else if (log['type'] == 'success') color = Colors.greenAccent;
                    else if (log['type'] == 'info') color = Colors.blueAccent;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: "[${log['time']}] ", style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
                            TextSpan(text: log['message'], style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace', height: 1.4)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    Widget? trailing,
    Widget? bottom,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? color : Colors.black.withOpacity(0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
            if (bottom != null) ...[
                const SizedBox(height: 12),
                bottom,
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [MetroColors.primary, MetroColors.primary.withBlue(255)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch, color: Colors.white, size: 48),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Siap Memulai?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                const SizedBox(height: 4),
                Text('VERSI ${AppConfig.appVersion} • BUILD ${AppConfig.buildNumber}', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Text('Ikuti 3 langkah: pilih server, masukkan kode, lalu aktivasi.', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: MetroColors.text, fontSize: 14, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            fillColor: Colors.white,
            filled: true,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.black.withOpacity(0.05))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: MetroColors.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildStaticInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold)),
          Text(value.isEmpty ? '-' : value.toUpperCase(), style: const TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }
}

class ActivationCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove dashes to count actual characters
    String cleanText = newValue.text.replaceAll('-', '').toUpperCase();
    
    // Limit to 9 characters
    if (cleanText.length > 9) {
      cleanText = cleanText.substring(0, 9);
    }

    String newText = '';
    for (int i = 0; i < cleanText.length; i++) {
        if (i > 0 && i % 3 == 0) {
            newText += '-';
        }
        newText += cleanText[i];
    }
    
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
