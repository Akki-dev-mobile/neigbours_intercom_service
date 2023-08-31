// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:badges/badges.dart' as badges;
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:math' as math;
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';

import '../../admin/pages/admin_dashboard_view.dart';

class GateDashboardView extends StatefulWidget {
  const GateDashboardView({super.key});

  @override
  State<GateDashboardView> createState() => _GateDashboardViewState();
}

class _GateDashboardViewState extends State<GateDashboardView> {
  @override
  void initState() {
    super.initState();
    if (!mobileController.text.isEmpty) {
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }
    _focusNode = FocusNode();
    Future.delayed(Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  late FocusNode _focusNode;
  final RegExp _numericRegExp = RegExp(r'[0-9]');
  final mobileControllerFormKey = GlobalKey<FormState>();
  final passcodeControllerFormKey = GlobalKey<FormState>();
  TextEditingController mobileController = TextEditingController();
  TextEditingController passcodeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemChannels.textInput.invokeMethod('TextInput.show');
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        extendBody: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        body: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: Container(
                margin: EdgeInsets.only(top: 0),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(
                      'https://3.imimg.com/data3/LL/IT/MY-10283605/apartment-security-service-500x500.jpg',
                    ),
                  ),
                  title: Text(
                    'onegate',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    'Gate 2',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  trailing: SizedBox(
                    width: 150,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: Icon(
                            Symbols.alarm_rounded,
                            color: Colors.black,
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: Icon(
                            Symbols.phone_missed_rounded,
                            color: Colors.black,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminDashboardView(),
                              ),
                            );
                          },
                          icon: Icon(
                            Symbols.settings_rounded,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              pinned: true,
              expandedHeight: 80,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        Color(0xffFFEBE6),
                        Colors.white,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  DashboardShortcut(
                    icon: Symbols.deskphone_rounded,
                    title: 'Intercom',
                    onTap: () {
                      Fluttertoast.showToast(
                        msg: "will be redirecting to crm payment page",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.CENTER,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.red,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    },
                    isPremium: true,
                    isVisible: true,
                  ),
                  DashboardShortcut(
                    icon: Symbols.package_rounded,
                    title: 'Parcel',
                    isPremium: false,
                    isVisible: true,
                    onTap: () {},
                  ),
                  DashboardShortcut(
                    isPremium: false,
                    isVisible: false,
                    icon: Symbols.qr_code_scanner_rounded,
                    title: 'Scan',
                    onTap: () {},
                  ),
                  DashboardShortcut(
                    isPremium: false,
                    isVisible: false,
                    icon: Symbols.import_contacts_rounded,
                    title: 'Log',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GateKeeperDashboardCard(
                    title: 'Visitor In',
                    subtitle: '47',
                    image:
                        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_in_01b37e79e9.gif?updated_at=2023-08-23T06:26:37.878Z',
                    transformAngle: math.pi,
                    color: Color(0xffCAF1D1),
                    onTap: () {},
                  ),
                  GateKeeperDashboardCard(
                    title: 'Visitor Out',
                    subtitle: '43',
                    image:
                        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_out_c9f84ddb97.gif?updated_at=2023-08-23T06:26:37.786Z',
                    transformAngle: 0,
                    color: Color(0xffFFE5E0),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: CustomForm.textField(
                  focusNode: _focusNode,
                  textController: mobileController,
                  "Visitor Mobile Number",
                  hintText: '0123456789',
                  isNumber: true,
                  length: 10,
                  suffixIcon: IconButton(
                    onPressed: () {
                      if (mobileControllerFormKey.currentState!.validate()) {
                        print('okkkkkkkkkkkkkkkk');
                      }
                    },
                    icon: Icon(
                      Symbols.done_rounded,
                      color: Colors.black,
                    ),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Mobile number is required';
                    } else if (value.length != 10) {
                      return 'Please enter a 10-digit number';
                    }
                    return null;
                  },
                  focusedColor: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardShortcut extends StatelessWidget {
  const DashboardShortcut({
    required this.title,
    required this.icon,
    required this.onTap,
    required this.isPremium,
    required this.isVisible,
    this.value,
    super.key,
  });
  final String title;
  final IconData icon;
  final Function onTap;
  final bool isPremium;
  final bool isVisible;
  final Int? value;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 15,
        ),
        width: MediaQuery.of(context).size.width * 0.2,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: isVisible
                  ? isPremium
                      ? badges.Badge(
                          badgeStyle: badges.BadgeStyle(
                            shape: badges.BadgeShape.square,
                            borderRadius: BorderRadius.circular(5),
                            padding: EdgeInsets.all(2),
                            badgeGradient: badges.BadgeGradient.linear(
                              colors: [
                                Colors.purple,
                                Colors.blue,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          position:
                              badges.BadgePosition.topEnd(top: -20, end: -20),
                          badgeContent: Text(
                            'PRO',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                          child: Icon(
                            icon,
                            color: Colors.black,
                            size: 24,
                          ),
                        )
                      : badges.Badge(
                          position:
                              badges.BadgePosition.topEnd(top: -13, end: -15),
                          badgeContent: CircleAvatar(
                            radius: 2,
                            backgroundColor: Colors.red,
                          ),
                          child: Icon(
                            icon,
                            color: Colors.black,
                            size: 24,
                          ),
                        )
                  : Icon(
                      icon,
                      color: Colors.black,
                      size: 24,
                    ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class GateKeeperDashboardCard extends StatelessWidget {
  const GateKeeperDashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.onTap,
    this.transformAngle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String image;
  final VoidCallback onTap;
  final double? transformAngle;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Container(
        padding: EdgeInsets.all(10),
        height: MediaQuery.of(context).size.height * 0.12,
        width: MediaQuery.of(context).size.width * 0.45,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.max,
          children: [
            RichText(
              text: TextSpan(
                children: <TextSpan>[
                  TextSpan(
                    text: '27\n',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextSpan(
                    text: title,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            Transform(
              transform: Matrix4.rotationY(transformAngle ?? 0),
              alignment: Alignment.center,
              child: Image(
                height: 45,
                width: 45,
                fit: BoxFit.contain,
                image: NetworkImage(
                  image,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
