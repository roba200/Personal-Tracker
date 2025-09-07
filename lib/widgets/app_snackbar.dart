import 'package:flutter/material.dart';

class AppSnackbar {
  static void show(BuildContext context, String message,
      {Color? backgroundColor, Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor, duration: duration),
    );
  }

  static void success(BuildContext context, String message) {
    final color = Colors.green.shade700;
    show(context, message, backgroundColor: color);
  }

  static void error(BuildContext context, String message) {
    final color = Colors.red.shade700;
    show(context, message, backgroundColor: color);
  }
}

