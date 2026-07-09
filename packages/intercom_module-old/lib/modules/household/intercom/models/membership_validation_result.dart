/// Result of POST /rooms/join membership validation.
enum MembershipValidationType {
  success,
  notMember,
  networkTimeout,
  serverError,
  unknownError,
}

class MembershipValidationResult {
  final MembershipValidationType type;
  final int? statusCode;
  final String? message;
  final Duration duration;

  const MembershipValidationResult({
    required this.type,
    this.statusCode,
    this.message,
    required this.duration,
  });

  bool get isSuccess => type == MembershipValidationType.success;

  bool get isNotMember => type == MembershipValidationType.notMember;

  bool get isTransientFailure =>
      type == MembershipValidationType.networkTimeout ||
      type == MembershipValidationType.serverError ||
      type == MembershipValidationType.unknownError;

  @override
  String toString() =>
      'MembershipValidationResult(type=$type, statusCode=$statusCode, '
      'duration=${duration.inMilliseconds}ms, message=$message)';
}
