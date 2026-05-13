import 'package:donapos_mobile/design_system.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:donapos_mobile/language_provider.dart';
import 'package:flutter/services.dart';
import 'package:donapos_mobile/utils_scaler.dart';

void checkOtp(BuildContext context, VoidCallback onValid) {
  _showOtpDialog(context, onValid, isRefund: false);
}

void checkRefundOtp(BuildContext context, VoidCallback onValid) {
  _showOtpDialog(context, onValid, isRefund: true);
}

void _showOtpDialog(BuildContext context, VoidCallback onValid, {required bool isRefund}) {
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String pin = "";
        final String challenge = (Random().nextInt(9000) + 1000).toString();
        
        return StatefulBuilder(
          builder: (context, setState) {
            final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
            // ignore: unused_local_variable
            final lp = Provider.of<LanguageProvider>(context, listen: false);

            String calculateExpected(String code) {
                int val = int.tryParse(code) ?? 0;
                if (isRefund) {
                    // 8-Digit Secure Algorithm for Refund
                    int calculated = ((val * 73) ^ 0x5F3759DF) * 13 + 98765432;
                    return (calculated.abs() % 100000000).toString().padLeft(8, '0');
                } else {
                    // Standard 6-Digit Vendor OTP
                    int calculated = (val + 1109) ^ 3338;
                    return (calculated % 1000000).toString().padLeft(6, '0');
                }
            }

            void onKey(String key) {
              if (key == 'BACK') {
                if (pin.isNotEmpty) setState(() => pin = pin.substring(0, pin.length - 1));
              } else if (key == 'ENTER') {
                final expected = calculateExpected(challenge);
                if (pin == expected) {
                  Navigator.pop(context);
                  onValid();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('KODE SALAH! AKSES DITOLAK.'),
                    backgroundColor: MetroColors.error,
                    duration: Duration(seconds: 1),
                  ));
                  setState(() => pin = "");
                }
              } else if (key == 'CLOSE') {
                 Navigator.pop(context);
              } else {
                int maxLen = isRefund ? 8 : 6;
                if (pin.length < maxLen) setState(() => pin += key);
              }
            }
            
            Widget infoSection = Container(
                padding: const EdgeInsets.all(32),
                color: MetroColors.white,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Row(children: [
                            Icon(isRefund ? Icons.undo : Icons.security, color: isRefund ? Colors.red : MetroColors.primary, size: 32),
                            const SizedBox(width: 16),
                            Expanded(child: Text(isRefund ? 'OTORISASI REFUND' : 'SECURITY CHECK', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: MetroColors.text), overflow: TextOverflow.ellipsis))
                        ]),
                        const SizedBox(height: 24),
                        Text(isRefund ? 'AREA DILINDUNGI OTP REFUND (LV2).' : 'AREA DILINDUNGI OTP VENDOR.', style: const TextStyle(fontSize: 11.7, color: Colors.black38, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 32),
                        Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                color: (isRefund ? Colors.red : MetroColors.primary).withOpacity(0.05),
                                border: Border.all(color: (isRefund ? Colors.red : MetroColors.primary).withOpacity(0.1))
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text('NOMOR RESPON (CHALLENGE)', style: TextStyle(fontWeight: FontWeight.w900, color: isRefund ? Colors.red : MetroColors.primary, fontSize: 10.8, letterSpacing: 1)),
                                    const SizedBox(height: 12),
                                    Text(challenge, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: MetroColors.text, letterSpacing: 4)),
                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 16),
                                    const Text('INSTRUKSI:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9.9, color: Colors.black38)),
                                    const SizedBox(height: 8),
                                    Text('1. KIRIM NOMOR DIATAS KE ${isRefund ? 'OWNER (REFUND)' : 'VENDOR'}', style: const TextStyle(fontSize: 9.9, color: MetroColors.text, fontWeight: FontWeight.bold)),
                                    Text('2. MASUKKAN ${isRefund ? '8' : '6'} DIGIT OTP YANG DIBERIKAN', style: const TextStyle(fontSize: 9.9, color: MetroColors.text, fontWeight: FontWeight.bold)),
                                ],
                            ),
                        ),
                    ],
                ),
            );

            Widget inputSection = Container(
                padding: const EdgeInsets.all(24),
                color: isRefund ? Colors.red : MetroColors.primary,
                child: Column(
                    children: [
                        const Text('MASUKKAN PIN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white70, fontSize: 10.8)),
                        const SizedBox(height: 24),
                        // VISIBLE PIN BOXES
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(isRefund ? 8 : 6, (index) {
                              bool hasChar = pin.length > index;
                              String char = hasChar ? pin[index] : "";
                              return Container(
                                width: isRefund ? 35 : 45,
                                height: 55,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: hasChar ? (isRefund ? Colors.orange : MetroColors.secondary) : Colors.white24,
                                    width: 2
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  char,
                                  style: TextStyle(
                                    fontSize: isRefund ? 20 : 28, 
                                    fontWeight: FontWeight.w900, 
                                    color: isRefund ? Colors.red : MetroColors.primary
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white24, height: 1),
                        Expanded(child: _Numpad(onKey: onKey))
                    ],
                ),
            );

            return Dialog(
              backgroundColor: MetroColors.white,
              insetPadding: const EdgeInsets.all(20), 
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              child: SizedBox(
                  width: isLandscape ? 800 : 400,
                  height: isLandscape ? 450 : 650,
                  child: isLandscape 
                      ? Row(
                          children: [
                              Expanded(flex: 4, child: infoSection),
                              Expanded(flex: 5, child: inputSection)
                          ],
                      )
                      : Column(
                          children: [
                              Expanded(flex: 5, child: inputSection),
                              Expanded(flex: 4, child: infoSection),
                          ],
                      )
              ),
            );
          },
        );
      });
}

