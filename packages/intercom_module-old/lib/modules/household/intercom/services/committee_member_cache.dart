import 'dart:developer';
import '../models/intercom_contact.dart';

/// Cache entry for a single committee's members
class _CommitteeMemberCacheEntry {
  final List<IntercomContact> members;
  final DateTime timestamp;
  final int companyId;

  _CommitteeMemberCacheEntry({
    required this.members,
    required this.timestamp,
    required this.companyId,
  });

  bool isValid(int? currentCompanyId, {Duration? expiry}) {
    if (companyId != currentCompanyId) return false;
    final now = DateTime.now();
    final cacheExpiry =
        expiry ?? const Duration(minutes: 10); // Default 10 minutes
    return now.difference(timestamp) < cacheExpiry;
  }
}

/// Per-committee member cache with TTL
///
/// This cache stores members for each committee separately, allowing:
/// - Progressive loading (show committees immediately, load members per committee)
/// - Selective refresh (only refresh expired committees)
/// - Reduced API calls (reuse cached data for 10 minutes)
class CommitteeMemberCache {
  static final CommitteeMemberCache _instance =
      CommitteeMemberCache._internal();
  factory CommitteeMemberCache() => _instance;
  CommitteeMemberCache._internal();

  // Cache: committeeId -> cache entry
  final Map<String, _CommitteeMemberCacheEntry> _cache = {};

  // Track in-flight requests to prevent duplicate calls
  final Set<String> _inFlightRequests = {};

  /// Get cached members for a committee
  List<IntercomContact>? getCachedMembers(String committeeId, int? companyId) {
    final entry = _cache[committeeId];
    if (entry == null) {
      log('📦 [CommitteeMemberCache] Cache miss for committee $committeeId');
      return null;
    }

    if (!entry.isValid(companyId)) {
      log('📦 [CommitteeMemberCache] Cache expired for committee $committeeId');
      _cache.remove(committeeId);
      return null;
    }

    final age = DateTime.now().difference(entry.timestamp);
    log('✅ [CommitteeMemberCache] Cache hit for committee $committeeId (age: ${age.inSeconds}s)');
    return List.from(entry.members); // Return copy
  }

  /// Store members for a committee
  void cacheMembers(
      String committeeId, List<IntercomContact> members, int companyId) {
    _cache[committeeId] = _CommitteeMemberCacheEntry(
      members: List.from(members), // Store copy
      timestamp: DateTime.now(),
      companyId: companyId,
    );
    log('💾 [CommitteeMemberCache] Cached ${members.length} members for committee $committeeId');
  }

  /// Check if a request is in-flight for a committee
  bool isRequestInFlight(String committeeId) {
    return _inFlightRequests.contains(committeeId);
  }

  /// Mark request as in-flight
  void markRequestInFlight(String committeeId) {
    _inFlightRequests.add(committeeId);
    log('🔄 [CommitteeMemberCache] Marked request in-flight for committee $committeeId');
  }

  /// Mark request as completed
  void markRequestComplete(String committeeId) {
    _inFlightRequests.remove(committeeId);
    log('✅ [CommitteeMemberCache] Marked request complete for committee $committeeId');
  }

  /// Clear cache for a specific company (on company change)
  void clearForCompany(int companyId) {
    _cache.removeWhere((key, entry) => entry.companyId == companyId);
    log('🗑️ [CommitteeMemberCache] Cleared cache for company $companyId');
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
    _inFlightRequests.clear();
    log('🗑️ [CommitteeMemberCache] Cleared all cache');
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'cachedCommittees': _cache.length,
      'inFlightRequests': _inFlightRequests.length,
    };
  }
}
