# Audio Service

The AudioService provides cross-platform audio feedback for user interactions, specifically designed for QR code scanning success and error sounds.

## Features

- **Success Sound**: Plays when QR code scan is successful
- **Error Sound**: Plays when QR code scan fails
- **Cross-platform**: Works on iOS, Android, and Web
- **Non-intrusive**: Short, soft sounds that don't interfere with user experience
- **Duplicate Prevention**: Prevents multiple sounds from playing simultaneously

## Usage

```dart
import 'package:flutter_onegate/services/audio/audio_service.dart';

final audioService = AudioService();

// Play success sound
await audioService.playSuccessSound();

// Play error sound
await audioService.playErrorSound();

// Clean up resources
await audioService.dispose();
```

## Implementation Details

### Success Sound
- Triggers only after successful QR code validation
- Plays once per scan to avoid duplicates
- Uses `success.mp3` audio file
- Duration: ~1 second

### Error Sound
- Triggers on failed or invalid QR codes
- Uses lower volume (0.3) for less intrusive feedback
- Uses `alarm.mp3` audio file with reduced volume
- Duration: ~800ms

## Audio Files

- `success.mp3`: Success sound for valid QR scans
- `alarm.mp3`: Error sound for failed QR scans (with reduced volume)

## Platform Compatibility

- **iOS**: Uses native audio APIs through audioplayers package
- **Android**: Uses native audio APIs through audioplayers package  
- **Web**: Uses HTML5 audio through audioplayers package

## Dependencies

- `audioplayers: ^6.1.0`: Cross-platform audio playback

## Integration

The AudioService is automatically integrated into:
- QR Scanner Screen (`qr_scanner_self.dart`)
- Plays success sound on valid QR scan
- Plays error sound on invalid QR scan
- Automatically disposed when screen is closed
