/// Pesan aktivasi yang ramah untuk pengguna non-teknis.
class ActivationMessages {
  static const String noInternet =
      'Periksa Wi‑Fi atau data seluler tablet, lalu coba lagi.';
  static const String serverUnreachable =
      'Server tidak terjangkau. Pastikan server bisnis aktif atau hubungi admin DonaPOS.';
  static const String invalidCode =
      'Kode aktivasi salah atau sudah dipakai. Minta kode baru di backoffice DonaPOS.';
  static const String timeout =
      'Koneksi lambat. Coba lagi dalam 1–2 menit.';
  static const String emptyUrl = 'Alamat server belum diisi.';
  static const String invalidUrl =
      'Alamat server harus diawali dengan http:// atau https://';
  static const String invalidCodeFormat =
      'Kode aktivasi harus 9 karakter (contoh: ABC-DEF-GHI).';
  static const String genericFailure =
      'Aktivasi gagal. Periksa kode dan koneksi internet, lalu coba lagi.';

  /// Format kode 9 karakter ke bentuk API: `XXX-XXX-XXX`.
  static String formatForApi(String normalizedNineChars) {
    final c = normalizedNineChars.replaceAll('-', '').trim().toUpperCase();
    if (c.length != 9) return normalizedNineChars;
    return '${c.substring(0, 3)}-${c.substring(3, 6)}-${c.substring(6, 9)}';
  }

  /// Ambil pesan untuk ditampilkan ke user (sudah ramah atau dipetakan).
  static String userMessage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return genericFailure;
    final lower = raw.toLowerCase();
    if (_looksFriendly(raw)) return raw.trim();

    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable')) {
      return noInternet;
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return timeout;
    }
    if (lower.contains('handshakeexception') || lower.contains('certificate')) {
      return 'Masalah sertifikat keamanan server. Pastikan jam tablet benar atau hubungi admin.';
    }
    if (lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('unauthorized') ||
        lower.contains('ditolak')) {
      return invalidCode;
    }
    if (lower.contains('kode') && (lower.contains('tidak valid') || lower.contains('salah'))) {
      return raw.trim();
    }
    if (lower.contains('kode') ||
        (lower.contains('activation') && lower.contains('invalid')) ||
        (lower.contains('sudah') && lower.contains('pakai'))) {
      return invalidCode;
    }
    if (lower.contains('404') || lower.contains('not found')) {
      return serverUnreachable;
    }
    if (lower.contains('tidak boleh kosong')) return emptyUrl;
    if (lower.contains('http')) return invalidUrl;

    return genericFailure;
  }

  static String fromException(Object error) {
    return userMessage(error.toString());
  }

  static String fromActivationHttp(int statusCode, {String? serverMessage}) {
    if (serverMessage != null && serverMessage.trim().isNotEmpty) {
      return userMessage(serverMessage);
    }
    if (statusCode == 401 || statusCode == 403) return invalidCode;
    if (statusCode == 404) return invalidCode;
    if (statusCode >= 500) {
      return 'Server sibuk ($statusCode). Coba lagi sebentar.';
    }
    if (statusCode >= 400) return invalidCode;
    return genericFailure;
  }

  static bool _looksFriendly(String msg) {
    final lower = msg.toLowerCase();
    return !lower.contains('exception') &&
        !lower.contains('socket') &&
        !lower.contains('http/') &&
        !lower.contains('connector/api') &&
        !lower.contains('error:') &&
        msg.length < 200;
  }
}
