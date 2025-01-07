import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_provider.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';


class GateSelectionView extends StatelessWidget {
  const GateSelectionView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GateProvider(),
      child: Consumer<GateProvider>(
        builder: (context, provider, child) {
          return MyScrollView(
            backButtonPressed: () {
              Navigator.pop(context);
            },
            pageTitle: 'Gate Selection',
            pageBody: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Select your gate',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                ...List.generate(provider.gates!.length, (index) {
                  return GateSettingListTile(
                    switchValue: provider.gates![index]['isSelected'],
                    onChanged: (value) =>  provider.selectGate(index),
                    title: provider.gates![index]['gate_name'] ?? 'Unknown Gate',
                    subtitle:
                    'Enable/Disable ${provider.gates![index]['gate_name']}',
                    leadingIcon: Symbols.gate,
                  );
                }),
              ],
            ),
            floatingActionButton: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CustomLargeBtn(
                text: 'CONFIRM',
                onPressed: () {
                  final selectedGate = provider.selectedGate;
                  if (selectedGate != null) {
                    print("Selected Gate: ${selectedGate['gateName']}");
                    SnackBar(content: Text("Gate Changed to ${selectedGate['gateName']}"),);
                  } else {
                    print("No gate selected");
                    SnackBar(content: Text("Gate Changed to ${selectedGate?['gateName']}"),);
                  }
   Navigator.push(context, MaterialPageRoute(builder: (context) => GateDashboardView()));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class GateSettingListTile extends StatelessWidget {
  const GateSettingListTile({
    Key? key,
    required this.switchValue,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    this.leadingIcon,
  }) : super(key: key);

  final bool switchValue;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: leadingIcon != null
          ? CircleAvatar(
        backgroundColor: const Color(0xffFFEBE6),
        radius: 22,
        child: Icon(
          size: 24,
          leadingIcon,
          color: Colors.black,
        ),
      )
          : null,
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      trailing: Switch(
        inactiveThumbColor: Theme.of(context).colorScheme.onBackground,
        inactiveTrackColor:
        Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
        value: switchValue,
        onChanged: onChanged,
      ),
    );
  }
}