import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:donapos_mobile/utils_scaler.dart';

class TablePaxDialog extends StatefulWidget {
  final ResTable table;
  final int initialPax;

  const TablePaxDialog({
    super.key,
    required this.table,
    this.initialPax = 0,
  });

  @override
  State<TablePaxDialog> createState() => _TablePaxDialogState();
}

class _TablePaxDialogState extends State<TablePaxDialog> {
  String _inputStr = "";

  @override
  void initState() {
    super.initState();
    if (widget.initialPax > 0) {
      _inputStr = widget.initialPax.toString();
    } else {
      _inputStr = "1";
    }
  }

  void _onKey(String key) {
    GlobalSettings.playClick();
    HapticFeedback.lightImpact();

    if (key == 'C') {
      setState(() => _inputStr = "");
    } else if (key == 'BACK') {
      if (_inputStr.isNotEmpty) {
        setState(() => _inputStr = _inputStr.substring(0, _inputStr.length - 1));
      }
    } else if (key == 'ENTER') {
      _onSubmit();
    } else {
      if (_inputStr.length < 3) { // Max 999 pax
        setState(() => _inputStr += key);
      }
    }
  }

  void _onSubmit() {
    int pax = int.tryParse(_inputStr) ?? 0;
    if (pax <= 0) {
       pax = 1; 
    }
    Navigator.pop(context, pax);
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      title: 'JUMLAH TAMU (PAX)',
      icon: Icons.people,
      width: 400.sc,
      height: 600.sc,
      content: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.sc),
            decoration: BoxDecoration(
              color: MetroColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.sc),
            ),
            child: Column(
              children: [
                Text(
                  "MEJA: ${widget.table.name.toUpperCase()}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                ),
                SizedBox(height: 8.sc),
                Text(
                  "Masukkan Jumlah Tamu / Orang",
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.sc),
          
          // Display
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 20.sc, horizontal: 24.sc),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12, width: 1.sc),
              borderRadius: BorderRadius.circular(4.sc),
            ),
            alignment: Alignment.center,
            child: Text(
              _inputStr.isEmpty ? "0" : _inputStr,
              style: TextStyle(fontSize: 48.sp, fontWeight: FontWeight.w900, color: MetroColors.primary),
            ),
          ),
          
          SizedBox(height: 24.sc),
          
          // Numpad
          Expanded(
            child: _buildNumpad(),
          ),
          
          SizedBox(height: 16.sc),
          
          MetroButton(
            label: 'LANJUT',
            icon: Icons.check,
            onPressed: _onSubmit,
            color: MetroColors.primary,
          )
        ],
      ),
    );
  }

  Widget _buildNumpad() {
      final keys = [
          '1', '2', '3',
          '4', '5', '6',
          '7', '8', '9',
          'C', '0', 'BACK',
      ];

      return GridView.builder(
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              crossAxisSpacing: 10.sc,
              mainAxisSpacing: 10.sc
          ),
          itemCount: keys.length,
          itemBuilder: (ctx, i) {
              final k = keys[i];
              Color? btnColor;
              Color txtColor = Colors.black87;
              
              if (k == 'C') {
                  btnColor = Colors.red.withOpacity(0.1);
                  txtColor = Colors.red;
              } else if (k == 'BACK') {
                  btnColor = Colors.grey.withOpacity(0.2);
              } else {
                  btnColor = Colors.white;
              }

              return InkWell(
                  onTap: () => _onKey(k),
                  child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: btnColor,
                          border: Border.all(color: Colors.black.withOpacity(0.05), width: 1.sc),
                          borderRadius: BorderRadius.circular(4.sc)
                      ),
                      child: k == 'BACK' 
                        ? Icon(Icons.backspace, size: 20.sc, color: Colors.black54)
                        : Text(k, style: TextStyle(
                            color: txtColor, 
                            fontSize: 24.sp, 
                            fontWeight: FontWeight.w900
                        )),
                  ),
              );
          },
      );
  }
}
