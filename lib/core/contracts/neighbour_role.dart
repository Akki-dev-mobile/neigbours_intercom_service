/// Host-facing role for feature gating (aligned with typical society apps).
///
/// Maps 1:1 with `UserRole` in `onegate_feature_core` when the host uses that package.
enum NeighbourRole {
  resident,
  guard,
  admin,
}
