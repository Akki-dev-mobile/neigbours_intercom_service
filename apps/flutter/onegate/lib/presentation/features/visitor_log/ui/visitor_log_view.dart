import 'dart:convert';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../data/datasources/gate_storage.dart';
import '../../dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';

class VisitorLogView extends StatefulWidget {
  final String id;
  final List<String> logList;
  final String? selectedBuilding;

  VisitorLogView({
    required this.id,
    required this.logList,
    this.selectedBuilding,
    Key? key,
  }) : super(key: key);

  @override
  State<VisitorLogView> createState() => _VisitorLogViewState();
}

class _VisitorLogViewState extends State<VisitorLogView> {
  static const String apiUrl =
      'https://gateapi.cubeone.in/api/visitor/log?company_id=';
  static const Map<String, String> headers = {
    'Content-Type': 'application/json'
  };
  GateStorage gateStorage = GateStorage();
  late String selectedId;
  String? _searchText = "";
  List<dynamic> visitorLogs = [];
  bool isLoading = true;
  bool _isFetching = false; // Flag to prevent multiple fetches

  @override
  void initState() {
    super.initState();
    fetchVisitorLogs();
  }

  Future<void> fetchVisitorLogs() async {
    String companyId = gateStorage.getSocietyId().toString();

    if (_isFetching) return;
    _isFetching = true;

    try {
      final response =
          await http.get(Uri.parse(apiUrl + companyId), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('API Response (status: ${response.statusCode}): $data');

        if (data is Map &&
            data['data'] is Map &&
            data['data']['data'] is List) {
          setState(() {
            visitorLogs = data['data']['data'];
          });
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        debugPrint('Error response: ${response.statusCode}, ${response.body}');
        throw Exception('Failed to fetch visitor logs');
      }
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
      _isFetching = false;
    }
  }

  Future<bool> _onWillPop() async {
    if (isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, data is still loading.')),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // _onWillPop,
      child: MyScrollView(
        // isScrollable: false,
        pageTitle: 'Visitor Logs',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GateDashboardView(),
                  ),
                );
              },
              icon: const Icon(
                Icons.home,
              ),
            ),
          ),
        ],
        pageBody: isLoading
            ? const Center(child: CircularProgressIndicator())
            : visitorLogs.isEmpty
                ? const Center(child: Text('No visitor logs available'))
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: visitorLogs.length,
                    itemBuilder: (context, index) {
                      final log = visitorLogs[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child:
                              Text(log['name'] != null ? log['name'][0] : '?'),
                        ),
                        title: Text(log['name'] ?? 'Unknown'),
                        subtitle: Text(
                            'Check-in: ${log['visitor_check_in'] ?? 'N/A'}'),
                      );
                    },
                  ),
      ),
    );
  }
}
