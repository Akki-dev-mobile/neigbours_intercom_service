/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'dart:async' as _i2;
import 'package:onegate_client/src/protocol/purpose_category.dart' as _i3;
import 'package:onegate_client/src/protocol/visitor.dart' as _i4;
import 'package:onegate_client/src/protocol/visitor_log.dart' as _i5;
import 'package:onegate_client/src/protocol/building_assignment.dart' as _i6;
import 'dart:io' as _i7;
import 'protocol.dart' as _i8;

class _EndpointExample extends _i1.EndpointRef {
  _EndpointExample(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'example';

  _i2.Future<String> hello(String name) => caller.callServerEndpoint<String>(
        'example',
        'hello',
        {'name': name},
      );
}

class _EndpointPurposeCategory extends _i1.EndpointRef {
  _EndpointPurposeCategory(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'purposeCategory';

  _i2.Future<List<_i3.PurposeCategory>> fetchPurposeCategory() =>
      caller.callServerEndpoint<List<_i3.PurposeCategory>>(
        'purposeCategory',
        'fetchPurposeCategory',
        {},
      );
}

class _EndpointVisitor extends _i1.EndpointRef {
  _EndpointVisitor(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'visitor';

  _i2.Future<_i4.Visitor?> fetchVisitor(String mobileNo) =>
      caller.callServerEndpoint<_i4.Visitor?>(
        'visitor',
        'fetchVisitor',
        {'mobileNo': mobileNo},
      );

  _i2.Future<_i4.Visitor> createVisitor(_i4.Visitor visitor) =>
      caller.callServerEndpoint<_i4.Visitor>(
        'visitor',
        'createVisitor',
        {'visitor': visitor},
      );
}

class _EndpointVisitorLog extends _i1.EndpointRef {
  _EndpointVisitorLog(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'visitorLog';

  _i2.Future<_i5.VisitorLog> createVisitorLog(_i5.VisitorLog visitorLog) =>
      caller.callServerEndpoint<_i5.VisitorLog>(
        'visitorLog',
        'createVisitorLog',
        {'visitorLog': visitorLog},
      );

  _i2.Future<_i6.BuildingAssignment> createBuildingAssignment(
          _i6.BuildingAssignment buildingAssignment) =>
      caller.callServerEndpoint<_i6.BuildingAssignment>(
        'visitorLog',
        'createBuildingAssignment',
        {'buildingAssignment': buildingAssignment},
      );

  _i2.Future<bool> checkOut(_i5.VisitorLog visitorLog) =>
      caller.callServerEndpoint<bool>(
        'visitorLog',
        'checkOut',
        {'visitorLog': visitorLog},
      );

  _i2.Future<List<_i5.VisitorLog>> fetchAllLogs(String dateTime) =>
      caller.callServerEndpoint<List<_i5.VisitorLog>>(
        'visitorLog',
        'fetchAllLogs',
        {'dateTime': dateTime},
      );

  _i2.Future<List<_i5.VisitorLog>> fetchCheckInLogs(String dateTime) =>
      caller.callServerEndpoint<List<_i5.VisitorLog>>(
        'visitorLog',
        'fetchCheckInLogs',
        {'dateTime': dateTime},
      );

  _i2.Future<List<_i5.VisitorLog>> fetchCheckOutLogs(String dateTime) =>
      caller.callServerEndpoint<List<_i5.VisitorLog>>(
        'visitorLog',
        'fetchCheckOutLogs',
        {'dateTime': dateTime},
      );
}

class Client extends _i1.ServerpodClient {
  Client(
    String host, {
    _i7.SecurityContext? context,
    _i1.AuthenticationKeyManager? authenticationKeyManager,
  }) : super(
          host,
          _i8.Protocol(),
          context: context,
          authenticationKeyManager: authenticationKeyManager,
        ) {
    example = _EndpointExample(this);
    purposeCategory = _EndpointPurposeCategory(this);
    visitor = _EndpointVisitor(this);
    visitorLog = _EndpointVisitorLog(this);
  }

  late final _EndpointExample example;

  late final _EndpointPurposeCategory purposeCategory;

  late final _EndpointVisitor visitor;

  late final _EndpointVisitorLog visitorLog;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
        'example': example,
        'purposeCategory': purposeCategory,
        'visitor': visitor,
        'visitorLog': visitorLog,
      };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {};
}
