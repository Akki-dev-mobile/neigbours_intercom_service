import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../src/config/chat_call_i18n.dart';
import 'voice_search_session.dart';

/// Voice input dialog for member search fields in Chat & Call.
///
/// Mirrors the purpose-entry [ListeningDialog] flow: a modal dialog that starts
/// listening immediately and returns the recognized text on Done.
class VoiceListeningDialog extends StatefulWidget {
  const VoiceListeningDialog({
    super.key,
    this.onTextRecognized,
  });

  final ValueChanged<String>? onTextRecognized;

  @override
  State<VoiceListeningDialog> createState() => _VoiceListeningDialogState();
}

class _VoiceListeningDialogState extends State<VoiceListeningDialog>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _recognizedText = '';
  bool _hasRecognizedText = false;

  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _speechToText = VoiceSearchSession.instance.speech;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _ringAnimation = Tween<double>(begin: 0.85, end: 1.18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startListening();
    });
  }

  Future<void> _startListening() async {
    if (!mounted) return;

    setState(() {
      _hasRecognizedText = false;
      _recognizedText = chatCallTr(
        context,
        'chatCall_listening',
        fallback: 'Listening...',
      );
    });

    await VoiceSearchSession.instance.prepareForSession();

    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _recognizedText = chatCallTr(
            context,
            'chatCall_speechRecognitionError',
            fallback: 'Error occurred. Please try again.',
          );
          _isListening = false;
        });
      },
    );

    if (!mounted) return;

    if (available) {
      setState(() => _isListening = true);
      await _speechToText.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            if (result.recognizedWords.isNotEmpty) {
              _recognizedText = result.recognizedWords;
              _hasRecognizedText = true;
              widget.onTextRecognized?.call(result.recognizedWords);
            }
            if (result.finalResult) {
              _isListening = false;
            }
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.search,
      );
    } else {
      setState(() {
        _recognizedText = chatCallTr(
          context,
          'chatCall_speechRecognitionIsNotAvailableOn',
          fallback: 'Speech recognition not available',
        );
        _isListening = false;
      });
    }
  }

  void _retryListening() {
    _stopListening();
    _startListening();
  }

  void _stopListening() {
    _speechToText.stop();
    if (mounted) setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _speechToText.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isKiosk = size.width >= 800;
    final horizontalPadding = isKiosk ? 48.0 : 24.0;
    final cardRadius = isKiosk ? 28.0 : 24.0;
    final fieldRadius = isKiosk ? 18.0 : 16.0;
    final dialogPadding = isKiosk ? 36.0 : 28.0;
    final titleSize = isKiosk ? 28.0 : 22.0;
    final bodySize = isKiosk ? 22.0 : 18.0;
    final buttonHeight = isKiosk ? 58.0 : 52.0;
    final micSize = isKiosk ? 88.0 : 72.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isKiosk ? 32 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isKiosk ? 560 : 420),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(
                color: const Color(0xff212427).withValues(alpha: 0.08),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: isKiosk ? 36 : 24,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(dialogPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context, titleSize, isKiosk),
                  SizedBox(height: isKiosk ? 26 : 22),
                  _buildTranscriptCard(fieldRadius, bodySize, isKiosk),
                  SizedBox(height: isKiosk ? 32 : 28),
                  _buildMicControl(micSize, isKiosk),
                  SizedBox(height: isKiosk ? 32 : 28),
                  _buildActions(buttonHeight, bodySize, isKiosk),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double titleSize, bool isKiosk) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(isKiosk ? 16 : 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xffF44336).withValues(alpha: 0.16),
                const Color(0xffD32F2F).withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(isKiosk ? 18 : 16),
          ),
          child: Icon(
            Icons.mic_rounded,
            size: isKiosk ? 34 : 28,
            color: const Color(0xffF44336),
          ),
        ),
        SizedBox(width: isKiosk ? 18 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chatCallTr(
                  context,
                  'chatCall_voiceSearch',
                  fallback: 'Voice Recognition',
                ),
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff212427),
                  height: 1.15,
                ),
              ),
              if (_isListening) ...[
                SizedBox(height: isKiosk ? 8 : 6),
                Text(
                  chatCallTr(
                    context,
                    'chatCall_listening',
                    fallback: 'Listening...',
                  ),
                  style: TextStyle(
                    fontSize: isKiosk ? 18 : 15,
                    color: const Color(0xff57636C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptCard(
    double fieldRadius,
    double bodySize,
    bool isKiosk,
  ) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: isKiosk ? 160 : 120),
      padding: EdgeInsets.symmetric(
        horizontal: isKiosk ? 24 : 20,
        vertical: isKiosk ? 22 : 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xffF44336).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(fieldRadius),
        border: Border.all(
          color: const Color(0xffF44336).withValues(alpha: 0.22),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          _recognizedText.isEmpty
              ? chatCallTr(
                  context,
                  'chatCall_listening',
                  fallback: 'Listening...',
                )
              : _recognizedText,
          style: TextStyle(
            fontSize: bodySize,
            fontWeight: FontWeight.w600,
            color: _hasRecognizedText
                ? const Color(0xff212427)
                : const Color(0xff57636C),
            height: 1.35,
          ),
          textAlign: TextAlign.center,
          maxLines: 6,
        ),
      ),
    );
  }

  Widget _buildMicControl(double micSize, bool isKiosk) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: micSize * 1.6,
          height: micSize * 1.6,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isListening) ...[
                Transform.scale(
                  scale: _ringAnimation.value,
                  child: Container(
                    width: micSize * 1.35,
                    height: micSize * 1.35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xffF44336).withValues(alpha: 0.18),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: micSize * 1.1,
                    height: micSize * 1.1,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xffF44336).withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ],
              Transform.scale(
                scale: _isListening ? _pulseAnimation.value : 1.0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isListening ? _stopListening : _startListening,
                    child: Ink(
                      width: micSize,
                      height: micSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isListening
                            ? const LinearGradient(
                                colors: [
                                  Color(0xffF44336),
                                  Color(0xffD32F2F),
                                ],
                              )
                            : null,
                        color: _isListening
                            ? null
                            : const Color(0xffF44336).withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        _isListening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        size: isKiosk ? 40 : 34,
                        color: _isListening
                            ? Colors.white
                            : const Color(0xffF44336),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActions(double buttonHeight, double labelSize, bool isKiosk) {
    final buttonRadius = isKiosk ? 18.0 : 16.0;

    return Row(
      children: [
        if (_hasRecognizedText) ...[
          Expanded(
            child: SizedBox(
              height: buttonHeight,
              child: OutlinedButton.icon(
                onPressed: _retryListening,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: isKiosk ? 24 : 22,
                  color: const Color(0xffF44336),
                ),
                label: Text(
                  chatCallTr(
                    context,
                    'chatCall_retry',
                    fallback: 'Retry',
                  ),
                  style: TextStyle(
                    fontSize: labelSize,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xffF44336),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: const Color(0xffF44336).withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(buttonRadius),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: isKiosk ? 16 : 14),
        ],
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _hasRecognizedText
                      ? const [Color(0xff212427), Color(0xff57636C)]
                      : const [Color(0xff57636C), Color(0xff8B95A1)],
                ),
                borderRadius: BorderRadius.circular(buttonRadius),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(buttonRadius),
                  onTap: () {
                    _stopListening();
                    if (_hasRecognizedText) {
                      Navigator.of(context).pop(_recognizedText);
                    } else {
                      Navigator.of(context).pop(null);
                    }
                  },
                  child: Center(
                    child: Text(
                      _hasRecognizedText
                          ? chatCallTr(
                              context,
                              'chatCall_done',
                              fallback: 'Done',
                            )
                          : chatCallTr(
                              context,
                              'chatCall_cancel',
                              fallback: 'Cancel',
                            ),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: labelSize,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
