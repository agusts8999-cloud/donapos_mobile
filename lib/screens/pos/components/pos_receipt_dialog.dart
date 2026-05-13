import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:provider/provider.dart';
import 'package:donapos_mobile/language_provider.dart';
import 'package:donapos_mobile/config.dart';
import 'package:donapos_mobile/utils_label_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:donapos_mobile/utils_scaler.dart';


class PosReceiptDialog extends StatefulWidget {
  final List<CartItem> cart;
  final Map<String, String> businessInfo;
  final String cashierName;
  final double subtotal;
  final double calculatedDiscount;
  final double calculatedTax;
  final double finalTotal;
  final double amountPaid;
  final double changeAmount;
  final String invoiceNumber;
  final String saleTypeLabel;
  final String? selectedTableName;
  final String? selectedCustomerName;
  final String? paymentMethod;
  final bool isLogoEnabled;
  final bool showAppVersion;
  final String appVersion;
  final Future<void> Function({int times, bool isDuplicate}) onPrint;
  final VoidCallback onFinalize;
  final List<Map<String, dynamic>> taxDetails;
  final bool allowDuplicate;
  final int pax;
  final String? waiterName;
  final VoidCallback? onRefund;
  final bool isPreview;

  const PosReceiptDialog({
    super.key,
    required this.cart,
    required this.businessInfo,
    required this.cashierName,
    required this.subtotal,
    required this.calculatedDiscount,
    required this.calculatedTax,
    required this.finalTotal,
    required this.amountPaid,
    required this.changeAmount,
    required this.invoiceNumber,
    required this.saleTypeLabel,
    this.selectedTableName,
    this.selectedCustomerName,
    this.paymentMethod,
    required this.isLogoEnabled,
    required this.showAppVersion,
    required this.appVersion,
    required this.onPrint,
    required this.onFinalize,
    this.taxDetails = const [],
    this.allowDuplicate = true,
    this.pax = 0,
    this.waiterName,
    this.onRefund,
    this.isPreview = false,
  });

  @override
  State<PosReceiptDialog> createState() => _PosReceiptDialogState();
}

class _PosReceiptDialogState extends State<PosReceiptDialog> {
  bool _isPrinting = false;
  bool _isPrintingLabel = false;
  bool _labelEnabled = false;
  String? _labelAddress;

  @override
  void initState() {
    super.initState();
    _checkLabelSettings();
  }

