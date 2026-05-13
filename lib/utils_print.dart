import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class PrintHelper {
  /// Converts an image file to ESC/POS raster byte array
  static Future<Uint8List?> generateImageBytes(String path, {int paperSize = 58, double ratio = 0.66}) async {
    try {
      final File file = File(path);
      if (!file.existsSync()) return null;

      final Uint8List bytes = await file.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      
      if (decoded == null) return null;

      // Dots per line: 58mm = 384, 80mm = 576
      int fullWidth = (paperSize == 80) ? 576 : 384;

      // 1. Convert to a standard format (uint8, 4 channels) to avoid issues with specialized formats
      img.Image image = decoded.convert(format: img.Format.uint8, numChannels: 4);

      // 2. Aggressive Trim (removes empty alpha/white space around logo)
      image = img.trim(image, mode: img.TrimMode.topLeftColor);

      // 3. Resize based on ratio
      int targetWidth = (fullWidth * ratio).toInt();
      
      // OPTIMIZATION: Many printers prefer widths that are multiples of 8 or 16
      targetWidth = (targetWidth ~/ 8) * 8;
      if (targetWidth < 8) targetWidth = 8;

      image = img.copyResize(image, width: targetWidth, interpolation: img.Interpolation.linear);

      // 4. Convert to Grayscale & Binarize for clean print
      image = img.grayscale(image);
      // image = img.contrast(image, contrast: 1.5); // Slightly boost contrast

      // 5. Generate ESC/POS commands
      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize == 80 ? PaperSize.mm80 : PaperSize.mm58, profile);
      
      List<int> bytesList = [];
      // NO INIT HERE - Let the caller handle it to avoid resetting settings repeatedly
      // bytesList.addAll([27, 64]); 
      
      // Center Alignment
      bytesList.addAll([27, 97, 1]); 
      
      // Image command (Raster is standard for clear logos)
      bytesList.addAll(generator.imageRaster(image));
      
      // Add a couple of New Lines after the image to prevent text overlapping or being cut
      bytesList.addAll([10, 10]); // LF, LF
      
      // Reset to Left Align for subsequent text
      bytesList.addAll([27, 97, 0]);

      return Uint8List.fromList(bytesList);
    } catch (e) {
      print("[PrintHelper] Error: $e");
      return null;
    }
  }

  /// Processes and saves an image optimized for the printer
  static Future<String?> processAndSaveLogo(String inputPath, int paperSize, {double ratio = 0.66}) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      int fullWidth = (paperSize == 80) ? 576 : 384;
      int targetWidth = (fullWidth * ratio).toInt();
      
      // Ensure specific multiple of 8 for printer compatibility
      targetWidth = (targetWidth ~/ 8) * 8;
      if (targetWidth < 8) targetWidth = 8;

      img.Image image = decoded.convert(format: img.Format.uint8, numChannels: 4);
      image = img.trim(image, mode: img.TrimMode.topLeftColor);
      image = img.copyResize(image, width: targetWidth, interpolation: img.Interpolation.linear);
      image = img.grayscale(image);

      final directory = await File(inputPath).parent.path;
      final fileName = "optimized_logo_${paperSize}mm_${(ratio*100).toInt()}.png";
      final outputPath = "$directory/$fileName";
      final outFile = File(outputPath);
      await outFile.writeAsBytes(img.encodePng(image));
      return outputPath;
    } catch (e) {
      print("[PrintHelper] Process & Save Error: $e");
      return null;
    }
  }
}
