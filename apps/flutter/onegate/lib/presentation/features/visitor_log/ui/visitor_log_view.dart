import 'dart:convert';
import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
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

  // Future<void> fetchVisitorLogs() async {
  //   int? companyId = await gateStorage.getSocietyId();
  //
  //   if (_isFetching) return;
  //   _isFetching = true;
  //
  //   try {
  //     final response =
  //         await http.get(Uri.parse('$apiUrl$companyId'), headers: headers);
  //
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       debugPrint('API Response (status: ${response.statusCode}): $data');
  //
  //       if (data is Map &&
  //           data['data'] is Map &&
  //           data['data']['data'] is List) {
  //         setState(() {
  //           visitorLogs = data['data']['data'];
  //         });
  //       } else {
  //         throw Exception('Unexpected response format');
  //       }
  //     } else {
  //       debugPrint('Error response: ${response.statusCode}, ${response.body}');
  //       throw Exception('Failed to fetch visitor logs');
  //     }
  //   } catch (e) {
  //     debugPrint('Error: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error fetching data: ${e.toString()}')),
  //     );
  //   } finally {
  //     setState(() {
  //       isLoading = false;
  //     });
  //     _isFetching = false;
  //   }
  // }

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

  Future<void> checkout(BuildContext context, String visitorId) async {
    const String apiUrl = 'https://gateapi.cubeone.in/api/visitor/checkout';

    try {
      // Show a loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      // API request payload
      final Map<String, dynamic> payload = {
        'visitor_log_id': visitorId,
      };

      // Make the HTTP POST request
      final response = await http.patch(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      Navigator.pop(context); // Close the loading indicator

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(responseData['message'] ?? 'Checkout successful!')),
          );
          // You can refresh the visitor logs or perform other necessary actions
        } else {
          // Show error message from API
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(responseData['message'] ?? 'Failed to check out.')),
          );
        }
      } else {
        // Handle non-200 responses
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close the loading indicator

      // Handle exceptions
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error occurred: $e')),
      );
    }
  }

  // Future<void> checkout(BuildContext context, String visitorId) async {
  //   const String apiUrl = 'https://gateapi.cubeone.in/api/visitor/checkout';
  //
  //   try {
  //     // Show a loading indicator
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (BuildContext context) {
  //         return const Center(child: CircularProgressIndicator());
  //       },
  //     );
  //
  //     // API request payload
  //     final Map<String, dynamic> payload = {
  //       'visitor_id': visitorId,
  //     };
  //
  //     // Make the HTTP POST request
  //     final response = await http.post(
  //       Uri.parse(apiUrl),
  //       headers: {
  //         'Content-Type': 'application/json',
  //       },
  //       body: jsonEncode(payload),
  //     );
  //
  //     Navigator.pop(context); // Close the loading indicator
  //
  //     if (response.statusCode == 200) {
  //       final responseData = jsonDecode(response.body);
  //
  //       if (responseData['success'] == true) {
  //         // Show success message
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //               content:
  //                   Text(responseData['message'] ?? 'Checkout successful!')),
  //         );
  //
  //         // Update the UI or data if necessary
  //       } else {
  //         // Show error message from API
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //               content:
  //                   Text(responseData['message'] ?? 'Failed to check out.')),
  //         );
  //       }
  //     } else {
  //       // Handle non-200 responses
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('API Error: ${response.statusCode}')),
  //       );
  //     }
  //   } catch (e) {
  //     Navigator.pop(context); // Close the loading indicator
  //
  //     // Handle exceptions
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error occurred: $e')),
  //     );
  //   }
  // }

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
        pageBody: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomForm.textField(
              widget.selectedBuilding ?? 'Search',
              titleColor: Theme.of(context).colorScheme.onSurface,
              hintColor: Theme.of(context).colorScheme.onSurface,
              hintText: 'Search Visitor',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (value) {
                if (kDebugMode) {
                  print(value);
                }
              },
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
              prefixIcon: IconButton(
                onPressed: () {},
                icon: Icon(
                  Ionicons.search_outline,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              suffixIcon: IconButton(
                onPressed: () {},
                icon: Icon(
                  Ionicons.funnel_outline,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 24,
                ),
              ),
            ),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : visitorLogs.isEmpty
                    ? const Center(child: Text('No visitor logs available'))
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: visitorLogs.length,
                        itemBuilder: (context, index) {
                          final log = visitorLogs[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8),
                                      leading: CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage: NetworkImage(
                                          log['visitor_image'] ??
                                              'https://via.placeholder.com/150',
                                        ),
                                      ),
                                      title: RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: log['name'] ?? 'Unknown',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold),
                                            ),
                                            if (log['visitor_type'] != null)
                                              TextSpan(
                                                text:
                                                    ' (${log['visitor_type']})',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                        color: Colors
                                                            .grey.shade600),
                                              ),
                                          ],
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 5),
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              const WidgetSpan(
                                                child: Icon(
                                                  Symbols.apartment,
                                                  color: Color(0xffFFB080),
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    ' ${log['unit_name'] ?? 'N/A'}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                        color: Colors.grey),
                                              ),
                                              WidgetSpan(
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                      left: 8),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xffFFEBE6),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Text(
                                                    '${log['purpose_category_name'] ?? 'N/A'}',
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      trailing: IconButton(
                                        onPressed: () {},
                                        icon: const Icon(
                                          Ionicons.call_outline,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                    Divider(
                                      indent: 16,
                                      endIndent: 16,
                                      color: Colors.grey[200],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.only(
                                          bottom: 14.0, top: 8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Tooltip(
                                            message: log['visitor_check_in'] !=
                                                    null
                                                ? DateFormat('MMM dd, yyyy')
                                                    .format(
                                                    DateTime.parse(log[
                                                        'visitor_check_in']),
                                                  )
                                                : 'No check-in date available',
                                            child: RichText(
                                              text: TextSpan(
                                                children: [
                                                  const WidgetSpan(
                                                    child: Icon(
                                                      Symbols
                                                          .directions_walk_rounded,
                                                      color: Colors.green,
                                                      size:
                                                          16, // Adjust size for alignment
                                                    ),
                                                  ),
                                                  const WidgetSpan(
                                                      child:
                                                          SizedBox(width: 4)),
                                                  // Add spacing
                                                  TextSpan(
                                                    text:
                                                        log['visitor_check_in'] !=
                                                                null
                                                            ? DateFormat(
                                                                    'hh:mm a')
                                                                .format(
                                                                DateTime.parse(log[
                                                                    'visitor_check_in']),
                                                              )
                                                            : 'N/A',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelMedium
                                                        ?.copyWith(
                                                          color: Colors.green,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          (log['visitor_card_number'] !=
                                                      null &&
                                                  log['visitor_card_number']
                                                      .isNotEmpty)
                                              ? Container(
                                                  margin: const EdgeInsets.only(
                                                      left: 8),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    vertical: 2,
                                                    horizontal: 10,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                      colors: [
                                                        Color.fromRGBO(
                                                            255, 236, 158, 0.8),
                                                        Color.fromRGBO(
                                                            255, 190, 168, 0.8),
                                                      ],
                                                      begin: Alignment.topRight,
                                                      end: Alignment.bottomLeft,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                      color:
                                                          const Color.fromRGBO(
                                                              255, 190, 168, 1),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Lottie.asset(
                                                        'assets/json/idcard.json',
                                                        width: 30,
                                                        height: 30,
                                                        fit: BoxFit.cover,
                                                      ),
                                                      const SizedBox(
                                                        width: 5,
                                                      ),
                                                      Text(
                                                        '${log['visitor_card_number']}' ??
                                                            'N/A',
                                                        style: const TextStyle(
                                                          color: Colors.black,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : const SizedBox(),
                                          (log['visitor_check_out']
                                                      .toString()
                                                      .isEmpty ||
                                                  log['visitor_check_out']
                                                          .toString() ==
                                                      'null')
                                              ? ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    if (visitorLogs
                                                        .isNotEmpty) {
                                                      // Get the visitor log ID from the first log (or modify to suit your logic)
                                                      String visitorId = visitorLogs[
                                                                  index]
                                                              ['visitor_log_id']
                                                          .toString(); // Assuming the ID is in 'visitor_log_id'

                                                      // Pass visitorId to the checkout function
                                                      checkout(
                                                          context, visitorId);
                                                    } else {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                            content: Text(
                                                                'No visitor logs available')),
                                                      );
                                                    }
                                                  },
                                                  // checkout(context,
                                                  //     log['visitor_id']);

                                                  child: Text(
                                                    'CheckOut',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall!
                                                        .merge(
                                                          const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 14),
                                                        ),
                                                  ),
                                                )
                                              : Tooltip(
                                                  message: log[
                                                              'visitor_check_out'] !=
                                                          null
                                                      ? DateFormat(
                                                              'MMM dd, yyyy')
                                                          .format(
                                                          DateTime.parse(log[
                                                              'visitor_check_out']),
                                                        )
                                                      : 'No check-in date available',
                                                  child: RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        const WidgetSpan(
                                                          child: Icon(
                                                            Symbols
                                                                .directions_walk_rounded,
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text: log['visitor_check_out'] !=
                                                                  null
                                                              ? DateFormat(
                                                                      'hh:mm a')
                                                                  .format(
                                                                  DateTime.parse(
                                                                      log['visitor_check_out']),
                                                                )
                                                              : 'N/A',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .labelMedium!
                                                                  .merge(
                                                                    const TextStyle(
                                                                      color: Colors
                                                                          .red,
                                                                    ),
                                                                  ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ],
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
