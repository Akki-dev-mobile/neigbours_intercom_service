import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/staff/ui/addStaff.dart';
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
  RemoteDataSource _remoteDataSource = RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  );

  GateStorage gateStorage = GateStorage();

  @override
  void initState() {
    super.initState();
    _initializeSocietyId();
  }

  Future<void> _initializeSocietyId() async {
    var societyID = await gateStorage.getSocietyId();
    log('Society ID: $societyID');
    _staffFuture = _staffApi.fetchStaffList(societyID.toString());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: "Staff",
      pageBody: FutureBuilder<List<dynamic>>(
        future: _staffFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(
                  color: Colors.red,
                ),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            return StaffListWidget(staffList: snapshot.data!);
          } else {
            return const Center(child: Text('No Data Available'));
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddStaff(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
