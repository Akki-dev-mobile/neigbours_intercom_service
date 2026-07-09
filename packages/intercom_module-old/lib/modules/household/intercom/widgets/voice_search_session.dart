import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Owns the shared [stt.SpeechToText] singleton used by member voice search.
///
/// `speech_to_text` exposes a single global instance. Tabs must not initialize
/// it on load; only this session should prepare and drive listen sessions.
class VoiceSearchSession {
  VoiceSearchSession._();

  static final VoiceSearchSession instance = VoiceSearchSession._();

  final stt.SpeechToText speech = stt.SpeechToText();

  bool get isInitialized => speech.isAvailable;

  bool get isListening => speech.isListening;

  /// Ends any in-flight listen so a new voice-search modal can start cleanly.
  Future<void> prepareForSession() async {
    if (!speech.isAvailable) {
      return;
    }

    if (speech.isListening) {
      await speech.cancel();
      // Give the platform a moment to release the microphone.
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<bool> initialize({
    stt.SpeechErrorListener? onError,
    stt.SpeechStatusListener? onStatus,
  }) async {
    await prepareForSession();
    return speech.initialize(
      onError: onError,
      onStatus: onStatus,
    );
  }

  Future<void> stopSession() async {
    if (speech.isAvailable && speech.isListening) {
      await speech.stop();
    }
  }

  Future<void> cancelSession() async {
    if (speech.isAvailable && speech.isListening) {
      await speech.cancel();
    }
  }
}
