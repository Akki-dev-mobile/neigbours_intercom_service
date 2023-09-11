import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'app_intro_event.dart';
part 'app_intro_state.dart';

class AppIntroBloc extends Bloc<AppIntroEvent, AppIntroState> {
  AppIntroBloc() : super(AppIntroInitial()) {
    on<AppIntroEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}
