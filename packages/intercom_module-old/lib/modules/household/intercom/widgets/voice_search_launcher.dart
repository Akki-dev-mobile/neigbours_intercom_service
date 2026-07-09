import 'package:flutter/material.dart';

import 'voice_listening_dialog.dart';
import 'voice_search_session.dart';

/// Opens the shared voice-search flow used by member/contact search fields.
class VoiceSearchLauncher {
  static Future<String?> open(
    BuildContext context, {
    required void Function(String text) onTextRecognized,
    void Function(String text)? onFinalResult,
  }) async {
    await VoiceSearchSession.instance.prepareForSession();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => VoiceListeningDialog(
        onTextRecognized: onTextRecognized,
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      onFinalResult?.call(result);
    }

    return result;
  }
}
