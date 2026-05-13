import 'package:donapos_mobile/design_system.dart';
import 'package:flutter/material.dart';

class SyncProgressDialog extends StatelessWidget {
  final String status;
  final double? progress; // 0.0 to 1.0, or null for indeterminate

  const SyncProgressDialog({
    super.key,
    required this.status,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button
      child: Dialog(
         backgroundColor: Colors.white,
         elevation: 10,
         shadowColor: Colors.black26,
         shape: const RoundedRectangleBorder(
             borderRadius: BorderRadius.all(Radius.circular(20)),
         ),
         child: Container(
             padding: const EdgeInsets.all(32),
             width: 350,
             decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20)
             ),
             child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                     // Logo
                     Container(
                         width: 100,
                         height: 100,
                         padding: const EdgeInsets.all(16),
                         decoration: BoxDecoration(
                             shape: BoxShape.circle,
                             color: Colors.white,
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.black.withOpacity(0.1),
                                 blurRadius: 20,
                                 offset: const Offset(0, 10)
                               )
                             ]
                         ),
                          child: ClipOval(
                             child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                               errorBuilder: (c, o, s) => const Icon(Icons.sync, size: 50, color: MetroColors.primary),
                             )
                         ),
                     ),
                     const SizedBox(height: 32),
                     const Text(
                         'SISTEM SEDANG BEKERJA',
                         textAlign: TextAlign.center,
                         style: TextStyle(
                             fontWeight: FontWeight.w900,
                             fontSize: 14,
                             letterSpacing: 2,
                             color: Colors.black87
                         ),
                     ),
                     const SizedBox(height: 16),
                     Text(
                         status.toUpperCase(),
                         textAlign: TextAlign.center,
                         style: const TextStyle(
                             fontWeight: FontWeight.bold,
                             fontSize: 11,
                             letterSpacing: 1,
                             color: Colors.cyan // Cyan as per screenshot
                         ),
                     ),
                     const SizedBox(height: 32),
                     ClipRRect(
                       borderRadius: BorderRadius.circular(10),
                       child: LinearProgressIndicator(
                           value: progress,
                           minHeight: 8,
                           backgroundColor: Colors.cyan.withOpacity(0.1),
                           valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
                       ),
                     )
                 ],
             ),
         ),
      ),
    );
  }
}
