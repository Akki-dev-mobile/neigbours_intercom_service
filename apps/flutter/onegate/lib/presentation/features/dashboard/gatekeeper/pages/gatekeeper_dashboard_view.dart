// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/intercom.dart';
import 'package:flutter_onegate/presentation/features/license_plate_detection/ui/license_plate_detection_page.dart';
import 'package:flutter_onegate/presentation/features/self_entry/ui/qr_scanner_self.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_screens/widgets/request_2.dart';
import 'package:vibration/vibration.dart';
import 'dart:math' as math;

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:badges/badges.dart' as badges;
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/dashboard/commons/ui/dashboard_commons.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/missed_approval/missed_approval_screen.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/ui/visitor_log_view.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:flutter_onegate/utils/network_log/dio_provider.dart';
import 'package:flutter_onegate/utils/network_log/ui/network_log_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app_intro/ui/keyclock_login.dart';
import '../../../parcel/ui/parcel_list.dart';
import '../../../settings/pages/settings_home.dart';
import 'id_input_view.dart';

class GateDashboardView extends StatefulWidget {
  const GateDashboardView({Key? key}) : super(key: key);

  @override
  State<GateDashboardView> createState() => _GateDashboardViewState();
}

class _GateDashboardViewState extends State<GateDashboardView>
    with TickerProviderStateMixin {
  List<VisitorLog> cardVisitors = [];
  bool? _visitorCardNumber = false;
  String? selectedGateName;
  bool isLoading = false;
  final RemoteDataSource _remoteDataSource = RemoteDataSource();
  bool hasPendingParcels = false; // ✅ New flag to track new parcels

  final gateDashboardBloc = GatekeeperDashboardBloc(
      VisitorUsecase(
        VisitorRepoImpl(
          RemoteDataSource(),
        ),
      ),
      VisitorLogUsecase(
        VisitorLogRepositoryImpl(
          RemoteDataSource(),
        ),
      ));

  @override
  void initState() {
    super.initState();
    GateStorage().removeComingFrom();
    GateStorage().clearVisitorImage();
    gateDashboardBloc.add(GatekeeperDashboardInitialEvent());
    _loadInitialData();
    getSelectedGate();
    checkForPendingParcels();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadVisitorSettings(),
    ]);
  }

  Future<void> getSelectedGate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedGateName = prefs.getString('selected_gate');
    });
  }

  Future<void> logout(BuildContext context) async {
    try {
      log("Attempting logout...");
      // Logout using AuthService instead of keycloakWrapper
      final authService = GetIt.instance<AuthService>();
      await authService.logout();
      log("Keycloak session ended.");

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      log("Preferences cleared.");

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => MyAppLogin()),
        (route) => false,
      );
    } catch (e, st) {
      log("Logout failed: $e\n$st");
    }
  }

  Future<void> _loadVisitorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _visitorCardNumber = prefs.getBool('visitorCardNumber');
    });
  }

  Future<void> checkForPendingParcels() async {
    try {
      final List parcelList = await _remoteDataSource.fetchParcels();

      // ✅ Check if any parcel has status "pending"
      bool hasPending = parcelList.any((parcel) =>
          parcel['parcel_status'] != null &&
          parcel['parcel_status'].toString().toLowerCase() == 'pending');

      setState(() {
        hasPendingParcels = hasPending; // ✅ Update notification status
      });

      log("🔔 Pending Parcels Status: ${hasPending ? 'YES' : 'NO'}");
    } catch (e) {
      log("❌ Error fetching parcels: $e");
    }
  }

  // Method to make real API requests for network logging
  Future<void> _makeRealApiRequests(BuildContext context) async {
    try {
      // Show a loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Fetching data to generate network logs...')),
        );
      }

      // Make multiple real API requests to generate logs

      // 1. Fetch gates
      await _remoteDataSource.fetchGates();

      // 2. Fetch parcels
      await _remoteDataSource.fetchParcels();

      // 3. Refresh dashboard data
      gateDashboardBloc.add(GatekeeperDashboardInitialEvent());

      // Navigate to the network log screen to show the results
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NetworkLogScreen(),
          ),
        );
      }
    } catch (e) {
      // Show error message if the widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // For backward compatibility with the test API button
  Future<void> _makeTestApiRequest(BuildContext context) async {
    await _makeRealApiRequests(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GatekeeperDashboardBloc, GatekeeperDashboardState>(
      bloc: gateDashboardBloc,
      listenWhen: (previous, current) =>
          current is GatekeeperDashboardActionState,
      buildWhen: (previous, current) =>
          current is! GatekeeperDashboardActionState,
      listener: (context, state) async {
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
            await Navigator.push(
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
            await Navigator.push(
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
            await Navigator.push(
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
                      selectedGateName
                          .toString()
                          .split(' ')
                          .map((word) => word.isNotEmpty
                              ? word[0].toUpperCase() +
                                  word.substring(1).toLowerCase()
                              : '')
                          .join(' '),
                      style: Theme.of(context).textTheme.bodyLarge,
                    )),
                actions: [
                  // Network Log Button (for debugging)
                  if (kDebugMode)
                    IconButton(
                      onPressed: () {
                        // Make real API requests and then show network logs
                        _makeRealApiRequests(context);
                      },
                      icon: const Icon(
                        Icons.bug_report,
                        color: Colors.red,
                      ),
                      tooltip: 'Fetch Data & Show Network Logs',
                    ),

                  IconButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  LicensePlateDetectionPage()));
                    },
                    icon: Icon(
                      Symbols.car_crash,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => MissedApprovalsScreen(
                                    remoteDataSource: _remoteDataSource,
                                  )));
                    },
                    icon: Icon(
                      Symbols.phone_missed_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
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
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => MemberList()));
                            },
                            isPremium: true,
                            isVisible: true,
                          ),
                          DashboardShortcut(
                            icon: Symbols.package_rounded,
                            title: 'Parcel',
                            isPremium: false,
                            isVisible: true,
                            hasNotification: hasPendingParcels,
                            // ✅ New parameter
                            onTap: () async {
                              setState(() => hasPendingParcels =
                                  false); // ✅ Remove badge on tap
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ParcelList(),
                                ),
                              );
                            },
                          ),
                          DashboardShortcut(
                            icon: Symbols.qr_code_scanner_rounded,
                            title: 'Scan',
                            isPremium: false,
                            isVisible: true,
                            onTap: () async {
                              final scannedResult = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => QRScannerScreen(
                                          status: 1,
                                        )),
                              );

                              if (scannedResult != null) {
                                myFluttertoast(
                                  msg: "Scanned QR: $scannedResult",
                                  backgroundColor: Colors.green,
                                );
                              }
                            },
                          ),
                          if (_visitorCardNumber == true)
                            DashboardShortcut(
                              icon: Symbols.badge,
                              title: 'Cards',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageTransition(
                                    type: PageTransitionType.leftToRight,
                                    child: VisitorLogView(
                                      id: 'Cards',
                                      logList: const [
                                        "In Out Book",
                                        "Visitor In",
                                        "Visitor Out",
                                      ],
                                    ),
                                  ),
                                );
                              },
                              isPremium: false,
                              isVisible: false,
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
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.only(top: 5, bottom: 8),
                              height: 60,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
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
                                  myFluttertoast(
                                      msg: "Visitor checked out successfully!");
                                  context
                                      .read<GatekeeperDashboardBloc>()
                                      .add(GatekeeperDashboardInitialEvent());
                                } else {
                                  myFluttertoast(
                                    msg: 'Failed to check out visitor.',
                                    backgroundColor: Colors.red,
                                  );
                                }
                              } catch (e) {
                                myFluttertoast(
                                  msg: 'Error: $e',
                                  backgroundColor: Colors.red,
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
    this.hasNotification = false,
    super.key,
  });

  final String title;
  final IconData icon;
  final Function onTap;
  final bool isPremium;
  final bool isVisible;
  final bool hasNotification;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 15),
        width: MediaQuery.of(context).size.width * 0.2,
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
              child: badges.Badge(
                position: badges.BadgePosition.topEnd(top: -8, end: -8),
                showBadge: hasNotification, // ✅ Show red dot for notifications
                badgeStyle: badges.BadgeStyle(
                  shape: badges.BadgeShape.circle,
                  badgeColor: Colors.red,
                  padding: EdgeInsets.all(5),
                ),
                child: isPremium
                    ? badges.Badge(
                        position:
                            badges.BadgePosition.topEnd(top: -18, end: -18),
                        badgeStyle: badges.BadgeStyle(
                          shape: badges.BadgeShape.square,
                          borderRadius: BorderRadius.circular(5),
                          padding: EdgeInsets.all(2),
                          badgeGradient: badges.BadgeGradient.linear(
                            colors: [Colors.purple, Colors.blue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        badgeContent: Text(
                          'PRO',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                        child: Icon(
                          icon,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 24,
                        ),
                      )
                    : Icon(
                        icon,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 24,
                      ),
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

// Add necessary import
