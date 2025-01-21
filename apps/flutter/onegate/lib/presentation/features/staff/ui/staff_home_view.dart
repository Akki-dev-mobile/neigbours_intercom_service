import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/staff/ui/addstaff.dart';
import 'package:flutter_onegate/presentation/features/staff/ui/staff_list_widget.dart';

import '../../../../dio_setup.dart';
import '../api/staff_api.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({Key? key}) : super(key: key);

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final StaffApi _staffApi = StaffApi();
  late Future<List<dynamic>> _staffFuture = Future.value([]);
  final RemoteDataSource _remoteDataSource = RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  );
  final GateStorage _gateStorage = GateStorage();

  List<dynamic> _staffListFull = [];

  List<dynamic> _filteredStaffList = [];

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeSocietyId();
  }

  Future<void> _initializeSocietyId() async {
    var societyID = await _gateStorage.getSocietyId();
    log('Society ID: $societyID');
    _staffFuture = _staffApi.fetchStaffList(societyID.toString());
    setState(() {});
  }

  void _filterStaffList(String query) {
    if (query.isEmpty) {
      _filteredStaffList = List.from(_staffListFull);
    } else {
      _filteredStaffList = _staffListFull.where((staffMap) {
        final staffName = (staffMap['name'] ?? '').toString().toLowerCase();
        return staffName.contains(query.toLowerCase());
      }).toList();
    }
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    _filteredStaffList = List.from(_staffListFull);
    setState(() {
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      isScrollable: true,
      pageTitleWidget: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Staff'),
          IconButton(
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _clearSearch();
                }
              });
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      pageBody: Column(
        children: [
          if (_isSearching)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  iconColor: Theme.of(context).colorScheme.onSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide:
                        BorderSide(color: Colors.grey), // Blue border on focus
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                        color: Colors.blue), // Blue border on focus
                  ),
                  hintText: 'Enter staff name',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _clearSearch(),
                  ),
                ),
                onChanged: (query) => _filterStaffList(query),
              ),
            ),
          const SizedBox(height: 10),
          FutureBuilder<List<dynamic>>(
            future: _staffFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 400.0),
                    child: CircularProgressIndicator(
                      color: Colors.red,
                    ),
                  ),
                );
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (snapshot.hasData) {
                final freshData = snapshot.data!;

                if (_staffListFull.isEmpty) {
                  _staffListFull = freshData;
                  _filteredStaffList = List.from(_staffListFull);
                }
                print("StaffId");
                print("StaffId: ${_staffListFull[0]['id']} ");

                return StaffListWidget(staffList: _filteredStaffList);
              } else {
                return const Center(child: Text('No Data Available'));
              }
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddStaff(),
            ),
          );
        },
        label: const Text('Add Staff'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
