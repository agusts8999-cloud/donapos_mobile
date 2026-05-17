import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Top-level function for Workmanager
@pragma('vm:entry-point') // Mandatory if App is obfuscated or using Flutter 3.10+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    print("[Workmanager] Native called background task: $task");

    if (task == 'sync_transactions_task') {
      try {
        final apiService = ApiService();
        print("[Workmanager] Starting Sync Transactions...");
        final result = await apiService.syncTransactions();
        print("[Workmanager] Sync finished. Count: $result");

        print("[Workmanager] Starting Sync Attendances...");
        await apiService.syncAttendances();
      } catch (err) {
        print("[Workmanager] Sync failed: $err");
        return Future.value(false);
      }
    }

    return Future.value(true);
  });
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ApiService _apiService = ApiService();
  Timer? _timer;
  bool _foregroundSyncRunning = false;

  void startPeriodicSync() async {
    final prefs = await SharedPreferences.getInstance();
    bool enabled = prefs.getBool('auto_posting_enabled') ?? true;

    if (!enabled) {
      print('[SyncService] Periodic sync is disabled by user.');
      return;
    }

    _startForegroundTimer();

    if (Platform.isAndroid || Platform.isIOS) {
      _initBackgroundSync();
    } else {
      print('[SyncService] Background Workmanager skipped on this platform.');
    }
  }

  void _startForegroundTimer() async {
    if (_timer != null && _timer!.isActive) return;

    final prefs = await SharedPreferences.getInstance();
    int interval = prefs.getInt('auto_posting_interval') ?? 10;

    print(
        '[SyncService] Starting foreground periodic sync (every $interval minutes)');
    await _runForegroundSync();

    _timer = Timer.periodic(Duration(minutes: interval), (timer) async {
      print('[SyncService] Running foreground sync at ${DateTime.now()}');
      await _runForegroundSync();
    });
  }

  Future<void> _runForegroundSync() async {
    if (_foregroundSyncRunning) {
      print('[SyncService] Foreground sync skipped: already in progress');
      return;
    }
    _foregroundSyncRunning = true;
    try {
      await _apiService.syncTransactions();
      await _apiService.syncAttendances();
    } catch (e) {
      print('[SyncService] Foreground sync error: $e');
    } finally {
      _foregroundSyncRunning = false;
    }
  }

  Future<void> _initBackgroundSync() async {
    final prefs = await SharedPreferences.getInstance();
    int interval = prefs.getInt('auto_posting_interval') ?? 10;

    int bgInterval = interval < 15 ? 15 : interval;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );

      await Workmanager().registerPeriodicTask(
        "donapos_sync_transactions",
        "sync_transactions_task",
        frequency: Duration(minutes: bgInterval),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(seconds: 10),
      );

      print(
          '[SyncService] Background Workmanager Registered (Every $bgInterval mins)');
    } catch (e) {
      print('[SyncService] Failed to init Workmanager: $e');
    }
  }

  void restartSync() {
    stopPeriodicSync();
    startPeriodicSync();
  }

  void stopPeriodicSync() {
    _timer?.cancel();
    _timer = null;
    print('[SyncService] Foreground sync stopped');
  }
}
