import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as audio;

/// WhatsApp-style audio/voice note message widget
/// Displays audio with waveform visualization, play/pause button, progress, and duration
class WhatsAppAudioMessage extends StatefulWidget {
  final File? audioFile;
  final String? audioUrl;
  final Duration? duration;
  final bool isFromMe;
  final audio.AudioPlayer audioPlayer;
  final String messageId;
  final bool isPlaying;
  final VoidCallback onTogglePlayback;
  final VoidCallback? onDownload;

  const WhatsAppAudioMessage({
    Key? key,
    this.audioFile,
    this.audioUrl,
    this.duration,
    required this.isFromMe,
    required this.audioPlayer,
    required this.messageId,
    required this.isPlaying,
    required this.onTogglePlayback,
    this.onDownload,
  }) : super(key: key);

  @override
  State<WhatsAppAudioMessage> createState() => _WhatsAppAudioMessageState();
}

class _WhatsAppAudioMessageState extends State<WhatsAppAudioMessage>
    with SingleTickerProviderStateMixin {
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  late AnimationController _waveformController;

  @override
  void initState() {
    super.initState();
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    // Listen to position changes - update if this message is playing
    _positionSubscription =
        widget.audioPlayer.positionStream.listen((position) {
      if (mounted && widget.isPlaying) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // Listen to duration changes - update when available
    _durationSubscription =
        widget.audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });
  }

  @override
  void didUpdateWidget(WhatsAppAudioMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When playback starts, get current position immediately
    if (!oldWidget.isPlaying && widget.isPlaying) {
      // Get current position from player (it's a Future)
      Future.microtask(() async {
        if (mounted && widget.isPlaying) {
          final position = await widget.audioPlayer.position;
          if (mounted && widget.isPlaying) {
            setState(() {
              _currentPosition = position;
            });
          }
        }
      });
      // Get duration if available (it's a Future)
      Future.microtask(() async {
        if (mounted && widget.isPlaying) {
          final duration = await widget.audioPlayer.duration;
          if (mounted && duration != null && widget.isPlaying) {
            setState(() {
              _totalDuration = duration;
            });
          }
        }
      });
    }
    // Reset position when playback stops
    if (oldWidget.isPlaying && !widget.isPlaying) {
      setState(() {
        _currentPosition = Duration.zero;
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _waveformController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double _getProgress() {
    // Only show progress if this message is currently playing
    if (!widget.isPlaying || _totalDuration.inMilliseconds == 0) {
      return 0.0;
    }
    return _currentPosition.inMilliseconds / _totalDuration.inMilliseconds;
  }

  @override
  Widget build(BuildContext context) {
    // Show duration - prefer actual duration from player, fallback to widget duration
    final displayDuration = _totalDuration.inMilliseconds > 0
        ? _totalDuration
        : (widget.duration ?? Duration.zero);
    // Show position - always show current position when playing, otherwise show 0:00
    final displayPosition =
        widget.isPlaying && _currentPosition.inMilliseconds > 0
            ? _currentPosition
            : Duration.zero;

    // WhatsApp colors: green for sent messages, grey for received
    final backgroundColor = widget.isFromMe
        ? const Color(0xFFDCF8C6) // Light green
        : Colors.white;
    final progressColor = widget.isFromMe
        ? const Color(0xFF075E54) // Dark green
        : const Color(0xFF34B7F1); // Light blue

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 280,
        minWidth: 200,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: widget.onTogglePlayback,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: progressColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Waveform and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform visualization
                SizedBox(
                  height: 20,
                  child: _buildWaveform(progressColor),
                ),
                const SizedBox(height: 4),
                // Duration and progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(displayPosition),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(displayDuration),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Download button (if available and not from me)
          if (widget.onDownload != null && !widget.isFromMe) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onDownload,
              child: Icon(
                Icons.download,
                size: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaveform(Color color) {
    // Generate a simple waveform visualization
    // Only show progress if THIS message is playing
    final progress = widget.isPlaying ? _getProgress() : 0.0;
    final barCount = 20;
    final bars = List.generate(barCount, (index) {
      final normalizedIndex = index / barCount;
      final isActive = widget.isPlaying && normalizedIndex <= progress;

      // Create animated bars with varying heights
      final baseHeight = 0.3 + (math.sin(index * 0.5) * 0.3);
      final height = isActive ? baseHeight : 0.1;

      return Container(
        width: 2,
        height: height * 20,
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(1),
        ),
      );
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: bars,
    );
  }
}
