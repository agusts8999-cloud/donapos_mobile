import 'package:donapos_mobile/design_system.dart';
import 'package:flutter/material.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:donapos_mobile/utils_printer.dart';
import 'dart:typed_data';
import 'package:donapos_mobile/config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:donapos_mobile/widgets/printer_settings_dialog.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class AttendanceDialog extends StatefulWidget {
  final int userId;
  final String username;

  const AttendanceDialog({
    super.key, 
    required this.userId, 
    required this.username
  });

  @override
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<AttendanceDialog> {
  bool _isLoading = true;
  Map<String, dynamic>? _activeAttendance;
  List<Map<String, dynamic>> _logs = [];
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  int _selectedShift = 1;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadLastShift();
  }

  Future<void> _loadLastShift() async {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
          _selectedShift = prefs.getInt('active_shift') ?? 1;
      });
  }

  Widget _buildShiftOption(int id, String label) {
      final isActive = _selectedShift == id;
      return GestureDetector(
          onTap: () => setState(() => _selectedShift = id),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                  color: isActive ? MetroColors.primary : Colors.black.withOpacity(0.05),
                  border: Border.all(color: isActive ? MetroColors.primary : Colors.black12),
                  borderRadius: BorderRadius.zero
              ),
              child: Text(label, style: TextStyle(
                  color: isActive ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.w900,
                  fontSize: 12
              )),
          ),
      );
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    final active = await DatabaseHelper.instance.getActiveAttendance(widget.userId);
    final logs = await DatabaseHelper.instance.getAttendanceLogs(limit: 10);
    setState(() {
      _activeAttendance = active;
      _logs = logs;
      _isLoading = false;
    });
  }

  Future<Map<String, String?>> _getLocationAndIp() async {
      String? ip;
      String? lat;
      String? long;
      String? address; // Currently unused or mapped to lat/long string?

      // 1. Get IP
      try {
          final response = await http.get(Uri.parse('https://api.ipify.org')).timeout(const Duration(seconds: 3));
          if (response.statusCode == 200) ip = response.body;
      } catch (_) {}

      // 2. Get Location
      try {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (serviceEnabled) {
              LocationPermission permission = await Geolocator.checkPermission();
              if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
              }
              
              if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
                  Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 5));
                  lat = position.latitude.toString();
                  long = position.longitude.toString();
                  address = '$lat,$long';
              }
          }
      } catch (_) {}
      
      return {'ip': ip, 'lat': lat, 'long': long, 'address': address};
  }

  Future<void> _clockIn() async {
    try {
      setState(() => _isLoading = true);
      
      // Fetch metadata
      final meta = await _getLocationAndIp();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('active_shift', _selectedShift);
      
      await DatabaseHelper.instance.clockIn(
        widget.userId, 
        widget.username,
        ip: meta['ip'],
        lat: meta['lat'],
        long: meta['long'],
        address: meta['address']
      );
      
      // Prepare print data before closing dialog
      final data = {
        'username': widget.username,
        'type': 'CLOCK IN (MASUK)',
        'shift': 'SHIFT $_selectedShift',
        'time': DateTime.now()
      };
      
      // Close dialog immediately — clock in is saved
      if (mounted) Navigator.pop(context);
      
      // Fire-and-forget: print slip asynchronously
      _safePrintAttendanceSlip(data);
      ApiService().syncAttendances();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDebugErrorDialog(context, title: 'GAGAL SIMPAN ABSENSI', error: e.toString());
      }
    }
  }

  Future<void> _clockOut() async {
    try {
      setState(() => _isLoading = true);
      
      final meta = await _getLocationAndIp();
      
      final prefs = await SharedPreferences.getInstance();
      int currentShift = prefs.getInt('active_shift') ?? 1;
      
      await DatabaseHelper.instance.clockOut(
        widget.userId,
        lat: meta['lat'],
        long: meta['long'],
        address: meta['address']
      );
      final data = {
        'username': widget.username,
        'type': 'CLOCK OUT (PULANG)',
        'shift': 'SHIFT $currentShift',
        'time': DateTime.now()
      };
      
      await prefs.remove('active_shift');
      
      // Close dialog immediately — clock out is saved
      if (mounted) Navigator.pop(context, true);
      
      // Fire-and-forget: print slip asynchronously
      _safePrintAttendanceSlip(data);
      ApiService().syncAttendances();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDebugErrorDialog(context, title: 'GAGAL SIMPAN ABSENSI', error: e.toString());
      }
    }
  }

  /// Fire-and-forget wrapper: prints attendance slip with timeout protection.
  /// This method never blocks the caller — errors are logged silently.
  void _safePrintAttendanceSlip(Map<String, dynamic> data) {
    _printAttendanceSlip(data).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('[Attendance] Print timeout after 10 seconds — skipping.');
      },
    ).catchError((e) {
      debugPrint('[Attendance] Print error: $e');
    });
  }

  Future<void> _printAttendanceSlip(Map<String, dynamic> data) async {
    try {
      if (!(await bluetooth.isConnected ?? false)) {
        debugPrint('[Attendance] Printer not connected — skipping print.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final fontType = prefs.getInt('printer_font_type') ?? 1;
      
      // Init printer
      await bluetooth.writeBytes(Uint8List.fromList([0x1B, 0x40]));
      
      Future<void> printRaw(String text, {int align = 0, bool bold = false}) async {
          await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getAlignBytes(align)));
          await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getFontBytes(fontType, bold: bold)));
          await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.textToBytes(text)));
          await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
      }
      
      Future<void> printLR(String left, String right) async {
          final maxChars = PrinterUtils.getMaxChars(fontType);
          await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getAlignBytes(0)));
          await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getFontBytes(fontType)));
          
          int contentLen = left.length + right.length;
          String line;
          if (contentLen >= maxChars) {
             int available = maxChars - right.length - 1;
             if (available < 0) available = 0;
             line = "${left.substring(0, available)} $right";
          } else {
             int spaces = maxChars - contentLen;
             line = left + (" " * spaces) + right;
          }
          await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.textToBytes(line)));
          await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
      }

      final timeStr = DateFormat('dd MMM yyyy HH:mm:ss').format(data['time']);

      await printRaw("=== STRUK PRESENSI ===", align: 1, bold: true);
      await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
      
      await printRaw(data['type'], align: 1, bold: true);
      await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
      
      await printLR("Nama Staff", data['username'].toString().toUpperCase());
      await printLR("Pilihan Shift", data['shift'] ?? '-');
      await printLR("Waktu", timeStr);
      
      await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
      
      final maxChars = PrinterUtils.getMaxChars(fontType);
      await printRaw("-" * maxChars, align: 1);
      
      await printRaw("SIMPAN SEBAGAI BUKTI KEHADIRAN", align: 1, bold: true);
      
      final showVersion = prefs.getBool('show_report_app_version') ?? true;
      if (showVersion) {
          final pkg = await PackageInfo.fromPlatform();
          await printRaw("${AppConfig.appName} ${pkg.version}+${pkg.buildNumber}", align: 1);
      }

      await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
      await bluetooth.paperCut();
      
      debugPrint('[Attendance] Print slip completed successfully.');
    } catch (e) {
      debugPrint('[Attendance] Print error inside _printAttendanceSlip: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MetroColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: Row(
        children: [
          const Icon(Icons.fingerprint, color: MetroColors.primary, size: 28),
          const SizedBox(width: 16),
          const Text('PRESENSI KASIR', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black26),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      content: SizedBox(
        width: 800,
        height: 400, // Reduced from 500 to 400
        child: _isLoading 
          ? const Center(child: DonaposLoader(size: 80))
          : Row(
              children: [
                // Action Side
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // Reduced vertical padding
                    color: Colors.black.withOpacity(0.02),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.account_circle, size: 60, color: Colors.black12), // Reduced from 80 to 60
                          const SizedBox(height: 12),
                          Text(widget.username.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                            _activeAttendance != null ? 'STATUS: SEDANG BERTUGAS' : 'STATUS: BELUM ABSEN',
                            style: TextStyle(
                              color: _activeAttendance != null ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 11
                            ),
                          ),
                          const SizedBox(height: 20), // Reduced from 32
                          if (_activeAttendance == null) ...[
                            const Text("PILIH SHIFT TUGAS:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildShiftOption(1, "SHIFT 1"),
                                const SizedBox(width: 8),
                                _buildShiftOption(2, "SHIFT 2"),
                              ],
                            ),
                            const SizedBox(height: 16), // Reduced from 24
                            MetroButton(
                              label: 'CLOCK IN (MASUK)',
                              icon: Icons.login,
                              color: Colors.green,
                              onPressed: _clockIn,
                            ),
                          ] else
                            MetroButton(
                              label: 'CLOCK OUT (PULANG)',
                              icon: Icons.logout,
                              color: MetroColors.error,
                              onPressed: _clockOut,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // History Side
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RIWAYAT TERAKHIR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5, color: Colors.black38)),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _logs.isEmpty 
                            ? const Center(child: Text('BELUM ADA RIWAYAT', style: TextStyle(color: Colors.black12, fontWeight: FontWeight.bold)))
                            : ListView.separated(
                                itemCount: _logs.length,
                                separatorBuilder: (_, __) => const Divider(height: 24, color: Colors.black12),
                                itemBuilder: (ctx, i) {
                                  final log = _logs[i];
                                  final clockIn = DateTime.parse(log['clock_in']);
                                  final clockOut = log['clock_out'] != null ? DateTime.parse(log['clock_out']) : null;
                                  
                                  return Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: (log['status'] == 'active' ? Colors.green : Colors.grey).withOpacity(0.1),
                                          shape: BoxShape.circle
                                        ),
                                        child: Icon(
                                          log['status'] == 'active' ? Icons.play_arrow : Icons.stop,
                                          size: 16,
                                          color: log['status'] == 'active' ? Colors.green : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(log['username'].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                            Text(
                                              'MASUK: ${DateFormat('dd MMM HH:mm').format(clockIn)}',
                                              style: const TextStyle(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (clockOut != null)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text('PULANG', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black26)),
                                            Text(DateFormat('HH:mm').format(clockOut), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                                          ],
                                        )
                                      else
                                        const Text('AKTIF', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 10)),
                                    ],
                                  );
                                },
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
