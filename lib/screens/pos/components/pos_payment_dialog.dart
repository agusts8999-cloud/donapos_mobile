import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:donapos_mobile/language_provider.dart';
import 'package:donapos_mobile/utils_scaler.dart';
import 'package:donapos_mobile/controllers/pos_cart_controller.dart';
import 'package:donapos_mobile/models.dart';

class PosPaymentDialog extends StatefulWidget {
  final double finalTotal;
  final List<CartItem> cartItems;
  final Function(List<Map<String, dynamic>> payments, double totalPaid, double change) onPaid;

  const PosPaymentDialog({
    super.key,
    required this.finalTotal,
    required this.cartItems,
    required this.onPaid,
  });

  @override
  State<PosPaymentDialog> createState() => _PosPaymentDialogState();
}

class _PosPaymentDialogState extends State<PosPaymentDialog> {
  String _inputStr = "";
  double payAmount = 0;
  double change = 0;
  
  String selectedPaymentMethod = 'cash';
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _allMethodsFetched = false;
  SharedPreferences? _prefs;
  List<double> _quickCashAmounts = [20000, 50000, 100000];
  Map<String, String?> _pmImages = {};

  int _activeIndex = -1; // -1 means we are creating a NEW payment row
  List<Map<String, dynamic>> _addedPayments = [];
  
  // Track unchecked items by index (preserves default "all checked")
  final Set<int> _uncheckedIndices = {};
  
  // Track items that are already "paid" by previous split payments
  final Set<int> _paidIndices = {};

  final ScrollController _methodScrollController = ScrollController();

  double get totalAddedPayments => _addedPayments.fold(0, (sum, p) => sum + (p['amount'] as double));
  double get remainingBalance => widget.finalTotal - totalAddedPayments;
  
  double get selectedTotal {
    double grossSub = 0;
    for (var item in widget.cartItems) grossSub += item.total;
    if (grossSub <= 0) return 0;
    double ratio = widget.finalTotal / grossSub;
    double sum = 0;
    for (int i = 0; i < widget.cartItems.length; i++) {
        if (!_uncheckedIndices.contains(i) && !_paidIndices.contains(i)) {
            sum += widget.cartItems[i].total;
        }
    }
    return sum * ratio;
  }

  double get unselectedTotal {
    double grossSub = 0;
    for (var item in widget.cartItems) grossSub += item.total;
    if (grossSub <= 0) return 0;
    double ratio = widget.finalTotal / grossSub;
    double sum = 0;
    for (int i = 0; i < widget.cartItems.length; i++) {
        if (_uncheckedIndices.contains(i) && !_paidIndices.contains(i)) {
            sum += widget.cartItems[i].total;
        }
    }
    return sum * ratio;
  }

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  void _loadPaymentMethods() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final methods = await db.query('payment_methods', where: 'is_active = 1', orderBy: 'id ASC');
      _prefs = await SharedPreferences.getInstance();
      await _prefs!.reload();
      if (mounted) {
        setState(() {
          _allMethodsFetched = true;
          _paymentMethods = methods;
          for (var pm in _paymentMethods) {
              String name = pm['name'];
              _pmImages[name] = _prefs!.getString('pm_image_$name');
          }
          
          if (_paymentMethods.isNotEmpty && !_paymentMethods.any((m) => m['name'] == 'cash')) {
             selectedPaymentMethod = _paymentMethods.first['name'];
          }

          // Load Quick Cash Settings
          List<String>? qc = _prefs!.getStringList('quick_cash_denominations');
          if (qc != null && qc.isNotEmpty) {
              _quickCashAmounts = qc.map((e) => double.tryParse(e) ?? 0).where((d) => d > 0).toList();
          }

          // Initial selection: Select all (except those we might mark as paid later, but initially none)
          // Default input is the full total initially
          _inputStr = widget.finalTotal.round().toString();
          _updateCalculations();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _allMethodsFetched = true);
    }
  }

  String _getPMDisplayLabel(Map<String, dynamic> method) {
      String name = method['name'];
      String? custom = _prefs?.getString('pm_label_$name');
      if (custom != null && custom.isNotEmpty) return custom.toUpperCase();
      return method['label'].toString().toUpperCase();
  }

  String _getLabelByName(String name) {
      final m = _paymentMethods.firstWhere((e) => e['name'] == name, orElse: () => {'name': name, 'label': name});
      return _getPMDisplayLabel(m);
  }

