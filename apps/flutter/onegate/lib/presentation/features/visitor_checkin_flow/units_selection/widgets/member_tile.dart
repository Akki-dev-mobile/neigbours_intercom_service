import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/units_selection/widgets/member_item.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class MemberTile extends StatelessWidget {
  final dynamic member;
  final Set<String> selectedMembers;
  final Function(dynamic) onMemberTap;

  const MemberTile({
    Key? key,
    required this.member,
    required this.selectedMembers,
    required this.onMemberTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final memberDetails = member['member_details'] as List<dynamic>? ?? [];
    final unitFlatNumber = member['unit_flat_number']?.toString() ?? 'N/A';
    final buildingUnit = member['building_unit']?.toString() ?? 'N/A';
    final socBuildingName = member['soc_building_name']?.toString() ?? '';

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Theme.of(context).colorScheme.onSurface.withAlpha(20),
      ),
      child: ExpansionTile(
        iconColor: Colors.redAccent,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: Icon(
          Symbols.location_away,
          color: Theme.of(context).colorScheme.onSurface,
          size: 32,
        ),
        title: Text(
          '$socBuildingName - $unitFlatNumber',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Text(
          "${memberDetails.length} Member(s)",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        collapsedIconColor: Theme.of(context).colorScheme.onSurface,
        children: memberDetails.isEmpty
            ? [Text(AppLocalizations.of(context)!.noMembersAvailable)]
            : memberDetails.map<Widget>((detail) {
                return MemberItem(
                  detail: detail,
                  member: member,
                  selectedMembers: selectedMembers,
                  onTap: onMemberTap,
                );
              }).toList(),
      ),
    );
  }
}
