// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:developer';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:badges/badges.dart' as badges;
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/dashboard/commons/ui/dashboard_commons.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/missed_approval/missed_approval_screen.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_settings.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/ui/visitor_log_view.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app_intro/ui/keyclock_login.dart';
import '../../../settings/pages/settings_home.dart';
import 'id_input_view.dart';
import 'package:intl/intl.dart';

class GateDashboardView extends StatefulWidget {
  const GateDashboardView({super.key});

  @override
  State<GateDashboardView> createState() => _GateDashboardViewState();
}

// late FocusNode _focusNode;
// final mobileControllerFormKey = GlobalKey<FormState>();
// final passcodeControllerFormKey = GlobalKey<FormState>();
// TextEditingController mobileController = TextEditingController();
// TextEditingController passcodeController = TextEditingController();
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
  List<VisitorLog> cardVisitors = [];
  bool isLoading = false;
  final remoteDataSource = RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  );

  final gateDashboardBloc = GatekeeperDashboardBloc(
      VisitorUsecase(
        VisitorRepoImpl(
          RemoteDataSource(DioSingleton.instance1, DioSingleton.instance2,
              DioSingleton.instance3),
        ),
      ),
      VisitorLogUsecase(
        VisitorLogRepositoryImpl(
          RemoteDataSource(DioSingleton.instance1, DioSingleton.instance2,
              DioSingleton.instance3),
        ),
      ));

  @override
  void initState() {
    // startKioskMode();
    super.initState();
    // _focusNode = FocusNode();
    // Future.delayed(Duration(milliseconds: 200), () {
    //   FocusScope.of(context).requestFocus(_focusNode);
    // });
    gateDashboardBloc.add(GatekeeperDashboardInitialEvent());
    _fetchCardNumbers();
  }

  Future<void> _fetchCardNumbers() async {
    setState(() {
      isLoading = true;
    });
    final visitorLogs = await remoteDataSource.fetchCardNumbers();
    setState(() {
      cardVisitors = visitorLogs ?? [];
      isLoading = false;
    });
  }

  @override
  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all stored preferences

    log("User logged out. Navigating to login screen.");

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MyAppLogin()),
    );
  }

  @override
  void dispose() {
    // _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GatekeeperDashboardBloc, GatekeeperDashboardState>(
      bloc: gateDashboardBloc,
      listenWhen: (previous, current) =>
          current is GatekeeperDashboardActionState,
      buildWhen: (previous, current) =>
          current is! GatekeeperDashboardActionState,
      listener: (context, state) {
        switch (state.runtimeType) {
          case GDInAndOutButtonPressedState:
            log('In and Out button pressed');
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (context) => VisitorLogView(
            //       id: 'In Out Book',
            //       logList: const [
            //         "In Out Book",
            //         "Visitor In",
            //         "Visitor Out",
            //       ],
            //     ),
            //   ),
            // );
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.leftToRight,
                child: VisitorLogView(
                  id: 'In Out Book',
                  logList: const [
                    "In Out Book",
                    "Visitor In",
                    "Visitor Out",
                  ],
                ),
              ),
            );
            break;
          case GDVisitorsInButtonPressedState:
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.topToBottom,
                child: VisitorLogView(
                  id: 'Visitor In',
                  logList: const [
                    "In Out Book",
                    "Visitor In",
                    "Visitor Out",
                  ],
                ),
              ),
            );
            break;
          case GDVisitorsOutButtonPressedState:
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: VisitorLogView(
                  id: 'Visitor Out',
                  logList: const [
                    "In Out Book",
                    "Visitor In",
                    "Visitor Out",
                  ],
                ),
              ),
            );
            break;
        }
      },
      builder: (context, state) {
        switch (state.runtimeType) {
          case GatekeeperDashboardLoadingState:
            return LoaderView();
          case GatekeeperDashboardSuccessState:
            final successState = state as GatekeeperDashboardSuccessState;
            return WillPopScope(
              onWillPop: () async {
                return false;
              },
              child: MyScrollView(
                hasBackButton: false,
                pageTitleWidget: Hero(
                    tag: 'gate_dashboard',
                    child: Text(
                      'Gate One',
                      style: Theme.of(context).textTheme.bodyLarge,
                    )),
                actions: [
                  //       IconButton(
                  //         onPressed: () {
                  // Navigator.push(context, MaterialPageRoute(builder: (context)=> MissedApprovalsScreen()));
                  //         },
                  //         icon: Icon(
                  //           Symbols.phone_missed_rounded,
                  //           color: Theme.of(context).colorScheme.onBackground,
                  //         ),
                  //       ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.rightToLeft,
                          child: SettingsHome(),

                          // VisitorSettingsView(),
                        ),
                      );
                    },
                    icon: Icon(
                      Symbols.settings_rounded,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Row(
                                children: const [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Colors.red),
                                  SizedBox(width: 8),
                                  Text(
                                    'Confirm Logout',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Are you sure you want to logout?',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'This action cannot be undone.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    elevation: 0,
                                    side: BorderSide(color: Colors.grey[300]!),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    logout(context);
                                  },
                                  child: Text(
                                    'Logout',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                              actionsPadding: EdgeInsets.all(16),
                              actionsAlignment: MainAxisAlignment.end,
                            );
                          },
                        );
                      },
                      icon: Icon(
                        Icons.logout,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                      label: Text(
                        'Logout',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )),
                ],
                pageBody: Column(
                  children: [
                    Container(
                      margin: EdgeInsets.only(
                        top: 0,
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
                                msg: "Intercom, coming soon",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.CENTER,
                                timeInSecForIosWeb: 1,
                                backgroundColor: Colors.black,
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
                            onTap: () {
                              Fluttertoast.showToast(
                                msg: "Parcel, coming soon",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.CENTER,
                                timeInSecForIosWeb: 1,
                                backgroundColor: Colors.black,
                                textColor: Colors.white,
                                fontSize: 16.0,
                              );
                            },
                          ),
                          DashboardShortcut(
                            isPremium: false,
                            isVisible: false,
                            icon: Symbols.qr_code_scanner_rounded,
                            title: 'Scan',
                            onTap: () {
                              Fluttertoast.showToast(
                                msg: "Scan qr, coming soon",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.CENTER,
                                timeInSecForIosWeb: 1,
                                backgroundColor: Colors.black,
                                textColor: Colors.white,
                                fontSize: 16.0,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    DashboardBlocks(
                        inBook: successState.inBook,
                        outBook: successState.outBook,
                        bloc: gateDashboardBloc),


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
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.only(top: 5, bottom: 8),
                              height: 60,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.background,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                              child: ListTile(
                                title: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: DefaultTextStyle(
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 18,
                                    ),
                                    child: AnimatedTextKit(
                                      repeatForever: true,
                                      animatedTexts: [
                                        TyperAnimatedText(
                                          '9912345678',
                                        ),
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
                            ),
                          ],
                        ),
                      ),
                    ),
                    // buildExpansionTile(context, cardVisitors, isLoading)
                  ],
                ),
              ),
            );
          default:
            return Container();
        }
      },
    );
  }

  Widget buildExpansionTile(
      BuildContext context, List<VisitorLog> cardVisitors, bool isLoading) {
    return ExpansionTile(
      title: Text(
        'Visitors with Card Numbers',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: Text(
        'Tap to view details',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      children: [
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (cardVisitors.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No visitors with card numbers found.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cardVisitors.length,
            itemBuilder: (context, index) {
              final visitor = cardVisitors[index];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFF5F7F8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    splashColor: const Color(0xFFDCEDF5),
                    onTap: () {
                      // Handle tap event
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Visitor: ${visitor.visitor?.name ?? "Unknown"}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Colors.black,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                if (visitor.visitor_card_number == null)
                                  SizedBox(
                                    height: 2,
                                    width: 100,
                                    child: LinearProgressIndicator(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      backgroundColor:
                                          Theme.of(context).colorScheme.surface,
                                    ),
                                  )
                                else
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Card: ',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w400,
                                              ),
                                        ),
                                        TextSpan(
                                          text: visitor.visitor_card_number,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              // Perform the checkout
                              try {
                                final response = await context
                                    .read<GatekeeperDashboardBloc>()
                                    .visitorLogUsecase
                                    .checkOut(visitor);

                                if (response) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Visitor checked out successfully!',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  context
                                      .read<GatekeeperDashboardBloc>()
                                      .add(GatekeeperDashboardInitialEvent());
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to check out visitor.',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error: $e',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: Text(
                              'Checkout',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

Route _createRoute() {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => IdInputView(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.ease;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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

class DashboardShortcut extends StatelessWidget {
  const DashboardShortcut({
    required this.title,
    required this.icon,
    required this.onTap,
    required this.isPremium,
    required this.isVisible,
    super.key,
  });

  final String title;
  final IconData icon;
  final Function onTap;
  final bool isPremium;
  final bool isVisible;

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
              margin: EdgeInsets.only(bottom: 5),
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
                            color: Theme.of(context).colorScheme.onBackground,
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
                            color: Theme.of(context).colorScheme.onBackground,
                            size: 24,
                          ),
                        )
                  : Icon(
                      icon,
                      color: Theme.of(context).colorScheme.onBackground,
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
