import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'admin_dashboard_event.dart';
part 'admin_dashboard_state.dart';

class AdminDashboardBloc extends Bloc<AdminDashboardEvent, AdminDashboardState> {
  AdminDashboardBloc() : super(AdminDashboardInitial()) {
    on<AdminDashboardEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}
