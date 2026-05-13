package com.example.donapos_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.util.Log
import com.szsicod.print.escpos.PrinterAPI
import com.szsicod.print.io.*
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.donapos.mobile/icod_printer"
    private var printer: PrinterAPI? = null

    companion object {
        init {
            try {
                System.loadLibrary("usb1.0")
                System.loadLibrary("serial_icod")
                System.loadLibrary("image_icod")
            } catch (e: Exception) {
                Log.e("iCodPrinter", "Error loading libraries: ${e.message}")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val type = call.argument<String>("type") ?: "usb" // "usb" or "serial"
                    val path = call.argument<String>("path") ?: "/dev/ttyS0"
                    val baudrate = call.argument<Int>("baudrate") ?: 115200
                    connectPrinter(type, path, baudrate, result)
                }
                "disconnect" -> {
                    disconnectPrinter(result)
                }
                "printText" -> {
                    val text = call.argument<String>("text")
                    printText(text, result)
                }
                "printRaw" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    printRaw(bytes, result)
                }
                "cutPaper" -> {
                    cutPaper(result)
                }
                "isConnected" -> {
                    result.success(printer?.isConnect ?: false)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun connectPrinter(type: String, path: String, baudrate: Int, result: MethodChannel.Result) {
        if (printer == null) {
            printer = PrinterAPI.getInstance()
        }

        if (printer?.isConnect == true) {
            printer?.disconnect()
        }

        Thread {
            val io: InterfaceAPI? = when (type) {
                "usb" -> USBAPI(this)
                "serial" -> SerialAPI(File(path), baudrate, 0)
                "usb_native" -> UsbNativeAPI()
                else -> null
            }

            if (io == null) {
                runOnUiThread { result.error("INVALID_TYPE", "Invalid connection type: $type", null) }
                return@Thread
            }

            val ret = printer?.connect(io) ?: -1
            runOnUiThread {
                if (ret == PrinterAPI.SUCCESS) {
                    result.success(true)
                } else {
                    result.error("CONNECT_FAILED", "Failed to connect to iCod printer: $ret", null)
                }
            }
        }.start()
    }

    private fun disconnectPrinter(result: MethodChannel.Result) {
        Thread {
            printer?.disconnect()
            runOnUiThread { result.success(true) }
        }.start()
    }

    private fun printText(text: String?, result: MethodChannel.Result) {
        if (printer?.isConnect != true) {
            runOnUiThread { result.error("NOT_CONNECTED", "Printer not connected", null) }
            return
        }
        Thread {
            try {
                printer?.printString(text, "GBK", true)
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("PRINT_ERROR", e.message, null) }
            }
        }.start()
    }

    private fun printRaw(bytes: ByteArray?, result: MethodChannel.Result) {
        if (printer?.isConnect != true) {
            runOnUiThread { result.error("NOT_CONNECTED", "Printer not connected", null) }
            return
        }
        Thread {
            try {
                printer?.sendOrder(bytes)
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("PRINT_ERROR", e.message, null) }
            }
        }.start()
    }

    private fun cutPaper(result: MethodChannel.Result) {
        if (printer?.isConnect != true) {
            runOnUiThread { result.error("NOT_CONNECTED", "Printer not connected", null) }
            return
        }
        Thread {
            try {
                printer?.cutPaper(66, 0)
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("CUT_ERROR", e.message, null) }
            }
        }.start()
    }

    override fun onDestroy() {
        printer?.disconnect()
        super.onDestroy()
    }
}
