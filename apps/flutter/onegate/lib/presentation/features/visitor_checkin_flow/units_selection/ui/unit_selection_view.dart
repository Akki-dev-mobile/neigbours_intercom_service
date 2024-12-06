import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:dart_amqp/dart_amqp.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
// import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:onegate_client/onegate_client.dart' as c;

class UnitSelectionView extends StatefulWidget {
  final c.Visitor visitor;
  final c.PurposeCategory purposeCategory;
  final String? comingFrom;
  final int? guestCount;
  final int? visitorId;

  final String guestname;
  final String mobileNumber;

  const UnitSelectionView(
      {Key? key,
      required this.visitor,
      required this.purposeCategory,
      this.comingFrom,
      this.guestCount,
      this.visitorId,
      required this.guestname,
      required this.mobileNumber})
      : super(key: key);

  @override
  State<UnitSelectionView> createState() => _UnitSelectionViewState();
}

class _UnitSelectionViewState extends State<UnitSelectionView> {
  final Dio _dio = Dio();
  String? selectedUnit;
  String? selectedMember;
  File? image;
  Set<String> selectedMembers = {};
  String selectedBuilding = '';
  List<dynamic> buildings = [];
  List<dynamic> units = [];
  late Client amqpClient;
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

  @override
  void initState() {
    super.initState();
    fetchBuildings();
    _searchController.addListener(_filterMembers);

    // setupAMQPReceiver(); // Initialize AMQP receiver
    print("rohit${widget.mobileNumber}");
  }

  Future<void> _initializeMembers() async {
    final members = await getMember();
    _allMembers = members;
    _filteredMembersNotifier.value = members;
  }

