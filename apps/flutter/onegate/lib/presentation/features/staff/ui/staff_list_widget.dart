import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/settings_home.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/staff_model.dart';
import 'edit_staff.dart';

class StaffListWidget extends StatelessWidget {
  final List<dynamic> staffList;

  const StaffListWidget({Key? key, required this.staffList}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: staffList.length,
      itemBuilder: (context, index) {
        final staffMap = staffList[index];
        final contactNumber = staffMap['staff_contact_number'] ?? 'N/A';

        return GestureDetector(
          onTap: () {
            final staffObj = Staff.fromJson(staffMap);
            log("staffObj: $staffObj");

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EditStaff(
                  staff: staffObj,
                  // staffId: staffMap['id'],
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
            decoration: BoxDecoration(
              border: Border.all(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: PrimarySettingsTile(
              icon: Symbols.person,
              title: staffMap['name'].toString() ?? 'No Name',
              subtitle: 'Contact: $contactNumber',
              trailing: IconButton(
                onPressed: () {
                  if (contactNumber != 'N/A' && contactNumber.isNotEmpty) {
                    _launchCaller(contactNumber);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No contact number available'),
                      ),
                    );
                  }
                },
                icon: const Icon(Symbols.call),
              ),
            ),
          ),
        );
      },
    );
  }

  void _launchCaller(String number) async {
    final url = 'tel:$number';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
