class VisitorLogMapper {
  int? id;
  int visitorId;
  int visitorPurposeCategoryId;
  int? visitorPurposeSubCategoryId;
  int visitorCount;
  DateTime? visitorCheckIn;
  DateTime? visitorCheckOut;
  String? visitorCardNumber;
  String? visitorComingFrom;
  int? visitorCardId;
  int companyId;
  bool isCheckedOut;

  VisitorLogMapper({
    this.id,
    required this.visitorId,
    required this.visitorPurposeCategoryId,
    this.visitorPurposeSubCategoryId,
    required this.visitorCount,
    this.visitorCheckIn,
    this.visitorCheckOut,
    this.visitorCardNumber,
    this.visitorComingFrom,
    this.visitorCardId,
    required this.companyId,
    required this.isCheckedOut,
  });

  /// Converts JSON to a VisitorLogMapper object
  factory VisitorLogMapper.fromJson(Map<String, dynamic> json) {
    return VisitorLogMapper(
      id: json['visitor_log_id'] as int?,
      visitorId: json['visitor_id'] as int? ?? 0,
      visitorPurposeCategoryId: json['visitor_purpose_category_id'] as int? ?? 0,
      visitorPurposeSubCategoryId: json['visitor_purpose_sub_category_id'] as int?,
      visitorCount: json['visitor_count'] as int? ?? 0,
      visitorCheckIn: _parseDateTime(json['visitor_check_in']),
      visitorCheckOut: _parseDateTime(json['visitor_check_out']),
      visitorCardNumber: json['visitor_card_number'] as String?,
      visitorComingFrom: json['visitor_coming_from'] as String?,
      visitorCardId: json['visitor_card_id'] as int?,
      companyId: json['company_id'] as int? ?? 0,
      isCheckedOut: json['is_checked_out'] as bool? ?? false,
    );
  }

  /// Converts a VisitorLogMapper object to JSON
  static Map<String, dynamic> toJson(VisitorLogMapper visitorLog) {
    return {
      'visitor_log_id': visitorLog.id,
      'visitor_id': visitorLog.visitorId,
      'visitor_purpose_category_id': visitorLog.visitorPurposeCategoryId,
      'visitor_purpose_sub_category_id': visitorLog.visitorPurposeSubCategoryId,
      'visitor_count': visitorLog.visitorCount,
      'visitor_check_in': visitorLog.visitorCheckIn?.toIso8601String(),
      'visitor_check_out': visitorLog.visitorCheckOut?.toIso8601String(),
      'visitor_card_number': visitorLog.visitorCardNumber,
      'visitor_coming_from': visitorLog.visitorComingFrom,
      'visitor_card_id': visitorLog.visitorCardId,
      'company_id': visitorLog.companyId,
      'is_checked_out': visitorLog.isCheckedOut,
    };
  }

  /// Helper function to safely parse DateTime
  static DateTime? _parseDateTime(dynamic date) {
    if (date == null) return null;
    try {
      return DateTime.parse(date as String);
    } catch (e) {
      print("Invalid DateTime format: $date");
      return null; // Return null if parsing fails
    }
  }
}
