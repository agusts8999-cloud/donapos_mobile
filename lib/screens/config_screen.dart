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
  final List<Map<String, dynamic>> _logs = []; // Activation Log
  String _serverMode = 'server1';

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

  Future<void> _activateByCode() async {
    if (_urlController.text.isEmpty || _activationCodeController.text.isEmpty) {
      showAppModal(
        context, 
        title: 'DATA KURANG', 
        message: 'MOHON ISI BASE URL DAN KODE AKTIVASI.', 
        isError: true
      );
      return;
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
        _activationCodeController.text.trim(),
        locationInfo: sentLocationInfo,
        ip: finalIp
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
            await showAppModal(
              context, 
              title: 'SIAP DIGUNAKAN', 
              message: 'AKTIVASI BERHASIL.\nBISNIS: ${_businessNameController.text}\nUSER: $userCount'
            );
            Navigator.pop(context, true); 
        }

      } else {
        throw result['message'] ?? 'Gagal aktivasi';
      }

    } catch (e) {
      setState(() => _isLoading = false);
      _addLog('ERROR: $e', isError: true);
      if (mounted) {
        showAppModal(
          context, 
          title: 'AKTIVASI GAGAL', 
          message: e.toString(), 
          isError: true
        );
      }
    }
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
          
          // ROW 1: DEMO & TRAINING
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  title: 'FITUR DEMO / TRAINING MODE',
                  subtitle: 'Latihan tanpa terhubung ke server',
                  icon: Icons.model_training,
                  color: Colors.orange,
                  isActive: _isDemoMode,
                  onTap: () => _toggleDemoMode(!_isDemoMode),
                  trailing: Switch(
                      value: _isDemoMode, 
                      onChanged: _toggleDemoMode,
                      activeColor: Colors.orange,
                  ),
                  bottom: !_isDemoMode ? Row(
                    children: [
                        SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                                value: _useCurrentAsDemo, 
                                activeColor: Colors.orange,
                                onChanged: (v) => setState(() => _useCurrentAsDemo = v ?? false)
                            ),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                            child: Text('GUNAKAN DATA SAAT INI', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.blueGrey))
                        )
                    ],
                  ) : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFeatureCard(
                  title: 'AKTIVASI DATA DEMO',
                  subtitle: 'Info hubungi vendor',
                  icon: Icons.auto_awesome,
                  color: Colors.blue,
                  onTap: _openDemoWebsite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ROW 2: ACTIVATION
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PILIH SERVER (BASE URL)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1, color: Colors.black38)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _serverMode,
                  decoration: InputDecoration(
                    fillColor: const Color(0xFFF9FAFB),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'server1', child: Text('donapos.serverzone.web.id', style: TextStyle(fontWeight: FontWeight.bold))),
                    DropdownMenuItem(value: 'server2', child: Text('app.donapos.biz.id', style: TextStyle(fontWeight: FontWeight.bold))),
                    DropdownMenuItem(value: 'custom', child: Text('Kustom (https://...)', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _serverMode = val!;
                      if (_serverMode == 'server1') {
                        _urlController.text = 'https://donapos.serverzone.web.id/public';
                      } else if (_serverMode == 'server2') {
                        _urlController.text = 'https://app.donapos.biz.id/public';
                      } else if (_urlController.text == 'https://donapos.serverzone.web.id/public' || _urlController.text == 'https://app.donapos.biz.id/public') {
                        _urlController.text = ''; // Kosongkan agar bisa diisi custom
                      }
                    });
                  },
                ),
                if (_serverMode == 'custom') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      fillColor: const Color(0xFFF9FAFB),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  )
                ],
                const SizedBox(height: 16),
                
                const Text('KODE AKTIVASI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1, color: Colors.black38)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _activationCodeController,
                        inputFormatters: [ActivationCodeFormatter()],
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4, color: MetroColors.primary),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'XXX-XXX-XXX',
                          hintStyle: TextStyle(color: Colors.grey.shade300),
                          fillColor: const Color(0xFFF9FAFB),
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Location Note Input
                const Text('NAMA LOKASI / KETERANGAN PERANGKAT (OPSIONAL)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1, color: Colors.black38)),
                const SizedBox(height: 8),
                TextField(
                   controller: _noteController,
                   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                   decoration: InputDecoration(
                     hintText: 'Contoh: Kasir Depan, Tablet Gudang, dll.',
                     hintStyle: TextStyle(color: Colors.grey.shade300),
                     fillColor: const Color(0xFFF9FAFB),
                     filled: true,
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                   ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 64,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MetroColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                          ),
                          onPressed: _activateByCode,
                          child: const Text('AKTIVASI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Masukan kode dari DonaPOS Aktivasi atau Admin Anda.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ROW 3: RESET / FINALIZATION
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
                      Text('UPDATE & HAPUS SEMUA DATA', style: TextStyle(fontWeight: FontWeight.w900, color: MetroColors.error, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('Tindakan ini akan mereset aplikasi ke kondisi pabrik.', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetroColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  onPressed: _finalizeSetup,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('RESET TOTAL', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),
          
          // TECHNICAL INFO (EXPANDABLE)
          ExpansionTile(
            title: const Text('INFORMASI TEKNIS SERVER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                color: Colors.black.withOpacity(0.02),
                child: Column(
                  children: [
                    _buildField('BASE URL', _urlController),
                    const SizedBox(height: 20),
                    _buildField('CLIENT ID', _clientIdController),
                    const SizedBox(height: 20),
                    _buildField('CLIENT SECRET', _clientSecretController),
                    const SizedBox(height: 20),
                    _buildField('LOCATION ID', _locationIdController),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildStaticInfo('NAMA BISNIS', _businessNameController.text),
                    _buildStaticInfo('NAMA LOKASI/OUTLET', _locationNameController.text),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
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
                Text('Sambungkan perangkat Anda ke ekosistem DonaPOS hanya dengan satu kode.', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, height: 1.5)),
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
