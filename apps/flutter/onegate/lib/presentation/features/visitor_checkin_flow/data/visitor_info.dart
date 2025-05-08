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
  final String? visitor_check_in;
  final Map<String, dynamic>? additionalDetails;
  final String? companyName;
  final bool? isCheckedOut;
  final String? visitorCardNumber;
  final String? unitName;

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
    this.visitor_check_in,
    this.additionalDetails,
    this.companyName,
    this.isCheckedOut,
    this.visitorCardNumber,
    this.unitName,
  });

  factory VisitorInfo.fromJson(Map<String, dynamic> json) {
    // Parse unit details
    UnitDetails parsedUnitDetails = UnitDetails(unitId: 0, building_unit: '');
    
    try {
      final unitDetailsString = json['unit_details'];

      if (unitDetailsString is String) {
        // Handle the double-encoded JSON string case
        String cleanJson = unitDetailsString;
        
        // If the string starts and ends with quotes, remove them
        if (cleanJson.startsWith('"') && cleanJson.endsWith('"')) {
          cleanJson = cleanJson.substring(1, cleanJson.length - 1);
        }
        
        // Replace escaped quotes with regular quotes
        cleanJson = cleanJson.replaceAll(r'\"', '"');
        
        final List<dynamic> decodedUnitDetails = jsonDecode(cleanJson);

        if (decodedUnitDetails.isNotEmpty) {
          final unitJson = decodedUnitDetails.first;
          parsedUnitDetails = UnitDetails(
            unitId: _parseToInt(unitJson['unit_id']),
            building_unit: unitJson["building_unit"]?.toString() ?? '',
          );
          
          log("🔍 Parsed building_unit: ${parsedUnitDetails.building_unit}");
        }
      } else if (unitDetailsString is List) {
        if (unitDetailsString.isNotEmpty) {
          final unitJson = unitDetailsString.first;
          parsedUnitDetails = UnitDetails(
            unitId: _parseToInt(unitJson['unit_id']),
            building_unit: unitJson["building_unit"]?.toString() ?? '',
          );
          
          log("🔍 Parsed building_unit: ${parsedUnitDetails.building_unit}");
        }
      }
    } catch (e) {
      log("❌ Error decoding unit details: $e");
    }

    // Parse additional details
    Map<String, dynamic>? parsedAdditionalDetails;
    try {
      final dynamic additionalDetailsString = json['additional_details'];

      if (additionalDetailsString != null &&
          additionalDetailsString.toString().isNotEmpty) {
        if (additionalDetailsString is String) {
          parsedAdditionalDetails = jsonDecode(additionalDetailsString);
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
      visitor_check_out: json['visitor_check_out']?.toString(),
      visitor_check_in: json['visitor_check_in']?.toString(),
      visitorLogId: _parseToInt(json['visitor_log_id']),
      companyId: _parseToInt(json['company_id']),
      inGate: json['in_gate']?.toString() ?? '',
      logCreatedAt: json['log_created_at']?.toString() ?? '',
      unitDetails: parsedUnitDetails,
      memberInfo: MemberInfo(
        name: json['member_name']?.toString() ?? '',
        mobileNumber: json['memb_mobile_number']?.toString(),
        email: json['memb_email']?.toString(),
        memberId: _parseToInt(json['member_id']),
        unitId: _parseToInt(json['unit_id']),
        building_unit: json["unit_name"]?.toString() ?? json["building_unit"]?.toString(),
        userId: json["user_id"]?.toString(),
      ),
      visitorComingFrom: json['coming_from']?.toString(),
      visitorPurposeCategoryId: _parseToInt(json['purpose_category_id']),
      purposeCategoryName: json['purpose_category_name']?.toString(),
      purposeSubCategoryName: json['purpose_sub_category_name']?.toString(),
      additionalDetails: parsedAdditionalDetails,
      companyName: json['company_name']?.toString(),
      isCheckedOut: json['is_checked_out'] is bool 
          ? json['is_checked_out'] 
          : json['is_checked_out']?.toString().toLowerCase() == 'true',
      visitorCardNumber: json['visitor_card_number']?.toString(),
      unitName: json['unit_name']?.toString(),
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
      visitor_check_in: $visitor_check_in,
      visitor_check_out: $visitor_check_out,
      unitDetails: $unitDetails,
      additionalDetails: $additionalDetails,
      companyName: $companyName,
      isCheckedOut: $isCheckedOut,
      visitorCardNumber: $visitorCardNumber,
      unitName: $unitName
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
  final String? userId;

  MemberInfo({
    required this.name,
    this.mobileNumber,
    this.email,
    this.unitId,
    this.memberId,
    this.building_unit,
    this.userId,
  });
  
  @override
  String toString() {
    return 'MemberInfo(name: $name, mobileNumber: $mobileNumber, email: $email, unitId: $unitId, memberId: $memberId, building_unit: $building_unit, userId: $userId)';
  }
}

class UnitDetails {
  final int? unitId;
  final String? building_unit;

  UnitDetails({this.unitId, this.building_unit});
  
  @override
  String toString() {
    return 'UnitDetails(unitId: $unitId, building_unit: $building_unit)';
  }
}

// Example of a response parser for the API response
class VisitorResponse {
  final bool success;
  final List<VisitorInfo> data;
  final String message;
  final int statusCode;

  VisitorResponse({
    required this.success,
    required this.data,
    required this.message,
    required this.statusCode,
  });

  factory VisitorResponse.fromJson(Map<String, dynamic> json) {
    return VisitorResponse(
      success: json['success'] ?? false,
      data: (json['data'] as List?)
          ?.map((item) => VisitorInfo.fromJson(item))
          .toList() ?? [],
      message: json['message'] ?? '',
      statusCode: json['status_code'] ?? 0,
    );
  }
}