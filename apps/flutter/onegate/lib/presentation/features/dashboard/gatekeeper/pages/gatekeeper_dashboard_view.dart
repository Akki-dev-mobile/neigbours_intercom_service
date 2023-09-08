// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:ffi';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:badges/badges.dart' as badges;

import 'dart:math' as math;

import 'id_input_view.dart';

class GateDashboardView extends StatefulWidget {
  const GateDashboardView({super.key});

  @override
  State<GateDashboardView> createState() => _GateDashboardViewState();
}

late FocusNode _focusNode;
final mobileControllerFormKey = GlobalKey<FormState>();
final passcodeControllerFormKey = GlobalKey<FormState>();
TextEditingController mobileController = TextEditingController();
TextEditingController passcodeController = TextEditingController();
int _currentIndex = 0;
List<String> _labels = ['Mobile', 'Pass Code'];
String? selectedPassAlpha;

List<String> listPassAlpha = [
  'A',
  'B',
  'C',
];

class _GateDashboardViewState extends State<GateDashboardView>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    Future.delayed(Duration(milliseconds: 200), () {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Theme.of(context).colorScheme.background,
          elevation: 0.2,
          title: Text(
            'Gate Two',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: Icon(
                Symbols.alarm_rounded,
                color: Colors.black,
              ),
            ),
            IconButton(
              onPressed: () {
                Fluttertoast.showToast(
                  msg: "test for different types of scenarios",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.CENTER,
                  timeInSecForIosWeb: 1,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  fontSize: 16.0,
                );
                // showModalBottomSheet(
                //   backgroundColor:
                //       Theme.of(context).colorScheme.background,
                //   context: context,
                //   builder: (context) => ApprovalsView(),
                // );
              },
              icon: Icon(
                Symbols.phone_missed_rounded,
                color: Colors.black,
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.rightToLeft,
                    child: AdminDashboardView(),
                  ),
                );
                Fluttertoast.showToast(
                  msg: "Test Switch to Admin Dashboard",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.CENTER,
                  timeInSecForIosWeb: 1,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  fontSize: 16.0,
                );
              },
              icon: Icon(
                Symbols.settings_rounded,
                color: Colors.black,
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(
                  top: 12,
                  bottom: 12,
                ),
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
                  ],
                ),
              ),
              Container(
                margin: EdgeInsets.only(bottom: 16),
                height: MediaQuery.of(context).size.height * 0.265,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      // margin: EdgeInsets.symmetric(vertical: 10),
                      width: MediaQuery.of(context).size.width * 0.28,
                      decoration: BoxDecoration(
                        color: Color(
                          0xffF2D8A5,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Container(
                            padding: EdgeInsets.all(2),
                            margin: EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Image(
                              height: 45,
                              width: 45,
                              fit: BoxFit.contain,
                              // controller: _outAnimationController,
                              image: NetworkImage(
                                "https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_book_31e76df597.gif?updated_at=2023-08-23T06:26:37.400Z",
                              ),
                            ),
                            // child: IconButton(
                            //   color: Color.fromARGB(255, 182, 143, 64),
                            //   onPressed: () {},
                            //   icon: Icon(
                            //     size: 30,
                            //     Symbols.import_contacts_rounded,
                            //   ),
                            // ),
                          ),
                          Text(
                            'In-Out',
                            // (parcelCount).toString(),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            'Book',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width * 0.55,
                          height: MediaQuery.of(context).size.height * 0.12,
                          decoration: BoxDecoration(
                            color: Color(0xffCAF1D1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 20,
                            ),
                            title: Text(
                              '74',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.displayMedium,
                            ),
                            subtitle: Text(
                              'Visitor In',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Transform(
                                transform: Matrix4.rotationY(math.pi),
                                alignment: Alignment.center,
                                child: Image(
                                  height: 45,
                                  width: 45,
                                  fit: BoxFit.contain,
                                  // controller: _outAnimationController,
                                  image: NetworkImage(
                                    "https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_in_01b37e79e9.gif?updated_at=2023-08-23T06:26:37.878Z",
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.55,
                          height: MediaQuery.of(context).size.height * 0.12,
                          decoration: BoxDecoration(
                            color: Color(0xffFFE5E0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 20,
                            ),
                            title: Text(
                              '38',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.displayMedium,
                            ),
                            subtitle: Text(
                              'Visitor Out',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Image(
                                height: 45,
                                width: 45,
                                fit: BoxFit.contain,
                                image: NetworkImage(
                                  "https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_out_c9f84ddb97.gif?updated_at=2023-08-23T06:26:37.786Z",
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    _createRoute(),
                  );
                },
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 2),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        'Enter Visitor Details',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: 5, bottom: 8),
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        child: ListTile(
                          title: DefaultTextStyle(
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                              fontSize: 18,
                            ),
                            child: AnimatedTextKit(
                              repeatForever: true,
                              animatedTexts: [
                                TyperAnimatedText('9912345678'),
                                TyperAnimatedText('G-39070'),
                              ],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  _createRoute(),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => IdInputView(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        var scaleTween = Tween(begin: 0.8, end: 1.0);
        var scaleAnimation = animation.drive(scaleTween);

        return SlideTransition(
          position: offsetAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
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
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 15),
        width: MediaQuery.of(context).size.width * 0.28,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
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
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
