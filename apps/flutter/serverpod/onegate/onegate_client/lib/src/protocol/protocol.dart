/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

library protocol; // ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'example.dart' as _i2;
import 'member_staff.dart' as _i3;
import 'member_staff_building_unit.dart' as _i4;
import 'member_staff_categories.dart' as _i5;
import 'member_staff_sub_categories.dart' as _i6;
import 'protocol.dart' as _i7;
export 'example.dart';
export 'member_staff.dart';
export 'member_staff_building_unit.dart';
export 'member_staff_categories.dart';
export 'member_staff_sub_categories.dart';
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
    if (t == _i2.Example) {
      return _i2.Example.fromJson(data, this) as T;
    }
    if (t == _i3.MemberStaff) {
      return _i3.MemberStaff.fromJson(data, this) as T;
    }
    if (t == _i4.MemberStaffBuildingUnit) {
      return _i4.MemberStaffBuildingUnit.fromJson(data, this) as T;
    }
    if (t == _i5.MemberStaffCategories) {
      return _i5.MemberStaffCategories.fromJson(data, this) as T;
    }
    if (t == _i6.MemberStaffSubCategories) {
      return _i6.MemberStaffSubCategories.fromJson(data, this) as T;
    }
    if (t == _i1.getType<_i2.Example?>()) {
      return (data != null ? _i2.Example.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i3.MemberStaff?>()) {
      return (data != null ? _i3.MemberStaff.fromJson(data, this) : null) as T;
    }
    if (t == _i1.getType<_i4.MemberStaffBuildingUnit?>()) {
      return (data != null
          ? _i4.MemberStaffBuildingUnit.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<_i5.MemberStaffCategories?>()) {
      return (data != null
          ? _i5.MemberStaffCategories.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<_i6.MemberStaffSubCategories?>()) {
      return (data != null
          ? _i6.MemberStaffSubCategories.fromJson(data, this)
          : null) as T;
    }
    if (t == _i1.getType<List<_i7.MemberStaffBuildingUnit>?>()) {
      return (data != null
          ? (data as List)
              .map((e) => deserialize<_i7.MemberStaffBuildingUnit>(e))
              .toList()
          : null) as dynamic;
    }
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object data) {
    if (data is _i2.Example) {
      return 'Example';
    }
    if (data is _i3.MemberStaff) {
      return 'MemberStaff';
    }
    if (data is _i4.MemberStaffBuildingUnit) {
      return 'MemberStaffBuildingUnit';
    }
    if (data is _i5.MemberStaffCategories) {
      return 'MemberStaffCategories';
    }
    if (data is _i6.MemberStaffSubCategories) {
      return 'MemberStaffSubCategories';
    }
    return super.getClassNameForObject(data);
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    if (data['className'] == 'Example') {
      return deserialize<_i2.Example>(data['data']);
    }
    if (data['className'] == 'MemberStaff') {
      return deserialize<_i3.MemberStaff>(data['data']);
    }
    if (data['className'] == 'MemberStaffBuildingUnit') {
      return deserialize<_i4.MemberStaffBuildingUnit>(data['data']);
    }
    if (data['className'] == 'MemberStaffCategories') {
      return deserialize<_i5.MemberStaffCategories>(data['data']);
    }
    if (data['className'] == 'MemberStaffSubCategories') {
      return deserialize<_i6.MemberStaffSubCategories>(data['data']);
    }
    return super.deserializeByClassName(data);
  }
}
