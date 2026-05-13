import 'package:donapos_mobile/design_system.dart';
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:donapos_mobile/widgets/attendance_dialog.dart';
import 'package:donapos_mobile/widgets/confirm_dialog.dart';
import 'package:provider/provider.dart';
import 'package:donapos_mobile/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:donapos_mobile/utils_printer.dart';
import 'package:donapos_mobile/screens/sales_graph_screen.dart';
import 'dart:typed_data';
import 'package:donapos_mobile/config.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:donapos_mobile/icod_printer.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class ReportDialog extends StatefulWidget {
  const ReportDialog({super.key});

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final ApiService _apiService = ApiService();
  int _selectedTab = 0; // 0: Shift, 1: Z-Report
  
  bool _isLoading = false;
  Map<String, dynamic>? _shiftData;
  Map<String, dynamic>? _zReportData;
  List<Map<String, dynamic>>? _productSummaryData;
  List<Map<String, dynamic>>? _productReportData;
  List<Map<String, dynamic>>? _categorySummaryData;
  List<Map<String, dynamic>>? _saleTypeSummaryData;
  List<Map<String, dynamic>>? _attendanceData;
  List<Map<String, dynamic>>? _tableReportData; 
  List<Map<String, dynamic>>? _expenseReportData;
  DateTime _zReportDate = DateTime.now();
  DateTime _prodStartDate = DateTime.now();
  DateTime _prodEndDate = DateTime.now();
  DateTime _attStartDate = DateTime.now();
  DateTime _attEndDate = DateTime.now();
  DateTime _expStartDate = DateTime.now();
  DateTime _expEndDate = DateTime.now();

  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  bool _connected = false;
  String? _cashierName;
  double? _initialCash;
  String? _businessName;
  String? _locationName;
  bool _showAppVersion = true;
  String _appVersion = "";
  final List<bool> _closingChecklist = [false, false, false, false, false];
  bool _isDemoMode = false;

  String _printerType = 'bluetooth'; // bluetooth, icod
  String _icodConnType = 'usb'; // usb, serial
  String _icodSerialPath = '/dev/ttyS0';

  @override
  void initState() {
    super.initState();
    _initPrinter();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final bizName = await _apiService.getBusinessName();
    final locName = await _apiService.getLocationName();
    final pkg = await PackageInfo.fromPlatform();
    if (mounted) {
       setState(() {
          _cashierName = prefs.getString('last_user_name');
          _initialCash = prefs.getDouble('initial_cash');
          _businessName = bizName;
          _locationName = locName;
          _showAppVersion = prefs.getBool('show_report_app_version') ?? true;
          _appVersion = "${pkg.version}+${pkg.buildNumber}";
          _isDemoMode = prefs.getBool('is_demo_mode') ?? false;
          _printerType = prefs.getString('printer_type') ?? 'bluetooth';
          _icodConnType = prefs.getString('icod_printer_conn_type') ?? 'usb';
          _icodSerialPath = prefs.getString('icod_printer_path') ?? '/dev/ttyS0';
       });
    }
    
    // Load sequentially to prevent database locking/busy errors
    await _fetchShiftReport();
    await _fetchZReport();
    await Future.wait([
        _fetchProductSummary(),
        _fetchCategorySummary(),
        _fetchSaleTypeSummary(),
    ]);
    await _fetchAttendanceReport();
    await _fetchTableReport(); 
    await _fetchExpenseReport();
    await _fetchProductReport();
  }

  void _initPrinter() async {
    bool connected = false;
    if (_printerType == 'bluetooth') {
        bool? isConnected = await bluetooth.isConnected;
        connected = isConnected ?? false;
    } else {
        connected = await IcodPrinter.isConnected();
    }
    if (mounted) setState(() => _connected = connected);
  }

  Future<void> _printRawLine(String text, {int align = 0, bool bold = false, int? fontTypeOverride}) async {
    final prefs = await SharedPreferences.getInstance();
    final fontType = fontTypeOverride ?? prefs.getInt('printer_font_type') ?? 1;
    
    final bytes = <int>[];
    bytes.addAll(PrinterUtils.getAlignBytes(align));
    bytes.addAll(PrinterUtils.getFontBytes(fontType, bold: bold));
    bytes.addAll(PrinterUtils.textToBytes(text));
    bytes.addAll(PrinterUtils.getNewLineBytes());
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(bytes));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(bytes));
    }
  }

  Future<void> _printLRLine(String left, String right, {bool bold = false, int? fontTypeOverride}) async {
    final prefs = await SharedPreferences.getInstance();
    final fontType = fontTypeOverride ?? prefs.getInt('printer_font_type') ?? 1;
    final maxChars = PrinterUtils.getMaxChars(fontType);
    
    final bytes = <int>[];
    bytes.addAll(PrinterUtils.getAlignBytes(0));
    bytes.addAll(PrinterUtils.getFontBytes(fontType, bold: bold));
    
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
    
    bytes.addAll(PrinterUtils.textToBytes(line));
    bytes.addAll(PrinterUtils.getNewLineBytes());
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(bytes));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(bytes));
    }
  }

  int _shiftReportId = 0; // 0: Joint, 1: Shift 1, 2: Shift 2

  Widget _tableHeader(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black38)),
    );
  }

  Widget _tableCell(String val, {TextAlign textAlign = TextAlign.left, bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(val, textAlign: textAlign, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, fontSize: 10, color: isBold ? MetroColors.text : Colors.black87)),
    );
  }

  Widget _dateDisplay(DateTime date, Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(data: ThemeData.dark(), child: child!)
        );
        if (picked != null) onPick(picked);
      },
      child: Row(
        children: [
          Text(DateFormat('dd/MM/yyyy').format(date).toUpperCase(), style: const TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(width: 8),
          const Icon(Icons.calendar_month, size: 16, color: MetroColors.primary)
        ],
      ),
    );
  }

  Future<void> _fetchShiftReport() async {
    if (mounted) setState(() => _isLoading = true);
    try {

      final data = await DatabaseHelper.instance.getLocalShiftReport(
          _cashierName
      );
      if (mounted) setState(() => _shiftData = data);
    } catch (e) {
      print("Shift Report Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchExpenseReport() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getExpenseReport(_expStartDate, _expEndDate);
      if (mounted) setState(() => _expenseReportData = data);
    } catch (e) {
      print("Expense Report Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchZReport() async {
    if (mounted) setState(() => _isLoading = true);
    try {

      final data = await DatabaseHelper.instance.getLocalZReport();
      if (mounted) setState(() => _zReportData = data);
    } catch (e) {
      print("Z Report Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProductSummary() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_zReportDate);
      final data = await DatabaseHelper.instance.getLocalProductSummary(dateStr);
      if (mounted) setState(() => _productSummaryData = data);
    } catch (e) {
      print("Product Summary Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProductReport() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getProductReport(_prodStartDate, _prodEndDate);
      if (mounted) setState(() => _productReportData = data);
    } catch (e) {
      print("Product Report Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCategorySummary() async {
    if (mounted) setState(() => _isLoading = true);
    try {

      final data = await DatabaseHelper.instance.getLocalCategorySummaryRange(_zReportDate, _zReportDate);
      if (mounted) setState(() => _categorySummaryData = data);
    } catch (e) {
      print("Category Summary Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSaleTypeSummary() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_zReportDate);
      final data = await DatabaseHelper.instance.getLocalSaleTypeSummary(dateStr);
      if (mounted) setState(() => _saleTypeSummaryData = data);
    } catch (e) {
      print("Sale Type Summary Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAttendanceReport() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_attStartDate);
      final endStr = DateFormat('yyyy-MM-dd').format(_attEndDate);
      final data = await DatabaseHelper.instance.getAttendanceLogs(
        startDate: startStr,
        endDate: endStr,
        limit: 100
      );
      if (mounted) setState(() => _attendanceData = data);
    } catch (e) {
      print("Attendance Report Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTableReport() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getTableReport(_zReportDate);
      if (mounted) setState(() => _tableReportData = data);
    } catch (e) {
      print("Table Report Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _hasHeldTransactions() async {
    final held = await DatabaseHelper.instance.getAllHeldTransactions();
    if (held.isNotEmpty) {
      if (mounted) {
        showAppModal(
          context, 
          title: 'TRANSAKSI HOLD', 
          message: 'MASIH ADA ${held.length} TRANSAKSI HOLD! SELESAIKAN ATAU BATALKAN DAHULU SEBELUM CLOSING / CETAK LAPORAN.',
          isError: true
        );
      }
      return true;
    }
    return false;
  }

  Future<void> _runClosingDay() async {
    if (await _hasHeldTransactions()) return;
    
    // RESET CHECKLIST EVERY TIME DIALOG OPENS
    setState(() {
      for (int i = 0; i < _closingChecklist.length; i++) {
        _closingChecklist[i] = false;
      }
    });

    final checklistItems = [
      "Pastikan uang setoran dan bon sudah rapih.",
      "Alat kerja sudah dikembalikan pada tempatnya.",
      "Kompor, dan Gas sudah dalam kondisi mati.",
      "Semua laporan sudah dicetak.",
      "Kunci laci dan pintu sudah siap."
    ];

    bool confirm = await showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          bool allChecked = _closingChecklist.every((e) => e == true);
          return GlassDialog(
            title: 'KONFIRMASI FINAL CLOSING',
            icon: Icons.security,
            iconColor: MetroColors.error,
            width: 550,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PERHATIAN: TINDAKAN INI BERSIFAT FINAL!', 
                    style: TextStyle(color: MetroColors.error, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Harap centang semua poin di bawah ini untuk melanjutkan proses penutupan hari (Closing Day):', 
                    style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Column(
                      children: List.generate(checklistItems.length, (index) {
                        return CheckboxListTile(
                          value: _closingChecklist[index],
                          onChanged: (v) {
                            setDialogState(() => _closingChecklist[index] = v ?? false);
                            setState(() => _closingChecklist[index] = v ?? false); // Keep parent in sync
                          },
                          title: Text(checklistItems[index], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: MetroColors.error,
                          dense: true,
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '* Tombol closing hanya akan aktif jika semua poin di atas telah dicentang.',
                    style: TextStyle(color: Colors.red, fontSize: 9.5, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            footer: Row(
              children: [
                Expanded(
                  child: MetroButton(
                    label: 'BATAL', 
                    onPressed: () => Navigator.pop(ctx, false),
                    color: Colors.black.withOpacity(0.05),
                    textColor: Colors.black38,
                    isSecondary: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetroButton(
                    label: 'YA, JALANKAN CLOSING', 
                    onPressed: allChecked ? () => Navigator.pop(ctx, true) : null,
                    color: allChecked ? MetroColors.error : Colors.grey[300]!,
                    textColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
      )
    ) ?? false;

    if (!confirm) return;

    showPowerfulLoader(context, message: 'MELAKUKAN CLOSING DAY...');
    try {
      await _apiService.closingDay();
      await DatabaseHelper.instance.closeDayLocal();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_cashier_open', false);

      if (mounted) {
         Navigator.pop(context); // Close loader
         showAppModal(context, title: 'BERHASIL', message: 'CLOSING DAY BERHASIL SELESAI!');
         await Future.delayed(const Duration(seconds: 2));
         
         // Offer Clock Out
         final confirmOut = await showAppConfirm(
           context,
           title: 'ABSENSI',
           message: 'APAKAH ANDA INGIN MELAKUKAN CLOCK OUT SEKARANG?',
           confirmLabel: 'YA, ABSEN PULANG',
           cancelLabel: 'NANTI SAJA'
         );

         if (confirmOut == true) {
            final prefs = await SharedPreferences.getInstance();
            final userId = prefs.getInt('last_user_id') ?? 0;
            final userName = prefs.getString('last_user_name') ?? 'Cashier';
            
            if (mounted) {
              final result = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => AttendanceDialog(userId: userId, username: userName)
              );
              
              if (result == true) {
                 if (Platform.isAndroid || Platform.isIOS) {
                    SystemNavigator.pop();
                 } else {
                    exit(0);
                 }
                 return;
              }
            }
         }

         if (mounted) {
           Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
         }
      }
    } catch (e) {
      if (mounted) {
          Navigator.pop(context); // Close loader
          showAppModal(context, title: 'GAGAL', message: 'CLOSING GAGAL: $e', isError: true);
      }
    }
  }

  void _printShiftReport() async {
    if (await _hasHeldTransactions()) return;
    if (_shiftData == null) return;
    
    bool connected = false;
    if (_printerType == 'bluetooth') {
        connected = await bluetooth.isConnected ?? false;
    } else {
        connected = await IcodPrinter.isConnected();
    }

    if (!connected) {
       showAppModal(context, title: 'PRINTER', message: 'PRINTER TIDAK TERHUBUNG!', isError: true);
       return;
    }

    final d = _shiftData!;
    final sales = d['sales'];
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // --- RAW SETUP ---
    final esc = PrinterUtils.esc;
    final prefs = await SharedPreferences.getInstance();
    final fontType = prefs.getInt('printer_font_type') ?? 1;
    final maxChars = PrinterUtils.getMaxChars(fontType);
    
    // Init
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList([esc, 0x40]));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList([esc, 0x40]));
    }

    await _printRawLine("=== LAPORAN KASIR ===", align: 1, bold: true);
    
    if (_isDemoMode) {
        await _printRawLine("*** DEMO MODE ***", align: 1, bold: true);
        await _printRawLine("TIDAK VALID UNTUK TRANSAKSI", align: 1);
        
        if (_printerType == 'bluetooth') {
            await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        } else {
            await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        }
    }

    await _printLRLine("Kasir", d['kasir_name']);
    await _printLRLine("Tanggal", d['tanggal']);
    await _printLRLine("Shift", "${d['jam_login']} - NOW");
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }
    
    await _printLRLine("Total Transaksi", "${d['total_transactions']}");
    await _printLRLine("Total Item", "${d['total_items']}");
    if (_initialCash != null) await _printLRLine("Modal Awal", currency.format(_initialCash));
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }
    
    await _printRawLine("--- PENJUALAN ---", align: 1, bold: true);
    await _printLRLine("Omzet Kotor", currency.format(sales['omzet_kotor']));
    await _printLRLine("Diskon", currency.format(sales['total_diskon']));
    await _printLRLine("Pajak", currency.format(sales['pajak']));
    await _printLRLine("Total Refund", currency.format(d['total_refunded'] ?? 0));
    await _printRawLine("-" * maxChars, align: 1);
    
    double nettSales = (sales['total_bersih'] as num).toDouble();
    double expenses = (d['total_expenses'] as num).toDouble();
    await _printLRLine("TOTAL BERSIH (NETT)", currency.format(nettSales - expenses), bold: true);
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }
    
    await _printRawLine("--- PEMBAYARAN ---", align: 1, bold: true);
    final payments = d['payments'] as Map<String, dynamic>;
    for (var entry in payments.entries) {
      if ((entry.value as num) > 0) await _printLRLine(entry.key.toUpperCase(), currency.format(entry.value));
    }
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }

    await _printRawLine("--- PENGELUARAN ---", align: 1, bold: true);
    await _printLRLine("Uang Keluar", currency.format(expenses));
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }

    await _printLRLine("UANG DI KASIR", currency.format(nettSales - expenses + (_initialCash ?? 0)), bold: true);
    await _printRawLine("=" * maxChars, align: 1);
    
    if (_showAppVersion) {
        await _printRawLine("${AppConfig.appName} v$_appVersion", align: 1);
    }
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await bluetooth.paperCut();
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await IcodPrinter.cutPaper();
    }
  }

  void _printZReport() async {
    if (await _hasHeldTransactions()) return;
    if (_zReportData == null) return;
    
    bool connected = false;
    if (_printerType == 'bluetooth') {
        connected = await bluetooth.isConnected ?? false;
    } else {
        connected = await IcodPrinter.isConnected();
    }

    if (!connected) {
       showAppModal(context, title: 'PRINTER', message: 'PRINTER TIDAK TERHUBUNG!', isError: true);
       return;
    }

    final d = _zReportData!;
    final sales = d['total_sales'];
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // --- RAW SETUP ---
    final esc = PrinterUtils.esc;
    final prefs = await SharedPreferences.getInstance();
    final fontType = prefs.getInt('printer_font_type') ?? 1;
    final maxChars = PrinterUtils.getMaxChars(fontType);
    
    // Init
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList([esc, 0x40]));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList([esc, 0x40]));
    }

    await _printRawLine("===== Z REPORT =====", align: 1, bold: true);
    
    if (_isDemoMode) {
        await _printRawLine("*** DEMO MODE ***", align: 1, bold: true);
        await _printRawLine("TIDAK VALID UNTUK TRANSAKSI", align: 1);
        
        if (_printerType == 'bluetooth') {
            await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        } else {
            await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        }
    }
    
    await _printLRLine("Tanggal", d['tanggal']);
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }

    await _printLRLine("Total Kasir", "${d['total_kasir']}");
    await _printLRLine("Total Transaksi", "${d['total_transactions']}");
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }
    
    await _printRawLine("--- TOTAL SALES ---", align: 1, bold: true);
    await _printLRLine("Diskon", currency.format(sales['diskon']));
    await _printLRLine("Pajak", currency.format(sales['pajak']));
    await _printLRLine("Total Refund", currency.format(d['total_refunded'] ?? 0));
    await _printRawLine("-" * maxChars, align: 1);
    
    double nettSales = (sales['total_bersih'] as num).toDouble();
    double expenses = (d['total_expenses'] as num).toDouble();
    await _printLRLine("TOTAL BERSIH (NETT)", currency.format(nettSales - expenses), bold: true);
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }
    
    await _printRawLine("--- PAYMENT ---", align: 1, bold: true);
    final payments = d['payments'] as Map<String, dynamic>;
    for (var entry in payments.entries) {
      if ((entry.value as num) > 0) await _printLRLine(entry.key.toUpperCase(), currency.format(entry.value));
    }
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }
    
    await _printLRLine("Total Pengeluaran", currency.format(d['total_expenses'] ?? 0));
    await _printLRLine("STATUS", d['status'], bold: true);
    await _printRawLine("=" * maxChars, align: 1);
    
    if (_showAppVersion) {
        await _printRawLine("${AppConfig.appName} v$_appVersion", align: 1);
    }
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await bluetooth.paperCut();
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await IcodPrinter.cutPaper();
    }
  }

  void _printProductSummary() async {
    if (await _hasHeldTransactions()) return;
    if (_productSummaryData == null || _productSummaryData!.isEmpty) return;
    
    bool connected = false;
    if (_printerType == 'bluetooth') {
        connected = await bluetooth.isConnected ?? false;
    } else {
        connected = await IcodPrinter.isConnected();
    }

    if (!connected) {
       showAppModal(context, title: 'PRINTER', message: 'PRINTER TIDAK TERHUBUNG!', isError: true);
       return;
    }
    
    // --- RAW SETUP ---
    final esc = PrinterUtils.esc;
    final prefs = await SharedPreferences.getInstance();
    final fontType = prefs.getInt('printer_font_type') ?? 1;
    final maxChars = PrinterUtils.getMaxChars(fontType);
    
    // Init
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList([esc, 0x40]));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList([esc, 0x40]));
    }

    // --- START PRINTING ---
    try {
      // 1. HEADER (Center, Bold)
      await _printRawLine("TOP TEN HARI INI", align: 1, bold: true);
      
      if (_isDemoMode) {
         await _printRawLine("*** DEMO MODE ***", align: 1, bold: true);
      }

      // 2. INFO (Center, Normal)
      String dateStr = DateFormat('dd/MM/yyyy').format(_zReportDate);
      await _printRawLine("BISNIS: ${_businessName?.toUpperCase() ?? '-'}", align: 1);
      await _printRawLine("LOKASI: ${_locationName?.toUpperCase() ?? '-'}", align: 1);
      await _printRawLine("KASIR: ${_cashierName?.toUpperCase() ?? '-'}", align: 1);
      await _printRawLine("TANGGAL: $dateStr", align: 1);
      
      if (_printerType == 'bluetooth') {
          await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
      } else {
          await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
      }

      // 3. TABLE HEADER (Left, Bold)
      await _printLRLine("NO   PRODUK", "QTY", bold: true);
      await _printRawLine("-" * maxChars);

      // 4. TABLE CONTENT (Left, Normal)
      int idx = 1;
      for (var item in _productSummaryData!.take(10)) {
         String name = item['product_name'] ?? '-';
         int qty = (item['total_qty'] as num).toInt();
         
         String left = "$idx. $name";
         String right = "$qty";
         
         await _printLRLine(left, right);
         idx++;
      }
      
      await _printRawLine("-" * maxChars);
      if (_showAppVersion) {
          await _printRawLine("${AppConfig.appName} v$_appVersion", align: 1);
      }
      
      if (_printerType == 'bluetooth') {
          await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
          await bluetooth.paperCut();
      } else {
          await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
          await IcodPrinter.cutPaper();
      }
      
    } catch (e) {
      print("Print Error: $e");
    }
  }

  void _printCategorySummary() async {
    if (await _hasHeldTransactions()) return;
    if (_categorySummaryData == null || _categorySummaryData!.isEmpty) return;
    
    bool connected = false;
    if (_printerType == 'bluetooth') {
        connected = await bluetooth.isConnected ?? false;
    } else {
        connected = await IcodPrinter.isConnected();
    }

    if (!connected) {
       showAppModal(context, title: 'PRINTER', message: 'PRINTER TIDAK TERHUBUNG!', isError: true);
       return;
    }

    final currency = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    String dateStr = DateFormat('dd MMM yyyy').format(_zReportDate);

    // --- RAW SETUP ---
    final esc = PrinterUtils.esc;
    final prefs = await SharedPreferences.getInstance();
    final fontType = prefs.getInt('printer_font_type') ?? 1;
    final maxChars = PrinterUtils.getMaxChars(fontType);
    
    // Init
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList([esc, 0x40]));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList([esc, 0x40]));
    }

    await _printRawLine("=== CATEGORY SUMMARY ===", align: 1, bold: true);
    
    if (_isDemoMode) {
        await _printRawLine("*** DEMO MODE ***", align: 1, bold: true);
    }
    await _printRawLine(dateStr, align: 1);
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }
    
    await _printLRLine("Category", "Qty   Total", bold: true);
    await _printRawLine("-" * maxChars, align: 1);
    
    double grandTotal = 0;
    int totalQty = 0;

    for (var item in _categorySummaryData!) {
      String name = item['category_name'] ?? 'Uncategorized';
      
      int qty = item['total_qty'];
      double total = (item['total_sales'] as num).toDouble();
      grandTotal += total;
      totalQty += qty;

      String qtyStr = qty.toString().padLeft(3);
      String totalStr = currency.format(total).padLeft(10);
      
      await _printLRLine(name, "$qtyStr $totalStr");
    }
    
    await _printRawLine("-" * maxChars, align: 1);
    await _printLRLine("TOTAL", "$totalQty ${currency.format(grandTotal).padLeft(10)}", bold: true);
    if (_showAppVersion) {
        await _printRawLine("${AppConfig.appName} v$_appVersion", align: 1);
    }
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await bluetooth.paperCut();
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await IcodPrinter.cutPaper();
    }
  }

  void _printSaleTypeSummary() async {
    if (await _hasHeldTransactions()) return;
    if (_saleTypeSummaryData == null || _saleTypeSummaryData!.isEmpty) return;
    
    bool connected = false;
    if (_printerType == 'bluetooth') {
        connected = await bluetooth.isConnected ?? false;
    } else {
        connected = await IcodPrinter.isConnected();
    }

    if (!connected) {
       showAppModal(context, title: 'PRINTER', message: 'PRINTER TIDAK TERHUBUNG!', isError: true);
       return;
    }

    final currency = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    String dateStr = DateFormat('dd MMM yyyy').format(_zReportDate);

    // --- RAW SETUP ---
    final esc = PrinterUtils.esc;
    final prefs = await SharedPreferences.getInstance();
    final fontType = prefs.getInt('printer_font_type') ?? 1;
    final maxChars = PrinterUtils.getMaxChars(fontType);
    
    // Init
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList([esc, 0x40]));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList([esc, 0x40]));
    }

    await _printRawLine("=== TIPE PESANAN SUMMARY ===", align: 1, bold: true);
    
    if (_isDemoMode) {
        await _printRawLine("*** DEMO MODE ***", align: 1, bold: true);
    }
    await _printRawLine(dateStr, align: 1);
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }
    
    await _printLRLine("Tipe Pesanan", "Qty   Total", bold: true);
    await _printRawLine("-" * maxChars, align: 1);
    
    double grandTotal = 0;
    int totalQty = 0;

    for (var item in _saleTypeSummaryData!) {
      String name = item['sale_type']?.toString().toUpperCase() ?? 'UNKNOWN';
      if (name == 'DINEIN') name = 'DINE IN';
      else if (name == 'TAKEAWAY') name = 'TAKE AWAY';
      
      int qty = (item['total_count'] as num).toInt();
      double total = (item['total_sales'] as num).toDouble();
      grandTotal += total;
      totalQty += qty;

      String qtyStr = qty.toString().padLeft(3);
      String totalStr = currency.format(total).padLeft(10);
      
      await _printLRLine(name, "$qtyStr $totalStr");
    }
    
    await _printRawLine("-" * maxChars, align: 1);
    await _printLRLine("TOTAL", "$totalQty ${currency.format(grandTotal).padLeft(10)}", bold: true);
    if (_showAppVersion) {
        await _printRawLine("${AppConfig.appName} v$_appVersion", align: 1);
    }
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await bluetooth.paperCut();
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await IcodPrinter.cutPaper();
    }
  }

  void _printTableReport() async {
    if (_tableReportData == null || _tableReportData!.isEmpty) return;
    
    bool connected = false;
    if (_printerType == 'bluetooth') {
        connected = await bluetooth.isConnected ?? false;
    } else {
        connected = await IcodPrinter.isConnected();
    }

    if (!connected) {
       showAppModal(context, title: 'PRINTER', message: 'PRINTER TIDAK TERHUBUNG!', isError: true);
       return;
    }

    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    String dateStr = DateFormat('dd MMM yyyy').format(_zReportDate);

    // --- RAW SETUP ---
    final esc = PrinterUtils.esc;
    final prefs = await SharedPreferences.getInstance();
    final fontType = prefs.getInt('printer_font_type') ?? 1;
    final maxChars = PrinterUtils.getMaxChars(fontType);
    
    // Init
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList([esc, 0x40]));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList([esc, 0x40]));
    }

    await _printRawLine("=== LAPORAN MEJA ===", align: 1, bold: true);
    
    if (_isDemoMode) {
        await _printRawLine("*** DEMO MODE ***", align: 1, bold: true);
    }
    await _printRawLine(dateStr, align: 1);
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }

    for (var item in _tableReportData!) {
      await _printLRLine(item['table_name'] ?? 'Meja', "PAX: ${item['total_pax']}", bold: true);
      await _printLRLine("   Tx: ${item['total_transactions']}", currency.format(item['total_revenue']));
    }
    
    await _printRawLine("-" * maxChars, align: 1);
    final totalRev = _tableReportData!.fold(0.0, (sum, item) => sum + (item['total_revenue'] as num).toDouble());
    await _printLRLine("TOTAL", currency.format(totalRev), bold: true);
    if (_showAppVersion) {
        await _printRawLine("${AppConfig.appName} v$_appVersion", align: 1);
    }
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await bluetooth.paperCut();
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await IcodPrinter.cutPaper();
    }
  }

  void _printAttendanceReport() async {
    if (_attendanceData == null || _attendanceData!.isEmpty) return;
    
    bool connected = false;
    if (_printerType == 'bluetooth') {
        connected = await bluetooth.isConnected ?? false;
    } else {
        connected = await IcodPrinter.isConnected();
    }

    if (!connected) {
       showAppModal(context, title: 'PRINTER', message: 'PRINTER TIDAK TERHUBUNG!', isError: true);
       return;
    }

    // --- RAW SETUP ---
    final esc = PrinterUtils.esc;
    final prefs = await SharedPreferences.getInstance();
    final fontType = prefs.getInt('printer_font_type') ?? 1;
    final maxChars = PrinterUtils.getMaxChars(fontType);
    
    // Init
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList([esc, 0x40]));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList([esc, 0x40]));
    }

    await _printRawLine("=== LAPORAN ABSENSI ===", align: 1, bold: true);
    
    if (_isDemoMode) {
        await _printRawLine("*** DEMO MODE ***", align: 1, bold: true);
    }
    final rangeStr = "${DateFormat('dd/MM/yy').format(_attStartDate)} - ${DateFormat('dd/MM/yy').format(_attEndDate)}";
    await _printRawLine(rangeStr, align: 1);
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }
    
    for (var log in _attendanceData!) {
      final clockIn = DateTime.parse(log['clock_in']);
      final clockOut = log['clock_out'] != null ? DateTime.parse(log['clock_out']) : null;
      
      await _printLRLine(log['username'].toString().toUpperCase(), log['status'] == 'active' ? 'AKTIF' : 'SELESAI', bold: true);
      await _printLRLine("Masuk", DateFormat('dd/MM HH:mm').format(clockIn));
      if (clockOut != null) await _printLRLine("Pulang", DateFormat('dd/MM HH:mm').format(clockOut));
      
      final duration = _formatDuration(clockIn, clockOut);
      await _printLRLine("Durasi Kerja", duration, bold: true);
      await _printRawLine("-" * maxChars, align: 1);
    }
    
    if (_showAppVersion) {
        await _printRawLine("${AppConfig.appName} v$_appVersion", align: 1);
    }
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await bluetooth.paperCut();
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await IcodPrinter.cutPaper();
    }
  }

  void _printProductReport() async {
    if (_productReportData == null || _productReportData!.isEmpty) return;
    
    bool connected = false;
    if (_printerType == 'bluetooth') {
        connected = await bluetooth.isConnected ?? false;
    } else {
        connected = await IcodPrinter.isConnected();
    }

    if (!connected) {
       showAppModal(context, title: 'PRINTER', message: 'PRINTER TIDAK TERHUBUNG!', isError: true);
       return;
    }
    
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final esc = PrinterUtils.esc;
    final prefs = await SharedPreferences.getInstance();
    final fontType = prefs.getInt('printer_font_type') ?? 1;
    final maxChars = PrinterUtils.getMaxChars(fontType);
    
    // Init
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList([esc, 0x40]));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList([esc, 0x40]));
    }

    await _printRawLine("=== LAPORAN PRODUK ===", align: 1, bold: true);
    
    if (_isDemoMode) {
        await _printRawLine("*** DEMO MODE ***", align: 1, bold: true);
    }
    String period = "${DateFormat('dd/MM/yy').format(_prodStartDate)} - ${DateFormat('dd/MM/yy').format(_prodEndDate)}";
    await _printRawLine(period, align: 1);
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }
    
    await _printLRLine("Produk", "Qty   Total", bold: true);
    await _printRawLine("-" * maxChars, align: 1);
    
    double grandTotal = 0;
    int totalQty = 0;

    for (var item in _productReportData!) {
      String name = item['product_name'] ?? '-';
      int qty = (item['total_qty'] as num).toInt();
      double total = (item['total_revenue'] as num).toDouble();
      grandTotal += total;
      totalQty += qty;

      String qtyStr = qty.toString().padLeft(3);
      String totalStr = currency.format(total).padLeft(10);
      
      await _printLRLine(name, "$qtyStr $totalStr");
    }
    
    await _printRawLine("-" * maxChars, align: 1);
    await _printLRLine("TOTAL", "$totalQty ${currency.format(grandTotal).padLeft(10)}", bold: true);
    if (_showAppVersion) {
        await _printRawLine("${AppConfig.appName} v$_appVersion", align: 1);
    }
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await bluetooth.paperCut();
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await IcodPrinter.cutPaper();
    }
  }

  void _printExpenseReport() async {
    if (_expenseReportData == null || _expenseReportData!.isEmpty) return;
    
    bool connected = false;
    if (_printerType == 'bluetooth') {
        connected = await bluetooth.isConnected ?? false;
    } else {
        connected = await IcodPrinter.isConnected();
    }

    if (!connected) {
       showAppModal(context, title: 'PRINTER', message: 'PRINTER TIDAK TERHUBUNG!', isError: true);
       return;
    }

    final currency = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    String period = "${DateFormat('dd/MM/yy').format(_expStartDate)} - ${DateFormat('dd/MM/yy').format(_expEndDate)}";

    // --- RAW SETUP ---
    final esc = PrinterUtils.esc;
    final prefs = await SharedPreferences.getInstance();
    final fontType = prefs.getInt('printer_font_type') ?? 1;
    final maxChars = PrinterUtils.getMaxChars(fontType);
    
    // Init
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList([esc, 0x40]));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList([esc, 0x40]));
    }

    await _printRawLine("LAPORAN PENGELUARAN", align: 1, bold: true);
    
    if (_isDemoMode) {
        await _printRawLine("*** DEMO MODE ***", align: 1, bold: true);
    }
    await _printRawLine(period, align: 1);
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
    }
    
    await _printLRLine("Keterangan", "Jumlah", bold: true);
    await _printRawLine("-" * maxChars, align: 1);
    
    double total = 0;
    for (var item in _expenseReportData!) {
      String cat = item['category_name'] ?? 'Lain-lain';
      String note = item['additional_notes'] ?? '';
      double amount = (item['final_total'] as num).toDouble();
      total += amount;

      await _printLRLine("$cat ${note.isNotEmpty ? '($note)' : ''}", currency.format(amount));
    }
    
    await _printRawLine("-" * maxChars, align: 1);
    await _printLRLine("TOTAL BIAYA", currency.format(total), bold: true);
    if (_showAppVersion) {
        await _printRawLine("${AppConfig.appName} v$_appVersion", align: 1);
    }
    
    if (_printerType == 'bluetooth') {
        await bluetooth.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await bluetooth.paperCut();
    } else {
        await IcodPrinter.printRaw(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
        await IcodPrinter.cutPaper();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return GlassDialog(
      title: 'Laporan & Closing',
      icon: Icons.analytics,
      width: (MediaQuery.of(context).orientation == Orientation.landscape) ? 1100 : 600,
      height: MediaQuery.of(context).size.height * ((MediaQuery.of(context).orientation == Orientation.landscape) ? 0.92 : 0.85),
      actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: MetroColors.primary),
              onPressed: () => _loadData(),
          )
      ],
      content: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            border: const Border(bottom: BorderSide(color: Colors.black12, width: 1))
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                  _buildPortraitTabItem(0, 'SHIFT'),
                  _buildPortraitTabItem(1, 'Z-REPORT'),
                  _buildPortraitTabItem(2, 'MEJA'),
                  _buildPortraitTabItem(3, 'KATEGORI'),
                  _buildPortraitTabItem(4, 'TIPE'),
                  _buildPortraitTabItem(5, 'TOP TEN'),
                  _buildPortraitTabItem(6, 'GRAFIK'),
                  _buildPortraitTabItem(7, 'BIAYA'),
                   _buildPortraitTabItem(8, 'ABSENSI'),
                   _buildPortraitTabItem(10, 'PRODUK'),
                   _buildPortraitTabItem(9, 'CLOSING'),
               ]),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _isLoading 
             ? const Center(child: DonaposLoader(size: 80))
             : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildContent(),
              ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 280,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Colors.black12, width: 1))
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  _buildMetroMenuItem(0, 'LAPORAN SHIFT', Icons.receipt_long),
                  const SizedBox(height: 8),
                  _buildMetroMenuItem(1, 'Z-REPORT HARIAN', Icons.today),
                  const SizedBox(height: 8),
                  _buildMetroMenuItem(2, 'LAPORAN MEJA', Icons.table_restaurant),
                  const SizedBox(height: 8),
                  _buildMetroMenuItem(3, 'RINGKASAN KATEGORI', Icons.category),
                  const SizedBox(height: 8),
                  _buildMetroMenuItem(4, 'RINGKASAN TIPE', Icons.shopping_cart),
                  const SizedBox(height: 8),
                  _buildMetroMenuItem(5, 'TOP TEN HARI INI', Icons.star, color: Colors.orange),
                  const SizedBox(height: 8),
                  _buildMetroMenuItem(6, 'GRAFIK PENJUALAN', Icons.bar_chart, color: MetroColors.accent),
                  const SizedBox(height: 8),
                  _buildMetroMenuItem(7, 'LAPORAN BIAYA', Icons.payments, color: Colors.red),
                  const SizedBox(height: 8),
                   _buildMetroMenuItem(8, 'LAPORAN ABSENSI', Icons.fingerprint),
                   const SizedBox(height: 8),
                   _buildMetroMenuItem(10, 'LAPORAN PRODUK', Icons.inventory_2, color: Colors.blueAccent),
                   const SizedBox(height: 32),
                  const Divider(color: Colors.black12, thickness: 1),
                  const SizedBox(height: 32),
                  _buildMetroMenuItem(9, 'CLOSING HARIAN', Icons.lock_clock, color: MetroColors.error),
                  const SizedBox(height: 64),
                ],
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1, color: Colors.black12),
        Expanded(
          child: _isLoading 
             ? const Center(child: DonaposLoader(size: 80))
             : Padding(
                 padding: const EdgeInsets.all(24),
                 child: _buildContent(),
               ),
        ),
      ],
    );
  }

  Widget _buildMetroMenuItem(int index, String title, IconData icon, {Color? color}) {
    final isSelected = _selectedTab == index;
    final activeColor = color ?? MetroColors.primary;
    return Material(
      color: isSelected ? activeColor : Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _onTabSelected(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
               Icon(icon, color: isSelected ? Colors.white : (color ?? MetroColors.text), size: 22),
               const SizedBox(width: 16),
               Expanded(
                 child: Text(
                   title.toUpperCase(), 
                   style: TextStyle(
                     color: isSelected ? Colors.white : (color ?? MetroColors.text), 
                     fontSize: 11.7, 
                     fontWeight: FontWeight.w900, 
                     letterSpacing: 1
                   )
                 )
               ),
               if (isSelected) const Icon(Icons.chevron_right, color: Colors.white, size: 16)
            ],
          ),
        ),
      ),
    );
  }

  void _onTabSelected(int index) {
     setState(() => _selectedTab = index);
     if (index == 0 && _shiftData == null) _fetchShiftReport();
     if (index == 1 && _zReportData == null) _fetchZReport();
     if (index == 2 && _tableReportData == null) _fetchTableReport();
     if (index == 3 && _categorySummaryData == null) _fetchCategorySummary();
     if (index == 4 && _saleTypeSummaryData == null) _fetchSaleTypeSummary();
     if (index == 5 && _productSummaryData == null) _fetchProductSummary();
     if (index == 7 && _expenseReportData == null) _fetchExpenseReport();
     if (index == 8 && _attendanceData == null) _fetchAttendanceReport();
     if (index == 10 && _productReportData == null) _fetchProductReport();
  }

  Widget _buildContent() {
      if (_selectedTab == 0) return _buildShiftContent();
      if (_selectedTab == 1) return _buildZReportContent();
      if (_selectedTab == 2) return _buildTableReportContent();
      if (_selectedTab == 3) return _buildCategorySummaryContent();
      if (_selectedTab == 4) return _buildSaleTypeSummaryContent();
      if (_selectedTab == 5) return _buildProductSummaryContent();
      if (_selectedTab == 6) return const SalesGraphTab();
      if (_selectedTab == 7) return _buildExpenseContent();
      if (_selectedTab == 8) return _buildAttendanceContent();
      if (_selectedTab == 10) return _buildProductReportContent();
      return _buildClosingDayContent();
  }

  Widget _buildShiftTabItem(int id, String label) {
      final isActive = _shiftReportId == id;
      return GestureDetector(
          onTap: () {
              setState(() => _shiftReportId = id);
              _fetchShiftReport();
          },
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: isActive ? MetroColors.primary : Colors.white,
                  border: Border.all(color: isActive ? MetroColors.primary : Colors.black12),
                  borderRadius: BorderRadius.zero
              ),
              child: Text(label, textAlign: TextAlign.center, style: TextStyle(
                  color: isActive ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.w900,
                  fontSize: 10
              )),
          ),
      );
  }

  Widget _buildPortraitTabItem(int index, String title) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabSelected(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: isSelected ? MetroColors.primary : Colors.transparent,
          alignment: Alignment.center,
          child: Text(title, style: TextStyle(
            color: isSelected ? Colors.white : MetroColors.primary,
            fontWeight: FontWeight.w900,
            fontSize: 9.9,
            letterSpacing: 1
          )),
        ),
      ),
    );
  }

  Widget _buildShiftContent() {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, 
      children: [
        // DATE SELECTOR
        InkWell(
           onTap: () async {
              final picked = await showDatePicker(
                 context: context, 
                 initialDate: _zReportDate, 
                 firstDate: DateTime(2020), 
                 lastDate: DateTime.now(),
                 builder: (context, child) => Theme(data: ThemeData.dark(), child: child!)
              );
              if (picked != null) {
                setState(() => _zReportDate = picked);
                _fetchShiftReport();
              }
           },
           child: Container(
              padding: const EdgeInsets.all(16),
              color: MetroColors.textDark,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                 const Text('PILIH TANGGAL:', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                 Row(children: [
                    Text(DateFormat('dd MMM yyyy').format(_zReportDate).toUpperCase(), style: const TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_month, size: 18, color: MetroColors.primary)
                 ])
              ]),
           ),
        ),
        const SizedBox(height: 12),
        // SHIFT SELECTOR
        Container(
          color: Colors.black.withOpacity(0.03),
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text("SHIFT:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(width: 12),
                SizedBox(width: 120, child: _buildShiftTabItem(0, "GABUNGAN")),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: _buildShiftTabItem(1, "SHIFT 1")),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: _buildShiftTabItem(2, "SHIFT 2")),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        if (_shiftData == null)
          const Expanded(child: Center(child: DonaposLoader(size: 80)))
        else ...[
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                 padding: const EdgeInsets.all(24),
                 color: Colors.transparent,
                 child: Column(children: [
                    _row('KASIR', _shiftData!['kasir_name'].toUpperCase(), isBold: true),
                    _row('TANGGAL', _shiftData!['tanggal'].toString().toUpperCase(), isBold: true),
                    _row('PERIODE', '${_shiftData!['jam_login']} - NOW'.toUpperCase()),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.black12),
                    const SizedBox(height: 24),
                    if (_initialCash != null) 
                        _row('MODAL AWAL KAS', currency.format(_initialCash)),
                    _row('TOTAL TRANSAKSI', '${_shiftData!['total_transactions']}'),
                    _row('TOTAL ITEM TERJUAL', '${_shiftData!['total_items']}'),
                    _row('TOTAL PENGELUARAN', currency.format(_shiftData!['total_expenses'] ?? 0), color: Colors.red),
                    _row('TOTAL REFUND', currency.format(_shiftData!['total_refunded'] ?? 0), color: Colors.orange),
                    const SizedBox(height: 16),
                    _row('OMZET KOTOR', currency.format(_shiftData!['sales']['omzet_kotor'])),
                    _row('TOTAL DISKON', currency.format(_shiftData!['sales']['total_diskon'])),
                    _row('TOTAL PAJAK', currency.format(_shiftData!['sales']['pajak'])),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.black12),
                    const SizedBox(height: 24),
                    _row('TOTAL BERSIH (NETT)', currency.format(_shiftData!['sales']['total_bersih'] - (_shiftData!['total_expenses'] ?? 0)), isBold: true, color: MetroColors.retailPrimary, size: 22),
                    _row('UANG DI KASIR', currency.format(_shiftData!['sales']['total_bersih'] - (_shiftData!['total_expenses'] ?? 0) + (_initialCash ?? 0)), isBold: true, color: Colors.green, size: 18),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: const Text('(TERMASUK MODAL AWAL)', style: TextStyle(color: Colors.black26, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 32),
                        const Divider(color: Colors.black12),
                        const SizedBox(height: 24),
                        const Text('RINCIAN PEMBAYARAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.5)),
                        const SizedBox(height: 16),
                        ...(_shiftData!['payments'] as Map<String, dynamic>).entries.map((e) {
                           if ((e.value as num) <= 0) return const SizedBox.shrink();
                           return _row(e.key.toUpperCase(), currency.format(e.value), color: Colors.blueGrey);
                        }).toList(),
                        const SizedBox(height: 80),
                 ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          MetroButton(
             label: 'CETAK LAPORAN KASIR',
             icon: Icons.print,
             onPressed: _printShiftReport,
             color: MetroColors.primary,
          )
        ]
      ],
    );
  }

  Widget _buildZReportContent() {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
           onTap: () async {
              final picked = await showDatePicker(
                 context: context, 
                 initialDate: _zReportDate, 
                 firstDate: DateTime(2020), 
                 lastDate: DateTime.now(),
                 builder: (context, child) => Theme(data: ThemeData.dark(), child: child!)
              );
              if (picked != null) {
                setState(() => _zReportDate = picked);
                _fetchZReport();
              }
           },
           child: Container(
              padding: const EdgeInsets.all(16),
              color: MetroColors.textDark,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                 const Text('PILIH TANGGAL:', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                 Row(children: [
                    Text(DateFormat('dd MMM yyyy').format(_zReportDate).toUpperCase(), style: const TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_month, size: 18, color: MetroColors.primary)
                 ])
              ]),
           ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _zReportData != null ? SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.transparent,
              child: Column(children: [
                _row('TANGGAL LAPORAN', _zReportData!['tanggal'].toString().toUpperCase(), isBold: true),
                const Divider(color: Colors.black12, height: 40),
                _row('TOTAL TRANSAKSI', '${_zReportData!['total_transactions']}'),
                _row('TOTAL KASIR AKTIF', '${_zReportData!['total_kasir']}'),
                _row('TOTAL PENGELUARAN', currency.format(_zReportData!['total_expenses'] ?? 0), color: Colors.red),
                _row('TOTAL REFUND', currency.format(_zReportData!['total_refunded'] ?? 0), color: Colors.orange),
                const SizedBox(height: 24),
                _row('OMZET HARIAN (NETT)', currency.format((_zReportData!['total_sales']['total_bersih'] as num).toDouble() - (_zReportData!['total_expenses'] ?? 0)), isBold: true, color: MetroColors.retailPrimary, size: 22),
                const SizedBox(height: 32),
                const Divider(color: Colors.black12),
                const SizedBox(height: 24),
                const Text('RINCIAN PEMBAYARAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.5)),
                const SizedBox(height: 16),
                ...(_zReportData!['payments'] as Map<String, dynamic>).entries.map((e) {
                    if ((e.value as num) <= 0) return const SizedBox.shrink();
                    return _row(e.key.toUpperCase(), currency.format(e.value), color: Colors.blueGrey);
                }).toList(),
                const SizedBox(height: 40),
              ]),
            ),
          ) : const Center(child: Text('DATA TIDAK DITEMUKAN', style: TextStyle(color: Colors.black12, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(height: 16),
        MetroButton(
          label: 'CETAK Z-REPORT',
          icon: Icons.print,
          onPressed: _printZReport,
          color: MetroColors.primary,
          textColor: Colors.white,
        ),
        const SizedBox(height: 48),
    ]);
  }

  Widget _row(String label, String val, {bool isBold = false, Color color = MetroColors.text, double size = 14}) {
      return Padding(
         padding: const EdgeInsets.symmetric(vertical: 6),
         child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: const TextStyle(color: Colors.black38, fontSize: 10.8, fontWeight: FontWeight.bold)),
            Text(val, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, fontSize: size)),
         ]),
      );
  }

  Widget _smallRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black26, fontSize: 8, fontWeight: FontWeight.bold)),
          Text(val, style: const TextStyle(color: MetroColors.text, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildProductSummaryContent() {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, 
        children: [
           _buildDatePickerHeader(),
           const SizedBox(height: 16),
           const Text("TOP TEN HARI INI", textAlign: TextAlign.center, style: TextStyle(color: MetroColors.primary, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
           const SizedBox(height: 16),
           
           Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(color: Colors.grey[100], border: Border.all(color: Colors.black12)),
             child: Column(children: [
               _smallRow('BISNIS', _businessName?.toUpperCase() ?? '-'),
               _smallRow('LOKASI', _locationName?.toUpperCase() ?? '-'),
               _smallRow('KASIR', _cashierName?.toUpperCase() ?? '-'),
               _smallRow('TANGGAL', DateFormat('dd/MM/yyyy').format(_zReportDate)),
             ]),
           ),
           
           const SizedBox(height: 16),
           _productSummaryData != null && _productSummaryData!.isNotEmpty ? Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(6),
                  2: FlexColumnWidth(2),
                },
                border: TableBorder.all(color: Colors.black12, width: 1),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey[100]),
                    children: [
                      _tableHeader('NO'),
                      _tableHeader('PRODUK'),
                      _tableHeader('QTY'),
                    ]
                  ),
                  ..._productSummaryData!.take(10).toList().asMap().entries.map((entry) {
                    int idx = entry.key + 1;
                    Map<String, dynamic> item = entry.value;
                    return TableRow(
                      children: [
                        _tableCell('$idx', textAlign: TextAlign.center),
                        _tableCell(item['product_name']?.toUpperCase() ?? '-'),
                        _tableCell('${item['total_qty']}X', textAlign: TextAlign.center, isBold: true),
                      ]
                    );
                  }),
                ],
              ),
           ) : const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('TIDAK ADA PENJUALAN PRODUK', style: TextStyle(color: Colors.black12, fontWeight: FontWeight.bold)))),

            const SizedBox(height: 16),
            MetroButton(
              label: 'CETAK TOP 10 PRODUK',
              icon: Icons.print,
              onPressed: _printProductSummary,
              color: MetroColors.primary,
            ),
            const SizedBox(height: 48),
      ]));
  }

  Widget _buildCategorySummaryContent() {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
         _buildDatePickerHeader(),
         const SizedBox(height: 16),
         Expanded(
           child: _categorySummaryData != null && _categorySummaryData!.isNotEmpty ? Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(2),
                  },
                  border: TableBorder.all(color: Colors.black12, width: 1),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey[100]),
                      children: [
                        _tableHeader('KATEGORI'),
                        _tableHeader('QTY'),
                        _tableHeader('TOTAL'),
                      ]
                    ),
                    ..._categorySummaryData!.map((item) => TableRow(
                      children: [
                        _tableCell(item['category_name']?.toUpperCase() ?? 'UNCATEGORIZED'),
                        _tableCell('${item['total_qty']}X', textAlign: TextAlign.center),
                        _tableCell(currency.format(item['total_sales']), textAlign: TextAlign.right, isBold: true),
                      ]
                    )),
                  ],
                ),
              ),
           ) : const Center(child: Text('TIDAK ADA PENJUALAN KATEGORI', style: TextStyle(color: Colors.black12, fontWeight: FontWeight.bold))),
         ),
         const SizedBox(height: 16),
         MetroButton(
           label: 'CETAK SUMMARY KATEGORI',
           icon: Icons.print,
           onPressed: _printCategorySummary,
           color: MetroColors.primary,
         ),
         const SizedBox(height: 48),
    ]);

  }

  Widget _buildSaleTypeSummaryContent() {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
         _buildDatePickerHeader(),
         const SizedBox(height: 16),
         Expanded(
           child: _saleTypeSummaryData != null && _saleTypeSummaryData!.isNotEmpty ? Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(2),
                  },
                  border: TableBorder.all(color: Colors.black12, width: 1),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey[100]),
                      children: [
                        _tableHeader('TIPE PESANAN'),
                        _tableHeader('QTY'),
                        _tableHeader('TOTAL'),
                      ]
                    ),
                    ..._saleTypeSummaryData!.map((item) {
                      String type = item['sale_type']?.toString().toUpperCase() ?? 'UNKNOWN';
                      if (type == 'DINEIN') type = 'DINE IN';
                      if (type == 'TAKEAWAY') type = 'TAKE AWAY';
                      
                      return TableRow(
                        children: [
                          _tableCell(type),
                          _tableCell('${item['total_count']}X', textAlign: TextAlign.center),
                          _tableCell(currency.format(item['total_sales']), textAlign: TextAlign.right, isBold: true),
                        ]
                      );
                    }),
                  ],
                ),
              ),
           ) : const Center(child: Text('TIDAK ADA DATA TIPE PESANAN', style: TextStyle(color: Colors.black12, fontWeight: FontWeight.bold))),
         ),
         const SizedBox(height: 16),
         MetroButton(
           label: 'CETAK SUMMARY TIPE PESANAN',
           icon: Icons.print,
           onPressed: _printSaleTypeSummary,
           color: MetroColors.primary,
         ),
         const SizedBox(height: 48),
    ]);
  }

  Widget _buildAttendanceContent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
         _buildDateRangePickerHeader(),
         const SizedBox(height: 16),
         Expanded(
           child: _attendanceData != null && _attendanceData!.isNotEmpty ? Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.5),
                    1: FlexColumnWidth(1.8),
                    2: FlexColumnWidth(1.8),
                    3: FlexColumnWidth(1.5),
                    4: FlexColumnWidth(1),
                  },
                  border: TableBorder.all(color: Colors.black12, width: 1),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey[100]),
                      children: [
                        _tableHeader('NAMA'),
                        _tableHeader('MASUK'),
                        _tableHeader('PULANG'),
                        _tableHeader('DURASI'),
                        _tableHeader('STS'),
                      ]
                    ),
                    ..._attendanceData!.map((item) {
                      final clockIn = DateTime.parse(item['clock_in']);
                      final clockOut = item['clock_out'] != null ? DateTime.parse(item['clock_out']) : null;
                      return TableRow(
                        children: [
                          _tableCell(item['username']?.toUpperCase() ?? '-'),
                          _tableCell(DateFormat('dd/MM HH:mm').format(clockIn)),
                          _tableCell(clockOut != null ? DateFormat('dd/MM HH:mm').format(clockOut) : '-'),
                          _tableCell(_formatDuration(clockIn, clockOut), isBold: true),
                          _tableCell(item['status'] == 'active' ? 'AKTIF' : 'OK', textAlign: TextAlign.center, isBold: item['status'] == 'active'),
                        ]
                      );
                    }),
                  ],
                ),
              ),
           ) : const Center(child: Text('TIDAK ADA DATA ABSENSI', style: TextStyle(color: Colors.black12, fontWeight: FontWeight.bold))),
         ),
         const SizedBox(height: 16),
         MetroButton(
           label: 'CETAK LAPORAN ABSENSI',
           icon: Icons.print,
           onPressed: _printAttendanceReport,
           color: MetroColors.primary,
         ),
         const SizedBox(height: 48),
    ]);
  }

  Widget _buildDateRangePickerHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black.withOpacity(0.05),
      child: Row(
        children: [
          const Text('RENTANG WAKTU:', style: TextStyle(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const Spacer(),
          _dateDisplay(_attStartDate, (d) {
            setState(() => _attStartDate = d);
            _fetchAttendanceReport();
          }),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('-', style: TextStyle(color: Colors.black26, fontWeight: FontWeight.bold)),
          ),
          _dateDisplay(_attEndDate, (d) {
            setState(() => _attEndDate = d);
            _fetchAttendanceReport();
          }),
        ],
      ),
    );
  }

  Widget _buildExpenseContent() {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
         _buildExpenseDatePickerHeader(),
         const SizedBox(height: 16),
         Expanded(
           child: _expenseReportData != null && _expenseReportData!.isNotEmpty ? Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.5),
                    1: FlexColumnWidth(2.5),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(1),
                  },
                  border: TableBorder.all(color: Colors.black12, width: 1),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey[100]),
                      children: [
                        _tableHeader('TANGGAL'),
                        _tableHeader('KATEGORI'),
                        _tableHeader('JUMLAH'),
                        _tableHeader('SYNC'),
                      ]
                    ),
                    ..._expenseReportData!.map((item) {
                      return TableRow(
                        children: [
                          _tableCell(item['transaction_date']),
                          _tableCell(item['category_name']?.toUpperCase() ?? 'UNCATEGORIZED'),
                          _tableCell(currency.format(item['final_total']), textAlign: TextAlign.right, isBold: true),
                          _tableCell(item['is_synced'] == 1 ? '✓' : '✗', textAlign: TextAlign.center),
                        ]
                      );
                    }),
                  ],
                ),
              ),
           ) : const Center(child: Text('TIDAK ADA DATA PENGELUARAN', style: TextStyle(color: Colors.black12, fontWeight: FontWeight.bold))),
         ),
         const SizedBox(height: 16),
         MetroButton(
           label: 'CETAK LAPORAN BIAYA',
           icon: Icons.print,
           onPressed: _printExpenseReport,
           color: MetroColors.primary,
         ),
         const SizedBox(height: 48),
    ]);
  }

  Widget _buildExpenseDatePickerHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black.withOpacity(0.05),
      child: Row(
        children: [
          const Text('RENTANG WAKTU:', style: TextStyle(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const Spacer(),
          _dateDisplay(_expStartDate, (d) {
            setState(() => _expStartDate = d);
            _fetchExpenseReport();
          }),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('-', style: TextStyle(color: Colors.black26, fontWeight: FontWeight.bold)),
          ),
          _dateDisplay(_expEndDate, (d) {
            setState(() => _expEndDate = d);
            _fetchExpenseReport();
          }),
        ],
      ),
    );
  }





  Widget _buildTableReportContent() {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
         _buildDatePickerHeader(),
         const SizedBox(height: 16),
         Expanded(
           child: _tableReportData != null && _tableReportData!.isNotEmpty ? Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(4),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(3),
                  },
                  border: TableBorder.all(color: Colors.black12, width: 1),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey[100]),
                      children: [
                        _tableHeader('MEJA'),
                        _tableHeader('PAX'),
                        _tableHeader('TOTAL'),
                      ]
                    ),
                    ..._tableReportData!.map((item) => TableRow(
                      children: [
                        _tableCell(item['table_name']?.toUpperCase() ?? 'MEJA #${item['res_table_id']}'),
                        _tableCell('${item['total_pax']}', textAlign: TextAlign.center),
                        _tableCell(currency.format(item['total_revenue']), textAlign: TextAlign.right, isBold: true),
                      ]
                    )),
                  ],
                ),
              ),
           ) : const Center(child: Text('TIDAK ADA DATA MEJA', style: TextStyle(color: Colors.black12, fontWeight: FontWeight.bold))),
         ),
         const SizedBox(height: 16),
         MetroButton(
           label: 'CETAK LAPORAN MEJA',
           icon: Icons.print,
           onPressed: _printTableReport,
           color: MetroColors.primary,
         ),
         const SizedBox(height: 48),
    ]);
  }

  Widget _buildDatePickerHeader() {
    return InkWell(
       onTap: () async {
          final picked = await showDatePicker(
             context: context, 
             initialDate: _zReportDate, 
             firstDate: DateTime(2020), 
             lastDate: DateTime.now(),
             builder: (context, child) => Theme(data: ThemeData.dark(), child: child!)
          );
          if (picked != null) {
            setState(() => _zReportDate = picked);
            _fetchShiftReport();
            _fetchZReport();
            _fetchProductSummary();
            _fetchCategorySummary();
            _fetchSaleTypeSummary();
            _fetchTableReport();
            _fetchAttendanceReport();
          }
       },
       child: Container(
          padding: const EdgeInsets.all(16),
          color: MetroColors.textDark,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
             const Text('TANGGAL LAPORAN:', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
             Row(children: [
                Text(DateFormat('dd MMM yyyy').format(_zReportDate).toUpperCase(), style: const TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900)),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_month, size: 18, color: MetroColors.primary)
             ])
          ]),
       ),
    );
  }



  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) return "MASIH AKTIF";
    final diff = end.difference(start);
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return "${hours}j ${mins}m";
  }

  Widget _buildProductReportContent() {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black.withOpacity(0.05),
          child: Row(
            children: [
              const Text('PERIODE PRODUK:', style: TextStyle(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const Spacer(),
              _dateDisplay(_prodStartDate, (d) {
                setState(() => _prodStartDate = d);
                _fetchProductReport();
              }),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("-", style: TextStyle(color: Colors.black26)),
              ),
              _dateDisplay(_prodEndDate, (d) {
                setState(() => _prodEndDate = d);
                _fetchProductReport();
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _productReportData != null && _productReportData!.isNotEmpty ? Container(
             color: Colors.white,
             padding: const EdgeInsets.all(16),
             child: SingleChildScrollView(
               child: Table(
                 columnWidths: const {
                   0: FlexColumnWidth(4),
                   1: FlexColumnWidth(1),
                   2: FlexColumnWidth(2),
                 },
                 border: TableBorder.all(color: Colors.black12, width: 1),
                 children: [
                   TableRow(
                     decoration: BoxDecoration(color: Colors.grey[100]),
                     children: [
                       _tableHeader('PRODUK'),
                       _tableHeader('QTY'),
                       _tableHeader('TOTAL'),
                     ]
                   ),
                   ..._productReportData!.map((item) {
                     return TableRow(
                       children: [
                         _tableCell(item['product_name']?.toUpperCase() ?? '-'),
                         _tableCell('${item['total_qty']}X', textAlign: TextAlign.center),
                         _tableCell(currency.format(item['total_revenue']), textAlign: TextAlign.right, isBold: true),
                       ]
                     );
                   }),
                 ],
               ),
             ),
          ) : const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('TIDAK ADA DATA PENJUALAN PRODUK', style: TextStyle(color: Colors.black12, fontWeight: FontWeight.bold)))),
        ),
        const SizedBox(height: 16),
        MetroButton(
          label: 'CETAK LAPORAN PRODUK',
          icon: Icons.print,
          onPressed: _printProductReport,
          color: MetroColors.retailPrimary,
        ),
        const SizedBox(height: 48),
    ]);
  }

  Widget _buildClosingDayContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_clock, size: 80, color: MetroColors.error),
          const SizedBox(height: 24),
          const Text("CLOSING HARIAN", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          const Text("PROSES PENUTUPAN HARI DAN PENGUNCIAN TRANSAKSI", textAlign: TextAlign.center, style: TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12)
            ),
            child: const Column(
              children: [
                Text("PENTING:", style: TextStyle(fontWeight: FontWeight.w900, color: MetroColors.error)),
                const SizedBox(height: 12),
                Text("Pastikan semua laporan sudah dicetak sebelum melakukan closing. Tindakan ini tidak dapat dibatalkan.", 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black54, fontWeight: FontWeight.bold)
                ),
                SizedBox(height: 8),
                Text("KLIK TOMBOL DI BAWAH UNTUK MELANJUTKAN KE TAHAP KONFIRMASI FINAL.", 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.black26, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 350,
            child: MetroButton(
              label: 'LANJUTKAN KE CLOSING',
              icon: Icons.chevron_right,
              onPressed: _runClosingDay,
              color: MetroColors.error,
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
