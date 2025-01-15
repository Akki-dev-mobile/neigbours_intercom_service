import 'dart:convert';

import 'package:http/http.dart' as http;

class OneGate {
  static const String baseUrl = 'https://socbackend.cubeone.in/api/admin';
  static const String companyId = '412';

  Future<void> getUnitsList() async {
    final url = Uri.parse('$baseUrl/units/list?company_id=$companyId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      // Process the JSON response
      final data = json.decode(response.body);
      print("Units List: $data");
    } else {
      print("Failed to load units list");
    }
  }

  Future<void> getBuildingsList() async {
    final url = Uri.parse('$baseUrl/building/list?company_id=$companyId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      // Process the JSON response
      final data = json.decode(response.body);
      print("Buildings List: $data");
    } else {
      print("Failed to load buildings list");
    }
  }

  Future<void> getMembersList() async {
    final url = Uri.parse('$baseUrl/member/list?company_id=$companyId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      // Process the JSON response
      final data = json.decode(response.body);
      print("Members List: $data");
    } else {
      print("Failed to load members list");
    }
  }
}
