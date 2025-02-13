import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/models/staff_model.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/settings_home.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/staff_model.dart';
import 'edit_staff.dart';
class StaffListWidget extends StatelessWidget {
  final List<StaffModel> staffList;

  const StaffListWidget({Key? key, required this.staffList}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: staffList.length,
      itemBuilder: (context, index) {
        final staff = staffList[index];

        return GestureDetector(
          onTap: () {
            // Navigate to EditStaff or any other action with the selected staff
            log("Selected staff: ${staff.name}");
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.all(8),
            child: PrimarySettingsTile(
              leadingIcon: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[200],
                child: const Icon(Icons.person, color: Colors.grey),
              ),
              title: staff.name,
              subtitleWidget: Text(staff.category),
              trailing: IconButton(
                onPressed: () {
                  _launchCaller(staff.staffContactNumber);
                },
                icon: const Icon(
                  Icons.call,
                  color: Colors.green,
                ),
              ),
            ),
          ),
        );
      },
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
}

