/// Call type enum for audio and video calls
/// 
/// This enum represents the type of call being made.
/// The value must be non-null in all call operations.
enum CallType {
  audio('audio'),
  video('video');

  const CallType(this.value);
  
  /// The string value sent to/from the backend API
  final String value;

  /// Parse a string value to CallType
  /// Throws [ArgumentError] if the value is not recognized
  static CallType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'audio':
        return CallType.audio;
      case 'video':
        return CallType.video;
      default:
        throw ArgumentError('Invalid call type: $value. Expected "audio" or "video".');
    }
  }

  /// Try to parse a string value to CallType, returns null if invalid
  static CallType? tryFromString(String? value) {
    if (value == null) return null;
    try {
      return fromString(value);
    } catch (_) {
      return null;
    }
  }

  /// Check if this is an audio call
  bool get isAudio => this == CallType.audio;

  /// Check if this is a video call
  bool get isVideo => this == CallType.video;

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case CallType.audio:
        return 'Audio Call';
      case CallType.video:
        return 'Video Call';
    }
  }

  @override
  String toString() => value;
}
