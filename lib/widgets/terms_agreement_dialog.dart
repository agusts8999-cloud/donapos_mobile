import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';

class TermsAgreementDialog extends StatefulWidget {
  final VoidCallback onContinue;

  const TermsAgreementDialog({super.key, required this.onContinue});

  @override
  State<TermsAgreementDialog> createState() => _TermsAgreementDialogState();
}

class _TermsAgreementDialogState extends State<TermsAgreementDialog> {
  bool _isChecked = false;
  final ScrollController _scrollController = ScrollController();

  List<TextSpan> _parseMarkdown(String text) {
      final List<TextSpan> spans = [];
      final parts = text.split('**');
      for (int i = 0; i < parts.length; i++) {
          if (i % 2 == 0) {
              // Normal text
              spans.add(TextSpan(text: parts[i], style: const TextStyle(color: Colors.black87, height: 1.5, fontSize: 13)));
          } else {
              // Bold text
              spans.add(TextSpan(text: parts[i], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, height: 1.5, fontSize: 13)));
          }
      }
      return spans;
  }

  @override
  Widget build(BuildContext context) {
    const String p1 = "Dengan mencentang satu checkbox persetujuan ini, saya menyatakan dan menegaskan bahwa **seluruh isi dokumen persetujuan ini merupakan satu kesatuan yang utuh, tidak terpisahkan, telah saya baca seluruhnya, saya pahami sepenuhnya, dan saya setujui secara sadar serta mengikat secara hukum**. Persetujuan ini berlaku untuk penggunaan Aplikasi **DonaPOS** baik versi **Mobile** maupun **Website / ERP**, termasuk seluruh fitur, layanan, sistem, dan pembaruan yang disediakan.";
    const String p2 = "Saya dengan ini **menyetujui dan bersedia membayar biaya langganan** sesuai paket, periode, dan harga yang berlaku pada Aplikasi DonaPOS. Saya memahami dan menyetujui bahwa **seluruh pembayaran bersifat final, mengikat, dan tidak dapat dikembalikan (non-refundable)** dengan alasan apa pun, termasuk namun tidak terbatas pada ketidaksesuaian kebutuhan, perubahan fitur, gangguan layanan, maupun penghentian layanan.";
    const String p3 = "Saya memahami dan menyetujui bahwa Aplikasi DonaPOS disediakan **SEBAGAIMANA ADANYA (AS IS)** dan **SEBAGAIMANA TERSEDIA (AS AVAILABLE)** tanpa jaminan apa pun, baik tersurat maupun tersirat. Saya menyadari bahwa **seluruh risiko penggunaan Aplikasi sepenuhnya menjadi tanggung jawab saya sendiri**, termasuk namun tidak terbatas pada kesalahan penggunaan, kesalahan input data, kehilangan atau kerusakan data, kerugian finansial, kerugian usaha, gangguan operasional, serta kerugian langsung maupun tidak langsung lainnya.";
    const String p4 = "Saya dengan ini **melepaskan, membebaskan, dan tidak akan mengajukan tuntutan, klaim, gugatan, atau permintaan ganti rugi dalam bentuk apa pun**, baik perdata, pidana, maupun administratif, terhadap DonaPOS, pemilik, pengelola, pengembang, karyawan, mitra, maupun afiliasinya, atas segala akibat yang timbul dari penggunaan atau ketidakmampuan menggunakan Aplikasi, termasuk namun tidak terbatas pada perubahan sistem, pembatasan akses, gangguan layanan, kebocoran atau kehilangan data, serta **penghentian layanan sementara maupun permanen**, sejauh diizinkan oleh hukum yang berlaku di **Republik Indonesia**.";
    const String p5 = "Saya memahami dan menyetujui bahwa persetujuan ini merupakan **persetujuan elektronik yang sah dan memiliki kekuatan hukum mengikat**, sesuai dengan ketentuan **Undang-Undang Informasi dan Transaksi Elektronik (UU ITE)** dan peraturan perundang-undangan terkait yang berlaku di Republik Indonesia. Dengan menekan tombol **Daftar / Aktifkan / Lanjutkan**, saya menyatakan bahwa persetujuan ini diberikan **secara sukarela, tanpa paksaan dari pihak mana pun**, dan dapat digunakan sebagai **alat bukti hukum yang sah**.";

    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), 
        elevation: 10,
        child: Container(
            width: 650, 
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            padding: const EdgeInsets.all(24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                    const Text(
                        'PERSETUJUAN PENGGUNAAN APLIKASI DONAPOS',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: MetroColors.primary, letterSpacing: -0.5),
                        textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Expanded(
                        child: Scrollbar(
                            thumbVisibility: true,
                            controller: _scrollController,
                            child: SingleChildScrollView(
                                controller: _scrollController,
                                padding: const EdgeInsets.only(right: 16),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        RichText(textAlign: TextAlign.justify, text: TextSpan(children: _parseMarkdown(p1))),
                                        const SizedBox(height: 12),
                                        RichText(textAlign: TextAlign.justify, text: TextSpan(children: _parseMarkdown(p2))),
                                        const SizedBox(height: 12),
                                        RichText(textAlign: TextAlign.justify, text: TextSpan(children: _parseMarkdown(p3))),
                                        const SizedBox(height: 12),
                                        RichText(textAlign: TextAlign.justify, text: TextSpan(children: _parseMarkdown(p4))),
                                        const SizedBox(height: 12),
                                        RichText(textAlign: TextAlign.justify, text: TextSpan(children: _parseMarkdown(p5))),
                                    ],
                                ),
                            ),
                        ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border.all(color: Colors.grey[300]!)
                      ),
                      padding: const EdgeInsets.all(8),
                      child: InkWell(
                          onTap: () => setState(() => _isChecked = !_isChecked),
                          child: Row(
                              children: [
                                  Checkbox(
                                      value: _isChecked, 
                                      onChanged: (v) => setState(() => _isChecked = v ?? false),
                                      activeColor: MetroColors.primary,
                                  ),
                                  const Expanded(
                                      child: Text(
                                          'Saya menyetujui Persetujuan Penggunaan Aplikasi DonaPOS',
                                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: MetroColors.text),
                                      ),
                                  ),
                              ],
                          ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    foregroundColor: Colors.grey
                                  ),
                                  child: const Text('BATAL', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 16),
                              if (_isChecked)
                                ElevatedButton(
                                    onPressed: () {
                                        Navigator.pop(context); 
                                        widget.onContinue(); 
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: MetroColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                      padding: const EdgeInsets.symmetric(horizontal: 32)
                                    ),
                                    child: const Text('LANJUTKAN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                                ),
                          ],
                      ),
                    )
                ],
            ),
        ),
    );
  }
}
