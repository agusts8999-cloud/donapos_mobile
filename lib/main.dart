import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:donapos_mobile/screens/splash_screen.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/screens/customer_display_screen.dart';
import 'package:donapos_mobile/controllers/pos_cart_controller.dart';
import 'package:donapos_mobile/providers/pos_provider.dart';

import 'package:donapos_mobile/sync_service.dart';
import 'package:donapos_mobile/language_provider.dart';
import 'package:donapos_mobile/location_service.dart';
import 'package:donapos_mobile/utils_scaler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load Scaling Settings
  await ScreenScaler.loadSettings();
  
  // Force landscape mode & Immersive (Mobile Only)
  if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Keep the screen awake
    WakelockPlus.enable();
  }

  // Init Location Service (Desktop support depends on geolocator)
  LocationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => PosCartController()),
        ChangeNotifierProvider(create: (_) => PosProvider()),
      ],
      child: MaterialApp(
        title: 'DonaPOS_Fnb_Plus',
        debugShowCheckedModeBanner: false,
        theme: MetroDesign.theme,
        home: const SplashScreen(),
        routes: {
          'customer_display': (context) => const CustomerDisplayScreen(),
        },
      ),
    );
  }
}
