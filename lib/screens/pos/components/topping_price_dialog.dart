import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/utils_scaler.dart';

class ToppingPriceDialog extends StatefulWidget {
  final String toppingName;
  final double initialPrice;

  const ToppingPriceDialog({
    Key? key,
    required this.toppingName,
    this.initialPrice = 0,
  }) : super(key: key);

  @override
  _ToppingPriceDialogState createState() => _ToppingPriceDialogState();
}

class _ToppingPriceDialogState extends State<ToppingPriceDialog> {
  String _inputStr = "0";

  @override
  @override
  void initState() {
    super.initState();
    // Default to the server price (initialPrice), but formatted nicely
    // If 0, show "0"
    if (widget.initialPrice == 0) {
       _inputStr = "0";
    } else {
       // Convert to int if possible for cleaner look
       if (widget.initialPrice % 1 == 0) {
           _inputStr = widget.initialPrice.toInt().toString();
       } else {
           _inputStr = widget.initialPrice.toString();
       }
    }
  }

  void _onNumpadTap(String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (value == 'C') {
        _inputStr = "0";
      } else if (value == 'BACK') {
        if (_inputStr.length > 1) {
          _inputStr = _inputStr.substring(0, _inputStr.length - 1);
        } else {
          _inputStr = "0";
        }
      } else if (value == '00') {
        if (_inputStr != "0") _inputStr += "00";
      } else {
        if (_inputStr == "0") _inputStr = "";
        _inputStr += value;
      }
    });
  }

  void _onQuickPrice(int value) {
    HapticFeedback.mediumImpact();
    setState(() {
      _inputStr = value.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.decimalPattern('id');

    return Dialog(
       backgroundColor: MetroColors.background,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
       child: Container(
         width: 400.sc,
         constraints: BoxConstraints(
             maxHeight: MediaQuery.of(context).size.height * 0.9
         ),
         padding: EdgeInsets.all(24.sc),
         child: Column( // Main Layout Column
           mainAxisSize: MainAxisSize.min,
           children: [
             // Header fixed
             Text(
               'INPUT HARGA: ${widget.toppingName.toUpperCase()}',
               style: MetroTypography.h3.copyWith(color: MetroColors.primary, fontSize: (MetroTypography.h3.fontSize ?? 16).sp),
               textAlign: TextAlign.center,
             ),
             SizedBox(height: 24.sc),
             
             // Scrollable Content
             Flexible(
               child: SingleChildScrollView(
                 child: Column(
                   children: [
                     // Display
                     Container(
                       width: double.infinity,
                       padding: EdgeInsets.symmetric(horizontal: 16.sc, vertical: 12.sc),
                       decoration: BoxDecoration(
                           color: Colors.white,
                           border: Border.all(color: MetroColors.primary, width: 1.sc),
                           borderRadius: BorderRadius.circular(4.sc)
                       ),
                       alignment: Alignment.centerRight,
                       child: Text(
                           currency.format(double.tryParse(_inputStr) ?? 0),
                           style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.w900, color: MetroColors.primary)
                       ),
                     ),
                     SizedBox(height: 16.sc),
                     
                     // Quick Buttons
                     Row(
                       children: [
                         _quickBtn(1000),
                         SizedBox(width: 8.sc),
                         _quickBtn(2000),
                         SizedBox(width: 8.sc),
                         _quickBtn(5000),
                         SizedBox(width: 8.sc),
                         _quickBtn(10000),
                       ],
                     ),
                     SizedBox(height: 16.sc),
                     
                     // Numpad
                     SizedBox(
                       height: 300.sc,
                       child: GridView.count(
                         crossAxisCount: 3,
                         childAspectRatio: 1.5,
                         crossAxisSpacing: 8.sc,
                         mainAxisSpacing: 8.sc,
                         physics: const NeverScrollableScrollPhysics(), // Disable grid scroll, let parent scroll
                         shrinkWrap: true,
                         children: [
                           _numpadBtn('7'), _numpadBtn('8'), _numpadBtn('9'),
                           _numpadBtn('4'), _numpadBtn('5'), _numpadBtn('6'),
                           _numpadBtn('1'), _numpadBtn('2'), _numpadBtn('3'),
                           _numpadBtn('C', color: Colors.orange), _numpadBtn('0'), _numpadBtn('00'),
                         ],
                       ),
                     ),
                    SizedBox(height: 16.sc),
                   ],
                 ),
               ),
             ),
             
             // Footer Fixed
             SizedBox(height: 8.sc),
             Row(
               children: [
                 Expanded(
                   child: MetroButton(
                     label: 'BATAL',
                     onPressed: () => Navigator.pop(context),
                     color: Colors.grey[800] ?? Colors.grey,
                   ),
                 ),
                 SizedBox(width: 16.sc),
                 Expanded(
                   child: MetroButton(
                     label: 'SIMPAN',
                     onPressed: () {
                        double val = double.tryParse(_inputStr) ?? 0;
                        Navigator.pop(context, val);
                     },
                     color: MetroColors.primary,
                   ),
                 ),
               ],
             )
           ],
         ),
       ),
    );
  }

  Widget _quickBtn(int value) {
    return Expanded(
      child: InkWell(
        onTap: () => _onQuickPrice(value),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.sc),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border.all(color: Colors.blue, width: 1.sc),
            borderRadius: BorderRadius.circular(4.sc)
          ),
          child: Text(
            '${value ~/ 1000}k',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13.sp),
          ),
        ),
      ),
    );
  }

  Widget _numpadBtn(String label, {Color? color}) {
    return InkWell(
      onTap: () => _onNumpadTap(label),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black12, width: 1.sc),
          borderRadius: BorderRadius.circular(4.sc)
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: color ?? Colors.black87),
        ),
      ),
    );
  }
}
