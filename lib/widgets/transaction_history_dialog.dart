import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/screens/pos/components/pos_receipt_dialog.dart';
import 'package:donapos_mobile/utils_printer.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:donapos_mobile/widgets/confirm_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:donapos_mobile/utils_print.dart';
import 'package:donapos_mobile/config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:donapos_mobile/utils_scaler.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';

class TransactionHistoryDialog extends StatefulWidget {
  final Map<String, String> businessInfo;
  final String cashierName;

  const TransactionHistoryDialog({
    super.key,
    required this.businessInfo,
    required this.cashierName,
  });

  @override
  State<TransactionHistoryDialog> createState() => _TransactionHistoryDialogState();
}

class _TransactionHistoryDialogState extends State<TransactionHistoryDialog> {
  bool _isLoading = true;
  bool _isPrinting = false;
  List<Map<String, dynamic>> _transactions = [];
  final NumberFormat _currency = NumberFormat.simpleCurrency(name: 'IDR', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    debugPrint("[TransactionHistoryDialog] initState called");
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final txs = await DatabaseHelper.instance.getTodayTransactions();
      if (mounted) {
        setState(() {
          _transactions = txs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading transactions: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        showAppModal(context, title: 'ERROR', message: 'Gagal memuat riwayat transaksi: $e', isError: true);
      }
    }
  }

  Future<void> _handleRefund(Map<String, dynamic> tx) async {
       bool confirm = await showAppConfirm(
           context, 
           title: 'REFUND TRANSAKSI?',
           message: 'APAKAH ANDA YAKIN INGIN MELAKUKAN REFUND UNTUK TRANSAKSI INV-${tx['id']}?\n\nTINDAKAN INI TIDAK DAPAT DIBATALKAN.',
           confirmLabel: 'YA, REFUND'
       );
       
       if (!confirm) return;
       
       // OTP Check using the specialized 8-digit refund OTP
       checkRefundOtp(context, () async {
           showPowerfulLoader(context, message: 'MEMPROSES REFUND...');
           try {
               await DatabaseHelper.instance.refundTransaction(tx['id'] as int);
               
               if (mounted) {
                   Navigator.pop(context); // Close loader
                   showAppModal(context, title: 'BERHASIL', message: 'TRANSAKSI INV-${tx['id']} TELAH DI-REFUND.');
                   _loadTransactions(); // Refresh list
               }
           } catch (e) {
               if (mounted) {
                   Navigator.pop(context);
                   showAppModal(context, title: 'GAGAL', message: 'ERROR: $e', isError: true);
               }
           }
       });
  }

  Future<void> _showDetails(Map<String, dynamic> tx) async {
       showPowerfulLoader(context, message: 'MEMUAT DETAIL...');
       try {
          // Re-use logic to show the detailed receipt dialog
          final db = await DatabaseHelper.instance.database;
          final itemsRes = await db.rawQuery('''
            SELECT ti.*, p.name as product_name, p.sku as product_sku
            FROM transaction_items ti
            JOIN products p ON ti.product_id = p.id
            WHERE ti.transaction_id = ?
          ''', [tx['id']]);

          List<CartItem> cart = itemsRes.map((item) {
            final product = Product(
              id: item['product_id'] as int,
              name: item['product_name'] as String,
              sku: item['product_sku'] as String,
              price: (item['price'] as num).toDouble(),
              categoryId: 0, 
              imageUrl: ''
            );
            
            return CartItem(
              product: product,
              qty: (item['qty'] as num).toInt(),
              price: (item['price'] as num).toDouble(),
              note: (item['note'] ?? '').toString(),
              selectedModifiers: [], 
              itemDiscount: item['discount'] != null ? (item['discount'] as num).toDouble() : 0.0,
            );
          }).toList();

          if (!mounted) return;
          Navigator.pop(context); // Close loader

          showDialog(
            context: context,
            builder: (_) => PosReceiptDialog(
              cart: cart,
              businessInfo: widget.businessInfo,
              cashierName: tx['cashier_name'] ?? widget.cashierName,
              subtotal: (tx['subtotal'] as num).toDouble(),
              calculatedDiscount: (tx['discount'] as num).toDouble(),
              calculatedTax: (tx['tax'] as num).toDouble(),
              finalTotal: (tx['total'] as num).toDouble(),
              amountPaid: (tx['amount_paid'] as num).toDouble(),
              changeAmount: (tx['change_amount'] as num).toDouble(),
              invoiceNumber: "INV-${tx['id']}", 
              saleTypeLabel: tx['sale_type'] ?? 'General',
              paymentMethod: tx['payment_method_label'] ?? tx['payment_method'],
              selectedCustomerName: tx['customer_name'],
              isLogoEnabled: true,
              showAppVersion: false,
              appVersion: '',
              allowDuplicate: true,
              pax: tx['pax'] ?? 0,
              onPrint: ({int times = 1, bool isDuplicate = false}) async {
                  await _reprintTransaction(tx, cart, isDuplicate);
              },
              onRefund: tx['is_refunded'] == 1 ? null : () => _handleRefund(tx),
              onFinalize: () {},
              isPreview: true,
            )
          );
       } catch (e) {
          if (mounted) {
              Navigator.pop(context); // Close loader
              showAppModal(context, title: 'GAGAL', message: 'Gagal memuat detail: $e', isError: true);
          }
       }
  }

  Future<void> _reprintTransaction(Map<String, dynamic> tx, List<CartItem> cart, bool isDuplicate) async {
      if (_isPrinting) return;
      setState(() => _isPrinting = true);

      try {
          final printer = BlueThermalPrinter.instance;
          if (!(await printer.isConnected ?? false)) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printer tidak terhubung')));
              setState(() => _isPrinting = false);
              return;
          }

      final prefs = await SharedPreferences.getInstance();
      final int fontType = prefs.getInt('printer_font_type') ?? 1;
      final bool isLogoEnabled = prefs.getBool('is_logo_enabled') ?? true;
      final int paperSize = prefs.getInt('printer_paper_size') ?? 58;
      final bool showAppVersion = prefs.getBool('show_app_version') ?? true;
      final pkg = await PackageInfo.fromPlatform();
      final String appVersion = "${pkg.version}+${pkg.buildNumber}";

      // Reconstruct items if specifically needed or just use what we have
      List<CartItem> itemsToPrint = cart;
      if (itemsToPrint.isEmpty) {
          final db = await DatabaseHelper.instance.database;
          final itemsRes = await db.rawQuery('''
            SELECT ti.*, p.name as product_name, p.sku as product_sku
            FROM transaction_items ti
            JOIN products p ON ti.product_id = p.id
            WHERE ti.transaction_id = ?
          ''', [tx['id']]);

          itemsToPrint = itemsRes.map((item) {
            final product = Product(
              id: item['product_id'] as int,
              name: item['product_name'] as String,
              sku: item['product_sku'] as String,
              price: (item['price'] as num).toDouble(),
              categoryId: 0, 
              imageUrl: ''
            );
            
            return CartItem(
              product: product,
              qty: (item['qty'] as num).toInt(),
              price: (item['price'] as num).toDouble(),
              note: (item['note'] ?? '').toString(),
              selectedModifiers: [], 
              itemDiscount: item['discount'] != null ? (item['discount'] as num).toDouble() : 0.0,
            );
          }).toList();
      }

      // Start printing
      await printer.writeBytes(Uint8List.fromList([0x1B, 0x40])); // Reset

      // Header & Logo
      if (isLogoEnabled && widget.businessInfo['logo_path'] != null && widget.businessInfo['logo_path']!.isNotEmpty) {
          final Uint8List? imgBytes = await PrintHelper.generateImageBytes(widget.businessInfo['logo_path']!, paperSize: paperSize);
          if (imgBytes != null) {
              await printer.writeBytes(imgBytes);
              await Future.delayed(const Duration(milliseconds: 1000));
          }
      }

      if (!isLogoEnabled) {
          await _printRawText(widget.businessInfo['name']?.toUpperCase() ?? 'DONAPOS', align: 1, bold: true, fontType: fontType);
          await _printRawText(widget.businessInfo['address'] ?? '', align: 1, fontType: fontType);
          await _printRawText(widget.businessInfo['mobile'] ?? '', align: 1, fontType: fontType);
      }
      await _printRawSeparator(fontType: fontType);

      // Info
      String dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(tx['created_at']));
      await _printRawLeftRight("No: INV-${tx['id']}", "", fontType: fontType);
      await _printRawLeftRight("Tgl: $dateStr", "", fontType: fontType);
      
      String customerName = tx['customer_name']?.toString().toUpperCase() ?? 'UMUM';
      await _printRawLeftRight("Plg: $customerName", "", fontType: fontType);

      // USER REQUEST: DUPLIKASI center below customer name
      if (isDuplicate) {
          await _printRawText("DUPLIKASI (COPY)", align: 1, bold: true, fontType: fontType);
      }

      await _printRawLeftRight("Kasir: ${tx['cashier_name'] ?? widget.cashierName}", "Tipe: ${tx['sale_type']?.toString().toUpperCase() ?? 'GENERAL'}", fontType: fontType);
      
      if (tx['pax'] != null && tx['pax'] > 0) {
           await _printRawLeftRight("Meja: ${tx['table_name'] ?? '-'} (${tx['pax']} Org)", "", fontType: fontType);
      }

      await _printRawSeparator(fontType: fontType);

      // Items
      int totalQty = 0;
      for (var item in itemsToPrint) {
          totalQty += item.qty;
          await _printRawLeftRight(item.product.name.toUpperCase(), "", fontType: fontType);
          await _printRawLeftRight(
              "  ${item.qty} x ${NumberFormat('#,###').format(item.price)}", 
              NumberFormat('#,###').format(item.price * item.qty),
              fontType: fontType
          );
          if (item.itemDiscount > 0) {
              await _printRawLeftRight("   Diskon", "-${NumberFormat('#,###').format(item.itemDiscount)}", fontType: fontType);
          }
          if (item.note.isNotEmpty) {
              await _printRawText("  (${item.note})", fontType: fontType);
          }
      }

      await _printRawSeparator(fontType: fontType);
      
      // Totals
      await _printRawLeftRight("SUBTOTAL", NumberFormat('#,###').format(tx['subtotal']), fontType: fontType);
      if (tx['discount'] != null && tx['discount'] > 0) {
          await _printRawLeftRight("DISKON", "-${NumberFormat('#,###').format(tx['discount'])}", fontType: fontType);
      }
      if (tx['tax'] != null && tx['tax'] > 0) {
          await _printRawLeftRight("PAJAK", NumberFormat('#,###').format(tx['tax']), fontType: fontType);
      }
      
      await _printRawSeparator(fontType: fontType);
      await _printRawLeftRight("TOTAL PRODUK ($totalQty)", NumberFormat('#,###').format(tx['total']), bold: true, fontType: fontType);
      await _printRawSeparator(fontType: fontType);

      // Payments
      String pmText = tx['payment_method']?.toString().toUpperCase() ?? 'CASH';
      if (pmText == 'CASH' || pmText == 'TUNAI') {
          await _printRawLeftRight("TUNAI", NumberFormat('#,###').format(tx['amount_paid']), fontType: fontType);
          await _printRawLeftRight("KEMBALI", NumberFormat('#,###').format(tx['change_amount']), fontType: fontType);
      } else {
          await _printRawLeftRight("BAYAR", pmText, fontType: fontType);
      }

      // Footer
      String footerText = widget.businessInfo['footer_text'] ?? 'Terima Kasih';
      for (var line in footerText.split('\n')) {
          if (line.trim().isNotEmpty) await _printRawText(line.trim(), align: 1, fontType: fontType);
      }
      
      if (showAppVersion) {
          await _printRawText("${AppConfig.appName} v$appVersion", align: 1, fontType: fontType);
      }
      
      await printer.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
      await printer.paperCut();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mencetak Salinan Struk...')));
      } catch (e) {
          print("[Reprint] Error: $e");
      } finally {
          if (mounted) setState(() => _isPrinting = false);
      }
  }

  // --- RAW PRINTER HELPERS ---
  Future<void> _printRawText(String text, {int align = 0, bool bold = false, int fontType = 2}) async {
      final printer = BlueThermalPrinter.instance;
      await printer.writeBytes(Uint8List.fromList(PrinterUtils.getAlignBytes(align)));
      await printer.writeBytes(Uint8List.fromList(PrinterUtils.getFontBytes(fontType, bold: bold)));
      await printer.writeBytes(Uint8List.fromList(PrinterUtils.textToBytes(text)));
      await printer.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
  }

  Future<void> _printRawLeftRight(String left, String right, {bool bold = false, int fontType = 2}) async {
      final printer = BlueThermalPrinter.instance;
      final maxChars = PrinterUtils.getMaxChars(fontType);
      await printer.writeBytes(Uint8List.fromList(PrinterUtils.getAlignBytes(0)));
      await printer.writeBytes(Uint8List.fromList(PrinterUtils.getFontBytes(fontType, bold: bold)));
      
      int contentLen = left.length + right.length;
      String line;
      if (contentLen >= maxChars) {
         int available = maxChars - right.length - 1;
         if (available < 0) available = 0;
         line = "${left.substring(0, available)} $right";
      } else {
         int spaces = maxChars - left.length - right.length;
         line = left + (" " * spaces) + right;
      }
      await printer.writeBytes(Uint8List.fromList(PrinterUtils.textToBytes(line)));
      await printer.writeBytes(Uint8List.fromList(PrinterUtils.getNewLineBytes()));
  }

  Future<void> _printRawSeparator({int fontType = 2}) async {
      final maxChars = PrinterUtils.getMaxChars(fontType);
      await _printRawText("-" * maxChars, fontType: fontType);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[TransactionHistoryDialog] build called - txCount: ${_transactions.length}");
    
    return Dialog(
       backgroundColor: Colors.transparent,
       insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
       child: Container(
          width: 900, // Fixed width matching Expense pattern
          height: 600, // Fixed height for consistency
          decoration: BoxDecoration(
              color: MetroColors.surface,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: MetroColors.primary, width: 2),
          ),
          child: Column(
              children: [
                  // HEADER (Following Expense Style)
                  Container(
                      padding: const EdgeInsets.all(20),
                      color: MetroColors.primary,
                      child: Row(
                          children: [
                              const Icon(Icons.history, color: Colors.white, size: 24),
                              const SizedBox(width: 12),
                              const Text(
                                  'RIWAYAT TRANSAKSI HARI INI', 
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)
                              ),
                              const Spacer(),
                              IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () => Navigator.pop(context),
                              )
                          ],
                      ),
                  ),
                  
                  // CONTENT
                  Expanded(
                      child: _isLoading 
                        ? const Center(child: DonaposLoader(size: 80))
                        : _transactions.isEmpty 
                            ? const Center(child: Text('BELUM ADA TRANSAKSI HARI INI', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
                            : ListView.separated(
                                padding: const EdgeInsets.all(24),
                                itemCount: _transactions.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (ctx, i) {
                                  final tx = _transactions[i];
                                  final date = DateTime.parse(tx['created_at']);
                                  final bool isRefunded = tx['is_refunded'] == 1;
                                  
                                  return Container(
                                      decoration: BoxDecoration(
                                          color: isRefunded ? Colors.red.withOpacity(0.05) : Colors.white,
                                          border: Border(
                                              left: BorderSide(color: isRefunded ? Colors.red : MetroColors.primary, width: isRefunded ? 8 : 1),
                                              top: const BorderSide(color: Colors.black12),
                                              right: const BorderSide(color: Colors.black12),
                                              bottom: const BorderSide(color: Colors.black12),
                                          ),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                      ),
                                      child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                              onTap: () => _showDetails(tx),
                                              child: Padding(
                                                  padding: const EdgeInsets.all(16),
                                                  child: Row(
                                                      children: [
                                                          Expanded(
                                                              flex: 3,
                                                              child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                      Text("INV-${tx['id']}  •  ${DateFormat('HH:mm').format(date)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                                                      const SizedBox(height: 4),
                                                                      Text("${tx['customer_name'] ?? 'Umum'} • ${tx['sale_type']?.toString().toUpperCase() ?? 'DINE IN'}", style: const TextStyle(fontSize: 11, color: Colors.black45)),
                                                                  ],
                                                              ),
                                                          ),
                                                          Expanded(
                                                              flex: 2,
                                                              child: Text((tx['payment_method_label'] ?? tx['payment_method']).toString().toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                                          ),
                                                          Expanded(
                                                              flex: 2,
                                                              child: Text(_currency.format(tx['total']), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isRefunded ? Colors.red : MetroColors.retailPrimary)),
                                                          ),
                                                          const SizedBox(width: 16),
                                                          if (!isRefunded)
                                                            IconButton(
                                                              icon: const Icon(Icons.print, color: MetroColors.primary),
                                                              onPressed: () => _reprintTransaction(tx, [], true), 
                                                            )
                                                      ],
                                                  ),
                                              ),
                                          ),
                                      ),
                                  );
                                },
                            ),
                  ),
                  
                  // FOOTER
                  Container(
                      padding: const EdgeInsets.all(24),
                      color: Colors.black.withOpacity(0.03),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                              Text('MENAMPILKAN ${_transactions.length} TRANSAKSI', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black38)),
                              SizedBox(
                                width: 150,
                                child: MetroButton(
                                    label: 'TUTUP',
                                    onPressed: () => Navigator.pop(context),
                                    color: Colors.grey,
                                )
                              )
                          ],
                      ),
                  )
              ],
          ),
       ),
    );
  }
}
