import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'gate_selection_event.dart';
part 'gate_selection_state.dart';

class GateSelectionBloc extends Bloc<GateSelectionEvent, GateSelectionState> {
  GateSelectionBloc() : super(GateSelectionInitial()) {
    on<GateSelectionEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}
