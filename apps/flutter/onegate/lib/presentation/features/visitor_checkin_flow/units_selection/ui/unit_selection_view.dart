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
// import 'package:onegate_client/onegate_client.dart';

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

  bool isLoading = true;
  bool isUnitsLoading = false;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredMembers = [];
  List<dynamic> _allMembers = [];
  String? approvalStatus;

  @override
  void initState() {
    super.initState();
    fetchBuildings();
    setupAMQPReceiver(); // Initialize AMQP receiver
  }

  @override
  void dispose() {
    amqpClient.close(); // Close AMQP client when the widget is disposed
    super.dispose();
  }

  Future<void> setupAMQPReceiver() async {
    try {
      log("Setting up AMQP Receiver");

      amqpClient = Client(
        settings: ConnectionSettings(
          host: "192.168.1.145",
          port: 15672,
          authProvider: const PlainAuthenticator("quest", "guest"),
        ),
      );

      Channel channel = await amqpClient.channel();
      Queue queue = await channel.queue(
        "visitor_approval_77525_${widget.visitorId}",
        durable: false,
      );

      log("Waiting for messages...");

      // Await the Consumer and then listen
      Consumer consumer = await queue.consume(consumerTag: "visitor_response");
      consumer.listen((AmqpMessage message) {
        final response = String.fromCharCodes(message.payload as List<int>);
        log("Received message: $response");

        // Example response processing
        final responseData = jsonDecode(response);
        final status = responseData['status']; // e.g., "Approved" or "Rejected"

        setState(() {
          approvalStatus = status;
        });

        log("Approval Status: $status");
        message.ack();
      });
    } catch (e) {
      log("Error in AMQP Receiver: $e");
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
        queryParameters: {'company_id': userId},
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
            if (approvalStatus != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Approval Status: $approvalStatus",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
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
            await postSelection();
            print("success");
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(builder: (context) => GateDashboardView()),
            // );
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

  Future<void> postSelection() async {
    print("Mobile number from widget: ${widget.mobileNumber}");

    try {
      String formattedInTime =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final String mobileNumber = widget.mobileNumber.trim();

      if (!RegExp(r'^\d{10,15}$').hasMatch(mobileNumber)) {
        print("Invalid mobile number: $mobileNumber");
        return;
      }

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

      print("Selected user_id: $userId");

      final String guestName =
          widget.guestname.isNotEmpty ? widget.guestname : "Unknown";
      print("Guest Name: $guestName");

      final data = {
        'company_id': "8191",
        'name': "shubham bane",
        'mobile': "8452060059",
        'purpose': "meeting",
        'in_time': formattedInTime,
        'user_id': "77525",
        'visitor_count': widget.guestCount?.toString() ?? "1",
        'purpose_details': "zomato",
        'coming_from': widget.comingFrom ?? "Unknown",
      };

      print("Request Data: $data");

      final response = await _dio.post(
        'https://gateapi.cubeone.in/api/send-fcm-notification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: data,
      );

      if (response.statusCode == 200) {
        print("FCM notification sent successfully: ${response.data}");
      } else {
        print("Failed to send FCM notification: ${response.statusCode}");
        print("Response: ${response.data}");
      }
    } catch (e) {
      if (e is DioError) {
        print(
            "Error during posting or sending notification: ${e.response?.data}");
        print("Request Data: ${e.response?.requestOptions.data}");
        if (e.response?.statusCode == 400) {
          print("Validation error or bad request.");
        }
      } else {
        print("Error during posting or sending notification: $e");
      }
    }
  }
}
