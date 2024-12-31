import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/settings_home.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

class StaffListWidget extends StatelessWidget {
  final List<dynamic> staffList;

  const StaffListWidget({Key? key, required this.staffList}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: staffList.length,
      itemBuilder: (context, index) {
        final staff = staffList[index];
        final contactNumber = staff['staff_contact_number'] ?? 'N/A';

        return PrimarySettingsTile(
          icon: Symbols.person,
          title: staff['name'] ?? 'No Name',
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
