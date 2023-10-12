import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceToTextButton extends StatelessWidget {
  final TextEditingController targetController;

  VoiceToTextButton({
    super.key,
    required this.targetController,
  });

  final stt.SpeechToText _speech = stt.SpeechToText();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        onSpeechToText(targetController);
      },
      icon: const CircleAvatar(
        backgroundColor: Color(0xffFFEBE6),
        radius: 20,
        child: Icon(
          size: 22,
          Ionicons.mic_outline,
          color: Colors.black,
        ),
      ),
    );
  }

  Future<void> onSpeechToText(TextEditingController controller) async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech recognition status: $status');
      },
    );

    if (available) {
      final result = await _speech.listen(
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 5),
        onResult: (result) {
          final text = result.recognizedWords;
          if (text != null) {
            controller.text = text;
          }
        },
      );

      if (result != null && result.finalResult == false) {
        print('Speech recognition could not understand speech.');
      }
    } else {
      print('Speech recognition not available');
    }
  }
}
