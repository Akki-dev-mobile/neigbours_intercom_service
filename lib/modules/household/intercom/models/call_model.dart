import 'package:equatable/equatable.dart';
import 'call_type.dart';
import 'call_status.dart';

/// Call model representing a call record from the backend
///
/// This model is the single source of truth for call data.
/// The `callType` field is non-null and required in all operations.
///
/// Backend Flow:
/// 1. Token Decoding: Extracts user info from JWT (old_sso_user_id, name, preferred_username, email)
/// 2. User Storage: Creates/updates caller user record with token data
/// 3. Recipient Validation: Verifies recipient exists in database
/// 4. Meeting ID Generation: 10-digit random identifier
/// 5. Jitsi URL Creation: Base URL + meeting ID + call type config
/// 6. Response: Complete call object with jitsi_meeting_url, from_user, to_user
class Call extends Equatable {
  /// Unique identifier for the call (from backend)
  final int id;

  /// Meeting ID used for Jitsi conference (10-digit random identifier)
  final String meetingId;

  /// Full Jitsi meeting URL with call type configuration
  /// Format: {base_jitsi_url}/{meeting_id}#config.startWithVideoMuted={audio}&config.startAudioOnly={audio}
  /// - Audio call: startWithVideoMuted=true, startAudioOnly=true
  /// - Video call: startWithVideoMuted=false, startAudioOnly=false
  final String? jitsiMeetingUrl;

  /// The type of call (audio or video) - REQUIRED, never null
  final CallType callType;

  /// Current status of the call
  final CallStatus status;

  /// User ID of the caller (extracted from JWT token's old_sso_user_id)
  final int? fromUserId;

  /// User ID of the recipient (internal DB id; display/debug only)
  final int? toUserId;

  /// Phone number of the recipient (used for initiating calls)
  final String? toUserPhone;

  /// Caller user information (from JWT token data stored in DB)
  final CallUser? fromUser;

  /// Recipient user information (from existing DB record)
  final CallUser? toUser;

  /// Timestamp when the call was created
  final DateTime? createdAt;

  /// Timestamp when the call was last updated
  final DateTime? updatedAt;

  const Call({
    required this.id,
    required this.meetingId,
    this.jitsiMeetingUrl,
    required this.callType,
    required this.status,
    this.fromUserId,
    this.toUserId,
    this.toUserPhone,
    this.fromUser,
    this.toUser,
    this.createdAt,
    this.updatedAt,
  });

