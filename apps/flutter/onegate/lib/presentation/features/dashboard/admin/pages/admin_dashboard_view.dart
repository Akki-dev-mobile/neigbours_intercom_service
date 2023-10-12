// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables


import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/admin_dash_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/use_cases/admin_dash_usecase.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/bloc/admin_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/settings_home.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';


import '../../commons/ui/dashboard_commons.dart';
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
        RemoteDataSource(DioSingleton.instance1,DioSingleton.instance2,DioSingleton.instance3),
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
                    DashboardBlocks(),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}
