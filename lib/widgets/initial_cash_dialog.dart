import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:intl/intl.dart';

class InitialCashDialog extends StatefulWidget {
  final Future<void> Function(double amount) onConfirm;

  const InitialCashDialog({super.key, required this.onConfirm});

  @override
  State<InitialCashDialog> createState() => _InitialCashDialogState();
}

class _InitialCashDialogState extends State<InitialCashDialog> {
  String _amountStr = '0';
  bool _isLoading = false;
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  void _onConfirm() async {
    final amount = double.tryParse(_amountStr) ?? 0;
    if (amount < 0) return;
    
    setState(() => _isLoading = true);
    await widget.onConfirm(amount);
    if (mounted) {
       setState(() => _isLoading = false);
       Navigator.pop(context, true);
    }
  }

  void _setAmount(String val) {
    setState(() => _amountStr = val);
  }

  void _onKey(String key) {
    setState(() {
      if (key == 'BACK') {
        if (_amountStr.length > 1) {
          _amountStr = _amountStr.substring(0, _amountStr.length - 1);
        } else {
          _amountStr = '0';
        }
      } else if (key == 'C') {
        _amountStr = '0';
      } else {
        if (_amountStr == '0') {
          _amountStr = key;
        } else if (_amountStr.length < 12) {
          _amountStr += key;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        width: isLandscape ? 850 : 450,
        height: isLandscape ? 500 : 750,
        decoration: const BoxDecoration(
          color: Color(0xFFE0E0E0), // Solid Grey
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          children: [
            // Custom Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              color: MetroColors.primary,
              child: const Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                  SizedBox(width: 16),
                  Text('INPUT MODAL KAS AWAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
                ],
              ),
            ),
            
            Expanded(
              child: Row(
                children: [
                  // Left Side: Display & Quick Cash
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: Colors.black12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('RINGKASAN SALDO', style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            color: Colors.white,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('TOTAL INPUT', style: TextStyle(color: Colors.black26, fontSize: 9, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    currencyFormat.format(double.tryParse(_amountStr) ?? 0),
                                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: MetroColors.text),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const Text('PILIH CEPAT', style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _quickBtn('100.000', '100000'),
                              const SizedBox(width: 8),
                              _quickBtn('200.000', '200000'),
                              const SizedBox(width: 8),
                              _quickBtn('300.000', '300000'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 64,
                            child: MetroButton(
                              label: 'VERIFIKASI & BUKA KASIR',
                              color: MetroColors.retailPrimary,
                              onPressed: _onConfirm,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  
                  // Right Side: Numpad
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      color: Colors.black.withOpacity(0.02),
                      child: Column(
                        children: [
                          _buildNumRow(['1', '2', '3']),
                          _buildNumRow(['4', '5', '6']),
                          _buildNumRow(['7', '8', '9']),
                          _buildNumRow(['C', '0', 'BACK']),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickBtn(String label, String val) {
    return Expanded(
      child: Material(
        color: Colors.white,
        elevation: 0,
        shape: Border.all(color: Colors.black12),
        child: InkWell(
          onTap: () => _setAmount(val),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(label, style: const TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 11.7)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumRow(List<String> keys) {
    return Expanded(
      child: Row(
        children: keys.map((k) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _numpadBtn(k),
          ),
        )).toList(),
      ),
    );
  }

  Widget _numpadBtn(String label) {
    final isSpecial = label == 'C' || label == 'BACK';
    return Material(
      color: isSpecial ? Colors.black.withOpacity(0.05) : Colors.white,
      elevation: 0,
      shape: Border.all(color: Colors.black.withOpacity(0.05)),
      child: InkWell(
        onTap: () => _onKey(label),
        child: Center(
          child: label == 'BACK' 
            ? const Icon(Icons.backspace, color: Colors.black38, size: 20)
            : Text(label, style: TextStyle(
                color: label == 'C' ? MetroColors.error : MetroColors.text, 
                fontSize: 21.6, 
                fontWeight: FontWeight.w900
              )),
        ),
      ),
    );
  }
}
