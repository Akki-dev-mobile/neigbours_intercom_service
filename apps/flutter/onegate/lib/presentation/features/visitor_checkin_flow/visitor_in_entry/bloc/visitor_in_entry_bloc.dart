import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'visitor_in_entry_event.dart';
part 'visitor_in_entry_state.dart';

class VisitorInEntryBloc extends Bloc<VisitorInEntryEvent, VisitorInEntryState> {
  VisitorInEntryBloc() : super(VisitorInEntryInitial()) {
    on<VisitorInEntryEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}