  void _updateCalculations() {
    double entered = double.tryParse(_inputStr) ?? 0;
    
    // ENFORCE EXACT AMOUNT FOR NON-CASH (OVO, etc)
    if (!isCash && entered != selectedTotal && selectedTotal > 0) {
        entered = selectedTotal;
        _inputStr = entered.round().toString();
    }

    if (_activeIndex != -1 && _activeIndex < _addedPayments.length) {
        _addedPayments[_activeIndex]['amount'] = entered;
    }

    setState(() {
        payAmount = entered;
        double currentTotalPaid = _addedPayments.fold(0.0, (sum, p) => sum + (p['amount'] as double));
        change = currentTotalPaid - widget.finalTotal;
    });
  }

  bool get isCash {
      // Assuming 'cash' is the internal name. Adjust if different.
      return selectedPaymentMethod.toLowerCase() == 'cash' || selectedPaymentMethod.toLowerCase() == 'tunai';
  }

  void _onNumpadTap(String value) {
    if (!isCash) return; // Disable numpad for non-cash

    GlobalSettings.playClick();
    HapticFeedback.lightImpact();
    if (value == 'C') {
      _inputStr = "";
    } else if (value == 'BACK') {
      if (_inputStr.isNotEmpty) {
        _inputStr = _inputStr.substring(0, _inputStr.length - 1);
      }
    } else if (value == '00') {
      if (_inputStr.isNotEmpty && _inputStr != "0") _inputStr += "00";
    } else {
      if (_inputStr == "0") _inputStr = "";
      _inputStr += value;
    }
    _updateCalculations();
  }
  
  void _onZero() {
      if (!isCash) return; // Disable zero button for non-cash
      GlobalSettings.playClick();
      setState(() {
          _inputStr = "0"; 
          _updateCalculations();
      });
  }

  void _onQuickCash(double amount, String label) {
      if (!isCash) return; // Disable quick cash for non-cash
      GlobalSettings.playClick();
      HapticFeedback.mediumImpact();
      if (label == 'UANG PAS') {
          double target = remainingBalance > 0 ? remainingBalance : 0;
          _inputStr = target.round().toString();
      } else {
          // Smart Cumulative Logic
          double currentInput = double.tryParse(_inputStr) ?? 0;
          
          // If current input exactly matches the suggested/default total (selected items or remaining balance),
          // we assume the user is starting fresh entry -> Replace.
          // Otherwise -> Add.
          // Note: selectedTotal is dynamic based on checkboxes.
          
          double defaultTarget = selectedTotal > 0 ? selectedTotal : (remainingBalance > 0 ? remainingBalance : 0);
          
          if ((currentInput - defaultTarget).abs() < 100) {
              // Current input is effectively the default suggested amount -> Replace it
              _inputStr = amount.round().toString();
          } else {
              // User has already modified input -> Accumulate
              _inputStr = (currentInput + amount).round().toString();
          }
      }
      _updateCalculations();
  }
  
  void _addPayment() {
      // Enforce full payment for non-cash
      if (!isCash && selectedTotal > 0) {
          _inputStr = selectedTotal.round().toString();
      }

      double amt = double.tryParse(_inputStr) ?? 0;
      if (amt <= 0) return;
      
      List<int> paymentIndices = [];
      
      setState(() {
          
          // Logic: Mark items as paid.
          // If Cash: only if amt >= selectedTotal (approx).
          // If Non-Cash: Always mark paid if matched (which it should be forcibly).
          bool shouldMarkPaid = false;
          
          if (isCash) {
              if ((amt - selectedTotal).abs() < 500 || amt > selectedTotal) {
                   shouldMarkPaid = true;
              }
          } else {
              // Non-cash always pays exact match of selected items
              shouldMarkPaid = true;
          }

          if (shouldMarkPaid) { 
             for (int i = 0; i < widget.cartItems.length; i++) {
                 if (!_uncheckedIndices.contains(i) && !_paidIndices.contains(i)) {
                     _paidIndices.add(i);
                     paymentIndices.add(i);
                 }
             }
          }
          
          _addedPayments.add({
              'method': selectedPaymentMethod,
              'amount': amt,
              'original_input': amt,
              'note': 'Split Payment',
              'paid_indices': paymentIndices
          });
          
          // Reset for next entry
          _activeIndex = -1;
          // Clear unchecked indices so ALL remaining items are selected by default for next payment entry
          _uncheckedIndices.clear();
          
          // Auto-suggest next amount (Remaining Balance)
          double rem = widget.finalTotal - _addedPayments.fold(0.0, (s, p) => s + (p['amount'] as double));
          if (rem < 0) rem = 0;
          
          _inputStr = rem.round().toString();
          if (_inputStr == "0") _inputStr = "";
          
          // If next method is non-cash (kept selection), ensure it matches remaining selected total (which is now 0?)
          // Usually after split payment, we start fresh selection.
          // But `selectedTotal` relies on `_paidIndices`. Since we added `_paidIndices`, `selectedTotal` for remaining items is now partial?
          // Actually if we paid ALL selected items, `selectedTotal` will be 0 for the remaining items (unless user selects new ones).
          // So resetting `_inputStr` to `rem` is fine for now, user will select next items.
          
          _updateCalculations();
      });
  }
  
