import 'package:flutter_onegate/domain/entities/visitor/building_assignment.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';

class VisitorLog {
  VisitorLog({
    this.id,
    this.visitor_id,
    this.visitor,
    this.visitor_purpose_category_id,
    this.visitor_purpose_sub_category_id,
    this.visitor_building_assignment,
    this.visitor_count,
    this.visitor_check_in,
    this.visitor_check_out,
    this.visitor_card_number,
    this.visitor_coming_from,
    this.visitor_card_id,
    this.company_id,
    this.is_checked_out,
    this.visitor_purpose_Category_name,
    this.purpose_sub_category_name,
    this.carNumber,
    this.initiated_from,
    this.approved_by, // Added field
  });

  final int? id;
  final int? visitor_id;
  final Visitor? visitor;
  final int? visitor_purpose_category_id;
  final int? visitor_purpose_sub_category_id;
  final List<BuildingAssignment>? visitor_building_assignment;
  final int? visitor_count;
  DateTime? visitor_check_in;
  DateTime? visitor_check_out;
  final String? visitor_card_number;
  final String? visitor_coming_from;
  final int? visitor_card_id;
  final int? company_id;
  bool? is_checked_out;
  final String? carNumber;
  final String? visitor_purpose_Category_name;
  final String? purpose_sub_category_name;
  final String? initiated_from; // Added field
  final String? approved_by; // Added field

  /// Creates a copy of this VisitorLog with the given fields replaced with new values
  VisitorLog copyWith({
    int? id,
    int? visitor_id,
    Visitor? visitor,
    int? visitor_purpose_category_id,
    int? visitor_purpose_sub_category_id,
    List<BuildingAssignment>? visitor_building_assignment,
    int? visitor_count,
    DateTime? visitor_check_in,
    DateTime? visitor_check_out,
    String? visitor_card_number,
    String? visitor_coming_from,
    int? visitor_card_id,
    int? company_id,
    bool? is_checked_out,
    String? carNumber,
    String? visitor_purpose_Category_name,
    String? purpose_sub_category_name,
    String? initiated_from,
    String? approved_by,
  }) {
    return VisitorLog(
      id: id ?? this.id,
      visitor_id: visitor_id ?? this.visitor_id,
      visitor: visitor ?? this.visitor,
      visitor_purpose_category_id:
          visitor_purpose_category_id ?? this.visitor_purpose_category_id,
      visitor_purpose_sub_category_id: visitor_purpose_sub_category_id ??
          this.visitor_purpose_sub_category_id,
      visitor_building_assignment:
          visitor_building_assignment ?? this.visitor_building_assignment,
      visitor_count: visitor_count ?? this.visitor_count,
      visitor_check_in: visitor_check_in ?? this.visitor_check_in,
      visitor_check_out: visitor_check_out ?? this.visitor_check_out,
      visitor_card_number: visitor_card_number ?? this.visitor_card_number,
      visitor_coming_from: visitor_coming_from ?? this.visitor_coming_from,
      visitor_card_id: visitor_card_id ?? this.visitor_card_id,
      company_id: company_id ?? this.company_id,
      is_checked_out: is_checked_out ?? this.is_checked_out,
      carNumber: carNumber ?? this.carNumber,
      visitor_purpose_Category_name:
          visitor_purpose_Category_name ?? this.visitor_purpose_Category_name,
      purpose_sub_category_name:
          purpose_sub_category_name ?? this.purpose_sub_category_name,
      initiated_from: initiated_from ?? this.initiated_from,
      approved_by: approved_by ?? this.approved_by,
    );
  }

  /// Convert the object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'visitor': visitor?.toJson(),
      'visitor_purpose_category_id': visitor_purpose_category_id,
      'vehicle_number': carNumber,
      'visitor_purpose_sub_category_id': visitor_purpose_sub_category_id,
      'visitor_building_assignment': visitor_building_assignment
          ?.map((assignment) => assignment.toJson())
          .toList(),
      'visitor_count': visitor_count,
      'visitor_check_in': visitor_check_in?.toIso8601String(),
      'visitor_check_out': visitor_check_out?.toIso8601String(),
      'visitor_card_number': visitor_card_number,
      'visitor_coming_from': visitor_coming_from,
      'visitor_card_id': visitor_card_id,
      'company_id': company_id,
      'is_checked_out': is_checked_out,
      'purpose_category_name': visitor_purpose_Category_name,
      'purpose_sub_category_name': purpose_sub_category_name,
      'initiated_from': initiated_from, // Added field to JSON output
      'approved_by': approved_by, // Added field to JSON output
    };
  }

  /// Create an instance from a JSON map (Handling `unit_details`, `additional_details` and flattened visitor fields)
  factory VisitorLog.fromJson(Map<String, dynamic> json) {
    return VisitorLog(
      id: json['visitor_log_id'] as int?,
      visitor_id: json['visitor_id'] as int?,
      visitor: Visitor(
        id: json['visitor_id'] as int?,
        name: json['name'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        visitor_image: json['visitor_image'] as String? ?? '',
      ),
      visitor_purpose_category_id: json['visitor_purpose_category_id'] as int?,
      visitor_purpose_sub_category_id:
          json['visitor_purpose_sub_category_id'] as int?,
      visitor_building_assignment: (json['unit_details'] as List<dynamic>?)
          ?.map((unit) => BuildingAssignment(
                id: null,
                visitor_id: json['visitor_id'] as int?,
                visitor_log_id: json['visitor_log_id'] as int?,
                company_id: json['company_id'] as int? ?? 0,
                building_id: 0,
                unit_id: [unit['building_unit'] as String? ?? ''],
              ))
          .toList(),
      visitor_count: json['visitor_count'] as int?,
      visitor_check_in: json['visitor_check_in'] != null
          ? DateTime.tryParse(json['visitor_check_in'] as String)
          : null,
      visitor_check_out: json['visitor_check_out'] != null
          ? DateTime.tryParse(json['visitor_check_out'] as String)
          : null,
      visitor_card_number: json['visitor_card_number'] as String?,
      visitor_coming_from: json['visitor_coming_from'] as String?,
      visitor_card_id: json['visitor_card_id'] as int?,
      company_id: json['company_id'] as int?,
      is_checked_out: json['is_checked_out'] as bool?,
      carNumber: json['vehicle_number'] as String?,
      visitor_purpose_Category_name: json['purpose_category_name'] as String?,
      purpose_sub_category_name: json['purpose_sub_category_name'] as String?,
      initiated_from: json['additional_details'] is Map<String, dynamic>
          ? json['additional_details']['initiated_from'] as String?
          : null,
      approved_by: json['additional_details'] is Map<String, dynamic>
          ? json['additional_details']['approved_by'] as String?
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisitorLog &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          visitor_id == other.visitor_id &&
          visitor == other.visitor &&
          visitor_purpose_category_id == other.visitor_purpose_category_id &&
          visitor_purpose_sub_category_id ==
              other.visitor_purpose_sub_category_id;

  @override
  int get hashCode =>
      id.hashCode ^
      visitor_id.hashCode ^
      visitor.hashCode ^
      visitor_purpose_category_id.hashCode ^
      visitor_purpose_sub_category_id.hashCode;
}