  Future<void> _checkLabelSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _labelEnabled = prefs.getBool('label_printer_enabled') ?? false;
      _labelAddress = prefs.getString('label_printer_address');
    });
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    Widget receiptWidget = Stack(
      children: [
        Container(
          decoration: BoxDecoration(
              color: widget.isPreview ? const Color(0xFFF2F2F2) : Colors.white,
              border: Border.all(color: Colors.black12, width: 1.sc),
              borderRadius: widget.isPreview ? BorderRadius.circular(12.sc) : BorderRadius.zero,
              boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3), 
                      blurRadius: 30.sc, 
                      offset: Offset(0, 10.sc)
                  )
              ]),
          padding: EdgeInsets.all(16.sc),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isPreview) SizedBox(height: 12.sc),
                if (widget.isLogoEnabled && widget.businessInfo['logo_path'] != null && widget.businessInfo['logo_path']!.isNotEmpty && File(widget.businessInfo['logo_path']!).existsSync())
                   Padding(
                     padding: EdgeInsets.only(bottom: 8.sc),
                     child: Image.file(
                       File(widget.businessInfo['logo_path']!),
                       height: 60.sc,
                       fit: BoxFit.contain,
                     ),
                   )
                else ...[
                  Text(widget.businessInfo['name']!.toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16.2.sp, color: Colors.black)),
                  Text(widget.businessInfo['address']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9.sp, color: Colors.black54)),
                  Text(widget.businessInfo['mobile']!,
                      style: TextStyle(fontSize: 9.sp, color: Colors.black54)),
                ],
                Divider(color: Colors.black26, thickness: 1.sc),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("Bln: ${DateFormat('dd/MM/yy HH:mm').format(DateTime.now())}",
                      style: TextStyle(fontSize: 9.sp, color: Colors.black)),
                  Text(widget.invoiceNumber.toUpperCase(),
                      style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("${lp.translate('pos_cashier')}: ${widget.cashierName.toUpperCase()}",
                      style: TextStyle(fontSize: 9.sp, color: Colors.black)),
                  Text(widget.saleTypeLabel.toUpperCase(),
                      style: TextStyle(
                          fontSize: 9.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                ]),
                if (widget.selectedCustomerName != null)
                  Padding(
                    padding: EdgeInsets.only(top: 2.sc),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text("${lp.translate('pos_customer_caps')}: ${widget.selectedCustomerName!.toUpperCase()}",
                            style: TextStyle(
                                fontSize: 9.sp, fontWeight: FontWeight.bold, color: MetroColors.primary)),
                        const Text(""),
                    ])),
                if (widget.waiterName != null)
                  Padding(
                    padding: EdgeInsets.only(top: 2.sc),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text("WAITER: ${widget.waiterName!.toUpperCase()}",
                            style: TextStyle(
                                fontSize: 9.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                        const Text(""),
                    ])),

                if (widget.selectedTableName != null)
                  Padding(
                    padding: EdgeInsets.only(top: 2.sc),
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: Text("${lp.translate('pos_table_caps')}: ${widget.selectedTableName}${widget.pax > 0 ? ' (${widget.pax} Org)' : ''}",
                            style: TextStyle(
                                fontSize: 9.sp, fontWeight: FontWeight.bold, color: Colors.black))),
                  ),
                Divider(color: Colors.black26, thickness: 1.sc),
                ...widget.cart
                    .map((item) {
                       return Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.sc),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(item.product.name.toUpperCase(),
                                        style: TextStyle(
                                            fontSize: 9.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                                  ),
                                  Text(NumberFormat('#,###').format(item.price * item.qty),
                                      style: TextStyle(
                                          fontSize: 9.sp, color: Colors.black)),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("  ${item.qty} x ${NumberFormat('#,###').format(item.price)}",
                                      style: TextStyle(fontSize: 8.5.sp, color: Colors.black87)),
                                ],
                              ),
                              if (item.selectedModifiers.isNotEmpty) 
                                ...item.selectedModifiers.map((mod) => Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("   + ${mod.name.toUpperCase()}", style: TextStyle(fontSize: 8.sp, color: Colors.black54)),
                                      Text(NumberFormat('#,###').format(mod.price * item.qty), style: TextStyle(fontSize: 8.sp, color: Colors.black54)),
                                    ],
                                )),
                              if (item.note.isNotEmpty)
                                Text("   (${item.note})", style: TextStyle(fontSize: 8.sp, fontStyle: FontStyle.italic, color: Colors.black45)),
                              if (item.itemDiscount > 0)
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        Text("   Diskon", 
                                            style: TextStyle(fontSize: 8.sp, fontStyle: FontStyle.italic, color: Colors.black54)),
                                        Text("-${NumberFormat('#,###').format(item.itemDiscount)}", 
                                            style: TextStyle(fontSize: 8.sp, fontStyle: FontStyle.italic, color: Colors.black54)),
                                    ]),

                            ],
                          ),
                        );
                    })
                    .toList(),
                Divider(color: Colors.black26, thickness: 1.sc),
                _buildSimRow(widget.businessInfo['lbl_subtotal']!, widget.subtotal),
                if (widget.calculatedDiscount > 0)
                  _buildSimRow(widget.businessInfo['lbl_discount']!, -widget.calculatedDiscount),
                
                // Tax Lines (Named)
                if (widget.taxDetails.isNotEmpty)
                    ...widget.taxDetails.map((t) => _buildSimRow(t['name'], t['amount']))
                else if (widget.calculatedTax > 0)
                  _buildSimRow(widget.businessInfo['lbl_tax']!, widget.calculatedTax),
                
                Divider(color: Colors.black26, thickness: 1.sc),
                _buildSimRow("${lp.translate('pos_total_product')} (${widget.cart.fold(0, (sum, item) => sum + item.qty)})", widget.finalTotal, isBold: true),
                Divider(color: Colors.black26, thickness: 1.sc),
                _buildSimRow(lp.translate('pos_paid'), widget.amountPaid),
                if (widget.changeAmount > 0)
                   _buildSimRow(lp.translate('pos_change'), widget.changeAmount),
                if (widget.paymentMethod != null) ...[
                    Divider(color: Colors.black26, thickness: 1.sc),
                    _buildSimMethodRow(lp.translate('pos_payment_method'), widget.paymentMethod!),
                ],
                Divider(color: Colors.black26, thickness: 1.sc),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.sc),
                  child: Column(
                    children: [
                      Text(widget.businessInfo['footer_text']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 9.9.sp, fontWeight: FontWeight.bold, color: Colors.black87)),
                      if (widget.showAppVersion)
                        Text("${AppConfig.appName} ${widget.appVersion}",
                            style: TextStyle(fontSize: 7.sp, color: Colors.black38)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.isPreview)
          Positioned(
            top: 10.sc,
            right: 10.sc,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(6.sc),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.black54, size: 20.sc),
              ),
            ),
          ),
      ],
    );

    Widget actionButtons = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.isPreview) ...[
          SizedBox(
            width: double.maxFinite,
            child: ElevatedButton.icon(
              onPressed: _isPrinting ? null : () async {
                setState(() => _isPrinting = true);
                await widget.onPrint(times: 1);
                if (mounted) widget.onFinalize();
              },
              icon: _isPrinting 
                  ? SizedBox(width: 24.sc, height: 24.sc, child: DonaposLoader(size: 24.sc)) 
                  : Icon(Icons.print, color: Colors.white, size: 24.sc),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ADEF),
                  disabledBackgroundColor: Colors.grey, // Disabled color
                  padding: EdgeInsets.symmetric(vertical: 25.sc),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
              label: Text(_isPrinting ? lp.translate('pos_printing').toUpperCase() : lp.translate('pos_print_receipt_1x').toUpperCase(),
                  style: TextStyle(
                      fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
          if (_labelEnabled && _labelAddress != null && widget.cart.any((i) => (i.product.needsLabel ?? 0) == 1)) ...[
             SizedBox(height: 15.sc),
             SizedBox(
               width: double.maxFinite,
               child: ElevatedButton.icon(
                 onPressed: _isPrintingLabel ? null : () async {
                    setState(() => _isPrintingLabel = true);
                    try {
                       await LabelPrinterUtil.printTransactionLabels(
                           _labelAddress!, 
                           widget.cart, 
                           widget.businessInfo['name'] ?? 'DONAPOS', 
                           widget.cashierName
                       );
                    } catch(e) {
                       debugPrint("Label Error: $e");
                    } finally {
                       if(mounted) setState(() => _isPrintingLabel = false);
                    }
                 },
                 icon: _isPrintingLabel 
                     ? SizedBox(width: 24.sc, height: 24.sc, child: DonaposLoader(size: 24.sc)) 
                     : Icon(Icons.label, color: Colors.white, size: 24.sc),
                 style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.indigo,
                     disabledBackgroundColor: Colors.grey, 
                     padding: EdgeInsets.symmetric(vertical: 25.sc),
                     shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                 label: Text(_isPrintingLabel ? "MENCETAK LABEL..." : "CETAK LABEL",
                     style: TextStyle(
                         fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.white)),
               ),
             ),
          ],
          if (widget.allowDuplicate) ...[
            SizedBox(height: 15.sc),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isPrinting ? null : () async {
                      setState(() => _isPrinting = true);
                      await widget.onPrint(times: 1);
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (dCtx) => AlertDialog(
                          backgroundColor: const Color(0xFF252525),
                          title: Text(lp.translate('pos_cut_paper'),
                              style: TextStyle(color: Colors.white, fontSize: 16.sp)),
                          content: Text(lp.translate('pos_cut_paper_msg'),
                              style: TextStyle(color: Colors.white70, fontSize: 14.sp)),
                          actions: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    padding: EdgeInsets.symmetric(vertical: 12.sc)),
                                onPressed: () async {
                                  Navigator.pop(dCtx);
                                  // We don't reset _isPrinting here because we continue printing
                                  await widget.onPrint(times: 1, isDuplicate: true);
                                  if (mounted) widget.onFinalize();
                                },
                                child: Text(lp.translate('pos_continue_duplicate').toUpperCase(),
                                    style: TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.orange, width: 2.sc),
                        backgroundColor: Colors.orange.withOpacity(0.05),
                        padding: EdgeInsets.symmetric(vertical: 18.sc)),
                    child: Text(lp.translate('pos_print_2x_duplicate').toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 10.8.sp)),
                  ),
                ),
                SizedBox(width: 15.sc),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isPrinting ? null : widget.onFinalize,
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey, width: 2.sc),
                        padding: EdgeInsets.symmetric(vertical: 18.sc)),
                    child: Text(lp.translate('pos_no_print').toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 10.8.sp)),
                  ),
                ),
              ],
            ),
          ] else ...[
             SizedBox(height: 15.sc),
             Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isPrinting ? null : widget.onFinalize,
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey, width: 2.sc),
                        padding: EdgeInsets.symmetric(vertical: 18.sc)),
                    child: Text(lp.translate('pos_close_finish').toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 10.8.sp)),
                  ),
                ),
                if (widget.onRefund != null) ...[
                    SizedBox(width: 15.sc),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onRefund,
                        style: OutlinedButton.styleFrom(
                            side: BorderSide(color: MetroColors.error, width: 2.sc),
                            padding: EdgeInsets.symmetric(vertical: 18.sc),
                            backgroundColor: MetroColors.error.withOpacity(0.05)
                        ),
                        child: Text('REFUND',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: MetroColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.8.sp)),
                      ),
                    ),
                ]
              ],
            ),
          ],
        ]
      ],
    );
    return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20.sc, vertical: 20.sc),
        elevation: 0,
        child: Container(
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.9), // Solid Dark Glass
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.sc),
                borderRadius: BorderRadius.circular(20.sc),
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 50.sc,
                        spreadRadius: 2.sc
                    )
                ]
            ),
            padding: EdgeInsets.all(30.sc),
            child: widget.isPreview
                ? Center(
                    child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 400.sc),
                        child: receiptWidget,
                    ),
                  )
                : isLandscape
                    ? Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 400.sc), child: receiptWidget))),
                            SizedBox(width: 40.sc),
                            Expanded(child: actionButtons),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Center(
                            child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 400.sc),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    receiptWidget,
                                    SizedBox(height: 30.sc),
                                    actionButtons,
                                  ],
                                ),
                            ),
                        ),
                      ),
        ),
    );
  }

  Widget _buildSimRow(String label, double val, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9.sp,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black)),
        Text(NumberFormat('#,###').format(val),
            style: TextStyle(
                fontSize: 9.sp,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black)),
      ],
    );
  }

  Widget _buildSimMethodRow(String label, String displayMethod) {
    String display = displayMethod.toUpperCase();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        Text(display,
            style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
      ],
    );
  }
}
