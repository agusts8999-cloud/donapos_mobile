import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/utils_print.dart';
import 'package:donapos_mobile/utils_printer.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' as ep;
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart' as p3;
import 'package:donapos_mobile/services/printer_service_universal.dart' as ups;
import 'package:flutter_presentation_display/flutter_presentation_display.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:donapos_mobile/utils_label_printer.dart';
// Providers & Controllers
import 'package:donapos_mobile/providers/pos_provider.dart';
import 'package:donapos_mobile/controllers/pos_cart_controller.dart';
import 'package:donapos_mobile/controllers/pos_transaction_controller.dart';
import 'package:donapos_mobile/language_provider.dart';
import 'package:donapos_mobile/utils_scaler.dart';

// Components & Widgets
import 'package:donapos_mobile/screens/pos/components/pos_app_bar.dart';
import 'package:donapos_mobile/screens/pos/components/pos_scan_bar.dart';
import 'package:donapos_mobile/screens/pos/components/pos_category_sidebar.dart';
import 'package:donapos_mobile/screens/pos/components/pos_product_grid.dart';
import 'package:donapos_mobile/screens/pos/components/pos_cart_panel.dart';
import 'package:donapos_mobile/screens/pos/components/pos_modifier_dialog.dart';
import 'package:donapos_mobile/screens/pos/components/pos_payment_dialog.dart';
import 'package:donapos_mobile/screens/pos/components/pos_receipt_dialog.dart';
import 'package:donapos_mobile/screens/pos/components/pos_table_selector.dart';
import 'package:donapos_mobile/screens/pos/components/pos_held_orders_dialog.dart';

import 'package:donapos_mobile/screens/login_screen.dart'; // For logout/nav
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:donapos_mobile/widgets/customer_manager_dialog.dart';
import 'package:donapos_mobile/widgets/confirm_dialog.dart';
import 'package:donapos_mobile/widgets/sync_center_dialog.dart';
import 'package:donapos_mobile/widgets/sync_progress_dialog.dart';
import 'package:donapos_mobile/sync_helper.dart';
import 'package:donapos_mobile/widgets/printer_settings_dialog.dart';
import 'package:donapos_mobile/icod_printer.dart';
import 'package:donapos_mobile/widgets/kitchen_printer_dialog.dart';
import 'package:donapos_mobile/config.dart';
import 'package:donapos_mobile/utils_backup.dart';
import 'package:donapos_mobile/screens/admin/sd_card_backup_screen.dart';
import 'package:donapos_mobile/widgets/calculator_dialog.dart';
import 'package:donapos_mobile/utils_ui.dart';

