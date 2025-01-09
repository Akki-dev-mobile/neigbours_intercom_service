
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';

class VisitorLogMapper {
  int? visitorLogId;
  int? visitorId;
  String? visitorName;
  int? visitorPurposeCategoryId;
  int? visitorPurposeSubCategoryId;
  int? visitorCount;
  DateTime? visitorCheckIn;
  DateTime? visitorCheckOut;
  String? visitorCardNumber;
  String? visitorComingFrom;
  int? visitorCardId;
  int? companyId;
  String? companyName;
  String? inGate;
  bool? isCheckedOut;
  List<Map<String, dynamic>>? memberDetails;
  List<VisitorMapper>? visitors; // New field for a list of visitors

  VisitorLogMapper({
    this.visitorLogId,
    this.visitorId,
    this.visitorName,
    this.visitorPurposeCategoryId,
    this.visitorPurposeSubCategoryId,
    this.visitorCount,
    this.visitorCheckIn,
    this.visitorCheckOut,
    this.visitorCardNumber,
    this.visitorComingFrom,
    this.visitorCardId,
    this.companyId,
    this.companyName,
    this.inGate,
    this.isCheckedOut,
    this.memberDetails,
    this.visitors, // Initialize the visitors list
  });

  /// Factory constructor to create a `VisitorLogMapper` object from JSON.
  factory VisitorLogMapper.fromJson(Map<String, dynamic> json) {
    return VisitorLogMapper(
      visitorLogId: json['id'] as int?,
      visitorId: json['visitor_id'] as int? ?? 0,
      visitorName: json['visitor_name'] as String?,
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
      companyName: json['company_name'] as String?,
      inGate: json['in_gate'] as String?,
      isCheckedOut: json['is_checked_out'] as bool? ?? false,
      memberDetails: (json['member_details'] as List<dynamic>?)
          ?.map((member) => Map<String, dynamic>.from(member as Map))
          .toList(),
      visitors: (json['visitors'] as List<dynamic>?)
          ?.map((visitor) => VisitorMapper.fromJson(visitor))
          .toList(), // Parse visitors list
    );
  }

  /// Converts the `VisitorLogMapper` object to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': visitorLogId,
      'visitor_id': visitorId,
      'visitor_name': visitorName,
      'visitor_purpose_category_id': visitorPurposeCategoryId,
      'visitor_purpose_sub_category_id': visitorPurposeSubCategoryId,
      'visitor_count': visitorCount,
      'visitor_check_in': visitorCheckIn?.toIso8601String(),
      'visitor_check_out': visitorCheckOut?.toIso8601String(),
      'visitor_card_number': visitorCardNumber,
      'visitor_coming_from': visitorComingFrom,
      'visitor_card_id': visitorCardId,
      'company_id': companyId,
      'company_name': companyName,
      'in_gate': inGate,
      'is_checked_out': isCheckedOut,
      'member_details': memberDetails,
      'visitors': visitors?.map((visitor) => visitor.toJson()).toList(), // Convert visitors list to JSON
    };
  }
}