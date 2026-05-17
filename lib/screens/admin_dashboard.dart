import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_pkg;
import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:donapos_mobile/widgets/confirm_dialog.dart';
import 'package:donapos_mobile/widgets/product_manager_dialog.dart';
import 'package:donapos_mobile/screens/admin/invoice_settings_dialog.dart';
import 'package:donapos_mobile/widgets/customer_manager_dialog.dart';
import 'package:donapos_mobile/utils_backup.dart';
import 'package:donapos_mobile/widgets/printer_settings_dialog.dart';
import 'package:donapos_mobile/screens/admin/local_data_check_dialog.dart';
import 'package:provider/provider.dart';
import 'package:donapos_mobile/language_provider.dart';
import 'package:donapos_mobile/widgets/kitchen_printer_dialog.dart';
import 'package:donapos_mobile/screens/admin/customer_display_settings_screen.dart';
import 'package:donapos_mobile/screens/admin/sd_card_backup_screen.dart';
import 'package:donapos_mobile/widgets/waiter_management_dialog.dart';
import 'package:donapos_mobile/widgets/product_label_settings_dialog.dart';
import 'package:donapos_mobile/screens/admin/qr_settings_dialog.dart';
import 'package:donapos_mobile/widgets/sync_progress_dialog.dart';
import 'package:donapos_mobile/widgets/sync_center_dialog.dart';
import 'package:donapos_mobile/sync_helper.dart';
import 'package:donapos_mobile/screens/login_screen.dart';
import 'package:donapos_mobile/utils_storage.dart';
import 'package:donapos_mobile/widgets/database_migration_dialog.dart';
import 'package:donapos_mobile/sync_service.dart';
import 'package:donapos_mobile/widgets/demo_restriction_dialog.dart';
import 'package:donapos_mobile/models/admin_sync_preset.dart';
import 'package:donapos_mobile/services/admin_sync_runner.dart';

class AdminDashboard extends StatefulWidget {
  final String username;
  const AdminDashboard({super.key, required this.username});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _apiService = ApiService();
  
  // Navigation State
  int _selectedIndex = 0;

  bool _isLoading = false;
  bool _isDemoMode = false;

  List<Map<String, dynamic>> _priceGroups = [];
  int? _selectedPriceGroupId;
  String _defaultSaleType = 'dinein';
  bool _roundingEnabled = false;
  int _roundingIncrement = 100;
  bool _taxEnabled = true;
  bool _duplicatePrintEnabled = true;
  bool _animProductEnabled = false;
  bool _animMenuEnabled = false;
  bool _soundEnabled = false;
  bool _secondScreenEnabled = false;
  bool _autoBackupEnabled = false;
  bool _calculatorEnabled = false;
  bool _toppingEditingEnabled = false;
  bool _autoPrintReceipt = true;
  bool _autoPostingEnabled = true;
  int _autoPostingInterval = 10;
  bool _showBillButton = false;
  bool _showKitchenButton = true;
  bool _showDiscountButton = false;
  bool _attendanceRequired = true;

  bool _showReportAppVersion = true;
  bool _printHoldReceiptEnabled = false;
  bool _allowEmergencyProduct = false;
  bool _syncAdminEnabled = false;
  bool _askCustomerNameEnabled = false;
  bool _autoPayAfterKot = true;
  bool _splitPaymentEnabled = false;

  String _businessName = '';
  String _locationName = '';
  int _productCount = 0;
  int _staffCount = 0;
  bool _isPostingSync = false;
  String _postingStatus = '';

  List<Map<String, dynamic>> _paymentMethods = [];
  final Map<String, TextEditingController> _pmControllers = {};
  final Map<String, String?> _pmImages = {};
  final List<TextEditingController> _qcControllers = [];
  final _printerFilterCashierController = TextEditingController();
  final _printerFilterLabelController = TextEditingController();

