import 'package:donapos_mobile/design_system.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final Color confirmColor;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'YA',
    this.cancelLabel = 'BATAL',
    this.confirmColor = MetroColors.error,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        elevation: 0,
        child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: const BoxDecoration(
                color: MetroColors.white,
                borderRadius: BorderRadius.zero,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 40, offset: Offset(0, 10))]
            ),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Container(
                        height: 5,
                        color: confirmColor,
                    ),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(40, 40, 40, 32),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                    children: [
                                        Icon(Icons.help_outline, color: confirmColor, size: 28),
                                        const SizedBox(width: 16),
                                        Expanded(
                                            child: Text(
                                                title.toUpperCase(),
                                                style: const TextStyle(color: MetroColors.text, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 18),
                                            ),
                                        ),
                                    ],
                                ),
                                const SizedBox(height: 24),
                                Text(
                                    message.toUpperCase(),
                                    style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.bold, fontSize: 11.7, height: 1.5, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 48),
                                Row(
                                    children: [
                                        Expanded(
                                            child: SizedBox(
                                                height: 56,
                                                child: TextButton(
                                                    style: TextButton.styleFrom(
                                                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                                        foregroundColor: Colors.black38,
                                                    ),
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: Text(cancelLabel.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                                                ),
                                            ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: SizedBox(
                                                height: 56,
                                                child: ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor: confirmColor,
                                                        foregroundColor: Colors.white,
                                                        elevation: 0,
                                                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                                    ),
                                                    onPressed: () => Navigator.pop(context, true),
                                                    child: Text(confirmLabel.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                                                ),
                                            ),
                                        ),
                                    ],
                                )
                            ],
                        ),
                    ),
                ],
            ),
        ),
    );
  }
}

Future<bool> showAppConfirm(BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'YA',
    String cancelLabel = 'BATAL',
    Color confirmColor = MetroColors.error,
}) async {
    return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ConfirmDialog(
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            cancelLabel: cancelLabel,
            confirmColor: confirmColor,
        ),
    ) ?? false;
}



