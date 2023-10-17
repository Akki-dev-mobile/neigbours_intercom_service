// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/auth/pages/login_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/commons/ui/dashboard_commons.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/settings_home.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/ui/visitor_log_view.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:kiosk_mode/kiosk_mode.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:badges/badges.dart' as badges;
import 'package:common_widgets/common_widgets.dart';
import 'package:shimmer/shimmer.dart';
import 'package:common_widgets/loading_view.dart';

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
    _focusNode = FocusNode();
    Future.delayed(Duration(milliseconds: 200), () {
      FocusScope.of(context).requestFocus(_focusNode);
    });
    gateDashboardBloc.add(GatekeeperDashboardInitialEvent());
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
                  IconButton(
                    onPressed: () {
                      Fluttertoast.showToast(
                        msg: "jaate raaho, coming soon",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.CENTER,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.black,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    },
                    icon: Icon(
                      Symbols.alarm_rounded,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Fluttertoast.showToast(
                        msg: "missed approvals, coming soon",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.CENTER,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.black,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    },
                    icon: Icon(
                      Symbols.phone_missed_rounded,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.rightToLeft,
                          child: SettingsHome(),
                        ),
                      );
                    },
                    icon: Icon(
                      Symbols.settings_rounded,
                      color: Theme.of(context).colorScheme.onBackground,
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
