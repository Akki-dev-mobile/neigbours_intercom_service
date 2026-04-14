import 'package:neigbours_intercom_service/core/contracts/neighbour_role.dart';

/// Returns whether [current] is allowed given an optional [allowed] set.
///
/// If [allowed] is null or empty, all roles are allowed (same as monorepo stubs).
bool isNeighbourRoleAllowed(
  NeighbourRole? current,
  Set<NeighbourRole>? allowed,
) {
  if (allowed == null || allowed.isEmpty) return true;
  if (current == null) return false;
  return allowed.contains(current);
}
