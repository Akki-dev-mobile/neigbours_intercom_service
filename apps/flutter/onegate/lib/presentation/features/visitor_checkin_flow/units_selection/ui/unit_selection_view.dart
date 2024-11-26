import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:onegate_client/onegate_client.dart';

class UnitSelectionView extends StatefulWidget {
  final Visitor visitor;
  final PurposeCategory purposeCategory;
  final String? comingFrom;
  final int? guestCount;
  final String guestname;
  final String mobileNumber;

  const UnitSelectionView(
      {Key? key,
      required this.visitor,
      required this.purposeCategory,
      this.comingFrom,
      this.guestCount,
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
  bool isLoading = true;
  bool isUnitsLoading = false;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredMembers = [];
  List<dynamic> _allMembers = [];

  @override
  void initState() {
    super.initState();
    fetchBuildings();
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
        onPressed: () {
          if (selectedUnit != null || selectedMember != null) {
            postSelection();
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
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.network(
                'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/search_members_692a406814.json',
                height: 200,
              ),
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
          if (_allMembers.isEmpty) {
            _allMembers = snapshot.data!;
            _filteredMembers = _allMembers;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _filteredMembers = _allMembers.where((member) {
                        final memberName = member['member_name']
                            ?.toLowerCase()
                            .contains(value.toLowerCase());
                        final unitNumber = member['unit_flat_number']
                            ?.toLowerCase()
                            .contains(value.toLowerCase());
                        return memberName || unitNumber;
                      }).toList();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search Members/Units',
                    border: OutlineInputBorder(),
                    prefixIcon: const Icon(Ionicons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Ionicons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _filteredMembers = _allMembers;
                        });
                      },
                    ),
                  ),
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
    if (selectedUnit == null && selectedMember == null) {
      print("No selection made");
      return;
    }

    print("Mobile number from widget: ${widget.mobileNumber}");

    try {
      String formattedInTime =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final String mobileNumber = widget.mobileNumber.trim();
      if (!RegExp(r'^\d{10,15}$').hasMatch(mobileNumber)) {
        print("Invalid mobile number: $mobileNumber");
        return;
      }

      final String guestName =
          widget.guestname.isNotEmpty ? widget.guestname : "Unknown";
      print("Guest Name: $guestName");
      String socId = (GlobalUser.getUserId()).toString();
      print(socId);
      String userId = (GlobalUser.getsocId().toString());

      final data = {
        'company_id': "412", // Convert to string
        'name': guestName,
        'mobile': mobileNumber, // Already a string
        'purpose': "meeting",
        'in_time': formattedInTime,
        'user_id': "3729", // Convert to string
        'visitor_count':
            widget.guestCount?.toString() ?? "1", // Convert to string
        'purpose_details': "zomato",
        'coming_from': widget.comingFrom ?? "Unknown",
      };

      print("Request Data: $data");

      final response = await _dio.post(
        'http://192.168.1.34:8000/api/send-fcm-notification',
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
