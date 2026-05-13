
class PrinterUtils {
  static const int esc = 0x1B;
  
  /// Gets font command bytes based on settings
  /// type: 0 = Standard (Font A)
  /// type: 1 = Condensed (Font B)
  /// type: 2 = Condensed Double Height (Font B + DH)
  static List<int> getFontBytes(int type, {bool bold = false}) {
     int n = 0x00;
     
     if (type == 1) n = 0x01; // Font B (Condensed)
     else if (type == 2) n = 0x01 | 0x10; // Font B + Double Height
     // 0 is Standard (Font A): 0x00
     
     if (bold) n |= 0x08; // Add Bold Bit
     
     return [esc, 0x21, n];
  }
  
  /// Gets max characters per line for current font type on 58mm printer
  /// Font A (Standard): ~32 chars
  /// Font B (Condensed): ~42 chars
  static int getMaxChars(int type) {
    if (type == 0) return 32;
    return 42; // Both Condensed types use Font B width
  }

  /// Alignment: 0=Left, 1=Center, 2=Right
  static List<int> getAlignBytes(int align) {
      // ESC a n
      return [esc, 0x61, align];
  }

  static List<int> getNewLineBytes() {
      return [0x0A];
  }
  
  static List<int> textToBytes(String text) {
      return text.codeUnits;
  }
}
