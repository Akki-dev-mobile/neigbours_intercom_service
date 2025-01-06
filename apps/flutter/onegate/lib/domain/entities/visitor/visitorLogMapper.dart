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
  bool? isCheckedOut;

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
    this.isCheckedOut,
  });

  factory VisitorLogMapper.fromJson(Map<String, dynamic> json) {
    return VisitorLogMapper(
      visitorLogId: json['id'] as int?,
      visitorId: json['visitor_id'] as int? ?? 0,
      // Fallback to 0 if missing
      visitorPurposeCategoryId:
          json['visitor_purpose_category_id'] as int? ?? 0,
      visitorPurposeSubCategoryId:
          json['visitor_purpose_sub_category_id'] as int?,
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
      isCheckedOut: json['is_checked_out'] as bool? ?? false,
    );
  }

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
      'is_checked_out': isCheckedOut,
    };
  }
}
