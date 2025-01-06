import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/common/apiHelper.dart';
import 'package:flutter_onegate/common/environment.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VisitorLogsProvider extends ChangeNotifier {
  bool isLoading = true;
  bool isLoadingMore = false;
  List<dynamic> visitorLogs = [];
  int currentPage = 1;
  int totalPages = 1; // Assuming the API provides total page information
  String? searchText;
GateStorage gateStorage = GateStorage();
   final String baseUrl = 'https://gateapi.cubeone.in/api/visitor/log'; // Replace with your API endpoint

  Future<void> fetchVisitorLogs({int currentPage = 1, String? searchText}) async {
    isLoading = true;
    notifyListeners();

    final int? companyId = await gateStorage.getSocietyId();
    if (companyId == null) {
      log('Error: Company ID is null');
      isLoading = false;
      notifyListeners();
      return;
    }

    final String baseUrl = 'https://gateapi.cubeone.in/api/visitor/log';
    final String url = '$baseUrl?company_id=$companyId&page=$currentPage&search=${searchText ?? ""}';

    try {
      log('Fetching visitor logs from: $url');
      final response = await http.get(Uri.parse(url), headers: {
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        log('Parsed Response: $data');

        if (data['data'] is List) {
          final List<dynamic> logs = data['data'];
          visitorLogs = currentPage == 1
              ? logs
              : [...visitorLogs, ...logs];
          log('Visitor Logs Loaded: ${visitorLogs.length} items');
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        log('API Error: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to load visitor logs. Status code: ${response.statusCode}');
      }
    } catch (e) {
      log('Error fetching visitor logs: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
  void searchVisitorLogs(String query) {
    searchText = query;
    fetchVisitorLogs();
  }
}