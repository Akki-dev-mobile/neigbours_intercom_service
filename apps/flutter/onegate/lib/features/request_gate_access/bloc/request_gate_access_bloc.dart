import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'request_gate_access_event.dart';
part 'request_gate_access_state.dart';

class RequestGateAccessBloc
    extends Bloc<RequestGateAccessEvent, RequestGateAccessState> {
  RequestGateAccessBloc() : super(RequestGateAccessInitial()) {
    on<RequestAccessButtonPressedEvent>(requestAccessButtonPressedEvent);
  }

  FutureOr<void> requestAccessButtonPressedEvent(
      RequestAccessButtonPressedEvent event,
      Emitter<RequestGateAccessState> emit) {
    print("requestAccessButtonPressedEvent");
    emit(
      RequestAccessButtonPressedState(),
    );
  }
}
