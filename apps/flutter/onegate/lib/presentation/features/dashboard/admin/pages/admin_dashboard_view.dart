// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:ffi';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/admin_dash_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/use_cases/admin_dash_usecase.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/bloc/admin_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/settings_home.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:badges/badges.dart' as badges;

import 'dart:math' as math;

import '../../../visitor_log/ui/visitor_log_view.dart';
import '../../gatekeeper/pages/gatekeeper_dashboard_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView>
    with TickerProviderStateMixin {
  final AdminDashboardBloc adminDashboardBloc = AdminDashboardBloc(
    AdminDashboardUseCase(
      AdminDashboardRepositoryImpl(
        RemoteDataSource(DioSingleton.instance1,DioSingleton.instance2),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminDashboardBloc, AdminDashboardState>(
      bloc: adminDashboardBloc,
      listenWhen: (previous, current) => current is AdminDashboardActionState,
      buildWhen: (previous, current) => current is! AdminDashboardActionState,
      listener: (context, state) {
        switch (state.runtimeType) {
          case NavigateToSettingsState:
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: SettingsHome(),
              ),
            );
            break;
        }
      },
      builder: (context, state) {
        switch (state.runtimeType) {
          default:
            return WillPopScope(
              onWillPop: () async {
                return false;
              },
              child: MyScrollView(
                hasBackButton: false,
                pageTitle: 'onegate',
                actions: [
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Symbols.notifications,
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
                      Symbols.settings,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                ],
                pageBody: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        DashboardShortcut(
                          icon: Symbols.looks_one_rounded,
                          title: 'onesociety',
                          onTap: () {},
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
                          icon: Symbols.badge_rounded,
                          title: 'Staff',
                          onTap: () {},
                        ),
                      ],
                    ),
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      height: MediaQuery.of(context).size.height * 0.300,
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageTransition(
                                  type: PageTransitionType.rightToLeft,
                                  child: VisitorLogView(
                                      id: 'In Out Book',
                                      logList: [
                                        "In Out Book",
                                        "Visitor In",
                                        "Visitor Out",
                                      ]),
                                ),
                              );
                            },
                            child: Container(
                              // margin: EdgeInsets.symmetric(vertical: 10),
                              width: MediaQuery.of(context).size.width * 0.32,
                              decoration: BoxDecoration(
                                color: Color(
                                  0xffF2D8A5,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(2),
                                    margin: EdgeInsets.only(top: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: CachedNetworkImage(
                                      maxHeightDiskCache: 10,
                                      height: 55,
                                      width: 55,
                                      fit: BoxFit.contain,
                                      imageUrl:
                                          'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_book_31e76df597.gif?updated_at=2023-08-23T06:26:37.400Z',
                                      placeholder: (context, url) =>
                                          const CircularProgressIndicator(),
                                      errorWidget: (context, url, error) =>
                                          const Icon(
                                        Icons.error,
                                        color: Colors.red,
                                      ),
                                      fadeOutDuration:
                                          const Duration(seconds: 1),
                                      fadeInDuration:
                                          const Duration(seconds: 3),
                                    ),
                                  ),
                                  Text(
                                    'In-Out',
                                    // (parcelCount).toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium,
                                  ),
                                  Text(
                                    'Book',
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: MediaQuery.of(context).size.width * 0.50,
                                height:
                                    MediaQuery.of(context).size.height * 0.14,
                                decoration: BoxDecoration(
                                  color: Color(0xffCAF1D1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: ListTile(
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 20,
                                    ),
                                    title: Text(
                                      '74',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium,
                                    ),
                                    subtitle: Text(
                                      'Visitor\nIn',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium,
                                    ),
                                    trailing: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Transform(
                                        transform: Matrix4.rotationY(math.pi),
                                        alignment: Alignment.center,
                                        child: CachedNetworkImage(
                                          maxHeightDiskCache: 10,
                                          height: 50,
                                          width: 50,
                                          fit: BoxFit.contain,
                                          imageUrl:
                                              'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_in_01b37e79e9.gif?updated_at=2023-08-23T06:26:37.878Z',
                                          placeholder: (context, url) =>
                                              const CircularProgressIndicator(),
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                            Icons.error,
                                            color: Colors.red,
                                          ),
                                          fadeOutDuration:
                                              const Duration(seconds: 1),
                                          fadeInDuration:
                                              const Duration(seconds: 3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: MediaQuery.of(context).size.width * 0.50,
                                height:
                                    MediaQuery.of(context).size.height * 0.14,
                                decoration: BoxDecoration(
                                  color: Color(0xffFFE5E0),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: ListTile(
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 20,
                                    ),
                                    title: Text(
                                      '38',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium,
                                    ),
                                    subtitle: Text(
                                      'Visitor\nOut',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium,
                                    ),
                                    trailing: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: CachedNetworkImage(
                                        maxHeightDiskCache: 10,
                                        height: 50,
                                        width: 50,
                                        fit: BoxFit.contain,
                                        imageUrl:
                                            'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_out_c9f84ddb97.gif?updated_at=2023-08-23T06:26:37.786Z',
                                        placeholder: (context, url) =>
                                            const CircularProgressIndicator(),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                          Icons.error,
                                          color: Colors.red,
                                        ),
                                        fadeOutDuration:
                                            const Duration(seconds: 1),
                                        fadeInDuration:
                                            const Duration(seconds: 3),
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
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}
