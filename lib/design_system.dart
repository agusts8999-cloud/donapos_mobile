import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:donapos_mobile/utils_scaler.dart';
export 'package:flutter/material.dart';

class GlobalSettings {
  static bool soundEnabled = false;

  static void playClick() {
    if (soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }
}

class MetroColors {
  // CLEAN LIGHT THEME (REVERTED AS PER USER PREFERENCE)
  static const Color primary = Color(0xFF00ADEF); // Light Blue (DonaPOS Primary)
  static const Color secondary = Color(0xFF0078D7);
  static const Color accent = Color(0xFF00ADEF);
  static const Color background = Color(0xFFF5F7FA); // Light Gray/White
  static const Color textDark = Colors.white; // For panels on dark background
  static const Color surface = Colors.white; // Standard surface color
  static const Color text = Color(0xFF1E1E1E); // Main text color
  static const Color error = Color(0xFFE81123);
  static const Color success = Color(0xFF107C10);
  static const Color white = Colors.white;
  static const Color white70 = Colors.white70;
  static const Color yellow = Color(0xFFFFB900);
  static const Color brown = Color(0xFFD2B48C);

  // SYSTEM COLORS
  static const Color retailPrimary = Color(0xFF107C10); // Green
  static const Color retailSecondary = Color(0xFF004B1C);
  static const Color retailAccent = Color(0xFF00B7C3);

  static const Color kioskPrimary = Color(0xFFD83B01); // Red/Orange
  static const Color kioskSecondary = Color(0xFFA80000);

  static const List<Color> productColors = [
    Color(0xFF00ADEF), // Light Blue
    Color(0xFF107C10), // Green
    Color(0xFFD83B01), // Orange/Red
    Color(0xFF603CBA), // Purple
    Color(0xFF00B7C3), // Teal
    Color(0xFFE81123), // Red
  ];
}

class MetroDesign {
  static double get primaryButtonHeight => ScreenScaler.scale(56.0);
  static double get secondaryButtonHeight => ScreenScaler.scale(48.0);
  static double get horizontalPadding => ScreenScaler.scale(16.0);
  static double get verticalPadding => ScreenScaler.scale(12.0);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: MetroColors.background,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: MetroColors.primary,
        primary: MetroColors.primary,
        secondary: MetroColors.secondary,
        error: MetroColors.error,
        surface: MetroColors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: MetroColors.primary,
        foregroundColor: MetroColors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: ScreenScaler.scale(18),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: MetroColors.white,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(fontSize: ScreenScaler.scale(24.7), fontWeight: FontWeight.bold, color: MetroColors.text, height: 1.2),
        headlineMedium: TextStyle(fontSize: ScreenScaler.scale(18.5), fontWeight: FontWeight.bold, color: MetroColors.text),
        titleLarge: TextStyle(fontSize: ScreenScaler.scale(13.9), fontWeight: FontWeight.bold, color: MetroColors.text, letterSpacing: 1.0),
        bodyLarge: TextStyle(fontSize: ScreenScaler.scale(12.3), color: MetroColors.text),
        bodyMedium: TextStyle(fontSize: ScreenScaler.scale(10.8), color: MetroColors.text),
      ),
      cardTheme: const CardThemeData(
        color: MetroColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: MetroColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: MetroColors.text,
        contentTextStyle: TextStyle(color: MetroColors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class MetroTypography {
  static TextStyle get h1 => TextStyle(fontSize: ScreenScaler.scale(24.7), fontWeight: FontWeight.w900, color: MetroColors.text, letterSpacing: 1.5);
  static TextStyle get h2 => TextStyle(fontSize: ScreenScaler.scale(18.5), fontWeight: FontWeight.w900, color: MetroColors.text, letterSpacing: 1.2);
  static TextStyle get h3 => TextStyle(fontSize: ScreenScaler.scale(13.9), fontWeight: FontWeight.w900, color: MetroColors.text, letterSpacing: 1.0);
  static TextStyle get body => TextStyle(fontSize: ScreenScaler.scale(10.8), color: MetroColors.text);
  static TextStyle get small => TextStyle(fontSize: ScreenScaler.scale(8.5), color: MetroColors.text);
}

// Atomic Widgets
class MetroButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final bool isSecondary;
  final bool isLarge;
  final bool isLoading;

  const MetroButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = MetroColors.primary,
    this.textColor = MetroColors.white,
    this.icon,
    this.isSecondary = false,
    this.isLarge = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isLarge ? 62.sc : (isSecondary ? MetroDesign.secondaryButtonHeight : MetroDesign.primaryButtonHeight),
      width: double.infinity,
      child: Material(
        color: (onPressed == null || isLoading) ? color.withOpacity(0.5) : color,
        child: InkWell(
          onTap: (onPressed == null || isLoading) ? null : () {
            GlobalSettings.playClick();
            HapticFeedback.lightImpact();
            onPressed!();
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.sc),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: isLoading 
                  ? [DonaposLoader(size: 24.sc, color: textColor)]
                  : [
                      if (icon != null) ...[
                        Icon(icon, color: textColor, size: 24.sc),
                        SizedBox(width: 6.sc), // Reduced from 12.sc
                      ],
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w900,
                          fontSize: isSecondary ? 10.0.sp : 11.5.sp,
                          letterSpacing: 1.0.sc, // Slightly reduced from 1.5.sc
                        ),
                      ),
                    ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MetroSectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  const MetroSectionTitle({super.key, required this.title, this.color = MetroColors.primary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.sc),
      child: Text(
        title.toUpperCase(), 
        style: TextStyle(color: color, fontSize: 8.5.sp, fontWeight: FontWeight.w900, letterSpacing: 2.5.sc)
      ),
    );
  }
}

class MetroPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool showBorder;

  const MetroPanel({
    super.key, 
    required this.child, 
    this.padding = const EdgeInsets.all(24),
    this.color,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding is EdgeInsets ? (padding as EdgeInsets).sc : padding,
      decoration: BoxDecoration(
        color: color ?? MetroColors.surface,
        border: showBorder ? Border.all(color: Colors.black.withOpacity(0.05), width: 1.sc) : null,
        boxShadow: color == null ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10.sc, offset: Offset(0, 4.sc))] : null,
      ),
      child: child,
    );
  }
}

