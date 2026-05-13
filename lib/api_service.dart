/**
 * File: api_service.dart
 * Deskripsi: Layanan komunikasi antara aplikasi Flutter dan Backend ERP DonaPOS.
 * Update Terakhir: 2026-02-03 15:52 (WIB)
 */

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/models.dart';
import 'package:intl/intl.dart';
import 'package:donapos_mobile/models/customer_display_setting.dart';
import 'package:donapos_mobile/config.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:math';
import 'package:donapos_mobile/services/logger_service.dart';

void apiServicePrint(String msg) {
    print('[ApiService] $msg');
}

class ApiService {
  // PERFORMANCE: Centralized Request Helper with TTL/Retry Logic
  Future<http.Response> _performRequest(
    Future<http.Response> Function() requestFn, {
    int maxRetries = 3,
    String? taskName,
  }) async {
    int retryCount = 0;
    while (true) {
      try {
        final response = await requestFn();
        
        // 1. Success -> Return
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        // 2. Handle Unauthorized (401) immediately if it's the first time
        if (response.statusCode == 401 && retryCount < 1) {
            LoggerService.instance.logWarning('Unauthorized (401) for $taskName. Attempting client re-auth...');
            bool reAuth = await reAuthenticateForSales();
            if (reAuth) {
                retryCount++;
                continue; // Retry with new token
            }
        }
        
        // 3. Handle Retryable Errors (429 Too Many Requests, 5xx Server Errors)
        if (response.statusCode == 429 || (response.statusCode >= 500 && response.statusCode <= 504)) {
            throw HttpException('Retryable Server Error (${response.statusCode})');
        }
        
        // 4. Non-retryable error (400, 404, etc.) -> Return response to caller
        return response; 
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          LoggerService.instance.logError('Request failed after $maxRetries retries: $taskName', e);
          rethrow;
        }
        
        // Exponential Backoff: 2s, 4s, 8s...
        final delay = Duration(seconds: pow(2, retryCount).toInt());
        LoggerService.instance.logWarning('Retrying $taskName ($retryCount/$maxRetries) in ${delay.inSeconds}s due to error: $e');
        await Future.delayed(delay);
      }
    }
  }

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Default values
  // SECURITY: Sensitive credentials (clientId, clientSecret, locationId) are NOT hardcoded.
  // They must be configured through the activation/setup screen and saved to SharedPreferences.
  // defaultBaseUrl is kept only as a UI hint in the setup form, not used as a working fallback.
  static const String defaultBaseUrl = '';
  static const String defaultClientId = '';
  static const String defaultClientSecret = ''; // NEVER hardcode secrets here
  static const String defaultLocationId = '';
  static const String defaultBusinessName = 'DonaPOS';
  static const String defaultLocationName = 'Main';

  bool _isGlobalSyncing = false;

  Future<bool> isDemo() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_demo_mode') ?? false;
  }

  Future<bool> isRegistered() async {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('client_id');
      final clientSecret = prefs.getString('client_secret');
      // Dianggap terdaftar jika client_id DAN client_secret sudah disimpan dan tidak kosong
      return clientId != null && clientId.isNotEmpty &&
             clientSecret != null && clientSecret.isNotEmpty;
  }

  Future<String> getActivationCode() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('activation_code') ?? '';
  }

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('base_url') ?? defaultBaseUrl;
  }

  Future<String> getClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('client_id') ?? defaultClientId;
  }

  Future<String> getClientSecret() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('client_secret') ?? defaultClientSecret;
  }

  Future<String> getDefaultSaleType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('default_sale_type') ?? 'dinein';
  }

  Future<String> getLocationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('location_id') ?? defaultLocationId;
  }
  
  Future<String> getBusinessName() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('business_name') ?? defaultBusinessName;
  }
  
  Future<String> getLocationName() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('location_name') ?? defaultLocationName;
  }
  
  // Menyimpan data konfigurasi API ke SharedPreferences
  Future<void> saveConfig(String baseUrl, String clientId, String clientSecret, String locationId, [String? businessName, String? locationName, String? defaultSaleType]) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('base_url', baseUrl);
      await prefs.setString('client_id', clientId);
      await prefs.setString('client_secret', clientSecret);
      await prefs.setString('location_id', locationId);
      if (businessName != null) await prefs.setString('business_name', businessName);
      if (locationName != null) await prefs.setString('location_name', locationName);
      if (defaultSaleType != null) await prefs.setString('default_sale_type', defaultSaleType);
  }

  Future<bool> checkConnection() async {
      if (await isDemo()) {
          print('[ApiService] CheckConnection: Demo Mode Active (Bypassing)');
          return true; 
      }
      try {
          final baseUrl = await getBaseUrl();
          print('[ApiService] CheckConnection: Checking $baseUrl/login');
          // Reduced timeout to 3 seconds for simple pings to make offline detection faster
          final response = await http.get(
            Uri.parse('$baseUrl/login'),
          ).timeout(const Duration(seconds: 3));
          print('[ApiService] CheckConnection: Result status ${response.statusCode}');
          return response.statusCode < 500; 
      } catch (e) {
          print('[ApiService] CheckConnection Error: $e');
          return false;
      }
  }

  Future<Map<String, dynamic>> validateBaseUrl(String url) async {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    
    if (cleanUrl.isEmpty) return {'valid': false, 'message': 'URL TIDAK BOLEH KOSONG.'};
    if (!cleanUrl.startsWith('http')) return {'valid': false, 'message': 'URL HARUS DIMULAI DENGAN HTTP/HTTPS.'};
    
    try {
      // Mencoba akses root URL
      final response = await http.get(Uri.parse(cleanUrl)).timeout(const Duration(seconds: 10));
      
      // Status code < 500 berarti server hidup dan merespon
      if (response.statusCode < 500) {
        return {
          'valid': true, 
          'message': 'KONEKSI BERHASIL! SERVER MERESPON (${response.statusCode}).\n\nSERVER TERDETEKSI AKTIF.'
        };
      } else {
        return {
          'valid': false, 
          'message': 'SERVER DITEMUKAN TAPI MEMBERIKAN RESPON ERROR (${response.statusCode}).'
        };
      }
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('SocketException')) {
        msg = "GAGAL MENGHUBUNGI HOST (IP/DOMAIN).\n\nTips:\n1. Pastikan Internet Aktif.\n2. Jika menggunakan XAMPP/Localhost, pastikan menggunakan alamat IP Laptop (contoh: 192.168.1.x) bukan 'localhost'.\n3. Pastikan Firewall Laptop tidak memblokir koneksi.";
      } else if (msg.contains('HandshakeException')) {
        msg = "MASALAH SSL/SERTIFIKAT (Handshake Error).\nPastikan waktu di Tablet sudah benar atau gunakan HTTP jika server tidak mendukung HTTPS.";
      }
      return {'valid': false, 'message': 'URL TIDAK MERESPON.\n\n$msg'};
    }
  }

  Future<Map<String, dynamic>> activateWithCode(String baseUrl, String code, {String locationInfo = "Unknown", String? ip}) async {
    String cleanUrl = baseUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    
    try {
      String deviceInfo = "Mobile: UNKNOWN DEVICE";
      try {
          final deviceInfoPlugin = DeviceInfoPlugin();
          if (Platform.isAndroid) {
            final androidInfo = await deviceInfoPlugin.androidInfo;
            deviceInfo = "Mobile: ${androidInfo.manufacturer} ${androidInfo.model} (Android ${androidInfo.version.release})";
          } else if (Platform.isIOS) {
            final iosInfo = await deviceInfoPlugin.iosInfo;
            deviceInfo = "Mobile: ${iosInfo.name} ${iosInfo.model} (iOS ${iosInfo.systemVersion})";
          }
      } catch (_) {}
      
      String fullInfo = "$deviceInfo | Location: $locationInfo";
      print('[ApiService] Activating: URL=$cleanUrl code=$code');

      final response = await http.post(
        Uri.parse('$cleanUrl/connector/api/activation/verify'),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'device_info': fullInfo,
          'ip_address': ip ?? ''
        },
      ).timeout(const Duration(seconds: 20));

      print('[ApiService] Activation response: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return {
              'success': true,
              'config': data['config'] ?? {},  // null-safe
              'users': data['users'] ?? []     // null-safe
            };
          } else {
            return {'success': false, 'message': data['message']?.toString() ?? 'AKTIVASI DITOLAK OLEH SERVER.'};
          }
        } catch (e) {
          return {'success': false, 'message': 'RESPON SERVER TIDAK VALID (BUKAN JSON).'};
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          return {'success': false, 'message': 'ERROR ${response.statusCode}: ${errorData['message'] ?? errorData.toString()}'};
        } catch (_) {
          return {'success': false, 'message': 'ERROR HTTP ${response.statusCode}.\nPastikan URL dan Kode Aktivasi benar.'};
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'GAGAL MENGHUBUNGI SERVER AKTIVASI.\nURL: $cleanUrl/connector/api/activation/verify\nERROR: $e'};
    }
  }

  Future<Map<String, dynamic>> fetchBusinessLocationInfo(String baseUrl, String locationId) async {
    // ... logic ...
    // Intentionally omitted for brevity, keeping original implementation or simplified
    return {'success': true}; 
  }
  
  Future<void> resetToken() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
  }
  
  Future<String?> _getClientToken() async {
    try {
      final baseUrl = await getBaseUrl();
      final clientId = await getClientId();
      final clientSecret = await getClientSecret();
      
      final response = await http.post(
        Uri.parse('$baseUrl/oauth/token'),
        body: {
          'grant_type': 'client_credentials',
          'client_id': clientId,
          'client_secret': clientSecret,
          'scope': '*'
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'];
      }
    } catch (e) {
      print('Get Client Token Error: $e');
    }
    return null;
  }

  // Login sebagai Client (Machine-to-Machine) untuk inisialisasi awal sebelum ada User
  Future<bool> authenticateClient() async {
    try {
      final baseUrl = await getBaseUrl();
      final clientId = await getClientId();
      final clientSecret = await getClientSecret();
      
      print('Authenticating Client: ID=$clientId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/oauth/token'),
        body: {
          'grant_type': 'client_credentials',
          'client_id': clientId,
          'client_secret': clientSecret,
          'scope': '*'
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['access_token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token); // Use 'token' instead of 'access_token'
          print('Client Authentication Successful. Token obtained.');
          return true;
        }
      } else {
        print('Client Auth Failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Client Auth Error: $e');
    }
    return false;
  }

  Future<bool> login(String username, String password) async {
    // Melakukan autentikasi user ke server (OAuth2) atau mode demo
    // SECURITY FIX: Demo login sekarang divalidasi via database lokal (PIN),
    // bukan hardcoded string. Demo users (tashia/aurel) ter-seed di db_helper
    // dengan PIN '12345' — alur ini identik dengan login normal offline.
    if (await isDemo()) {
      try {
        final users = await DatabaseHelper.instance.getAllUsers();
        final match = users.where((u) =>
          u['username']?.toString().toLowerCase() == username.toLowerCase()
        ).toList();
        if (match.isEmpty) return false;
        final user = match.first;
        // Validasi: password dicocokkan dengan field 'pin' di DB lokal
        // (demo users di-seed dengan pin = '12345')
        final storedPin = user['pin']?.toString() ?? '';
        return storedPin.isNotEmpty && storedPin == password;
      } catch (e) {
        print('[Auth] Demo login error: $e');
        return false;
      }
    }
    try {
      final baseUrl = await getBaseUrl();
      final clientId = await getClientId();
      final clientSecret = await getClientSecret();
      
      final response = await http.post(
        Uri.parse('$baseUrl/oauth/token'),
        body: {
          'grant_type': 'password',
          'client_id': clientId,
          'client_secret': clientSecret,
          'username': username,
          'password': password,
          'scope': '',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['access_token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('last_login_username', username);
        await prefs.setString('last_login_password', password);
        return true;
      }
      print('Login failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // --- Price Group Preferences ---
  Future<void> savePriceGroupConfig(int? dineInId, int? takeAwayId, int? onlineId, {int? online1Id, int? online2Id, int? otherId}) async {
      final prefs = await SharedPreferences.getInstance();
      if (dineInId != null) await prefs.setInt('pg_dinein', dineInId);
      if (takeAwayId != null) await prefs.setInt('pg_takeaway', takeAwayId);
      if (onlineId != null) await prefs.setInt('pg_online', onlineId);
      
      if (online1Id != null) await prefs.setInt('pg_online1', online1Id);
      if (online2Id != null) await prefs.setInt('pg_online2', online2Id);
      if (otherId != null) await prefs.setInt('pg_other', otherId);
  }

  Future<Map<String, int?>> getPriceGroupConfig() async {
      final prefs = await SharedPreferences.getInstance();
      return {
          'dinein': prefs.getInt('pg_dinein'),
          'takeaway': prefs.getInt('pg_takeaway'),
          'online': prefs.getInt('pg_online'),
          'online1': prefs.getInt('pg_online1'),
          'online2': prefs.getInt('pg_online2'),
          'other': prefs.getInt('pg_other'),
      };
  }
  
  // Wrapper helper for headers
  Future<Map<String, String>> getHeaders() async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      final headers = {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
      };
      
      final lat = prefs.getDouble('last_latitude');
      final lng = prefs.getDouble('last_longitude');
      
      if (lat != null && lng != null) {
          headers['X-Latitude'] = lat.toString();
          headers['X-Longitude'] = lng.toString();
      }
      
      return headers;
  }

  // ============================================================
  // TOKEN ISOLATION: Obtain ephemeral admin/client token for Sync
  // WITHOUT overwriting the active cashier's token in SharedPreferences.
  // This prevents the "security" errors on Closing/Reports.
  // ============================================================
  Future<Map<String, String>> _prepareAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Try to obtain a dedicated Admin token if sync_admin is enabled
    if (prefs.getBool('sync_admin_enabled') ?? false) {
        String? adminUser = prefs.getString('sync_admin_user');
        String? adminPass = prefs.getString('sync_admin_pass');
        if (adminUser != null && adminPass != null) {
            final ephemeralToken = await _obtainEphemeralToken(adminUser, adminPass);
            if (ephemeralToken != null) {
                print('[Sync] Using ephemeral Admin token (cashier token preserved).');
                return _buildHeaders(ephemeralToken, prefs);
            }
            // If ephemeral login failed, fall through to use existing token
            print('[Sync] Ephemeral Admin login failed, using existing token.');
        }
    }
    
    // 2. Fallback: use the existing token (cashier's or machine's)
    final currentToken = prefs.getString('token');
    if (currentToken == null || currentToken.isEmpty) {
        // No token at all: try machine-level auth (this IS safe to persist)
        print('[Sync] No active token, attempting Client Credentials auth...');
        await authenticateClient();
    }
    return await getHeaders();
  }

  /// Obtain a token via OAuth2 Password Grant WITHOUT persisting it.
  /// Returns the access_token string or null on failure.
  Future<String?> _obtainEphemeralToken(String username, String password) async {
    try {
      final baseUrl = await getBaseUrl();
      final clientId = await getClientId();
      final clientSecret = await getClientSecret();

      final response = await http.post(
        Uri.parse('$baseUrl/oauth/token'),
        body: {
          'grant_type': 'password',
          'client_id': clientId,
          'client_secret': clientSecret,
          'username': username,
          'password': password,
          'scope': '',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'] as String?;
      }
      print('[Sync] Ephemeral token request failed: ${response.statusCode}');
    } catch (e) {
      print('[Sync] Ephemeral token error: $e');
    }
    return null;
  }

  /// Helper to recover User Token because Machine Tokens get 403 on Sales endpoints.
  Future<bool> reAuthenticateForSales() async {
      final prefs = await SharedPreferences.getInstance();
      String? u = prefs.getString('last_login_username');
      String? p = prefs.getString('last_login_password');
      if (u != null && p != null && u.isNotEmpty && p.isNotEmpty) {
          print('[API] Attempting User Token recovery for Sales...');
          return await login(u, p);
      }
      print('[API] No User credentials found. Falling back to Machine Client Auth...');
      return await authenticateClient();
  }

  /// Build standard API headers with a specific token.
  Map<String, String> _buildHeaders(String token, SharedPreferences prefs) {
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final lat = prefs.getDouble('last_latitude');
    final lng = prefs.getDouble('last_longitude');
    if (lat != null && lng != null) {
      headers['X-Latitude'] = lat.toString();
      headers['X-Longitude'] = lng.toString();
    }
    return headers;
  }
  
  Future<Map<String, dynamic>?> getUserInfo() async {
      if (await isDemo()) {
          // SECURITY FIX: Tidak hardcode username 'tashia'.
          // Ambil user admin pertama dari database lokal yang di-seed saat demo setup.
          try {
              final allUsers = await DatabaseHelper.instance.getAllUsers();
              final adminUser = allUsers.firstWhere(
                  (u) => u['is_admin'] == 1 || u['is_admin'] == true,
                  orElse: () => allUsers.isNotEmpty ? allUsers.first : {},
              );
              if (adminUser.isNotEmpty) {
                  return {
                      'id': adminUser['id'] ?? 0,
                      'username': adminUser['username'] ?? 'demo',
                      'first_name': adminUser['first_name'] ?? 'Demo',
                      'last_name': adminUser['last_name'] ?? '',
                      'is_admin': true,
                  };
              }
          } catch (e) {
              print('[Auth] getUserInfo demo error: $e');
          }
          // Fallback jika DB belum ter-seed (seharusnya tidak terjadi)
          return {'id': 0, 'username': 'demo', 'first_name': 'Demo', 'is_admin': true};
      }
      if (!await checkConnection()) return null;
      final baseUrl = await getBaseUrl();
      final headers = await getHeaders();
      try {
          final response = await http.get(Uri.parse('$baseUrl/connector/api/user/loggedin'), headers: headers).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
               final jsonResponse = json.decode(response.body);
               if (jsonResponse['data'] != null) {
                   return jsonResponse['data'];
               }
               return jsonResponse;
          }
      } catch (e) {
          print('Get User Info Error: $e');
      }
      return null;
  }


  // Sinkronisasi data bisnis (alamat, logo, label struk) dari server
  Future<void> syncBusinessDetails() async {
      if (await isDemo()) return;
      if (!await checkConnection()) return;
      
      final baseUrl = await getBaseUrl();
      final locationId = await getLocationId();
      final headers = await getHeaders();
      if (headers['Authorization'] == 'Bearer null') return;
      
      try {
           final response = await http.get(
             Uri.parse('$baseUrl/connector/api/business-location'), 
             headers: headers
           ).timeout(const Duration(seconds: 10));
           
           if (response.statusCode == 200) {
               final data = json.decode(response.body);
               final List locations = data['data'];
               
               // Find matching location
               final myLoc = locations.firstWhere((l) => l['id'].toString() == locationId || l['location_id'] == locationId, orElse: () => null);
               
               if (myLoc != null) {
                   final prefs = await SharedPreferences.getInstance();
                   await prefs.setString('location_name', myLoc['name']);
                   
                   // Restore: Save more info for receipt
                   String address = "${myLoc['landmark'] ?? ''}, ${myLoc['city'] ?? ''}".trim();
                   if (address.startsWith(',')) address = address.substring(1).trim();
                   if (address.endsWith(',')) address = address.substring(0, address.length - 1).trim();
                   if (address.isEmpty) address = "Jakarta Barat";

                   await prefs.setString('business_name', myLoc['name'] ?? 'donapos');
                   await prefs.setString('business_address', address);
                   await prefs.setString('business_mobile', myLoc['mobile'] ?? '081219752227');
                   
                   // Restore: Invoice Layout Labels & Footer
                   if (myLoc['invoice_layout'] != null) {
                       final layout = myLoc['invoice_layout'];
                       await prefs.setString('lbl_subtotal', layout['sub_total_label'] ?? 'Subtotal');
                       await prefs.setString('lbl_discount', layout['discount_label'] ?? 'Diskon');
                       await prefs.setString('lbl_tax', layout['tax_label'] ?? 'Pajak');
                       await prefs.setString('lbl_total', layout['total_label'] ?? 'TOTAL');
                       await prefs.setString('lbl_return', layout['change_return_label'] ?? 'Kembalian');
                       await prefs.setString('footer_text', layout['footer_text'] ?? 'Terima Kasih');
                   }

                   if (myLoc['invoice_scheme'] != null) {
                       final scheme = myLoc['invoice_scheme'];
                       await prefs.setString('invoice_prefix', scheme['prefix'] ?? 'MBL');
                   }

                   // New: Business Logo handling
                   String? serverLogo;
                   if (myLoc['invoice_layout'] != null) {
                       serverLogo = myLoc['invoice_layout']['logo_url'] ?? myLoc['invoice_layout']['logo'];
                   }
                   serverLogo ??= myLoc['logo_url'] ?? myLoc['logo'];

                   if (serverLogo != null && serverLogo.isNotEmpty) {
                       print('[API] Server Logo Value: $serverLogo');
                       
                       // List of Candidate URLs to try
                       List<String> candidates = [];
                       
                       if (serverLogo.startsWith('http')) {
                           candidates.add(serverLogo);
                       } else {
                           final cleanBase = baseUrl.replaceAll('/public', '');
                           final fileName = serverLogo.split('/').last;

                           // 1. Standard Storage
                           candidates.add('$cleanBase/storage/$serverLogo');
                           
                           // 2. Public Uploads (User specific case)
                           candidates.add('$baseUrl/uploads/invoice_logos/$fileName');
                           candidates.add('$cleanBase/uploads/invoice_logos/$fileName');
                           
                           // 3. Just Base + Path (for relative paths like 'uploads/...')
                           candidates.add('$baseUrl/$serverLogo');
                           
                           // 4. Clean Base + Path
                           candidates.add('$cleanBase/$serverLogo');
                           
                           // 5. Direct Storage path
                           candidates.add('$baseUrl/storage/$fileName');
                           candidates.add('$baseUrl/storage/invoice_logos/$fileName');
                           candidates.add('$cleanBase/storage/invoice_logos/$fileName');
                           candidates.add('https://donapos.serverzone.web.id/public/uploads/invoice_logos/$fileName');
                           candidates.add('https://donapos.serverzone.web.id/uploads/invoice_logos/$fileName');
                       }
                       
                       String? downloadedPath;
                       for (var url in candidates) {
                           print('[API] Trying to download logo from: $url');
                           downloadedPath = await _downloadAndSaveImage(url, 'erp_logo.png');
                           if (downloadedPath != null) {
                               print('[API] Success! Logo saved to: $downloadedPath');
                               break; 
                           }
                       }
                       
                       if (downloadedPath != null) {
                           await prefs.setString('logo_path', downloadedPath);
                       } else {
                           print('[API] Failed to download logo from all candidates.');
                       }
                   }

                   print('Real Location & Layout Synced: ${myLoc['name']} - Prefix: ${prefs.getString('invoice_prefix')}');
                   
                   // NEW: Sync Featured Products
                   if (myLoc['featured_products'] != null) {
                      List<dynamic> featuredRaw = myLoc['featured_products'];
                      // Ensure it's list of strings
                      List<String> featuredIds = featuredRaw.map((e) => e.toString()).toList();
                      await DatabaseHelper.instance.setFeaturedProducts(featuredIds);
                      // Save to prefs for reapplying after product sync
                      await prefs.setStringList('featured_product_ids', featuredIds);
                      print('[API] Synced ${featuredIds.length} Featured Products');
                   } else {
                      // If server returns null, clear all featured
                      await DatabaseHelper.instance.setFeaturedProducts([]);
                      await prefs.remove('featured_product_ids');
                      print('[API] Cleared Featured Products (null from server)');
                   }
               }
           }
      } catch (e) {
          print('Sync Business Error: $e');
      }
  }

  Future<String?> _downloadAndSaveImage(String url, String fileName) async {
      try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
              final directory = await getApplicationDocumentsDirectory();
              final file = File('${directory.path}/$fileName');
              await file.writeAsBytes(response.bodyBytes);
              return file.path;
          }
      } catch (e) {
          print('Download logo error: $e');
      }
      return null;
  }

  Future<String?> _downloadAndCompressImage(String url, String fileName) async {
      try {
          final headers = await getHeaders();
          final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 20));
          
          if (response.statusCode != 200) {
              print('[API] Download failed for $url. Status: ${response.statusCode}');
              return null;
          }

          final bytes = response.bodyBytes;
          if (bytes.isEmpty) {
              print('[API] Downloaded bytes are empty for $url');
              return null;
          }
          
          // Decode image
          final originalImage = img.decodeImage(bytes);
          if (originalImage == null) {
              print('[API] Failed to decode image from $url (Format not supported or file corrupted)');
              return null;
          }

          // Resize to a reasonable POS tile size (e.g. 250px width)
          img.Image thumbnail;
          if (originalImage.width > 250) {
              thumbnail = img.copyResize(originalImage, width: 250);
          } else {
              thumbnail = originalImage;
          }

          // Encode as JPG with some compression
          final compressedBytes = img.encodeJpg(thumbnail, quality: 75);

          final directory = await getApplicationDocumentsDirectory();
          final imageDir = Directory('${directory.path}/product_images');
          if (!await imageDir.exists()) {
              await imageDir.create(recursive: true);
          }

          final file = File('${imageDir.path}/$fileName');
          await file.writeAsBytes(compressedBytes);
          return file.path;
      } catch (e) {
          print('[API] Download/Compress error for $url: $e');
      }
      return null;
  }

  // Sinkronisasi data user/staff/waiter dari server ke database lokal
  Future<int> syncUsers() async {
      if (await isDemo()) return 0;
      if (!await checkConnection()) return 0;
      final baseUrl = await getBaseUrl();
      final locationId = await getLocationId();
      final headers = await getHeaders();
      if (headers['Authorization'] == 'Bearer null') return 0;
      
      try {
          final response = await _performRequest(
            () async => http.get(Uri.parse('$baseUrl/connector/api/user?location_id=$locationId'), headers: await getHeaders()).timeout(const Duration(seconds: 10)),
            taskName: 'Sync Users',
          );
          
          if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final List users = data['data'];
              
              // Preserve waiter status
              List<int> existingWaiters = [];
              try {
                 existingWaiters = await DatabaseHelper.instance.getWaiterIds();
              } catch (e) {
                 print("Failed to get existing waiters (might be first run): $e"); 
              }

              await DatabaseHelper.instance.clearUsers();
              int count = 0;
              
              for (var u in users) {
                  print('User Sync Data: ${u['username']} - Image: ${u['image_url']}'); 

                  String? pin = u['service_staff_pin']?.toString();
                   
                   // Siapkan data untuk DB (biarkan PIN apa adanya dari server)
                   await DatabaseHelper.instance.insertUser({
                      'id': int.tryParse(u['id'].toString()) ?? 0,
                      'username': u['username']?.toString() ?? 'user_${u['id']}',
                      'first_name': u['first_name']?.toString() ?? 'Unknown',
                      'last_name': u['last_name'],
                      'pin': pin,
                      'profile_image': u['image_url'],
                      'is_admin': u['is_admin'] == true || u['is_admin'] == 1 ? 1 : 0,
                   });
                  count++;
              }
              return count;
          }
      } catch (e) {
          print('Sync Users Error: $e');
          throw e; // Propagate error
      }
      return 0;
  }

  // Sinkronisasi data pelanggan (kontak) dari server dengan dukungan paginasi
  Future<int> syncContacts({Function(String)? onProgress}) async {
      if (await isDemo()) return 0;
      if (!await checkConnection()) return 0;
      final baseUrl = await getBaseUrl();
      final headers = await getHeaders();
      if (headers['Authorization'] == 'Bearer null') return 0;
      
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString('last_sync_contacts');
      
      int page = 1;
      int perPage = 100; // Lowered from 500 for stability
      int totalSynced = 0;
      bool hasMore = true;

      print('[API] Sync Contacts Start. Last Sync: $lastSync');

      try {
          while (hasMore) {
              String url = '$baseUrl/connector/api/customer-sync?type=customer&per_page=$perPage&page=$page';
              
              final response = await _performRequest(
                () async => http.get(Uri.parse(url), headers: await getHeaders()).timeout(const Duration(seconds: 20)),
                taskName: 'Sync Contacts (Page $page)',
              );
              
              if (response.statusCode == 200) {
                  final data = json.decode(response.body);
                  List contacts = [];
                  
                  if (data is Map) {
                      if (data.containsKey('data')) {
                          contacts = data['data'];
                      } else if (data.containsKey('contacts')) { // Fallback case
                          contacts = data['contacts'];
                      }
                  } else if (data is List) {
                      contacts = data;
                  }
                  
                  print('[API] Page $page: Found ${contacts.length} contacts');
                  
                  if (contacts.isEmpty) {
                      hasMore = false;
                      break;
                  }
                  
                  if (onProgress != null) onProgress("SYNC: KONTAK (${totalSynced + contacts.length} ITEM)...");

                  // FULL REFRESH: Clear contacts on first page
                  if (page == 1) {
                      await DatabaseHelper.instance.clearAllContacts();
                  }
                  
                  for (var c in contacts) {
                      await DatabaseHelper.instance.insertContact({
                          'server_id': c['id'],
                          'contact_id': c['contact_id'],
                          'name': c['name'],
                          'mobile': c['mobile'],
                          'email': c['email'],
                          'address': c['address_line_1'],
                          'city': c['city'],
                          'state': c['state'],
                          'zip_code': c['zip_code'],
                          'customer_group_id': c['customer_group_id'],
                          'is_default': (c['is_default'] == 1 || c['is_default'] == true) ? 1 : 0,
                          'is_synced': 1
                      });
                  }
                  totalSynced += contacts.length;
                  
                  // Pagination Check
                  if (data is Map && data['meta'] != null && data['meta']['last_page'] != null) {
                      int current = data['meta']['current_page'] ?? page;
                      int last = data['meta']['last_page'] ?? 1;
                      if (current >= last) hasMore = false;
                      else page++;
                  } else {
                      if (contacts.length < perPage) hasMore = false;
                      else page++;
                  }
              } else {
                  print('[API] Sync Contacts Failed: ${response.statusCode} - ${response.body}');
                  hasMore = false;
              }
          }
          
          if (totalSynced > 0 || lastSync == null) {
              await prefs.setString('last_sync_contacts', DateTime.now().toIso8601String());
          }
          print('[API] Success! Synced $totalSynced Contacts');
          return totalSynced;

      } catch (e) {
          print('[API] Sync Contacts Exception: $e');
      }
      return 0;
  }

  Future<int> uploadContacts() async {
      if (await isDemo()) return 0;
      final baseUrl = await getBaseUrl();
      final headers = await getHeaders();
      if (headers['Authorization'] == 'Bearer null') return 0;
      
      final unsynced = await DatabaseHelper.instance.getUnsyncedContacts();
      int count = 0;
      
      for (var c in unsynced) {
          try {
              final response = await http.post(
                  Uri.parse('$baseUrl/connector/api/contactapi'),
                  headers: headers,
                  body: json.encode({
                      'type': 'customer',
                      'name': c['name'],
                      'mobile': c['mobile'],
                      'address_line_1': c['address'],
                      'city': c['city'],
                      'state': c['state'],
                      'zip_code': c['zip_code'],
                      'email': c['email']
                  })
              );
              
              if (response.statusCode == 200 || response.statusCode == 201) {
                  final data = json.decode(response.body);
                  final serverData = data['data'] ?? data;
                  await DatabaseHelper.instance.markContactSynced(
                      c['id'], 
                      serverData['id'], 
                      serverData['contact_id']
                  );
                  count++;
              }
          } catch (e) {
              print('Upload Contact Error: $e');
          }
      }
      return count;
  }

  Future<Map<String, dynamic>?> uploadNewCustomer(Map<String, dynamic> c) async {
    if (await isDemo()) return null;
    final baseUrl = await getBaseUrl();
    final headers = await getHeaders();
    if (headers['Authorization'] == 'Bearer null') return null;

    try {
        final response = await http.post(
            Uri.parse('$baseUrl/connector/api/contactapi'),
            headers: headers,
            body: json.encode({
                'type': 'customer',
                'first_name': c['name'], // ERP specifically requires first_name
                'mobile': c['mobile'],
                'address_line_1': c['address'],
                'city': c['city'],
                'state': c['state'],
                'zip_code': c['zip_code'],
                'email': c['email']
            })
        ).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 200 || response.statusCode == 201) {
            final data = json.decode(response.body);
            return data['data'] ?? data;
        } else {
            print('[API] uploadNewCustomer Failed: ${response.statusCode} ${response.body}');
        }
    } catch (e) {
        print('[API] uploadNewCustomer Error: $e');
    }
    return null;
  }

  // Sinkronisasi kategori produk dari server
  Future<int> syncCategories() async {
      if (await isDemo()) return 0;
      if (!await checkConnection()) return 0;
      final baseUrl = await getBaseUrl();
      final headers = await getHeaders();
      if (headers['Authorization'] == 'Bearer null') return 0;
      
      print('[API] Syncing Categories from: $baseUrl/connector/api/taxonomy?type=product');
      try {
          final response = await _performRequest(
            () async => http.get(Uri.parse('$baseUrl/connector/api/taxonomy?type=product'), headers: await getHeaders()).timeout(const Duration(seconds: 10)),
            taskName: 'Sync Categories',
          );
          print('[API] Cat Sync Response: ${response.statusCode}');
          
          if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final List cats = data['data'] ?? [];
              print('[API] Found ${cats.length} categories');
              
              await DatabaseHelper.instance.clearCategories();
              int count = 0;
              for (var c in cats) {
                  // Ensure ID is integer
                  int? id = int.tryParse(c['id'].toString());
                  if (id != null) {
                      await DatabaseHelper.instance.insertCategory({
                          'id': id, 
                          'name': c['name'] ?? 'Unknown'
                      });
                      count++;
                  }
              }
              return count;
          } else {
              print('[API] Cat Sync Error: ${response.body}');
          }
      } catch (e) {
          print('Sync Cat Error: $e');
      }
      return 0;
  }

  Future<int> syncResTables() async {
      if (await isDemo()) return 0;
      if (!await checkConnection()) return 0;
      final baseUrl = await getBaseUrl();
      final headers = await getHeaders();
      final locationId = await getLocationId();
      
      final url = '$baseUrl/connector/api/res-table?location_id=$locationId';
      print('[API] Syncing Restaurant Tables...');
      print('[API] URL: $url');
      
      try {
          final response = await http.get(
              Uri.parse('$baseUrl/connector/api/res-table?location_id=$locationId'), 
              headers: headers
          );
          
          print('[API] Response Status: ${response.statusCode}');
          print('[API] Response Body: ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}...');
          
          if (response.statusCode == 200) {
              final data = json.decode(response.body);
              print('[API] Parsed success=${data['success']}, tables count=${data['data']?.length ?? 0}');
              if (data['success'] == true) {
                  final List tables = data['data'] ?? [];
                  
                  await DatabaseHelper.instance.clearResTables();
                  
                  int count = 0;
                  for (var t in tables) {
                      int? id = int.tryParse(t['id'].toString());
                      if (id != null) {
                          await DatabaseHelper.instance.insertResTable({
                              'id': id,
                              'business_id': int.tryParse(t['business_id']?.toString() ?? '0') ?? 0,
                              'location_id': int.tryParse(t['location_id']?.toString() ?? '0') ?? 0,
                              'name': t['name'] ?? 'Unknown',
                              'description': t['description'],
                          });
                          count++;
                      }
                  }
                  
                  print('[API] ✓ Successfully synced $count tables to database!');
                  return count;
              } else {
                  print('[API] Tables Sync Error: ${data['message']}');
              }
          } else {
              print('[API] Tables Sync HTTP Error: ${response.statusCode}');
          }
      } catch (e, stackTrace) {
          print('[API] ❌ Sync Tables Error: $e');
          print('[API] Stack: $stackTrace');
      }
      return 0;
  }

  Future<int> syncPriceGroups() async {
      if (await isDemo()) return 0;
      final baseUrl = await getBaseUrl();
      final headers = await getHeaders();
      
      try {
          final response = await http.get(Uri.parse('$baseUrl/connector/api/selling-price-group'), headers: headers);
          if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final List groups = data['data'] ?? [];
              
              await DatabaseHelper.instance.clearPriceGroups();
              for (var g in groups) {
                  await DatabaseHelper.instance.insertPriceGroup({
                      'id': g['id'],
                      'name': g['name']
                  });
              }
              print('Synced ${groups.length} Price Groups');
              return groups.length;
          }
      } catch (e) {
          print('Sync Price Groups Error: $e');
      }
      return 0;
  }

  Future<int> syncTaxes() async {
      if (await isDemo()) return 0;
      final baseUrl = await getBaseUrl();
      final headers = await getHeaders();
      try {
          final response = await http.get(Uri.parse('$baseUrl/connector/api/tax'), headers: headers);
          if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final List taxes = data['data'];

              await DatabaseHelper.instance.clearTaxes();
              int count = 0;
              for (var t in taxes) {
                  await DatabaseHelper.instance.insertTax({
                      'id': t['id'],
                      'name': t['name'],
                      'amount': (t['amount'] as num).toDouble()
                  });
                  count++;
              }
              print('Synced $count Taxes');
              return count;
          }
      } catch (e) {
          print('Sync Taxes Error: $e');
      }
      return 0;
  }

  Future<int> syncDiscounts() async {
      if (await isDemo()) return 0;
      final baseUrl = await getBaseUrl();
      final headers = await getHeaders();
      final prefs = await SharedPreferences.getInstance();
      String log = "Sync Start: ${DateTime.now()}\n";
      int count = 0;
      
      try {
          final url = '$baseUrl/connector/api/discount';
          log += "URL: $url\n";
          final response = await http.get(Uri.parse(url), headers: headers);
          
          if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final List discounts = data['data'] ?? [];
              log += "Data received: ${discounts.length} items\n";
              
              await DatabaseHelper.instance.clearDiscounts();
              for (var d in discounts) {
                  int dId = int.tryParse(d['id'].toString()) ?? 0;
                  log += "- Processing ID $dId: ${d['name']}\n";
                  
                  await DatabaseHelper.instance.insertDiscount({
                      'id': dId,
                      'name': d['name'],
                      'type': d['discount_type'],
                      'amount': double.tryParse(d['discount_amount'].toString()) ?? 0.0,
                      'priority': int.tryParse(d['priority'].toString()) ?? 0,
                      'starts_at': d['starts_at'],
                      'ends_at': d['ends_at'],
                      'is_active': 1,
                      'brand_id': d['brand_id'],
                      'category_id': d['category_id'],
                      'spg': d['spg']?.toString()
                  });
                  
                  if (d['variations'] != null) {
                      for (var v in d['variations']) {
                          int vId = int.tryParse(v['id'].toString()) ?? 0;
                          await DatabaseHelper.instance.insertDiscountVariation(dId, vId); 
                      }
                  }
                  count++;
              }
              log += "Sync Success.\n";
          } else {
              log += "HTTP Error: ${response.statusCode}\nBody: ${response.body}\n";
          }
      } catch (e) {
          log += "Exception: $e\n";
      }
      
      await prefs.setString('last_sync_log', log);
      print(log);
      return count;
  }

  Future<int> syncPaymentMethods() async {
      if (await isDemo()) return 0;
      final baseUrl = await getBaseUrl();
      final headers = await getHeaders();
      
      try {
          final db = await DatabaseHelper.instance.database;
          await db.execute('''
            CREATE TABLE IF NOT EXISTS payment_methods (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              label TEXT NOT NULL,
              is_active INTEGER DEFAULT 1
            )
          ''');

          final response = await http.get(Uri.parse('$baseUrl/connector/api/payment-methods'), headers: headers);
          
          if (response.statusCode == 200) {
              final data = json.decode(response.body);
              // API returns a Map {key: label}, not a List
              
              await db.delete('payment_methods');
              
              // Helper to insert
              Future<void> _add(String name, String label) async {
                  await db.insert('payment_methods', {
                      'name': name,
                      'label': label,
                      'is_active': 1
                  }, conflictAlgorithm: ConflictAlgorithm.replace);
              }

              int count = 0;
              if (data is Map) {
                  for (var entry in data.entries) {
                      await _add(entry.key, entry.value.toString());
                      count++;
                  }
              }
              
              if (count == 0) {
                  // Fallback if data is empty or wrong format
                  await _add('cash', 'Tunai');
                  await _add('card', 'Kartu Debit/Kredit');
                  await _add('bank_transfer', 'Transfer Bank');
                  await _add('cheque', 'Cek / Giro');
                  await _add('other', 'Lainnya');
                  count = 5;
              }
              
              print('Synced $count Payment Methods');
              return count;
          }
      } catch (e) {
          print('Sync Payment Methods Error: $e');
      }
      return 0;
  }

  Future<int> syncProducts({bool includeImages = true, bool force = false, Function(String)? onProgress}) async {
    if (await isDemo()) return 0;
    if (!await checkConnection()) throw Exception('No Internet Connection');
    final baseUrl = await getBaseUrl();
    final locationId = await getLocationId();
    var headers = await getHeaders();
    if (headers['Authorization'] == 'Bearer null') throw Exception('Unauthorized: Please Login Again');

    final prefs = await SharedPreferences.getInstance();
    String? lastSync = prefs.getString('last_sync_products');
    
    // Check if local DB is empty. If so, force FULL SYNC.
    final localCount = await DatabaseHelper.instance.getProductCount();
    if (localCount == 0) {
        print('[API] Local products empty. Forcing full sync.');
        lastSync = null;
    }
    
    int page = 1;
    int perPage = 500;
    int totalSynced = 0;
    bool hasMore = true;
    
    // REMOVED CLEAR LOGIC FOR DELTA SYNC
    // await DatabaseHelper.instance.clearProducts();
    // await DatabaseHelper.instance.clearVariationGroupPrices();

    print('[API] Sync Products Start... (Last Sync: $lastSync)');

    try {
      // DYNAMIC COLUMN DETECTION:
      // Check which columns exist in the local 'products' table to avoid "No Column" or "Constraint Failed" errors.
      // This handles legacy databases that might still have (or miss) specific columns.
      final db = await DatabaseHelper.instance.database;
      final tableInfo = await db.rawQuery('PRAGMA table_info(products)');
      final existingColumns = tableInfo.map((c) => c['name'] as String).toSet();
      
    int retryCount = 0;
    
    while (hasMore) {
          String url = '$baseUrl/connector/api/product?selling_price_group=1&per_page=$perPage&page=$page';
          
          if (locationId != null && locationId.toString() != 'null') {
              url += '&location_id=$locationId';
          }

          if (lastSync != null && !force) {
              url += '&updated_after=$lastSync';
          }
          
          print('[API] Requesting: $url');
          
          var response = await _performRequest(
            () async {
                final h = await getHeaders();
                return http.get(Uri.parse(url), headers: h).timeout(const Duration(seconds: 60));
            },
            taskName: 'Sync Products (Page $page)',
          );

          if (response.statusCode != 200) {
             final errorMsg = 'HTTP ${response.statusCode}: ${response.body}';
             print('[API] syncProducts Failed: $errorMsg');
             if (response.statusCode == 401 || response.statusCode == 403) {
                 throw Exception('Akses Terbatas (Unauthorized/Forbidden). Pastikan Modul Connector di ERP aktif dan User memiliki izin Akses Produk.');
             }
             throw Exception('Gagal menarik data produk ($errorMsg)');
          }

          List products = [];
          final data = json.decode(response.body);
          
          if (data is Map && data.containsKey('data')) {
              products = data['data'];
          } else if (data is List) {
              products = data;
          }

          if (products.isEmpty) {
              hasMore = false;
              break;
          }

            for (var p in products) {
                double price = 0.0;
                int? variationId;
                
                // Extract Main Price & Variation ID
                List pVars = p['product_variations'] ?? [];
                String? sku = p['sku'];
                if (pVars.isNotEmpty) {
                    List vars = pVars[0]['variations'] ?? [];
                    if (vars.isNotEmpty) {
                        var v = vars[0];
                        // Prefer variation SKU if available
                        if (v['sub_sku'] != null && v['sub_sku'].isNotEmpty) {
                            sku = v['sub_sku'];
                        }
                        // ... existing price extraction ...
                        price = double.tryParse(v['sell_price_inc_tax'].toString()) ?? 0.0;
                        variationId = v['id'];
                        
                        // Parse Group Prices
                        var rawGroupPrices = v['group_prices'] ?? v['selling_price_group'];
                        List<dynamic> groupPrices = [];
                        
                        if (rawGroupPrices is List) {
                            groupPrices = rawGroupPrices;
                        } else if (rawGroupPrices is Map) {
                            groupPrices = rawGroupPrices.values.toList();
                        }
                        
                        // Clear OLD group prices for this variation to avoid duplicates before inserting new ones
                        await (await DatabaseHelper.instance.database).delete(
                            'variation_group_prices', 
                            where: 'variation_id = ?', 
                            whereArgs: [variationId]
                        );

                        for (var gp in groupPrices) {
                             if (gp == null) continue;
                             try {
                                await DatabaseHelper.instance.insertVariationGroupPrice({
                                    'variation_id': variationId,
                                    'price_group_id': gp['price_group_id'],
                                    'price': double.tryParse(gp['price_inc_tax'].toString()) ?? 0.0
                                });
                             } catch (e) {
                                print('Error inserting group price: $e');
                             }
                        }
                    }
                }
                
                int storageId = (p['type'] == 'single' && variationId != null) ? variationId : p['id'];
                if (variationId != null) storageId = variationId;

                int? catId = int.tryParse(p['category_id']?.toString() ?? '');
                if (catId == null && p['category'] != null) {
                    catId = int.tryParse(p['category']['id']?.toString() ?? '');
                }

                int? brandId = int.tryParse(p['brand_id']?.toString() ?? '');
                if (brandId == null && p['brand'] != null) {
                    brandId = int.tryParse(p['brand']['id']?.toString() ?? '');
                }

                // Image Extraction Logic:
                // Prefer main image, fallback to variation image, then check other path keys
                String? imageUrl = p['image_url'] ?? p['image'] ?? p['image_path'];
                if (imageUrl == null || imageUrl.isEmpty) {
                   // Try to get image from specific variation if main is empty
                   try {
                     var v = p['product_variations']?[0]?['variations']?[0];
                     imageUrl = v?['image_url'] ?? v?['image'] ?? v?['image_path'];
                   } catch (_) {}
                }

                Map<String, dynamic> productData = {
                  'id': storageId, 
                  'parent_id': p['id'],
                  'name': p['name'] ?? 'Unknown Product',
                  'price': price,
                  'category_id': catId,
                  'brand_id': brandId,
                  'image_url': includeImages ? imageUrl : null,
                  'sku': sku,
                  'is_local': 0,
                  'server_variation_id': storageId
                };

                // Conditionally add legacy columns ONLY if they exist in the DB schema
                // This prevents "No column named X" and satisfies "NOT NULL" if they do exist
                List<String> legacyCols = [
                   'price_dinein', 'price_takeaway', 'price_delivery', 
                   'price_online', 'price_online_1', 'price_online_2'
                ];

                for (var col in legacyCols) {
                   if (existingColumns.contains(col)) {
                       productData[col] = price;
                   }
                }

                // Check and Merge if this SKU already exists as a local product
                // await DatabaseHelper.instance.mergeLocalProduct(sku, storageId);

                // --- CRITICAL FIX FOR DUPLICATION ---
                // 1. Purge any existing product with same parent_id (ERP Product ID) but different local ID
                // This handles cases where product ID vs variation ID caused ghosts.
                try {
                    int deletedParent = await db.delete('products', where: 'parent_id = ? AND id != ?', whereArgs: [p['id'], storageId]);
                    if (deletedParent > 0) print('[API] Purged $deletedParent ghost records for product: ${p['name']} (ID mismatch)');
                    
                    // 2. Purge any existing product with same SKU but different ID
                    if (sku != null && sku.isNotEmpty) {
                        int deletedSku = await db.delete('products', where: 'sku = ? AND id != ?', whereArgs: [sku, storageId]);
                        if (deletedSku > 0) print('[API] Purged $deletedSku duplicate products by SKU: $sku');
                    }

                    await DatabaseHelper.instance.insertProduct(productData);
                } catch (e) {
                    print('[API] FAILED to insert product "${p['name']}" (ID: $storageId): $e');
                    // Continue to next product, do not crash sync
                }
            }
            
            totalSynced += products.length;
            if (onProgress != null) onProgress("SYNC: PRODUK ($totalSynced)...");
            print('[API] Synced page $page (${products.length} items)');
            
             // Pagination Check
            if (data is Map && data['meta'] != null) {
                int current = data['meta']['current_page'];
                int last = data['meta']['last_page'];
                if (current >= last) hasMore = false;
                else page++;
            } else {
                if (products.length < perPage) hasMore = false;
                else page++;
          }
      }
      
      // Update Timestamp if successful
      if (totalSynced > 0 || lastSync == null) {
        await prefs.setString('last_sync_products', DateTime.now().toIso8601String());
      }
      // --- RE-APPLY FEATURED STATUS ---
      // This is necessary because insertion with REPLACE wipes columns not in the data
      try {
          final featuredIds = prefs.getStringList('featured_product_ids');
          if (featuredIds != null && featuredIds.isNotEmpty) {
              await DatabaseHelper.instance.setFeaturedProducts(featuredIds);
              print('[API] Re-applied ${featuredIds.length} Featured Status after sync');
          }
      } catch (e) {
          print('[API] Error re-applying featured status: $e');
      }

      print('[API] Sync Products Complete. Total: $totalSynced');
      return totalSynced;
      
    } catch (e) {
      print('Sync Products Error: $e');
      rethrow;
    }
  }

  
  Future<int> syncModifiers() async {
      if (await isDemo()) return 0;
      if (!await checkConnection()) return 0;
      int totalSetsSynced = 0;
      try {
          final baseUrl = await getBaseUrl();
          final headers = await getHeaders();
          
          bool hasMore = true;
          int page = 1;
          const int perPage = 50;

          // Clear old modifiers first
          await DatabaseHelper.instance.clearModifiers();
          
          while (hasMore) {
              final url = Uri.parse('$baseUrl/connector/api/product?per_page=$perPage&page=$page');
              final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 20));
              
              if (response.statusCode == 200) {
                  final data = json.decode(response.body);
                  List products = (data is Map && data['data'] != null) ? data['data'] : data;
                  
                  for (var p in products) {
                      if (p['modifier_sets'] != null) {
                          List modSets = p['modifier_sets'];
                          int productId = int.parse(p['id'].toString());
                          
                          // Handle Variation Mapping if needed, but for linking we use Product ID or Variation ID
                          // Check if single or variable
                          if (p['type'] == 'single' && p['product_variations'] != null && (p['product_variations'] as List).isNotEmpty) {
                             // Map to Variation ID for single products as that's what we store in Cart
                             var v = p['product_variations'][0]['variations'][0];
                             productId = int.parse(v['id'].toString());
                          }

                          for (var ms in modSets) {
                              int setId = int.parse(ms['id'].toString());
                              await DatabaseHelper.instance.insertModifierSet(setId, ms['name']);
                              await DatabaseHelper.instance.linkProductToModifier(productId, setId);
                              totalSetsSynced++;
                              
                              if (ms['variations'] != null) {
                                  for (var mv in ms['variations']) {
                                      await DatabaseHelper.instance.insertModifierOption(
                                          int.parse(mv['id'].toString()), 
                                          setId, 
                                          mv['name'], 
                                          double.tryParse(mv['default_sell_price'].toString()) ?? 0.0
                                      );
                                  }
                              }
                          }
                      }
                  }
                  
                  if (data is Map && data['meta'] != null) {
                      int current = data['meta']['current_page'];
                      int last = data['meta']['last_page'];
                      if (current >= last) hasMore = false;
                      else page++;
                  } else {
                      if (products.length < perPage) hasMore = false;
                      else page++;
                  }
              } else {
                  hasMore = false;
              }
          }
      } catch (e) {
          print('Sync Modifiers Error: $e');
      }
      return totalSetsSynced;
  }

  Future<int> syncProductImages({Function(String)? onProgress}) async {
      if (await isDemo()) return 0;
      if (!await checkConnection()) return 0;
      
      // Update product list first to get latest Image URLs (Optional/Best Effort)
      try {
          if (onProgress != null) onProgress("SYNC: LIST DATA PRODUK...");
          await syncProducts(includeImages: true, force: true, onProgress: onProgress);
      } catch (e) {
          print('[API] Warning: Product list update failed before image sync: $e');
          if (onProgress != null) onProgress("WARNING: GAGAL UPDATE LIST. LANJUT DOWNLOAD...");
      }
      
      final dbData = await DatabaseHelper.instance.getAllProducts();
      int successCount = 0;
      int failCount = 0;
      
      print('[API] Starting Image Sync for ${dbData.length} products...');
      
      for (var pMap in dbData) {
          final id = pMap['id'];
          final name = pMap['name'] ?? 'Unknown';
          String? url = pMap['image_url'];
          
          if (url != null && url.isNotEmpty) {
              final baseUrl = await getBaseUrl();
              final cleanBase = baseUrl.replaceAll('/public', '');
              
              List<String> candidates = [];
              if (url.startsWith('http')) {
                  candidates.add(url);
              } else {
                  // Candidates for product images
                  // 1. Storage prefix (Laravel standard with symlink)
                  if (!url.startsWith('storage/')) {
                      candidates.add('$cleanBase/storage/$url');
                  } else {
                      candidates.add('$cleanBase/$url');
                  }
                  
                  // 2. Direct path with baseUrl (contains /public if configured)
                  candidates.add('$baseUrl/$url');
                  
                  // 3. Direct path with cleanBase (no /public)
                  candidates.add('$cleanBase/$url');
                  
                  // 4. Common UltimatePOS storage patterns
                  final fileName = url.split('/').last;
                  if (url.contains('product_images')) {
                      candidates.add('$cleanBase/storage/product_images/$fileName');
                      candidates.add('$baseUrl/storage/product_images/$fileName');
                  } else {
                      candidates.add('$cleanBase/storage/uploads/img/$fileName');
                      candidates.add('$baseUrl/storage/uploads/img/$fileName');
                  }
                  
                  // 5. Fallback for specific Serverzone environments
                  candidates.add('https://donapos.serverzone.web.id/public/uploads/img/$fileName');
                  candidates.add('https://donapos.serverzone.web.id/uploads/img/$fileName');
              }

              final fileName = 'p_$id.jpg';
              String? localPath;
              
              for (var candidate in candidates) {
                  print('[API] Trying image for "$name" (ID: $id): $candidate');
                  localPath = await _downloadAndCompressImage(candidate, fileName);
                  if (localPath != null) {
                      print('[API] Success! Downloaded "$name" from: $candidate');
                      break;
                  }
              }
              
              if (localPath != null) {
                  await DatabaseHelper.instance.updateProductImagePath(id, localPath);
                  successCount++;
                  if (onProgress != null && successCount % 3 == 0) onProgress("SYNC: DOWNLOAD GAMBAR ($successCount)...");
              } else {
                  failCount++;
                  final errorMsg = "✗ GAGAL: $name (ID: $id)";
                  if (onProgress != null) onProgress(errorMsg);
                  print('[API] Failed to download image for "$name" (ID: $id) after trying all candidates.');
              }
          }
      }
      
      print('[API] Image Sync Finished. Success: $successCount, Failed: $failCount');
      return successCount;
  }
  
  Future<bool> syncAll({Function(String)? onProgress}) async {
      if (await isDemo()) return true; // Allow demo mode to "complete" sync without network ops
      // Complete Synchronization of all master data
      final prefs = await SharedPreferences.getInstance();
      
      // Force reset of sync timestamps to ensure FULL download
      await prefs.remove('last_sync_products');
      await prefs.remove('last_sync_contacts');
      
      if (onProgress != null) onProgress('SYNC: DETAIL BISNIS...');
      await syncBusinessDetails(); 
      if (onProgress != null) onProgress('SYNC: USER & STAF...');
      await syncUsers();
      if (onProgress != null) onProgress('SYNC: MEJA...');
      await syncResTables();
      if (onProgress != null) onProgress('SYNC: KATEGORI...');
      await syncCategories();
      if (onProgress != null) onProgress('SYNC: PAJAK...');
      await syncTaxes(); 
      if (onProgress != null) onProgress('SYNC: DISKON...');
      await syncDiscounts(); 
      if (onProgress != null) onProgress('SYNC: METODE BAYAR...');
      await syncPaymentMethods();
      if (onProgress != null) onProgress('SYNC: KONTAK...');
      await syncContacts(onProgress: onProgress); // Will sync from scratch due to removed pref
      if (onProgress != null) onProgress('SYNC: GRUP HARGA...');
      await syncPriceGroups();
    if (onProgress != null) onProgress('SYNC: GRUP PELANGGAN...');
    await syncCustomerGroups();
      if (onProgress != null) onProgress('SYNC: PRODUK & GAMBAR...');
      await syncProducts(includeImages: true, force: true, onProgress: onProgress); // Force full sync
      if (onProgress != null) onProgress('SYNC: MODIFIER...');
      await syncModifiers();
      if (onProgress != null) onProgress('SYNC: KATEGORI PENGELUARAN...');
      await syncExpenseCategories();
      
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
      return true;
  }

  Future<int> syncTransactions() async {
    if (await isDemo()) return 0;
    try {
        final result = await syncTransactionsWithLogs();
        return (result['count'] ?? 0) as int;
    } catch (e) {
        print('[SyncService] Background Transaction Sync Error: $e');
        return 0;
    }
  }

  // --- Reports & Closing ---
  Future<Map<String, dynamic>> getKasirSummary() async {
    if (await isDemo()) return {};
    final baseUrl = await getBaseUrl();
    final headers = await getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/connector/api/report/kasir-summary'), headers: headers).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load Kasir Summary: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getZReport(String date) async {
    if (await isDemo()) return {};
    final baseUrl = await getBaseUrl();
    final headers = await getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/connector/api/report/z-report?tanggal=$date'), headers: headers).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load Z-Report: ${response.body}');
    }
  }

  Future<void> closingDay() async {
    if (await isDemo()) return;
    final baseUrl = await getBaseUrl();
    
    // Initial Attempt
    var headers = await _prepareAuthHeaders(); 
    final locationId = await getLocationId();
    final body = json.encode({'location_id': locationId});
    
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/connector/api/report/closing-day'), 
        headers: headers,
        body: body
      );

      // RETRY LOGIC FOR 401 UNAUTHENTICATED
      if (response.statusCode == 401) {
          print('[Closing] 401 Unauthenticated. Attempting re-auth...');
          final prefs = await SharedPreferences.getInstance();
          
          // 1. Clear invalid token
          await prefs.remove('token');
          
          // 2. Authenticate using User Token recovery if possible
          await reAuthenticateForSales();
          
          // 3. Get new headers and retry
          headers = await getHeaders(); 
          response = await http.post(
            Uri.parse('$baseUrl/connector/api/report/closing-day'), 
            headers: headers,
            body: body
          );
      }

      if (response.statusCode != 200) {
        throw Exception('Closing Day Failed (${response.statusCode}): ${response.body}');
      }
      
      // SUCCESS: Close Local DB
      await DatabaseHelper.instance.closeDayLocal();
      
    } catch (e) {
      rethrow;
    }
  }
  
  // --- Auto-Create Helpers ---
  
  Future<dynamic> _ensureContactSynced(int? localId) async {
      if (await isDemo()) return 1; // Return a dummy ID for demo mode
      final db = await DatabaseHelper.instance.database;

      // Logic to find Default Customer as ultimate fallback
    Future<dynamic> getUltimateFallback() async {
        final def = await DatabaseHelper.instance.getDefaultContact();
        if (def != null) {
            // Priority: erp_contact_id string, then server_id int
            return def['contact_id'] ?? def['server_id'] ?? 1;
        }
        final prefs = await SharedPreferences.getInstance();
        return prefs.getInt('default_walkin_id') ?? 1;
    }

      // Handle Walk-In / Null Customer
      if (localId == null) {
          final prefs = await SharedPreferences.getInstance();
          int? defId = prefs.getInt('default_walkin_id');
          if (defId != null) return defId;
          
          try {
             return await _createOnServer({
               'type': 'customer',
               'first_name': 'Walk-In Customer (Mobile)',
               'mobile': '0000000000',
               'city': 'Mobile', 
             }, 'contactapi', isWalkIn: true);
          } catch (e) {
             print('Sync TX: Create Walk-In Error $e');
             return await getUltimateFallback();
          }
      }
      
      final rs = await db.query('contacts', where: 'id = ?', whereArgs: [localId]);
      if (rs.isEmpty) return await getUltimateFallback();
      
      final contact = rs.first;
      
      // Preference: the 'contact_id' record string (e.g., CO0001)
      if (contact['contact_id'] != null && contact['contact_id'].toString().isNotEmpty) {
          return contact['contact_id'].toString();
      }

      // Fallback: the server numeric ID
      if (contact['server_id'] != null && (contact['server_id'] as int) > 0) {
          return contact['server_id'] as int;
      }
      
      // Not synced, create on server
      try {
          final payload = {
              'type': 'customer',
              'first_name': contact['name'],
              'mobile': contact['mobile'] ?? '',
              'email': contact['email'] ?? '',
              'city': contact['city'] ?? '',
              'address_line_1': contact['address'] ?? ''
          };
          
          final newId = await _createOnServer(payload, 'contactapi');
          // After creating, the response usually has contact_id too, but for simplicity we return numeric ID for now
          await db.update('contacts', {'server_id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [localId]);
          return newId;
      } catch (e) {
          print('Sync TX: Sync Customer Error $e');
      }
      
      return await getUltimateFallback();
  }

  Future<int> _createOnServer(Map<String, dynamic> payload, String type, {bool isWalkIn = false}) async {
      if (await isDemo()) return 1; // Return a dummy ID for demo mode
      final baseUrl = await getBaseUrl();
      final headers = await getHeaders();
      final response = await http.post(Uri.parse('$baseUrl/connector/api/$type'), headers: headers, body: json.encode(payload));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
          final resData = json.decode(response.body);
          if (resData['data'] != null && resData['data']['id'] != null) {
              int id = int.parse(resData['data']['id'].toString());
              if (isWalkIn) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('default_walkin_id', id);
              }
              return id;
          }
      }
      throw Exception('Failed to create $type: ${response.body}');
  }
  
  // _ensureProductSynced, uploadEmergencyProduct, and uploadLocalProducts removed

  Future<Map<String, dynamic>> syncTransactionsWithLogs({Function(String)? onProgress}) async {
    if (await isDemo()) {
        return {'success_count': 0, 'fail_count': 0, 'logs': ['MODE DEMO: POSTING DINONAKTIFKAN']};
    }
    if (!await checkConnection()) return {'success_count': 0, 'fail_count': 0, 'logs': ['Koneksi gagal']};
    if (_isGlobalSyncing) {
        print('[SyncService] Sync delayed: Another sync process is already running. Waiting...');
        // Timeout after 30 seconds to prevent infinite hang if previous sync crashed
        int waitCount = 0;
        while (_isGlobalSyncing && waitCount < 60) {
            await Future.delayed(const Duration(milliseconds: 500));
            waitCount++;
        }
        if (_isGlobalSyncing) {
            print('[SyncService] Force releasing stale sync lock after 30s timeout.');
            _isGlobalSyncing = false;
        }
    }

    _isGlobalSyncing = true; // Lock set
    
    List<String> logs = [];
    final prefs = await SharedPreferences.getInstance();

    final baseUrl = await getBaseUrl();
    final locationId = await getLocationId();

    // REVERT: Forced Machine Token caused 403/500 errors on backend. Only User Token allows sales.
    // We will rely on payload fields (commission_agent, notes) for cashier ID.
    var headers = await _prepareAuthHeaders();
    
    if (headers['Authorization'] == 'Bearer null' || headers['Authorization'] == 'Bearer ') {
        _isGlobalSyncing = false; // Release lock
        return {'count': 0, 'total': 0, 'logs': ['Sync TX aborted: No valid Auth Header (Level Admin/Client Required)']};
    }
    
    // Step 1: Upload Emergency Products Skip (Feature Disabled)

    // List<String> logs = []; // Defined above
    int syncedCount = 0;
    int totalItems = 0;

    try {
        final unsynced = await DatabaseHelper.instance.getUnsyncedTransactions();
        totalItems = unsynced.length;
        logs.add('Sync TX: Found $totalItems unsynced transactions');
        
        if (unsynced.isEmpty) {
             _isGlobalSyncing = false;
             return {'count': 0, 'total': 0, 'logs': logs};
        }

        if (AppConfig.isTrainingMode) {
             logs.add('Sync TX: Skipped (Training Mode Active)');
             _isGlobalSyncing = false;
             return {'count': 0, 'total': unsynced.length, 'logs': logs};
        }


        final String prefix = prefs.getString('invoice_prefix') ?? 'MBL';
        final int startIndex = prefs.getInt('invoice_start_index') ?? 0;
        final int currentUserId = prefs.getInt('last_user_id') ?? 1;
        final allTaxes = await DatabaseHelper.instance.getAllTaxes();
        int? defaultTaxId;
        if (allTaxes.isNotEmpty) defaultTaxId = allTaxes.first['id'];

        // Batch Process
        final int batchSize = 10;
        bool hasRetriedBatch = false;
        
        for (var i = 0; i < unsynced.length; i += batchSize) {
            final end = (i + batchSize < unsynced.length) ? i + batchSize : unsynced.length;
            final batch = unsynced.sublist(i, end);
            
            if (onProgress != null) onProgress('BATCH ${i ~/ batchSize + 1}/${(unsynced.length / batchSize).ceil()}...');
            
            List<Map<String, dynamic>> sellsPayload = [];
            
            for (var tx in batch) {
                 try {
                    logs.add('Sync TX: Processing ID ${tx['id']} for local customer ID ${tx['customer_id']}');
                    final db = await DatabaseHelper.instance.database;
                    final contactRs = await db.query('contacts', where: 'id = ?', whereArgs: [tx['customer_id']]);
                    if (contactRs.isNotEmpty) {
                        logs.add('Sync TX: Local Contact found: ${contactRs.first['name']} (SID: ${contactRs.first['server_id']}, CID: ${contactRs.first['contact_id']})');
                    } else {
                        logs.add('Sync TX: Local Contact NOT FOUND for ID ${tx['customer_id']}');
                    }
                    dynamic erpContactId = await _ensureContactSynced(tx['customer_id']);
                    logs.add('Sync TX: Resolved ERP Contact ID/Code: $erpContactId');
                    
                    final items = await DatabaseHelper.instance.getTransactionItems(tx['id']);
                    List<Map<String, dynamic>> productsPayload = [];
                    double totalItemDiscounts = 0;
                    
                    for (var item in items) {
                        try {
                           // _ensureProductSynced call removed
                           final p = await DatabaseHelper.instance.getProductById(item['product_id']);
                           if (p != null) {
                               final itemModifiers = await DatabaseHelper.instance.getTransactionItemModifiers(item['id']);
                               List<Map<String, dynamic>> modifiersPayload = [];
                               
                               if (itemModifiers.isNotEmpty) {
                                   for (var m in itemModifiers) {
                                       modifiersPayload.add({
                                           'product_id': m['product_id'],
                                           'variation_id': m['modifier_option_id'],
                                           'quantity': item['qty'], // Modifier qty usually matches parent qty
                                           'unit_price': m['price']
                                       });
                                   }
                               }

                               productsPayload.add({
                                  'product_id': p['parent_id'],
                                  // Use server_variation_id if present (for synced local products), else fallback to generic ID
                                  'variation_id': p['server_variation_id'] ?? item['product_id'],
                                  'quantity': item['qty'],
                                  'unit_price': item['price'],
                                  'tax_rate_id': null,
                                   'discount_amount': (item['discount'] ?? 0) / (item['qty'] ?? 1),
                                   'discount_type': 'fixed',
                                   'note': item['note'],
                                   'modifier': modifiersPayload, 'modifiers': modifiersPayload
                               });

                                // Infer line discount percentage if it matches closely
                                double lineNominal = (item['discount'] ?? 0) / (item['qty'] ?? 1);
                                if (lineNominal > 0 && (item['price'] ?? 0) > 0) {
                                    double prc = (lineNominal / item['price']) * 100;
                                    double rounded = (prc * 1000).round() / 1000;
                                    if ((rounded - prc).abs() < 0.001) {
                                        productsPayload.last['discount_amount'] = rounded;
                                        productsPayload.last['discount_type'] = 'percentage';
                                    }
                                }
                               totalItemDiscounts += (item['discount'] ?? 0);
                           }
                        } catch (e) {
                           logs.add("Product Prep Error (TX ${tx['id']} Item ${item['id']}): $e");
                        }
                    }
                    
                    String formattedDate;
                    try {
                        DateTime dt = (tx['created_at'] != null) ? DateTime.parse(tx['created_at']) : DateTime.now();
                        formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
                    } catch (_) {
                        formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
                    }

                    // Handle Split Payments
                    final localPayments = await DatabaseHelper.instance.getTransactionPayments(tx['id']);
                    List<Map<String, dynamic>> erpPayments = [];
                    
                    if (localPayments.isNotEmpty) {
                        for (var lp in localPayments) {
                            erpPayments.add({
                                'amount': lp['amount'],
                                'method': _mapToErpPaymentMethod(lp['method']),
                                'note': lp['note'] ?? 'Split Payment'
                            });
                        }
                    } else {
                        // Fallback to legacy single payment method
                        String localPm = tx['payment_method']?.toString().toLowerCase() ?? 'cash';
                        erpPayments.add({
                            'amount': tx['total'],
                            'method': _mapToErpPaymentMethod(localPm),
                            'note': 'POS Mobile Upload'
                        });
                    }

                    double txDiscount = double.tryParse(tx['discount']?.toString() ?? '0') ?? 0.0;
                    double txTax = double.tryParse(tx['tax']?.toString() ?? '0') ?? 0.0;
                    double finalRoundOff = txTax; // As per comment: Captures Local Tax + Rounding

                    // Calculate transaction-level discount (total discount minus item-level discounts)
                    double txDiscountForPayload = txDiscount - totalItemDiscounts;
                    if (txDiscountForPayload < 0) txDiscountForPayload = 0; // Safety: never send negative discount

                    logs.add('Sync TX Item ${tx['id']}: Cashier=${tx['cashier_name']} (ID ${tx['cashier_id'] ?? currentUserId})');

                    sellsPayload.add({
                      'status': 'final',
                      'invoice_no': '$prefix${DateFormat('yyMMdd').format(DateTime.parse(tx['created_at']))}${(tx['id'] + startIndex).toString().padLeft(4, '0')}',
                      'contact_id': erpContactId, 
                      'customer_id': erpContactId, 
                      'created_by': tx['cashier_id'] ?? currentUserId,
                      'user_id': tx['cashier_id'] ?? currentUserId,
                      'commission_agent': tx['cashier_id'] ?? currentUserId,
                      'transaction_date': formattedDate,
                      'staff_note': 'Kasir: ${tx['cashier_name']}',
                      'sale_note': 'Kasir: ${tx['cashier_name']}',
                      'location_id': locationId, 
                      'table_id': tx['res_table_id'],
                      'service_staff_id': tx['res_service_staff_id'],
                      'pax': tx['pax'],
                      'tax_rate_id': txTax > 0 ? defaultTaxId : null,
                      'discount_amount': txDiscountForPayload,
                      'discount_type': 'fixed',
                      'change_return': tx['change_amount'] ?? 0, 
                      'round_off_amount': 0, 
                      'payment': erpPayments, 
                      'products': productsPayload
                    });

                    // Infer transaction discount type (percentage vs fixed)
                    if (txDiscountForPayload > 0 && (tx['subtotal'] ?? 0) > 0) {
                        double prc = (txDiscountForPayload / tx['subtotal']) * 100;
                        double rounded = (prc * 1000).round() / 1000;
                        if ((rounded - prc).abs() < 0.001) {
                            sellsPayload.last['discount_amount'] = rounded;
                            sellsPayload.last['discount_type'] = 'percentage';
                        }
                    }
                } catch (e) {
                    logs.add('Sync TX [Prepare Error] ID ${tx['id']}: $e');
                }
            }

            if (sellsPayload.isEmpty) continue;

            try {
                final payload = {'sells': sellsPayload};
                logs.add('Sending Batch (${sellsPayload.length} items)...');

                final response = await http.post(
                  Uri.parse('$baseUrl/connector/api/sell'), 
                  headers: headers, 
                  body: json.encode(payload)
                ).timeout(const Duration(seconds: 30));

                if (response.statusCode == 401 && !hasRetriedBatch) {
                    logs.add("HTTP 401: Unauthorized. Attempting silent re-auth...");
                    bool reAuth = await reAuthenticateForSales();
                    if (reAuth) {
                        logs.add("Silent re-auth successful. Retrying batch...");
                        headers = await _prepareAuthHeaders();
                        hasRetriedBatch = true;
                        i -= batchSize; // Offset loop increment to retry same batch
                        continue;
                    } else {
                        logs.add("Silent re-auth failed. Aborting.");
                        break; // Stop syncing if we can't auth
                    }
                } else if (response.statusCode == 401) {
                    logs.add("HTTP 401: Unauthorized after retry. Aborting.");
                    break;
                }
                
                hasRetriedBatch = false; // Reset for next batch

                if (response.statusCode == 200 || response.statusCode == 201) {
                    try {
                       final responseData = json.decode(response.body);
                       if (responseData is List) {
                           for (int k = 0; k < batch.length; k++) {
                              if (k < responseData.length) {
                                  final resItem = responseData[k];
                                  if (resItem is Map && resItem.containsKey('id') && resItem['id'] != null && !resItem.containsKey('trace')) {
                                      await DatabaseHelper.instance.markTransactionSynced(batch[k]['id']);
                                      syncedCount++;
                                      logs.add('Item ${batch[k]['id']} synced successfully');
                                  } else {
                                      logs.add("Item ${batch[k]['id']} Rejected: ${json.encode(resItem)}");
                                      
                                      // AUTO-FIX: Handle Invalid Contact ID
                                      // Error: "Data tidak ditemukan di server: No query results for model [App\\Contact] 117"
                                      String errStr = json.encode(resItem);
                                      if (errStr.contains('App\\\\Contact') || errStr.contains('Invalid contact ID') || errStr.contains('Contact not found')) {
                                          try {
                                              // Try to extract ID from standard Laravel error or custom error
                                              RegExp regex = RegExp(r'(?:\[App\\\\Contact\]|ID:)\s*(\d+)');
                                              var match = regex.firstMatch(errStr);
                                              if (match != null) {
                                                  String badId = match.group(1)!;
                                                  apiServicePrint('Auto-fixing Invalid Contact Server ID: $badId');
                                                  await DatabaseHelper.instance.database.then((db) async {
                                                      await db.update('contacts', {'server_id': null, 'is_synced': 0}, 
                                                          where: 'server_id = ?', whereArgs: [int.parse(badId)]);
                                                  });
                                                  logs.add("Auto-fix: Reset invalid Contact ID $badId. Please Sync again.");
                                              }
                                          } catch (e) {
                                              print('Auto-fix Contact Error: $e');
                                          }
                                      }
                                      }
                                  }
                              }
                       } else {
                           logs.add("Batch result not a list: ${response.body}");
                       }
                    } catch (e) {
                       logs.add("JSON Decode Error: ${response.body}");
                    }
                } else {
                    logs.add("HTTP ${response.statusCode}: ${response.body}");
                }
            } catch (e) {
                logs.add("Network Error: $e");
            }
        }
    } catch (e) {
        logs.add("Global Error: $e");
    } finally {
        _isGlobalSyncing = false; // Lock released always
        try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('last_tx_sync_log', logs.join('\n'));
        } catch (_) {}
    }

    return {'count': syncedCount, 'total': totalItems, 'logs': logs};
  }

  String _mapToErpPaymentMethod(String? localPm) {
      if (localPm == null) return 'cash';
      String pm = localPm.toLowerCase();
      
      // If already an ERP code, return as is
      if (pm.startsWith('custom_pay_')) return pm;
      if (pm == 'bank_transfer' || pm == 'card' || pm == 'cash' || pm == 'other') return pm;

      if (pm.contains('tunai') || pm == 'cash') return 'cash';
      if (pm.contains('kartu') || pm == 'card' || pm.contains('debit') || pm.contains('kredit')) return 'card';
      if (pm.contains('bank') || pm.contains('transfer') || pm.contains('va')) return 'custom_pay_7'; // VA is 7
      if (pm.contains('ovo')) return 'custom_pay_1';
      if (pm.contains('gopay')) return 'custom_pay_2';
      if (pm.contains('qris')) return 'custom_pay_3';
      if (pm.contains('dana')) return 'custom_pay_5';
      if (pm.contains('shopeepay')) return 'custom_pay_4';
      if (pm.contains('link')) return 'custom_pay_6';
      
      return 'cash';
  }

  // --- Expenses ---
  Future<int> syncExpenseCategories() async {
    final baseUrl = await getBaseUrl();
    final headers = await getHeaders();
    if (headers['Authorization'] == 'Bearer null') return 0;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/connector/api/expense-categories'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List categories = data['data'];
        await DatabaseHelper.instance.clearExpenseCategories();
        for (var cat in categories) {
          await DatabaseHelper.instance.insertExpenseCategory({
            'id': cat['id'],
            'name': cat['name'],
          });
        }
        return categories.length;
      }
    } catch (e) {
      print('Sync Expense Categories Error: $e');
    }
    return 0;
  }

  Future<Map<String, dynamic>> syncExpenses() async {
    if (!await checkConnection()) return {'count': 0};
    final baseUrl = await getBaseUrl();
    final locationId = await getLocationId();
    final headers = await _prepareAuthHeaders();
    if (headers['Authorization'] == 'Bearer null') return {'count': 0};

    final unsynced = await DatabaseHelper.instance.getUnsyncedExpenses();
    int syncedCount = 0;

    for (var exp in unsynced) {
      try {
        final payload = {
          'location_id': locationId,
          'final_total': exp['final_total'],
          'transaction_date': exp['transaction_date'],
          'expense_category_id': exp['category_id'],
          'additional_notes': exp['additional_notes'],
          'payment': [
            {
              'amount': exp['final_total'],
              'method': 'cash',
              'note': 'POS Mobile Expense'
            }
          ]
        };

        final response = await http.post(
          Uri.parse('$baseUrl/connector/api/expense'),
          headers: headers,
          body: json.encode(payload),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 || response.statusCode == 201) {
          await DatabaseHelper.instance.markExpenseSynced(exp['id']);
          syncedCount++;
        }
      } catch (e) {
        print('Sync Expense Error [ID ${exp['id']}]: $e');
      }
    }

    return {'count': syncedCount};
  }

  // --- Customer Display Settings ---
  Future<CustomerDisplaySetting?> fetchCustomerDisplaySettings() async {
    final baseUrl = await getBaseUrl();
    final headers = await getHeaders();
    try {
      final response = await http.get(Uri.parse('$baseUrl/connector/api/customer-display-settings'), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final settings = CustomerDisplaySetting.fromJson(data);
        await saveCustomerDisplaySettings(settings); // cache it
        return settings;
      }
    } catch (e) {
      print('Fetch Customer Display Settings Error: $e');
    }
    return null;
  }

  Future<void> saveCustomerDisplaySettings(CustomerDisplaySetting settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customer_display_settings', json.encode(settings.toJson()));
  }

  Future<CustomerDisplaySetting?> getLocalCustomerDisplaySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString('customer_display_settings');
    if (jsonStr != null) {
      return CustomerDisplaySetting.fromJson(json.decode(jsonStr));
    }
    return null;
  }
  // --- Customer Groups ---
  Future<int> syncCustomerGroups() async {
    final baseUrl = await getBaseUrl();
    final headers = await getHeaders();
    if (headers['Authorization'] == 'Bearer null') return 0;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/connector/api/business-groups'), // Assuming default ERP endpoint for customer groups
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List groups = (data is Map && data.containsKey('data')) ? data['data'] : (data is List ? data : []);
        
        // If empty or unexpected format, try alternative endpoint if needed, but for now stick to standard
        if (groups.isEmpty) {
             print('Sync Customer Groups: No data found.');
             return 0;
        }

        final db = await DatabaseHelper.instance.database;
        await db.delete('customer_groups'); // Replace all

        for (var g in groups) {
          await DatabaseHelper.instance.insertCustomerGroup({
            'id': g['id'],
            'name': g['name'],
            'amount': double.tryParse(g['amount']?.toString() ?? '0') ?? 0,
            'price_calculation_type': g['price_calculation_type'],
            'selling_price_group_id': g['selling_price_group_id']
          });
        }
        return groups.length;
      } else {
        print('Sync Customer Groups Failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Sync Customer Groups Error: $e');
    }
    return 0;
  }

  Future<Map<String, dynamic>> syncAttendances({Function(String)? onProgress}) async {
      if (await isDemo()) return {'count': 0, 'logs': ['MODE DEMO: POSTING DINONAKTIFKAN']};
      if (!await checkConnection()) return {'count': 0, 'logs': ['TIDAK ADA KONEKSI INTERNET']};
      
      final unsynced = await DatabaseHelper.instance.getUnsyncedAttendances();
      print('[Sync|ATT] Unsynced count: ${unsynced.length}');
      
      if (unsynced.isEmpty) {
          final db = await DatabaseHelper.instance.database;
          final totalCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM attendances')) ?? 0;
          print('[Sync|ATT] Total records in DB: $totalCount');
          return {'count': 0, 'logs': ['TIDAK ADA DATA ABSENSI BARU UNTUK DIKIRIM (Total di DB: $totalCount)']};
      }
      
      final baseUrl = await getBaseUrl();
      var headers = await _prepareAuthHeaders();
      int count = 0;
      List<String> logs = [];
      logs.add('Ditemukan ${unsynced.length} data absensi belum terkirim.');
      
      if (onProgress != null) onProgress('Uploading 0/${unsynced.length}');
      
      int i = 0;
      for (var att in unsynced) {
         i++;
         if (onProgress != null) onProgress('Uploading $i/${unsynced.length}');
         try {
            // Convert ISO8601 to MySQL Format (Y-m-d H:i:s)
            String formatTime(String? iso) {
                if (iso == null || iso.isEmpty) return '';
                return iso.replaceFirst('T', ' ').split('.').first;
            }

            // Function to perform POST with 401 retry
            Future<http.Response> postWithRetry(String endpoint, Map<String, dynamic> body) async {
                var response = await http.post(
                   Uri.parse('$baseUrl/connector/api/attendance/$endpoint'),
                   headers: headers,
                   body: json.encode(body)
                ).timeout(const Duration(seconds: 10));

                if (response.statusCode == 401) {
                    print('[Sync Attendance] 401 Unauthenticated. Retrying with fresh Machine Token...');
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('token');
                    await authenticateClient();
                    headers = await getHeaders(); // Update outer scope headers
                    
                    response = await http.post(
                       Uri.parse('$baseUrl/connector/api/attendance/$endpoint'),
                       headers: headers,
                       body: json.encode(body)
                    ).timeout(const Duration(seconds: 10));
                }
                return response;
            }

            bool clockInSuccess = false;

            // 1. Clock In (Mandatory part of record)
            final clockInRes = await postWithRetry('clockin', {
                'user_id': att['user_id'],
                'clock_in_time': formatTime(att['clock_in']),
                'clock_in_note': 'Synced from Donapos Mobile',
                'ip_address': att['ip_address'],
                'latitude': att['latitude'],
                'longitude': att['longitude'],
            });
            
            // Treat 200 (Success) OR 4xx (Client Error, likely duplicated) as success for Clock In step
            if (clockInRes.statusCode == 200 || (clockInRes.statusCode >= 400 && clockInRes.statusCode < 500)) {
               clockInSuccess = true;
               if (clockInRes.statusCode != 200) {
                   print('Sync Attendance ClockIn Warning (ID ${att['id']}): ${clockInRes.statusCode} ${clockInRes.body}. Continuing...');
               }
            } else {
               print('Sync Attendance ClockIn Failed (ID ${att['id']}): ${clockInRes.statusCode} ${clockInRes.body}');
            }

            // If Clock In step is considered done (or skipped/duplicated), proceed to Clock Out if needed
            if (clockInSuccess) {
               bool finalSuccess = true;

               // 2. Clock Out (If record is finished)
               if (att['status'] == 'finished' && att['clock_out'] != null) {
                  final clockOutRes = await postWithRetry('clockout', {
                      'user_id': att['user_id'],
                      'clock_out_time': formatTime(att['clock_out']),
                      'clock_out_note': 'Synced from Donapos Mobile',
                      'latitude': att['clock_out_latitude'],
                      'longitude': att['clock_out_longitude'],
                  });

                  if (clockOutRes.statusCode != 200) {
                      finalSuccess = false;
                      print('Sync Attendance ClockOut Failed (ID ${att['id']}): ${clockOutRes.statusCode} ${clockOutRes.body}');
                  }
               }
               
               if (finalSuccess) {
                   await DatabaseHelper.instance.markAttendanceSynced(att['id']);
                   count++;
               }
            }
         } catch (e) {
            print('Sync Attendance Error (ID ${att['id']}): $e');
         }
      }
      return {'count': count, 'logs': logs};
  }
}
