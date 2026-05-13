import 'package:flutter/material.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:donapos_mobile/language_provider.dart';
import 'package:donapos_mobile/screens/sales_graph_screen.dart';
import 'package:donapos_mobile/config.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ApiService _apiService = ApiService();
  int _selectedIndex = 0;
  
  bool _isLoading = false;
  Map<String, dynamic>? _shiftData;
  Map<String, dynamic>? _zReportData;
  List<Map<String, dynamic>>? _tableReportData;
  List<Map<String, dynamic>>? _productReportData;
  DateTime _zReportDate = DateTime.now();
  DateTime _tableReportDate = DateTime.now();
  DateTime _productStartDate = DateTime.now();
  DateTime _productEndDate = DateTime.now();
  String? _cashierName;
  String? _businessName;
  String? _locationName;
  bool _showAppVersion = true;
  String _appVersion = "";

  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  bool _connected = false;

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
    setState(() {
        _cashierName = prefs.getString('last_user_name');
        _businessName = bizName;
        _locationName = locName;
        _showAppVersion = prefs.getBool('show_report_app_version') ?? true;
        _appVersion = "${pkg.version}+${pkg.buildNumber}";
    });
    _fetchShiftReport();
    _fetchZReport();
    _fetchTableReport();
    _fetchProductReport();
  }

  void _initPrinter() async {
    bool? isConnected = await bluetooth.isConnected;
    setState(() {
      _connected = isConnected ?? false;
    });
  }

  Future<void> _fetchShiftReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getLocalShiftReport(_cashierName);
      setState(() => _shiftData = data);
    } catch (e) {
      if (mounted) showAppModal(context, title: Provider.of<LanguageProvider>(context, listen: false).translate('report_error'), message: 'GAGAL MEMUAT RINGKASAN SHIFT: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchZReport() async {
    setState(() => _isLoading = true);
    try {
      // Fetch Active Open Session
      final data = await DatabaseHelper.instance.getLocalZReport();
      setState(() => _zReportData = data);
    } catch (e) {
      if (mounted) showAppModal(context, title: Provider.of<LanguageProvider>(context, listen: false).translate('report_error'), message: 'GAGAL MEMUAT Z-REPORT: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Report Fetch Methods)

  Widget _buildZReportTab(LanguageProvider lp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // REMOVED DATE PICKER - Z-Report is now strictly for the Active Session
        Container(
          padding: const EdgeInsets.all(20),
          color: MetroColors.surface,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
             const Text('CURRENT SESSION:', style: TextStyle(color: Colors.black38, fontSize: 9.9, fontWeight: FontWeight.bold)),
             Text('ACTIVE / OPEN', style: const TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 11.7)),
          ]),
        ),
        const SizedBox(height: 24),
        
        if (_zReportData != null) ...[
         Container(
           color: MetroColors.surface,
           padding: const EdgeInsets.all(24),
           child: Column(children: [
             Text(lp.translate('daily_z_report'), style: const TextStyle(color: MetroColors.primary, fontSize: 14.4, fontWeight: FontWeight.w900, letterSpacing: 1)),
             const SizedBox(height: 8),
             Text(_zReportData!['tanggal'].toString().toUpperCase(), style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 9.9)),
             const SizedBox(height: 24),
             const Divider(color: Colors.black12, height: 1),
             const SizedBox(height: 16),
             _row(lp.translate('total_transactions'), '${_zReportData!['total_transactions']}'),
             _row('TOTAL SALES', NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_zReportData!['total_sales']['total_bersih']), color: MetroColors.accent, isBold: true),
           ]),
         ),
         const SizedBox(height: 24),
          const SizedBox(height: 24),
          MetroButton(
            label: lp.translate('print_z_report'), 
            onPressed: _printZReport,
            color: MetroColors.retailPrimary,
            icon: Icons.print,
          ),
          const SizedBox(height: 80),
        ] else 
           Padding(padding: const EdgeInsets.only(top: 50), child: Center(child: Text(lp.translate('no_data_for_date'), style: const TextStyle(color: Colors.black26, fontWeight: FontWeight.bold, fontSize: 10.8))))
      ]),
    );
  }

  Future<void> _fetchTableReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getTableReport(_tableReportDate);
      setState(() => _tableReportData = data);
    } catch (e) {
      if (mounted) showAppModal(context, title: Provider.of<LanguageProvider>(context, listen: false).translate('report_error'), message: 'GAGAL MEMUAT LAPORAN MEJA: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProductReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getProductReport(_productStartDate, _productEndDate);
      setState(() => _productReportData = data);
    } catch (e) {
      if (mounted) showAppModal(context, title: Provider.of<LanguageProvider>(context, listen: false).translate('report_error'), message: 'GAGAL MEMUAT LAPORAN PRODUK: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  final List<bool> _closingChecklist = [false, false, false, false, false];

  Future<void> _runClosingDay() async {
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

    setState(() => _isLoading = true);
    try {
      await _apiService.closingDay();
      if (mounted) showAppModal(context, title: Provider.of<LanguageProvider>(context, listen: false).translate('success'), message: Provider.of<LanguageProvider>(context, listen: false).translate('closing_success_msg'));
      _fetchZReport();
    } catch (e) {
      if (mounted) showAppModal(context, title: Provider.of<LanguageProvider>(context, listen: false).translate('closing_failed'), message: 'GAGAL MEMPROSES CLOSING: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _printShiftReport() async {
    if (_shiftData == null) return;
    if (!(await bluetooth.isConnected ?? false)) {
       if (mounted) showAppModal(context, title: Provider.of<LanguageProvider>(context, listen: false).translate('printer_offline'), message: 'BLUETOOTH PRINTER TIDAK TERHUBUNG.', isError: true);
       return;
    }

    final d = _shiftData!;
    final sales = d['sales'];
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    bluetooth.printCustom("=== LAPORAN KASIR ===", 1, 1);
    bluetooth.printLeftRight("Kasir", d['kasir_name'], 0);
    bluetooth.printLeftRight("Tanggal", d['tanggal'], 0);
    bluetooth.printLeftRight("Shift", "${d['jam_login']} - NOW", 0);
    bluetooth.printNewLine();
    bluetooth.printLeftRight("Total Transaksi", "${d['total_transactions']}", 0);
    bluetooth.printLeftRight("Total Item", "${d['total_items']}", 0);
    bluetooth.printNewLine();
    bluetooth.printCustom("--- PENJUALAN ---", 1, 1);
    bluetooth.printLeftRight("Omzet Kotor", currency.format(sales['omzet_kotor']), 0);
    bluetooth.printLeftRight("Diskon", currency.format(sales['total_diskon']), 0);
    bluetooth.printLeftRight("Pajak", currency.format(sales['pajak']), 0);
    bluetooth.printCustom("-------------------", 1, 1);
    bluetooth.printLeftRight("TOTAL BERSIH", currency.format(sales['total_bersih']), 1);
    bluetooth.printNewLine();
    bluetooth.printCustom("--- PEMBAYARAN ---", 1, 1);
    final payments = d['payments'] as Map<String, dynamic>;
    payments.forEach((k, v) {
      if ((v as num) > 0) bluetooth.printLeftRight(k.toUpperCase(), currency.format(v), 0);
    });
    bluetooth.printNewLine();
    bluetooth.printCustom("--- ORDER TYPE ---", 1, 1);
    for (var o in d['order_types']) {
       bluetooth.printLeftRight(o['name'], currency.format(o['total_sales']), 0);
    }
    bluetooth.printCustom("===================", 1, 1);
    if (_showAppVersion) {
        bluetooth.printCustom("${AppConfig.appName} v$_appVersion", 0, 1);
    }
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  void _printZReport() async {
    if (_zReportData == null) return;
    if (!(await bluetooth.isConnected ?? false)) {
       if (mounted) showAppModal(context, title: Provider.of<LanguageProvider>(context, listen: false).translate('printer_offline'), message: 'BLUETOOTH PRINTER TIDAK TERHUBUNG.', isError: true);
       return;
    }

    final d = _zReportData!;
    final sales = d['total_sales'];
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    bluetooth.printCustom("===== Z REPORT =====", 2, 1);
    bluetooth.printLeftRight("Tanggal", d['tanggal'], 0);
    bluetooth.printNewLine();
    bluetooth.printLeftRight("Total Kasir", "${d['total_kasir']}", 0);
    bluetooth.printLeftRight("Total Transaksi", "${d['total_transactions']}", 0);
    bluetooth.printLeftRight("Total Item", "${d['total_items']}", 0);
    bluetooth.printNewLine();
    bluetooth.printCustom("--- TOTAL SALES ---", 1, 1);
    bluetooth.printLeftRight("Omzet Kotor", currency.format(sales['omzet_kotor']), 0);
    bluetooth.printLeftRight("Diskon", currency.format(sales['diskon']), 0);
    bluetooth.printLeftRight("Pajak", currency.format(sales['pajak']), 0);
    bluetooth.printCustom("-------------------", 1, 1);
    bluetooth.printLeftRight("TOTAL BERSIH", currency.format(sales['total_bersih']), 1);
    bluetooth.printNewLine();
    bluetooth.printCustom("--- PAYMENT ---", 1, 1);
    final payments = d['payments'] as Map<String, dynamic>;
    payments.forEach((k, v) {
      if ((v as num) > 0) bluetooth.printLeftRight(k.toUpperCase(), currency.format(v), 0);
    });
    bluetooth.printNewLine();
    bluetooth.printLeftRight("STATUS", d['status'], 1);
    bluetooth.printCustom("===================", 1, 1);
    if (_showAppVersion) {
        bluetooth.printCustom("${AppConfig.appName} v$_appVersion", 0, 1);
    }
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  void _printTopTenReport() async {
    if (_productReportData == null || _productReportData!.isEmpty) return;
    if (!(await bluetooth.isConnected ?? false)) {
       if (mounted) showAppModal(context, title: Provider.of<LanguageProvider>(context, listen: false).translate('printer_offline'), message: 'BLUETOOTH PRINTER TIDAK TERHUBUNG.', isError: true);
       return;
    }

    String period = "${DateFormat('dd/MM/yy').format(_productStartDate)} - ${DateFormat('dd/MM/yy').format(_productEndDate)}";

    bluetooth.printCustom("TOP TEN HARI INI", 1, 1);
    bluetooth.printCustom("BISNIS: ${_businessName?.toUpperCase() ?? '-'}", 0, 1);
    bluetooth.printCustom("LOKASI: ${_locationName?.toUpperCase() ?? '-'}", 0, 1);
    bluetooth.printCustom("KASIR: ${_cashierName?.toUpperCase() ?? '-'}", 0, 1);
    bluetooth.printCustom("PERIODE: $period", 0, 1);
    bluetooth.printNewLine();
    
    bluetooth.printLeftRight("NO   PRODUK", "QTY", 1);
    bluetooth.printCustom("--------------------------------", 1, 1);
    
    int idx = 1;
    for (var item in _productReportData!.take(10)) {
       String name = item['product_name'] ?? '-';
       int qty = item['total_qty'] ?? 0;
       
       String left = "$idx. $name";
       String right = "$qty";
       
       bluetooth.printLeftRight(left, right, 0);
       idx++;
    }
    
    bluetooth.printCustom("--------------------------------", 1, 1);
    if (_showAppVersion) {
        bluetooth.printCustom("${AppConfig.appName} v$_appVersion", 0, 1);
    }
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  void _printTableReport() async {
    if (_tableReportData == null || _tableReportData!.isEmpty) return;
    if (!(await bluetooth.isConnected ?? false)) {
       if (mounted) showAppModal(context, title: Provider.of<LanguageProvider>(context, listen: false).translate('printer_offline'), message: 'BLUETOOTH PRINTER TIDAK TERHUBUNG.', isError: true);
       return;
    }

    bluetooth.printCustom("LAPORAN PENJUALAN PER MEJA", 1, 1);
    bluetooth.printCustom(DateFormat('dd MMMM yyyy').format(_tableReportDate).toUpperCase(), 0, 1);
    bluetooth.printNewLine();
    
    bluetooth.printLeftRight("MEJA (PAX)", "TX   OMZET", 1);
    bluetooth.printCustom("--------------------------------", 1, 1);
    
    for (var d in _tableReportData!) {
       final tableName = d['table_name'] ?? 'Meja #${d['res_table_id']}';
       final pax = d['total_pax'] ?? 0;
       final tx = d['total_transactions'] ?? 0;
       final revenue = d['total_revenue'] ?? 0;
       
       bluetooth.printLeftRight("$tableName ($pax)", "$tx  ${NumberFormat('#,###').format(revenue)}", 0);
    }
    
    bluetooth.printCustom("--------------------------------", 1, 1);
    bluetooth.printLeftRight("TOTAL OMZET", NumberFormat('#,###').format(_tableReportData!.fold(0.0, (sum, item) => sum + (item['total_revenue'] as num).toDouble())), 1);
    bluetooth.printLeftRight("TOTAL TAMU", "${_tableReportData!.fold(0, (sum, item) => sum + (item['total_pax'] as int))}", 0);
    bluetooth.printCustom("================================", 1, 1);

    if (_showAppVersion) {
        bluetooth.printCustom("${AppConfig.appName} v$_appVersion", 0, 1);
    }
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: MetroColors.background,
      appBar: AppBar(
        title: Text(lp.translate('reports_closing'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: MetroColors.text, fontSize: 16.2)),
        backgroundColor: MetroColors.background,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: MetroColors.text), onPressed: () => Navigator.pop(context)),
        actions: [
            IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, color: MetroColors.primary)
            ),
        ],
      ),
      body: _isLoading ? Center(child: PowerfulLoader(message: lp.translate('connecting_to_server'))) : Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Colors.black12, width: 1))
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  children: [
                    _buildNavButton(0, lp.translate('shift_summary'), Icons.receipt_long),
                    const SizedBox(height: 8),
                    _buildNavButton(1, lp.translate('daily_z_report'), Icons.today),
                    const SizedBox(height: 8),
                    _buildNavButton(2, 'LAPORAN MEJA', Icons.table_restaurant),
                    const SizedBox(height: 8),
                    _buildNavButton(3, 'TOP TEN HARI INI', Icons.star, color: Colors.orange),
                    const SizedBox(height: 8),
                    _buildNavButton(4, 'GRAFIK PENJUALAN', Icons.bar_chart, color: MetroColors.accent),
                    const SizedBox(height: 32),
                    const Divider(color: Colors.black12, thickness: 1),
                    const SizedBox(height: 32),
                    _buildNavButton(5, 'CLOSING HARIAN', Icons.lock_clock, color: MetroColors.error),
                    const SizedBox(height: 64),
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.black12),
          // Content
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMainContent(lp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(int index, String label, IconData icon, {Color? color}) {
    bool isSelected = _selectedIndex == index;
    final activeColor = color ?? MetroColors.primary;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.black38, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? activeColor : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                  fontSize: 10.8,
                  letterSpacing: 0.5
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(LanguageProvider lp) {
    if (_selectedIndex == 0) return _buildShiftTab(lp);
    if (_selectedIndex == 1) return _buildZReportTab(lp);
    if (_selectedIndex == 2) return _buildTableReportTab(lp);
    if (_selectedIndex == 3) return _buildProductReportTab(lp);
    if (_selectedIndex == 4) return const SalesGraphTab();
    return _buildAdminClosingContent(lp);
  }

  Widget _buildAdminClosingContent(LanguageProvider lp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_clock, size: 80, color: MetroColors.error),
          const SizedBox(height: 24),
          const Text("CLOSING HARIAN", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          const Text("PROSES PENUTUPAN HARI DAN PENGUNCIAN TRANSAKSI", textAlign: TextAlign.center, style: TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12)
            ),
            child: const Column(
              children: [
                Text("PENTING:", style: TextStyle(fontWeight: FontWeight.w900, color: MetroColors.error)),
                SizedBox(height: 12),
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
          const SizedBox(height: 48),
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

  Widget _buildShiftTab(LanguageProvider lp) {
    if (_shiftData == null && !_isLoading) {
      return Center(child: Text(lp.translate('connecting_to_server'), style: const TextStyle(color: Colors.black38, fontWeight: FontWeight.bold)));
    }
    
    if (_shiftData == null) return const SizedBox.shrink();

    final d = _shiftData!;
    final sales = d['sales'];
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
         Container(
           color: MetroColors.surface,
           padding: const EdgeInsets.all(24),
           child: Column(children: [
             Text('USER: ${d['kasir_name'].toString().toUpperCase()}', style: const TextStyle(color: MetroColors.primary, fontSize: 14.4, fontWeight: FontWeight.w900, letterSpacing: 1)),
             const SizedBox(height: 8),
             Text('${d['tanggal'].toString().toUpperCase()} | ${d['jam_login']} - AKTIF', style: const TextStyle(color: Colors.black54, fontSize: 9.9, fontWeight: FontWeight.bold)),
             const SizedBox(height: 24),
             const Divider(color: Colors.black12, height: 1),
             const SizedBox(height: 16),
             _row(lp.translate('total_transactions'), '${d['total_transactions']}'),
             _row(lp.translate('total_items'), '${d['total_items']}'),
             const SizedBox(height: 16),
             const Divider(color: Colors.black12, height: 1),
             const SizedBox(height: 16),
             _row(lp.translate('omzet_gross'), currency.format(sales['omzet_kotor'])),
             _row(lp.translate('discount'), currency.format(sales['total_diskon'])),
             _row(lp.translate('tax'), currency.format(sales['pajak'])),
             const SizedBox(height: 16),
             const Divider(color: Colors.black12, height: 1),
             const SizedBox(height: 16),
             _row(lp.translate('total_net'), currency.format(sales['total_bersih']), isBold: true, color: MetroColors.accent),
           ]),
         ),
         const SizedBox(height: 24),
         MetroButton(
           label: lp.translate('print_shift_report'), 
           onPressed: _printShiftReport,
           color: MetroColors.primary,
           icon: Icons.print,
         ),
         const SizedBox(height: 80),
      ]),
    );
  }



  Widget _buildTableReportTab(LanguageProvider lp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context, 
              initialDate: _tableReportDate, 
              firstDate: DateTime(2020), 
              lastDate: DateTime.now(),
              builder: (c, child) => Theme(
                data: ThemeData.dark().copyWith(
                   colorScheme: const ColorScheme.dark(primary: MetroColors.primary, onPrimary: Colors.white, surface: MetroColors.textDark),
                   dialogBackgroundColor: MetroColors.textDark,
                ),
                child: child!,
              )
            );
            if (picked != null) {
              setState(() => _tableReportDate = picked);
              _fetchTableReport();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            color: MetroColors.surface,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Text('${lp.translate('select_date')}:', style: const TextStyle(color: Colors.black38, fontSize: 9.9, fontWeight: FontWeight.bold)),
               Text(DateFormat('dd MMMM yyyy').format(_tableReportDate).toUpperCase(), style: const TextStyle(color: MetroColors.text, fontWeight: FontWeight.w900, fontSize: 11.7)),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        
        if (_tableReportData != null && _tableReportData!.isNotEmpty) ...[
         Container(
           color: MetroColors.surface,
           padding: const EdgeInsets.all(24),
           child: Column(children: [
             const Text("LAPORAN PENJUALAN PER MEJA", style: TextStyle(color: MetroColors.primary, fontSize: 14.4, fontWeight: FontWeight.w900, letterSpacing: 1)),
             const SizedBox(height: 24),
             const Divider(color: Colors.black12, height: 1),
             const SizedBox(height: 16),
             
             // Header
             Row(
                children: [
                    Expanded(flex: 3, child: Text('MEJA', style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('PAX', textAlign: TextAlign.center, style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('TX', textAlign: TextAlign.center, style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold))),
                    Expanded(flex: 3, child: Text('OMZET', textAlign: TextAlign.right, style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold))),
                ],
             ),
             const SizedBox(height: 12),
             
             ..._tableReportData!.map((d) {
                 final tableName = d['table_name'] ?? 'Meja #${d['res_table_id']}';
                 final pax = d['total_pax'] ?? 0;
                 final tx = d['total_transactions'] ?? 0;
                 final revenue = d['total_revenue'] ?? 0;
                 return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                        children: [
                            Expanded(flex: 3, child: Text(tableName, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 11))),
                            Expanded(flex: 2, child: Text('$pax', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 11))),
                            Expanded(flex: 2, child: Text('$tx', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 11))),
                            Expanded(flex: 3, child: Text(NumberFormat('#,###').format(revenue), textAlign: TextAlign.right, style: const TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 11))),
                        ],
                    ),
                 );
             }).toList(),

             const SizedBox(height: 16),
             const Divider(color: Colors.black12, height: 1),
             const SizedBox(height: 12),
             _row(
                 "TOTAL KESELURUHAN", 
                 NumberFormat('#,###').format(_tableReportData!.fold(0.0, (sum, item) => sum + (item['total_revenue'] as num).toDouble())),
                 isBold: true,
                 color: MetroColors.accent
             ),
             _row(
                 "TOTAL TAMU (PAX)", 
                 "${_tableReportData!.fold(0, (sum, item) => sum + (item['total_pax'] as int))}",
                 isBold: true,
                 color: Colors.black87
             ),
           ]),
         ),
        ] else 
           Padding(padding: const EdgeInsets.only(top: 50), child: Center(child: Text(lp.translate('no_data_for_date'), style: const TextStyle(color: Colors.black26, fontWeight: FontWeight.bold, fontSize: 10.8)))),
         const SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildProductReportTab(LanguageProvider lp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(
            children: [
                Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context, 
                          initialDate: _productStartDate, 
                          firstDate: DateTime(2020), 
                          lastDate: DateTime.now(),
                          builder: (c, child) => Theme(
                            data: ThemeData.dark().copyWith(
                               colorScheme: const ColorScheme.dark(primary: MetroColors.primary, onPrimary: Colors.white, surface: MetroColors.textDark),
                               dialogBackgroundColor: MetroColors.textDark,
                            ),
                            child: child!,
                          )
                        );
                        if (picked != null) {
                          setState(() {
                              _productStartDate = picked;
                              if(_productEndDate.isBefore(_productStartDate)) _productEndDate = picked;
                          });
                          _fetchProductReport();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: MetroColors.surface,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                           const Text('DARI TANGGAL:', style: TextStyle(color: Colors.black38, fontSize: 8, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 4),
                           Text(DateFormat('dd MMM yyyy').format(_productStartDate).toUpperCase(), style: const TextStyle(color: MetroColors.text, fontWeight: FontWeight.w900, fontSize: 11)),
                        ]),
                      ),
                    ),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context, 
                          initialDate: _productEndDate, 
                          firstDate: _productStartDate, // Can't be before start date
                          lastDate: DateTime.now(),
                          builder: (c, child) => Theme(
                            data: ThemeData.dark().copyWith(
                               colorScheme: const ColorScheme.dark(primary: MetroColors.primary, onPrimary: Colors.white, surface: MetroColors.textDark),
                               dialogBackgroundColor: MetroColors.textDark,
                            ),
                            child: child!,
                          )
                        );
                        if (picked != null) {
                          setState(() => _productEndDate = picked);
                          _fetchProductReport();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: MetroColors.surface,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                           const Text('SAMPAI TANGGAL:', style: TextStyle(color: Colors.black38, fontSize: 8, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 4),
                           Text(DateFormat('dd MMM yyyy').format(_productEndDate).toUpperCase(), style: const TextStyle(color: MetroColors.text, fontWeight: FontWeight.w900, fontSize: 11)),
                        ]),
                      ),
                    ),
                ),
            ],
        ),
        const SizedBox(height: 24),

        if (_productReportData != null && _productReportData!.isNotEmpty) ...[
         Container(
           color: MetroColors.surface,
           padding: const EdgeInsets.all(24),
           child: Column(children: [
             const Text("TOP TEN HARI INI", style: TextStyle(color: MetroColors.primary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
             const SizedBox(height: 12),
             
             // BUSINESS INFO HEADER
             Container(
               padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
               decoration: BoxDecoration(
                 border: Border.all(color: Colors.black12),
                 color: Colors.white.withOpacity(0.5)
               ),
               child: Column(
                 children: [
                   _row('BISNIS', _businessName?.toUpperCase() ?? '-'),
                   _row('LOKASI', _locationName?.toUpperCase() ?? '-'),
                   _row('KASIR', _cashierName?.toUpperCase() ?? '-'),
                   _row('PERIODE', '${DateFormat('dd/MM/yy').format(_productStartDate)} - ${DateFormat('dd/MM/yy').format(_productEndDate)}'),
                 ],
               ),
             ),
             
             const SizedBox(height: 24),
             const Divider(color: Colors.black12, height: 1),
             const SizedBox(height: 16),
             
             // Header
             Row(
                children: [
                    const Expanded(flex: 1, child: Text('NO', style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold))),
                    const Expanded(flex: 7, child: Text('PRODUK', style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold))),
                    const Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold))),
                ],
             ),
             const SizedBox(height: 12),
             
             ..._productReportData!.asMap().entries.map((entry) {
                 int idx = entry.key + 1;
                 Map<String, dynamic> d = entry.value;
                 final productName = d['product_name'] ?? 'Item #${d['product_id']}';
                 final qty = d['total_qty'] ?? 0;
                 return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                        children: [
                            Expanded(flex: 1, child: Text('$idx', style: const TextStyle(color: Colors.black38, fontWeight: FontWeight.bold, fontSize: 11))),
                            Expanded(flex: 7, child: Text(productName, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11))),
                            Expanded(flex: 2, child: Text('${NumberFormat('#,###').format(qty)}', textAlign: TextAlign.right, style: const TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 11))),
                        ],
                    ),
                 );
             }).toList().take(10).toList(),

             const SizedBox(height: 24),
             const Divider(color: Colors.black12, height: 1),
             const SizedBox(height: 12),
             _row(
                 "TOTAL REVENUE", 
                 NumberFormat('Rp #,###').format(_productReportData!.fold(0.0, (sum, item) => sum + (item['total_revenue'] as num).toDouble())),
                 isBold: true,
                 color: MetroColors.retailPrimary
             ),
           ]),
         ),
         const SizedBox(height: 24),
         MetroButton(
           label: "CETAK LAPORAN TOP 10", 
           onPressed: _printTopTenReport,
           color: MetroColors.primary,
           icon: Icons.print,
         ),
         const SizedBox(height: 80),
        ] else 
            Padding(padding: const EdgeInsets.only(top: 50), child: Center(child: Text(lp.translate('no_data_for_date'), style: const TextStyle(color: Colors.black26, fontWeight: FontWeight.bold, fontSize: 10.8)))),
         const SizedBox(height: 48),
      ]),
    );
  }

  Widget _row(String label, String val, {bool isBold = false, Color color = Colors.black45}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 9.9, fontWeight: FontWeight.bold)),
        Text(val, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, fontSize: isBold ? 14.4 : 11.7)),
      ]),
    );
  }
}
