class VisitorLogMapper {
  int? visitorLogId;
  int? visitorId;
  int? visitorPurposeCategoryId;
  int? visitorPurposeSubCategoryId;
  int? visitorCount;
  DateTime? visitorCheckIn;
  DateTime? visitorCheckOut;
  String? visitorCardNumber;
  String? visitorComingFrom;
  int? visitorCardId;
  int? companyId;
  String? companyName; // New field for company name
  bool? isCheckedOut;
  List<Map<String, dynamic>>? memberDetails; // Corrected to List<Map<String, dynamic>>

  VisitorLogMapper({
    this.visitorLogId,
    this.visitorId,
    this.visitorPurposeCategoryId,
    this.visitorPurposeSubCategoryId,
    this.visitorCount,
    this.visitorCheckIn,
    this.visitorCheckOut,
    this.visitorCardNumber,
    this.visitorComingFrom,
    this.visitorCardId,
    this.companyId,
    this.companyName, // Initialize companyName
    this.isCheckedOut,
    this.memberDetails, // Initialize memberDetails
  });

  /// Factory constructor to create a `VisitorLogMapper` object from JSON.
  factory VisitorLogMapper.fromJson(Map<String, dynamic> json) {
    return VisitorLogMapper(
      visitorLogId: json['id'] as int?,
      visitorId: json['visitor_id'] as int? ?? 0, // Fallback to 0 if missing
      visitorPurposeCategoryId: json['visitor_purpose_category_id'] as int? ?? 0,
      visitorPurposeSubCategoryId: json['visitor_purpose_sub_category_id'] as int?,
      visitorCount: json['visitor_count'] as int? ?? 0,
      visitorCheckIn: json['visitor_check_in'] != null
          ? DateTime.tryParse(json['visitor_check_in'])
          : null,
      visitorCheckOut: json['visitor_check_out'] != null
          ? DateTime.tryParse(json['visitor_check_out'])
          : null,
      visitorCardNumber: json['visitor_card_number'] as String?,
      visitorComingFrom: json['visitor_coming_from'] as String?,
      visitorCardId: json['visitor_card_id'] as int?,
      companyId: json['company_id'] as int? ?? 0,
      companyName: json['company_name'] as String?, // Parse company name
      isCheckedOut: json['is_checked_out'] as bool? ?? false,
      memberDetails: (json['member_details'] as List<dynamic>?)
          ?.map((member) => Map<String, dynamic>.from(member as Map))
          .toList(), // Properly handle memberDetails as List<Map<String, dynamic>>
    );
  }

  /// Converts the `VisitorLogMapper` object to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': visitorLogId,
      'visitor_id': visitorId,
      'visitor_purpose_category_id': visitorPurposeCategoryId,
      'visitor_purpose_sub_category_id': visitorPurposeSubCategoryId,
      'visitor_count': visitorCount,
      'visitor_check_in': visitorCheckIn?.toIso8601String(),
      'visitor_check_out': visitorCheckOut?.toIso8601String(),
      'visitor_card_number': visitorCardNumber,
      'visitor_coming_from': visitorComingFrom,
      'visitor_card_id': visitorCardId,
      'company_id': companyId,
      'company_name': companyName, // Include companyName in JSON
      'is_checked_out': isCheckedOut,
      'member_details': memberDetails, // Include memberDetails in JSON
    };
  }
}