  void _toggleItemCheck(int index) {
      if (_paidIndices.contains(index)) return; // Can't toggle paid items

      setState(() {
          if (_uncheckedIndices.contains(index)) {
              _uncheckedIndices.remove(index);
          } else {
              _uncheckedIndices.add(index);
          }
          // Update input string to match selected TOTAL
          _inputStr = selectedTotal.round().toString();
          _updateCalculations();
      });
  }

  void _onFinalize() {
      double totalCovered = _addedPayments.fold(0, (sum, p) => sum + (p['amount'] as double));
      
      if (_addedPayments.isEmpty && totalCovered == 0) {
          double inputAmt = double.tryParse(_inputStr) ?? 0;
          
          // Final safety check for non-cash single payment: Nominal cannot exceed Total
          if (!isCash && inputAmt > widget.finalTotal) {
              inputAmt = widget.finalTotal;
          }

           if (inputAmt > 0) {
               _addedPayments.add({
                  'method': selectedPaymentMethod,
                  'amount': inputAmt,
                  'original_input': inputAmt
               });
               totalCovered = inputAmt;
           }
      }

      if (totalCovered < widget.finalTotal) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('TOTAL PEMBAYARAN BELUM MENCUKUPI!'), backgroundColor: Colors.red)
          );
          return;
      }
      
      double totalTendered = totalCovered;
      double finalChange = totalTendered - widget.finalTotal;
      if (finalChange < 0) finalChange = 0;

      widget.onPaid(_addedPayments, totalTendered, finalChange);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(name: 'IDR', decimalDigits: 0);
    bool completed = remainingBalance <= 0;

    return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(8.sc),
        child: Container(
            width: double.infinity,
            height: double.infinity,
            constraints: BoxConstraints(
                maxWidth: 1200.sc, 
                maxHeight: MediaQuery.of(context).size.height * 0.9 // Be flexible with height
            ),
            decoration: BoxDecoration(
                color: MetroColors.background,
                boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 20.sc)],
                borderRadius: BorderRadius.circular(4.sc)
            ),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    // --- COLUMN 1: KERANJANG BELANJA ---
                    Expanded(
                        flex: 3,
                        child: Container(
                            color: Colors.white,
                            padding: EdgeInsets.all(12.sc),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text("KERANJANG BELANJA", style: TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 14.sp, letterSpacing: 1.sc)),
                                    SizedBox(height: 8.sc),
                                    Expanded(
                                        child: Container(
                                            decoration: BoxDecoration(
                                                color: Colors.grey[50], 
                                                border: Border.all(color: Colors.black.withOpacity(0.05), width: 1.sc),
                                                borderRadius: BorderRadius.circular(4.sc)
                                            ),
                                            child: ListView.separated(
                                                itemCount: widget.cartItems.length,
                                                separatorBuilder: (_, __) => const Divider(height: 1),
                                                itemBuilder: (ctx, i) {
                                                    final item = widget.cartItems[i];
                                                    final isPaid = _paidIndices.contains(i);
                                                    final isChecked = !_uncheckedIndices.contains(i) && !isPaid;
                                                    return Opacity(
                                                        opacity: isPaid ? 0.4 : 1.0,
                                                        child: CheckboxListTile(
                                                            value: isPaid || isChecked,
                                                            activeColor: isPaid ? Colors.grey : MetroColors.primary,
                                                            dense: true,
                                                            onChanged: isPaid ? null : (_) => _toggleItemCheck(i),
                                                            title: Text(item.product.name.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.sp, decoration: isPaid ? TextDecoration.lineThrough : null)),
                                                            subtitle: Text("${item.qty} x ${currency.format(item.price)}", style: TextStyle(fontSize: 10.sp)),
                                                            secondary: Text(currency.format(item.total), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.sp, color: MetroColors.primary)),
                                                        ),
                                                    );
                                                },
                                            ),
                                        ),
                                    ),
                                    SizedBox(height: 8.sc),
                                    Container(
                                        padding: EdgeInsets.all(8.sc),
                                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4.sc)),
                                        child: Column(
                                            children: [
                                                Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                        Text("TOTAL CHECKED", style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.blue)),
                                                        Text(currency.format(selectedTotal), style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.blue)),
                                                    ],
                                                ),
                                                SizedBox(height: 4.sc),
                                                Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                        Text("UNCHECKED", style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.black54)),
                                                        Text(currency.format(unselectedTotal), style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Colors.black87)),
                                                    ],
                                                ),
                                            ],
                                        ),
                                    ),
                                    if (_addedPayments.isNotEmpty) ...[
                                        SizedBox(height: 8.sc),
                                        Text("PEMBAYARAN TERBAGI", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w900, fontSize: 10.sp, letterSpacing: 1.sc)),
                                        SizedBox(height: 4.sc),
                                        Container(
                                            height: 100.sc,
                                            decoration: BoxDecoration(border: Border.all(color: Colors.black.withOpacity(0.05), width: 1.sc), color: Colors.grey[50], borderRadius: BorderRadius.circular(4.sc)),
                                            child: ListView.builder(
                                                itemCount: _addedPayments.length,
                                                itemBuilder: (ctx, i) {
                                                    final p = _addedPayments[i];
                                                    return ListTile(
                                                        dense: true,
                                                        visualDensity: VisualDensity.compact,
                                                        title: Text(_getLabelByName(p['method'].toString()), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.sp)),
                                                        trailing: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                                Text(currency.format(p['amount']), style: TextStyle(fontWeight: FontWeight.bold, color: MetroColors.primary, fontSize: 10.sp)),
                                                                IconButton(
                                                                    icon: Icon(Icons.close, size: 14.sc, color: MetroColors.error),
                                                                    padding: EdgeInsets.zero,
                                                                    constraints: const BoxConstraints(),
                                                                    onPressed: () => setState(() {
                                                                        final List<int> pIndices = (p['paid_indices'] as List<int>?) ?? [];
                                                                        for (int idx in pIndices) _paidIndices.remove(idx);
                                                                        _addedPayments.removeAt(i);
                                                                        _activeIndex = -1;
                                                                        _updateCalculations();
                                                                    }),
                                                                )
                                                            ],
                                                        ),
                                                    );
                                                },
                                            ),
                                        ),
                                    ],
                                ],
                            ),
                        ),
                    ),
                    const VerticalDivider(width: 1, color: Colors.black12),

                    // --- COLUMN 2: PEMBAYARAN ---
                    Expanded(
                        flex: 4,
                        child: Container(
                            color: const Color(0xFFF8F9FA),
                            padding: EdgeInsets.all(16.sc),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text("PEMBAYARAN", style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.w900, fontSize: 14.sp, letterSpacing: 1.sc)),
                                    SizedBox(height: 12.sc),
                                    
                                    // Total Status Display
                                    Container(
                                        padding: EdgeInsets.all(12.sc),
                                        decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6.sc),
                                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4.sc)],
                                            border: Border.all(color: Colors.black.withOpacity(0.05), width: 1.sc)
                                        ),
                                        child: Column(
                                            children: [
                                                _summaryRow("TOTAL BILL", currency.format(widget.finalTotal), fontSize: 18.sp, weight: FontWeight.w900),
                                                if (totalAddedPayments > 0) ...[
                                                    Divider(height: 12.sc, thickness: 1.sc),
                                                    _summaryRow("TOTAL TERBAYAR", currency.format(totalAddedPayments), color: Colors.blue[700], fontSize: 16.sp, weight: FontWeight.w900),
                                                ],
                                                Divider(height: 16.sc, thickness: 1.sc),
                                                _summaryRow(remainingBalance > 0 ? "SISA TAGIHAN" : "LUNAS", currency.format(remainingBalance > 0 ? remainingBalance : 0), 
                                                    color: remainingBalance > 0 ? MetroColors.error : Colors.green, fontSize: 24.sp, weight: FontWeight.w900),
                                                if (remainingBalance < 0) ...[
                                                    SizedBox(height: 4.sc),
                                                    _summaryRow("KEMBALIAN", currency.format(remainingBalance.abs()), color: MetroColors.primary, fontSize: 20.sp, weight: FontWeight.w900),
                                                ]
                                            ],
                                        ),
                                    ),
                                    SizedBox(height: 16.sc),
                                    
                                    Text("PILIH METODE BAYAR", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.sp, color: Colors.black54, letterSpacing: 1.sc)),
                                    SizedBox(height: 8.sc),
                                    // Make this part scrollable but with a minimum visible height if possible
                                    ConstrainedBox(
                                        constraints: BoxConstraints(maxHeight: 300.sc, minHeight: 150.sc),
                                        child: _buildGridMethods(),
                                    ),
                                    SizedBox(height: 16.sc),
                                    
                                    Row(
                                        children: [
                                            if (_activeIndex == -1 && remainingBalance > 0 && (double.tryParse(_inputStr) ?? 0) > 0) ...[
                                                Expanded(
                                                    child: MetroButton(
                                                        label: "TAMBAH SPLIT",
                                                        icon: Icons.add_circle_outline,
                                                        color: Colors.white,
                                                        textColor: const Color(0xFF1976D2),
                                                        onPressed: _addPayment,
                                                    )
                                                ),
                                                SizedBox(width: 8.sc),
                                            ],
                                            Expanded(
                                              child: MetroButton(
                                                label: "BATAL",
                                                icon: Icons.close,
                                                color: Colors.white,
                                                textColor: Colors.black54,
                                                onPressed: () => Navigator.pop(context),
                                              ),
                                            ),
                                            SizedBox(width: 8.sc),
                                            Expanded(
                                                flex: 2,
                                                child: MetroButton(
                                                    label: completed ? "SIMPAN & CETAK" : "BAYAR TAGIHAN",
                                                    icon: completed ? Icons.print : Icons.payment,
                                                    color: completed ? Colors.green[700]! : MetroColors.primary,
                                                    onPressed: _onFinalize,
                                                ),
                                            ),
                                        ],
                                    ),
                                ],
                              ),
                            ),
                        ),
                    ),
                    const VerticalDivider(width: 1, color: Colors.black12),

                    // --- COLUMN 3: NUMPAD ---
                    Expanded(
                        flex: 3,
                        child: Container(
                            color: Colors.white,
                            padding: EdgeInsets.all(16.sc),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text("NUMPAD", style: TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 14.sp, letterSpacing: 1.sc)),
                                    SizedBox(height: 12.sc),
                                    
                                    // Moved Input Display here
                                    Container(
                                        width: double.infinity,
                                        height: 60.sc,
                                        padding: EdgeInsets.symmetric(horizontal: 16.sc),
                                        decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(color: MetroColors.primary, width: 2.sc),
                                            borderRadius: BorderRadius.circular(6.sc)
                                        ),
                                        alignment: Alignment.centerRight,
                                        child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                                Text("JUMLAH BAYAR", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 8.sp, color: Colors.black54, letterSpacing: 0.5.sc)),
                                                Text(
                                                    NumberFormat.decimalPattern('id').format(double.tryParse(_inputStr) ?? 0),
                                                    style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: MetroColors.primary)
                                                ),
                                            ],
                                        ),
                                    ),
                                    SizedBox(height: 12.sc),
                                    ConstrainedBox(
                                        constraints: BoxConstraints(maxHeight: 350.sc, minHeight: 250.sc),
                                        child: _buildNumpad(),
                                    ),
                                    SizedBox(height: 12.sc),
                                    Text("CEPAT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.sp, color: Colors.black54, letterSpacing: 1.sc)),
                                    SizedBox(height: 6.sc),
                                    Wrap(
                                        spacing: 6.sc,
                                        runSpacing: 6.sc,
                                        children: [
                                            ..._quickCashAmounts.map((amt) => _quickCashBtn(amt)),
                                            _quickCashBtn(0, label: "UANG PAS"),
                                        ],
                                    ),
                                    SizedBox(height: 12.sc),
                                    SizedBox(
                                        width: double.infinity,
                                        height: 48.sc,
                                        child: MetroButton(
                                            label: "HAPUS / RESET",
                                            icon: Icons.backspace_outlined,
                                            color: Colors.red[50]!,
                                            textColor: Colors.red[700]!,
                                            onPressed: () => _onNumpadTap('C'),
                                        ),
                                    )
                                ],
                              ),
                            ),
                        ),
                    ),
                ],
            ),
        ),
    );
  }

  Widget _summaryRow(String label, String value, {double fontSize = 14, Color? color, FontWeight weight = FontWeight.bold}) {
      return Padding(
          padding: EdgeInsets.symmetric(vertical: 4.sc),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp, color: Colors.black54)),
                    ),
                  ),
                  SizedBox(width: 8.sc),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value, style: TextStyle(fontWeight: weight, fontSize: fontSize, color: color ?? Colors.black87)),
                    ),
                  ),
              ],
          ),
      );
  }

  Widget _buildGridMethods() {
      final list = _paymentMethods.isNotEmpty ? _paymentMethods : [
          {'name': 'cash', 'label': 'TUNAI'},
          {'name': 'card', 'label': 'KARTU'},
          {'name': 'qris', 'label': 'QRIS'},
          {'name': 'transfer', 'label': 'TRANSFER'},
      ];

      return GridView.builder(
          itemCount: list.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              crossAxisSpacing: 12.sc,
              mainAxisSpacing: 12.sc,
          ),
          itemBuilder: (ctx, i) {
              final m = list[i];
              final isSelected = m['name'] == selectedPaymentMethod;
              return InkWell(
                  onTap: () {
                      setState(() {
                          selectedPaymentMethod = m['name'];
                          if (!isCash) _inputStr = selectedTotal.round().toString();
                          _updateCalculations();
                      });
                      if (_activeIndex != -1) _addedPayments[_activeIndex]['method'] = m['name'];
                  },
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                          color: isSelected ? MetroColors.primary : Colors.white,
                          border: Border.all(color: isSelected ? MetroColors.primary : Colors.black12, width: 2.sc),
                          borderRadius: BorderRadius.circular(8.sc),
                          boxShadow: isSelected ? [BoxShadow(color: MetroColors.primary.withOpacity(0.3), blurRadius: 8.sc, offset: Offset(0, 4.sc))] : null
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              if (_pmImages[m['name']] != null)
                                Opacity(
                                  opacity: isSelected ? 1.0 : 0.8,
                                  child: _buildPmIcon(_pmImages[m['name']]!, isSelected, height: 32.sc),
                                )
                              else ...[
                                Icon(isSelected ? Icons.check_circle : Icons.payment, color: isSelected ? Colors.white : MetroColors.primary, size: 20.sc),
                                SizedBox(height: 4.sc),
                                Text(_getPMDisplayLabel(m), textAlign: TextAlign.center, style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black87,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w900
                                )),
                              ]
                          ],
                      ),
                  ),
              );
          },
      );
  }
  
  Widget _buildNumpad() {
      final keys = ['7','8','9','4','5','6','1','2','3','0','00','BACK'];
      
      return GridView.builder(
          itemCount: keys.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, 
              crossAxisSpacing: 6.sc, 
              mainAxisSpacing: 6.sc,
              childAspectRatio: 1.4,
          ),
          itemBuilder: (ctx, i) {
              final labels = ['1','2','3','4','5','6','7','8','9','00','0','BACK'];
              final val = labels[i];
              return InkWell(
                  onTap: () => _onNumpadTap(val),
                  child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black.withOpacity(0.06), width: 1.sc),
                          borderRadius: BorderRadius.circular(4.sc)
                      ),
                      alignment: Alignment.center,
                      child: val == 'BACK' 
                        ? Icon(Icons.backspace_outlined, size: 20.sc, color: Colors.black54) 
                        : Text(val, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.blueGrey[800])),
                  ),
              );
          },
      );
  }

  Widget _quickCashBtn(double amt, {String? label}) {
      final color = MetroColors.primary;
      return InkWell(
      onTap: () => _onQuickCash(amt, label ?? ''),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.sc, vertical: 8.sc),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4.sc),
          border: Border.all(color: color.withOpacity(0.2), width: 1.sc)
        ),
        child: Text(
          label ?? NumberFormat.decimalPattern('id').format(amt),
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10.sp),
        ),
      ),
    );
  }

  Widget _buildPmIcon(String p, bool isSelected, {double height = 24}) {
      if (p.startsWith('assets/')) {
          return SizedBox(
              height: height, 
              child: Image.asset(p, fit: BoxFit.contain, color: isSelected ? Colors.white : null),
          );
      }
      return SizedBox(
          height: height, 
          child: Image.file(File(p), fit: BoxFit.contain, color: isSelected ? Colors.white : null),
      );
  }
}

