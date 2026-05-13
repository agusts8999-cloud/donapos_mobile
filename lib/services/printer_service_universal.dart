import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as bt;
import 'package:donapos_mobile/icod_printer.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PrinterType { bluetooth, icod, windowsUsb, windowsSerial, windowsLan }

class UniversalPrinterService {
  static final UniversalPrinterService _instance = UniversalPrinterService._internal();
  factory UniversalPrinterService() => _instance;
  UniversalPrinterService._internal();

  // Mobile Handlers
  final bt.BlueThermalPrinter _btPrinter = bt.BlueThermalPrinter.instance;
  
  // Windows/Unified Handlers
  var _printerManager = PrinterManager.instance;
  
  bool _isConnected = false;
  PrinterType _currentType = PrinterType.bluetooth;

  Future<bool> get isConnected async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (_currentType == PrinterType.bluetooth) return await _btPrinter.isConnected ?? false;
      if (_currentType == PrinterType.icod) return await IcodPrinter.isConnected();
    } else if (Platform.isWindows) {
      // Logic for Windows connection status via flutter_pos_printer_platform
      return _isConnected; 
    }
    return false;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final typeStr = prefs.getString('printer_settings_type') ?? 'bluetooth';
    
    if (typeStr == 'bluetooth') _currentType = PrinterType.bluetooth;
    else if (typeStr == 'icod') _currentType = PrinterType.icod;
    else if (typeStr == 'win_usb') _currentType = PrinterType.windowsUsb;
    else if (typeStr == 'win_lan') _currentType = PrinterType.windowsLan;
    else if (typeStr == 'win_serial') _currentType = PrinterType.windowsSerial;
  }

  Future<void> sendBytes(Uint8List bytes) async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (_currentType == PrinterType.bluetooth) {
        await _btPrinter.writeBytes(bytes);
      } else if (_currentType == PrinterType.icod) {
        await IcodPrinter.printRaw(bytes);
      }
    } else if (Platform.isWindows) {
       // Send to Windows Printer via flutter_pos_printer_platform
       // This requires the printer to be connected first via its specific driver
    }
  }

  Future<void> cut() async {
     if (Platform.isAndroid || Platform.isIOS) {
      if (_currentType == PrinterType.bluetooth) {
        await _btPrinter.paperCut();
      } else if (_currentType == PrinterType.icod) {
        await IcodPrinter.cutPaper();
      }
    } else if (Platform.isWindows) {
       // Windows cut command
    }
  }
}
