import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'visitor_log_event.dart';
part 'visitor_log_state.dart';

class VisitorLogBloc extends Bloc<VisitorLogEvent, VisitorLogState> {
  VisitorLogBloc() : super(VisitorLogInitial()) {
    on<VisitorLogEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}
