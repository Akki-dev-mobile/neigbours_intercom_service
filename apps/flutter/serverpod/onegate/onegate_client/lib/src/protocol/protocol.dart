/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

library protocol; // ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'delivery_visitors.dart' as _i2;
import 'example.dart' as _i3;
import 'guest_visitors.dart' as _i4;
import 'member_categories.dart' as _i5;
import 'member_staff.dart' as _i6;
import 'member_sub_categories.dart' as _i7;
import 'staff_building_units.dart' as _i8;
import 'staff_companies.dart' as _i9;
import 'staff_company_building.dart' as _i10;
import 'staff_visitors.dart' as _i11;
import 'transport_visitors.dart' as _i12;
import 'vendor_visitors.dart' as _i13;
import 'verification_types.dart' as _i14;
import 'visitor_building_units.dart' as _i15;
import 'visitor_companies.dart' as _i16;
import 'visitor_company_buildings.dart' as _i17;
import 'visitors.dart' as _i18;
export 'delivery_visitors.dart';
export 'example.dart';
export 'guest_visitors.dart';
export 'member_categories.dart';
export 'member_staff.dart';
export 'member_sub_categories.dart';
export 'staff_building_units.dart';
export 'staff_companies.dart';
export 'staff_company_building.dart';
export 'staff_visitors.dart';
export 'transport_visitors.dart';
export 'vendor_visitors.dart';
export 'verification_types.dart';
export 'visitor_building_units.dart';
export 'visitor_companies.dart';
export 'visitor_company_buildings.dart';
export 'visitors.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Map<Type, _i1.constructor> customConstructors = {};

  static final Protocol _instance = Protocol._();

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;
    if (customConstructors.containsKey(t)) {
      return customConstructors[t]!(data, this) as T;
    }
    if (t == _i2.DeliveryVisitors) {
      return _i2.DeliveryVisitors.fromJson(data, this) as T;
    }
    if (t == _i3.Example) {
      return _i3.Example.fromJson(data, this) as T;
    }
    if (t == _i4.GuestVisitors) {
      return _i4.GuestVisitors.fromJson(data, this) as T;
    }
    if (t == _i5.MemberCategories) {
      return _i5.MemberCategories.fromJson(data, this) as T;
    }
    if (t == _i6.MemberStaff) {
      return _i6.MemberStaff.fromJson(data, this) as T;
    }
    if (t == _i7.MemberSubCategories) {
      return _i7.MemberSubCategories.fromJson(data, this) as T;
    }
    if (t == _i8.StaffBuildingUnits) {
      return _i8.StaffBuildingUnits.fromJson(data, this) as T;
    }
    if (t == _i9.StaffCompanies) {
      return _i9.StaffCompanies.fromJson(data, this) as T;
    }
    if (t == _i10.StaffCompanyBuilding) {
      return _i10.StaffCompanyBuilding.fromJson(data, this) as T;
    }
    if (t == _i11.StaffVisitors) {
      return _i11.StaffVisitors.fromJson(data, this) as T;
    }
    if (t == _i12.TransportVisitors) {
      return _i12.TransportVisitors.fromJson(data, this) as T;
    }
    if (t == _i13.VendorVisitors) {
      return _i13.VendorVisitors.fromJson(data, this) as T;
    }
    if (t == _i14.VerificationTypes) {
      return _i14.VerificationTypes.fromJson(data, this) as T;
    }
    if (t == _i15.VisitorBuildingUnits) {
      return _i15.VisitorBuildingUnits.fromJson(data, this) as T;
    }
    if (t == _i16.VisitorCompanies) {
      return _i16.VisitorCompanies.fromJson(data, this) as T;
    }
    if (t == _i17.VisitorCompanyBuildings) {
      return _i17.VisitorCompanyBuildings.fromJson(data, this) as T;
    }
    if (t == _i18.Visitors) {
      return _i18.Visitors.fromJson(data, this) as T;
    }
    if (t == _i1.getType<_i2.DeliveryVisitors?>()) {
      return (data != null ? _i2.DeliveryVisitors.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i3.Example?>()) {
      return (data != null ? _i3.Example.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i4.GuestVisitors?>()) {
      return (data != null ? _i4.GuestVisitors.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i5.MemberCategories?>()) {
      return (data != null ? _i5.MemberCategories.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i6.MemberStaff?>()) {
      return (data != null ? _i6.MemberStaff.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i7.MemberSubCategories?>()) {
      return (data != null
          ? _i7.MemberSubCategories.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<_i8.StaffBuildingUnits?>()) {
      return (data != null ? _i8.StaffBuildingUnits.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i9.StaffCompanies?>()) {
      return (data != null ? _i9.StaffCompanies.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i10.StaffCompanyBuilding?>()) {
      return (data != null
          ? _i10.StaffCompanyBuilding.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<_i11.StaffVisitors?>()) {
      return (data != null ? _i11.StaffVisitors.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i12.TransportVisitors?>()) {
      return (data != null ? _i12.TransportVisitors.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i13.VendorVisitors?>()) {
      return (data != null ? _i13.VendorVisitors.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i14.VerificationTypes?>()) {
      return (data != null ? _i14.VerificationTypes.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i15.VisitorBuildingUnits?>()) {
      return (data != null
          ? _i15.VisitorBuildingUnits.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<_i16.VisitorCompanies?>()) {
      return (data != null ? _i16.VisitorCompanies.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i17.VisitorCompanyBuildings?>()) {
      return (data != null
          ? _i17.VisitorCompanyBuildings.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<_i18.Visitors?>()) {
      return (data != null ? _i18.Visitors.fromJson(data, this) : null) as T;
    }
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object data) {
    if (data is _i2.DeliveryVisitors) {
      return 'DeliveryVisitors';
    }
    if (data is _i3.Example) {
      return 'Example';
    }
    if (data is _i4.GuestVisitors) {
      return 'GuestVisitors';
    }
    if (data is _i5.MemberCategories) {
      return 'MemberCategories';
    }
    if (data is _i6.MemberStaff) {
      return 'MemberStaff';
    }
    if (data is _i7.MemberSubCategories) {
      return 'MemberSubCategories';
    }
    if (data is _i8.StaffBuildingUnits) {
      return 'StaffBuildingUnits';
    }
    if (data is _i9.StaffCompanies) {
      return 'StaffCompanies';
    }
    if (data is _i10.StaffCompanyBuilding) {
      return 'StaffCompanyBuilding';
    }
    if (data is _i11.StaffVisitors) {
      return 'StaffVisitors';
    }
    if (data is _i12.TransportVisitors) {
      return 'TransportVisitors';
    }
    if (data is _i13.VendorVisitors) {
      return 'VendorVisitors';
    }
    if (data is _i14.VerificationTypes) {
      return 'VerificationTypes';
    }
    if (data is _i15.VisitorBuildingUnits) {
      return 'VisitorBuildingUnits';
    }
    if (data is _i16.VisitorCompanies) {
      return 'VisitorCompanies';
    }
    if (data is _i17.VisitorCompanyBuildings) {
      return 'VisitorCompanyBuildings';
    }
    if (data is _i18.Visitors) {
      return 'Visitors';
    }
    return super.getClassNameForObject(data);
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    if (data['className'] == 'DeliveryVisitors') {
      return deserialize<_i2.DeliveryVisitors>(data['data']);
    }
    if (data['className'] == 'Example') {
      return deserialize<_i3.Example>(data['data']);
    }
    if (data['className'] == 'GuestVisitors') {
      return deserialize<_i4.GuestVisitors>(data['data']);
    }
    if (data['className'] == 'MemberCategories') {
      return deserialize<_i5.MemberCategories>(data['data']);
    }
    if (data['className'] == 'MemberStaff') {
      return deserialize<_i6.MemberStaff>(data['data']);
    }
    if (data['className'] == 'MemberSubCategories') {
      return deserialize<_i7.MemberSubCategories>(data['data']);
    }
    if (data['className'] == 'StaffBuildingUnits') {
      return deserialize<_i8.StaffBuildingUnits>(data['data']);
    }
    if (data['className'] == 'StaffCompanies') {
      return deserialize<_i9.StaffCompanies>(data['data']);
    }
    if (data['className'] == 'StaffCompanyBuilding') {
      return deserialize<_i10.StaffCompanyBuilding>(data['data']);
    }
    if (data['className'] == 'StaffVisitors') {
      return deserialize<_i11.StaffVisitors>(data['data']);
    }
    if (data['className'] == 'TransportVisitors') {
      return deserialize<_i12.TransportVisitors>(data['data']);
    }
    if (data['className'] == 'VendorVisitors') {
      return deserialize<_i13.VendorVisitors>(data['data']);
    }
    if (data['className'] == 'VerificationTypes') {
      return deserialize<_i14.VerificationTypes>(data['data']);
    }
    if (data['className'] == 'VisitorBuildingUnits') {
      return deserialize<_i15.VisitorBuildingUnits>(data['data']);
    }
    if (data['className'] == 'VisitorCompanies') {
      return deserialize<_i16.VisitorCompanies>(data['data']);
    }
    if (data['className'] == 'VisitorCompanyBuildings') {
      return deserialize<_i17.VisitorCompanyBuildings>(data['data']);
    }
    if (data['className'] == 'Visitors') {
      return deserialize<_i18.Visitors>(data['data']);
    }
    return super.deserializeByClassName(data);
  }
}