  void _filterMembers() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.length >= 3) {
      _filteredMembersNotifier.value = _allMembers.where((member) {
        final memberName =
            member['member_name']?.toLowerCase().contains(query) ?? false;
        final unitNumber =
            member['unit_flat_number']?.toLowerCase().contains(query) ?? false;
        return memberName || unitNumber;
      }).toList();
    } else {
      _filteredMembersNotifier.value = _allMembers;
    }
  }

  @override
  void dispose() {
    amqpClient.close(); // Close AMQP client
    _filteredMembersNotifier.dispose();
    _selectedMembersNotifier.dispose();

    super.dispose();
  }

  Future<void> setupAMQPReceiver() async {
    try {
      log("Initializing AMQP Receiver...");

      // Initialize AMQP client with connection settings
      amqpClient = Client(
        settings: ConnectionSettings(
          host: "65.1.230.119",
          authProvider:
              const PlainAuthenticator("dinesh.koli", "7nqRG&I!FesI&7zCrii0"),
        ),
      );

      log("Connecting to RabbitMQ server...");
      await amqpClient.connect();
      log("Connection to RabbitMQ server established successfully.");

      // Define the queue name dynamically based on the mobile number
      final queueName = "visitor_approval_77525_${widget.mobileNumber}";
      log("Queue Name: $queueName");

      // Access the channel and declare the queue
      Channel channel = await amqpClient.channel();
      log("Channel opened.");

      Queue queue = await channel.queue(queueName, durable: false);
      log("Queue declared: $queueName");

      // Bind the queue to an exchange (if required)
      // Note: Replace "exchange_name" and "routing_key" with actual values if applicable
      const String exchangeName = "logs"; // Example exchange name
      final Exchange exchange = await channel.exchange(
        exchangeName,
        ExchangeType.FANOUT,
        durable: false,
      );
      log("Exchange bound: $exchangeName");

      await queue.bind(exchange, "routing_key_placeholder");
      log("Queue bound to exchange with routing key.");

      // Start consuming messages from the queue
      Consumer consumer = await queue.consume();

      log("Consumer registered for queue. Waiting for messages...");

      // Listen for messages on the queue
      consumer.listen((AmqpMessage message) {
        log("Message received from queue.");

        try {
          // Decode the message payload
          final payload = utf8.decode(message.payload as List<int>);
          log("Raw Message Payload: $payload");

          // Parse the message as JSON
          final response = jsonDecode(payload);
          log("Decoded Message: $response");

          // Extract the approval status from the message
          final status = response['status'];
          log("Approval Status: $status");
          showApprovalDialog(status);

          // Update the dialog dynamically
          // setState(() {
          //   approvalStatus = status;
          // });

          // Acknowledge the message
          message.ack();
        } catch (e) {
          log("Error processing message: $e");
        }
      });
    } catch (e) {
      log("Error setting up AMQP Receiver: $e");
    }
  }

  Future<void> showApprovalDialog(approvalStatusNew) async {
    // Ensure `approvalStatus` starts with "Waiting for approval..."
    // setState(() {
    //   approvalStatus = "Waiting for approval...";
    // });

    await setupAMQPReceiver();

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

  Future<void> fetchBuildings() async {
    try {
      setState(() => isLoading = true);
      final userId = GlobalUser.getUserId();
      if (userId == null) {
        throw Exception("Company ID (userId) is null");
      }
      final response = await _dio.get(
        'https://societybackend.cubeone.in/api/admin/building/list?company_id=$userId',
      );
      setState(() {
        buildings = response.data['data'];
        if (buildings.isNotEmpty) {
          selectedBuilding = buildings[0]['soc_building_name'];
          fetchUnits(buildings[0]['id']);
        }
      });
    } catch (e) {
      print('Error fetching buildings: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchUnits(int buildingId) async {
    try {
      setState(() => isUnitsLoading = true);
      final userId = GlobalUser.getUserId();
      if (userId == null) {
        throw Exception("Company ID (userId) is null");
      }
      final response = await _dio.get(
        'https://societybackend.cubeone.in/api/admin/units/list',
        queryParameters: {
          'company_id': userId,
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
      final userId = GlobalUser.getUserId();
      if (userId == null) {
        throw Exception("Company ID (userId) is null");
      }
      final response = await _dio.get(
          'https://societybackend.cubeone.in/api/admin/member/list',
          queryParameters: {
            'company_id': userId,
            'unit_id': null,
            'current_tab': 'approved'
          });
          log("response:::$response");
      return response.data['data'];
    } catch (e) {
      print('Error fetching members: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return MyScrollView(
      isScrollable: false,
      pageTitle: 'Select Units/Members',
      pageBody: FutureBuilder<void>(
        future: _initializeMembers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
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

      // pageBody: DefaultTabController(
      //   length: 2,
      //   child: SizedBox(
      //     height: MediaQuery.of(context).size.height,
      //     child: Column(
      //       children: [
      //         // if (approvalStatus != null)
      //         //   Padding(
      //         //     padding: const EdgeInsets.all(16.0),
      //         //     child: Text(
      //         //       "Approval Status: $approvalStatus",
      //         //       style: Theme.of(context).textTheme.headlineSmall,
      //         //     ),
      //         //   ),
      //         TabBar(
      //           labelStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
      //                 fontWeight: FontWeight.bold,
      //               ),
      //           indicatorColor: Colors.red,
      //           tabs: const [
      //             Tab(text: 'Units'),
      //             Tab(text: 'Members'),
      //           ],
      //         ),
      //         Expanded(
      //           child: TabBarView(
      //             // physics: const NeverScrollableScrollPhysics(),
      //             children: [
      //               buildUnitsTab(),
      //               buildMembersTab(),
      //             ],
      //           ),
      //         ),
      //       ],
      //     ),
      //   ),
      // ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (selectedUnit != null || selectedMember != null) {
            print("Selected Unit: $selectedUnit");
            print("Selected Member: $selectedMember");
            await postSelection(context);
            showApprovalDialog('Waiting for approval......');
          } else {
            print("No selection made");
          }
        },
        label: Text(
          selectedUnit != null
              ? "Selected Unit: $selectedUnit"
              : selectedMember != null
                  ? "Selected Member: $selectedMember"
                  : "No Selection",
        ),
        icon: const Icon(Icons.navigate_next),
      ),
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

  Widget _buildMemberList(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _selectedMembersNotifier,
      builder: (context, selectedMembers, child) {
        return ValueListenableBuilder<List<dynamic>>(
          valueListenable: _filteredMembersNotifier,
          builder: (context, filteredMembers, child) {
            if (filteredMembers.isEmpty) {
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
              padding: const EdgeInsets.all(16),
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index];
                final isSelected =
                    selectedMembers.contains(member['member_details']);

                return ExpansionTile(
                  // contentPadding: EdgeInsets.zero,
                  title: Text(
                    member['unit_flat_number'],
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                  ),
                  subtitle: Text(
                    member['member_name'],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      isSelected
                          ? Ionicons.checkmark_circle
                          : Ionicons.add_circle_outline,
                      color: isSelected ? Colors.green : null,
                    ),
                    onPressed: () {
                      print("Selected Member: ${member['member_name']}");
                      // Update the selected members in the ValueNotifier
                      final updatedMembers = Set<String>.from(selectedMembers);
                      print("update:::$updatedMembers");
                      if (isSelected) {
                        updatedMembers.remove(member['member_name']);
                      } else {
                        updatedMembers.add(member['member_name']);
                      }
                      _selectedMembersNotifier.value = updatedMembers;
                      print("Members:::$updatedMembers");
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget buildUnitsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButton<String>(
            value: selectedBuilding,
            items: buildings.map<DropdownMenuItem<String>>((building) {
              return DropdownMenuItem<String>(
                value: building['soc_building_name'],
                child: Text(building['soc_building_name']),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedBuilding = value!;
                final buildingId = buildings.firstWhere(
                    (building) => building['soc_building_name'] == value)['id'];
                fetchUnits(buildingId);
              });
            },
          ),
        ),
        if (isUnitsLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(
                12,
                16,
                12,
                MediaQuery.of(context).size.height * 0.25,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2,
              ),
              itemCount: units.length,
              itemBuilder: (context, index) {
                final unit = units[index]['unit_flat_number'];
                final isSelected = selectedUnit == unit;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedUnit = unit;
                      selectedMember = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          isSelected ? Colors.orange[100] : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? Colors.orange : Colors.grey,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FittedBox(
                      child: Text(
                        unit,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.orange : Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget buildMembersTab() {
    return FutureBuilder<List<dynamic>>(
      future: getMember(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
        } else {
          if (_allMembers.isEmpty) {
            _allMembers = snapshot.data!;
            _filteredMembers = _allMembers;
          }

          return SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Column(
              children: [
                CustomForm.textField(
                  'Search Members',
                  titleColor: Theme.of(context).colorScheme.onSurface,
                  hintColor:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  hintText: 'Search Members',
                  textController: _searchController,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Ionicons.search,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: () {
                          final query =
                              _searchController.text.trim().toLowerCase();
                          setState(() {
                            _filteredMembers = _allMembers.where((member) {
                              final memberName = member['member_name']
                                  ?.toLowerCase()
                                  .contains(query);
                              final unitNumber = member['unit_flat_number']
                                  ?.toLowerCase()
                                  .contains(query);
                              return memberName || unitNumber;
                            }).toList();
                          });
                        },
                      ),
                      _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Ionicons.close,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _filteredMembers = _allMembers;
                                });
                              },
                            )
                          : const SizedBox.shrink(),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = _filteredMembers[index];
                      final isSelected =
                          selectedMember == member['member_name'];
                      return ListTile(
                        title: Text(
                          member['member_name'],
                        ),
                        subtitle: Text(member['unit_flat_number']),
                        trailing: IconButton(
                          icon: Icon(
                            isSelected
                                ? Ionicons.checkmark_circle
                                : Ionicons.add_circle_outline,
                            color: isSelected ? Colors.green : null,
                          ),
                          onPressed: () {
                            setState(() {
                              selectedMember = member['member_name'];
                              selectedUnit = null;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Future<void> postSelection(BuildContext context) async {
    try {
      String formattedInTime =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      String? userId;

      if (selectedUnit != null) {
        userId = units
            .firstWhere(
                (unit) => unit['unit_flat_number'] == selectedUnit)['id']
            .toString();
      } else if (selectedMember != null) {
        userId = _allMembers
            .firstWhere(
                (member) => member['member_name'] == selectedMember)['id']
            .toString();
      } else {
        print("No unit or member selected for user_id");
        return;
      }

      final data = {
        'company_id': "8196",
        'name': widget.guestname,
        'mobile': widget.mobileNumber,
        'purpose': "meeting",
        'in_time': formattedInTime,
        'user_id': "5",
        'visitor_count': widget.guestCount?.toString() ?? "1",
        'purpose_details': "zomato",
        'coming_from': widget.comingFrom ?? "Unknown",
      };

      print("Request Data: $data");

      final response = await Dio().post(
        'https://gateapi.cubeone.in/api/send-fcm-notification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: data,
      );

      if (response.statusCode == 200) {
        print("FCM notification sent successfully: ${response.data}");
        setState(() {
          isWaitingForApproval = true; // Show waiting state
        });
        await showApprovalDialog(approvalStatus);
        setupAMQPReceiver();
        // Start listening for approval
      } else {
        print("Failed to send FCM notification: ${response.statusCode}");
      }
    } catch (e) {
      log("Error during posting or sending notification: $e");
    }
  }
}
