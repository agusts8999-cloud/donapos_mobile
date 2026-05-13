import 'package:flutter/material.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/design_system.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogoDebugDialog extends StatefulWidget {
  const LogoDebugDialog({super.key});

  @override
  State<LogoDebugDialog> createState() => _LogoDebugDialogState();
}

class _LogoDebugDialogState extends State<LogoDebugDialog> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String _log = "Memulai diagnosa...\n";
  List<String> _imageUrls = [];
  Map<String, dynamic>? _rawData;

  @override
  void initState() {
    super.initState();
    _startDiagnosis();
  }

  void _addLog(String msg) {
    setState(() => _log += "$msg\n");
  }

  Future<void> _startDiagnosis() async {
    try {
      final baseUrl = await _apiService.getBaseUrl();
      final locationId = await _apiService.getLocationId();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final Map<String, String> headers = {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
      };
      
      _addLog("Base URL: $baseUrl");
      _addLog("Location ID: $locationId");

      // We need to access private method logic, but we'll reimplement partially here for debug
      // Actually we can't call potentially private methods easily, so we use http directly
      if (headers['Authorization'] == 'Bearer null') {
          _addLog("ERROR: Token tidak ditemukan. Silakan login ulang.");
          setState(() => _isLoading = false);
          return;
      }

      final url = '$baseUrl/connector/api/business-location';
      _addLog("Fetching from: $url");
      
      final response = await http.get(Uri.parse(url), headers: headers);
      _addLog("Response Code: ${response.statusCode}");
      
      if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List locations = data['data'];
          
          final myLoc = locations.firstWhere((l) => l['id'].toString() == locationId || l['location_id'] == locationId, orElse: () => null);
          
          if (myLoc != null) {
              setState(() => _rawData = myLoc);
              _addLog("✅ Lokasi ditemukan: ${myLoc['name']}");
              
              String? logoUrl = myLoc['logo_url'];
              String? logo = myLoc['logo'];
              String? layoutLogo = myLoc['invoice_layout']?['logo'];
              String? layoutLogoUrl = myLoc['invoice_layout']?['logo_url'];

              _addLog("\n--- DATA DARI SERVER ---");
              _addLog("1. Field 'logo_url' (Top): ${logoUrl ?? '(kosong)'}");
              _addLog("2. Field 'logo' (Top): ${logo ?? '(kosong)'}");
              _addLog("3. Field 'invoice_layout > logo': ${layoutLogo ?? '(kosong)'}");
              _addLog("4. Field 'invoice_layout > logo_url': ${layoutLogoUrl ?? '(kosong)'}");

              // Collect candidates
              Set<String> candidates = {};

              // Helper function inside the scope
              void addCandidate(String? val) {
                  if (val == null || val.isEmpty) return;
                  if (val.startsWith('http')) {
                      candidates.add(val);
                  } else {
                      final cleanBase = baseUrl.replaceAll('/public', '');
                      final fileName = val.split('/').last;

                      // 1. Standard Storage
                      candidates.add('$cleanBase/storage/$val');
                      
                      // 2. Public Uploads (User specific case)
                      candidates.add('$baseUrl/uploads/invoice_logos/$fileName');
                      candidates.add('$cleanBase/uploads/invoice_logos/$fileName');
                      
                      // 3. Just Base + Path
                      candidates.add('$baseUrl/$val');
                      
                      // 4. Clean Base + Path
                      candidates.add('$cleanBase/$val');

                      // 5. Direct
                      candidates.add('$baseUrl/storage/$fileName');
                      candidates.add('$baseUrl/storage/invoice_logos/$fileName');
                      candidates.add('$cleanBase/storage/invoice_logos/$fileName');
                      candidates.add('https://donapos.serverzone.web.id/public/uploads/invoice_logos/$fileName');
                      candidates.add('https://donapos.serverzone.web.id/uploads/invoice_logos/$fileName');
                  }
              }

              addCandidate(logoUrl);
              addCandidate(logo);
              addCandidate(layoutLogo);
              addCandidate(layoutLogoUrl);

              setState(() {
                  _imageUrls = candidates.toList();
                  _isLoading = false;
              });

              _addLog("\n--- MENCOBA DOWNLOAD (${_imageUrls.length} URL) ---");
              for(var u in _imageUrls) {
                  _addLog("Coba: $u");
              }

          } else {
              _addLog("❌ Lokasi ID $locationId tidak ditemukan di response server.");
          }
      } else {
          _addLog("❌ Gagal mengambil data. ${response.body}");
      }

    } catch (e) {
      _addLog("❌ Exception: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
        title: 'DIAGNOSA LOGO',
        icon: Icons.bug_report,
        width: 800,
        height: 700,
        content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // LOG PANEL
                Expanded(
                    flex: 1,
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.black87,
                        child: SingleChildScrollView(
                            child: Text(_log, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 10)),
                        ),
                    ),
                ),
                const SizedBox(width: 16),
                
                // PREVIEW PANEL
                Expanded(
                    flex: 1,
                    child: Column(
                        children: [
                            const Text("PREVIEW GAMBAR DITEMUKAN:", style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Expanded(
                                child: _isLoading 
                                    ? const Center(child: DonaposLoader(size: 60))
                                    : _imageUrls.isEmpty 
                                        ? const Center(child: Text("Tidak ada kandidat URL gambar."))
                                        : ListView.builder(
                                            itemCount: _imageUrls.length,
                                            itemBuilder: (ctx, i) {
                                                final url = _imageUrls[i];
                                                return Card(
                                                    margin: const EdgeInsets.only(bottom: 16),
                                                    child: Column(
                                                        children: [
                                                            Container(
                                                                height: 100,
                                                                width: double.infinity,
                                                                color: Colors.grey.shade200,
                                                                alignment: Alignment.center,
                                                                child: Image.network(
                                                                    url,
                                                                    fit: BoxFit.contain,
                                                                    errorBuilder: (c,e,s) => const Column(
                                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                                        children: [
                                                                            Icon(Icons.broken_image, color: Colors.red),
                                                                            Text("Gagal Muat (404)", style: TextStyle(fontSize: 10, color: Colors.red))
                                                                        ],
                                                                    ),
                                                                    loadingBuilder: (c,child,progress) {
                                                                        if (progress == null) return child;
                                                                        return const Center(child: SizedBox(width: 20, height: 20, child: DonaposLoader(size: 20)));
                                                                    },
                                                                ),
                                                            ),
                                                            Padding(
                                                                padding: const EdgeInsets.all(8.0),
                                                                child: SelectableText(url, style: const TextStyle(fontSize: 8, color: Colors.black54), textAlign: TextAlign.center),
                                                            )
                                                        ],
                                                    ),
                                                );
                                            },
                                        ),
                            )
                        ],
                    ),
                )
            ],
        ),
    );
  }
}

// Extension to expose protected method for this debug tool (hacky but works for quick debug)
extension ApiServiceHeader on ApiService {
     Future<Map<String, String>> getHeaders() async {
          // Re-implement or expose
         // Since I can't easily modify the original class to expose private `_getHeaders`, 
         // I'll just reimplement logic here or assume public if I made it public. 
         // Checking... `_getHeaders` is private in `ApiService`.
         // I will have to rely on `getHeaders` if I add it, or just use shared prefs here.
         
         // Fix: create local logic
         return {}; 
     }
}
