import 'package:equatable/equatable.dart';
import 'call_status.dart';
import 'call_type.dart';

/// Represents a single call history record.
class CallHistoryEntry extends Equatable {
  const CallHistoryEntry({
    required this.callId,
    required this.contactName,
    required this.contactPhone,
    this.contactAvatar,
    required this.callType,
    required this.status,
    required this.initiatedAt,
    this.endedAt,
    this.duration,
    this.isOutgoing = true,
  });

  final int callId;
  final String contactName;
  final String contactPhone;
  final String? contactAvatar;
  final CallType callType;
  final CallStatus status;
  final DateTime initiatedAt;
  final DateTime? endedAt;
  final Duration? duration;
  final bool isOutgoing;

  CallHistoryEntry copyWith({
    CallStatus? status,
    DateTime? endedAt,
    Duration? duration,
    String? contactName,
    String? contactPhone,
    String? contactAvatar,
    CallType? callType,
    bool? isOutgoing,
  }) {
    return CallHistoryEntry(
      callId: callId,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactAvatar: contactAvatar ?? this.contactAvatar,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      initiatedAt: initiatedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      isOutgoing: isOutgoing ?? this.isOutgoing,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'contact_avatar': contactAvatar,
      'call_type': callType.value,
      'status': status.value,
      'initiated_at': initiatedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': duration?.inSeconds,
      'is_outgoing': isOutgoing,
    };
  }

  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) {
    final initiatedAtString = json['initiated_at'] as String?;
    final endedAtString = json['ended_at'] as String?;
    final durationSeconds = json['duration_seconds'] as int?;

    final initiatedAt =
        initiatedAtString != null ? DateTime.tryParse(initiatedAtString) : null;
    final endedAt =
        endedAtString != null ? DateTime.tryParse(endedAtString) : null;
    final duration =
        durationSeconds != null ? Duration(seconds: durationSeconds) : null;

    return CallHistoryEntry(
      callId: json['call_id'] as int,
      contactName: json['contact_name'] as String? ?? 'Unknown',
      contactPhone: json['contact_phone'] as String? ?? 'Unknown',
      contactAvatar: json['contact_avatar'] as String?,
      callType: CallType.tryFromString(json['call_type'] as String?) ??
          CallType.audio,
      status: CallStatus.tryFromString(json['status'] as String?) ??
          CallStatus.ended,
      initiatedAt: initiatedAt ?? DateTime.now(),
      endedAt: endedAt,
      duration: duration,
      isOutgoing: json['is_outgoing'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
        callId,
        contactName,
        contactPhone,
        contactAvatar,
        callType,
        status,
        initiatedAt,
        endedAt,
        duration,
        isOutgoing,
      ];
}