class MetroTile extends StatelessWidget {
  final String label;
  final String? subLabel;
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLarge;
  final bool isHorizontal;

  const MetroTile({
    super.key,
    required this.label,
    this.subLabel,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLarge = false,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: () {
          GlobalSettings.playClick();
          HapticFeedback.lightImpact();
          onTap();
        },
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          constraints: BoxConstraints(minHeight: isHorizontal ? 42.sc : (isLarge ? 115.sc : 80.sc)),
          padding: EdgeInsets.symmetric(horizontal: 10.sc, vertical: isHorizontal ? 6.sc : 8.sc),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 6.sc)),
          ),
          child: isHorizontal 
            ? Row(
                children: [
                   _buildIcon(),
                   SizedBox(width: 12.sc),
                   Expanded(child: _buildText()),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   _buildIcon(),
                   SizedBox(height: 8.sc),
                   _buildText(),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
      return Container(
         padding: EdgeInsets.all(6.sc),
         decoration: BoxDecoration(
           color: color.withOpacity(0.08),
           borderRadius: BorderRadius.zero,
         ),
         child: icon is IconData 
            ? Icon(icon, color: color, size: 20.sc)
            : Image.asset(icon as String, width: 20.sc, height: 20.sc, color: color),
       );
  }

  Widget _buildText() {
      return Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         mainAxisSize: MainAxisSize.min,
         children: [
           FittedBox(
             fit: BoxFit.scaleDown,
             alignment: Alignment.centerLeft,
             child: Text(
               label.toUpperCase(), 
               style: TextStyle(
                   color: MetroColors.text, 
                   fontWeight: FontWeight.w900, 
                   fontSize: 8.5.sp,
                   letterSpacing: 0.8.sc,
                   height: 1.0
               ),
             ),
           ),
           if (subLabel != null) ...[
              SizedBox(height: 2.sc),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  subLabel!.toUpperCase(), 
                  style: TextStyle(color: Colors.black26, fontSize: 6.5.sp, fontWeight: FontWeight.w900), 
                ),
              ),
           ],
         ],
      );
  }
}

class MetroInput extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? hint;
  final Function(String)? onChanged;

  const MetroInput({
    super.key,
    required this.label,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.hint,
    this.onChanged,
  });

  @override
  State<MetroInput> createState() => _MetroInputState();
}

class _MetroInputState extends State<MetroInput> {
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: TextStyle(
            fontSize: 7.7.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5.sc,
            color: Colors.black54,
          ),
        ),
        SizedBox(height: 8.sc),
        Container(
          height: 50.sc,
          decoration: BoxDecoration(
            color: MetroColors.white,
            border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.sc),
          ),
          child: TextField(
            controller: widget.controller,
            obscureText: _obscureText,
            keyboardType: widget.keyboardType,
            onChanged: widget.onChanged,
            style: TextStyle(fontSize: 10.8.sp, color: MetroColors.text, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: widget.hint?.toUpperCase(),
              hintStyle: TextStyle(color: Colors.black26, fontSize: 9.3.sp),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.sc, vertical: 15.sc),
              border: InputBorder.none,
              suffixIcon: widget.isPassword ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.black26,
                  size: 20.sc,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              ) : null,
            ),
          ),
        ),
      ],
    );
  }
}
class DonaposLoader extends StatefulWidget {
  final double size;
  final Color? color;
  const DonaposLoader({super.key, this.size = 50, this.color});

  @override
  State<DonaposLoader> createState() => _DonaposLoaderState();
}

class _DonaposLoaderState extends State<DonaposLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Image.asset(
        'assets/images/logo.png',
        width: widget.size.sc,
        height: widget.size.sc,
        fit: BoxFit.contain,
        color: widget.color,
      ),
    );
  }
}


extension EdgeInsetsScale on EdgeInsets {
  EdgeInsets get sc => copyWith(
    left: ScreenScaler.scale(left),
    top: ScreenScaler.scale(top),
    right: ScreenScaler.scale(right),
    bottom: ScreenScaler.scale(bottom),
  );
}

