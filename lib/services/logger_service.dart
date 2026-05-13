import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LoggerService {
  static final LoggerService instance = LoggerService._();
  LoggerService._();

  File? _logFile;

  Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
      
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _logFile = File('${logsDir.path}/log_$today.txt');
    } catch (e) {
      print('Logger Init Error: $e');
    }
  }

  Future<void> log(String message, {String level = 'INFO', dynamic error, StackTrace? stackTrace}) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final logEntry = '[$timestamp] [$level] $message ${error != null ? "\nError: $error" : ""} ${stackTrace != null ? "\nStack: $stackTrace" : ""}\n';
    
    print(logEntry); // Also print to console
    
    try {
      if (_logFile == null) await init();
      if (_logFile != null) {
        await _logFile!.writeAsString(logEntry, mode: FileMode.append);
      }
    } catch (e) {
      print('Failed to write to log file: $e');
    }
  }

  Future<void> logError(String message, [dynamic error, StackTrace? stackTrace]) async {
    await log(message, level: 'ERROR', error: error, stackTrace: stackTrace);
  }

  Future<void> logWarning(String message) async {
    await log(message, level: 'WARNING');
  }

  Future<String> getLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
    } catch (e) {
      return 'Error reading logs: $e';
    }
    return 'No logs found.';
  }
  
  Future<void> clearLogs() async {
     try {
       final directory = await getApplicationDocumentsDirectory();
       final logsDir = Directory('${directory.path}/logs');
       if (await logsDir.exists()) {
         await logsDir.delete(recursive: true);
       }
       await init();
     } catch (e) {
       print('Error clearing logs: $e');
     }
  }
}
