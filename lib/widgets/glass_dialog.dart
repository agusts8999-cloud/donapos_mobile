import 'package:donapos_mobile/design_system.dart';

class GlassDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget content;
  final double? width;
  final double? height;
  final Color iconColor;
  final Color? backgroundColor;
  final Color? titleColor;
  final List<Widget>? actions;
  final Widget? footer;

  const GlassDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    this.width,
    this.height,
    this.iconColor = MetroColors.primary,
    this.backgroundColor,
    this.titleColor,
    this.actions,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: width,
        height: height,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.grey[200],
          border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 10))]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Top Accent Bar
            Container(height: 4, color: iconColor),
            
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title.toUpperCase(), 
                      style: TextStyle(
                        color: titleColor ?? MetroColors.text, 
                        fontWeight: FontWeight.w900, 
                        fontSize: 16.2,
                        letterSpacing: 2
                      )
                    ),
                  ),
                  if (actions != null) ...actions!,
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black26),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: content,
              ),
            ),
            
            if (footer != null) 
              Padding(
                padding: const EdgeInsets.all(24),
                child: footer,
              )
            else
              const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
