import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'gatekeeper_dashboard_event.dart';
part 'gatekeeper_dashboard_state.dart';

class GatekeeperDashboardBloc extends Bloc<GatekeeperDashboardEvent, GatekeeperDashboardState> {
  GatekeeperDashboardBloc() : super(GatekeeperDashboardInitial()) {
    on<GatekeeperDashboardEvent>((event, emit) {
      
    });
  }
}
