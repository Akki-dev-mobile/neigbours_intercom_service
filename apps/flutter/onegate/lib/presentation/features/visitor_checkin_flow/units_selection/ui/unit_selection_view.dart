import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart';
// import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:onegate_client/onegate_client.dart' as c;
import 'package:shared_preferences/shared_preferences.dart';

class UnitSelectionView extends StatefulWidget {
  final c.Visitor visitor;
  final c.PurposeCategory purposeCategory;
  final String? comingFrom;
  final int? guestCount;
  final int? visitorId;
  final int? companyId;
  final String guestname;
  final String mobileNumber;

  const UnitSelectionView(
      {Key? key,
      required this.visitor,
      required this.purposeCategory,
      this.comingFrom,
      this.guestCount,
      this.companyId,
      this.visitorId,
      required this.guestname,
      required this.mobileNumber})
      : super(key: key);

  @override
  State<UnitSelectionView> createState() => _UnitSelectionViewState();
}

class _UnitSelectionViewState extends State<UnitSelectionView> {
  final Dio _dio = Dio();
  int? selectedUnit;
  int? selectedMember;
  final PreferenceUtils preferenceUtils = GetIt.I<PreferenceUtils>();
  final GateStorage gateStorage = GateStorage();
  File? image;
  Set<int> selectedMembers = {};
  Set<int> selectedUnits = {};
  String selectedBuilding = '';
  List<dynamic> buildings = [];
  List<dynamic> units = [];

  // late Client amqpClient;
  String? approvalStatus =
      "Waiting for approval..."; // Holds approval/decline message
  bool isWaitingForApproval = false; // Shows waiting state
  bool isLoading = true;
  bool isUnitsLoading = false;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredMembers = [];
  List<dynamic> _allMembers = [];
  final ValueNotifier<List<dynamic>> _filteredMembersNotifier =
      ValueNotifier([]);
  final ValueNotifier<Set<String>> _selectedMembersNotifier = ValueNotifier({});
  final ValueNotifier<Set<int>> _selectedUnitsNotifier = ValueNotifier({});
  int? companyId;
  final remoteDataSource = RemoteDataSource(
      DioSingleton.instance1, DioSingleton.instance2, DioSingleton.instance3);

  @override
  void initState() {
    super.initState();
    // fetchBuildings();
    _searchController.addListener(_filterMembers);

    // setupAMQPReceiver(); // Initialize AMQP receiver
    print("widget.mobileNumber${widget.mobileNumber}");
    _fetchCompanyId();
    print("widget.visitorId${widget.visitorId}");
  }

  Future<void> _initializeMembers() async {
    final members = await getMember();
    _allMembers = members;
    _filteredMembersNotifier.value = members;
  }

  Future<void> _fetchCompanyId() async {
    companyId = await gateStorage.getSocietyId();
    setState(() {});
  }

