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
    return _filteredList.isEmpty
        ? _buildNoStaffFoundWidget(context)
        : Column(
            children: List.generate(_filteredList.length, (index) {
                    final staff = _filteredList[index];
                    return _buildStaffCard(context, staff);
            }),
    );
  }

  Widget _buildStaffCard(BuildContext context, StaffModel staff) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
      ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
      child: InkWell(
        onTap: () {
          log("Selected staff: ${staff.name}");
          _showStaffDetails(context, staff);
        },
          borderRadius: BorderRadius.circular(20),
        child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
          child: Row(
            children: [
                // Enhanced avatar with gradient background
                Container(
                  width: isTablet ? 70 : 60,
                  height: isTablet ? 70 : 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.red.shade300,
                        Colors.red.shade400,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.shade300.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                child: Text(
                  staff.name.isNotEmpty ? staff.name[0].toUpperCase() : "?",
                      style: TextStyle(
                        fontSize: isTablet ? 28 : 24,
                    fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 20 : 16),

                // Enhanced staff info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isTablet ? 18 : 16,
                          color: const Color(0xff212427),
                          letterSpacing: 0.3,
                      ),
                    ),
                      SizedBox(height: isTablet ? 8 : 6),

                      // Category with icon
                      Row(
                        children: [
                          Icon(
                            Icons.work_outline_rounded,
                            size: isTablet ? 16 : 14,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                      staff.category,
                      style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: isTablet ? 15 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                      ),
                    ),
                        ],
                      ),
                      SizedBox(height: isTablet ? 6 : 4),

                      // Phone with icon
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: isTablet ? 16 : 14,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                      staff.staffContactNumber,
                      style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: isTablet ? 15 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                      ),
                        ],
                    ),
                  ],
                ),
              ),

                // Enhanced call button
              IconButton(
                onPressed: () => _launchCaller(staff.staffContactNumber),
                  icon: Icon(
                    Icons.call_rounded,
                    color: Colors.green.shade600,
                    size: isTablet ? 28 : 24,
                  ),
              ),
            ],
            ),
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

  Widget _buildNoStaffFoundWidget(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: isTablet ? 80 : 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Enhanced icon container
            Container(
              padding: EdgeInsets.all(isTablet ? 32 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.red.shade50,
                    Colors.red.shade100.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: Colors.red.shade200.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: isTablet ? 64 : 48,
                color: Colors.red.shade300,
              ),
            ),
            SizedBox(height: isTablet ? 24 : 20),

            // Enhanced title
            Text(
              'No Staff Found',
              style: TextStyle(
                color: const Color(0xff212427),
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: isTablet ? 8 : 6),

            // Enhanced subtitle
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 50 : 32),
              child: Text(
                'No staff members match your search criteria. Try adjusting your search terms.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: isTablet ? 14 : 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStaffDetails(BuildContext context, StaffModel staff) {
    // keep your existing modal logic here
  }
}
