
import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/utils_ui.dart';

void showDemoRestrictionDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: MetroColors.white,
          borderRadius: BorderRadius.circular(0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              color: MetroColors.accent,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off, size: 60, color: MetroColors.accent),
                  const SizedBox(height: 24),
                  const Text(
                    'FITUR ONLINE DIBATASI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: MetroColors.text,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Anda sedang dalam Mode Demo (Offline). Fitur ini memerlukan koneksi ke server.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'SILAKAN AKTIVASI MODE FULL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: MetroColors.primary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: MetroButton(
                      label: 'MENGERTI',
                      onPressed: () => Navigator.pop(ctx),
                      color: MetroColors.primary,
                      textColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const DonaposFooter(textColor: Colors.black),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
