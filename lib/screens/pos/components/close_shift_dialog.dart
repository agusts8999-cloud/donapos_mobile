import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/utils_scaler.dart';

class CloseShiftDialog extends StatefulWidget {
  final Future<void> Function(String reason, String note)? onPrint;
  const CloseShiftDialog({super.key, this.onPrint});

  @override
  State<CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<CloseShiftDialog> {
  String? _selectedReason;
  bool _isPrinting = false;
  final _noteController = TextEditingController();
  final List<String> _reasons = ['SELESAI SHIFT', 'ISTIRAHAT', 'TOKO TUTUP', 'LAINNYA'];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.all(20.sc),
      child: Container(
        constraints: BoxConstraints(maxWidth: 500.sc),
        decoration: BoxDecoration(
          color: MetroColors.white,
          borderRadius: BorderRadius.circular(0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30.sc,
              offset: Offset(0, 15.sc),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 5.sc, color: MetroColors.error),
            Padding(
              padding: EdgeInsets.all(24.sc),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MetroSectionTitle(title: 'KELUAR KASIR'),
                  SizedBox(height: 24.sc),
                  Text('PILIH ALASAN PENUTUPAN:', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.black54)),
                  SizedBox(height: 12.sc),
                  Wrap(
                    spacing: 8.sc,
                    runSpacing: 8.sc,
                    children: _reasons.map((reason) {
                      bool isSelected = _selectedReason == reason;
                      return InkWell(
                        onTap: () => setState(() => _selectedReason = reason),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(horizontal: 16.sc, vertical: 12.sc),
                          decoration: BoxDecoration(
                            color: isSelected ? MetroColors.error : Colors.grey.shade100,
                            border: Border.all(
                              color: isSelected ? MetroColors.error : Colors.grey.shade300,
                              width: 1.5.sc
                            ),
                          ),
                          child: Text(
                            reason,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w900,
                              fontSize: 11.sp,
                              letterSpacing: 0.5.sc
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 24.sc),
                  Text('CATATAN TAMBAHAN (OPSIONAL):', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.black54)),
                  SizedBox(height: 8.sc),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Misal: Uang tunai diserahkan ke SPV...',
                      hintStyle: TextStyle(fontSize: 13.sp),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12.sc),
                    ),
                    style: TextStyle(fontSize: 13.sp),
                  ),
                  SizedBox(height: 32.sc),
                  Row(
                    children: [
                      Expanded(
                        child: MetroButton(
                          label: 'BATAL',
                          onPressed: () => Navigator.pop(context),
                          color: MetroColors.secondary,
                          isSecondary: true,
                        ),
                      ),
                      SizedBox(width: 8.sc),
                      Expanded(
                        child: MetroButton(
                          label: _isPrinting ? 'CETAK...' : 'CETAK BUKTI',
                          icon: Icons.print,
                          onPressed: (_selectedReason == null || _isPrinting) ? null : () async {
                              if (widget.onPrint != null) {
                                  setState(() => _isPrinting = true);
                                  await widget.onPrint!(_selectedReason!, _noteController.text.trim());
                                  if (mounted) setState(() => _isPrinting = false);
                              }
                          },
                          color: MetroColors.primary,
                          textColor: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8.sc),
                      Expanded(
                        child: MetroButton(
                          label: 'KELUAR',
                          icon: Icons.power_settings_new,
                          onPressed: () {
                            Navigator.pop(context, {'action': 'exit'});
                          },
                          color: Colors.black,
                          textColor: Colors.white,
                        ),
                      ),
                    ],
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