  final List<String> _availableImages = [
      'assets/images/payments/bca.png',
      'assets/images/payments/bri.png',
      'assets/images/payments/mandiri.png',
      'assets/images/payments/qris.png',
      'assets/images/payments/dana.png',
      'assets/images/payments/gopay.png',
      'assets/images/payments/ovo.png',
      'assets/images/payments/shopeepay.png',
      'assets/images/payments/linkaja.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadPriceGroups();
    _loadPaymentMethods();
    _loadHomeStats();

    // Check storage on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
        StorageUtils.checkStorageAndWarn(context);
    });
  }

  @override
  void dispose() {
    _printerFilterCashierController.dispose();
    _printerFilterLabelController.dispose();
    for (var c in _pmControllers.values) {
      c.dispose();
    }
    for (var c in _qcControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _logout() async {
    bool confirm = await showAppConfirm(
      context,
      title: 'KELUAR ADMIN?',
      message: 'ANDA AKAN KEMBALI KE LAYAR LOGIN UTAMA.',
      confirmLabel: 'KELUAR',
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_user_id');
      await prefs.remove('last_user_name');
      
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen(showAdminLogin: true)),
        (route) => false,
      );
    }
  }

  void _enterPos() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('MASUK MENU KASIR?', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        content: const Text(
          'JIKA ANDA MASUK DENGAN PIN KASIR, MAKA NAMA ADMIN AKAN TERCATAT KE SERVER SEBAGAI USER/KASIR UNTUK TRANSAKSI TERSEBUT.\n\nLANJUTKAN KE LAYAR PILIH STAF?',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('last_user_id');
              await prefs.remove('last_user_name');
              
              if (!mounted) return;
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen(showAdminLogin: false)),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: MetroColors.secondary),
            child: const Text('YA, LANJUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadConfig() async {
    final saleType = await _apiService.getDefaultSaleType();
    final pgConfig = await _apiService.getPriceGroupConfig();
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _defaultSaleType = saleType;
      _selectedPriceGroupId = prefs.getInt('selected_price_group_id');
      _isDemoMode = prefs.getBool('is_demo_mode') ?? false;
      _roundingEnabled = prefs.getBool('rounding_enabled') ?? false;
      _roundingIncrement = prefs.getInt('rounding_increment') ?? 100;
      _taxEnabled = prefs.getBool('tax_enabled') ?? false;
      _duplicatePrintEnabled = prefs.getBool('duplicate_print_enabled') ?? false;
      _animProductEnabled = prefs.getBool('anim_product_enabled') ?? false;
      _animMenuEnabled = prefs.getBool('anim_menu_enabled') ?? false;
      _soundEnabled = prefs.getBool('sound_enabled') ?? false;
      _secondScreenEnabled = prefs.getBool('second_screen_enabled') ?? false;
      _autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? false;
      _autoPrintReceipt = prefs.getBool('auto_print_receipt') ?? false; // Default OFF
      _autoPostingEnabled = prefs.getBool('auto_posting_enabled') ?? true; // Default ON
      _autoPostingInterval = prefs.getInt('auto_posting_interval') ?? 10;
      _showBillButton = prefs.getBool('show_bill_button') ?? false;
      _showKitchenButton = prefs.getBool('show_kitchen_button') ?? true; // Default ON
      _showDiscountButton = prefs.getBool('show_discount_button') ?? false;
      _attendanceRequired = prefs.getBool('attendance_required') ?? true; // Default ON
      _calculatorEnabled = prefs.getBool('show_calculator') ?? false; // Default OFF
      _toppingEditingEnabled = prefs.getBool('topping_editing_enabled') ?? false;
      _showReportAppVersion = prefs.getBool('show_report_app_version') ?? true;
      _printHoldReceiptEnabled = prefs.getBool('print_hold_receipt_enabled') ?? false;
      _allowEmergencyProduct = prefs.getBool('allow_emergency_product') ?? false;
      _syncAdminEnabled = prefs.getBool('sync_admin_enabled') ?? false;
      _askCustomerNameEnabled = prefs.getBool('ask_customer_name_enabled') ?? false;
      _autoPayAfterKot = prefs.getBool('auto_pay_after_kot') ?? true;
      _splitPaymentEnabled = prefs.getBool('split_payment_enabled') ?? false;
    
    // Load Quick Cash
      List<String> qc = prefs.getStringList('quick_cash_denominations') ?? ['20000', '50000', '100000'];
      _qcControllers.clear();
      for (var val in qc) {
          _qcControllers.add(TextEditingController(text: val));
      }
      _printerFilterCashierController.text = prefs.getString('printer_filter_cashier_name') ?? 'RPP02N';
      _printerFilterLabelController.text = prefs.getString('printer_filter_label_name') ?? '';
    });
  }

  Future<void> _loadPaymentMethods() async {
    final db = await DatabaseHelper.instance.database;
    final list = await db.query('payment_methods', orderBy: 'id ASC');
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _paymentMethods = list;
      for (var pm in _paymentMethods) {
        String name = pm['name'];
        String savedLabel = prefs.getString('pm_label_$name') ?? pm['label'].toString();
        _pmControllers[name] = TextEditingController(text: savedLabel);
        _pmImages[name] = prefs.getString('pm_image_$name');
      }
    });
  }

  Future<void> _savePaymentMethodImage(String name, String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove('pm_image_$name');
    } else {
      await prefs.setString('pm_image_$name', path);
    }
  }

  Future<void> _savePaymentMethodLabel(String name, String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pm_label_$name', label);
  }

  Future<void> _saveQuickCash() async {
      final prefs = await SharedPreferences.getInstance();
      List<String> vals = _qcControllers.map((e) => e.text.replaceAll(RegExp(r'[^0-9]'), '')).where((s) => s.isNotEmpty).toList();
      await prefs.setStringList('quick_cash_denominations', vals);
  }

  Future<void> _loadPriceGroups() async {
    final groups = await DatabaseHelper.instance.getAllPriceGroups();
    setState(() {
      _priceGroups = groups;
    });
  }

  Future<void> _loadHomeStats() async {
    final bn = await _apiService.getBusinessName();
    final ln = await _apiService.getLocationName();
    final db = await DatabaseHelper.instance.database;
    final products = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM products'),
        ) ??
        0;
    final staff = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users'),
        ) ??
        0;
    if (mounted) {
      setState(() {
        _businessName = bn;
        _locationName = ln;
        _productCount = products;
        _staffCount = staff;
      });
    }
  }

  Future<void> _runPostingPreset({bool fromHome = false}) async {
    if (_isDemoMode) {
      showDemoRestrictionDialog(context);
      return;
    }
    if (_isPostingSync) return;

    setState(() {
      _isPostingSync = true;
      _postingStatus = 'Mengirim data ke server...';
    });

    final result = await runAdminSyncPreset(
      api: _apiService,
      presetIds: AdminSyncPreset.postingIds,
      onStep: (current, total, label) {
        if (mounted) {
          setState(() => _postingStatus = 'Langkah $current/$total: $label');
        }
      },
    );

    if (!mounted) return;
    setState(() {
      _isPostingSync = false;
      _postingStatus = result.success
          ? 'Data berhasil dikirim ke server.'
          : (result.errorMessage ?? 'Gagal mengirim data.');
    });

    showAppModal(
      context,
      title: result.success ? 'BERHASIL' : 'GAGAL',
      message: _postingStatus,
      isError: !result.success,
    );
  }

  Future<void> _syncGroups() async {
    if (_isDemoMode) {
      showDemoRestrictionDialog(context);
      return;
    }
    setState(() => _isLoading = true);
    await _apiService.syncPriceGroups();
    await _loadPriceGroups();
    setState(() => _isLoading = false);
    showAppModal(context, title: 'SINKRONISASI', message: 'DAFTAR GRUP HARGA BERHASIL DIPERBARUI!');
  }
  
  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_sale_type', _defaultSaleType);
    await prefs.setBool('rounding_enabled', _roundingEnabled);
    await prefs.setInt('rounding_increment', _roundingIncrement);
    await prefs.setBool('tax_enabled', _taxEnabled);
    await prefs.setBool('duplicate_print_enabled', _duplicatePrintEnabled);
    await prefs.setBool('anim_product_enabled', _animProductEnabled);
    await prefs.setBool('anim_menu_enabled', _animMenuEnabled);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setBool('second_screen_enabled', _secondScreenEnabled);
    await prefs.setBool('auto_backup_enabled', _autoBackupEnabled);
    await prefs.setBool('auto_print_receipt', _autoPrintReceipt);
    await prefs.setBool('show_calculator', _calculatorEnabled);
    await prefs.setBool('topping_editing_enabled', _toppingEditingEnabled);
    await prefs.setBool('show_report_app_version', _showReportAppVersion);
    await prefs.setBool('print_hold_receipt_enabled', _printHoldReceiptEnabled);
    await prefs.setBool('allow_emergency_product', _allowEmergencyProduct);
    await prefs.setBool('sync_admin_enabled', _syncAdminEnabled);
    await prefs.setBool('ask_customer_name_enabled', _askCustomerNameEnabled);
    await prefs.setBool('auto_pay_after_kot', _autoPayAfterKot);
    await prefs.setBool('split_payment_enabled', _splitPaymentEnabled);
    await prefs.setBool('auto_posting_enabled', _autoPostingEnabled);
    await prefs.setInt('auto_posting_interval', _autoPostingInterval);
    await prefs.setBool('show_bill_button', _showBillButton);
    await prefs.setBool('show_kitchen_button', _showKitchenButton);
    await prefs.setBool('show_discount_button', _showDiscountButton);
    await prefs.setBool('attendance_required', _attendanceRequired);
    
    // Notify SyncService to reload config
    SyncService().restartSync();
    if (_selectedPriceGroupId != null) {
        await prefs.setInt('selected_price_group_id', _selectedPriceGroupId!);
    } else {
        await prefs.remove('selected_price_group_id');
    }
    if (!mounted) return;
    showAppModal(context, title: 'SUKSES', message: 'KONFIGURASI HARGA TELAH DISIMPAN.');
  }

  void _runSyncTask(String title, Future<dynamic> Function({Function(String)? onProgress}) task) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Check connection first
      final isOnline = await _apiService.checkConnection();
      if (!isOnline) {
        if (mounted) {
          showAppModal(
            context, 
            title: 'OFFLINE', 
            message: 'TIDAK DAPAT MELAKUKAN SINKRONISASI DALAM MODE OFFLINE. PERIKSA KONEKSI INTERNET ANDA.',
            isError: true
          );
        }
        return;
      }

      await SyncHelper.runSyncTask(context, title, task);
    } catch (e) {
      debugPrint("Sync task error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetSales() async {
    bool confirm = await showAppConfirm(
      context,
      title: 'RESET PENJUALAN?',
      message: 'DATA LOKAL DI TABLET INI AKAN DIHAPUS PERMANEN. DATA DI CLOUD TETAP AMAN DAN DAPAT DI-DOWNLOAD KEMBALI.',
      confirmLabel: 'HAPUS',
    );
    if (confirm == true) {
      await DatabaseHelper.instance.resetSales();
      
      // Reset Default Settings as requested
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rounding_enabled', false);
      await prefs.setBool('tax_enabled', false);
      await prefs.setBool('duplicate_print_enabled', false);
      await prefs.setBool('allow_emergency_product', false);
      await prefs.setBool('print_hold_receipt_enabled', false);
      await prefs.setBool('auto_backup_enabled', false);

      await prefs.setBool('anim_product_enabled', false);
      await prefs.setBool('anim_menu_enabled', false);
      await prefs.remove('anim_payment_enabled');
      await prefs.setBool('topping_editing_enabled', false);
      await prefs.setBool('sound_enabled', false);
      await prefs.setBool('show_calculator', true);
      await prefs.setBool('show_report_app_version', true);
      await prefs.setBool('ask_customer_name_enabled', true);
      
      // Enforce Defaults
      await prefs.setBool('attendance_required', true);
      await prefs.setBool('auto_posting_enabled', true);
      await prefs.setBool('auto_print_receipt', false);
      await prefs.setBool('show_kitchen_button', false);
      await prefs.setBool('auto_pay_after_kot', true);
      
      await prefs.setInt('printer_font_type', 1);
      
      // Reset Session
      await prefs.remove('initial_cash');
      await prefs.remove('last_user_id');
      await prefs.remove('last_user_name');
      await prefs.setBool('is_cashier_open', false);
      
      await _loadConfig();

      if (mounted) {
          showAppModal(context, title: 'RESET BERHASIL', message: 'DATA PENJUALAN & PENGATURAN TELAH DIKOSONGKAN.');
      }
    }
  }

  Future<void> _clearProducts() async {
    bool confirm = await showAppConfirm(
      context,
      title: 'HAPUS SEMUA PRODUK?',
      message: 'SEMUA PRODUK (TERMASUK PRODUK TAMBAHAN/LOKAL) AKAN DIHAPUS DARI TABLET INI.',
      confirmLabel: 'HAPUS PRODUK',
    );
    if (confirm == true) {
      setState(() => _isLoading = true);
      await DatabaseHelper.instance.clearProducts();
      setState(() => _isLoading = false);
      if (mounted) {
          showAppModal(context, title: 'BERHASIL', message: 'DAFTAR PRODUK TELAH DIKOSONGKAN.');
      }
    }
  }

  Future<void> _clearProductImages() async {
    bool confirm = await showAppConfirm(
      context,
      title: 'HAPUS SEMUA GAMBAR?',
      message: 'SEMUA FILE GAMBAR PRODUK AKAN DIHAPUS DARI PENYIMPANAN TABLET.',
      confirmLabel: 'HAPUS GAMBAR',
    );
    if (confirm == true) {
      setState(() => _isLoading = true);
      await DatabaseHelper.instance.clearProductImages();
      setState(() => _isLoading = false);
      if (mounted) {
          showAppModal(context, title: 'BERHASIL', message: 'SEMUA GAMBAR PRODUK TELAH DIHAPUS.');
      }
    }
  }

  Future<void> _manualMigration() async {
      final dbHelper = DatabaseHelper.instance;
      int oldV = await dbHelper.getLocalVersion();
      int newV = DatabaseHelper.schemaVersion;
      
      if (!mounted) return;
      
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => DatabaseMigrationDialog(oldVersion: oldV, newVersion: newV)
      );
  }

  @override
  Widget build(BuildContext context) {
    const menuItems = ['Beranda', 'Unduh data', 'Pengaturan', 'Lanjutan'];
    const menuIcons = [
      Icons.home_rounded,
      Icons.cloud_download_rounded,
      Icons.tune_rounded,
      Icons.more_horiz_rounded,
    ];
    // Beranda, Unduh data, Pengaturan: Expanded + GridView (hindari GridView di ScrollView tanpa shrinkWrap)
    final useFixedHeight = _selectedIndex <= 2;

    return Scaffold(
      backgroundColor: MetroColors.background,
      body: Row(
        children: [
          Container(
            width: 160,
            color: MetroColors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: MetroColors.primary,
                  width: double.infinity,
                  child: Column(
                    children: [
                      const Icon(Icons.admin_panel_settings, color: Colors.white, size: 36),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ADMIN',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              fontSize: 13,
                            ),
                          ),
                          if (_isDemoMode)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'DEMO',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        widget.username.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedIndex == index;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        tileColor: isSelected ? MetroColors.background : null,
                        leading: Icon(
                          menuIcons[index],
                          color: isSelected ? MetroColors.primary : Colors.black45,
                          size: 20,
                        ),
                        title: Text(
                          menuItems[index],
                          style: TextStyle(
                            color: isSelected ? MetroColors.primary : Colors.black54,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => setState(() => _selectedIndex = index),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      MetroButton(
                        label: 'Buka kasir',
                        icon: Icons.shopping_cart,
                        onPressed: _enterPos,
                        color: MetroColors.secondary,
                        isLarge: false,
                      ),
                      const SizedBox(height: 8),
                      MetroButton(
                        label: 'Keluar',
                        icon: Icons.logout,
                        onPressed: _logout,
                        color: MetroColors.error,
                        isSecondary: true,
                        isLarge: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.black12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    menuItems[_selectedIndex],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: MetroColors.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: useFixedHeight
                        ? _buildContent()
                        : SingleChildScrollView(child: _buildContent()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final lp = Provider.of<LanguageProvider>(context);
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildDownloadTab();
      case 2:
        return _buildSettingsTab(lp);
      case 3:
        return _buildAdvancedTab(lp);
      default:
        return const SizedBox();
    }
  }

  Widget _buildHomeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_businessName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '$_businessName · $_locationName · $_productCount produk · $_staffCount staf',
              style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
            ),
          ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _homeActionCard(
                title: 'Unduh data bisnis',
                subtitle: 'Produk, kasir, meja',
                icon: Icons.cloud_download_rounded,
                color: MetroColors.primary,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _homeActionCard(
                title: 'Kirim ke server',
                subtitle: 'Penjualan & biaya',
                icon: Icons.cloud_upload_rounded,
                color: MetroColors.secondary,
                onTap: _isPostingSync ? null : () => _runPostingPreset(fromHome: true),
              ),
              _homeActionCard(
                title: 'Atur printer',
                subtitle: 'Printer kasir',
                icon: Icons.print_rounded,
                color: Colors.blueAccent,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const PrinterSettingsDialog(),
                ),
              ),
              _homeActionCard(
                title: 'Buka kasir',
                subtitle: 'Mulai transaksi',
                icon: Icons.point_of_sale_rounded,
                color: Colors.teal,
                onTap: _enterPos,
              ),
            ],
          ),
        ),
        if (_postingStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _postingStatus,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _isPostingSync ? MetroColors.primary : Colors.black54,
              ),
            ),
          ),
        if (_isDemoMode)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Mode demo — beberapa aksi berbahaya dibatasi.',
              style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _homeActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadTab() {
    return MetroPanel(
      padding: EdgeInsets.zero,
      showBorder: true,
      child: SyncCenterDialog(
        isContentOnly: true,
        isLoading: false,
        username: widget.username,
        apiService: _apiService,
        uiMode: AdminSyncUiMode.simple,
        initialPresetIds: AdminSyncPreset.downloadIds,
        onSyncTask: (title, task) {},
        onSyncComplete: () {
          if (mounted) {
            _loadPriceGroups();
            _loadPaymentMethods();
            _loadHomeStats();
          }
        },
      ),
    );
  }

  Widget _buildSettingsTab(LanguageProvider lp) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cols = constraints.maxWidth > 500 ? 2 : 1;
        return GridView.count(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: cols == 2 ? 1.55 : 2.2,
          children: [
            MetroTile(
              label: 'Printer kasir',
              icon: Icons.print,
              color: Colors.blueAccent,
              onTap: () => showDialog(context: context, builder: (_) => const PrinterSettingsDialog()),
            ),
            MetroTile(
              label: 'Printer dapur',
              icon: Icons.restaurant,
              color: Colors.deepOrangeAccent,
              onTap: () => showDialog(context: context, builder: (_) => const KitchenPrinterDialog()),
            ),
            MetroTile(
              label: 'Kelola menu',
              icon: Icons.price_change,
              color: Colors.orange,
              onTap: () => showDialog(context: context, builder: (_) => const ProductManagerDialog()),
            ),
            MetroTile(
              label: 'Layar pelanggan',
              icon: Icons.monitor,
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerDisplaySettingsScreen()),
              ),
            ),
            MetroTile(
              label: 'Invoice & struk',
              icon: Icons.receipt,
              color: Colors.teal,
              onTap: () => showDialog(context: context, builder: (_) => const InvoiceSettingsDialog()),
            ),
            MetroTile(
              label: 'Label produk',
              icon: Icons.label,
              color: Colors.blueGrey,
              onTap: () => showDialog(context: context, builder: (_) => const ProductLabelSettingsDialog()),
            ),
            MetroTile(
              label: 'Manajemen waiter',
              icon: Icons.badge,
              color: Colors.cyan,
              onTap: () => showDialog(context: context, builder: (_) => const WaiterManagementDialog()),
            ),
            MetroTile(
              label: 'QR login kasir',
              icon: Icons.qr_code_2,
              color: Colors.indigo,
              onTap: () => showDialog(context: context, builder: (_) => const QrSettingsDialog()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPmImage(String p, {double size = 20}) {
      if (p.startsWith('assets/')) return Image.asset(p, fit: BoxFit.contain, height: size);
      return Image.file(File(p), fit: BoxFit.contain, height: size);
  }

  void _showIconPicker(String pmName) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('PUSTAKA ICON', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))
                ],
              ),
              content: SizedBox(
                  width: double.maxFinite,
                  child: GridView.builder(
                      shrinkWrap: true,
                      itemCount: _availableImages.length + 2,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
                      itemBuilder: (context, i) {
                          if (i == 0) {
                              // REMOVE BUTTON
                              return InkWell(
                                  onTap: () {
                                      setState(() => _pmImages[pmName] = null);
                                      _savePaymentMethodImage(pmName, null);
                                      Navigator.pop(ctx);
                                  },
                                  child: Container(
                                      decoration: BoxDecoration(color: MetroColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: MetroColors.error.withOpacity(0.2))),
                                      child: const Icon(Icons.delete_outline, color: MetroColors.error),
                                  ),
                              );
                          }
                          if (i == 1) {
                              // ADD FROM STORAGE
                              return InkWell(
                                  onTap: () => _pickCustomImage(pmName, ctx),
                                  child: Container(
                                      decoration: BoxDecoration(color: MetroColors.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: MetroColors.secondary.withOpacity(0.2))),
                                      child: const Icon(Icons.add_a_photo, color: MetroColors.secondary),
                                  ),
                              );
                          }

                          final pathStr = _availableImages[i-2];
                          return InkWell(
                              onTap: () {
                                  setState(() => _pmImages[pmName] = pathStr);
                                  _savePaymentMethodImage(pmName, pathStr);
                                  Navigator.pop(ctx);
                              },
                              child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: Colors.black.withOpacity(0.05)),
                                      borderRadius: BorderRadius.circular(8)
                                  ),
                                  child: Image.asset(pathStr, fit: BoxFit.contain),
                              ),
                          );
                      },
                  ),
              ),
          )
      );
  }

  Future<void> _pickCustomImage(String pmName, BuildContext dialogCtx) async {
      try {
          final result = await FilePicker.platform.pickFiles(type: FileType.image);
          if (result != null && result.files.single.path != null) {
              final file = File(result.files.single.path!);
              final appDir = await getApplicationDocumentsDirectory();
              final fileName = 'pm_${pmName}_${DateTime.now().millisecondsSinceEpoch}${path_pkg.extension(file.path)}';
              final savedFile = await file.copy('${appDir.path}/$fileName');
              
              setState(() => _pmImages[pmName] = savedFile.path);
              _savePaymentMethodImage(pmName, savedFile.path);
              if (mounted) Navigator.pop(dialogCtx);
          }
      } catch (e) {
          print("Pick Image Error: $e");
      }
  }

  Widget _buildAdvancedTab(LanguageProvider lp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MetroSectionTitle(title: 'Kirim ke cloud'),
        SizedBox(
          height: 260,
          child: MetroPanel(
            padding: EdgeInsets.zero,
            showBorder: true,
            child: SyncCenterDialog(
              isContentOnly: true,
              isLoading: false,
              username: widget.username,
              apiService: _apiService,
              uiMode: AdminSyncUiMode.simple,
              initialPresetIds: AdminSyncPreset.postingIds,
              onSyncTask: (title, task) {},
              onSyncComplete: () {},
            ),
          ),
        ),
        const SizedBox(height: 24),
        const MetroSectionTitle(title: 'Data & backup'),
        Row(
          children: [
            Expanded(
              child: MetroTile(
                label: 'Cek data di tablet',
                subLabel: 'Lihat ringkasan data lokal',
                icon: Icons.manage_search,
                color: MetroColors.secondary,
                isHorizontal: true,
                onTap: () => showDialog(context: context, builder: (_) => const LocalDataCheckDialog()),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: MetroTile(
                label: 'Cek ruang penyimpanan',
                subLabel: 'Kapasitas memori tablet',
                icon: Icons.storage_rounded,
                color: Colors.blueAccent,
                isHorizontal: true,
                onTap: () => StorageUtils.showStorageInfo(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: MetroButton(
            label: 'Backup ke kartu SD',
            icon: Icons.sd_storage,
            color: Colors.blueGrey,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SdCardBackupScreen(allowRestore: true)),
            ),
            isSecondary: true,
          ),
        ),
        const SizedBox(height: 24),
        MetroSectionTitle(title: lp.translate('payment_methods')),
        _buildPaymentMethodsEditor(),
        const SizedBox(height: 24),
        _buildQuickCashSettings(),
        const SizedBox(height: 24),
        _buildPrinterFilterSettings(),
        const SizedBox(height: 24),
        const MetroSectionTitle(title: 'Pengaturan kasir'),
        MetroPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ExpansionTile(
                initiallyExpanded: true,
                title: const Text('Operasional', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                children: [
                  _buildSettingRow(
                    'Backup otomatis setelah transaksi',
                    'Simpan salinan ke kartu SD setiap selesai transaksi',
                    _autoBackupEnabled,
                    (v) { setState(() => _autoBackupEnabled = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Pembulatan otomatis',
                    'Bulatkan total transaksi ke ratusan terdekat',
                    _roundingEnabled,
                    (v) { setState(() => _roundingEnabled = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Hitung pajak',
                    'Aktifkan perhitungan pajak di kasir',
                    _taxEnabled,
                    (v) { setState(() => _taxEnabled = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Izinkan kasir sinkron data',
                    'Gunakan akun admin untuk unduh data dari kasir',
                    _syncAdminEnabled,
                    (v) async {
                      setState(() => _syncAdminEnabled = v);
                      final prefs = await SharedPreferences.getInstance();
                      if (v) {
                        await prefs.setString('sync_admin_user', widget.username);
                      } else {
                        await prefs.remove('sync_admin_user');
                        await prefs.remove('sync_admin_pass');
                      }
                      await prefs.setBool('sync_admin_enabled', v);
                      if (mounted) {
                        showAppModal(
                          context,
                          title: v ? 'Sinkron kasir aktif' : 'Sinkron kasir nonaktif',
                          message: v
                              ? 'Kredensial admin tersimpan untuk kasir.'
                              : 'Kasir tidak dapat mengunduh data.',
                        );
                      }
                    },
                  ),
                  _buildSettingRow(
                    'Wajib absen masuk',
                    'Blokir kasir jika belum clock-in',
                    _attendanceRequired,
                    (v) { setState(() => _attendanceRequired = v); _saveConfig(); },
                  ),
                  _buildAutoPostingRow(),
                ],
              ),
              const Divider(height: 1),
              ExpansionTile(
                initiallyExpanded: true,
                title: const Text('Tampilan kasir', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                children: [
                  _buildSettingRow(
                    'Cetak struk ganda',
                    'Tampilkan opsi cetak ulang struk',
                    _duplicatePrintEnabled,
                    (v) { setState(() => _duplicatePrintEnabled = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Cetak bukti saat hold',
                    'Tanya cetak saat transaksi ditahan',
                    _printHoldReceiptEnabled,
                    (v) { setState(() => _printHoldReceiptEnabled = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Cetak otomatis setelah bayar',
                    'Cetak struk langsung setelah pembayaran',
                    _autoPrintReceipt,
                    (v) { setState(() => _autoPrintReceipt = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Tanya nama pelanggan',
                    'Minta nama sebelum bayar (pelanggan umum)',
                    _askCustomerNameEnabled,
                    (v) { setState(() => _askCustomerNameEnabled = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Tombol cetak tagihan',
                    'Tampilkan tombol Bill di kasir',
                    _showBillButton,
                    (v) { setState(() => _showBillButton = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Tombol cetak dapur',
                    'Tampilkan tombol Dapur di kasir',
                    _showKitchenButton,
                    (v) { setState(() => _showKitchenButton = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Bayar setelah cetak dapur',
                    'Buka layar bayar otomatis setelah kirim dapur',
                    _autoPayAfterKot,
                    (v) { setState(() => _autoPayAfterKot = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Pembayaran terpisah',
                    'Izinkan split payment satu pesanan',
                    _splitPaymentEnabled,
                    (v) { setState(() => _splitPaymentEnabled = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Tombol diskon',
                    'Tampilkan diskon manual di kasir',
                    _showDiscountButton,
                    (v) { setState(() => _showDiscountButton = v); _saveConfig(); },
                  ),
                ],
              ),
              const Divider(height: 1),
              ExpansionTile(
                title: const Text('Animasi & suara', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                children: [
                  _buildSettingRow(
                    'Animasi daftar produk',
                    'Geser otomatis daftar produk',
                    _animProductEnabled,
                    (v) { setState(() => _animProductEnabled = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Animasi menu kasir',
                    'Geser otomatis menu header',
                    _animMenuEnabled,
                    (v) { setState(() => _animMenuEnabled = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Ubah harga topping',
                    'Kasir boleh ubah harga topping',
                    _toppingEditingEnabled,
                    (v) { setState(() => _toppingEditingEnabled = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Efek suara',
                    'Suara klik di aplikasi',
                    _soundEnabled,
                    (v) {
                      setState(() => _soundEnabled = v);
                      GlobalSettings.soundEnabled = v;
                      _saveConfig();
                    },
                  ),
                  _buildSettingRow(
                    'Kalkulator',
                    'Tombol kalkulator di kasir',
                    _calculatorEnabled,
                    (v) { setState(() => _calculatorEnabled = v); _saveConfig(); },
                  ),
                  _buildSettingRow(
                    'Versi di laporan',
                    'Tampilkan versi app di footer laporan',
                    _showReportAppVersion,
                    (v) { setState(() => _showReportAppVersion = v); _saveConfig(); },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        MetroTile(
          label: 'Perbaiki database (teknisi)',
          subLabel: 'Migrasi manual & log perbaikan',
          icon: Icons.terminal_rounded,
          color: Colors.blueGrey,
          isHorizontal: true,
          onTap: _manualMigration,
        ),
        const SizedBox(height: 24),
        const MetroSectionTitle(title: 'Zona bahaya'),
        Row(
          children: [
            Expanded(
              child: MetroButton(
                label: 'Hapus semua produk',
                icon: Icons.inventory_2,
                color: Colors.orange.shade800,
                onPressed: _clearProducts,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetroButton(
                label: 'Hapus foto produk',
                icon: Icons.image_not_supported,
                color: Colors.pink.shade800,
                onPressed: _clearProductImages,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: MetroButton(
            label: 'Reset database penjualan',
            icon: Icons.delete_forever,
            color: MetroColors.error,
            onPressed: _resetSales,
          ),
        ),
      ],
    );
  }

  Widget _buildAutoPostingRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kirim ke server otomatis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                Text('Kirim penjualan secara berkala', style: TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ),
          if (_autoPostingEnabled)
            GestureDetector(
              onTap: () async {
                final controller = TextEditingController(text: _autoPostingInterval.toString());
                await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Interval kirim data', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kirim data setiap berapa menit?'),
                        const SizedBox(height: 12),
                        TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(suffixText: 'menit', border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                      ElevatedButton(
                        onPressed: () {
                          final val = int.tryParse(controller.text);
                          if (val != null && val > 0) {
                            setState(() => _autoPostingInterval = val);
                            _saveConfig();
                            Navigator.pop(ctx);
                          }
                        },
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MetroColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$_autoPostingInterval menit',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: MetroColors.secondary),
                ),
              ),
            ),
          Switch(
            value: _autoPostingEnabled,
            activeColor: MetroColors.secondary,
            onChanged: (v) {
              setState(() => _autoPostingEnabled = v);
              _saveConfig();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsEditor() {
    return MetroPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Label & ikon metode bayar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('Sesuaikan tampilan di layar pembayaran', style: TextStyle(fontSize: 9, color: Colors.black38)),
                  ],
                ),
              ),
              _isLoading
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.sync, color: MetroColors.primary),
                      onPressed: () => _runSyncTask('Metode bayar', ({onProgress}) async {
                        await _apiService.syncPaymentMethods();
                        await _loadPaymentMethods();
                      }),
                    ),
            ],
          ),
          const SizedBox(height: 16),
          if (_paymentMethods.isEmpty)
            const Text('Belum ada data. Unduh data bisnis terlebih dahulu.', style: TextStyle(color: Colors.grey)),
          ..._paymentMethods.map((pm) {
            final name = pm['name'] as String;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _showIconPicker(name),
                    child: Container(
                      width: 50,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _pmImages[name] == null
                          ? const Icon(Icons.add_photo_alternate, color: Colors.black12, size: 20)
                          : Padding(
                              padding: const EdgeInsets.all(6),
                              child: _buildPmImage(_pmImages[name]!),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: MetroColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 35,
                      child: TextField(
                        controller: _pmControllers[name],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        style: const TextStyle(fontSize: 11),
                        onChanged: (v) => _savePaymentMethodLabel(name, v),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickCashSettings() {
      return MetroPanel(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  const Text('Tombol uang cepat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const Text('Nominal pintasan di layar pembayaran', style: TextStyle(fontSize: 9, color: Colors.black38)),
                  const SizedBox(height: 16),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                          ..._qcControllers.asMap().entries.map((entry) {
                              int i = entry.key;
                              var controller = entry.value;
                              return Container(
                                  width: 120,
                                  child: Row(
                                      children: [
                                          Expanded(
                                              child: SizedBox(
                                                  height: 35,
                                                  child: TextField(
                                                      controller: controller,
                                                      keyboardType: TextInputType.number,
                                                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                      onChanged: (_) => _saveQuickCash(),
                                                  ),
                                              ),
                                          ),
                                          IconButton(
                                              icon: const Icon(Icons.remove_circle, color: MetroColors.error, size: 20),
                                              onPressed: () {
                                                  setState(() {
                                                      _qcControllers.removeAt(i);
                                                      _saveQuickCash();
                                                  });
                                              },
                                          )
                                      ],
                                  ),
                              );
                          }).toList(),
                          TextButton.icon(
                              onPressed: () {
                                  setState(() {
                                      _qcControllers.add(TextEditingController(text: ''));
                                  });
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('TAMBAH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                          )
                      ],
                  )
              ],
          ),
      );
  }

  Widget _buildSettingRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ]),
        Switch(value: value, activeColor: MetroColors.primary, onChanged: onChanged),
      ],
    );
  }

  Widget _buildFlatDropdown<T>(String label, T? value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.03),
            border: Border.all(color: Colors.black.withOpacity(0.05))
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: MetroColors.white,
              icon: const Icon(Icons.arrow_drop_down, color: MetroColors.primary),
              style: const TextStyle(color: MetroColors.text, fontSize: 13, fontWeight: FontWeight.bold),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _savePrinterFilters() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_filter_cashier_name', _printerFilterCashierController.text.trim());
      await prefs.setString('printer_filter_label_name', _printerFilterLabelController.text.trim());
  }

  Widget _buildPrinterFilterSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         const MetroSectionTitle(title: 'Filter printer Bluetooth'),
         MetroPanel(
            child: Column(
               children: [
                  TextField(
                     key: const ValueKey('kasir_printer_filter'),
                     controller: _printerFilterCashierController,
                     style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: MetroColors.text),
                     decoration: const InputDecoration(
                         labelText: 'Nama printer kasir (contoh: RPP02N)',
                         helperText: 'Kosongkan untuk menampilkan semua perangkat',
                         border: OutlineInputBorder(),
                         filled: true,
                         fillColor: Colors.white,
                         contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                     ),
                     onChanged: (v) => _savePrinterFilters(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                     key: const ValueKey('label_printer_filter'),
                     controller: _printerFilterLabelController,
                     style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: MetroColors.text),
                     decoration: const InputDecoration(
                         labelText: 'Nama printer label',
                         helperText: 'Kosongkan untuk menampilkan semua perangkat',
                         border: OutlineInputBorder(),
                         filled: true,
                         fillColor: Colors.white,
                         contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                     ),
                     onChanged: (v) => _savePrinterFilters(),
                  ),
               ]
            )
         )
      ]
    );
  }
}