class _Numpad extends StatelessWidget {
  final Function(String) onKey;
  const _Numpad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
            Expanded(
                child: Column(
                    children: [
                        Expanded(child: Row(children: ['1','2','3'].map(_btn).toList())),
                        Expanded(child: Row(children: ['4','5','6'].map(_btn).toList())),
                        Expanded(child: Row(children: ['7','8','9'].map(_btn).toList())),
                        Expanded(child: Row(children: [
                            _keyBtn('CLOSE', MetroColors.error),
                            _btn('0'),
                            _keyBtn('BACK', MetroColors.kioskPrimary),
                        ])),
                    ]
                )
            ),
            const SizedBox(height: 8),
            MetroButton(
                label: 'VERIFIKASI & LANJUT', 
                onPressed: () => onKey('ENTER'),
                isLarge: true,
                color: MetroColors.retailPrimary, // Green for action
                textColor: Colors.white,
            ),
        ]
    );
  }
  
  Widget _btn(String label) {
      return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4), 
            child: Material(
                color: Colors.white, // Solid white for visibility
                elevation: 2,
                child: InkWell(
                    onTap: () => onKey(label),
                    child: Center(
                        child: Text(label, style: const TextStyle(fontSize: 21.6, fontWeight: FontWeight.w900, color: MetroColors.primary))
                    )
                ),
            )
          )
      );
  }
  
  Widget _keyBtn(String val, Color color) {
      return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4), 
            child: Material(
                color: color,
                elevation: 2,
                child: InkWell(
                    onTap: () => onKey(val),
                    child: Center(
                        child: Icon(
                            val == 'BACK' ? Icons.backspace : Icons.close, 
                            color: MetroColors.white, 
                            size: 24
                        )
                    )
                ),
            )
          )
      );
  }
}

void showPowerfulLoader(BuildContext context, {String message = 'MEMPROSES DATA...'}) {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (ctx) => PowerfulLoader(message: message)
    );
}

