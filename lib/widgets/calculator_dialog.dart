import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CalculatorDialog extends StatefulWidget {
  const CalculatorDialog({super.key});

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  String _display = "0";
  String _expression = "";
  double? _firstOperand;
  String? _operator;
  bool _shouldResetDisplay = false;
  static String _memoryValue = "0"; 

  final _formatter = NumberFormat("#,###", "en_US");

  String _formatDisplay(String val) {
    if (val.isEmpty || val == "-") return val;
    try {
      if (val.contains('.')) {
        List<String> parts = val.split('.');
        double? whole = double.tryParse(parts[0]);
        if (whole == null) return val;
        return "${_formatter.format(whole)}.${parts[1]}";
      } else {
        double? num = double.tryParse(val);
        if (num == null) return val;
        return _formatter.format(num);
      }
    } catch (e) {
      return val;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMemory();
  }

  Future<void> _loadMemory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _memoryValue = prefs.getString('calc_memory') ?? "0";
      _display = _memoryValue;
    });
  }

  Future<void> _saveMemory(String val) async {
    _memoryValue = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calc_memory', val);
  }

  void _onKeyTap(String key) {
    setState(() {
      if (key == "C") {
        _display = "0";
        _expression = "";
        _firstOperand = null;
        _operator = null;
      } else if (key == "CE") {
        _display = "0";
        _expression = "";
        _firstOperand = null;
        _operator = null;
        _saveMemory("0");
      } else if (key == "+" || key == "-" || key == "x" || key == "/") {
        _firstOperand = double.tryParse(_display);
        _operator = key;
        _expression = "$_display $key";
        _shouldResetDisplay = true;
      } else if (key == "=") {
        if (_firstOperand != null && _operator != null) {
          double secondOperand = double.tryParse(_display) ?? 0;
          double result = 0;
          switch (_operator) {
            case "+": result = _firstOperand! + secondOperand; break;
            case "-": result = _firstOperand! - secondOperand; break;
            case "x": result = _firstOperand! * secondOperand; break;
            case "/": result = secondOperand != 0 ? _firstOperand! / secondOperand : 0; break;
          }
          _display = result % 1 == 0 ? result.toInt().toString() : result.toStringAsFixed(2);
          _expression = "";
          _firstOperand = null;
          _operator = null;
          _saveMemory(_display);
        }
      } else {
        // Numbers and dot
        if (_display == "0" || _shouldResetDisplay) {
          _display = key;
          _shouldResetDisplay = false;
        } else {
          if (key == "." && _display.contains(".")) return;
          _display += key;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 320,
        decoration: const BoxDecoration(
          color: MetroColors.background,
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: MetroColors.primary,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('KALKULATOR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  )
                ],
              ),
            ),
            // Result Display
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              color: Colors.black.withOpacity(0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_expression, style: const TextStyle(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_formatDisplay(_display), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: MetroColors.primary)),
                  ),
                ],
              ),
            ),
            // Numpad
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _row(["C", "CE", "/", "x"]),
                  _row(["7", "8", "9", "-"]),
                  _row(["4", "5", "6", "+"]),
                  _row(["1", "2", "3", "="], largeSpan: true),
                  _row(["0", "."]),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _row(List<String> keys, {bool largeSpan = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: keys.map((k) {
          bool isOp = ["+", "-", "x", "/", "="].contains(k);
          bool isSpecial = ["C", "CE"].contains(k);
          
          int flex = 1;
          if (k == "=" && largeSpan) flex = 1;
          if (k == "0" && keys.length == 2) flex = 3;
          if (k == "=" ) flex = 1;

          return Expanded(
            flex: flex,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _btn(k, isOp: isOp, isSpecial: isSpecial),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _btn(String label, {bool isOp = false, bool isSpecial = false}) {
    Color color = Colors.white;
    Color textColor = MetroColors.text;
    
    if (isOp) {
      color = MetroColors.primary;
      textColor = Colors.white;
    } else if (isSpecial) {
      color = label == "CE" ? MetroColors.error : Colors.orange;
      textColor = Colors.white;
    }

    return Material(
      color: color,
      child: InkWell(
        onTap: () => _onKeyTap(label),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
        ),
      ),
    );
  }
}
