import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'gatekeeper_dashboard_event.dart';
part 'gatekeeper_dashboard_state.dart';

class GatekeeperDashboardBloc
    extends Bloc<GatekeeperDashboardEvent, GatekeeperDashboardState> {
  GatekeeperDashboardBloc() : super(GatekeeperDashboardInitial()) {
    on<GatekeeperDashboardInitialEvent>(gatekeeperDashboardInitialEvent);
  }

  FutureOr<void> gatekeeperDashboardInitialEvent(
      GatekeeperDashboardInitialEvent event,
      Emitter<GatekeeperDashboardState> emit) {}
}
