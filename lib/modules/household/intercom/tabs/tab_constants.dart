/// Shared constants for Neighbour Screen tabs
///
/// Centralizes timing, debounce, pagination, and cache configuration
/// to ensure consistency across Groups, Residents, and Committee tabs.
class TabConstants {
  TabConstants._(); // Private constructor to prevent instantiation

  // ============================================================================
  // Tab Activation Timing
  // ============================================================================

  /// Standard delay before triggering initial tab load
  /// Used to ensure widget is fully initialized before data fetching
  static const Duration kTabActivationDelay = Duration(milliseconds: 200);

  /// Delay for tab activation check when tab is already active on init
  /// Slightly longer to ensure all initialization is complete
  static const Duration kTabActiveInitDelay = Duration(milliseconds: 300);

  // ============================================================================
  // Data Refresh Debouncing
  // ============================================================================

  /// Minimum time between automatic tab-triggered data reloads
  /// Prevents excessive API calls when switching tabs rapidly
  /// Current behavior: 3 seconds (preserved from existing implementation)
  static const Duration kTabReloadDebounce = Duration(seconds: 3);

  // ============================================================================
  // Cache Configuration
  // ============================================================================

  /// Cache expiry duration for tab data
  /// Data is considered fresh if loaded within this duration
  /// Matches GroupsTab cache pattern (5 minutes)
  static const Duration kDataCacheExpiry = Duration(minutes: 5);

  /// Room info cache expiry (GroupsTab specific)
  /// Kept separate as it has different refresh requirements
  static const Duration kRoomInfoCacheExpiry = Duration(minutes: 5);

  // ============================================================================
  // Pagination Limits
  // ============================================================================

  /// Maximum members to fetch per page for residents
  /// Current effective limit: 1000 (preserved for backward compatibility)
  /// Note: Backend may return more, but we process up to this limit
  static const int kResidentsPerPage = 1000;

  /// Maximum committees to fetch per page
  /// Current effective limit: 20 (preserved for backward compatibility)
  static const int kCommitteesPerPage = 20;

  /// Maximum committee members to fetch per committee
  /// Current effective limit: 20 (preserved for backward compatibility)
  static const int kCommitteeMembersPerPage = 20;

  /// Maximum buildings to fetch per page
  /// Used for building filter chips in ResidentsTab
  static const int kBuildingsPerPage = 100;

  // ============================================================================
  // API Request Delays
  // ============================================================================

  /// Delay before executing data load after tab becomes active
  /// Ensures widget is fully built before API calls
  static const Duration kDataLoadDelay = Duration(milliseconds: 200);

  /// Delay for company change detection reload
  /// Slightly longer to avoid conflicts during navigation
  static const Duration kCompanyChangeReloadDelay = Duration(milliseconds: 300);
}
