/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

library protocol; // ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'building_assignment.dart' as _i2;
import 'member_staff.dart' as _i3;
import 'purpose_category.dart' as _i4;
import 'purpose_sub_category.dart' as _i5;
import 'staff_category.dart' as _i6;
import 'staff_sub_category.dart' as _i7;
import 'visitor.dart' as _i8;
import 'visitor_card.dart' as _i9;
import 'visitor_log.dart' as _i10;
import 'protocol.dart' as _i11;
import 'package:onegate_client/src/protocol/purpose_category.dart' as _i12;
import 'package:onegate_client/src/protocol/visitor_log.dart' as _i13;
export 'building_assignment.dart';
export 'member_staff.dart';
export 'purpose_category.dart';
export 'purpose_sub_category.dart';
export 'staff_category.dart';
export 'staff_sub_category.dart';
export 'visitor.dart';
export 'visitor_card.dart';
export 'visitor_log.dart';
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
    if (t == _i2.BuildingAssignment) {
      return _i2.BuildingAssignment.fromJson(data, this) as T;
    }
    if (t == _i3.MemberStaff) {
      return _i3.MemberStaff.fromJson(data, this) as T;
    }
    if (t == _i4.PurposeCategory) {
      return _i4.PurposeCategory.fromJson(data, this) as T;
    }
    if (t == _i5.PurposeSubCategory) {
      return _i5.PurposeSubCategory.fromJson(data, this) as T;
    }
    if (t == _i6.StaffCategory) {
      return _i6.StaffCategory.fromJson(data, this) as T;
    }
    if (t == _i7.StaffSubCategory) {
      return _i7.StaffSubCategory.fromJson(data, this) as T;
    }
    if (t == _i8.Visitor) {
      return _i8.Visitor.fromJson(data, this) as T;
    }
    if (t == _i9.VisitorCard) {
      return _i9.VisitorCard.fromJson(data, this) as T;
    }
    if (t == _i10.VisitorLog) {
      return _i10.VisitorLog.fromJson(data, this) as T;
    }
    if (t == _i1.getType<_i2.BuildingAssignment?>()) {
      return (data != null ? _i2.BuildingAssignment.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i3.MemberStaff?>()) {
      return (data != null ? _i3.MemberStaff.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i4.PurposeCategory?>()) {
      return (data != null ? _i4.PurposeCategory.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i5.PurposeSubCategory?>()) {
      return (data != null ? _i5.PurposeSubCategory.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i6.StaffCategory?>()) {
      return (data != null ? _i6.StaffCategory.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i7.StaffSubCategory?>()) {
      return (data != null ? _i7.StaffSubCategory.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i8.Visitor?>()) {
      return (data != null ? _i8.Visitor.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i9.VisitorCard?>()) {
      return (data != null ? _i9.VisitorCard.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i10.VisitorLog?>()) {
      return (data != null ? _i10.VisitorLog.fromJson(data, this) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList()
          as dynamic;
    }
    if (t == List<_i11.BuildingAssignment>) {
      return (data as List)
          .map((e) => deserialize<_i11.BuildingAssignment>(e))
          .toList() as dynamic;
    }
    if (t == _i1.getType<List<_i11.BuildingAssignment>?>()) {
      return (data != null
          ? (data as List)
              .map((e) => deserialize<_i11.BuildingAssignment>(e))
              .toList()
          : null) as dynamic;
    }
    if (t == List<_i12.PurposeCategory>) {
      return (data as List)
          .map((e) => deserialize<_i12.PurposeCategory>(e))
          .toList() as dynamic;
    }
    if (t == List<_i13.VisitorLog>) {
      return (data as List).map((e) => deserialize<_i13.VisitorLog>(e)).toList()
          as dynamic;
    }
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object data) {
    if (data is _i2.BuildingAssignment) {
      return 'BuildingAssignment';
    }
    if (data is _i3.MemberStaff) {
      return 'MemberStaff';
    }
    if (data is _i4.PurposeCategory) {
      return 'PurposeCategory';
    }
    if (data is _i5.PurposeSubCategory) {
      return 'PurposeSubCategory';
    }
    if (data is _i6.StaffCategory) {
      return 'StaffCategory';
    }
    if (data is _i7.StaffSubCategory) {
      return 'StaffSubCategory';
    }
    if (data is _i8.Visitor) {
      return 'Visitor';
    }
    if (data is _i9.VisitorCard) {
      return 'VisitorCard';
    }
    if (data is _i10.VisitorLog) {
      return 'VisitorLog';
    }
    return super.getClassNameForObject(data);
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    if (data['className'] == 'BuildingAssignment') {
      return deserialize<_i2.BuildingAssignment>(data['data']);
    }
    if (data['className'] == 'MemberStaff') {
      return deserialize<_i3.MemberStaff>(data['data']);
    }
    if (data['className'] == 'PurposeCategory') {
      return deserialize<_i4.PurposeCategory>(data['data']);
    }
    if (data['className'] == 'PurposeSubCategory') {
      return deserialize<_i5.PurposeSubCategory>(data['data']);
    }
    if (data['className'] == 'StaffCategory') {
      return deserialize<_i6.StaffCategory>(data['data']);
    }
    if (data['className'] == 'StaffSubCategory') {
      return deserialize<_i7.StaffSubCategory>(data['data']);
    }
    if (data['className'] == 'Visitor') {
      return deserialize<_i8.Visitor>(data['data']);
    }
    if (data['className'] == 'VisitorCard') {
      return deserialize<_i9.VisitorCard>(data['data']);
    }
    if (data['className'] == 'VisitorLog') {
      return deserialize<_i10.VisitorLog>(data['data']);
    }
    return super.deserializeByClassName(data);
  }
}
