import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:dart_amqp/dart_amqp.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
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
  final gateStorage = GateStorage();

  File? image;
  Set<int> selectedMembers = {};
  Set<int> selectedUnits = {};
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
  final ValueNotifier<Set<int>> _selectedUnitsNotifier = ValueNotifier({});

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
      setState(() {
        _filteredMembersNotifier.value = _allMembers.where((member) {
          final memberName =
              member['member_name']?.toLowerCase().contains(query) ?? false;
          final unitNumber =
              member['unit_flat_number']?.toLowerCase().contains(query) ??
                  false;
          final unitID =
              member['fk_unit_id']?.toString().toLowerCase().contains(query) ??
                  false;

          print("unitID:::$unitID");

          return memberName || unitNumber || unitID;
        }).toList();
      });
    } else {
      setState(() {
        _filteredMembersNotifier.value = _allMembers;
      });
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
      final userId = gateStorage.getUserId();
      print("Company IDDDDDD$userId");

      if (userId == null) {
        throw Exception("Company ID (userId) is null");
      }
      final response = await _dio.get(
        'https://societybackend.cubeone.in/api/admin/building/list?company_id=$userId',
      );
      setState(() {
        print("Company IDDDDDD");
        buildings = response.data['data'];
        // print("Company IDDDDDD$buildings");
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
      final userId = gateStorage.getUserId();
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
      final userId = gateStorage.getUserId();

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
          return FloatingActionButton.extended(
            onPressed: () async {
              print(
                  "FloatingActionButtonunitId Selected Member: $selectedMembers, Selected Unit: $selectedUnit");

              if (selectedUnits != null || selectedMember != null) {
                print("Selected Unit: $selectedUnits");
                print("Selected Member: $selectedMember");

                String? userId;
                if (selectedUnits.isNotEmpty) {
                  userId = selectedUnits.first.toString();
                } else if (selectedMembers.isNotEmpty) {
                  userId = _allMembers
                      .firstWhere((member) =>
                          selectedMembers.contains(member['member_name']))['id']
                      .toString();
                }
                print("Selected User ID: $userId");

                print("Post Selection:::");
                await postSelection(context, selectedMember, selectedUnits);
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
            icon: Icon(Icons.navigate_next),
          );
        },
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

//   Widget _buildMemberList(BuildContext context) {
//     return ValueListenableBuilder<Set<String>>(
//       valueListenable: _selectedMembersNotifier,
//       builder: (context, selectedMembers, child) {
//         return ValueListenableBuilder<List<dynamic>>(
//           valueListenable: _filteredMembersNotifier,
//           builder: (context, filteredMembers, child) {
//             if (filteredMembers.isEmpty) {
//               return Center(
//                 child: Text(
//                   'No Members Found.\nSearch members by their name or flat',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 16,
//                     color: Colors.grey[600],
//                   ),
//                 ),
//               );
//             }
//           ListView.builder(
//   padding: const EdgeInsets.all(16),
//   itemCount: filteredMembers.length,
//   itemBuilder: (context, index) {
//     if (filteredMembers.isEmpty || index >= filteredMembers.length) {
//       // Safeguard in case data is empty or index is out of bounds
//       return const SizedBox.shrink(); // Return an empty widget
//     }

//     final member = filteredMembers[index];
//     final isSelected = selectedMembers.contains(member['unit_flat_number']);

//     return ExpansionTile(
//       title: Text(
//         member['unit_flat_number'] ?? 'N/A',
//         style: Theme.of(context).textTheme.bodyMedium!.copyWith(
//               fontWeight: FontWeight.bold,
//               fontSize: 16,
//             ),
//       ),
//       children: (member['member_details'] as List<dynamic>?)
//               ?.map<Widget>((detail) {
//             final firstName = detail['member_first_name'] ?? 'N/A';
//             final userId = detail['user_id']?.toString() ?? 'N/A';

//             return ListTile(
//               title: Text(
//                 'First Name: $firstName',
//                 style: Theme.of(context).textTheme.bodyMedium,
//               ),
//               subtitle: Text(
//                 'User ID: $userId',
//                 style: Theme.of(context).textTheme.bodySmall,
//               ),
//               trailing: IconButton(
//                 icon: Icon(
//                   isSelected
//                       ? Ionicons.checkmark_circle
//                       : Ionicons.add_circle_outline,
//                   color: isSelected ? Colors.green : null,
//                 ),
//                 onPressed: () {
//                   // Update the selection logic
//                   final updatedMembers = Set<String>.from(selectedMembers);
//                   if (isSelected) {
//                     updatedMembers.remove(member['unit_flat_number']);
//                   } else {
//                     updatedMembers.add(member['unit_flat_number']);
//                   }
//                   _selectedMembersNotifier.value = updatedMembers;
//                 },
//               ),
//             );
//           }).toList() ??
//           [const Text('No details available')], // Fallback if details are null
//     );
//   },
// );

//             // return ListView.builder(
//             //   padding: const EdgeInsets.all(16),
//             //   itemCount: filteredMembers.length,
//             //   itemBuilder: (context, index) {
//             //     final member = filteredMembers[index];
//             //     final isSelected = selectedMembers.contains(member['member_name'][0]);

//             //     return ExpansionTile(
//             //       title: Text(
//             //       member['unit_flat_number'],
//             //       style: Theme.of(context).textTheme.bodyMedium!.copyWith(
//             //           fontWeight: FontWeight.w900,
//             //           fontSize: 14,
//             //         ),
//             //       ),
//             //       children: [
//             //       ListTile(
//             //         title: Text(
//             //         member['member_name'],
//             //         style: Theme.of(context).textTheme.bodyMedium,
//             //         ),
//             //         subtitle: Text(
//             //         'Name: ${member['member_detials'] ?? 'N/A'}\nEmail: ${member['member_email_id'] ?? 'N/A'}\nName: ${member['member_first_name'] ?? 'N/A'}',
//             //         style: Theme.of(context).textTheme.bodySmall,
//             //         ),
//             //         trailing: IconButton(
//             //         icon: Icon(
//             //           isSelected
//             //             ? Ionicons.checkmark_circle
//             //             : Ionicons.add_circle_outline,
//             //           color: isSelected ? Colors.green : null,
//             //         ),
//             //         onPressed: () {
//             //           print("Selected Member: ${member['member_name']}");
//             //           final updatedMembers = Set<String>.from(selectedMembers);
//             //           if (isSelected) {
//             //           updatedMembers.remove(member['member_name']);
//             //           } else {
//             //           updatedMembers.add(member['member_name']);
//             //           }
//             //           _selectedMembersNotifier.value = updatedMembers;
//             //         },
//             //         ),
//             //       ),
//             //       ],
//             //     );
//             //     // final member = filteredMembers[index];
//             //     // final isSelected =
//             //     //     selectedMembers.contains(member['member_name']);

//             //     // return ExpansionTile(
//             //     //   // contentPadding: EdgeInsets.zero,
//             //     //   title: Text(
//             //     //     member['unit_flat_number'],
//             //     //     style: Theme.of(context).textTheme.bodyMedium!.copyWith(
//             //     //           fontWeight: FontWeight.w900,
//             //     //           fontSize: 14,
//             //     //         ),
//             //     //   ),
//             //     //   children: [
//             //     //     Text(
//             //     //     member['member_name'],
//             //     //     style: Theme.of(context).textTheme.bodyMedium,
//             //     //   ),

//             //     //   ],
//             //     //   // subtitle: Text(
//             //     //   //   member['member_name'],
//             //     //   //   style: Theme.of(context).textTheme.bodyMedium,
//             //     //   // ),
//             //     //   trailing: IconButton(
//             //     //     icon: Icon(
//             //     //       isSelected
//             //     //           ? Ionicons.checkmark_circle
//             //     //           : Ionicons.add_circle_outline,
//             //     //       color: isSelected ? Colors.green : null,
//             //     //     ),
//             //     //     onPressed: () {
//             //     //       print("Selected Member: ${member['member_name']}");
//             //     //       // Update the selected members in the ValueNotifier
//             //     //       final updatedMembers = Set<String>.from(selectedMembers);
//             //     //       print("update:::$updatedMembers");
//             //     //       if (isSelected) {
//             //     //         updatedMembers.remove(member['member_name']);
//             //     //       } else {
//             //     //         updatedMembers.add(member['member_name']);
//             //     //       }
//             //     //       _selectedMembersNotifier.value = updatedMembers;
//             //     //       print("Members:::$updatedMembers");
//             //     //     },
//             //     //   ),
//             //     // );
//             //   },
//             // );

//           },
//         );
//       },
//     );
//   }

// Define a global variable to store user IDs
  Set<String> selectedUserIds = {};

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
              padding: const EdgeInsets.all(16),
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index];
                final unitId = member['fk_unit_id']?.toString() ?? 'N/A';
                print("ninad nigga $unitId");
                final isSelected =
                    selectedMembers.contains(member['unit_flat_number']);

                return ExpansionTile(
                  title: Text(
                    member['unit_flat_number'] ?? 'N/A',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                  ),
                  subtitle: Text(
                    'Unit ID: $unitId',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  children: (member['member_details'] as List<dynamic>?)
                          ?.map<Widget>((detail) {
                        print(member['member_details']);
                        final firstName = detail['member_first_name'] ?? 'N/A';
                        final lastName =
                            detail['member_last_name']?.toString() ?? 'N/A';
                        final userId = detail['user_id']?.toString() ?? 'N/A';

                        return ListTile(
                          title: Text(
                            'First Name: $firstName',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          subtitle: Text(
                            'Last Name: $lastName\nUser ID: $userId',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              selectedMembers.contains(firstName)
                                  ? Ionicons.checkmark_circle
                                  : Icons.add_circle_outline,
                              color: selectedMembers.contains(firstName)
                                  ? Colors.green
                                  : null,
                            ),
                            onPressed: () {
                              // unitId
                              print("ListView.builder unitId:::$unitId");

                              final updatedMembers =
                                  Set<String>.from(selectedMembers);
                              if (selectedMembers.contains(firstName)) {
                                updatedMembers.remove(firstName);
                                selectedUserIds.remove(
                                    userId); // Remove userId from global variable
                              } else {
                                updatedMembers.add(firstName);
                                selectedUserIds.add(
                                    userId); // Add userId to global variable
                              }
                              _selectedMembersNotifier.value = updatedMembers;

                              // Add/remove unitId in selectedUnits
                              final updateUnits = Set<int>.from(selectedUnits);
                              if (selectedUnits.contains(unitId)) {
                                updateUnits.remove(unitId);
                              } else {
                                selectedUnits.add(unitId);
                              }
                              _selectedUnitsNotifier.value = updateUnits;

                              // Debugging logs
                              print("Selected User IDs: $selectedUserIds");
                            },
                          ),
                        );
                      }).toList() ??
                      [
                        const Text('No details available')
                      ], // Fallback if details are null
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

                      final unitID = member['fk_unit_id'];
                      print("unitID:::$unitID");
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
                              selectedUnit = member['fk_unit_id'];

                              print(
                                  "Selected Member: $selectedMember, Selected Unit: $selectedUnit");
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

//   Future<void> postSelection(
//     BuildContext context,
//     selectedMember,
//     unitId,
//   ) async {
//     print("Request Data Posting selection...");
//     print(
//         "postSlection:: selectedUnit:::$selectedUnits, selectedMember:::$selectedMember");
//
//     try {
//       String formattedInTime =
//           DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
//       String? userId;
//       print(
//           "postSlection:: selectedUnit:::$selectedUnits, selectedMember:::$selectedMember");
//       if (unitId != null) {
//         print("selectedUnit:::$selectedUnit");
//
//         userId = units
//             .firstWhere((unit) => unit['unit_flat_number'] == unitId)[
//                 'fk_unit_id']
//             .toString();
//         print("c::$userId");
//       } else if (selectedMember != null) {
//         userId = _allMembers
//             .firstWhere(
//                 (member) => member['member_name'] == selectedMember)['id']
//             .toString();
//       } else {
//         print("No unit or member selected for user_id");
//         return;
//       }
//
//       final data = {
//         'company_id': GlobalUser.getUserId(),
//         'name': widget.guestname,
//         'mobile': widget.mobileNumber,
//         'purpose': "meeting",
//         'in_time': formattedInTime,
//         'user_id': userId,
//         'visitor_count': widget.guestCount?.toString() ?? "1",
//         'purpose_details': "zomato",
//         'coming_from': widget.comingFrom ?? "Unknown",
//       };
//
//       print("Request Data: $data");
//
//       final response = await Dio().post(
//         'https://gateapi.cubeone.in/api/send-fcm-notification',
//         options: Options(headers: {"Content-Type": "application/json"}),
//         data: data,
//       );
//
//       if (response.statusCode == 200) {
//         print("FCM notification sent successfully: ${response.data}");
//         setState(() {
//           isWaitingForApproval = true; // Show waiting state
//         });
//
//         await showApprovalDialog(approvalStatus);
//         setupAMQPReceiver();
//         // Start listening for approval
//       } else {
//         print("Failed to send FCM notification: ${response.statusCode}");
//       }
//     } catch (e) {
//       log("Error during posting or sending notification: $e");
//     }
//   }
// }
  Future<void> postSelection(BuildContext context, Set<String> selectedMembers,
      Set<int> selectedUnits) async {
    print("Request Data Posting selection...");
    print(
        "postSelection:: selectedUnits:::$selectedUnits, selectedMembers:::$selectedMembers");

    try {
      // Ensure only one user ID is processed
      if (selectedUserIds.length != 1) {
        print("Request skipped: Exactly one user ID must be selected.");
        print("Returning success as no posting is required.");
        await Navigator.push(context,
            MaterialPageRoute(builder: (context) => const GateDashboardView()));
        return;
      }

      // Ensure only one unit is processed
      if (selectedUnits.length != 1) {
        print("Request skipped: Exactly one unit must be selected.");
        print("Returning success as no posting is required.");
        return;
      }

      // Extract the single user ID and unit ID
      String userId = selectedUserIds.first;

      String formattedInTime =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      // Prepare the request data
      final data = {
        'company_id': gateStorage.getUserId(),
        'name': widget.guestname,
        'mobile': widget.mobileNumber,
        'purpose': "meeting",
        'in_time': formattedInTime,
        'user_id': userId, // Single user ID
        'visitor_count': widget.guestCount?.toString() ?? "1",
        'purpose_details': "zomato",
        'coming_from': widget.comingFrom ?? "Unknown",
      };

      print("Request Data:");
      data.forEach((key, value) {
        print("$key: $value (Type: ${value.runtimeType})");
      });

      // Send the request
      final response = await Dio().post(
        'https://gateapi.cubeone.in/api/send-fcm-notification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: data,
      );

      // Handle response
      if (response.statusCode == 200) {
        print("FCM notification sent successfully: ${response.data}");

        setState(() {
          isWaitingForApproval = true; // Show waiting state
        });

        await showApprovalDialog(approvalStatus);
        setupAMQPReceiver();
      } else {
        print("Failed to send FCM notification: ${response.statusCode}");
      }
    } catch (e) {
      log("Error during posting or sending notification: $e");
    }
  }
}
