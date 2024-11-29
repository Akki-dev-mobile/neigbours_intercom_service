import 'dart:convert';
import 'dart:developer';

import 'package:dart_amqp/dart_amqp.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
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
  String selectedBuilding = '';
  List<dynamic> buildings = [];
  List<dynamic> units = [];
  late Client amqpClient;
  String? approvalStatus; // Holds approval/decline message
  bool isWaitingForApproval = false; // Shows waiting state
  bool isLoading = true;
  bool isUnitsLoading = false;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredMembers = [];
  List<dynamic> _allMembers = [];

  @override
  void initState() {
    super.initState();
    fetchBuildings();
    setupAMQPReceiver(); // Initialize AMQP receiver
    print("rohit${widget.mobileNumber}");
  }

  @override
  void dispose() {
    amqpClient.close(); // Close AMQP client
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

          // Update the UI with the approval status
          setState(() {
            approvalStatus = status;
            isWaitingForApproval = false;
          });

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

  Future<void> fetchBuildings() async {
    try {
      setState(() => isLoading = true);
      final userId = GlobalUser.getUserId();
      if (userId == null) {
        throw Exception("Company ID (userId) is null");
      }
      final response = await _dio.get(
        'https://societybackend.cubeone.in/api/admin/building/list',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Units/Members'),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // if (approvalStatus != null)
            //   Padding(
            //     padding: const EdgeInsets.all(16.0),
            //     child: Text(
            //       "Approval Status: $approvalStatus",
            //       style: Theme.of(context).textTheme.headlineSmall,
            //     ),
            //   ),
            const TabBar(
              tabs: [
                Tab(text: 'Units'),
                Tab(text: 'Members'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  buildUnitsTab(),
                  buildMembersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (selectedUnit != null || selectedMember != null) {
            print("Selected Unit: $selectedUnit");
            print("Selected Member: $selectedMember");
            await postSelection(context);
            print("success");
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
              padding: const EdgeInsets.all(16),
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
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.orange : Colors.black,
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
          // Do nothing while waiting for data
          return Container();
        } else if (snapshot.hasError) {
          // Show error message if there's an error
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Handle case when no members are found
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'No Members Found.\nSearch members by their name or flat',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          );
        } else {
          // Populate the members list
          if (_allMembers.isEmpty) {
            _allMembers = snapshot.data!;
            _filteredMembers = _allMembers;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search Members/Units',
                          border: OutlineInputBorder(),
                          prefixIcon: const Icon(Ionicons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
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
                      child: const Text('Search'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = _filteredMembers[index];
                    final isSelected = selectedMember == member['member_name'];
                    return ListTile(
                      title: Text(member['member_name']),
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
        'company_id': "8191",
        'name': widget.guestname,
        'mobile': widget.mobileNumber,
        'purpose': "meeting",
        'in_time': formattedInTime,
        'user_id': "77525",
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

        setupAMQPReceiver(); // Start listening for approval
      } else {
        print("Failed to send FCM notification: ${response.statusCode}");
      }
    } catch (e) {
      log("Error during posting or sending notification: $e");
    }
  }
}
