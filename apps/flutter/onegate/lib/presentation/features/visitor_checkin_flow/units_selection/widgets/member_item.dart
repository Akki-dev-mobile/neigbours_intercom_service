import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

class MemberItem extends StatelessWidget {
  final dynamic detail;
  final dynamic member;
  final Set<String> selectedMembers;
  final Function(dynamic) onTap;

  const MemberItem({
    Key? key,
    required this.detail,
    required this.member,
    required this.selectedMembers,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firstName = detail['member_first_name']?.toString() ?? 'N/A';
    final lastName = detail['member_last_name']?.toString() ?? '';
    final memberName = "$firstName $lastName";

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      title: Text(
        memberName,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: Icon(
        selectedMembers.contains(memberName)
            ? Ionicons.checkmark_circle
            : Icons.add_circle_outline,
        color: selectedMembers.contains(memberName) ? Colors.green : null,
      ),
      onTap: () => onTap(detail),
    );
  }
}
