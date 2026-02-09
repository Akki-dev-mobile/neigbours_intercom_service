import 'package:flutter/foundation.dart';

import 'user_role.dart';

@immutable
class SocietyContext {
  const SocietyContext({
    required this.societyId,
    required this.userId,
    required this.role,
    this.flatId,
  });

  final String societyId;
  final String userId;
  final UserRole role;
  final String? flatId;
}
