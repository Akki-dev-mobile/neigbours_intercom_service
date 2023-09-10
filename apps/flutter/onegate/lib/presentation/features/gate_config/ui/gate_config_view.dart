// // ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

// import 'package:flutter/material.dart';
// import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
// import 'package:ionicons/ionicons.dart';

// import 'package:common_widgets/common_widgets.dart';
// import 'package:page_transition/page_transition.dart';

// class GateConfigView extends StatefulWidget {
//   const GateConfigView({super.key});

//   @override
//   State<GateConfigView> createState() => _GateConfigViewState();
// }

// class _GateConfigViewState extends State<GateConfigView> {
//   bool _visitorsIn = true;
//   bool _visitorsOut = false;
//   bool _vehicleIn = true;
//   bool _vehicleOut = false;

//   @override
//   Widget build(BuildContext context) {
//     return MyScrollView(
//       pageTitle: 'Gate Settings',
//       pageBody: Column(
//         children: [
//           ListTile(
//             contentPadding: EdgeInsets.zero,
//             title: Text('Visitors Permissions'),
//           ),
//           GateSettingListTile(
//             switchValue: _visitorsIn,
//             onChanged: (value) {
//               setState(() {
//                 _visitorsIn = value;
//               });
//             },
//             title: 'Visitors In',
//             subtitle: 'Enable/Disable Gate 1',
//             leadingIcon: Ionicons.person_outline,
//           ),
//           GateSettingListTile(
//             switchValue: _visitorsOut,
//             onChanged: (value) {
//               setState(() {
//                 _visitorsOut = value;
//               });
//             },
//             title: 'Visitor Out',
//             subtitle: 'Enable/Disable Gate 1',
//             leadingIcon: Ionicons.person_outline,
//           ),
//           ListTile(
//             contentPadding: EdgeInsets.zero,
//             title: Text('Vehicle Permissions'),
//           ),
//           GateSettingListTile(
//             switchValue: _vehicleIn,
//             onChanged: (value) {
//               setState(() {
//                 _vehicleIn = value;
//               });
//             },
//             title: 'Vehicle In',
//             subtitle: 'Enable/Disable Gate 1',
//             leadingIcon: Ionicons.car_outline,
//           ),
//           GateSettingListTile(
//             switchValue: _vehicleOut,
//             onChanged: (value) {
//               setState(() {
//                 _vehicleOut = value;
//               });
//             },
//             title: 'Vehicle Out',
//             subtitle: 'Enable/Disable Gate 1',
//             leadingIcon: Ionicons.car_outline,
//           ),
//         ],
//       ),
//       floatingActionButton: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: CustomLargeBtn(
//           text: 'CONFIRM',
//           onPressed: () {
//             Navigator.push(
//               context,
//               PageTransition(
//                 type: PageTransitionType.bottomToTop,
//                 child: AdminDashboardView(),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// class GateSettingListTile extends StatelessWidget {
//   const GateSettingListTile({
//     Key? key,
//     required this.switchValue,
//     required this.onChanged,
//     required this.title,
//     required this.subtitle,
//     this.leadingIcon,
//   }) : super(key: key);

//   final bool switchValue;
//   final ValueChanged<bool> onChanged;
//   final String title;
//   final String subtitle;
//   final IconData? leadingIcon;

//   @override
//   Widget build(BuildContext context) {
//     return ListTile(
//       contentPadding: EdgeInsets.zero,
//       leading: leadingIcon != null
//           ? CircleAvatar(
//               // backgroundColor: Color(0X101973E9),
//               backgroundColor: Color(0xffFFEBE6),
//               radius: 22,
//               child: Icon(
//                 size: 24,
//                 leadingIcon,
//                 // color: Color(0XFF1973E9),
//                 color: Colors.black,
//               ),
//             )
//           : null,
//       title: Text(title),
//       subtitle: Text(subtitle),
//       trailing: Switch(
//         value: switchValue,
//         onChanged: onChanged,
//       ),
//     );
//   }
// }
