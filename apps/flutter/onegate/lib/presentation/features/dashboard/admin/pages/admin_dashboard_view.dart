// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:ffi';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:badges/badges.dart' as badges;

import 'dart:math' as math;

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
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
                    'Admin',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  trailing: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Fluttertoast.showToast(
                        msg: "Test Switch to Gatekeeper Dashboard",
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
                      colors: [
                        Theme.of(context).colorScheme.surfaceVariant,
                        Theme.of(context).colorScheme.background,
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
                  AdminDashboardShortcut(
                    icon: Symbols.looks_one_rounded,
                    title: 'onesociety',
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
                  AdminDashboardShortcut(
                    icon: Symbols.package_rounded,
                    title: 'Parcel',
                    isPremium: false,
                    isVisible: true,
                    onTap: () {},
                  ),
                  AdminDashboardShortcut(
                    isPremium: false,
                    isVisible: false,
                    icon: Symbols.badge_rounded,
                    title: 'Staff',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  margin: EdgeInsets.only(top: 16, bottom: 16),
                  height: MediaQuery.of(context).size.height * 0.27,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width * 0.3,
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
                                image: NetworkImage(
                                  "https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_book_31e76df597.gif?updated_at=2023-08-23T06:26:37.400Z",
                                ),
                              ),
                            ),
                            Text(
                              'In-Out',
                              style: Theme.of(context).textTheme.bodyMedium,
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
                          GestureDetector(
                            onTap: () {},
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.13,
                              width: MediaQuery.of(context).size.width * 0.6,
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
                                  style:
                                      Theme.of(context).textTheme.displayMedium,
                                ),
                                subtitle: Text(
                                  'Visitor In',
                                  style: Theme.of(context).textTheme.bodyMedium,
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
                                      image: NetworkImage(
                                        "https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_in_01b37e79e9.gif?updated_at=2023-08-23T06:26:37.878Z",
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            height: MediaQuery.of(context).size.height * 0.13,
                            width: MediaQuery.of(context).size.width * 0.6,
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
                                style:
                                    Theme.of(context).textTheme.displayMedium,
                              ),
                              subtitle: Text(
                                'Visitor Out',
                                style: Theme.of(context).textTheme.bodyMedium,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDashboardShortcut extends StatelessWidget {
  const AdminDashboardShortcut({
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
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    fontSize: 14,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
