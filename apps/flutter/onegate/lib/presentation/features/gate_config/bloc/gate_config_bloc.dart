import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'gate_config_event.dart';
part 'gate_config_state.dart';

class GateConfigBloc extends Bloc<GateConfigEvent, GateConfigState> {
  GateConfigBloc() : super(GateConfigInitial()) {
    on<GateConfigEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}
