import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:donapos_mobile/models.dart';
import 'package:intl/intl.dart';

class LabelPrinterUtil {
  // Check Connection Status
  static Future<bool> get isConnected async => await PrintBluetoothThermal.connectionStatus;

  // Get Paired Devices
  static Future<List<BluetoothInfo>> getBondedDevices() async {
      try {
          return await PrintBluetoothThermal.pairedBluetooths;
      } catch (e) {
          print("Error getting bonded devices: $e");
          return [];
      }
  }

  // Connect to Device by MAC Address
  static Future<bool> connect(String mac) async {
    try {
        // Disconnect any existing connection first to be safe
        await disconnect();
        return await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    } catch (e) {
        print("Connect Error: $e");
        return false;
    }
  }

  // Disconnect
  static Future<bool> disconnect() async {
      try {
          return await PrintBluetoothThermal.disconnect;
      } catch (e) {
          return false;
      }
  }

  // Send Raw CPCL Data
  static Future<bool> printRaw(String cpclData) async {
      bool connected = await isConnected;
      if (!connected) return false;
      
      // Use Latin1 to safely encode ASCII CPCL commands
      return await PrintBluetoothThermal.writeBytes(Uint8List.fromList(latin1.encode(cpclData)));
  }

  // Test Print Function
  static Future<void> printTest(String address) async {
      bool connected = await connect(address);
      if (!connected) throw "Gagal terhubung ke printer";
      
      try {
          String cpcl = "! 0 200 200 260 1\r\n"
                        "PAGE-WIDTH 384\r\n"
                        "CENTER\r\n"
                        "TEXT 4 3 0 10 TEST PBT CPCL\r\n"
                        "TEXT 7 0 0 60 CONNECTION OK\r\n"
                        "BARCODE 128 1 1 50 150 50 123456\r\n"
                        "PRINT\r\n";
          
          await printRaw(cpcl);
          await Future.delayed(const Duration(seconds: 2));
      } finally {
          await disconnect();
      }
  }

  // Transaction Label Printing
  static Future<void> printTransactionLabels(
    String address, 
    List<CartItem> items, 
    String businessName, 
    String cashierName
  ) async {
     bool ok = await connect(address);
     if (!ok) return;

     try {
        for (var item in items) {
           if (item.product.needsLabel != 1) continue;

           for (int i=0; i<item.qty; i++) {
               // Sanitize Product Name
               String pname = item.product.name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9 a-z\-\.\(\)]'), '');
               
               String cpcl = "! 0 200 200 260 1\r\n"
                             "PAGE-WIDTH 384\r\n"
                             "CENTER\r\n"
                             "TEXT 7 0 0 10 ${businessName.toUpperCase()}\r\n"
                             "LEFT\r\n"
                             "TEXT 4 0 10 50 $pname\r\n";
               
               int y = 90;
               if (item.selectedModifiers.isNotEmpty) {
                   String mods = item.selectedModifiers.map((m) => m.name.replaceAll(RegExp(r'[^A-Z0-9 a-z]'), '')).join(", ");
                   if (mods.length > 28) mods = "${mods.substring(0, 28)}..";
                   cpcl += "TEXT 0 2 10 $y ($mods)\r\n";
                   y += 35;
               }

               String footer = "$cashierName - ${DateFormat('HH:mm').format(DateTime.now())}";
               cpcl += "TEXT 0 2 10 $y $footer\r\n"
                       "RIGHT\r\n"
                       "TEXT 0 2 10 $y ${i+1}/${item.qty}\r\n"
                       "PRINT\r\n";

               await printRaw(cpcl);
               await Future.delayed(const Duration(milliseconds: 500));
           }
        }
     } catch (e) {
        print("Label Print Error: $e");
     } finally {
        await disconnect();
     }
  }
}