class PowerfulLoader extends StatelessWidget {
  final String message;
  const PowerfulLoader({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final logoSize = screenHeight * 0.25; // 1/4 of screen height

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Center(
        child: Container(
          width: 450, // Slightly wider to accommodate larger logo
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              )
            ],
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonaposLoader(size: logoSize),
              const SizedBox(height: 40),
              const Text(
                'SISTEM SEDANG BEKERJA',
                style: TextStyle(
                  color: MetroColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message.toUpperCase(),
                style: TextStyle(
                  color: MetroColors.primary.withOpacity(0.8),
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ClipRRect(
                child: LinearProgressIndicator(
                  backgroundColor: MetroColors.primary.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(MetroColors.primary),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


Future showAppModal(BuildContext context, {required String title, required String message, bool isError = false, Widget? extraWidget}) {
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 60),
            child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                decoration: const BoxDecoration(
                    color: MetroColors.white,
                    borderRadius: BorderRadius.zero,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 60, offset: Offset(0, 20))]
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Container(
                            height: 5,
                            color: isError ? MetroColors.error : MetroColors.retailPrimary,
                        ),
                        Padding(
                            padding: const EdgeInsets.fromLTRB(48, 48, 48, 32),
                            child: Column(
                                children: [
                                    Icon(
                                        isError ? Icons.error_outline : Icons.check_circle_outline, 
                                        color: isError ? MetroColors.error : MetroColors.retailPrimary, 
                                        size: 72
                                    ),
                                    const SizedBox(height: 32),
                                    Text(
                                        title.toUpperCase(),
                                        style: const TextStyle(color: MetroColors.text, fontWeight: FontWeight.w900, letterSpacing: 2.5, fontSize: 16.2),
                                        textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                        message.toUpperCase(),
                                        style: const TextStyle(color: Colors.black26, fontWeight: FontWeight.w900, fontSize: 10.8, height: 1.5, letterSpacing: 1),
                                        textAlign: TextAlign.center,
                                    ),
                                    if (extraWidget != null) ...[
                                        const SizedBox(height: 16),
                                        extraWidget,
                                    ],
                                    const SizedBox(height: 48),
                                    SizedBox(
                                        width: double.infinity,
                                        height: 64,
                                        child: MetroButton(
                                            label: 'OK', 
                                            onPressed: () => Navigator.pop(ctx),
                                            color: MetroColors.accent,
                                            textColor: Colors.white,
                                            isSecondary: false,
                                        ),
                                    )
                                ],
                            ),
                        ),
                    ],
                ),
            ),
        ),
    );
}

void showDebugErrorDialog(BuildContext context, {required String title, required String error}) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => DebugErrorDialog(title: title, error: error),
    );
}

class DebugErrorDialog extends StatelessWidget {
    final String title;
    final String error;

    const DebugErrorDialog({super.key, required this.title, required this.error});

    @override
    Widget build(BuildContext context) {
        return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                decoration: const BoxDecoration(
                    color: MetroColors.white,
                    borderRadius: BorderRadius.zero,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 60, offset: Offset(0, 20))]
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Container(
                            height: 5,
                            color: MetroColors.error,
                        ),
                        Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Row(
                                        children: [
                                            const Icon(Icons.bug_report, color: MetroColors.error, size: 28),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: Text(
                                                    title.toUpperCase(),
                                                    style: const TextStyle(color: MetroColors.text, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
                                                ),
                                            ),
                                            IconButton(
                                                icon: const Icon(Icons.close),
                                                onPressed: () => Navigator.pop(context),
                                            )
                                        ],
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                        'DETAIL KESALAHAN (SILAKAN SALIN DAN KIRIM KE VENDOR):',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                        width: double.infinity,
                                        height: 250,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.05),
                                            border: Border.all(color: Colors.black12),
                                        ),
                                        child: SingleChildScrollView(
                                            child: SelectableText(
                                                error,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: MetroColors.text,
                                                    fontFamily: 'monospace'
                                                ),
                                            ),
                                        ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                        children: [
                                            Expanded(
                                                child: MetroButton(
                                                    label: 'SALIN DETAIL',
                                                    icon: Icons.copy,
                                                    onPressed: () {
                                                        Clipboard.setData(ClipboardData(text: error));
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DETAIL KESALAHAN DISALIN')));
                                                    },
                                                    color: MetroColors.secondary,
                                                    isLarge: false,
                                                ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: MetroButton(
                                                    label: 'KIRIM KE VENDOR',
                                                    icon: Icons.send,
                                                    onPressed: () async {
                                                        final text = Uri.encodeComponent("SISTEM ERROR: $title\n\n$error");
                                                        final url = "https://wa.me/628123456789?text=$text";
                                                        if (await canLaunchUrl(Uri.parse(url))) {
                                                            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                                        }
                                                    },
                                                    color: MetroColors.primary,
                                                    isLarge: false,
                                                ),
                                            ),
                                        ],
                                    )
                                ],
                            ),
                        ),
                    ],
                ),
            ),
        );
    }
}

class DonaposFooter extends StatelessWidget {
  final Color textColor;
  const DonaposFooter({super.key, this.textColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                Text('Powered by ', style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 9.sp, fontWeight: FontWeight.bold)),
                Text('DONA®', style: TextStyle(color: textColor.withOpacity(0.9), fontWeight: FontWeight.w900, fontSize: 10.sp, letterSpacing: 0.5.sc)),
            ]
        ),
        SizedBox(height: 2.sc),
        Text('Digital Otomasi Niaga Aplikasi', style: TextStyle(color: textColor.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 8.sp, letterSpacing: 0.5.sc)),
      ],
    );
  }
}
