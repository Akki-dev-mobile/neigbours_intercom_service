/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import '../endpoints/purpose_endpoint.dart' as _i2;
import '../endpoints/visitor_endpoint.dart' as _i3;
import '../endpoints/visitor_log_endpoint.dart' as _i4;
import 'package:onegate_server/src/generated/visitor.dart' as _i5;
import 'package:onegate_server/src/generated/visitor_log.dart' as _i6;
import 'package:onegate_server/src/generated/building_assignment.dart' as _i7;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'purposeCategory': _i2.PurposeCategoryEndpoint()
        ..initialize(
          server,
          'purposeCategory',
          null,
        ),
      'visitor': _i3.VisitorEndpoint()
        ..initialize(
          server,
          'visitor',
          null,
        ),
      'visitorLog': _i4.VisitorLogEndpoint()
        ..initialize(
          server,
          'visitorLog',
          null,
        ),
    };
    connectors['purposeCategory'] = _i1.EndpointConnector(
      name: 'purposeCategory',
      endpoint: endpoints['purposeCategory']!,
      methodConnectors: {
        'fetchPurposeCategory': _i1.MethodConnector(
          name: 'fetchPurposeCategory',
          params: {},
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async =>
              (endpoints['purposeCategory'] as _i2.PurposeCategoryEndpoint)
                  .fetchPurposeCategory(session),
        )
      },
    );
    connectors['visitor'] = _i1.EndpointConnector(
      name: 'visitor',
      endpoint: endpoints['visitor']!,
      methodConnectors: {
        'fetchVisitor': _i1.MethodConnector(
          name: 'fetchVisitor',
          params: {
            'mobileNo': _i1.ParameterDescription(
              name: 'mobileNo',
              type: _i1.getType<String>(),
              nullable: false,
            )
          },
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async =>
              (endpoints['visitor'] as _i3.VisitorEndpoint).fetchVisitor(
            session,
            params['mobileNo'],
          ),
        ),
        'createVisitor': _i1.MethodConnector(
          name: 'createVisitor',
          params: {
            'visitor': _i1.ParameterDescription(
              name: 'visitor',
              type: _i1.getType<_i5.Visitor>(),
              nullable: false,
            )
          },
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async =>
              (endpoints['visitor'] as _i3.VisitorEndpoint).createVisitor(
            session,
            params['visitor'],
          ),
        ),
        'updateVisitor': _i1.MethodConnector(
          name: 'updateVisitor',
          params: {
            'visitor': _i1.ParameterDescription(
              name: 'visitor',
              type: _i1.getType<_i5.Visitor>(),
              nullable: false,
            )
          },
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async =>
              (endpoints['visitor'] as _i3.VisitorEndpoint).updateVisitor(
            session,
            params['visitor'],
          ),
        ),
      },
    );
    connectors['visitorLog'] = _i1.EndpointConnector(
      name: 'visitorLog',
      endpoint: endpoints['visitorLog']!,
      methodConnectors: {
        'createVisitorLog': _i1.MethodConnector(
          name: 'createVisitorLog',
          params: {
            'visitorLog': _i1.ParameterDescription(
              name: 'visitorLog',
              type: _i1.getType<_i6.VisitorLog>(),
              nullable: false,
            )
          },
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async =>
              (endpoints['visitorLog'] as _i4.VisitorLogEndpoint)
                  .createVisitorLog(
            session,
            params['visitorLog'],
          ),
        ),
        'createBuildingAssignment': _i1.MethodConnector(
          name: 'createBuildingAssignment',
          params: {
            'buildingAssignment': _i1.ParameterDescription(
              name: 'buildingAssignment',
              type: _i1.getType<_i7.BuildingAssignment>(),
              nullable: false,
            )
          },
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async =>
              (endpoints['visitorLog'] as _i4.VisitorLogEndpoint)
                  .createBuildingAssignment(
            session,
            params['buildingAssignment'],
          ),
        ),
        'checkOut': _i1.MethodConnector(
          name: 'checkOut',
          params: {
            'visitorLog': _i1.ParameterDescription(
              name: 'visitorLog',
              type: _i1.getType<_i6.VisitorLog>(),
              nullable: false,
            )
          },
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async =>
              (endpoints['visitorLog'] as _i4.VisitorLogEndpoint).checkOut(
            session,
            params['visitorLog'],
          ),
        ),
        'fetchAllLogs': _i1.MethodConnector(
          name: 'fetchAllLogs',
          params: {
            'dateTime': _i1.ParameterDescription(
              name: 'dateTime',
              type: _i1.getType<String>(),
              nullable: false,
            )
          },
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async =>
              (endpoints['visitorLog'] as _i4.VisitorLogEndpoint).fetchAllLogs(
            session,
            params['dateTime'],
          ),
        ),
        'fetchCheckInLogs': _i1.MethodConnector(
          name: 'fetchCheckInLogs',
          params: {
            'dateTime': _i1.ParameterDescription(
              name: 'dateTime',
              type: _i1.getType<String>(),
              nullable: false,
            )
          },
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async =>
              (endpoints['visitorLog'] as _i4.VisitorLogEndpoint)
                  .fetchCheckInLogs(
            session,
            params['dateTime'],
          ),
        ),
        'fetchCheckOutLogs': _i1.MethodConnector(
          name: 'fetchCheckOutLogs',
          params: {
            'dateTime': _i1.ParameterDescription(
              name: 'dateTime',
              type: _i1.getType<String>(),
              nullable: false,
            )
          },
          call: (
            _i1.Session session,
            Map<String, dynamic> params,
          ) async =>
              (endpoints['visitorLog'] as _i4.VisitorLogEndpoint)
                  .fetchCheckOutLogs(
            session,
            params['dateTime'],
          ),
        ),
      },
    );
  }
}
