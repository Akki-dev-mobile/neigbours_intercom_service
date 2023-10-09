/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

library protocol; // ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'building_assignment.dart' as _i2;
import 'example.dart' as _i3;
import 'member_staff.dart' as _i4;
import 'purpose_category.dart' as _i5;
import 'purpose_sub_category.dart' as _i6;
import 'staff_category.dart' as _i7;
import 'staff_sub_category.dart' as _i8;
import 'visitor.dart' as _i9;
import 'visitor_card.dart' as _i10;
import 'visitor_log.dart' as _i11;
import 'protocol.dart' as _i12;
import 'package:onegate_client/src/protocol/purpose_category.dart' as _i13;
import 'package:onegate_client/src/protocol/visitor_log.dart' as _i14;
export 'building_assignment.dart';
export 'example.dart';
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
    if (t == _i3.Example) {
      return _i3.Example.fromJson(data, this) as T;
    }
    if (t == _i4.MemberStaff) {
      return _i4.MemberStaff.fromJson(data, this) as T;
    }
    if (t == _i5.PurposeCategory) {
      return _i5.PurposeCategory.fromJson(data, this) as T;
    }
    if (t == _i6.PurposeSubCategory) {
      return _i6.PurposeSubCategory.fromJson(data, this) as T;
    }
    if (t == _i7.StaffCategory) {
      return _i7.StaffCategory.fromJson(data, this) as T;
    }
    if (t == _i8.StaffSubCategory) {
      return _i8.StaffSubCategory.fromJson(data, this) as T;
    }
    if (t == _i9.Visitor) {
      return _i9.Visitor.fromJson(data, this) as T;
    }
    if (t == _i10.VisitorCard) {
      return _i10.VisitorCard.fromJson(data, this) as T;
    }
    if (t == _i11.VisitorLog) {
      return _i11.VisitorLog.fromJson(data, this) as T;
    }
    if (t == _i1.getType<_i2.BuildingAssignment?>()) {
      return (data != null ? _i2.BuildingAssignment.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i3.Example?>()) {
      return (data != null ? _i3.Example.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i4.MemberStaff?>()) {
      return (data != null ? _i4.MemberStaff.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i5.PurposeCategory?>()) {
      return (data != null ? _i5.PurposeCategory.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i6.PurposeSubCategory?>()) {
      return (data != null ? _i6.PurposeSubCategory.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i7.StaffCategory?>()) {
      return (data != null ? _i7.StaffCategory.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i8.StaffSubCategory?>()) {
      return (data != null ? _i8.StaffSubCategory.fromJson(data, this) : null)
          as T;
    }
    if (t == _i1.getType<_i9.Visitor?>()) {
      return (data != null ? _i9.Visitor.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i10.VisitorCard?>()) {
      return (data != null ? _i10.VisitorCard.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i11.VisitorLog?>()) {
      return (data != null ? _i11.VisitorLog.fromJson(data, this) : null) as T;
    }
    if (t == List<int>) {
      return (data as List).map((e) => deserialize<int>(e)).toList() as dynamic;
    }
    if (t == List<_i12.BuildingAssignment>) {
      return (data as List)
          .map((e) => deserialize<_i12.BuildingAssignment>(e))
          .toList() as dynamic;
    }
    if (t == List<_i13.PurposeCategory>) {
      return (data as List)
          .map((e) => deserialize<_i13.PurposeCategory>(e))
          .toList() as dynamic;
    }
    if (t == List<_i14.VisitorLog>) {
      return (data as List).map((e) => deserialize<_i14.VisitorLog>(e)).toList()
          as dynamic;
    }
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object data) {
    if (data is _i2.BuildingAssignment) {
      return 'BuildingAssignment';
    }
    if (data is _i3.Example) {
      return 'Example';
    }
    if (data is _i4.MemberStaff) {
      return 'MemberStaff';
    }
    if (data is _i5.PurposeCategory) {
      return 'PurposeCategory';
    }
    if (data is _i6.PurposeSubCategory) {
      return 'PurposeSubCategory';
    }
    if (data is _i7.StaffCategory) {
      return 'StaffCategory';
    }
    if (data is _i8.StaffSubCategory) {
      return 'StaffSubCategory';
    }
    if (data is _i9.Visitor) {
      return 'Visitor';
    }
    if (data is _i10.VisitorCard) {
      return 'VisitorCard';
    }
    if (data is _i11.VisitorLog) {
      return 'VisitorLog';
    }
    return super.getClassNameForObject(data);
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    if (data['className'] == 'BuildingAssignment') {
      return deserialize<_i2.BuildingAssignment>(data['data']);
    }
    if (data['className'] == 'Example') {
      return deserialize<_i3.Example>(data['data']);
    }
    if (data['className'] == 'MemberStaff') {
      return deserialize<_i4.MemberStaff>(data['data']);
    }
    if (data['className'] == 'PurposeCategory') {
      return deserialize<_i5.PurposeCategory>(data['data']);
    }
    if (data['className'] == 'PurposeSubCategory') {
      return deserialize<_i6.PurposeSubCategory>(data['data']);
    }
    if (data['className'] == 'StaffCategory') {
      return deserialize<_i7.StaffCategory>(data['data']);
    }
    if (data['className'] == 'StaffSubCategory') {
      return deserialize<_i8.StaffSubCategory>(data['data']);
    }
    if (data['className'] == 'Visitor') {
      return deserialize<_i9.Visitor>(data['data']);
    }
    if (data['className'] == 'VisitorCard') {
      return deserialize<_i10.VisitorCard>(data['data']);
    }
    if (data['className'] == 'VisitorLog') {
      return deserialize<_i11.VisitorLog>(data['data']);
    }
    return super.deserializeByClassName(data);
  }
}
