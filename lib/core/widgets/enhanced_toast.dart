import 'package:flutter/material.dart';

enum ToastType {
  success,
  error,
  warning,
  info,
}

class EnhancedToast {
  static void show(
    BuildContext context, {
    required String message,
    required ToastType type,
    Duration duration = const Duration(seconds: 3),
    String? title,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    Color bg;
    switch (type) {
      case ToastType.success:
        bg = Colors.green.shade700;
        break;
      case ToastType.error:
        bg = Colors.red.shade700;
        break;
      case ToastType.warning:
        bg = Colors.orange.shade800;
        break;
      case ToastType.info:
        bg = Colors.blueGrey.shade800;
        break;
    }

    final text = (title != null && title.trim().isNotEmpty)
        ? '${title.trim()}: $message'
        : message;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: duration,
        backgroundColor: bg,
      ),
    );
  }

  static void success(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: ToastType.success,
      title: title,
      duration: duration,
    );
  }

  static void error(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message: message,
      type: ToastType.error,
      title: title,
      duration: duration,
    );
  }

  static void warning(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: ToastType.warning,
      title: title,
      duration: duration,
    );
  }

  static void info(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: ToastType.info,
      title: title,
      duration: duration,
    );
  }
}

