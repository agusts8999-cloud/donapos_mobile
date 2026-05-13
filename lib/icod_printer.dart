import 'package:flutter/services.dart';
import 'dart:typed_data';

class IcodPrinter {
  static const MethodChannel _channel = MethodChannel('com.donapos.mobile/icod_printer');

  static Future<bool> connect({String type = 'usb', String path = '/dev/ttyS0', int baudrate = 115200}) async {
    try {
      final bool success = await _channel.invokeMethod('connect', {
        'type': type,
        'path': path,
        'baudrate': baudrate,
      });
      return success;
    } catch (e) {
      print("[IcodPrinter] Connect Error: $e");
      return false;
    }
  }

  static Future<bool> connectUsb() => connect(type: 'usb');
  static Future<bool> connectSerial(String path, int baudrate) => connect(type: 'serial', path: path, baudrate: baudrate);

  static Future<bool> disconnect() async {
    try {
      final bool success = await _channel.invokeMethod('disconnect');
      return success;
    } catch (e) {
      print("[IcodPrinter] Disconnect Error: $e");
      return false;
    }
  }

  static Future<bool> isConnected() async {
    try {
      final bool connected = await _channel.invokeMethod('isConnected');
      return connected;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> printText(String text) async {
    try {
      final bool success = await _channel.invokeMethod('printText', {'text': text});
      return success;
    } catch (e) {
      print("[IcodPrinter] PrintText Error: $e");
      return false;
    }
  }

  static Future<bool> printRaw(Uint8List bytes) async {
    try {
      final bool success = await _channel.invokeMethod('printRaw', {'bytes': bytes});
      return success;
    } catch (e) {
      print("[IcodPrinter] PrintRaw Error: $e");
      return false;
    }
  }

  static Future<bool> cutPaper() async {
    try {
      final bool success = await _channel.invokeMethod('cutPaper');
      return success;
    } catch (e) {
      print("[IcodPrinter] Cut Error: $e");
      return false;
    }
  }
}
