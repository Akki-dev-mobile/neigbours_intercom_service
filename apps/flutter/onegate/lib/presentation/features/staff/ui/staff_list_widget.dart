import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/models/staff_model.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/settings_home.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/staff_model.dart';
import 'edit_staff.dart';

class StaffListWidget extends StatefulWidget {
  final List<StaffModel> staffList;

  const StaffListWidget({Key? key, required this.staffList}) : super(key: key);

  @override
  State<StaffListWidget> createState() => _StaffListWidgetState();
}

class _StaffListWidgetState extends State<StaffListWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<StaffModel> _filteredList = [];

  @override
  void initState() {
    super.initState();
    _filteredList = widget.staffList;
    _searchController.addListener(_filterStaffList);
  }

  void _filterStaffList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredList = widget.staffList.where((staff) {
        return staff.name.toLowerCase().contains(query) ||
            staff.staffContactNumber.toLowerCase().contains(query) ||
            staff.category.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Field

        // Staff List (Scrollable)
        _filteredList.isEmpty
            ? const Center(child: Text('No staff found'))
            : Container(
                height: MediaQuery.of(context).size.height,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _filteredList.length,
                  itemBuilder: (context, index) {
                    final staff = _filteredList[index];
                    return _buildStaffCard(context, staff);
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildStaffCard(BuildContext context, StaffModel staff) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          log("Selected staff: ${staff.name}");
          _showStaffDetails(context, staff);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.red.withOpacity(0.1),
                child: Text(
                  staff.name.isNotEmpty ? staff.name[0].toUpperCase() : "?",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      staff.category,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      staff.staffContactNumber,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _launchCaller(staff.staffContactNumber),
                icon: const Icon(Icons.call, color: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _launchCaller(String number) async {
    final url = 'tel:$number';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  void _showStaffDetails(BuildContext context, StaffModel staff) {
    // keep your existing modal logic here
  }
}
