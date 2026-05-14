import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:donapos_mobile/utils_scaler.dart';

class DigitalClock extends StatefulWidget {
  final TextStyle? style;
  final bool showSeconds;

  const DigitalClock({
    super.key,
    this.style,
    this.showSeconds = true,
  });

  @override
  State<DigitalClock> createState() => _DigitalClockState();
}

class _DigitalClockState extends State<DigitalClock> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final format = widget.showSeconds ? 'HH:mm:ss' : 'HH:mm';
    return Text(
      DateFormat(format).format(_now),
      style: widget.style ?? TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    );
  }
}
