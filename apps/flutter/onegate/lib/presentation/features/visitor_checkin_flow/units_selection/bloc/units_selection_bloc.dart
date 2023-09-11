import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'units_selection_event.dart';
part 'units_selection_state.dart';

class UnitsSelectionBloc extends Bloc<UnitsSelectionEvent, UnitsSelectionState> {
  UnitsSelectionBloc() : super(UnitsSelectionInitial()) {
    on<UnitsSelectionEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}
