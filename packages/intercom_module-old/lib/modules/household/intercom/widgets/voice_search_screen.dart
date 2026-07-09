import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/widgets/enhanced_toast.dart';
import '../../../../features/oscar/presentation/widgets/animated_oscar_icon.dart';
import '../../../../src/config/chat_call_i18n.dart';
import 'voice_search_session.dart';

class VoiceSearchScreen extends StatefulWidget {
  final Function(String) onTextRecognized;
  final Function(String)? onFinalResult;
  final String? title;
  final String? listeningText;
  final String? waitingText;
  final String? placeholderText;

  const VoiceSearchScreen({
    Key? key,
    required this.onTextRecognized,
    this.onFinalResult,
    this.title,
    this.listeningText,
    this.waitingText,
    this.placeholderText,
  }) : super(key: key);

  @override
  State<VoiceSearchScreen> createState() => _VoiceSearchScreenState();
}

class _VoiceSearchScreenState extends State<VoiceSearchScreen>
    with SingleTickerProviderStateMixin {
  final VoiceSearchSession _session = VoiceSearchSession.instance;
  bool _isListening = false;
  bool _speechReady = false;
  String _recognizedText = '';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  stt.SpeechToText get _speech => _session.speech;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _initializeSpeech();
  }

  @override
  void dispose() {
    _session.cancelSession();
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _ensureMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    }

    status = await Permission.microphone.request();
    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied && mounted) {
      EnhancedToast.warning(
        context,
        title: chatCallTr(
          context,
          'chatCall_microphonePermissionRequired',
          fallback: 'Microphone Permission Required',
        ),
        message: chatCallTr(
          context,
          'chatCall_enableMicrophoneInSettings',
          fallback: 'Enable microphone access in Settings to use voice search.',
        ),
      );
      await openAppSettings();
    }

    return false;
  }

  Future<String?> _resolveListenLocaleId() async {
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) {
        return null;
      }

      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final languageCode = deviceLocale.languageCode.toLowerCase();

      for (final locale in locales) {
        final localeId = locale.localeId.toLowerCase();
        if (localeId.startsWith(languageCode)) {
          return locale.localeId;
        }
      }
    } catch (_) {}

    return null;
  }

  void _setListening(bool listening) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isListening = listening;
    });

    if (listening) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController.stop();
      _animationController.reset();
    }
  }

  Future<void> _initializeSpeech() async {
    final hasMicPermission = await _ensureMicrophonePermission();
    if (!hasMicPermission) {
      if (mounted) {
        EnhancedToast.warning(
          context,
          title: chatCallTr(
            context,
            'chatCall_microphonePermissionRequired',
            fallback: 'Microphone Permission Required',
          ),
          message: chatCallTr(
            context,
            'chatCall_microphonePermissionNeededForVoiceSearch',
            fallback: 'Microphone permission is needed for voice search.',
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    final available = await _session.initialize(
      onStatus: (status) {
        if (!mounted) {
          return;
        }

        if (status == 'done' || status == 'notListening') {
          _setListening(false);
        } else if (status == 'listening') {
          _setListening(true);
        }
      },
      onError: (error) {
        if (!mounted) {
          return;
        }

        _setListening(false);
        EnhancedToast.error(
          context,
          title: chatCallTr(
            context,
            'chatCall_speechRecognitionError',
            fallback: 'Speech Recognition Error',
          ),
          message: error.errorMsg,
        );
      },
    );

    if (!available) {
      if (mounted) {
        EnhancedToast.warning(
          context,
          title: chatCallTr(
            context,
            'chatCall_speechRecognition',
            fallback: 'Speech Recognition',
          ),
          message: chatCallTr(
            context,
            'chatCall_speechRecognitionIsNotAvailableOn',
            fallback: 'Speech recognition is not available on this device.',
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    _speechReady = true;
    await _beginListening();
  }

  Future<void> _beginListening({bool isRetry = false}) async {
    if (!_speechReady || !mounted) {
      return;
    }

    await _session.prepareForSession();

    setState(() {
      _recognizedText = '';
    });
    _setListening(true);

    final localeId = await _resolveListenLocaleId();

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) {
            return;
          }

          final recognizedText = result.recognizedWords.trim();

          setState(() {
            _recognizedText = recognizedText;
          });

          widget.onTextRecognized(recognizedText);

          if (result.finalResult) {
            _setListening(false);
            widget.onFinalResult?.call(recognizedText);

            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Navigator.pop(context, recognizedText);
              }
            });
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        localeId: localeId,
        cancelOnError: false,
        partialResults: true,
        listenMode: stt.ListenMode.search,
      );
    } on stt.ListenFailedException catch (error) {
      _setListening(false);
      if (mounted) {
        EnhancedToast.error(
          context,
          title: chatCallTr(
            context,
            'chatCall_speechRecognitionError',
            fallback: 'Speech Recognition Error',
          ),
          message: error.message ??
              chatCallTr(
                context,
                'chatCall_speechRecognitionIsNotAvailableOn',
                fallback: 'Speech recognition is not available on this device.',
              ),
        );
      }
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!_speech.isListening && mounted) {
      if (!isRetry) {
        await _beginListening(isRetry: true);
        return;
      }

      _setListening(false);
      EnhancedToast.warning(
        context,
        title: chatCallTr(
          context,
          'chatCall_speechRecognition',
          fallback: 'Speech Recognition',
        ),
        message: chatCallTr(
          context,
          'chatCall_speechRecognitionIsNotAvailableOn',
          fallback: 'Speech recognition is not available on this device.',
        ),
      );
    }
  }

  void _stopListening() {
    _session.stopSession();
    _setListening(false);
  }

  void _cancel() {
    _stopListening();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _cancel,
                  ),
                  Expanded(
                    child: Text(
                      widget.title ??
                          chatCallTr(
                            context,
                            'chatCall_voiceSearch',
                            fallback: 'Voice Search',
                          ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isListening ? _scaleAnimation.value : 1.0,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: _isListening
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isListening ? Colors.red : Colors.grey,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: AnimatedOscarIcon(
                                size: 60,
                                showGlow: _isListening,
                                animationSpeed: _isListening ? 1.5 : 1.0,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    Text(
                      _isListening
                          ? (widget.listeningText ??
                              chatCallTr(
                                context,
                                'chatCall_listening',
                                fallback: 'Listening...',
                              ))
                          : (widget.waitingText ??
                              chatCallTr(
                                context,
                                'chatCall_tapToStart',
                                fallback: 'Tap to start',
                              )),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minHeight: 150,
                        maxHeight: 300,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            if (_recognizedText.isEmpty)
                              Text(
                                widget.placeholderText ??
                                    chatCallTr(
                                      context,
                                      'chatCall_speakToSearch',
                                      fallback: 'Speak to search...',
                                    ),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              )
                            else
                              Text(
                                _recognizedText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _cancel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            chatCallTr(
                              context,
                              'chatCall_cancel',
                              fallback: 'Cancel',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (!_isListening)
                          ElevatedButton(
                            onPressed: _beginListening,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              chatCallTr(
                                context,
                                'chatCall_tapToStart',
                                fallback: 'Tap to start',
                              ),
                            ),
                          ),
                        if (_recognizedText.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () {
                              _stopListening();
                              widget.onFinalResult?.call(_recognizedText);
                              Navigator.pop(context, _recognizedText);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              chatCallTr(
                                context,
                                'chatCall_done',
                                fallback: 'Done',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
