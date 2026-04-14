/// Call status enum representing the lifecycle states of a call
/// 
/// Status transitions:
/// - initiated → answered (user joins Jitsi)
/// - initiated → declined (user cancels before joining)
/// - initiated → missed (no answer after timeout)
/// - answered → ended (call terminates normally)
enum CallStatus {
  /// Call has been created but not yet answered
  initiated('initiated'),
  
  /// Call has been answered (Jitsi conference joined)
  answered('answered'),
  
  /// Call was declined (user cancelled before joining)
  declined('declined'),
  
  /// Call has ended normally (after being answered)
  ended('ended'),
  
  /// Call was not answered within timeout period
  missed('missed');

  const CallStatus(this.value);
  
  /// The string value sent to/from the backend API
  final String value;

  /// Parse a string value to CallStatus
  /// Throws [ArgumentError] if the value is not recognized
  static CallStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'initiated':
        return CallStatus.initiated;
      case 'answered':
        return CallStatus.answered;
      case 'declined':
        return CallStatus.declined;
      case 'ended':
        return CallStatus.ended;
      case 'missed':
        return CallStatus.missed;
      default:
        throw ArgumentError('Invalid call status: $value');
    }
  }

  /// Try to parse a string value to CallStatus, returns null if invalid
  static CallStatus? tryFromString(String? value) {
    if (value == null) return null;
    try {
      return fromString(value);
    } catch (_) {
      return null;
    }
  }

  /// Check if the call is still active (not terminated)
  bool get isActive => this == CallStatus.initiated || this == CallStatus.answered;

  /// Check if the call has terminated
  bool get isTerminated => 
      this == CallStatus.declined || 
      this == CallStatus.ended || 
      this == CallStatus.missed;

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case CallStatus.initiated:
        return 'Calling...';
      case CallStatus.answered:
        return 'In Call';
      case CallStatus.declined:
        return 'Declined';
      case CallStatus.ended:
        return 'Ended';
      case CallStatus.missed:
        return 'Missed';
    }
  }

  @override
  String toString() => value;
}
