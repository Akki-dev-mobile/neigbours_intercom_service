import 'dart:convert';
import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../data/datasources/gate_storage.dart';
import '../../../../data/datasources/remote_datasource.dart';
import '../../../../dio_setup.dart';
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
  final remoteDataSource = RemoteDataSource(
      DioSingleton.instance1, DioSingleton.instance2, DioSingleton.instance3);

  late String selectedId;
  String? _searchText = "";
  List<dynamic> visitorLogs = [];
  bool isLoading = true;
  bool _isFetching = false; // Flag to prevent multiple fetches

  @override
  void initState() {
    log("page id is ${widget.id}");
    super.initState();
    fetchVisitorLogs();
  }

  Future<void> fetchVisitorLogs() async {
    int? companyId = await gateStorage.getSocietyId();

    if (_isFetching) return;
    _isFetching = true;

    try {
      final response =
          await http.get(Uri.parse('$apiUrl$companyId'), headers: headers);

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

  final dateFormat = DateFormat("yyyy-MM-ddTHH:mm:ss.SSSSSSZ");

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // _onWillPop,
      child: MyScrollView(
        hasBackButton: false,
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
          (widget.id == "In Out Book")
              ? Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: IconButton(
                    onPressed: () async {
                      await _showExportBottomSheet(context);
                    },
                    icon: const Icon(
                      Icons.download,
                    ),
                  ),
                )
              : const SizedBox(),
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

  Future<void> _showExportBottomSheet(BuildContext context) async {
    TextEditingController emailController = TextEditingController();
    TextEditingController nameController = TextEditingController();
    TextEditingController dateController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString('email') ?? '';
    emailController.text = storedEmail;

    final exportFormKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 30,
              ),
              child: Form(
                key: exportFormKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Export Logs',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    CustomForm.textField(
                      "Email",
                      titleColor: Theme.of(context).colorScheme.onSurface,
                      hintColor: Theme.of(context).colorScheme.onPrimary,
                      hintText: "Enter email for export",
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                      textController: emailController,
                    ),
                    CustomForm.textField(
                      "Date Range",
                      titleColor: Theme.of(context).colorScheme.onSurface,
                      hintColor: Theme.of(context).colorScheme.onPrimary,
                      textController: dateController,
                      hintText: "Select date range",
                      isReadOnly: true,
                      suffixIcon: IconButton(
                        onPressed: () async {
                          final DateTimeRange? picked =
                              await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                            initialDateRange:
                                startDate != null && endDate != null
                                    ? DateTimeRange(
                                        start: startDate!, end: endDate!)
                                    : null,
                            builder: (BuildContext context, Widget? child) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      MediaQuery.of(context).size.height * 0.2,
                                      16,
                                      0,
                                    ),
                                  ),
                                  Container(
                                    height: MediaQuery.of(context).size.height *
                                        0.7,
                                    width:
                                        MediaQuery.of(context).size.width * 0.9,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Theme(
                                      data: ThemeData(
                                        datePickerTheme: DatePickerThemeData(
                                          rangeSelectionBackgroundColor:
                                              Colors.red.shade200,
                                          dayBackgroundColor:
                                              WidgetStateProperty.all(
                                            Colors.red.shade200,
                                          ),
                                        ),
                                        useMaterial3: true,
                                      ),
                                      child: child!,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );

                          if (picked != null) {
                            setState(() {
                              startDate = picked.start;
                              endDate = picked.end;
                              dateController.text =
                                  '${DateFormat('MMM dd, yyyy').format(startDate!)} - ${DateFormat('MMM dd, yyyy').format(endDate!)}';
                            });
                          }
                        },
                        icon: const Icon(Symbols.calendar_today),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Please select date range';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomLargeBtn(
                          onPressed: () async {
                            if (exportFormKey.currentState!.validate() &&
                                startDate != null &&
                                endDate != null) {
                              await prefs.setString(
                                  'email', emailController.text);

                              final formattedFromDate =
                                  DateFormat('yyyy-MM-dd').format(startDate!);
                              final formattedToDate =
                                  DateFormat('yyyy-MM-dd').format(endDate!);

                              var visitorData = visitorLogs.map((visitor) {
                                return {
                                  "name": nameController.text,
                                  "to_mail": emailController.text,
                                  "from_date": formattedFromDate,
                                  "to_date": formattedToDate,
                                };
                              }).toList();

                              await remoteDataSource.exportLogs(visitorData);
                              Navigator.of(context).pop();
                            } else {
                              Fluttertoast.showToast(
                                msg: "Please fill all fields",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.CENTER,
                                timeInSecForIosWeb: 1,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                fontSize: 16.0,
                              );
                            }
                          },
                          text: "Export",
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