  /// Create a Call from JSON response
  ///
  /// Expected JSON format from POST /api/calls/initiate:
  /// ```json
  /// {
  ///   "id": 123,
  ///   "meeting_id": "1234567890",
  ///   "jitsi_meeting_url": "https://collab.cubeone.in/1234567890#config.startWithVideoMuted=false",
  ///   "call_type": "video",
  ///   "call_status": "initiated",
  ///   "from_user_id": 1,
  ///   "to_user_id": 2,
  ///   "from_user": { "id": 1, "name": "Caller Name", "phone": "1234567890" },
  ///   "to_user": { "id": 2, "name": "Recipient Name", "phone": "0987654321" },
  ///   "created_at": "2024-01-01T00:00:00Z",
  ///   "updated_at": "2024-01-01T00:00:00Z"
  /// }
  /// ```
  factory Call.fromJson(Map<String, dynamic> json) {
    // Handle nested response structure where call data might be inside "call" key
    // Backend may return: { "call": { ...callData } } or { ...callData }
    Map<String, dynamic> callData = json;
    if (json.containsKey('call') && json['call'] is Map<String, dynamic>) {
      callData = json['call'] as Map<String, dynamic>;
    }

    // Extract call_type - REQUIRED field
    final callTypeRaw = callData['call_type'] as String?;
    if (callTypeRaw == null || callTypeRaw.isEmpty) {
      // Log available keys for debugging
      throw ArgumentError('call_type is required and cannot be null or empty. '
          'Available keys: ${callData.keys.toList()}');
    }

    // Extract call_status with fallback to 'initiated'
    final statusRaw = callData['call_status'] as String? ??
        callData['status'] as String? ??
        'initiated';

    // Parse from_user if present
    CallUser? fromUser;
    if (callData['from_user'] != null &&
        callData['from_user'] is Map<String, dynamic>) {
      fromUser =
          CallUser.fromJson(callData['from_user'] as Map<String, dynamic>);
    }

    // Parse to_user if present
    CallUser? toUser;
    if (callData['to_user'] != null &&
        callData['to_user'] is Map<String, dynamic>) {
      toUser = CallUser.fromJson(callData['to_user'] as Map<String, dynamic>);
    }

    return Call(
      id: callData['id'] as int,
      meetingId: callData['meeting_id'] as String,
      jitsiMeetingUrl: callData['jitsi_meeting_url'] as String?,
      callType: CallType.fromString(callTypeRaw),
      status: CallStatus.fromString(statusRaw),
      fromUserId: callData['from_user_id'] as int?,
      toUserId: callData['to_user_id'] as int?,
      toUserPhone: callData['to_user_phone'] as String?,
      fromUser: fromUser,
      toUser: toUser,
      createdAt: callData['created_at'] != null
          ? DateTime.tryParse(callData['created_at'] as String)
          : null,
      updatedAt: callData['updated_at'] != null
          ? DateTime.tryParse(callData['updated_at'] as String)
          : null,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meeting_id': meetingId,
      if (jitsiMeetingUrl != null) 'jitsi_meeting_url': jitsiMeetingUrl,
      'call_type': callType.value,
      'call_status': status.value,
      if (fromUserId != null) 'from_user_id': fromUserId,
      if (toUserId != null) 'to_user_id': toUserId,
      if (toUserPhone != null) 'to_user_phone': toUserPhone,
      if (fromUser != null) 'from_user': fromUser!.toJson(),
      if (toUser != null) 'to_user': toUser!.toJson(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Create a copy with updated status
  Call copyWithStatus(CallStatus newStatus) {
    return Call(
      id: id,
      meetingId: meetingId,
      jitsiMeetingUrl: jitsiMeetingUrl,
      callType: callType,
      status: newStatus,
      fromUserId: fromUserId,
      toUserId: toUserId,
      toUserPhone: toUserPhone,
      fromUser: fromUser,
      toUser: toUser,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Check if this is an audio call
  bool get isAudioCall => callType.isAudio;

  /// Check if this is a video call
  bool get isVideoCall => callType.isVideo;

  /// Check if the call is still active
  bool get isActive => status.isActive;

  /// Check if the call has terminated
  bool get isTerminated => status.isTerminated;

  @override
  List<Object?> get props => [
        id,
        meetingId,
        jitsiMeetingUrl,
        callType,
        status,
        fromUserId,
        toUserId,
        toUserPhone,
        fromUser,
        toUser,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'Call(id: $id, meetingId: $meetingId, type: ${callType.value}, status: ${status.value}, jitsiUrl: ${jitsiMeetingUrl != null ? "present" : "null"})';
  }
}

/// User information associated with a call
///
/// Contains user data extracted from JWT token (for caller) or DB (for recipient)
/// JWT token claims used:
/// - old_sso_user_id → userId
/// - name → name
/// - preferred_username → phone
/// - email → email
class CallUser extends Equatable {
  /// Unique identifier for the user
  final int id;

  /// User ID string (from old_sso_user_id in JWT)
  final String? userId;

  /// User's full name (from name claim in JWT)
  final String? name;

  /// User's phone number (from preferred_username in JWT)
  final String? phone;

  /// User's email address (from email claim in JWT)
  final String? email;

  const CallUser({
    required this.id,
    this.userId,
    this.name,
    this.phone,
    this.email,
  });

  factory CallUser.fromJson(Map<String, dynamic> json) {
    return CallUser(
      id: json['id'] as int,
      userId: json['user_id'] as String?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
    };
  }

  @override
  List<Object?> get props => [id, userId, name, phone, email];

  @override
  String toString() {
    return 'CallUser(id: $id, name: $name, phone: $phone)';
  }
}

/// Request model for initiating a call
class InitiateCallRequest {
  /// Phone number of the recipient (optional)
  final String? toUserPhone;

  /// User ID of the recipient (optional)
  final String? toUserId;

  /// Caller avatar URL (optional)
  final String? imageAvatarUrl;

  /// Platform identifier expected by backend (e.g. android/ios/web)
  final String? platform;

  /// Type of call (audio or video) - REQUIRED
  final CallType callType;

  const InitiateCallRequest({
    this.toUserPhone,
    this.toUserId,
    this.imageAvatarUrl,
    this.platform,
    required this.callType,
  });

  Map<String, dynamic> toJson() {
    final hasToUserId = toUserId != null && toUserId!.trim().isNotEmpty;
    return {
      if (hasToUserId) 'to_user_id': toUserId!.trim(),
      if (!hasToUserId && toUserPhone != null && toUserPhone!.trim().isNotEmpty)
        'to_user_phone': toUserPhone!.trim(),
      if (imageAvatarUrl != null && imageAvatarUrl!.isNotEmpty)
        'image_avatar_url': imageAvatarUrl,
      'call_type': callType.value,
      if (platform != null && platform!.trim().isNotEmpty)
        'platform': platform!.trim(),
    };
  }
}

/// Request model for updating call status
class UpdateCallStatusRequest {
  /// New status for the call
  final CallStatus status;

  /// Platform (android/ios/web) - optional, sent when required by backend.
  final String? platform;

  const UpdateCallStatusRequest({
    required this.status,
    this.platform,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status.value,
      if (platform != null && platform!.trim().isNotEmpty)
        'platform': platform!.trim(),
    };
  }
}
