import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserSearchState {
  const UserSearchState();
}

class UserSearchNotifier extends StateNotifier<UserSearchState> {
  UserSearchNotifier() : super(const UserSearchState());

  void clearSearch() {
    state = const UserSearchState();
  }
}

final userSearchProvider =
    StateNotifierProvider<UserSearchNotifier, UserSearchState>(
  (ref) => UserSearchNotifier(),
);

