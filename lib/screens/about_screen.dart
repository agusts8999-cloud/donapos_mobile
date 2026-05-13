import 'package:flutter/material.dart';
import 'package:donapos_mobile/config.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:provider/provider.dart';
import 'package:donapos_mobile/language_provider.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: MetroColors.background,
      appBar: AppBar(
        title: Text(lp.translate('about_app'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
        backgroundColor: MetroColors.primary,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header Info
          Center(
            child: Column(
              children: [
                const Icon(Icons.shield_rounded, size: 80, color: MetroColors.primary),
                const SizedBox(height: 24),
                Text(
                  AppConfig.appName.toUpperCase(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: MetroColors.text, letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                Text(
                  '${lp.translate('version_caps')} ${AppConfig.appVersion} (BUILD ${AppConfig.buildNumber})',
                  style: const TextStyle(fontSize: 11, color: MetroColors.primary, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text(
            lp.translate('changelog_caps'),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          // Changelog List
          ...AppConfig.changelog.map((log) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${lp.translate('version_caps')} ${log['version']}'.toUpperCase(),
                        style: const TextStyle(
                             fontSize: 13, fontWeight: FontWeight.w900, color: MetroColors.primary),
                      ),
                      Text(
                        log['date'].toString().toUpperCase(),
                        style: const TextStyle(color: Colors.black26, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  ...log['changes'].map<Widget>((change) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('▪ ', style: TextStyle(color: MetroColors.primary, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(change.toString().toUpperCase(), style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold, height: 1.4))),
                          ],
                        ),
                      )).toList(),
                ],
              ),
            );
          }).toList(),
          
          const SizedBox(height: 40),
          const Center(
              child: Text('© 2026 DONAPOS ENTERPRISE SYSTEM', style: TextStyle(color: Colors.black12, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1))
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