// New Menu & Selectors
import 'package:donapos_mobile/screens/pos/components/pos_menu_dialog.dart';
import 'package:donapos_mobile/widgets/waiter_selector_dialog.dart';
import 'package:donapos_mobile/widgets/report_dialog.dart';
import 'package:donapos_mobile/widgets/expense_dialog.dart';
import 'package:donapos_mobile/widgets/attendance_dialog.dart';
import 'package:donapos_mobile/widgets/initial_cash_dialog.dart';
import 'package:donapos_mobile/screens/pos/components/close_shift_dialog.dart';
import 'package:donapos_mobile/widgets/transaction_history_dialog.dart';
// Manual Product Manager removed
import 'package:donapos_mobile/utils_storage.dart';
import 'package:donapos_mobile/screens/admin/local_data_check_dialog.dart';
import 'package:donapos_mobile/widgets/product_label_final.dart';
import 'package:donapos_mobile/screens/admin_dashboard.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  // Logic & Controllers
  late PosCartController _cartController;
  late PosProvider _posProvider;
  final PosTransactionController _transactionController = PosTransactionController();
  final ApiService _apiService = ApiService();
  
  // Local State (that hasn't moved to Provider yet, or UI specific)
  List<ResTable> _resTables = [];
  ResTable? _selectedTable;
  int? _activeTransactionId; 
  bool _isResuming = false;
  Map<String, dynamic>? _selectedCustomer;
  AppUser? _selectedWaiter;
  int _pax = 0;
  
  // UI Interaction
  Timer? _timer;
  Timer? _marqueeTimer;
  DateTime _now = DateTime.now();
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _actionsScrollController = ScrollController();
  final FocusNode _scanFocusNode = FocusNode();
  
  String _interactionMode = 'add';
  bool _isScanMode = false;
  bool _isManualInput = false;
  bool _isLoadingSync = false;
  bool _isPrinting = false;
  String _syncStatus = '';
  bool _isBlockedByAttendance = false;

  
  // Preferences
  Map<String, String> _businessInfo = {};
  String _cashierName = 'Admin';
  // ignore: unused_field
  int _currentUserId = 0;
  bool _roundingEnabled = false;
  int _roundingIncrement = 100;
  // ignore: unused_field
  bool _taxEnabled = false;
  bool _isLogoEnabled = true;
  int _paperSize = 58;
  bool _showAppVersion = true;
  String _appVersion = "";
  bool _calculatorEnabled = true;
  bool _animProductEnabled = false;
  bool _animMenuEnabled = false;
  bool _autoBackupEnabled = false;
  bool _duplicatePrintEnabled = false;
  bool _isDemoMode = false;
  bool _showBillButton = false;
  bool _showKitchenButton = true;
  bool _showDiscountButton = false;
  bool _attendanceRequired = true;
  bool _askCustomerNameEnabled = true;
  bool _autoPayAfterKot = true;
  
  // Sale Type Labels Cache
  final Map<String, String> _saleTypeLabels = {};
  
  // Printer
  BlueThermalPrinter printer = BlueThermalPrinter.instance;
  BluetoothDevice? _selectedDevice;
  // ignore: unused_field
  bool _connected = false;
  int _printerFontType = 2;
  bool _kotEnabled = false;
  String _kotType = 'bluetooth';
  String _kotAddress = '';
  String _kotAlias = 'PRINTER DAPUR';
  
  // Secondary Screen
  bool _secondScreenEnabled = false;
  bool _printHoldReceiptEnabled = false;
  bool _isRegistered = true;
  bool _isAdmin = false;

  // Transaction State for Receipt
  String _lastPaymentMethod = 'cash';
  List<Map<String, dynamic>> _lastPayments = [];
  List<Map<String, dynamic>> _paymentMethods = []; 
  // ignore: unused_field
  double _amountPaid = 0;
  // ignore: unused_field
  double _changeAmount = 0;
  int? _lastTxId;
  int _invoiceStartIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ScreenScaler.init(context);
  }

  @override
  void initState() {
    super.initState();
    _cartController = Provider.of<PosCartController>(context, listen: false);
    _posProvider = Provider.of<PosProvider>(context, listen: false);
    
    _cartController.addListener(_onCartChanged);
    _scanFocusNode.addListener(_onScanFocusChange);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData();
    });
    
    _initPrinter();
    _startClock();
    _startMarquees();
  }
  
  void _onCartChanged() {
      if (mounted) {
          setState(() {}); 
          if (_secondScreenEnabled) _updateSecondaryDisplay();
      }
  }
  
  void _onScanFocusChange() {
      if (_isScanMode && !_scanFocusNode.hasFocus) {
          Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _isScanMode && !_scanFocusNode.hasFocus) {
                  _scanFocusNode.requestFocus();
              }
          });
      }
  }

  @override
  void dispose() {
    _cartController.removeListener(_onCartChanged);
    _scanFocusNode.removeListener(_onScanFocusChange);
    SharedPreferences.getInstance().then((p) => p.reload());
    _timer?.cancel();
    _marqueeTimer?.cancel();
    _headerScrollController.dispose();
    _actionsScrollController.dispose();
    _scanFocusNode.dispose();
    super.dispose();
  }

  // --- LOADING DATA ---
  Future<void> _loadData() async {
      await _initPrefs();
      if (!mounted) return;
      
      final lastId = await DatabaseHelper.instance.getLastTransactionId();
      setState(() => _lastTxId = lastId);

      await _posProvider.loadData(context);
      await _loadTables();
      
      final db = await DatabaseHelper.instance.database;
      _paymentMethods = await db.query('payment_methods');
      
      // Load Default Customer
      final defaultCustomer = await DatabaseHelper.instance.getDefaultContact();
      if (defaultCustomer != null && _selectedCustomer == null) {
          setState(() => _selectedCustomer = defaultCustomer);
          await _applyCustomerPriceGroup(defaultCustomer);
      }

      _syncCartConfig();
      await _checkAttendance();
  }

  Future<void> _applyCustomerPriceGroup(Map<String, dynamic> c) async {
    try {
        // Reset to Standard Price by default unless overridden
        int? targetPgId;
        double? targetDisc;

        // Condition: Not "Pelanggan Umum" and not a default customer
        bool isUmum = c['name']?.toString().toLowerCase().contains('pelanggan umum') ?? false;
        bool isDefault = (c['is_default'] == 1 || c['is_default'] == true);

        if (!isUmum && !isDefault && c.containsKey('customer_group_id') && c['customer_group_id'] != null) {
            final groupId = c['customer_group_id'] is int ? c['customer_group_id'] : int.tryParse(c['customer_group_id'].toString());
            if (groupId != null) {
                final group = await DatabaseHelper.instance.getCustomerGroupById(groupId);
                if (group != null) {
                    if (group['price_calculation_type'] == 'percentage') {
                        targetDisc = double.tryParse(group['amount']?.toString() ?? '0') ?? 0;
                    } 
                    else if (group['price_calculation_type'] == 'selling_price_group' && group['selling_price_group_id'] != null) {
                        targetPgId = group['selling_price_group_id'] is int ? group['selling_price_group_id'] : int.parse(group['selling_price_group_id'].toString());
                    }
                    else if (group['selling_price_group_id'] != null) {
                        targetPgId = group['selling_price_group_id'] is int ? group['selling_price_group_id'] : int.parse(group['selling_price_group_id'].toString());
                    }
                }
            }
        }

        // Apply findings
        await _posProvider.setPriceGroup(targetPgId); 
        
        if (targetDisc != null && targetDisc > 0) {
            _cartController.setManualDiscount(targetDisc, true);
        } else {
            _cartController.setManualDiscount(0, false);
        }
        
        _syncCartConfig();

    } catch (e) {
        print('Apply Customer Price Group Error: $e');
    }
  }
  
  void _syncCartConfig() {
      _cartController.loadConfig(
          discounts: _posProvider.discounts, 
          taxes: _posProvider.taxes, 
          rounding: _roundingEnabled, 
          increment: _roundingIncrement, 
          discountVariations: _posProvider.discountVariations,
          localDiscount: _posProvider.activeLocalDiscount,
          currentPriceGroupId: _posProvider.currentPriceGroupId,
          displayPrices: _posProvider.displayPrices,
          taxEnabled: _taxEnabled,
          discountEnabled: false
      );
  }

  Future<void> _initPrefs() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      
      setState(() {
          _businessInfo = {
                'name': prefs.getString('business_name') ?? 'DonaPOS',
                'address': prefs.getString('business_address') ?? 'Kalideres, Jakarta Barat',
                'mobile': prefs.getString('business_mobile') ?? '081219752227',
                'lbl_subtotal': prefs.getString('lbl_subtotal') ?? 'Subtotal',
                'lbl_discount': prefs.getString('lbl_discount') ?? 'Diskon',
                'lbl_tax': prefs.getString('lbl_tax') ?? 'Tax',
                'lbl_total': prefs.getString('lbl_total') ?? 'TOTAL',
                'lbl_return': prefs.getString('lbl_return') ?? 'Kembalian',
                'footer_text': prefs.getString('footer_text') ?? 'Terima Kasih\nSelamat Menikmati',
                'invoice_prefix': prefs.getString('invoice_prefix') ?? 'MBL',
                'logo_path': prefs.getString('logo_path') ?? '',
          };
          _cashierName = prefs.getString('last_user_name') ?? 'Admin';
          _currentUserId = prefs.getInt('last_user_id') ?? 0;
          _roundingEnabled = prefs.getBool('rounding_enabled') ?? false;
          _roundingIncrement = prefs.getBool('rounding_enabled') as bool? ?? false ? prefs.getInt('rounding_increment') ?? 100 : 100; // wait, let's keep it simple
          _taxEnabled = prefs.getBool('tax_enabled') ?? false;
          _isLogoEnabled = prefs.getBool('is_logo_enabled') ?? true;
          _printHoldReceiptEnabled = prefs.getBool('print_hold_receipt_enabled') ?? false;
          _paperSize = prefs.getInt('printer_paper_size') ?? 58;
          _invoiceStartIndex = prefs.getInt('invoice_start_index') ?? 0;
          _showAppVersion = prefs.getBool('show_report_app_version') ?? true;
          _calculatorEnabled = prefs.getBool('show_calculator') ?? true;
          _animProductEnabled = prefs.getBool('anim_product_enabled') ?? false;
          _animMenuEnabled = prefs.getBool('anim_menu_enabled') ?? false;
          _autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? false;
          _duplicatePrintEnabled = prefs.getBool('duplicate_print_enabled') ?? false;
          _isDemoMode = prefs.getBool('is_demo_mode') ?? false;
          GlobalSettings.soundEnabled = prefs.getBool('sound_enabled') ?? false;
          _kotEnabled = prefs.getBool('kitchen_printer_enabled') ?? false;
          _kotType = prefs.getString('kitchen_printer_type') ?? 'bluetooth';
          _kotAddress = prefs.getString('kitchen_printer_address') ?? '';
          _kotAlias = prefs.getString('kitchen_printer_alias') ?? 'PRINTER DAPUR';
          _secondScreenEnabled = prefs.getBool('second_screen_enabled') ?? false;
          _showBillButton = prefs.getBool('show_bill_button') ?? false;
          _showKitchenButton = prefs.getBool('show_kitchen_button') ?? false; // Default OFF
          _showDiscountButton = prefs.getBool('show_discount_button') ?? false;
          _attendanceRequired = prefs.getBool('attendance_required') ?? true;
          _askCustomerNameEnabled = prefs.getBool('ask_customer_name_enabled') ?? true;
          _autoPayAfterKot = prefs.getBool('auto_pay_after_kot') ?? true;
          _isAdmin = prefs.getBool('last_user_is_admin') ?? false;
      });

      final isReg = await _apiService.isRegistered();
      setState(() {
          _isRegistered = isReg;
      });
      
      if (_secondScreenEnabled) {
          final displayManager = FlutterPresentationDisplay();
          final displays = await displayManager.getDisplays();
          if (displays != null && displays.length > 1 && displays[1].displayId != null) {
              displayManager.showSecondaryDisplay(displayId: displays[1].displayId!, routerName: 'customer_display');
          }
      }
      
      final pkg = await PackageInfo.fromPlatform();
      setState(() {
          _appVersion = "${pkg.version}+${pkg.buildNumber}";
      });
  }

   Future<void> _loadTables() async {
        try {
            final data = await DatabaseHelper.instance.getAllResTables();
            final pgs = await DatabaseHelper.instance.getAllPriceGroups();
            setState(() {
                _resTables = data.map((e) => ResTable.fromMap(e)).toList();
                for (var g in pgs) {
                    _saleTypeLabels['pg_${g['id']}'] = g['name'].toString().toUpperCase();
                }
            });
        } catch (e) {
            print("Error loading tables: $e");
        }
   }

  // --- UI BUILDING ---
  @override
  Widget build(BuildContext context) {
    return Consumer<PosProvider>(
      builder: (context, pos, child) {
        return Scaffold(
          backgroundColor: MetroColors.background,
          body: Stack(
            children: [
              Positioned.fill(
                child: SafeArea(
                  child: Column(
                    children: [
                      if (AppConfig.isTrainingMode)
                        Container(
                          width: double.infinity,
                          color: Colors.deepOrange, 
                          padding: EdgeInsets.symmetric(vertical: 4.sc),
                          child: Text('MODE LATIHAN - TRANSAKSI TIDAK DI-UPLOAD', 
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp, letterSpacing: 1.sc)
                          ),
                        ),
                      
                      // APP BAR
                      SizedBox(
                          height: kToolbarHeight, 
                          child: PosAppBar(
                            isClockedIn: true, 
                            businessName: _businessInfo['name'] ?? 'Donapos',
                            cashierName: _cashierName,
                            invoiceNumber: _getInvoiceNumber(isDraft: true),
                            now: _now,
                            saleTypeLabel: _getTypeLabel(pos.selectedPriceGroupId),
                            selectedTableName: _selectedTable != null ? '${_selectedTable!.name} (${_pax > 0 ? "$_pax P" : "0 P"})' : null,
                            hasCartItems: _cartController.hasItems,
                            selectedCustomerName: _selectedCustomer != null 
                                ? "${_selectedCustomer!['contact_id'] ?? ''} - ${_selectedCustomer!['name']}"
                                : null,
                            selectedWaiterName: _selectedWaiter?.firstName,
                            isResuming: _isResuming,
                            headerScrollController: _headerScrollController,
                            actionsScrollController: _actionsScrollController,
                            onMenuPressed: _showMainMenu,
                            onSaleTypePressed: _openSaleTypeSelector,
                            onHoldListPressed: _openHeldOrdersList,
                            onTablePressed: _openTableSelector,
                            onBillPressed: () {
                                if (!_cartController.hasItems) {
                                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KERANJANG KOSONG')));
                                   return;
                                }
                                _showReceiptSimulationDialog(isPreview: true);
                            },
                            onKitchenPrintPressed: () {
                                if (!_cartController.hasItems) {
                                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KERANJANG KOSONG')));
                                   return;
                                }
                                _confirmPrintKitchenOrder();
                            },
                            onSearchPressed: _openSearchDialog,
                            onScanPressed: _toggleScanMode,
                            onCustomerPressed: _showCustomerSelector,
                            onWaiterPressed: _showWaiterSelector,
                            onDiscountPressed: _showManualDiscountDialog,
                            onSyncPressed: _handleSyncTap,
                            onCalculatorPressed: _showCalculator,
                            calculatorEnabled: _calculatorEnabled,
                            billEnabled: _showBillButton,
                            kitchenEnabled: _showKitchenButton,
                            discountEnabled: _showDiscountButton,
                            isScanMode: _isScanMode,
                            unsyncedCount: pos.unsyncedCount,
                            isDemo: _isDemoMode,
                            onActionsPointerDown: (e) => _marqueeTimer?.cancel(),
                            onCloseAppPressed: _handleShiftClosing,
                          ),
                      ),
  
                      // SCAN BAR
                      PosScanBar(
                          isScanMode: _isScanMode,
                          isManualInput: _isManualInput,
                          scanFocusNode: _scanFocusNode,
                          onScan: _handleBarcodeScan,
                          onToggleMode: _toggleScanMode,
                          onToggleManualInput: () {
                              setState(() => _isManualInput = !_isManualInput);
                          },
                          onManualInputChange: (val) {
                               setState(() => _isManualInput = val);
                          },
                      ),
  
                      // MAIN CONTENT
                      Expanded(
                        child: Row(
                          children: [
                            // COL 1: SIDEBAR (Categories)
                            SizedBox(
                                width: 100.sc, // Explicit width for sidebar
                                child: PosCategorySidebar(
                                   categories: pos.categories,
                                    selectedCategoryId: pos.selectedCategoryId,
                                    onCategorySelected: (id) async {
                                        await pos.setCategory(id);
                                        _syncCartConfig();
                                    },
                                ),
                            ),
                            // COL 2: GRID (Products)
                            Expanded(
                                flex: 6,
                                child: PosProductGrid(
                                    products: pos.products,
                                    displayPrices: pos.displayPrices,
                                    cart: _cartController.cart,
                                    activeDiscounts: _cartController.activeDiscounts,
                                    discountVariations: _cartController.discountVariations,
                                    activeLocalDiscount: _cartController.activeLocalDiscount,
                                    selectedPriceGroupId: pos.selectedPriceGroupId,
                                    onProductTap: (p, price) => _handleTileTap(p),
                                    productsWithModifiers: pos.productsWithModifiers,
                                    isAnimEnabled: _animProductEnabled,
                                )
                            ),
                            // COL 3: CART & ACTIONS
                            SizedBox(
                                width: 320.sc, // Explicit width for cart panel
                                child: PosCartPanel(
                                    cart: _cartController.cart,
                                    subtotal: _cartController.subtotal,
                                    calculatedDiscount: _cartController.effectiveDiscount,
                                    calculatedTax: _cartController.calculatedTax,
                                    finalTotal: _cartController.finalTotal,
                                    invoiceNumber: _getInvoiceNumber(isDraft: true),
                                    interactionMode: _interactionMode,
                                    onInteractionModeChanged: (mode) => setState(() => _interactionMode = mode),
                                    onPayPressed: _showPaymentDialog,
                                    onHoldPressed: _holdTransaction,
                                    onItemTap: _editCartItem,
                                )
                            )
                          ]
                        )
                      )
                    ]
                  )
                ),
              ),
              
                if (pos.isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54, 
                    child: Center(
                      child: DonaposLoader(size: 80.sc),
                    ),
                  )
                ),

                if (_isPrinting)
                Positioned.fill(
                  child: Container(
                    color: Colors.black87, 
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DonaposLoader(size: 100.sc),
                          SizedBox(height: 20.sc),
                          Text(
                            'MENCETAK PESANAN...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.sc
                            ),
                          ),
                          SizedBox(height: 8.sc),
                          Text(
                            'HARAP TUNGGU SEBENTAR',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ),
            ]
          )
        );
      }
    );
  }

  // --- LOGIC: CART & PRODUCT ---
  void _handleBarcodeScan(String val) {
     final product = _posProvider.findProductBySku(val);
     if (product != null) {
         if (_interactionMode == 'add') {
             _addToCart(product);
         } else if (_interactionMode == 'sub') {
             _removeFromCart(product, isDecrease: true);
         } else if (_interactionMode == 'remove') {
             _removeFromCart(product, isDecrease: false);
         }
         
         if (mounted) {
             ScaffoldMessenger.of(context).clearSnackBars();
             ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('DISCAN: ${product.name.toUpperCase()}'), duration: const Duration(milliseconds: 800), backgroundColor: MetroColors.primary)
             );
         }
     } else {
         if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('SKU "$val" TIDAK DITEMUKAN'), backgroundColor: Colors.red)
             );
         }
     }
     _scanFocusNode.requestFocus();
  }

  Future<void> _addToCart(Product product) async {
     GlobalSettings.playClick();
     HapticFeedback.lightImpact();
     
     double price = _posProvider.displayPrices[product.id] ?? product.price;

     // Check Modifiers
     final modifiers = await DatabaseHelper.instance.getProductModifiers(product.id);
     List<ModifierOption> selectedModifiers = [];
     String note = '';
     
     if (modifiers.isNotEmpty && mounted) {
        final result = await showDialog(
            context: context,
            builder: (_) => PosModifierDialog(product: product)
        );
        if (result == null) return;
        if (result is Map) {
            selectedModifiers = result['modifiers'] as List<ModifierOption>;
            note = result['note'] as String;
        }
     } else if (_posProvider.productsWithModifiers.contains(product.id) && mounted) {
         showAppModal(context, title: 'MODIFIER ERROR', message: 'Data variasi tidak lengkap. Harap sinkron ulang.', isError: true);
         return;
     }
     
     _cartController.addToCart(product, price, selectedModifiers, note);
  }

  void _removeFromCart(Product p, {bool isDecrease = true}) {
      GlobalSettings.playClick();
      HapticFeedback.lightImpact();
      _cartController.removeFromCart(p, isDecrease: isDecrease);
  }
  
  void _handleTileTap(Product p) {
      if (_interactionMode == 'add') {
          _addToCart(p);
      } else if (_interactionMode == 'sub') {
          _removeFromCart(p, isDecrease: true);
      } else if (_interactionMode == 'remove') {
          _removeFromCart(p, isDecrease: false);
      }
  }

  void _editCartItem(CartItem item, int index) async {
      final controller = TextEditingController(text: item.note);
      await showDialog(context: context, builder: (context) => AlertDialog(
          title: const Text('Add Note'),
          content: TextField(controller: controller),
          actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(onPressed: () {
                  _cartController.updateNote(index, controller.text);
                  Navigator.pop(context);
              }, child: const Text('Save'))
          ],
      ));
   }

  // --- LOGIC: TRANSACTION ---

  Future<void> _showPaymentDialog() async {
    if (_cartController.cart.isEmpty) return;

    // REQUIREMENT: Customer is mandatory
    bool hasCustomer = await _ensureCustomerIsSelected();
    if (!hasCustomer) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PosPaymentDialog(
        finalTotal: _cartController.finalTotal,
        cartItems: _cartController.cart,
        onPaid: (payments, totalPaid, change) {
            Navigator.pop(ctx);
            _amountPaid = totalPaid;
            _changeAmount = change;
            
            // Determine primary method for legacy support
            String method = 'cash';
            if (payments.isNotEmpty) {
                 // Use the first non-cash method if available, or just the first method
                 // Or better: keep 'cash' if mixed, or specific if single
                 method = payments.first['method'];
            }
            
            _processTransaction(method, payments);
        },
      ),
    );
  }

  Future<void> _processTransaction(String paymentMethod, List<Map<String, dynamic>> payments) async {
    print('Processing TX: Method=$paymentMethod, Payments=$payments, Customer=${_selectedCustomer?['id']} (${_selectedCustomer?['name']})');
    setState(() {
        _lastPaymentMethod = paymentMethod;
        _lastPayments = payments;
    });
    try {
        final prefs = await SharedPreferences.getInstance();
        final activeShift = prefs.getInt('active_shift') ?? 1;

        final txId = await _transactionController.saveTransaction(
            cart: _cartController.cart,
            saleType: _getTypeLabel(_posProvider.selectedPriceGroupId),
            subtotal: _cartController.subtotal,
            discount: _cartController.effectiveDiscount, 
            tax: _cartController.calculatedTax,
            total: _cartController.finalTotal,
            paymentMethod: paymentMethod,
            cashierId: _currentUserId,
            cashierName: _cashierName,
            amountPaid: _amountPaid,
            changeAmount: _changeAmount,
            tableId: _selectedTable?.id,
            customerId: _selectedCustomer?['id'],
            customerName: _selectedCustomer?['name'],
            existingTxId: _isResuming ? _activeTransactionId : null,
            shiftId: activeShift,
            resServiceStaffId: _selectedWaiter?.id,
            pax: _pax,
            payments: payments,
            invoiceNo: _getInvoiceNumber(isDraft: true),
            manualDiscount: _cartController.manualDiscount,
        );
        
        setState(() => _lastTxId = txId);

        final bool autoPrint = prefs.getBool('auto_print_receipt') ?? true;
        if (autoPrint) {
            if (!_isResuming) {
                // Print with timeout protection — never block POS for more than 15s
                try {
                    await _printCustomerReceipt().timeout(
                        const Duration(seconds: 15),
                        onTimeout: () => debugPrint('[POS] Receipt print timeout — skipping.'),
                    );
                    
                    await Future.delayed(const Duration(milliseconds: 1000));

                    await _confirmPrintKitchenOrder();

                    await Future.delayed(const Duration(milliseconds: 1000));

                    await _printLabelStickers().timeout(
                        const Duration(seconds: 15),
                        onTimeout: () => debugPrint('[POS] Label print timeout — skipping.'),
                    );
                } catch (e) {
                    debugPrint('[POS] Print error (non-fatal): $e');
                }
            }
            // Finalize directly without dialog
            await _performFinalize();
        } else {
            // Show Dialog for verification/Finalize (Simulation)
            _showReceiptSimulationDialog(); 
        }
        
    } catch (e) {
        print('Transaction Error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showReceiptSimulationDialog({bool isPreview = false}) async {
    if (!mounted) return;
    
    // Pass payments to dialog if needed or handled inside
    showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PosReceiptDialog(
            isPreview: isPreview,
            allowDuplicate: _duplicatePrintEnabled, 
            cart: _cartController.cart,
            businessInfo: _businessInfo,
            cashierName: _cashierName,
            subtotal: _cartController.subtotal,
            calculatedDiscount: _cartController.effectiveDiscount,
            calculatedTax: _cartController.calculatedTax,
            finalTotal: _cartController.finalTotal,
            amountPaid: isPreview ? 0 : _amountPaid,
            changeAmount: isPreview ? 0 : _changeAmount,
            invoiceNumber: _getInvoiceNumber(),
            saleTypeLabel: _getTypeLabel(_posProvider.selectedPriceGroupId),
            selectedTableName: _selectedTable?.name,
            pax: _pax,
            waiterName: _selectedWaiter != null ? "${_selectedWaiter!.firstName} ${_selectedWaiter!.lastName ?? ''}".trim() : null,
            selectedCustomerName: _selectedCustomer?['name'],
            paymentMethod: isPreview ? null : _getPaymentMethodDisplay(_lastPaymentMethod),
            isLogoEnabled: _isLogoEnabled,
            showAppVersion: _showAppVersion,
            appVersion: _appVersion,
            onPrint: ({int times = 1, bool isDuplicate = false}) async {
              await _printCustomerReceipt(times: times, isDuplicate: isDuplicate);
            },
            onFinalize: () => _finalizeAndClose(ctx),
             taxDetails: _cartController.activeTaxes.map((t) {
                 double taxable = (_cartController.subtotal - _cartController.effectiveDiscount);
                 if (taxable < 0) taxable = 0;
                 return {
                     'name': t.name,
                     'amount': taxable * (t.amount / 100)
                 };
            }).toList(),
          ),
    );
  }

  Future<void> _finalizeAndClose(BuildContext dialogCtx) async {
      Navigator.pop(dialogCtx);
      await _performFinalize();
  }

  Future<void> _performFinalize() async {
      _cartController.clearCart();
      setState(() { 
          _selectedTable = null; 
          _selectedCustomer = null;
          _selectedWaiter = null;
          _activeTransactionId = null;
          _isResuming = false;
          _pax = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi Berhasil! Sedang Posting...'), duration: Duration(seconds: 1)));
      
      // Fire-and-forget: sync runs in background, POS ready immediately for next customer
      _transactionController.syncTransactions().then((_) {
          if (mounted) _posProvider.updateUnsyncedCount();
      }).catchError((e) {
          debugPrint('[POS] Background sync error: $e');
      });
      
      await _posProvider.setPriceGroup(null); // Reset to Standard Price
      _syncCartConfig();
      await _loadData(); // Comprehensive reset and refresh

      if (_autoBackupEnabled) {
          BackupService.autoBackup(maxBackups: 50);
      }
  }
  
  // --- TABLE & HOLD LOGIC ---
  void _openTableSelector() {
      showDialog(
          context: context,
          builder: (ctx) => PosTableSelectorDialog(
              tables: _resTables,
              selectedTable: _selectedTable,
              onSyncPressed: () { 
                  Navigator.pop(ctx);
                  _showSyncCenterDialog(); 
              },
              onManualPressed: () {
                  Navigator.pop(ctx);
                  _showManualTableEntry();
              },
              onReleaseTable: () {
                  setState(() => _selectedTable = null);
                  Navigator.pop(ctx);
              },
              onTableSelected: (table, pax) {
                  setState(() {
                      _selectedTable = table;
                      _pax = pax;
                  });
                  _checkForHeldTransaction(table.id);
                  Navigator.pop(ctx);
              },
          )
      );
  }

  Future<void> _checkForHeldTransaction(int tableId) async {
      final heldTx = await DatabaseHelper.instance.getHeldTransactionByTable(tableId);
      if (heldTx != null) {
          if (!mounted) return;
          final confirm = await showAppConfirm(
              context, 
              title: 'TRANSAKSI HOLD', 
              message: 'SIMPAN TRANSAKSI KE DAFTAR HOLD?',
              confirmLabel: 'LANJUTKAN',
              cancelLabel: 'BUAT BARU'
          );
          
          if (confirm) {
              _resumeTransaction(heldTx);
          } else {
              setState(() {
                  _cartController.clearCart();
                  _activeTransactionId = null;
                  _isResuming = false;
              });
          }
      } else {
          setState(() {
              _activeTransactionId = null;
              _isResuming = false;
          });
      }
  }

  Future<void> _resumeTransaction(Map<String, dynamic> tx) async {
      final items = await DatabaseHelper.instance.getTransactionItems(tx['id']);
      List<CartItem> resumedCart = [];
      for (var row in items) {
          final productMap = await DatabaseHelper.instance.getProductById(row['product_id']);
          if (productMap != null) {
              final modifierRows = await DatabaseHelper.instance.getTransactionItemModifiers(row['id']);
              List<ModifierOption> selectedModifiers = modifierRows.map((m) => ModifierOption(
                  id: m['modifier_option_id'],
                  setId: m['product_id'] ?? 0,
                  name: m['modifier_name'],
                  price: (m['price'] as num).toDouble(),
              )).toList();

              resumedCart.add(CartItem(
                product: Product.fromMap(productMap),
                qty: row['qty'],
                price: row['price'],
                note: row['note'] ?? '',
                selectedModifiers: selectedModifiers,
              ));
          }
      }

      AppUser? waiter;
      if (tx['res_service_staff_id'] != null) {
          final waiterMap = await DatabaseHelper.instance.getUserById(tx['res_service_staff_id']);
          if (waiterMap != null) {
              waiter = AppUser.fromMap(waiterMap);
          }
      }

      Map<String, dynamic>? customer;
      if (tx['customer_id'] != null) {
          customer = await DatabaseHelper.instance.getContactById(tx['customer_id']);
          // Fallback to minimal map if not found in contacts table
          customer ??= {
              'id': tx['customer_id'],
              'server_id': tx['customer_id'],
              'name': tx['customer_name'] ?? 'Umum',
          };
      }

      setState(() {
          _activeTransactionId = tx['id'];
          _isResuming = true;
          _selectedTable = (tx['res_table_id'] != null)
              ? _resTables.firstWhere((t) => t.id == tx['res_table_id'], orElse: () => ResTable(id: 0, businessId: 0, locationId: 0, name: '?'))
              : null;
          _pax = tx['pax'] ?? 0;
          _selectedCustomer = customer;
          _selectedWaiter = waiter;
      });


      _cartController.setCartItems(resumedCart);
      _cartController.setManualDiscount(tx['manual_discount'] ?? 0, false);

      // Note: mapping legacy dinein/takeaway back to null for now as it's the new standard
      await _posProvider.setPriceGroup(null);
      _syncCartConfig();
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Melanjutkan transaksi di Meja ${_selectedTable?.name}')));
  }
  
  void _openHeldOrdersList() async {
      final heldOrders = await DatabaseHelper.instance.getAllHeldTransactions();
      if (!mounted) return;
      showDialog(
          context: context,
          builder: (ctx) => PosHeldOrdersDialog(
              heldOrders: heldOrders,
              tables: _resTables,
              onOrderSelected: (order) {
                  _resumeTransaction(order); // It already pops in widget? Checked: yes it pops.
              },
          )
      );
  }
  
  Future<void> _holdTransaction() async {
      if (!_cartController.hasItems) return;

      final noteController = TextEditingController();
      bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
              title: const Text('HOLD TRANSAKSI?'),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      const Text('Masukkan catatan untuk pesanan ini (opsional):'),
                      const SizedBox(height: 12),
                      TextField(
                          controller: noteController,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Catatan / Nama Pelanggan'
                          ),
                      )
                  ],
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BATAL')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SIMPAN HOLD')),
              ],
          )
      );
      
      if (confirm != true) return;

      String holdNote = noteController.text.trim();
      if (holdNote.isEmpty) {
          // Generate random 4 digit number if empty
          holdNote = (1000 + Random().nextInt(9000)).toString();
      }

      int newTxId = 0;

      try {
          final prefs = await SharedPreferences.getInstance();
          final activeShift = prefs.getInt('active_shift') ?? 1;

          newTxId = await _transactionController.saveTransaction(
              cart: _cartController.cart,
              saleType: _getTypeLabel(_posProvider.selectedPriceGroupId),
              subtotal: _cartController.subtotal,
              discount: _cartController.effectiveDiscount, 
              tax: _cartController.calculatedTax,
              total: _cartController.finalTotal,
              paymentMethod: '',
              cashierName: _cashierName,
              amountPaid: 0,
              changeAmount: 0,
              tableId: _selectedTable?.id,
              customerId: _selectedCustomer?['server_id'] ?? _selectedCustomer?['id'],
              customerName: _selectedCustomer?['name'],
              existingTxId: _isResuming ? _activeTransactionId : null,
              shiftId: activeShift,
              resServiceStaffId: _selectedWaiter?.id,
              pax: _pax,
              status: 'hold', // Set status to hold
              isHold: true,   // Set isHold flag
              holdNote: holdNote,
              invoiceNo: _getInvoiceNumber(isDraft: true),
              manualDiscount: _cartController.manualDiscount,
          );

          if (!mounted) return;

          // Check if print is enabled
          if (_printHoldReceiptEnabled) {
               bool? printConfirm = await showAppConfirm(
                   context,
                   title: 'CETAK BUKTI?',
                   message: 'Cetak bukti hold untuk pesanan ini?',
                   confirmLabel: 'CETAK',
                   cancelLabel: 'TIDAK'
               );
               
               if (printConfirm == true) {
                   await _printHoldReceipt(newTxId, holdNote);
               }
          }

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Transaksi berhasil di-hold'),
              backgroundColor: Colors.orange,
          ));

          setState(() {
              _cartController.clearCart();
              _selectedTable = null;
              _selectedCustomer = null;
              _activeTransactionId = null;
              _isResuming = false;
              _selectedWaiter = null;
              _pax = 0;
          });
          await _posProvider.setPriceGroup(null);
          _syncCartConfig();
          
      } catch (e) {
          print('Hold Error: $e');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
  }

  Future<void> _printHoldReceipt(int txId, String holdNote) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
       final prefs = await SharedPreferences.getInstance();
       final String printerType = prefs.getString('printer_settings_type') ?? 'bluetooth';
       _printerFontType = prefs.getInt('printer_font_type') ?? 1;

       final profile = await ep.CapabilityProfile.load();
       final generator = ep.Generator(_paperSize == 80 ? ep.PaperSize.mm80 : ep.PaperSize.mm58, profile);
       List<int> bytes = [];

       bytes += generator.reset();
       final ep.PosFontType fontType = _printerFontType == 0 ? ep.PosFontType.fontA : ep.PosFontType.fontB;

       if (_isDemoMode) {
           bytes += generator.text("*** DEMO MODE ***", styles: ep.PosStyles(align: ep.PosAlign.center, bold: true, fontType: fontType));
           bytes += generator.text("TRANSAKSI UJI COBA", styles: ep.PosStyles(align: ep.PosAlign.center, fontType: fontType));
           bytes += generator.hr();
       }
       
       bytes += generator.text("PESANAN TERTUNDA", styles: ep.PosStyles(align: ep.PosAlign.center, bold: true, fontType: fontType, height: ep.PosTextSize.size2));
       bytes += generator.text("Nota Simpan", styles: ep.PosStyles(align: ep.PosAlign.center, fontType: fontType));
       bytes += generator.hr();

       bytes += generator.text(holdNote, styles: ep.PosStyles(align: ep.PosAlign.center, bold: true, fontType: fontType, height: ep.PosTextSize.size2));
       bytes += generator.hr();

       bytes += generator.text("Tgl: ${DateFormat('dd/MM/yy HH:mm').format(DateTime.now())}", styles: ep.PosStyles(fontType: fontType));
       if (_selectedTable != null) {
          bytes += generator.text("Meja: ${_selectedTable!.name} (${_pax} Pax)", styles: ep.PosStyles(bold: true, fontType: fontType));
       }
       if (_selectedCustomer != null) {
          bytes += generator.text("Plg: ${_selectedCustomer!['name']}", styles: ep.PosStyles(fontType: fontType));
       }
       if (_selectedWaiter != null) {
          bytes += generator.text("Waiter: ${_selectedWaiter!.firstName}", styles: ep.PosStyles(fontType: fontType));
       }
       
       bytes += generator.hr();
       
       for (var item in _cartController.cart) {
           bytes += generator.text("${item.qty} x ${item.product.name.toUpperCase()}", styles: ep.PosStyles(bold: true, fontType: fontType));
           if (item.selectedModifiers.isNotEmpty) {
               for(var mod in item.selectedModifiers) {
                   bytes += generator.text("  + ${mod.name}", styles: ep.PosStyles(fontType: fontType));
               }
           }
           if (item.note.isNotEmpty) bytes += generator.text("  (${item.note})", styles: ep.PosStyles(fontType: fontType));
       }
       
       bytes += generator.hr();
       bytes += generator.text("MOHON DISIMPAN", styles: ep.PosStyles(align: ep.PosAlign.center, fontType: fontType));
       bytes += generator.feed(2);
       bytes += generator.cut();

       if (printerType == 'icod') {
           bool ok = await IcodPrinter.isConnected();
           if (!ok) {
              final String connType = prefs.getString('icod_conn_type') ?? 'USB';
              if (connType == 'USB') await IcodPrinter.connectUsb();
              else await IcodPrinter.connectSerial(prefs.getString('icod_serial_path') ?? '/dev/ttyS1', prefs.getInt('icod_baud_rate') ?? 115200);
           }
           await IcodPrinter.printRaw(Uint8List.fromList(bytes));
       } else {
           if (!(await _ensurePrinterConnected())) return;
           await printer.writeBytes(Uint8List.fromList(bytes));
       }
    } catch (e) {
      debugPrint("Hold Print Error: $e");
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }


  
  void _clearTransaction() {
      setState(() {
          _cartController.clearCart();
          _selectedTable = null;
          _selectedCustomer = null;
          _selectedWaiter = null;
          _amountPaid = 0;
          _changeAmount = 0;
          _activeTransactionId = null;
          _isResuming = false;
          _pax = 0;
          _lastTxId = 0;
      });
  }

  // --- OTHERS ---
  Future<void> _showManualTableEntry() async {
      final textController = TextEditingController();
      final paxController = TextEditingController(text: '1');
      
      await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              title: Row(
                  children: [
                      const Icon(Icons.add_circle, color: MetroColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Text('INPUT MEJA MANUAL'.toUpperCase(), style: const TextStyle(color: MetroColors.text, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
                  ],
              ),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      TextField(
                          controller: textController,
                          autofocus: true,
                          style: const TextStyle(color: MetroColors.text, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                              labelText: 'NAMA MEJA',
                              labelStyle: TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.bold),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: MetroColors.primary)),
                          ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                          controller: paxController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: MetroColors.text, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                              labelText: 'JUMLAH PAX',
                              labelStyle: TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.bold),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: MetroColors.primary)),
                          ),
                      ),
                  ],
              ),
              actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx), 
                      child: const Text('BATAL', style: TextStyle(color: Colors.black26, fontWeight: FontWeight.bold))
                  ),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: MetroColors.primary, 
                          foregroundColor: Colors.white, 
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          elevation: 0
                      ),
                      onPressed: () {
                          if (textController.text.isNotEmpty) {
                              final manualTable = ResTable(
                                  id: -1 * DateTime.now().millisecondsSinceEpoch.floor(), // Virtual ID
                                  businessId: 0,
                                  locationId: 0,
                                  name: textController.text,
                              );
                              setState(() {
                                  _selectedTable = manualTable;
                                  _pax = int.tryParse(paxController.text) ?? 1;
                              });
                              Navigator.pop(ctx);
                          }
                      }, 
                      child: const Text('GUNAKAN MEJA', style: TextStyle(fontWeight: FontWeight.bold))
                  )
              ],
          )
      );
  }

  String _getInvoiceNumber({bool isDraft = false}) {
       int id = (_lastTxId ?? 0);
       if (isDraft) id += 1;
       if (id == 0 && !isDraft) return "-";
       if (id == 0 && isDraft) id = 1;
       final prefix = _businessInfo['invoice_prefix'] ?? 'MBL';
       final date = DateFormat('yyMMdd').format(DateTime.now());
       int displayId = id + _invoiceStartIndex;
       return "$prefix$date${displayId.toString().padLeft(4, '0')}";
  }
  
   String _getTypeLabel(int? pgId) {
       if (pgId == null) return 'HARGA STANDAR';
       return _saleTypeLabels['pg_$pgId'] ?? 'GRUP #$pgId';
   }


  Future<void> _showMainMenu() async {
    final String? command = await showDialog<String>(
      context: context,
      builder: (_) => PosMenuDialog(
        isAdmin: _isAdmin,
      ),
    );

    if (command == null) return;
    
    // Safety delay to ensure previous dialog is completely dismissed from the stack
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    switch (command) {
      case 'history':
        _showHistory();
        break;
      case 'expenses':
        showDialog(context: context, builder: (_) => const ExpenseDialog());
        break;
      case 'attendance':
        final res = await showDialog<bool>(
            context: context, 
            builder: (_) => AttendanceDialog(userId: _currentUserId, username: _cashierName)
        );
        if (res == true) {
             if (Platform.isAndroid || Platform.isIOS) {
                SystemNavigator.pop();
             } else {
                exit(0);
             }
        }
        break;
      case 'label_printer':
        debugPrint("[PosScreen] OPENING ProductLabelFinal...");
        if (!mounted) break;
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) {
            debugPrint("[PosScreen] Internal Builder for ProductLabelFinal...");
            return const ProductLabelFinal();
          }
        );
        break;
      case 'settings':
        showDialog(context: context, builder: (_) => const PrinterSettingsDialog());
        break;
      case 'kitchen_settings':
        await showDialog(context: context, builder: (_) => const KitchenPrinterDialog());
        // Reload KOT settings after dialog closed
        await _initPrefs(); 
        break;
      case 'report':
        showDialog(context: context, builder: (_) => const ReportDialog());
        break;
      case 'check_local':
        showDialog(context: context, builder: (_) => const LocalDataCheckDialog());
        break;
      case 'check_storage':
        StorageUtils.showStorageInfo(context);
        break;
      case 'sync':
        _showSyncCenterDialog();
        break;
      case 'backup':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SdCardBackupScreen(allowRestore: false)));
        break;
      case 'admin':
        _showAdminAuthToDashboard();
        break;
      case 'logout':
        _handleShiftClosing();
        break;
    }
  }
  
  void _showHistory() {
      debugPrint("[PosScreen] _showHistory called");
      showDialog(
         context: context,
         builder: (_) => TransactionHistoryDialog(
            businessInfo: _businessInfo,
            cashierName: _cashierName
         )
     );
  }
  
  Future<void> _openSaleTypeSelector() async {
      final List<Map<String, dynamic>> pgs = await DatabaseHelper.instance.getAllPriceGroups();

      await showDialog(
          context: context,
          builder: (ctx) => GlassDialog(
             title: 'PILIH GRUP HARGA JUAL',
             icon: Icons.sell,
             width: 450,
             height: 500,
             content: SingleChildScrollView(
               child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                       // Standard Price Option
                       _typeBtn(ctx, 'HARGA STANDAR (DEFAULT)', null, Icons.stars, MetroColors.primary),
                       
                       if (pgs.isNotEmpty) ...[
                           const Padding(
                             padding: EdgeInsets.symmetric(vertical: 20),
                             child: Row(
                               children: [
                                 Expanded(child: Divider()),
                                 Padding(
                                   padding: EdgeInsets.symmetric(horizontal: 16),
                                   child: Text('GRUP HARGA ERP', style: TextStyle(color: Colors.black26, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                 ),
                                 Expanded(child: Divider()),
                               ],
                             ),
                           ),
                           ...pgs.map((g) {
                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 12),
                                 child: _typeBtn(ctx, g['name'].toString().toUpperCase(), g['id'], Icons.sell, Colors.blueGrey),
                               );
                           }).toList(),
                       ],
                   ],
               ),
             )
          )
      );
  }

  Widget _typeBtn(BuildContext ctx, String label, int? pgId, IconData icon, Color color) {
      return MetroButton(
          label: label, 
          icon: icon, 
          color: color,
          onPressed: () async {
              await _posProvider.setPriceGroup(pgId);
              _syncCartConfig();
              if (ctx.mounted) Navigator.pop(ctx);
          },
          isLarge: true,
      );
  }
  
  void _openSearchDialog() {
       final controller = TextEditingController(text: _posProvider.searchQuery);
       showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              title: Row(
                children: [
                   const Icon(Icons.search, color: MetroColors.primary, size: 20),
                   const SizedBox(width: 12),
                   Text('CARI PRODUK'.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                ],
              ),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (val) => _posProvider.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'KETIK NAMA ATAU KODE...',
                    hintStyle: const TextStyle(fontSize: 10, color: Colors.black26),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         // add_circle button removed
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black26),
                          onPressed: () {
                            controller.clear();
                            _posProvider.setSearchQuery('');
                          },
                        ),
                      ],
                    ),
                  ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  child: Text('OK', style: TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900))
                )
              ]
          )
       );
  }
  
  void _toggleScanMode() {
      setState(() {
          _isScanMode = !_isScanMode;
          _isManualInput = false;
          if (_isScanMode) _scanFocusNode.requestFocus();
          else _scanFocusNode.unfocus();
      });
  }
  
  // Stubs for remaining UI actions
  void _showCustomerSelector() { 
    showDialog(
      context: context, 
      builder: (_) => CustomerManagerDialog(
        isSelectionOnly: true, 
        onSelect: (c) {
          setState(() => _selectedCustomer = c);
          _applyCustomerPriceGroup(c);
        }
      )
    ); 
  }
  void _showWaiterSelector() {
    showDialog(
      context: context,
      builder: (_) => WaiterSelectorDialog(
        onSelect: (user) {
          setState(() => _selectedWaiter = user);
        },
      ),
    );
  }
  void _showManualDiscountDialog() { _showManualDiscountDialogImpl(); } 
  void _showCalculator() { showDialog(context: context, builder: (_) => CalculatorDialog()); }
  void _handleSyncTap() {
    if (_isLoadingSync) return;
    if (_posProvider.unsyncedCount > 0) {
      _quickUploadSales();
    } else {
      _showSyncCenterDialog();
    }
  }

  void _quickUploadSales() async {
    setState(() => _isLoadingSync = true);
    
    final isOnline = await _apiService.checkConnection();
    if (!isOnline) {
      if (mounted) {
        setState(() => _isLoadingSync = false);
        showAppModal(
          context, 
          title: 'OFFLINE', 
          message: 'GAGAL KIRIM DATA. PERIKSA KONEKSI INTERNET ANDA.', 
          isError: true
        );
      }
      return;
    }

    try {
      await SyncHelper.runSyncTask(
        context, 
        'POSTING PENJUALAN', 
        ({onProgress}) => _apiService.syncTransactionsWithLogs(onProgress: onProgress),
        onSuccess: () {
          if (mounted) {
              _posProvider.updateUnsyncedCount();
          }
        }
      );
    } finally {
      if (mounted) setState(() => _isLoadingSync = false);
    }
  }

  void _showAdminAuthToDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminDashboard(username: _cashierName)),
    );
  }

  void _handleShiftClosing() async {
      final result = await showDialog(
        context: context,
        builder: (ctx) => CloseShiftDialog(
            onPrint: (reason, note) => _printShiftClosing(reason, note),
        )
      );

      if (result != null && result is Map) {
          final String action = result['action'];

          if (mounted) {
              if (action == 'exit') {
                  if (Platform.isAndroid || Platform.isIOS) {
                      SystemNavigator.pop();
                  } else {
                      exit(0);
                  }
              }
          }
      }
  }

  Future<void> _printShiftClosing(String reason, String note) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
       final prefs = await SharedPreferences.getInstance();
       final String printerType = prefs.getString('printer_settings_type') ?? 'bluetooth';

       final profile = await ep.CapabilityProfile.load();
       final generator = ep.Generator(_paperSize == 80 ? ep.PaperSize.mm80 : ep.PaperSize.mm58, profile);
       List<int> bytes = [];

       bytes += generator.reset();
       bytes += generator.text("LAPORAN PENUTUPAN", styles: const ep.PosStyles(align: ep.PosAlign.center, bold: true, fontType: ep.PosFontType.fontB));
       bytes += generator.feed(1);
       bytes += generator.text("Kasir: $_cashierName", styles: const ep.PosStyles(align: ep.PosAlign.center, fontType: ep.PosFontType.fontB));
       bytes += generator.text("Waktu: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}", styles: const ep.PosStyles(align: ep.PosAlign.center, fontType: ep.PosFontType.fontB));
       bytes += generator.feed(1);
       bytes += generator.hr();
       
       bytes += generator.text("ALASAN:", styles: const ep.PosStyles(fontType: ep.PosFontType.fontB));
       bytes += generator.text(reason, styles: const ep.PosStyles(align: ep.PosAlign.right, fontType: ep.PosFontType.fontB));
       
       if (note.isNotEmpty) {
           bytes += generator.feed(1);
           bytes += generator.text("CATATAN:", styles: const ep.PosStyles(fontType: ep.PosFontType.fontB));
           bytes += generator.text(note, styles: const ep.PosStyles(fontType: ep.PosFontType.fontB));
       }
       
       bytes += generator.feed(2);
       
       // Simple Footer
       bytes += generator.text("SPV                     KASIR", styles: const ep.PosStyles(align: ep.PosAlign.center, bold: true, fontType: ep.PosFontType.fontB));
       bytes += generator.feed(3);
       bytes += generator.text("( ............ )       ( ............ )", styles: const ep.PosStyles(align: ep.PosAlign.center, fontType: ep.PosFontType.fontB));
       bytes += generator.feed(2);
       bytes += generator.text("Terima Kasih", styles: const ep.PosStyles(align: ep.PosAlign.center, fontType: ep.PosFontType.fontB));
       bytes += generator.feed(2);
       bytes += generator.cut();

       if (printerType == 'icod') {
           bool ok = await IcodPrinter.isConnected();
           if (!ok) {
              final String connType = prefs.getString('icod_conn_type') ?? 'USB';
              if (connType == 'USB') await IcodPrinter.connectUsb();
              else await IcodPrinter.connectSerial(prefs.getString('icod_serial_path') ?? '/dev/ttyS1', prefs.getInt('icod_baud_rate') ?? 115200);
           }
           await IcodPrinter.printRaw(Uint8List.fromList(bytes));
       } else {
           if (!(await _ensurePrinterConnected())) return;
           await printer.writeBytes(Uint8List.fromList(bytes));
       }
    } catch (e) {
        debugPrint("Shift Closing Print Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("GAGAL CETAK: $e"), backgroundColor: Colors.red));
    } finally {
        if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _showSyncCenterDialog() async { 
    setState(() => _isLoadingSync = true);
    
    // CRITICAL: Force Logout/Reset first to ensure `authenticateClient` gets fresh token.
    await _apiService.resetToken();
    bool authSuccess = await _apiService.authenticateClient();
    
    if (!authSuccess) {
         if (mounted) {
            setState(() => _isLoadingSync = false);
            showAppModal(context, title: 'ERROR', message: 'GAGAL LOGIN BACKGROUND ADMIN. PERIKSA KONEKSI.', isError: true);
         }
         return;
    }

    if (!mounted) return;
    setState(() => _isLoadingSync = false);

    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => SyncCenterDialog(
            isLoading: false,
            username: _cashierName,
            apiService: _apiService,
            onSyncTask: (title, task) {},
            onSyncComplete: () {
                if (mounted) {
                    _posProvider.updateUnsyncedCount();
                    _loadData();
                }
            },
        )
    ).then((_) async {
         // User closed dialog.
         // Request says "Login Ulang".
         // Since we don't have PIN, attempt to re-establish User Context if possible?
         // Maybe just re-fetch user info?
         // Actually, if Machine Token is active, `getUserInfo` returns null/empty?
         // Let's just reload data.
         if (mounted) _loadData();
    });
  }
  Future<void> _confirmPrintKitchenOrder() async {
      if (!_cartController.hasItems) return;
      
      final String warningText = _kotEnabled 
          ? 'Yakin akan mencetak pesanan ke dapur sekarang? Instruksi akan langsung dikerjakan oleh bagian dapur.'
          : 'PRINTER DAPUR SEDANG NON-AKTIF (OFF).\n\nPesanan akan dicetak menggunakan Printer Kasir sebagai cadangan. Lanjutkan?';

      final bool? proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
              title: Text(_kotEnabled ? 'KIRIM KE DAPUR?' : 'CETAK KE KASIR? (KOT OFF)', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Text(warningText),
              actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false), 
                      child: Text('BATAL', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold))
                  ),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true), 
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _kotEnabled ? MetroColors.primary : Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
                      ),
                      child: Text(_kotEnabled ? 'CETAK SEKARANG' : 'LANJUT CETAK KASIR', style: const TextStyle(fontWeight: FontWeight.bold))
                  ),
              ],
          )
      );

      if (proceed == true) {
          await _printKitchenOrder();
          
          // FEATURE: Auto Pay after KOT
          if (_autoPayAfterKot && mounted) {
              await Future.delayed(const Duration(milliseconds: 500));
              _showPaymentDialog();
          }
      }
  }

  Future<void> _printKitchenOrder() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      if (!_kotEnabled) {
         await _executeKitchenPrintBT(printer); // Fallback to current behavior if not explicitly configured
         return;
      }

      if (_kotType == 'bluetooth') {
          final String targetAddress = _kotAddress;

          if (targetAddress.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ALAMAT PRINTER DAPUR BELUM DISET (KOSONG)'), backgroundColor: Colors.red));
              return;
          } else {
              final cashierAddress = _selectedDevice?.address;
              
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Memutus koneksi... Menuju Dapur: $targetAddress'), duration: const Duration(seconds: 2)));
              
              // 1. Force Disconnect
              await printer.disconnect();
              await Future.delayed(const Duration(milliseconds: 2000));
              
              // 2. Connect to Kitchen MAC
              final devs = await printer.getBondedDevices();
              final d = devs.firstWhere((element) => element.address == targetAddress, orElse: () => throw "Printer Dapur ($targetAddress) tidak ditemukan di daftar Paired Bluetooth.");
              
              bool success = await printer.connect(d) ?? false;
              if (!success) {
                  await Future.delayed(const Duration(milliseconds: 1500));
                  await printer.connect(d);
              }
              
              await Future.delayed(const Duration(milliseconds: 1000));
              
              // 3. Print
              if (await printer.isConnected ?? false) {
                  await _executeKitchenPrintBT(printer);
                  await Future.delayed(const Duration(milliseconds: 1500));
              } else {
                  throw "Gagal terhubung ke Printer Dapur ($targetAddress)";
              }
              
              // 4. Revert
              if (cashierAddress != null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kembali ke Kasir...'), duration: Duration(seconds: 1)));
                  await printer.disconnect();
                  await Future.delayed(const Duration(milliseconds: 2000));
                  final devsAfter = await printer.getBondedDevices();
                  final c = devsAfter.firstWhere((element) => element.address == cashierAddress);
                  await printer.connect(c);
              }
          }
      }
      else if (_kotType == 'lan') {
          if (_kotAddress.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IP PRINTER DAPUR BELUM DIATUR')));
              return;
          }
          await _executeKitchenPrintLAN(_kotAddress);
      } else {
          await _executeKitchenPrintBT(printer);
      }
    } catch (e) {
      debugPrint("Kitchen Printing Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GAGAL CETAK DAPUR: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _executeKitchenPrintLAN(String ip) async {
    try {
        final profile = await ep.CapabilityProfile.load();
        final generator = ep.Generator(_paperSize == 80 ? ep.PaperSize.mm80 : ep.PaperSize.mm58, profile);
        
        List<int> bytes = await _generateKitchenBytes(generator);

        var printerManager = p3.PrinterManager.instance;
        bool result = await printerManager.connect(
            type: p3.PrinterType.network, 
            model: p3.TcpPrinterInput(ipAddress: ip)
        );
        
        if (result) {
            await printerManager.send(type: p3.PrinterType.network, bytes: bytes);
            // Wait a bit before disconnect to ensure buffer is sent
            await Future.delayed(const Duration(seconds: 1));
            await printerManager.disconnect(type: p3.PrinterType.network);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ORDER DAPUR TERKIRIM KE IP: $ip')));
        } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GAGAL TERHUBUNG KE PRINTER DAPUR (LAN)'), backgroundColor: Colors.red));
        }
    } catch (e) {
        debugPrint("Kitchen LAN Print Error: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ERROR CETAK DAPUR: $e'), backgroundColor: Colors.red));
    }
  }

  Future<List<int>> _generateKitchenBytes(ep.Generator generator) async {
    List<int> bytes = [];
    int kitchenFont = 1; // Condensed

    bytes += generator.reset();
    
    if (_isDemoMode) {
        bytes += generator.text("*** DEMO MODE ***", styles: const ep.PosStyles(align: ep.PosAlign.center, bold: true));
        bytes += generator.text("TESTING ORDER", styles: const ep.PosStyles(align: ep.PosAlign.center, bold: true));
        bytes += generator.hr();
    }

    bytes += generator.text(_kotAlias.toUpperCase(), styles: const ep.PosStyles(align: ep.PosAlign.center, bold: true, height: ep.PosTextSize.size2, width: ep.PosTextSize.size2));
    bytes += generator.hr();
    
    final invoice = _getInvoiceNumber(isDraft: true);
    final orderNum = invoice.length > 4 ? invoice.substring(invoice.length - 4) : invoice;
    
    bytes += generator.text("NO. ORDER: $orderNum", styles: const ep.PosStyles(bold: true));
    bytes += generator.text("INVOICE: $invoice");
    bytes += generator.text("TGL: ${DateFormat('dd/MM/yy').format(DateTime.now())} JAM: ${DateFormat('HH:mm').format(DateTime.now())}");
    
    if (_selectedTable != null) {
        bytes += generator.text("MEJA: ${_selectedTable!.name.toUpperCase()}${_pax > 0 ? ' ($_pax P)' : ''}", styles: const ep.PosStyles(bold: true));
    } else {
        bytes += generator.text("MEJA: -");
    }
    
    final waiterName = _selectedWaiter != null 
        ? "${_selectedWaiter!.firstName} ${_selectedWaiter!.lastName ?? ''}".trim() 
        : "-";
    bytes += generator.text("WAITER: ${waiterName.toUpperCase()}");
    bytes += generator.text("KASIR: $_cashierName".toUpperCase());
    bytes += generator.text("PELANGGAN: ${_selectedCustomer?['name']?.toUpperCase() ?? 'UMUM'}");
    bytes += generator.text("TIPE: ${_getTypeLabel(_posProvider.selectedPriceGroupId)}".toUpperCase());
    
    bytes += generator.hr();
    
    for (var item in _cartController.cart) {
        bytes += generator.text("${item.qty} x ${item.product.name}".toUpperCase(), styles: const ep.PosStyles(bold: true));
        
        if (item.selectedModifiers.isNotEmpty) {
            for (var mod in item.selectedModifiers) {
                bytes += generator.text("  + ${mod.name}".toUpperCase());
            }
        }
        
        if (item.note.isNotEmpty) {
            bytes += generator.text("  NOTE: ${item.note}".toUpperCase());
        }
        bytes += generator.feed(1);
    }
    
    bytes += generator.hr();
    bytes += generator.feed(3);
    bytes += generator.cut();
    
    return bytes;
  }

  // Internal Impls
  void _showManualDiscountDialogImpl() {
      if (!_cartController.hasItems) {
          showAppModal(context, title: 'KERANJANG KOSONG', message: 'TAMBAHKAN PRODUK TERLEBIH DAHULU!', isError: true);
          return;
      }

      double localVal = _cartController.manualDiscountVal;
      bool localIsPercent = _cartController.manualDiscountIsPercent;

      showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
              builder: (context, setDialogState) => GlassDialog(
                  title: 'DISKON TAMBAHAN',
                  icon: Icons.percent,
                  width: 680,
                  height: 400,

                  content: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          Expanded(
                              flex: 4,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      const Text('TIPE DISKON', style: TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                      const SizedBox(height: 8),
                                      _typeTab(ctx, 'PERSENTASE (%)', localIsPercent, () => setDialogState(() => localIsPercent = true)),
                                      const SizedBox(height: 4),
                                      _typeTab(ctx, 'NOMINAL (RUPIAH)', !localIsPercent, () => setDialogState(() => localIsPercent = false)),
                                      const Spacer(),
                                      Container(
                                          padding: const EdgeInsets.all(10),
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              border: Border.all(color: Colors.black12),
                                          ),
                                          child: Column(
                                              children: [
                                                  const Text('NOMINAL INPUT', style: TextStyle(color: Colors.black38, fontSize: 8, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 4),
                                                  FittedBox(
                                                      child: Text(
                                                          localIsPercent ? "${localVal.toStringAsFixed(0)}%" : NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(localVal),
                                                          style: const TextStyle(color: MetroColors.text, fontSize: 32, fontWeight: FontWeight.w900)
                                                      ),
                                                  ),
                                              ],
                                          ),
                                      ),
                                  ],
                              ),
                          ),
                          const VerticalDivider(width: 32, color: Colors.black12, indent: 5, endIndent: 5),
                          Expanded(
                              flex: 5,
                              child: Column(
                                  children: [
                                      Expanded(
                                          child: GridView.count(
                                              crossAxisCount: 3,
                                              mainAxisSpacing: 4,
                                              crossAxisSpacing: 4,
                                              childAspectRatio: 1.8,
                                              children: [
                                                  for (var i = 1; i <= 9; i++) _numBtn(i.toString(), () => _updateManualDisc(setDialogState, i.toString(), localVal, (v) => localVal = v, localIsPercent)),
                                                  _numBtn('C', () => setDialogState(() => localVal = 0), color: Colors.red.withOpacity(0.1), textColor: Colors.red),
                                                  _numBtn('0', () => _updateManualDisc(setDialogState, '0', localVal, (v) => localVal = v, localIsPercent)),
                                                  _numBtn('DEL', () {
                                                      String s = localVal.toStringAsFixed(0);
                                                      if (s.length > 1) {
                                                          setDialogState(() => localVal = double.parse(s.substring(0, s.length - 1)));
                                                      } else {
                                                          setDialogState(() => localVal = 0);
                                                      }
                                                  }, color: Colors.orange.withOpacity(0.3)),
                                              ],
                                          ),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                          width: double.infinity,
                                          height: 46,
                                          child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: MetroColors.primary, 
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
                                              ),
                                              onPressed: () {
                                                  _cartController.setManualDiscount(localVal, localIsPercent);
                                                  Navigator.pop(ctx);
                                              },
                                              child: const Text('TERAPKAN DISKON', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                                          ),
                                      )
                                  ],
                              ),
                          ),
                      ],
                  ),
              ),
          )
      );
  }

  void _updateManualDisc(StateSetter setDialogState, String val, double current, Function(double) update, bool isPercent) {
      String s = current.toStringAsFixed(0);
      if (s == "0") s = "";
      String next = s + val;
      double nextVal = double.tryParse(next) ?? 0;

      if (isPercent && nextVal > 100) nextVal = 100;
      if (!isPercent && nextVal > _cartController.subtotal) nextVal = _cartController.subtotal;

      setDialogState(() => update(nextVal));
  }

  Widget _typeTab(BuildContext ctx, String label, bool active, VoidCallback onTap) {
      return InkWell(
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: active ? MetroColors.primary : Colors.grey[200],
              alignment: Alignment.center,
              child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.black45, fontSize: 8.5, fontWeight: FontWeight.bold)),
          ),
      );
  }

  Widget _numBtn(String label, VoidCallback onTap, {Color? color, Color textColor = Colors.black87}) {
      return Material(
          color: color ?? Colors.white,
          shape: RoundedRectangleBorder(side: BorderSide(color: Colors.black.withOpacity(0.05))),
          child: InkWell(onTap: onTap, child: Center(child: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)))),
      );
  }
  
  // --- PRINTER LOGIC ---
  void _initPrinter() async {
    try {
      List<BluetoothDevice> devices = await printer.getBondedDevices();
      final prefs = await SharedPreferences.getInstance();
      final savedAddress = prefs.getString('printer_address');
      if (savedAddress != null && devices.isNotEmpty) {
          final found = devices.where((d) => d.address == savedAddress);
          if (found.isNotEmpty) {
              setState(() => _selectedDevice = found.first);
              _connectPrinter();
          }
      }
    } catch(e) {
      print("[Printer] Error init: $e");
    }
  }

  Future<void> _connectPrinter() async {
      if (_selectedDevice != null) {
          try {
              if ((await printer.isConnected) != true) {
                  await printer.connect(_selectedDevice!);
                  if (mounted) setState(() => _connected = true);
              }
          } catch (e) {
              print("Error connecting printer: $e");
          }
      }
  }

  Future<bool> _ensurePrinterConnected() async {
    if ((await printer.isConnected) == true) return true;
    _initPrinter(); 
    await Future.delayed(const Duration(milliseconds: 500));
    if ((await printer.isConnected) == true) return true;

    if (!mounted) return false;

    bool? goToConfig = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PRINTER TIDAK TERHUBUNG'),
        content: const Text('Aplikasi tidak dapat terhubung ke printer thermal. Pastikan Bluetooth dan Printer sudah aktif.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('TIDAK CETAK')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('PENGATURAN')),
        ],
      ),
    );

    if (goToConfig == true) {
      await showDialog(context: context, builder: (_) => const PrinterSettingsDialog());
      return (await printer.isConnected) == true;
    }
    return false;
  }

  Future<void> _executeKitchenPrintBT(BlueThermalPrinter btPrinter) async {
    // Note: Caller is responsible for ensuring connection to correct device
    if ((await btPrinter.isConnected) != true) {
        debugPrint("[POS] BT Printer not connected for Kitchen Print.");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PRINTER DAPUR TIDAK TERHUBUNG"), backgroundColor: Colors.red));
        return;
    }

    try {
        final profile = await ep.CapabilityProfile.load();
        final generator = ep.Generator(_paperSize == 80 ? ep.PaperSize.mm80 : ep.PaperSize.mm58, profile);
        
        List<int> bytes = await _generateKitchenBytes(generator);
        await btPrinter.writeBytes(Uint8List.fromList(bytes));
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Dapur Dicetak (Bluetooth)')));
    } catch (e) {
        debugPrint("BT Kitchen Print Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("GAGAL CETAK DAPUR: $e"), backgroundColor: Colors.red));
    }
  }
  
  Future<void> _printCustomerReceipt({int times = 1, bool isDuplicate = false}) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String printerType = prefs.getString('printer_settings_type') ?? 'bluetooth';
      _printerFontType = prefs.getInt('printer_font_type') ?? 1;

      final profile = await ep.CapabilityProfile.load();
      final generator = ep.Generator(_paperSize == 80 ? ep.PaperSize.mm80 : ep.PaperSize.mm58, profile);
      
      List<int> bytes = await _generateCustomerReceiptBytes(generator, isDuplicate: isDuplicate);

      if (printerType == 'icod') {
          // iCod Internal Printer
          bool ok = await IcodPrinter.isConnected();
          if (!ok) {
              final String connType = prefs.getString('icod_conn_type') ?? 'USB';
              if (connType == 'USB') await IcodPrinter.connectUsb();
              else await IcodPrinter.connectSerial(prefs.getString('icod_serial_path') ?? '/dev/ttyS1', prefs.getInt('icod_baud_rate') ?? 115200);
          }
          
          for (int i = 0; i < times; i++) {
              await IcodPrinter.printRaw(Uint8List.fromList(bytes));
              if (i < times - 1) await Future.delayed(const Duration(milliseconds: 500));
          }
      } else {
          // Bluetooth Printer
          if (!(await _ensurePrinterConnected())) return;
          
          for (int i = 0; i < times; i++) {
              await printer.writeBytes(Uint8List.fromList(bytes));
              if (i < times - 1) await Future.delayed(const Duration(milliseconds: 500));
          }
      }
    } catch (e) {
      debugPrint("Print Receipt Error: $e");
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<List<int>> _generateCustomerReceiptBytes(ep.Generator generator, {bool isDuplicate = false}) async {
    List<int> bytes = [];
    final ep.PosFontType fontType = _printerFontType == 0 ? ep.PosFontType.fontA : ep.PosFontType.fontB;
    final bool isDH = _printerFontType == 2;

    bytes += generator.reset();

    if (_isDemoMode) {
        bytes += generator.text("*** DEMO MODE ***", styles: ep.PosStyles(align: ep.PosAlign.center, bold: true, fontType: fontType));
        bytes += generator.text("TRANSAKSI UJI COBA", styles: ep.PosStyles(align: ep.PosAlign.center, fontType: fontType));
        bytes += generator.feed(1);
    }

    if (!_isRegistered) {
        bytes += generator.text("*** BELUM DIREGRISTRASI ***", styles: ep.PosStyles(align: ep.PosAlign.center, bold: true, fontType: fontType));
        bytes += generator.text("SILAKAN LAKUKAN AKTIVASI", styles: ep.PosStyles(align: ep.PosAlign.center, fontType: fontType));
        bytes += generator.feed(1);
    }

    if (isDuplicate) {
        bytes += generator.text("DUPLIKASI (COPY)", styles: ep.PosStyles(align: ep.PosAlign.center, bold: true, fontType: fontType));
        bytes += generator.feed(1);
    }

    bool logoPrinted = false;
    if (_isLogoEnabled && _businessInfo['logo_path'] != null && _businessInfo['logo_path']!.isNotEmpty) {
        final Uint8List? imgBytes = await PrintHelper.generateImageBytes(_businessInfo['logo_path']!, paperSize: _paperSize);
        if (imgBytes != null) {
            bytes += imgBytes;
            logoPrinted = true;
            bytes += generator.feed(1);
        }
    }

    if (!logoPrinted) {
        bytes += generator.text(_businessInfo['name']!.toUpperCase(), styles: ep.PosStyles(align: ep.PosAlign.center, bold: true, fontType: fontType, height: isDH ? ep.PosTextSize.size2 : ep.PosTextSize.size1));
        bytes += generator.text(_businessInfo['address']!, styles: ep.PosStyles(align: ep.PosAlign.center, fontType: fontType));
        bytes += generator.text(_businessInfo['mobile']!, styles: ep.PosStyles(align: ep.PosAlign.center, fontType: fontType));
    }

    bytes += generator.hr();
    bytes += generator.row([
        ep.PosColumn(text: "No: ${_getInvoiceNumber()}", width: 12, styles: ep.PosStyles(fontType: fontType)),
    ]);
    bytes += generator.row([
        ep.PosColumn(text: "Tgl: ${DateFormat('dd/MM/yy HH:mm').format(DateTime.now())}", width: 12, styles: ep.PosStyles(fontType: fontType)),
    ]);
    bytes += generator.row([
        ep.PosColumn(text: "Plg: ${_selectedCustomer?['name']?.toUpperCase() ?? 'UMUM'}", width: 12, styles: ep.PosStyles(fontType: fontType)),
    ]);

    final waiterName = _selectedWaiter != null 
        ? "${_selectedWaiter!.firstName} ${_selectedWaiter!.lastName ?? ''}".trim() 
        : "-";
    bytes += generator.text("Waiter: ${waiterName.toUpperCase()}", styles: ep.PosStyles(fontType: fontType));
    
    bytes += generator.row([
        ep.PosColumn(text: "Kasir: $_cashierName", width: 6, styles: ep.PosStyles(fontType: fontType)),
        ep.PosColumn(text: "Tipe: ${_getTypeLabel(_posProvider.selectedPriceGroupId)}", width: 6, styles: ep.PosStyles(align: ep.PosAlign.right, fontType: fontType)),
    ]);

    if (_selectedTable != null) {
        bytes += generator.row([
            ep.PosColumn(text: "Meja: ${_selectedTable!.name}", width: 6, styles: ep.PosStyles(fontType: fontType)),
            ep.PosColumn(text: _pax > 0 ? "Pax: $_pax" : "", width: 6, styles: ep.PosStyles(align: ep.PosAlign.right, fontType: fontType)),
        ]);
    }
    bytes += generator.hr();

    for (var item in _cartController.cart) {
        bytes += generator.text(item.product.name.toUpperCase(), styles: ep.PosStyles(fontType: fontType, bold: true));
        
        if (item.selectedModifiers.isNotEmpty) {
            for (var mod in item.selectedModifiers) {
                bytes += generator.row([
                    ep.PosColumn(text: "  + ${mod.name}", width: 8, styles: ep.PosStyles(fontType: fontType)),
                    ep.PosColumn(text: NumberFormat('#,###').format(mod.price * item.qty), width: 4, styles: ep.PosStyles(align: ep.PosAlign.right, fontType: fontType)),
                ]);
            }
        }

        bytes += generator.row([
            ep.PosColumn(text: "  ${item.qty} x ${NumberFormat('#,###').format(item.price)}", width: 8, styles: ep.PosStyles(fontType: fontType)),
            ep.PosColumn(text: NumberFormat('#,###').format(item.price * item.qty), width: 4, styles: ep.PosStyles(align: ep.PosAlign.right, fontType: fontType)),
        ]);

        if (item.itemDiscount > 0) {
            bytes += generator.row([
                ep.PosColumn(text: "   Diskon", width: 8, styles: ep.PosStyles(fontType: fontType)),
                ep.PosColumn(text: "-${NumberFormat('#,###').format(item.itemDiscount)}", width: 4, styles: ep.PosStyles(align: ep.PosAlign.right, fontType: fontType)),
            ]);
        }

        if (item.note.isNotEmpty) {
            bytes += generator.text("  (${item.note})", styles: ep.PosStyles(fontType: fontType));
        }
    }

    bytes += generator.hr();
    bytes += generator.row([
        ep.PosColumn(text: _businessInfo['lbl_subtotal']!, width: 8, styles: ep.PosStyles(fontType: fontType)),
        ep.PosColumn(text: NumberFormat('#,###').format(_cartController.subtotal), width: 4, styles: ep.PosStyles(align: ep.PosAlign.right, fontType: fontType)),
    ]);

    if (_cartController.effectiveDiscount > 0) {
        bytes += generator.row([
            ep.PosColumn(text: _businessInfo['lbl_discount']!, width: 8, styles: ep.PosStyles(fontType: fontType)),
            ep.PosColumn(text: "-${NumberFormat('#,###').format(_cartController.effectiveDiscount)}", width: 4, styles: ep.PosStyles(align: ep.PosAlign.right, fontType: fontType)),
        ]);
    }

    if (_cartController.calculatedTax > 0) {
        bytes += generator.row([
            ep.PosColumn(text: _businessInfo['lbl_tax']!, width: 8, styles: ep.PosStyles(fontType: fontType)),
            ep.PosColumn(text: NumberFormat('#,###').format(_cartController.calculatedTax), width: 4, styles: ep.PosStyles(align: ep.PosAlign.right, fontType: fontType)),
        ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
        ep.PosColumn(text: "TOTAL", width: 6, styles: ep.PosStyles(bold: true, fontType: fontType, height: ep.PosTextSize.size2, width: ep.PosTextSize.size1)),
        ep.PosColumn(text: NumberFormat('#,###').format(_cartController.finalTotal), width: 6, styles: ep.PosStyles(align: ep.PosAlign.right, bold: true, fontType: fontType, height: ep.PosTextSize.size2, width: ep.PosTextSize.size1)),
    ]);
    bytes += generator.hr();

    if (_lastPayments.isNotEmpty) {
        for (var p in _lastPayments) {
            bytes += generator.row([
                ep.PosColumn(text: _getPaymentMethodDisplay(p['method']), width: 8, styles: ep.PosStyles(fontType: fontType)),
                ep.PosColumn(text: NumberFormat('#,###').format(p['amount']), width: 4, styles: ep.PosStyles(align: ep.PosAlign.right, fontType: fontType)),
            ]);
        }
    } else {
        bytes += generator.row([
            ep.PosColumn(text: _getPaymentMethodDisplay(_lastPaymentMethod), width: 8, styles: ep.PosStyles(fontType: fontType)),
            ep.PosColumn(text: NumberFormat('#,###').format(_amountPaid), width: 4, styles: ep.PosStyles(align: ep.PosAlign.right, fontType: fontType)),
        ]);
    }

    if (_changeAmount > 0) {
        bytes += generator.row([
            ep.PosColumn(text: "KEMBALI", width: 8, styles: ep.PosStyles(fontType: fontType)),
            ep.PosColumn(text: NumberFormat('#,###').format(_changeAmount), width: 4, styles: ep.PosStyles(align: ep.PosAlign.right, fontType: fontType)),
        ]);
    }

    bytes += generator.feed(1);
    List<String> footerLines = _businessInfo['footer_text']!.split('\n');
    for (var line in footerLines) {
        if (line.trim().isNotEmpty) {
            bytes += generator.text(line.trim(), styles: ep.PosStyles(align: ep.PosAlign.center, fontType: fontType));
        }
    }

    if (_showAppVersion) {
        bytes += generator.text("${AppConfig.appName} v$_appVersion", styles: ep.PosStyles(align: ep.PosAlign.center, fontType: fontType, width: ep.PosTextSize.size1));
    }

    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  // --- RAW PRINTER HELPERS ---
  Future<void> _printRawText(String text, {int align = 0, bool bold = false, int? size}) async {
    await printer.writeBytes(Uint8List.fromList(PrinterUtils.getAlignBytes(align)));
    await printer.writeBytes(Uint8List.fromList(PrinterUtils.getFontBytes(size ?? _printerFontType, bold: bold)));
    await printer.writeBytes(Uint8List.fromList(PrinterUtils.textToBytes(text)));
    await printer.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
  }

  Future<void> _printRawLeftRight(String left, String right, {bool bold = false}) async {
    final maxChars = PrinterUtils.getMaxChars(_printerFontType);
    await printer.writeBytes(Uint8List.fromList(PrinterUtils.getAlignBytes(0)));
    await printer.writeBytes(Uint8List.fromList(PrinterUtils.getFontBytes(_printerFontType, bold: bold)));
    
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
    
    await printer.writeBytes(Uint8List.fromList(PrinterUtils.textToBytes(line)));
    await printer.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
  }

  Future<void> _printRawSeparator() async {
    final maxChars = PrinterUtils.getMaxChars(_printerFontType);
    await printer.writeBytes(Uint8List.fromList(PrinterUtils.getAlignBytes(1)));
    await printer.writeBytes(Uint8List.fromList(PrinterUtils.getFontBytes(_printerFontType)));
    await printer.writeBytes(Uint8List.fromList(PrinterUtils.textToBytes("-" * maxChars)));
    await printer.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
  }
  
  Future<void> _checkAttendance() async {
      if (!_attendanceRequired) {
          if (mounted && _isBlockedByAttendance) setState(() => _isBlockedByAttendance = false);
          return;
      }
      
      if (_currentUserId == 0) return; // Wait for user load

      final active = await DatabaseHelper.instance.getActiveAttendance(_currentUserId);
      
      if (active == null) {
          if (_isBlockedByAttendance) return; // Already showing dialog
          
          if (mounted) setState(() => _isBlockedByAttendance = true);
          if (!mounted) return;

          await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => WillPopScope(
                  onWillPop: () async => false, // Prevent back button
                  child: Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: EdgeInsets.symmetric(horizontal: 100.sc),
                      child: Container(
                        padding: EdgeInsets.all(32.sc),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.sc),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 30.sc, offset: Offset(0, 10.sc))]
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_clock, size: 60.sc, color: MetroColors.error),
                            SizedBox(height: 24.sc),
                            Text(
                                "AKSES DITUTUP", 
                                style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: MetroColors.error, letterSpacing: 2.sc)
                            ),
                            SizedBox(height: 16.sc),
                            Text(
                                "ANDA BELUM MELAKUKAN PRESENSI (CLOCK-IN).\nSILAKAN ABSEN TERLEBIH DAHULU UNTUK MEMULAI SHIFT.", 
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.black54, height: 1.5.sc)
                            ),
                            SizedBox(height: 40.sc),
                            SizedBox(
                              width: double.infinity,
                              height: 56.sc,
                              child: MetroButton(
                                label: 'BUKA MENU ABSENSI',
                                icon: Icons.fingerprint,
                                onPressed: () async {
                                  await showDialog(
                                    context: context, 
                                    builder: (_) => AttendanceDialog(userId: _currentUserId, username: _cashierName)
                                  );
                                  
                                  // Re-check after dialog closes
                                  final check = await DatabaseHelper.instance.getActiveAttendance(_currentUserId);
                                  if (check != null && mounted) {
                                      Navigator.pop(ctx);
                                      setState(() => _isBlockedByAttendance = false);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selamat Bertugas!')));
                                  }
                                },
                                color: MetroColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                                onTap: () => showDialog(context: context, builder: (_) => const PrinterSettingsDialog()),
                                child: const Text(
                                    "pastikan printer siap",
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blueGrey,
                                        decoration: TextDecoration.underline,
                                        fontStyle: FontStyle.italic
                                    ),
                                ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  (route) => false,
                                );
                              },
                              child: const Text('KELUAR / GANTI AKUN', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            )
                          ],
                        ),
                      ),
                  ),
              )
          );
      }
  }
  
  void _startClock() {
     _timer = Timer.periodic(const Duration(seconds: 1), (t) {
         if (mounted) setState(() => _now = DateTime.now());
         if (t.tick % 60 == 0) _checkAttendance();
     });
  }
  
  void _startMarquees() {
    _marqueeTimer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (_animMenuEnabled && mounted) {
        if (_headerScrollController.hasClients) {
          final max = _headerScrollController.position.maxScrollExtent;
          if (max > 0) {
            final target = _headerScrollController.offset > 0 ? 0.0 : max;
            _headerScrollController.animateTo(target, duration: const Duration(milliseconds: 3000), curve: Curves.easeInOut);
          }
        }
        if (_actionsScrollController.hasClients) {
          final max = _actionsScrollController.position.maxScrollExtent;
          if (max > 0) {
             final target = _actionsScrollController.offset > 0 ? 0.0 : max;
             _actionsScrollController.animateTo(target, duration: const Duration(milliseconds: 4000), curve: Curves.easeInOut);
          }
        }
      }
    });
  }
  
  void _updateSecondaryDisplay() {
     // Trigger presentation display update
  }

  String _getPaymentMethodDisplay(String method) {
      if (_paymentMethods.isEmpty) return method.toUpperCase();
      final m = _paymentMethods.firstWhere((e) => e['name'] == method, orElse: () => {});
      if (m.isNotEmpty) {
          return m['label']?.toString().toUpperCase() ?? method.toUpperCase();
      }
      
      // Fallback for ERP codes
      if (method == 'custom_pay_1') return 'OVO';
      if (method == 'custom_pay_2') return 'GOPAY';
      if (method == 'custom_pay_3') return 'QRIS';
      if (method == 'custom_pay_4') return 'SHOPEEPAY';
      if (method == 'custom_pay_5') return 'DANA';
      if (method == 'custom_pay_7') return 'BANK/VA';

      return method.toUpperCase();
  }
  Future<bool> _ensureCustomerIsSelected() async {
    final isDefault = _selectedCustomer == null || 
                     (_selectedCustomer?['name'] ?? '').toLowerCase() == 'pelanggan umum' ||
                     (_selectedCustomer?['name'] ?? '').toLowerCase() == 'umum';

    if (!isDefault) return true;
    
    // If setting disabled, don't ask, just proceed as "Umum"
    if (!_askCustomerNameEnabled) return true;

    String? nameNote;
    bool result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: MetroColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          width: 650.sc,
          padding: EdgeInsets.all(20.sc),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                   Icon(Icons.person_add, color: MetroColors.primary, size: 20.sc),
                   SizedBox(width: 8.sc),
                   Text("IDENTITAS PEMBELI", style: TextStyle(fontWeight: FontWeight.w900, color: MetroColors.primary, fontSize: 13.sp, letterSpacing: 1.sc)),
                   const Spacer(),
                   IconButton(icon: Icon(Icons.close, size: 20.sc, color: Colors.black26), onPressed: () => Navigator.pop(ctx, false))
                ],
              ),
              const Divider(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT SIDE: INPUTS
                  Expanded(
                    flex: 6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MetroButton(
                            label: "PILIH DARI KONTAK",
                            icon: Icons.person_search,
                            color: MetroColors.secondary,
                            isSecondary: true,
                            onPressed: () {
                                Navigator.pop(ctx, false);
                                _showCustomerSelector();
                            }
                        ),
                        SizedBox(height: 16.sc),
                        Text("NAMA PEMBELI (OPSIONAL):", style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.sc)),
                        SizedBox(height: 6.sc),
                        SizedBox(
                          height: 48.sc,
                          child: TextField(
                            autofocus: true,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(borderRadius: BorderRadius.zero), 
                              hintText: "KETIK NAMA DI SINI...",
                              contentPadding: EdgeInsets.symmetric(horizontal: 12.sc, vertical: 0)
                            ),
                            onChanged: (v) => nameNote = v,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 20.sc),
                  // RIGHT SIDE: ACTIONS
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MetroButton(
                          label: "LANJUT",
                          icon: Icons.check,
                          color: MetroColors.primary,
                          isSecondary: false, // Make this one stand out
                          onPressed: () {
                            // If name is empty, set it to "UMUM" automatically
                            String finalName = "UMUM";
                            if (nameNote != null && nameNote!.trim().isNotEmpty) {
                                finalName = nameNote!.trim();
                            }
                            
                            setState(() => _selectedCustomer = {'id': null, 'name': finalName});
                            Navigator.pop(ctx, true);
                          },
                        ),
                        const SizedBox(height: 10),
                        MetroButton(
                          label: "BATAL",
                          color: Colors.grey.shade200,
                          textColor: Colors.black54,
                          onPressed: () => Navigator.pop(ctx, false),
                          isSecondary: true,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      )
    ) ?? false;

    return result;
  }

  Future<void> _printLabelStickers() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool labelEnabled = prefs.getBool('label_printer_enabled') ?? false;
      final String? labelAddr = prefs.getString('label_printer_address');
      
      if (!labelEnabled || labelAddr == null || labelAddr.isEmpty) return;

      final itemsWithLabel = _cartController.cart.where((item) => item.product.needsLabel == 1).toList();
      if (itemsWithLabel.isEmpty) return;

      try {
        // 1. Disconnect from Receipt Printer
        if (await printer.isConnected ?? false) {
            await printer.disconnect();
            await Future.delayed(const Duration(milliseconds: 800));
        }

        // 2. Print Labels using Unified utility
        await LabelPrinterUtil.printTransactionLabels(
            labelAddr, 
            itemsWithLabel, 
            _businessInfo['name'] ?? 'DONAPOS', 
            _cashierName
        );
        
        // 3. Disconnect from Label Printer
        if (await printer.isConnected ?? false) {
            await printer.disconnect();
            await Future.delayed(const Duration(milliseconds: 800));
        }
        
        // 4. Re-connect to Main Receipt Printer
        if (_selectedDevice != null) {
            try {
               await printer.connect(_selectedDevice!);
               if (mounted) setState(() => _connected = true);
            } catch(e) {
               print("Reconnect error: $e");
            }
        }
      } catch (e) {
        debugPrint("Print Label Error: $e");
        try {
           if (_selectedDevice != null) await printer.connect(_selectedDevice!);
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }
}
