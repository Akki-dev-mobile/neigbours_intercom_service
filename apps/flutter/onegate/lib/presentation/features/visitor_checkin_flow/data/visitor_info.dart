import 'dart:convert';
import 'dart:developer';

class VisitorInfo {
  final int visitorId;
  final String visitorName;
  final String visitorMobile;
  final String visitorImage;
  final String allowStatus;
  final int? visitorCount;
  final int? visitorLogId;
  final int companyId;
  final String inGate;
  final String logCreatedAt;
  final MemberInfo memberInfo;
  final String? visitorComingFrom;
  final int? visitorPurposeCategoryId;
  final String? purposeCategoryName;
  final String? purposeSubCategoryName;
  final UnitDetails unitDetails;
  final String? visitor_check_out;
  final Map<String, dynamic>? additionalDetails; // Parsed Additional Details

  VisitorInfo({
    required this.visitorId,
    this.visitorCount,
    required this.visitorName,
    required this.visitorMobile,
    required this.visitorImage,
    required this.allowStatus,
    this.visitorLogId,
    required this.unitDetails,
    required this.companyId,
    required this.inGate,
    required this.logCreatedAt,
    required this.memberInfo,
    this.visitorComingFrom,
    this.visitorPurposeCategoryId,
    this.purposeCategoryName,
    this.purposeSubCategoryName,
    this.visitor_check_out,
    this.additionalDetails, // Include Additional Details
  });

  factory VisitorInfo.fromJson(Map<String, dynamic> json) {
    List<UnitDetails> parsedUnitDetails = [];

    try {
      final unitDetailsString = json['unit_details'];

      if (unitDetailsString is String) {
        final List<dynamic> decodedUnitDetails = jsonDecode(unitDetailsString);

        parsedUnitDetails = decodedUnitDetails.map<UnitDetails>((unitJson) {
          final unit = UnitDetails(
            unitId: _parseToInt(unitJson['unit_id']),
            building_unit: unitJson["building_unit"]?.toString() ?? '',
          );

          log("🔍 Parsed building_unit: ${unit.building_unit}");

          return unit;
        }).toList();
      } else if (unitDetailsString is List) {
        parsedUnitDetails = unitDetailsString.map<UnitDetails>((unitJson) {
          final unit = UnitDetails(
            unitId: _parseToInt(unitJson['unit_id']),
            building_unit: unitJson["building_unit"]?.toString() ?? '',
          );

          log("🔍 Parsed building_unit: ${unit.building_unit}");

          return unit;
        }).toList();
      }
    } catch (e) {
      log("❌ Error decoding unit details: $e");
    }

    // ✅ Fix for `additional_details` Parsing
    Map<String, dynamic>? parsedAdditionalDetails;
    try {
      final dynamic additionalDetailsString = json['additional_details'];

      if (additionalDetailsString != null &&
          additionalDetailsString.toString().isNotEmpty) {
        if (additionalDetailsString is String) {
          parsedAdditionalDetails = jsonDecode(additionalDetailsString
              .replaceAll(r'\"', '"')); // Handle escaped quotes
        } else if (additionalDetailsString is Map<String, dynamic>) {
          parsedAdditionalDetails = additionalDetailsString;
        }
      }
    } catch (e) {
      log("❌ Error parsing additional_details: $e");
      parsedAdditionalDetails = {};
    }


    return VisitorInfo(
      visitorId: _parseToInt(json['visitor_id']),
      visitorName: json['visitor_name']?.toString() ?? '',
      visitorMobile: json['visitor_mobile']?.toString() ?? '',
      visitorImage: json['visitor_image']?.toString() ?? '',
      allowStatus: json['allow_status']?.toString() ?? '',
      visitorCount: _parseToInt(json['visitor_count']),

      visitor_check_out: json['visitor_check_out']?.toString() ?? '',
      visitorLogId: _parseToInt(json['visitor_log_id']),
      companyId: _parseToInt(json['company_id']),
      inGate: json['in_gate']?.toString() ?? '',
      logCreatedAt: json['log_created_at']?.toString() ?? '',
      unitDetails: parsedUnitDetails.isNotEmpty
          ? parsedUnitDetails.first
          : UnitDetails(unitId: 0, building_unit: ''),
      memberInfo: MemberInfo(
        name: json['member_name']?.toString() ?? '',
        mobileNumber: json['memb_mobile_number']?.toString(),
        email: json['memb_email']?.toString(),
        memberId: _parseToInt(json['member_id']),
        unitId: _parseToInt(json['unit_id']),
        building_unit: json["building_unit"]?.toString(),
      ),
      visitorComingFrom: json['visitor_coming_from']?.toString(),
      visitorPurposeCategoryId: _parseToInt(json['purpose_category_id']),
      purposeCategoryName: json['purpose_category_name']?.toString(),
      purposeSubCategoryName: json['purpose_sub_category_name']?.toString(),
      additionalDetails:
          parsedAdditionalDetails, // ✅ Correctly parsed `additional_details`
    );
  }

  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  @override
  String toString() {
    return '''
    VisitorInfo(
      visitorId: $visitorId, 
      visitorName: $visitorName, 
      visitorMobile: $visitorMobile, 
      allowStatus: $allowStatus, 
      visitorLogId: $visitorLogId, 
      visitorCount: $visitorCount,
      companyId: $companyId, 
      inGate: $inGate, 
      logCreatedAt: $logCreatedAt, 
      visitorComingFrom: $visitorComingFrom, 
      visitorPurposeCategoryId: $visitorPurposeCategoryId,
      purposeCategoryName: $purposeCategoryName,
      purposeSubCategoryName: $purposeSubCategoryName,
      memberInfo: $memberInfo,
      visitorImage: $visitorImage,
      visitor_check_out: $visitor_check_out,
      unitDetails: $unitDetails,
      additionalDetails: $additionalDetails
    )
    ''';
  }
}

class MemberInfo {
  final String name;
  final String? mobileNumber;
  final String? email;
  final int? unitId;
  final int? memberId;
  final String? building_unit;

  MemberInfo(
      {required this.name,
      this.mobileNumber,
      this.email,
      this.unitId,
      this.memberId,
      this.building_unit});
}

class UnitDetails {
  final int? unitId;

  final String? building_unit;

  UnitDetails({this.unitId, this.building_unit});
}
