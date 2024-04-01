import 'package:dio/dio.dart';
import 'package:flutter_onegate/domain/entities/society/building.dart';
import 'package:flutter_onegate/domain/entities/society/member_unit.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

var client = Client('https://gateapi.cubeone.in')
//var client = Client('http://localhost:8080/')
  ..connectivityMonitor = FlutterConnectivityMonitor();

class RemoteDataSource {
  final Dio _dio1;
  final Dio _dio2;
  final Dio _dio3;

  RemoteDataSource(this._dio1, this._dio2, this._dio3);

  Future<Map<String, dynamic>> loginUser(
      String username, String password, String method) async {
    try {
      final response = await _dio1.post('/login',
          data: {'username': "91$username", 'password': password});

      return response.data['data'];
    } catch (e) {
      print(e.toString());
    }
    return {};
  }

  Future<List<dynamic>> fetchGates(int companyId) async {
    try {
      final queryParams = {'company_id': companyId};
      final response = await _dio2.get('/api/admin/gates/list',
          queryParameters: queryParams);
      print(response.data['data'].toString());
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw DioError(
            requestOptions: response.requestOptions,
            response: response,
            type: DioErrorType.response);
      }
    } catch (e) {
      print('Error fetching gates: $e');
      rethrow;
    }
  }

  Future<Visitor?> searchVisitor(String mobileNumber) async {
    try {
      final result = await client.visitor.fetchVisitor(mobileNumber);
      print("searchVisitor: ${result.toString()}");
      return result!;
    } catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<List<PurposeCategory>?> fetchPurpose() async {
    try {
      final result = await client.purposeCategory.fetchPurposeCategory();
      print("fetchPurpose: ${result.toString()}");
      return result;
    } catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<Visitor?> createVisitor(Visitor visitor) async {
    try {
      final result = await client.visitor.createVisitor(visitor);
      print("createVisitor: ${result.toString()}");
      return result;
    } catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<BuildingAssignment?> createBuildingAssignment(
      BuildingAssignment buildingAssignment) async {
    try {
      final result =
          await client.visitorLog.createBuildingAssignment(buildingAssignment);
      print("createBuildingAssignment: ${result.toString()}");
      return result;
    } catch (e) {
      print(e.toString());
    }
    return null;
  }

  Future<VisitorLog?> checkIn(VisitorLog visitorLog) async {
    try {
      final result = await client.visitorLog.createVisitorLog(visitorLog);
      for (BuildingAssignment buildingAssignment
          in visitorLog.visitor_building_assignment!) {
            buildingAssignment.visitor_log_id = result.id;
        await createBuildingAssignment(buildingAssignment);
      }
      print("checkIn: ${result.toString()}");
      return result;
    } catch (e) {
      print(e.toString());
    }
    return null;
  }


  Future<List<dynamic>> getBuilding(int companyId) async {
    try {
      final response = await _dio2.get('/api/admin/building/list',
          queryParameters: {'company_id': 412});
      return response.data['data'];
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getMemberUnit(int companyId, int buildingId) async {
    try {
      final response = await _dio2.get('/api/admin/units/list',
          queryParameters: {
            'company_id': 412,
            'building_id': buildingId,
            'per_page': 1000
          });
      return response.data['data'];
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getMember(int companyId, int unitId) async {
    try {
      final response = await _dio2.get('/api/admin/member/list',
          queryParameters: {
            'company_id': 412,
            'unit_id': unitId,
            'current_tab': 'approved'
          });
      return response.data['data'];
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
  }

  Future<List<VisitorLog>> fetchAllLogs(int companyId, String dateTime) async {
    try {
      final visitor_log =
          await client.visitorLog.fetchAllLogs(dateTime);
      return visitor_log;
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
  }

  Future<List<VisitorLog>> fetchCheckInLogs(int companyId, String dateTime) async {
    try {
      final visitor_log =
          await client.visitorLog.fetchCheckInLogs(dateTime);
      return visitor_log;
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
  }

   Future<List<VisitorLog>> fetchCheckOutLogs(int companyId, String dateTime) async {
    try {
      final visitor_log =
          await client.visitorLog.fetchCheckOutLogs(dateTime);
      return visitor_log;
    } catch (e) {
      print('Error fetching buildings: $e');
      rethrow;
    }
  }

  Future<bool> checkOut(VisitorLog visitorLog) async {
    try {
      final result = await client.visitorLog.checkOut(visitorLog);
      print("checkOut: ${result.toString()}");
      return result;
    } catch (e) {
      print(e.toString());
    }
    return false;
  }




}
