import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/widgets/enhanced_toast.dart';
import '../../../../features/oscar/presentation/widgets/animated_oscar_icon.dart';

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
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _initializeSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (mounted) {
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
            _animationController.stop();
            _animationController.reset();
          } else if (status == 'listening') {
            setState(() {
              _isListening = true;
            });
            _animationController.repeat(reverse: true);
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
          });
          _animationController.stop();
          _animationController.reset();
          EnhancedToast.error(
            context,
            title: 'Speech Recognition Error',
            message: error.errorMsg,
          );
        }
      },
    );

    if (!available && mounted) {
      EnhancedToast.warning(
        context,
        title: 'Speech Recognition',
        message: 'Speech recognition is not available on this device.',
      );
      Navigator.pop(context);
      return;
    }

    // Start listening immediately
    _startListening();
  }

  Future<void> _startListening() async {
    if (!await _speech.initialize()) {
      if (mounted) {
        EnhancedToast.warning(
          context,
          title: 'Speech Recognition',
          message: 'Speech recognition is not available.',
        );
        Navigator.pop(context);
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isListening = true;
        _recognizedText = '';
      });
    }

    _speech.listen(
      onResult: (result) {
        if (!mounted) return;

        final recognizedText = result.recognizedWords.trim();

        setState(() {
          _recognizedText = recognizedText;
        });

        // Call the callback with recognized text
        widget.onTextRecognized(recognizedText);

        if (result.finalResult) {
          // Final result
          if (mounted) {
            setState(() {
              _isListening = false;
            });
            _animationController.stop();
            _animationController.reset();

            // Call final result callback if provided
            if (widget.onFinalResult != null) {
              widget.onFinalResult!(recognizedText);
            }

            // Close the screen after a short delay
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Navigator.pop(context, recognizedText);
              }
            });
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      cancelOnError: true,
    );
  }

  void _stopListening() {
    _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
      _animationController.stop();
      _animationController.reset();
    }
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
            // Header
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
                      widget.title ?? 'Voice Search',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the close button
                ],
              ),
            ),

            // Main content
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated OSCAR icon
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

                    // Status text
                    Text(
                      _isListening
                          ? (widget.listeningText ?? 'Listening...')
                          : (widget.waitingText ?? 'Tap to start'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Recognized text container
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
                                widget.placeholderText ?? 'Speak to search...',
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

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Cancel button
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
                          child: const Text('Cancel'),
                        ),

                        const SizedBox(width: 16),

                        // Done button (only show when there's text)
                        if (_recognizedText.isNotEmpty)
                          ElevatedButton(
                            onPressed: () {
                              _stopListening();
                              if (widget.onFinalResult != null) {
                                widget.onFinalResult!(_recognizedText);
                              }
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
                            child: const Text('Done'),
                          ),
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
