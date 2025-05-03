import 'dart:developer';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/models/staff_model.dart';
import 'package:flutter_onegate/presentation/features/staff/ui/staff_list_widget.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({Key? key}) : super(key: key);

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  late Future<List<StaffModel>> _staffFuture = Future.value([]);
  final RemoteDataSource remoteDataSource = RemoteDataSource();
  final GateStorage _gateStorage = GateStorage();

  List<StaffModel> _staffListFull = [];
  List<StaffModel> _filteredStaffList = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeSocietyId();
  }

  Future<void> _initializeSocietyId() async {
    var societyID = await _gateStorage.getSocietyId();
    log('Society ID: $societyID');

    _staffFuture = remoteDataSource.fetchStaffList(societyID.toString());
    setState(() {});
  }

  void _filterStaffList(String query) {
    if (query.isEmpty) {
      _filteredStaffList = List.from(_staffListFull);
    } else {
      _filteredStaffList = _staffListFull.where((staff) {
        final staffName = staff.name.toLowerCase();
        return staffName.contains(query.toLowerCase());
      }).toList();
    }
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    _filteredStaffList = List.from(_staffListFull);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      isScrollable: true,
      pageTitle: "Staff",
      pageBody: Column(
        children: [
          CustomForm.textField(
            "Search Staff",
            textController: _searchController,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _clearSearch(),
                  )
                : const SizedBox.shrink(),
            onChanged: (query) => _filterStaffList(query),
            titleColor: Colors.black,
            hintColor: Colors.grey,
            hintText: 'Enter Staff Name',
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<StaffModel>>(
            future: _staffFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 200.0),
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

                if (_filteredStaffList.isEmpty) {
                  return _buildNoStaffWidget();
                }

                // Show the filtered staff list
                return StaffListWidget(staffList: _filteredStaffList);
              } else {
                return _buildNoStaffWidget();
              }
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // floatingActionButton: ElevatedButton.icon(
      //   style: ElevatedButton.styleFrom(
      //     backgroundColor: Theme.of(context).colorScheme.onSurface,
      //   ),
      //   onPressed: () {
      //     Navigator.of(context)
      //         .push(
      //       MaterialPageRoute(
      //         builder: (context) => const AddStaff(),
      //       ),
      //     )
      //         .then((_) {
      //       // Refresh the staff list after navigation
      //       _initializeSocietyId();
      //     });
      //   },
      //   label: Text(
      //     'Add Staff',
      //     style: Theme.of(context)
      //         .textTheme
      //         .bodyLarge
      //         ?.copyWith(color: Colors.white),
      //   ),
      //   icon: Icon(
      //     Icons.add,
      //     size: Theme.of(context).iconTheme.size,
      //     color: Colors.white,
      //   ),
      // ),
    );
  }

  /// **🛑 No Staff Available Widget**
  Widget _buildNoStaffWidget() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 150.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off, // No Staff Icon
              size: 100,
              color: Colors.grey,
            ),
            SizedBox(height: 20),
            Text(
              'No Staff Available',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
