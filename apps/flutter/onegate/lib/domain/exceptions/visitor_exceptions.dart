/// Custom exceptions for visitor-related operations
class VisitorAlreadyCheckedInException implements Exception {
  final String message;

  const VisitorAlreadyCheckedInException(this.message);

  @override
  String toString() => 'VisitorAlreadyCheckedInException: $message';
}

/// General visitor operation exception
class VisitorOperationException implements Exception {
  final String message;
  final int? statusCode;

  const VisitorOperationException(this.message, {this.statusCode});

  @override
  String toString() =>
      'VisitorOperationException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// API error exception for non-200 status codes
class VisitorApiException implements Exception {
  final String message;
  final int statusCode;

  const VisitorApiException(this.message, this.statusCode);

  @override
  String toString() => 'VisitorApiException: $message (Status: $statusCode)';
}
