import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/units_selection/widgets/empty_state.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/units_selection/widgets/member_tile.dart';

class MemberList extends StatelessWidget {
  final ValueNotifier<Set<String>> selectedMembersNotifier;
  final ValueNotifier<List<dynamic>> filteredMembersNotifier;
  final bool isLoading;
  final Function(dynamic, Set<String>) onMemberTap;

  const MemberList({
    Key? key,
    required this.selectedMembersNotifier,
    required this.filteredMembersNotifier,
    required this.isLoading,
    required this.onMemberTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: selectedMembersNotifier,
      builder: (context, selectedMembers, child) {
        return ValueListenableBuilder<List<dynamic>>(
          valueListenable: filteredMembersNotifier,
          builder: (context, filteredMembers, child) {
            if (isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DashboardLoaderIcon(color: Colors.black),
                    SizedBox(height: 16),
                    Text(
                      'Loading members...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            if (filteredMembers.isEmpty) {
              return const EmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index];
                return MemberTile(
                  member: member,
                  selectedMembers: selectedMembers,
                  onMemberTap: (memberDetails) {
                    onMemberTap(memberDetails, selectedMembers);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
