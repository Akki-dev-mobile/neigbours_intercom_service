import 'package:audioplayers/audioplayers.dart';
import 'dart:developer';

/// Audio service for playing system sounds
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  /// Play success sound for QR code scan
  Future<void> playSuccessSound() async {
    try {
      // Prevent multiple simultaneous plays
      if (_isPlaying) {
        log('🔊 Audio already playing, skipping success sound');
        return;
      }

      _isPlaying = true;
      log('🔊 Playing QR scan success sound');

      // Play the success sound
      await _audioPlayer.play(AssetSource('media/audio/success.mp3'));

      // Reset playing state after a short delay
      Future.delayed(const Duration(milliseconds: 1000), () {
        _isPlaying = false;
      });

      log('✅ Success sound played successfully');
    } catch (e) {
      log('❌ Error playing success sound: $e');
      _isPlaying = false;
    }
  }

  /// Play error sound for failed QR code scan
  Future<void> playErrorSound() async {
    try {
      if (_isPlaying) {
        log('🔊 Audio already playing, skipping error sound');
        return;
      }

      _isPlaying = true;
      log('🔊 Playing QR scan error sound');

      // For now, we'll use the same sound but with different volume
      // In a real implementation, you'd have a different error sound file
      await _audioPlayer.setVolume(0.3); // Lower volume for error
      await _audioPlayer.play(AssetSource('media/audio/alarm.mp3'));
      await _audioPlayer.setVolume(1.0); // Reset volume

      Future.delayed(const Duration(milliseconds: 800), () {
        _isPlaying = false;
      });

      log('✅ Error sound played successfully');
    } catch (e) {
      log('❌ Error playing error sound: $e');
      _isPlaying = false;
    }
  }

  /// Dispose audio player resources
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      log('🔊 Audio service disposed');
    } catch (e) {
      log('❌ Error disposing audio service: $e');
    }
  }
}
