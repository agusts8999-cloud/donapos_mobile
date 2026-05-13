import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/utils_scaler.dart';
import 'package:flutter/material.dart';

class PosScanBar extends StatefulWidget {
  final bool isScanMode;
  final bool isManualInput;
  final FocusNode scanFocusNode;
  final Function(String) onScan;
  final VoidCallback onToggleMode;
  final VoidCallback onToggleManualInput;
  final Function(bool) onManualInputChange;

  const PosScanBar({
    super.key,
    required this.isScanMode,
    required this.isManualInput,
    required this.scanFocusNode,
    required this.onScan,
    required this.onToggleMode,
    required this.onToggleManualInput,
    required this.onManualInputChange,
  });

  @override
  State<PosScanBar> createState() => _PosScanBarState();
}

class _PosScanBarState extends State<PosScanBar> {
  final TextEditingController _scanController = TextEditingController();

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      if (!widget.isScanMode) return const SizedBox.shrink();

      return Container(
          width: double.infinity,
          height: 60.sc,
          decoration: BoxDecoration(
              color: MetroColors.surface,
              border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05), width: 1.sc)),
              boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10.sc, offset: Offset(0, 4.sc))
              ]
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.sc),
          child: Row(
              children: [
                   Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.sc, vertical: 8.sc),
                      decoration: BoxDecoration(
                          color: MetroColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.zero,
                      ),
                      child: Row(
                          children: [
                              Icon(Icons.qr_code_scanner, color: MetroColors.primary, size: 20.sc),
                              SizedBox(width: 8.sc),
                              Text('SCAN / SKU', style: TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 11.sp, letterSpacing: 1.sc)),
                          ],
                      ),
                  ),
                  SizedBox(width: 16.sc),
                  Expanded(
                      child: TextField(
                          focusNode: widget.scanFocusNode,
                          controller: _scanController,
                          autofocus: true,
                          showCursor: true,
                          keyboardType: widget.isManualInput ? TextInputType.text : TextInputType.none,
                          onSubmitted: (val) {
                              widget.onScan(val);
                              _scanController.clear();
                              // Reset manual input mode after submit to hide keyboard for next scan (handled by parent logic typically, or here)
                              widget.onManualInputChange(false);
                          },
                          decoration: InputDecoration(
                              hintText: widget.isManualInput ? 'KETIK SKU PRODUK...' : 'SCAN BARCODE SEKARANG...',
                              hintStyle: TextStyle(fontSize: 12.sp, color: Colors.black26, fontWeight: FontWeight.bold),
                              prefixIcon: IconButton(
                                  icon: Icon(
                                      widget.isManualInput ? Icons.keyboard : Icons.keyboard_hide, 
                                      color: widget.isManualInput ? MetroColors.primary : Colors.grey,
                                      size: 18.sc,
                                  ),
                                  onPressed: () {
                                      widget.onToggleManualInput();
                                      // Toggle focus to refresh keyboard
                                      widget.scanFocusNode.unfocus();
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                          widget.scanFocusNode.requestFocus();
                                      });
                                  },
                                  tooltip: 'Tampilkan/Sembunyikan Keyboard',
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(color: Colors.black.withOpacity(0.1), width: 1.sc)
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(color: Colors.black.withOpacity(0.1), width: 1.sc)
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(
                                      color: widget.isManualInput ? MetroColors.primary : Colors.orange, 
                                      width: 2.sc
                                  )
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16.sc),
                              suffixIcon: _scanController.text.isNotEmpty ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () => setState(() => _scanController.clear()),
                              ) : null,
                          ),
                          style: TextStyle(
                              fontSize: 14.sp, 
                              fontWeight: FontWeight.w900, 
                              letterSpacing: 2.sc, 
                              color: widget.isManualInput ? MetroColors.text : MetroColors.retailPrimary
                          ),
                          onChanged: (_) => setState(() {}), // Refresh for clear button
                      ),
                  ),
                  SizedBox(width: 16.sc),
                  SizedBox(
                      width: 100.sc,
                      child: MetroButton(
                          label: 'TUTUP',
                          onPressed: widget.onToggleMode,
                          color: Colors.red.withOpacity(0.1),
                          textColor: Colors.red,
                          isSecondary: true,
                      ),
                  ),
              ],
          ),
      );
  }
}
