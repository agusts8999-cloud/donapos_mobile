import 'dart:ui';
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
import 'package:donapos_mobile/app_route_observer.dart';
import 'package:donapos_mobile/services/logger_service.dart';

import 'package:donapos_mobile/language_provider.dart';
import 'package:donapos_mobile/location_service.dart';
import 'package:donapos_mobile/utils_scaler.dart';

void _configureImageCache() {
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSize = 50;
  cache.maximumSizeBytes = 50 << 20; // 50 MB
}

void _configureErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    LoggerService.instance.logError(
      'FlutterError: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    LoggerService.instance.logError('Uncaught async error', error, stack);
    return true;
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LoggerService.instance.init();
  _configureImageCache();
  _configureErrorHandlers();

  await ScreenScaler.loadSettings();

  if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WakelockPlus.enable();
  }

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
        navigatorObservers: [appRouteObserver],
        home: const SplashScreen(),
        routes: {
          'customer_display': (context) => const CustomerDisplayScreen(),
        },
      ),
    );
  }
}
