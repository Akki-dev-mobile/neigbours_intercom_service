// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/admin_dash_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/domain/use_cases/admin_dash_usecase.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/bloc/admin_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/settings_home.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/ui/visitor_log_view.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';

import '../../commons/ui/dashboard_commons.dart';
import '../../commons/intercom_services_launcher.dart';

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
          RemoteDataSource(),
        ),
      ),
      VisitorLogUsecase(VisitorLogRepositoryImpl(RemoteDataSource())));

  @override
  void initState() {
    super.initState();
    adminDashboardBloc.add(AdminDashboardInitialEvent());
  }

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
          case ADInAndOutButtonPressedState:
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
          case ADVisitorsInButtonPressedState:
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
          case ADVisitorsOutButtonPressedState:
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
                    ),
                  );
                },
                icon: Icon(
                  Symbols.settings,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
            pageBody: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          IntercomServicesLauncher.open(context);
                        },
                        icon: const Icon(Icons.miscellaneous_services_rounded),
                        label: const Text('Intercom'),
                      ),
                    ],
                  ),
                ),
                if (state is AdminDashboardSuccessState)
                  DashboardBlocks(
                      inBook: (state).inBook,
                      outBook: (state).outBook,
                      bloc: adminDashboardBloc)
                else
                  const DashboardBlocksSkeleton(),
              ],
            ),
          ),
        );
      },
    );
  }
}