  void _filterMembers() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.length >= 3) {
      _filteredMembersNotifier.value = _allMembers.where((member) {
        final memberName =
            member['member_name']?.toLowerCase().contains(query) ?? false;
        final unitNumber =
            member['unit_flat_number']?.toLowerCase().contains(query) ?? false;

        final unitID =
            member['fk_unit_id']?.toString().toLowerCase().contains(query) ??
                false;
        print("unitID:::$unitID");

        return memberName || unitNumber;
      }).toList();
    } else {
      _filteredMembersNotifier.value = _allMembers;
    }
  }

  @override
  void dispose() {
    // amqpClient.close();
    _filteredMembersNotifier.dispose();
    _selectedMembersNotifier.dispose();

    super.dispose();
  }

  // Future<void> setupAMQPReceiver() async {
  //   try {
  //     log("Initializing AMQP Receiver...");
  //
  //     // Initialize AMQP client with connection settings
  //     amqpClient = Client(
  //       settings: ConnectionSettings(
  //         host: "65.1.230.119",
  //         authProvider:
  //             const PlainAuthenticator("dinesh.koli", "7nqRG&I!FesI&7zCrii0"),
  //       ),
  //     );
  //
  //     log("Connecting to RabbitMQ server...");
  //     await amqpClient.connect();
  //     log("Connection to RabbitMQ server established successfully.");
  //
  //     // Define the queue name dynamically based on the mobile number
  //     final queueName = "visitor_approval_77525_${widget.mobileNumber}";
  //     log("Queue Name: $queueName");
  //
  //     // Access the channel and declare the queue
  //     Channel channel = await amqpClient.channel();
  //     log("Channel opened.");
  //
  //     Queue queue = await channel.queue(queueName, durable: false);
  //     log("Queue declared: $queueName");
  //
  //     // Bind the queue to an exchange (if required)
  //     // Note: Replace "exchange_name" and "routing_key" with actual values if applicable
  //     const String exchangeName = "logs"; // Example exchange name
  //     final Exchange exchange = await channel.exchange(
  //       exchangeName,
  //       ExchangeType.FANOUT,
  //       durable: false,
  //     );
  //     log("Exchange bound: $exchangeName");
  //
  //     await queue.bind(exchange, "routing_key_placeholder");
  //     log("Queue bound to exchange with routing key.");
  //
  //     // Start consuming messages from the queue
  //     Consumer consumer = await queue.consume();
  //
  //     log("Consumer registered for queue. Waiting for messages...");
  //
  //     // Listen for messages on the queue
  //     consumer.listen((AmqpMessage message) {
  //       log("Message received from queue.");
  //
  //       try {
  //         // Decode the message payload
  //         final payload = utf8.decode(message.payload as List<int>);
  //         log("Raw Message Payload: $payload");
  //
  //         // Parse the message as JSON
  //         final response = jsonDecode(payload);
  //         log("Decoded Message: $response");
  //
  //         // Extract the approval status from the message
  //         final status = response['status'];
  //         log("Approval Status: $status");
  //
  //         showApprovalDialog(status);
  //
  //         // Update the dialog dynamically
  //         // setState(() {
  //         //   approvalStatus = status;
  //         // });
  //
  //         // Acknowledge the message
  //         message.ack();
  //       } catch (e) {
  //         log("Error processing message: $e");
  //       }
  //     });
  //   } catch (e) {
  //     log("Error setting up AMQP Receiver: $e");
  //   }
  // }

  Future<void> showApprovalDialog(approvalStatusNew) async {
    // Ensure `approvalStatus` starts with "Waiting for approval..."
    // setState(() {
    //   approvalStatus = "Waiting for approval...";
    // });

    // await setupAMQPReceiver();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing the dialog
      builder: (_) {
        return AlertDialog(
          title: const Text("Approval Status"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (approvalStatus == "Waiting for approval...")
                    const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    approvalStatusNew,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
          actions: [
            if (approvalStatus == "Approved" || approvalStatus == "Rejected")
              TextButton(
                onPressed: () {
                  // Clear `approvalStatus` and close the dialog
                  setState(() {
                    approvalStatus = null;
                  });
                  Navigator.pop(context);
                },
                child: const Text("Close"),
              ),
          ],
        );
      },
    ).then((_) {
      // Ensure `approvalStatus` is cleared if the dialog is dismissed in other ways
      setState(() {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const GateDashboardView()));
      });
    });
  }

  // Future<void> fetchBuildings() async {
  //   try {
  //     setState(() => isLoading = true);
  //
  //     final response = await _dio.get(
  //       'https://societybackend.cubeone.in/api/admin/building/list?company_id=$companyId',
  //     );
  //     setState(() {
  //       print("Company IDDDDDD");
  //       buildings = response.data['data'];
  //       // print("Company IDDDDDD$buildings");
  //       if (buildings.isNotEmpty) {
  //         selectedBuilding = buildings[0]['soc_building_name'];
  //         fetchUnits(buildings[0]['id']);
  //       }
  //     });
  //   } catch (e) {
  //     print('Error fetching buildings: $e');
  //     setState(() => isLoading = false);
  //   }
  // }

  Future<void> fetchUnits(int buildingId) async {
    try {
      setState(() => isUnitsLoading = true);

      final response = await _dio.get(
        'https://societybackend.cubeone.in/api/admin/units/list',
        queryParameters: {
          'company_id': companyId,
          'building_id': buildingId,
          'per_page': 1000,
        },
      );
      setState(() {
        units = response.data['data'];
        isUnitsLoading = false;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching units: $e');
      setState(() => isUnitsLoading = false);
    }
  }

  Future<List<dynamic>> getMember() async {
    try {
      final response = await _dio.get(
          'https://societybackend.cubeone.in/api/admin/member/list',
          queryParameters: {
            'company_id': companyId.toString(),
            'unit_id': null,
            'current_tab': 'approved'
          });
      // log("soc units list:::$response");
      return response.data['data'];
    } catch (e) {
      print('Error fetching members: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      isScrollable: false,
      pageTitle: 'Select Units/Members',
      pageBody: FutureBuilder<void>(
        future: _initializeMembers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16), // Add spacing
                  Text(
                    "Loading Units and Members...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          } else {
            return SizedBox(
              height: MediaQuery.of(context).size.height,
              child: Column(
                children: [
                  _buildSearchField(context),
                  Expanded(child: _buildMemberList(context)),
                ],
              ),
            );
          }
        },
      ),
      floatingActionButton: ValueListenableBuilder<Set<String>>(
          valueListenable: _selectedMembersNotifier,
          builder: (context, selectedMember, child) {
            return (selectedMembers.isNotEmpty || selectedMember.isNotEmpty)
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 20,
                    ),
                    color: Theme.of(context).colorScheme.onSurface,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          selectedMember.length > 1
                              ? "${selectedMember.first} +${selectedMember.length - 1}"
                              : selectedMember.first,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.surface,
                              ),
                        ),
                        ElevatedButton.icon(
                          style: ButtonStyle(
                            // overlayColor: MaterialStateProperty.all<Color>(
                            //   Color(0xFF61677A),
                            // ),
                            foregroundColor: WidgetStateProperty.all<Color>(
                              const Color(0xFF7D7C7C),
                            ),
                            backgroundColor: WidgetStateProperty.all<Color>(
                              Theme.of(context).colorScheme.surface,
                            ),
                            elevation: WidgetStateProperty.resolveWith<double>(
                              (Set<WidgetState> states) {
                                if (states.contains(WidgetState.pressed)) {
                                  return 8;
                                }
                                return 0;
                              },
                            ),
                            shape:
                                WidgetStateProperty.all<RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            padding:
                                WidgetStateProperty.all<EdgeInsetsGeometry>(
                              const EdgeInsets.symmetric(
                                horizontal: 36,
                                vertical: 16,
                              ),
                            ),
                          ),
                          onPressed: () async {
                            log("FloatingActionButtonunitId Selected Member: $selectedMembers, Selected Unit: $selectedUnit");

                            if (selectedUnits != null ||
                                selectedMember != null) {
                              log("Selected Unit: $selectedUnits");
                              log("Selected Member: $selectedMember");

                              String? userId;
                              if (selectedUnits.isNotEmpty) {
                                userId = selectedUnits.first.toString();
                              } else if (selectedMembers.isNotEmpty) {
                                userId = _allMembers
                                    .firstWhere(
                                      (member) => selectedMembers.contains(
                                        member['member_name'],
                                      ),
                                    )['id']
                                    .toString();
                              }

                              List<int> memberIds = _allMembers
                                  .where((member) => selectedMembers
                                      .contains(member['member_name']))
                                  .map<int>(
                                      (member) => member['member_id'] as int)
                                  .toList();

                              log("Member IDs List: $memberIds");

                              log("Post Selection:::");
                              await postSelection(
                                  context, selectedMember, selectedUnits);

                              // preferenceUtils.getTooglevalue() == true
                              //     ? showApprovalDialog('Waiting for approval......')
                              //     : await postSelection(
                              //         context, selectedMember, unitId);
                            } else {
                              log("No selection made");
                            }
                          },
                          label: Text(
                            (selectedMember.length > 1) ? "Allow" : "Next",
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          icon: Icon(
                            Icons.navigate_before,
                            size: 32,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox();
          }),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return CustomForm.textField(
      'Search Members',
      titleColor: Theme.of(context).colorScheme.onSurface,
      hintColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
      hintText: 'Search Members',
      textController: _searchController,
      onChanged: (_) {
        _searchController.text.trim().length >= 3
            ? _filterMembers()
            : _filteredMembersNotifier.value = _allMembers;
      },
      suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
              icon: Icon(
                Ionicons.close,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                _searchController.clear();
                _filteredMembersNotifier.value = _allMembers;
              },
            )
          : null,
    );
  }

// Define a global variable to store user IDs
  Set<String> selectedUserIds = {};

// Global variables
  List<int> selectedMemberIds = []; // To store selected member IDs
  List<String> selectedBuildingUnits =
      []; // To store selected building-unit combinations

  Widget _buildMemberList(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _selectedMembersNotifier,
      builder: (context, selectedMembers, child) {
        return ValueListenableBuilder<List<dynamic>>(
          valueListenable: _filteredMembersNotifier,
          builder: (context, filteredMembers, child) {
            if (filteredMembers.isEmpty) {
              // Display a message when no members are found
              return Center(
                child: Text(
                  'No Members Found.\nSearch members by their name or flat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index];
                print("shubham $member");

                final unitId = member['fk_unit_id'] ?? 'N/A';
                final memberId = member["member_id"];
                final buildingUnit = member["building_unit"] ?? 'N/A';

                final memberDetails =
                    member['member_details'] as List<dynamic>? ?? [];
                final firstMemberName = memberDetails.isNotEmpty
                    ? memberDetails.first['member_first_name'] ?? 'N/A'
                    : 'N/A';
                final additionalMembersCount = memberDetails.length > 1
                    ? '+${memberDetails.length - 1}'
                    : '';

                final isSelected =
                    selectedMembers.contains(member['unit_flat_number']);

                return Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor:
                        Theme.of(context).colorScheme.onSurface.withAlpha(20),
                  ),
                  child: ExpansionTile(
                    iconColor: Colors.redAccent,
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    leading: Icon(
                      Symbols.location_away,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 32,
                    ),
                    title: Text(
                      member['unit_flat_number'] ?? 'N/A',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    subtitle: Text(
                      '$firstMemberName $additionalMembersCount',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w300,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                    collapsedIconColor: Theme.of(context).colorScheme.onSurface,
                    children: [
                      ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: memberDetails.length,
                        separatorBuilder: (context, index) => Divider(
                          color: Theme.of(context).dividerColor,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final detail = memberDetails[index];
                          final firstName =
                              detail['member_first_name'] ?? 'N/A';
                          final lastName =
                              detail['member_last_name']?.toString() ?? 'N/A';
                          final userId = detail['user_id']?.toString() ?? 'N/A';

                          return ListTile(
                            contentPadding: const EdgeInsets.only(
                              top: 3,
                              bottom: 10,
                            ),
                            title: Text(
                              '$firstName $lastName',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            onTap: () async {
                              final updatedMembers =
                                  Set<String>.from(selectedMembers);
                              if (selectedMembers.contains(firstName)) {
                                updatedMembers.remove(firstName);
                                selectedUserIds.remove(userId);
                                selectedMemberIds.remove(memberId);
                                selectedBuildingUnits.remove(buildingUnit);
                              } else {
                                updatedMembers.add(firstName);
                                selectedUserIds.add(userId);
                                final cleanedMemberIds = memberId
                                    .toString()
                                    .split(
                                        ',') // Split by commas into a list of strings
                                    .map((id) => id
                                        .trim()) // Remove extra spaces from each part
                                    .where((id) => id
                                        .isNotEmpty) // Filter out any empty strings
                                    .toList();

                                for (final id in cleanedMemberIds) {
                                  try {
                                    selectedMemberIds.add(int.parse(
                                        id)); // Safely parse each ID to int
                                  } catch (e) {
                                    print("Error parsing ID: $id, Error: $e");
                                  }
                                }

                                print("Cleaned Member IDs: $selectedMemberIds");
                                selectedBuildingUnits.add(buildingUnit);
                              }
                              _selectedMembersNotifier.value = updatedMembers;
                              final updateUnits = Set<int>.from(selectedUnits);
                              if (selectedUnits.contains(unitId)) {
                                updateUnits.remove(unitId);
                              } else {
                                selectedUnits.add(unitId);
                              }
                              _selectedUnitsNotifier.value = updateUnits;
                              // Debugging logs
                              log("Selected User IDs: $selectedUserIds");
                              log("Selected Member IDs: $selectedMemberIds");
                              log("Selected Building Units: $selectedBuildingUnits");
                            },
                            trailing: Icon(
                              selectedMembers.contains(firstName)
                                  ? Ionicons.checkmark_circle
                                  : Icons.add_circle_outline,
                              color: selectedMembers.contains(firstName)
                                  ? Colors.green
                                  : null,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

// Global or Class-level Map to store details
  Map<String, dynamic> savedMemberUnitDetails = {};

  Future<void> saveMemberAndUnitToPrefs(
      Set<String> memberDetails, Set<int?> unitIDs) async {
    // Debug: Print the sets
    print("Member Details Set: $memberDetails");
    print("Unit IDs Set: $unitIDs");
    print("Building Units: $selectedBuildingUnits");

    // Convert sets to lists for storage
    final List<String> memberList = memberDetails.toList();
    final List<int> unitList = unitIDs.whereType<int>().toList();
    final List<String> buildingUnitList = selectedBuildingUnits.toList();

    // Store the data in the Map
    savedMemberUnitDetails['member_details'] = memberList;
    savedMemberUnitDetails['unit_ids'] = unitList;
    savedMemberUnitDetails['member_ids'] = selectedMemberIds.toList();
    savedMemberUnitDetails['building_unit'] = buildingUnitList;

    // Debugging: Print saved data
    print(
        "Saved Member Details: ${jsonEncode(savedMemberUnitDetails['member_details'])}");
    print("Saved Unit IDs: ${jsonEncode(savedMemberUnitDetails['unit_ids'])}");
    print(
        "Saved Member IDs: ${jsonEncode(savedMemberUnitDetails['member_ids'])}");
    print(
        "Saved Building Units: ${jsonEncode(savedMemberUnitDetails['building_unit'])}");

    await remoteDataSource.visitorLogDetails([savedMemberUnitDetails]);

    Fluttertoast.showToast(
      msg: "Member and Unit details saved successfully.",
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  Future<void> postSelection(BuildContext context, Set<String> selectedMembers,
      Set<int> selectedUnits) async {
    print("Request Data Posting selection...");
    print(
        "postSelection:: selectedUnits:::$selectedUnits, selectedMembers:::$selectedMembers");

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? visitorId = prefs.getString('visitorId');
    await saveMemberAndUnitToPrefs(selectedMembers, selectedUnits);
    if (selectedMembers.length != 1) {
      print("Request skipped: Exactly one user ID must be selected.");
      print("Returning success as no posting is required.");

      final c.VisitorLog data = c.VisitorLog(
        visitor_id: widget.visitorId ?? int.parse(visitorId!),
        visitor_purpose_category_id: 1,
        visitor_purpose_sub_category_id: null,
        visitor_count: 1, // Example count
        visitor_check_in: DateTime.now(),
        visitor_check_out: null,
        visitor_card_number: null,
        visitor_coming_from: "Unknown",
        visitor_card_id: null,
        company_id: companyId!,
        is_checked_out: false,
      );

      await _showApprovedDialog(context, data);
      return;
    }

    if (selectedUnits.length != 1) {
      final c.VisitorLog data = c.VisitorLog(
        visitor_id: widget.visitorId ?? int.parse(visitorId!),
        visitor_purpose_category_id: 1,
        visitor_purpose_sub_category_id: null,
        visitor_count: 1, // Example count
        visitor_check_in: DateTime.now(),
        visitor_check_out: null,
        visitor_card_number: null,
        visitor_coming_from: "Unknown",
        visitor_card_id: null,
        company_id: companyId!,
        is_checked_out: false,
      );

      print("Request skipped: Exactly one unit must be selected.");
      print("Returning success as no posting is required.");
      _showApprovedDialog(context, data);
      return;
    }

    final String userId = selectedMembers.first;
    final String formattedInTime =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final int unitId = selectedUnits.first;

    final String selectedMemberName = selectedMembers.first;
    final int selectedUnitId = selectedUnits.first;

    // Fetch the member details from _allMembers
    final selectedMemberDetails = _allMembers.firstWhere(
      (member) =>
          member['member_name'] == selectedMemberName &&
          member['fk_unit_id'] == selectedUnitId,
      orElse: () => {},
    );
    print(selectedMemberDetails);
    final String memberName = selectedMemberDetails['member_name'] ?? 'Unknown';
    final String unitFlatNumber =
        selectedMemberDetails['unit_flat_number'] ?? 'N/A';

    print(
        "Saving Member Details: member_name: $memberName, unit_id: $unitId, unit_flat_number: $unitFlatNumber");

    // Save Selected Member Details to gateStorage
    try {
      await gateStorage.saveMemberDetails({
        'member_name': memberName,
        'unit_id': unitId,
        'unit_flat_number': unitFlatNumber,
      });
      print("Saved to storage: Member - $memberName, Unit - $unitId");
    } catch (e) {
      print("Error saving member details: $e");
      Fluttertoast.showToast(
        msg: "Error saving member details.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    // Prepare the request data
    final data = {
      'company_id': companyId,
      'name': widget.guestname,
      'mobile': widget.mobileNumber,
      'purpose': "meeting",
      'in_time': formattedInTime,
      'user_id': userId,
      'visitor_count': widget.guestCount?.toString() ?? "1",
      'purpose_details': "zomato",
      'coming_from': widget.comingFrom ?? "Unknown",
    };

    try {
      // Send the request
      final response = await Dio().post(
        'https://gateapi.cubeone.in/api/visitor/sendFcmNotification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: data,
      );

      if (response.statusCode == 200) {
        print("FCM notification sent successfully: ${response.data}");

        setState(() {
          isWaitingForApproval = true;
        });

        await showApprovalDialog(true);

        // Clear visitorId from SharedPreferences
        // await prefs.remove('visitorId');
        print("Visitor ID cleared from SharedPreferences.");
      } else {
        print("Unhandled response status code: ${response.statusCode}");
      }
    } on DioError catch (e) {
      if (e.response?.statusCode == 400) {
        Fluttertoast.showToast(
          msg: "Not a OneApp user",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 2,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        final c.VisitorLog data = c.VisitorLog(
          visitor_id: widget.visitorId ?? int.parse(visitorId!),
          visitor_purpose_category_id: 1,
          visitor_purpose_sub_category_id: null,
          visitor_count: 1,
          visitor_check_in: DateTime.now(),
          visitor_check_out: null,
          visitor_card_number: null,
          visitor_coming_from: "Unknown",
          visitor_card_id: null,
          company_id: companyId!,
          is_checked_out: false,
        );

        await _showApprovedDialog(context, data);
      } else {
        log("Error during posting or sending notification: ${e.response?.statusCode} - ${e.response?.data}");
        Fluttertoast.showToast(
          msg:
              "An unexpected error occurred: ${e.response?.statusCode ?? 'Unknown error'}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 2,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      log("Unexpected error during posting or sending notification: $e");
      Fluttertoast.showToast(
        msg: "An unexpected error occurred. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 2,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _showApprovedDialog(
      BuildContext context, c.VisitorLog data) async {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissal by tapping outside
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/json/approved.json',
                  width: 150,
                  height: 150,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                Text(
                  "Approved!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                CustomLargeBtn(
                    onPressed: () async {
                      // Navigator.pop(dialogContext);

                      await remoteDataSource.checkIn(data);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const GateDashboardView()),
                      );
                    },
                    text: "Continue")
              ],
            ),
          ),
        );
      },
    );
  }
}
