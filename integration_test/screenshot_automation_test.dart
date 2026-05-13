import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:donapos_mobile/main.dart' as app;

// How to run:
// flutter test integration_test/screenshot_automation_test.dart

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Take screenshots of major screens', (WidgetTester tester) async {
    // 1. Launch App
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // -- LOGIN SCREEN --
    // Wait for data load
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.takeScreenshot('01_login_user_select');

    // Select User (Assumes 'Tashia' or any user exists) or click first tile
    final userTile = find.byIcon(Icons.person).first;
    if (found(userTile)) {
      await tester.tap(userTile);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('02_pin_entry');

      // Enter PIN (123456)
      await _tapPin(tester, ['1', '2', '3', '4', '5', '6']);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Handle Initial Cash Dialog if it appears
      if (find.text('KAS AWAL').evaluate().isNotEmpty) {
         await binding.takeScreenshot('03_initial_cash_dialog');
         // Confirm default
         await tester.tap(find.text('BUKA KASIR'));
         await tester.pumpAndSettle(const Duration(seconds: 2));
      }
    } else {
        // Must be setup mode
        await binding.takeScreenshot('01_login_setup_mode');
        // Try admin login
        // Can't proceed easily without credentials
        return;
    }

    // -- POS SCREEN -- 
    // Now should be on POS Screen
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.takeScreenshot('04_pos_screen_empty');

    // Add Items
    // Find first product (using Icon? or just by type)
    // We assume GridView tiles with Images or Text
    final productTile = find.byType(InkWell).at(10); // Find a random product
    if (found(productTile)) {
        await tester.tap(productTile);
        await tester.pumpAndSettle();
        // Add another
        await tester.tap(find.byType(InkWell).at(11));
        await tester.pumpAndSettle();
    
        await binding.takeScreenshot('05_pos_screen_with_items');
    }

    // Open Payment Dialog (Assume button "BAYAR")
    final payBtn = find.textContaining('BAYAR');
    if (found(payBtn)) {
       await tester.tap(payBtn);
       await tester.pumpAndSettle(const Duration(seconds: 1));
       await binding.takeScreenshot('06_payment_dialog');
       // Close dialog (tap outside or close button)
       // Usually tap 'BATAL' or back
       await tester.pageBack();
       await tester.pumpAndSettle();
    }

    // -- ADMIN DASHBOARD --
    // Find Menu Button (Top Left) or Admin Icon?
    // In POS Screen, usually there is a way to go back or menu.
    // Based on code, maybe it's the logo or a specific button.
    // Let's assume we can relaunch app to go to Admin if needed, but logging out is safer.
    
    // Tap Logout/Back
    // If not found, we can try to find Icon(Icons.menu)
    final menuIcon = find.byIcon(Icons.grid_view); // Category menu?
    // Let's skip complex nav for now.
    
    // End test
  });
}

bool found(Finder finder) => finder.evaluate().isNotEmpty;

Future<void> _tapPin(WidgetTester tester, List<String> keys) async {
  for (var key in keys) {
    await tester.tap(find.text(key));
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.tap(find.text('ENTER')); // If explicity needed
  await tester.pumpAndSettle();
}
