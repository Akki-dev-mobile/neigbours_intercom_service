import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/enhanced_toast.dart';
import '../../../../core/utils/navigation_helper.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/keycloak_service.dart';
import '../../../../core/storage/storage_service.dart';
import '../models/intercom_contact.dart';
import '../models/group_chat_model.dart';
import '../models/room_model.dart';
import '../models/room_info_model.dart';
import '../models/room_message_model.dart';
import '../services/room_service.dart';
import '../services/chat_service.dart';
import '../services/chat_websocket_service.dart';
import '../services/unread_count_manager.dart';
import '../utils/activity_preview_helper.dart';
import '../../../../core/models/api_response.dart';
import '../group_chat_screen.dart';
import '../widgets/voice_search_screen.dart';
import '../create_group_screen.dart';
import '../pages/create_group_page.dart';
import '../../../../screens/neighbour_screen.dart';
import '../../providers/selected_flat_provider.dart';
import 'tab_constants.dart';

class GroupsTab extends ConsumerStatefulWidget {
  final ValueNotifier<int>? activeTabNotifier;
  final int? tabIndex;
  final ValueNotifier<bool>?
      loadingNotifier; // Notify parent when loading state changes

  const GroupsTab({
    super.key,
    this.activeTabNotifier,
    this.tabIndex,
    this.loadingNotifier,
  });

  // Method to get available contacts - will be accessible from outside
  List<IntercomContact> getAvailableContacts() {
    final state = _key.currentState;
    if (state != null) {
      return state._getMockMembers();
    }
    return [];
  }

  // Method to add a new group - will be accessible from outside
  void addNewGroup(GroupChat newGroup) {
    final state = _key.currentState;
    if (state != null) {
      state._addNewGroup(newGroup);
    }
  }

  // Static method to update a specific group's iconUrl - will be accessible from outside
  static void updateGroupIconUrl(String groupId, String? iconUrl) {
    final state = _key.currentState;
    if (state != null) {
      state._updateGroupIconUrl(groupId, iconUrl);
    }
  }

  // Static method to refresh groups list - will be accessible from outside
  static void refreshGroups() {
    final state = _key.currentState;
    if (state != null) {
      state._loadGroups(force: true);
    }
  }

  // Static flag to track if an image was uploaded - will trigger refresh on return
  static bool _imageUploaded = false;

  // Static method to mark that an image was uploaded
  static void markImageUploaded() {
    _imageUploaded = true;
    debugPrint('✅ [GroupsTab] Image upload marked, will refresh on return');
  }

  // Static flag to track if ANY update happened (photo upload, add member, etc.)
  // This ensures API is called immediately when user returns to groups tab
  static bool _groupUpdated = false;

  // Static method to mark that a group was updated (photo, members, etc.)
  // This will trigger immediate API call when tab becomes active
  static void markGroupUpdated() {
    _groupUpdated = true;
    debugPrint(
        '✅ [GroupsTab] Group update marked, will refresh immediately on return');
  }

  // Static method to remove a group from the list - will be accessible from outside
  static void removeGroup(String groupId) {
    final state = _key.currentState;
    if (state != null) {
      state._removeGroup(groupId);
    }
  }

  // Static method to invalidate groups cache - ensures fresh data after mutations
  static void invalidateGroupsCache() {
    final state = _key.currentState;
    if (state != null) {
      state._invalidateGroupsCache();
      debugPrint(
          '🗑️ [GroupsTab] Cache invalidated - will fetch fresh data on next load');
    }
  }

  // Static method to optimistically increment member count for a group
  static void incrementGroupMemberCount(String groupId, int incrementBy) {
    final state = _key.currentState;
    if (state != null) {
      state._incrementGroupMemberCount(groupId, incrementBy);
    }
  }

  // Static method to optimistically decrement member count for a group
  static void decrementGroupMemberCount(String groupId, int decrementBy) {
    final state = _key.currentState;
    if (state != null) {
      state._decrementGroupMemberCount(groupId, decrementBy);
    }
  }

  // Static method to check if user has left a group - will be accessible from outside
  static bool hasUserLeftGroup(String groupId) {
    final state = _key.currentState;
    if (state != null) {
      return state._hasUserLeftGroup(groupId);
    }
    return false;
  }

  // Static method to mark that user has left a group - will be accessible from outside
  static void markUserLeftGroup(String groupId) {
    final state = _key.currentState;
    if (state != null) {
      state._markUserLeftGroup(groupId);
    }
  }

  // Static method to clear left status when user rejoins a group - will be accessible from outside
  static void clearUserLeftGroup(String groupId) {
    final state = _key.currentState;
    if (state != null) {
      state._clearUserLeftGroup(groupId);
    }
  }

  // Create global key to access state
  static final GlobalKey<_GroupsTabState> _key = GlobalKey<_GroupsTabState>();

  @override
  ConsumerState<GroupsTab> createState() => _GroupsTabState();
}

/// Helper class to cache room info with timestamp
class _CachedRoomInfo {
  final RoomInfo? roomInfo;
  final DateTime timestamp;

  _CachedRoomInfo({
    required this.roomInfo,
    required this.timestamp,
  });
}

/// Cached data for groups with timestamp
class _CachedGroupsData {
  final List<GroupChat> groups;
  final DateTime timestamp;
  final int? companyId;

  _CachedGroupsData({
    required this.groups,
    required this.timestamp,
    required this.companyId,
  });

  bool isValid(int? currentCompanyId) {
    if (companyId != currentCompanyId) return false;
    final now = DateTime.now();
    return now.difference(timestamp) < TabConstants.kDataCacheExpiry;
  }
}

/// Data class for last message information
class _LastMessageData {
  final String? lastMessage;
  final int unreadCount;
  final bool isUnread;
  final DateTime lastMessageTime;

  _LastMessageData({
    this.lastMessage,
    required this.unreadCount,
    required this.isUnread,
    required this.lastMessageTime,
  });
}

class _GroupsTabState extends ConsumerState<GroupsTab> {
  /// List of group chats
  List<GroupChat> _groups = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _currentUserId; // Will be loaded from auth service (UUID)
  int?
      _currentUserNumericId; // Numeric user ID for comparison with created_by_user_id
  final TextEditingController _searchController = TextEditingController();

  // Track which groups the current user has left
  // Key: groupId, Value: true if user has left this group
  final Set<String> _leftGroups = {};
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _searchQuery = '';
  List<GroupChat> _filteredGroups = [];
  final RoomService _roomService = RoomService.instance;
  final ApiService _apiService = ApiService.instance;
  final ChatService _chatService = ChatService.instance;
  final UnreadCountManager _unreadManager = UnreadCountManager.instance;
  bool _isWebSocketConnected = false;
  StreamSubscription<bool>? _wsConnectionSubscription;
  StreamSubscription<WebSocketMessage>? _wsMessageSubscription;

  // Track the company_id used to load current groups
  // This helps detect when society/company changes
  int? _lastLoadedCompanyId;

  // Prevent multiple simultaneous loads
  bool _isLoadingGroups = false;
  bool _hasLoadedOnce = false;
  DateTime? _lastLoadTime;
  int? _lastActiveTabIndex;

  // Single-flight request coalescing: If a load is in progress, return the same Future
  Future<void>? _inFlightLoad;

  // Request throttling: Minimum interval between requests (2-3 seconds)
  static const Duration _minRequestInterval = Duration(seconds: 2);
  DateTime? _lastRequestTime;

  // Cancellable activation timer
  Timer? _activationTimer;

  // Generation tracking for cancellation (increments on each activation)
  int _activationGeneration = 0;

  // CRITICAL FIX: Prevent concurrent company change checks
  // This prevents didChangeDependencies from triggering multiple checks
  bool _isCheckingCompanyChange = false;

  // Cache room info to avoid refetching unnecessarily
  // Key: room_id, Value: RoomInfo with timestamp
  final Map<String, _CachedRoomInfo> _roomInfoCache = {};

  // Track which groups have been opened (same logic as chat history)
  Set<String> _openedGroups = {};
  // Use shared constant for cache expiry
  static Duration get _roomInfoCacheExpiry => TabConstants.kRoomInfoCacheExpiry;

  // Cache for groups data with timestamp
  _CachedGroupsData? _cachedGroupsData;

  /// Clean up expired cache entries
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    _roomInfoCache.removeWhere((roomId, cached) {
      final isExpired = now.difference(cached.timestamp) > _roomInfoCacheExpiry;
      if (isExpired) {
        debugPrint('🗑️ [GroupsTab] Removing expired cache for room: $roomId');
      }
      return isExpired;
    });
  }

  /// Clear room info cache (call when company changes or manual refresh)
  void _clearRoomInfoCache() {
    debugPrint(
        '🗑️ [GroupsTab] Clearing room info cache (${_roomInfoCache.length} entries)');
    _roomInfoCache.clear();
  }

  /// Invalidate cache for a specific room (call when room is updated)
  void _invalidateRoomInfoCache(String roomId) {
    debugPrint('🗑️ [GroupsTab] Invalidating cache for room: $roomId');
    _roomInfoCache.remove(roomId);
  }

  /// Invalidate groups data cache (call after group creation/modification)
  void _invalidateGroupsCache() {
    debugPrint('🗑️ [GroupsTab] Invalidating groups data cache');
    _cachedGroupsData = null;
  }

  /// Optimistically increment member count for a specific group in cached data
  void _incrementGroupMemberCount(String groupId, int incrementBy) {
    // CRITICAL FIX: Update both cached data AND current _groups state
    // This ensures UI updates immediately even if cache check is skipped

    // Update _groups directly for immediate UI update
    final updatedGroupsList = _groups.map((group) {
      if (group.id == groupId) {
        final newMemberCount =
            (group.memberCount ?? group.members.length) + incrementBy;
        debugPrint(
            '⚡ [GroupsTab] Optimistically incremented member count for group ${group.name}: ${group.memberCount ?? group.members.length} → $newMemberCount');
        return group.copyWith(memberCount: newMemberCount);
      }
      return group;
    }).toList();

    // Update cache if available
    if (_cachedGroupsData != null) {
      final updatedGroupsCache = _cachedGroupsData!.groups.map((group) {
        if (group.id == groupId) {
          final newMemberCount =
              (group.memberCount ?? group.members.length) + incrementBy;
          return group.copyWith(memberCount: newMemberCount);
        }
        return group;
      }).toList();

      _cachedGroupsData = _CachedGroupsData(
        groups: updatedGroupsCache,
        timestamp: DateTime.now(), // Fresh timestamp for optimistic update
        companyId: _cachedGroupsData!.companyId,
      );
    } else {
      debugPrint(
          '⚠️ [GroupsTab] No cached groups data, updating _groups directly');
    }

    // Update UI immediately - CRITICAL: Always update UI even if group not in cache
    if (mounted) {
      setState(() {
        _groups = updatedGroupsList;
        _filterGroups(); // Re-apply filtering
      });
      debugPrint('✅ [GroupsTab] UI updated immediately with new member count');
    } else {
      debugPrint('⚠️ [GroupsTab] Widget not mounted, UI update skipped');
    }
  }

  /// Decrement member count for a group (when member leaves)
  /// Updates both cached data AND current _groups state for immediate UI update
  void _decrementGroupMemberCount(String groupId, int decrementBy) {
    // Update _groups directly for immediate UI update
    final updatedGroupsList = _groups.map((group) {
      if (group.id == groupId) {
        final currentCount = group.memberCount ?? group.members.length;
        final newMemberCount =
            (currentCount - decrementBy).clamp(0, double.infinity).toInt();
        debugPrint(
            '⚡ [GroupsTab] Optimistically decremented member count for group ${group.name}: $currentCount → $newMemberCount');
        return group.copyWith(memberCount: newMemberCount);
      }
      return group;
    }).toList();

    // Update cache if available
    if (_cachedGroupsData != null) {
      final updatedGroupsCache = _cachedGroupsData!.groups.map((group) {
        if (group.id == groupId) {
          final currentCount = group.memberCount ?? group.members.length;
          final newMemberCount =
              (currentCount - decrementBy).clamp(0, double.infinity).toInt();
          return group.copyWith(memberCount: newMemberCount);
        }
        return group;
      }).toList();

      _cachedGroupsData = _CachedGroupsData(
        groups: updatedGroupsCache,
        timestamp: DateTime.now(), // Fresh timestamp for optimistic update
        companyId: _cachedGroupsData!.companyId,
      );
    } else {
      debugPrint(
          '⚠️ [GroupsTab] No cached groups data, updating _groups directly');
    }

    // Update UI immediately - CRITICAL: Always update UI even if group not in cache
    if (mounted) {
      setState(() {
        _groups = updatedGroupsList;
        _filterGroups(); // Re-apply filtering
      });
      debugPrint(
          '✅ [GroupsTab] UI updated immediately with decremented member count');
    } else {
      debugPrint('⚠️ [GroupsTab] Widget not mounted, UI update skipped');
    }
  }

  /// Load the set of opened group room IDs from SharedPreferences
  Future<void> _loadOpenedGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final openedGroupsList = prefs.getStringList('opened_group_rooms') ?? [];
      setState(() {
        _openedGroups = openedGroupsList.toSet();
      });
      debugPrint('✅ [GroupsTab] Loaded ${_openedGroups.length} opened groups');
    } catch (e) {
      debugPrint('⚠️ [GroupsTab] Error loading opened groups: $e');
    }
  }

  /// Mark a group as opened and save to SharedPreferences
  /// Also updates the group's unreadCount to 0 immediately to clear the indicator
  Future<void> _markGroupAsOpened(String roomId) async {
    try {
      // CRITICAL FIX: Update the group's unreadCount to 0 immediately
      // This ensures the indicator is cleared on first open, not after multiple opens
      final groupIndex = _groups.indexWhere((g) => g.id == roomId);
      if (groupIndex != -1 && _groups[groupIndex].unreadCount > 0) {
        setState(() {
          _openedGroups.add(roomId);
          // Create updated group with unreadCount = 0
          _groups[groupIndex] = GroupChat(
            id: _groups[groupIndex].id,
            name: _groups[groupIndex].name,
            description: _groups[groupIndex].description,
            iconUrl: _groups[groupIndex].iconUrl,
            creatorId: _groups[groupIndex].creatorId,
            createdByUserId: _groups[groupIndex].createdByUserId,
            members: _groups[groupIndex].members,
            memberCount: _groups[groupIndex].memberCount,
            createdAt: _groups[groupIndex].createdAt,
            lastMessageTime: _groups[groupIndex].lastMessageTime,
            lastMessage: _groups[groupIndex].lastMessage,
            isUnread: false, // No longer unread
            unreadCount: 0, // Clear unread count immediately
          );
          // Update filtered groups as well
          final filteredIndex = _filteredGroups.indexWhere((g) => g.id == roomId);
          if (filteredIndex != -1) {
            _filteredGroups[filteredIndex] = _groups[groupIndex];
          }
        });
        debugPrint('✅ [GroupsTab] Cleared unreadCount for group $roomId on open');
      } else if (!_openedGroups.contains(roomId)) {
        // Just add to opened set if not already there
        setState(() {
          _openedGroups.add(roomId);
        });
      }

      // Also clear in UnreadCountManager to keep in sync
      await _unreadManager.clearUnreadCount(roomId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('opened_group_rooms', _openedGroups.toList());
      debugPrint('✅ [GroupsTab] Marked group $roomId as opened');
    } catch (e) {
      debugPrint('⚠️ [GroupsTab] Error marking group as opened: $e');
    }
  }

  /// Remove opened flag when a new message arrives so indicators can reappear
  Future<void> _clearGroupOpenedFlag(String roomId) async {
    if (!_openedGroups.contains(roomId)) {
      return;
    }

    final removed = _openedGroups.remove(roomId);
    if (!removed) {
      return;
    }

    if (mounted) {
      setState(() {});
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('opened_group_rooms', _openedGroups.toList());
      debugPrint('ℹ️ [GroupsTab] Cleared opened flag for group $roomId');
    } catch (e) {
      debugPrint(
          '⚠️ [GroupsTab] Error clearing opened flag for group $roomId: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadOpenedGroups();
    _loadLeftGroups(); // Load persisted left groups state
    _initializeSpeech();
    _searchController.addListener(_onSearchChanged);
    _setupWebSocketListener();
    _hasLoadedOnce = false; // Will be set to true after first successful load
    _lastLoadTime = null; // Will be set after first load

    // Initial loading state will be set when _loadGroups() is called
    // No need to set it here - it will be set when load actually starts

    // Listen to active tab changes
    // FIX: Only use listener to trigger loads - no duplicate timers in initState
    // This prevents multiple API calls when tab becomes active
    if (widget.activeTabNotifier != null && widget.tabIndex != null) {
      widget.activeTabNotifier!.addListener(_onTabChanged);
      // Initialize to -1 to ensure first load happens even if tab is already active
      _lastActiveTabIndex = -1;

      // FIX: Only trigger initial load if tab is already active AND hasn't loaded yet
      // The listener will handle all subsequent tab activations
      if (widget.activeTabNotifier!.value == widget.tabIndex &&
          !_hasLoadedOnce) {
        // Small delay to ensure widget is fully initialized (cancellable with generation check)
        final scheduledGeneration = _activationGeneration;
        _activationTimer = Timer(TabConstants.kTabActiveInitDelay, () {
          // Validate generation before executing
          if (!mounted ||
              scheduledGeneration != _activationGeneration ||
              _isLoadingGroups) {
            if (scheduledGeneration != _activationGeneration) {
              debugPrint(
                  '⏹️ [GroupsTab] Cancelled initial load (generation changed: $scheduledGeneration -> $_activationGeneration)');
            }
            return;
          }
          // Only load if we haven't loaded yet (prevent duplicate calls)
          if (!_hasLoadedOnce) {
            debugPrint('🔄 [GroupsTab] Initial load triggered from initState');
            _loadGroups();
          }
        });
      }
      // NOTE: If tab is not active, the listener will handle it when tab becomes active
      // No need for a separate timer here - this prevents duplicate calls
    } else {
      // If no ValueNotifier, load immediately (fallback for old code)
      // But only if not already loading
      if (!_isLoadingGroups && !_hasLoadedOnce) {
        _loadGroups();
      }
    }

    // Initialize connection status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isWebSocketConnected = _chatService.isWebSocketConnected;
        });
      }
    });
  }

  /// Handle tab changes (both active and inactive transitions)
  /// This ensures proper cleanup when tab becomes inactive and proper loading when active
  void _onTabChanged() {
    if (widget.activeTabNotifier == null || widget.tabIndex == null) return;

    final currentActiveIndex = widget.activeTabNotifier!.value;
    final wasActive = _lastActiveTabIndex == widget.tabIndex;
    final isNowActive = currentActiveIndex == widget.tabIndex;

    if (!wasActive && isNowActive) {
      // Tab became active
      _onTabBecameActive();
    } else if (wasActive && !isNowActive) {
      // Tab became inactive - CRITICAL FIX: Reset loading state
      _onTabBecameInactive();
    }

    // Update last active index AFTER handling the transition
    _lastActiveTabIndex = currentActiveIndex;
  }

  /// Handle tab becoming inactive
  /// CRITICAL: Reset loading flags to prevent stuck state on next activation
  void _onTabBecameInactive() {
    debugPrint('🔴 [GroupsTab] Tab became inactive - resetting loading state');

    // Cancel any pending activation timer
    _activationTimer?.cancel();
    _activationTimer = null;

    // CRITICAL FIX: Reset loading flags so next activation can start fresh
    // The in-flight request will continue but its result might be ignored
    // if the tab is inactive when it completes (mounted check)
    _isLoadingGroups = false;
    _inFlightLoad = null;

    // Increment generation to invalidate any pending delayed operations
    _activationGeneration++;
  }

  /// Handle tab becoming active
  ///
  /// GENERATION-BASED CANCELLATION: Each activation increments _activationGeneration.
  /// Any delayed operations (Timer callbacks) validate the generation before executing.
  /// If generation changed, the operation is cancelled. This prevents:
  /// - Stale delayed operations from executing after tab becomes inactive
  /// - Overlapping loads from rapid tab switching
  /// - State mutations after widget disposal
  void _onTabBecameActive() {
    // NOTE: Tab transition detection is now handled in _onTabChanged()
    // This method is called only when tab actually becomes active

    // Increment generation to invalidate any pending delayed operations
    // This ensures stale timers don't execute after tab becomes inactive
    _activationGeneration++;
    debugPrint(
        '🟢 [GroupsTab] Tab became active (generation: $_activationGeneration)');

      // Cancel any pending activation timer
      // This prevents queued delayed loads from executing
      _activationTimer?.cancel();
      _activationTimer = null;

      // STEP 1: Render cached data immediately (if available)
      // This ensures UI is never empty when cached data exists
      _renderCachedDataIfAvailable();

      // STEP 2: Always call API when tab is tapped to fetch fresh data
      // Cache is used for immediate UI feedback, but we always fetch fresh data
      _apiService.getSelectedSocietyId().then((currentCompanyId) async {
        // Check if a group was updated (photo upload, add member, etc.)
        // If updated, immediately call API with force=true to bypass cache and throttling
        if (GroupsTab._groupUpdated) {
          debugPrint(
              '🔄 [GroupsTab] Group update detected - immediately calling API (bypassing cache and throttling)');
          debugPrint(
              '📡 [GroupsTab] API: GET http://13.201.27.102:7071/api/v1/rooms/all?company_id=$currentCompanyId&chat_type=group&is_member=true');
          GroupsTab._groupUpdated = false; // Reset flag

          // CRITICAL FIX: Don't clear cache - optimistic updates might already be in _groups
          // The API refresh will update with fresh data, but we don't want to lose optimistic updates
          // Just invalidate cache so API is called, but keep current _groups until API responds
          _cachedGroupsData = null;
          _clearRoomInfoCache();

          // Immediately call API with force=true (bypasses cache, throttling, and loading checks)
          // force=true ensures refresh happens even if a load is in progress
          _loadGroups(force: true);
          return;
        }

        // Check if we have valid cached data (for immediate UI feedback)
        final hasValidCache = _cachedGroupsData != null &&
            _cachedGroupsData!.isValid(currentCompanyId);

        if (hasValidCache) {
          final cacheAge =
              DateTime.now().difference(_cachedGroupsData!.timestamp);
          debugPrint(
              '✅ [GroupsTab] Cache is valid (age: ${cacheAge.inSeconds}s), showing cached data immediately');

          // FIX #3: Ensure data is visible even if cache is valid
          // Re-render cached data to ensure UI is updated (in case state was cleared)
          // This fixes the issue where data doesn't show when returning to tab
          if (mounted && (_groups.isEmpty || _filteredGroups.isEmpty)) {
            debugPrint(
                '🔄 [GroupsTab] State is empty but cache is valid, re-rendering cached data');
            _renderCachedDataIfAvailable();
          }
        }

        // Always call API when tab is tapped to fetch fresh groups data
        // This ensures we always have the latest groups for the user
        // But check if load is already in progress to avoid duplicate calls
        if (_isLoadingGroups) {
          debugPrint(
              '⏸️ [GroupsTab] Tab became active but load already in progress, skipping duplicate call...');
          return;
        }

        debugPrint(
            '🔄 [GroupsTab] Tab tapped - calling API to fetch fresh groups (will respect throttling)');
        debugPrint(
            '📡 [GroupsTab] API: GET http://13.201.27.102:7071/api/v1/rooms/all?company_id=$currentCompanyId&chat_type=group&is_member=true');

        // Small delay to ensure widget is fully built (cancellable with generation check)
        final scheduledGeneration = _activationGeneration;
        _activationTimer = Timer(TabConstants.kDataLoadDelay, () {
          // Validate generation before executing
          if (!mounted ||
              _isLoadingGroups ||
              scheduledGeneration != _activationGeneration) {
            if (scheduledGeneration != _activationGeneration) {
              debugPrint(
                  '⏹️ [GroupsTab] Cancelled delayed load (generation changed: $scheduledGeneration -> $_activationGeneration)');
            }
            return;
          }
          // Call API to fetch fresh groups (throttling in _loadGroups will prevent if too soon)
          // Use force=false to respect throttling, but always attempt to fetch
          _loadGroups(force: false);
        });
      });
  }

  /// Render cached data immediately if available
  ///
  /// This ensures UI is never empty when cached data exists.
  /// Called synchronously on tab activation, before any network calls.
  void _renderCachedDataIfAvailable() {
    if (_cachedGroupsData == null) {
      debugPrint(
          'ℹ️ [GroupsTab] No cached data available for immediate rendering');
      return; // No cached data
    }

    // ALWAYS render cached data if it exists, even if expired
    // This prevents blank UI. Network fetch will validate expiry and refresh if needed.
    final hasGroups = _cachedGroupsData!.groups.isNotEmpty;

    if (hasGroups) {
      debugPrint(
          '✅ [GroupsTab] Rendering cached data immediately on activation (${_cachedGroupsData!.groups.length} groups)');

      if (mounted) {
        setState(() {
          // Render cached data immediately - this ensures UI is never blank
          _groups = List.from(_cachedGroupsData!.groups);
          _filterGroups(); // Apply filtering (removes left groups and applies search)
          _isLoading = false;
          _hasError = false;
          _errorMessage = null;

          // Apply search filter if active
          if (_searchQuery.isNotEmpty) {
            _filterGroups();
          }
        });
      }
    } else {
      debugPrint(
          'ℹ️ [GroupsTab] Cached data exists but is empty - will show loading state');
      // If no cached data, ensure loading state is shown
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    }
  }

  /// Setup WebSocket connection state listener
  void _setupWebSocketListener() {
    // Listen to connection state changes
    _wsConnectionSubscription = _chatService.connectionStateStream.listen(
      (isConnected) {
        if (mounted) {
          setState(() {
            _isWebSocketConnected = isConnected;
          });
        }
      },
    );

    // Listen to incoming messages
    _wsMessageSubscription = _chatService.messageStream.listen(
      (wsMessage) {
        _handleWebSocketMessage(wsMessage);
      },
      onError: (error) {
        debugPrint('WebSocket message stream error: $error');
      },
    );
  }

  /// Handle incoming WebSocket messages - update group unread counts and last messages
  void _handleWebSocketMessage(WebSocketMessage wsMessage) async {
    if (!mounted) return;

    final roomId = wsMessage.roomId;
    if (roomId == null || roomId.isEmpty) return;

    // Handle unread_count_update events from WebSocket
    final messageType = wsMessage.type?.toLowerCase() ??
        wsMessage.data?['type']?.toString().toLowerCase();
    if (messageType == 'unread_count_update' ||
        wsMessage.messageTypeEnum == WebSocketMessageType.unreadCountUpdate) {
      final updateRoomId = roomId ?? wsMessage.data?['room_id']?.toString();
      final userId = wsMessage.userId ?? wsMessage.data?['user_id']?.toString();
      final unreadCount = wsMessage.data?['unread_count'] as int? ??
          (wsMessage.data?['unread_count'] is String
              ? int.tryParse(wsMessage.data!['unread_count'] as String)
              : null);

      if (updateRoomId != null && userId != null && unreadCount != null) {
        debugPrint(
            '📊 [GroupsTab] Received unread_count_update: room=$updateRoomId, user=$userId, count=$unreadCount');

        // Update local unread count manager if this is for current user
        final currentUserId = _currentUserId;
        if (userId == currentUserId) {
          if (unreadCount == 0) {
            await _unreadManager.clearUnreadCount(updateRoomId);
          } else {
            // Backend is source of truth - update local cache with exact count
            await _unreadManager.setUnreadCount(updateRoomId, unreadCount);
            debugPrint(
                '📊 [GroupsTab] Unread count updated to $unreadCount for room $updateRoomId');
            // So indicator shows: remove from opened set when backend says there are unread messages
            await _clearGroupOpenedFlag(updateRoomId);
          }

          // Update group in list with new unread count
          final groupIndex = _groups.indexWhere((g) => g.id == updateRoomId);
          if (groupIndex != -1) {
            final lastMessage = _unreadManager.getLastMessage(updateRoomId);
            final lastMessageTime =
                _unreadManager.getLastMessageTime(updateRoomId) ??
                    DateTime.now();
            // Get the actual unread count from manager (may have been updated)
            final actualUnreadCount = _unreadManager.getUnreadCount(updateRoomId);

            final updatedGroup = GroupChat(
              id: _groups[groupIndex].id,
              name: _groups[groupIndex].name,
              description: _groups[groupIndex].description,
              iconUrl: _groups[groupIndex].iconUrl,
              creatorId: _groups[groupIndex].creatorId,
              createdByUserId: _groups[groupIndex].createdByUserId,
              members: _groups[groupIndex].members,
              memberCount: _groups[groupIndex].memberCount,
              createdAt: _groups[groupIndex].createdAt,
              lastMessageTime: lastMessageTime,
              lastMessage: lastMessage,
              isUnread: actualUnreadCount > 0,
              unreadCount: actualUnreadCount,
            );

            setState(() {
              _groups[groupIndex] = updatedGroup;
              _filteredGroups = List.from(_groups);
            });
          }
        }
      }
      return; // Don't process unread_count_update as messages
    }

    // Handle presence_update events from WebSocket
    if (messageType == 'presence_update' ||
        messageType == 'presenceupdate' ||
        wsMessage.messageTypeEnum == WebSocketMessageType.presenceUpdate) {
      final userId = wsMessage.data?['user_id']?.toString();
      final isOnline = wsMessage.data?['is_online'] as bool?;
      final statusString = wsMessage.data?['status']?.toString();

      debugPrint(
          '👤 [GroupsTab] Presence update: user=$userId, online=$isOnline, status=$statusString');

      // Presence updates are handled at the group chat level, not list level
      // Just log for now - group members' presence is tracked in group chat screen
      return; // Don't process presence_update as messages
    }

    // Handle read_receipt events from WebSocket
    if (messageType == 'read_receipt' ||
        messageType == 'readreceipt' ||
        wsMessage.messageTypeEnum == WebSocketMessageType.readReceipt) {
      final messageId = wsMessage.data?['message_id']?.toString();
      final userId = wsMessage.userId ?? wsMessage.data?['user_id']?.toString();

      debugPrint(
          '📖 [GroupsTab] Read receipt: message=$messageId, user=$userId');

      // Read receipts are handled at the group chat screen level
      return; // Don't process read_receipt as messages
    }

    debugPrint('📨 [GroupsTab] Received WebSocket message for room: $roomId');

    // Check if this message is from current user
    final currentUserId = _currentUserId;
    final isFromCurrentUser = wsMessage.userId == currentUserId;

    // Check if this is a system message (should not increment unread count)
    final isSystemMessage = _isSystemMessageFromWebSocket(wsMessage);

    // Update last message timestamp and content with user-friendly preview
    final activityPreview = ActivityPreviewHelper.fromWebSocket(
      content: wsMessage.content,
      messageType: wsMessage.messageType,
      data: wsMessage.data,
    );

    if (activityPreview.text.isNotEmpty) {
      await _unreadManager.updateLastMessage(
        roomId,
        activityPreview.text,
        DateTime.now(),
      );
    }

    // Backend is source of truth for unread counts (DB + unread_count_update).
    // Only clear "opened" flag so indicator can reappear; count is applied via unread_count_update.
    if (!isFromCurrentUser && !isSystemMessage) {
      await _clearGroupOpenedFlag(roomId);
    }

    // Update group in list
    final groupIndex = _groups.indexWhere((g) => g.id == roomId);
    if (groupIndex == -1) {
      debugPrint(
          '⚠️ [GroupsTab] Received message for unknown group $roomId - unread count updated');
      return; // Group not in list (maybe filtered out)
    }

    final unreadCount = _unreadManager.getUnreadCount(roomId);
    final lastMessage = _unreadManager.getLastMessage(roomId);
    final lastMessageTime =
        _unreadManager.getLastMessageTime(roomId) ?? DateTime.now();

    final updatedGroup = GroupChat(
      id: _groups[groupIndex].id,
      name: _groups[groupIndex].name,
      description: _groups[groupIndex].description,
      iconUrl: _groups[groupIndex].iconUrl,
      creatorId: _groups[groupIndex].creatorId,
      createdByUserId: _groups[groupIndex].createdByUserId,
      members: _groups[groupIndex].members,
      memberCount: _groups[groupIndex].memberCount,
      createdAt: _groups[groupIndex].createdAt,
      lastMessageTime: lastMessageTime,
      lastMessage: lastMessage,
      isUnread: unreadCount > 0,
      unreadCount: unreadCount,
    );

    setState(() {
      _groups[groupIndex] = updatedGroup;
      _filteredGroups = List.from(_groups);
    });

    debugPrint(
        '✅ [GroupsTab] Updated group $roomId: unread=$unreadCount, lastMsg=${lastMessage?.substring(0, lastMessage.length > 20 ? 20 : lastMessage.length)}');
  }

  /// Load current user ID from auth service
  /// For group chat, we need UUID (sub field from Keycloak) to match reaction user IDs
  Future<void> _loadCurrentUserId() async {
    try {
      // Priority 1: Decode token directly to get UUID (sub field) - most reliable method
      // This ensures we always get the UUID from the token payload (matches backend reaction user IDs)
      try {
        final accessToken = await KeycloakService.getAccessToken();
        if (accessToken != null) {
          try {
            final decodedToken = JwtDecoder.decode(accessToken);
            final sub = decodedToken['sub'];
            if (sub != null) {
              final subStr = sub.toString().trim();
              // Validate it's a UUID format (contains dashes)
              if (subStr.isNotEmpty &&
                  subStr.contains('-') &&
                  subStr.length > 15) {
                if (mounted) {
                  setState(() {
                    _currentUserId = subStr; // UUID for group chat reactions
                  });
                  debugPrint(
                      '✅ [GroupsTab] Current user UUID loaded: $subStr (decoded from token)');
                }
              } else {
                debugPrint(
                    '⚠️ [GroupsTab] Sub field is not a valid UUID: $subStr');
              }
            } else {
              debugPrint('⚠️ [GroupsTab] No sub field found in decoded token');
            }
          } catch (e) {
            debugPrint('⚠️ [GroupsTab] Error decoding token: $e');
          }
        } else {
          debugPrint('⚠️ [GroupsTab] No access token available');
        }
      } catch (e) {
        debugPrint('⚠️ [GroupsTab] Error getting access token: $e');
      }

      // Fallback 1: If UUID not found, try getUserInfo() which decodes token
      if (_currentUserId == null) {
        try {
          final userInfo = await KeycloakService.getUserInfo();
          if (userInfo != null) {
            final sub = userInfo['sub'];
            if (sub != null) {
              final subStr = sub.toString().trim();
              if (subStr.isNotEmpty &&
                  subStr.contains('-') &&
                  subStr.length > 15) {
                if (mounted) {
                  setState(() {
                    _currentUserId = subStr;
                  });
                  debugPrint(
                      '✅ [GroupsTab] Current user UUID loaded from getUserInfo: $subStr');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ [GroupsTab] Error getting userInfo: $e');
        }
      }

      // Fallback 2: If UUID still not found, try getUserData() which might have it
      if (_currentUserId == null) {
        try {
          final userData = await KeycloakService.getUserData();
          if (userData != null) {
            final sub = userData['sub'];
            if (sub != null) {
              final subStr = sub.toString().trim();
              if (subStr.isNotEmpty &&
                  subStr.contains('-') &&
                  subStr.length > 15) {
                if (mounted) {
                  setState(() {
                    _currentUserId = subStr;
                  });
                  debugPrint(
                      '✅ [GroupsTab] Current user UUID loaded from getUserData: $subStr');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ [GroupsTab] Error getting userData: $e');
        }
      }

      // Final fallback: If UUID still not found, try getUserId() (but this may return numeric ID)
      if (_currentUserId == null) {
        try {
          final userId = await _apiService.getUserId();
          if (mounted && userId != null) {
            setState(() {
              _currentUserId = userId.toString();
            });
            debugPrint(
                '⚠️ [GroupsTab] Using fallback user ID (may be numeric): $userId');
          }
        } catch (e) {
          debugPrint('⚠️ [GroupsTab] Error getting fallback user ID: $e');
        }
      }

      // Also load numeric user ID from Keycloak token/user data for comparison (backward compatibility)
      try {
        final userData = await KeycloakService.getUserData();
        if (userData != null) {
          // Priority order for finding numeric user_id:
          // 1. user_id (from login API response - stored in user data)
          // 2. old_gate_user_id (from token)
          // 3. old_sso_user_id (from token)
          // 4. gate_user_id (from token)
          // 5. sso_user_id (from token)
          // 6. Check in chsone_session if available
          final candidates = [
            userData['user_id'], // Direct user_id from login response
            userData['old_gate_user_id'],
            userData['old_sso_user_id'],
            userData['gate_user_id'],
            userData['sso_user_id'],
          ];

          // Also check chsone_session if available
          if (userData['chsone_session'] is Map) {
            final chsoneSession = userData['chsone_session'] as Map;
            candidates.add(chsoneSession['user_id']);
          }

          for (final candidate in candidates) {
            if (candidate != null) {
              final candidateStr = candidate.toString().trim();
              // Skip UUIDs (they contain '-' and are longer)
              // Only process strings that don't contain '-' (numeric IDs)
              if (!candidateStr.contains('-')) {
                final parsed = int.tryParse(candidateStr);
                if (parsed != null) {
                  if (mounted) {
                    setState(() {
                      _currentUserNumericId = parsed;
                    });
                    debugPrint(
                        '✅ [GroupsTab] Current numeric user ID loaded: $parsed (from: $candidateStr)');
                  }
                  return;
                }
              } else {
                debugPrint(
                    '⚠️ [GroupsTab] Skipping UUID candidate: $candidateStr');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [GroupsTab] Error loading numeric user ID: $e');
      }
    } catch (e) {
      debugPrint('⚠️ [GroupsTab] Error loading user ID: $e');
      // Keep _currentUserId as null - delete icon won't show
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Simplified pattern matching My Vehicles tab
    // Only check for company changes and image uploads - no automatic tab visibility reloads
    // Let _onTabBecameActive() handle tab visibility changes when activeTabNotifier is provided

    // Check if company_id has changed and reload groups if needed
    // This will only reload if company actually changed, not on every didChangeDependencies call
    _checkCompanyChangeAndReload();

    // Check if image was uploaded and refresh if needed
    _checkImageUploadAndRefresh();

    // CRITICAL: Check if group was updated (leave, upload image, clear chat, add/remove member)
    // This ensures immediate refresh when user navigates back from group chat screen
    // This handles cases where tab might already be active but user navigated back
    _checkGroupUpdateAndRefresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _speech.stop();
    _wsConnectionSubscription?.cancel();
    _wsMessageSubscription?.cancel();
    // Cancel activation timer
    _activationTimer?.cancel();
    // Remove listener for active tab changes
    if (widget.activeTabNotifier != null) {
      widget.activeTabNotifier!.removeListener(_onTabChanged);
    }
    // Clear cache on dispose
    _roomInfoCache.clear();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
          });
          EnhancedToast.error(
            context,
            title: 'Speech Recognition Error',
            message: error.errorMsg,
          );
        }
      },
    );

    if (!available && mounted) {
      EnhancedToast.warning(
        context,
        title: 'Speech Recognition',
        message: 'Speech recognition is not available on this device.',
      );
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterGroups();
    });
  }

  void _filterGroups() {
    // First filter out groups the user has left
    final visibleGroups =
        _groups.where((group) => !_hasUserLeftGroup(group.id)).toList();

    if (_searchQuery.isEmpty) {
      _filteredGroups = visibleGroups;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredGroups = visibleGroups.where((group) {
        return group.name.toLowerCase().contains(query) ||
            (group.description != null &&
                group.description!.toLowerCase().contains(query));
      }).toList();
    }
  }

  // Helper method to add a new group
  void _addNewGroup(GroupChat newGroup) {
    if (mounted) {
      setState(() {
        _groups.insert(0, newGroup);
      });
    }
  }

  // Helper method to remove a group from the list
  void _removeGroup(String groupId) {
    if (mounted) {
      setState(() {
        _groups.removeWhere((group) => group.id == groupId);
        _filterGroups(); // Update filtered list
      });
      debugPrint('✅ [GroupsTab] Removed group: $groupId');
    }
  }

  /// Check if user has left a specific group
  bool _hasUserLeftGroup(String groupId) {
    return _leftGroups.contains(groupId);
  }

  /// Mark that user has left a specific group
  void _markUserLeftGroup(String groupId) {
    _leftGroups.add(groupId);
    debugPrint('🚫 [GroupsTab] Marked user as left from group: $groupId');
    _persistLeftGroups(); // Persist to storage
  }

  /// Clear left status when user rejoins group (e.g., added back by admin)
  /// This prevents the group from being hidden when user is re-added
  void _clearUserLeftGroup(String groupId) {
    if (_leftGroups.contains(groupId)) {
      _leftGroups.remove(groupId);
      _persistLeftGroups(); // Persist the change
      debugPrint('✅ [GroupsTab] Cleared left status for group: $groupId');
    }
  }

  /// Load left groups from persistent storage
  void _loadLeftGroups() async {
    try {
      final storage = StorageService.instance;
      final leftGroupsJson = await storage.getJson('left_groups');
      if (leftGroupsJson != null && leftGroupsJson['groups'] is List) {
        final groups = (leftGroupsJson['groups'] as List).cast<String>();
        if (mounted) {
          setState(() {
            _leftGroups.addAll(groups);
          });
        }
        debugPrint(
            '✅ [GroupsTab] Loaded ${groups.length} left groups from storage');
      }
    } catch (e) {
      debugPrint('❌ [GroupsTab] Error loading left groups: $e');
    }
  }

  /// Persist left groups to storage
  void _persistLeftGroups() async {
    try {
      final storage = StorageService.instance;
      await storage.setJson('left_groups', {
        'groups': _leftGroups.toList(),
      });
      debugPrint(
          '✅ [GroupsTab] Persisted ${_leftGroups.length} left groups to storage');
    } catch (e) {
      debugPrint('❌ [GroupsTab] Error persisting left groups: $e');
    }
  }

  /// Update a specific group's iconUrl in the list
  void _updateGroupIconUrl(String groupId, String? iconUrl) {
    if (!mounted) return;

    final groupIndex = _groups.indexWhere((group) => group.id == groupId);
    if (groupIndex != -1) {
      setState(() {
        // Update the group with new iconUrl
        _groups[groupIndex] = _groups[groupIndex].copyWith(iconUrl: iconUrl);

        // Also update filtered groups if it exists there
        final filteredIndex =
            _filteredGroups.indexWhere((group) => group.id == groupId);
        if (filteredIndex != -1) {
          _filteredGroups[filteredIndex] =
              _filteredGroups[filteredIndex].copyWith(iconUrl: iconUrl);
        }
      });
      debugPrint('✅ [GroupsTab] Updated iconUrl for group: $groupId');
    } else {
      debugPrint('⚠️ [GroupsTab] Group not found for iconUrl update: $groupId');
    }
  }

  /// Check if image was uploaded and refresh groups if needed
  /// This is called in didChangeDependencies when returning from GroupChatScreen
  void _checkImageUploadAndRefresh() {
    if (!mounted || _isLoadingGroups) return;

    // Check if an image was uploaded
    if (GroupsTab._imageUploaded) {
      debugPrint(
          '🔄 [GroupsTab] Image was uploaded, refreshing groups list...');
      GroupsTab._imageUploaded = false; // Reset flag

      // Clear cache for affected rooms (if we know which room, we could invalidate just that one)
      // For now, clear all cache since we don't know which room was updated
      _clearRoomInfoCache();

      // Immediately refresh groups list by calling the API
      // No delay - call API immediately for fast loading like Postman
      if (mounted && !_isLoadingGroups) {
        _loadGroups(force: true);
      }
    }
  }

  /// Check if group was updated (leave, upload image, clear chat, add/remove member) and refresh groups if needed
  /// This is called in didChangeDependencies, build(), and navigation callbacks when returning from GroupChatScreen
  /// This ensures immediate API refresh when user navigates back after performing group actions
  void _checkGroupUpdateAndRefresh() {
    if (!mounted) return;

    // Check if a group was updated (any action: leave, upload image, clear chat, add/remove member)
    if (GroupsTab._groupUpdated) {
      debugPrint(
          '🔄 [GroupsTab] Group update detected - immediately calling API (bypassing cache, throttling, and loading checks)');
      GroupsTab._groupUpdated = false; // Reset flag

      // Clear cache to ensure fresh data
      _cachedGroupsData = null;
      _clearRoomInfoCache();

      // CRITICAL: Use force=true to bypass all checks (loading, cache, throttling)
      // This ensures refresh happens immediately even if a load is in progress
      // The _loadGroups method with force=true will handle concurrent loads properly
      if (mounted) {
        _loadGroups(force: true);
      }
    }
  }

  /// Check if company_id has changed and reload groups if needed
  /// This is called in didChangeDependencies and build() to detect society/company changes
  /// IMPORTANT: This only reloads if company actually changed, not on every call
  /// FIXED: Added idempotent check, prevents rebuild-triggered reloads, only clears cache on real change
  Future<void> _checkCompanyChangeAndReload() async {
    // CRITICAL FIX #1: Prevent rebuild-triggered reloads
    // Only check if not already loading, not in-flight, and not already checking
    if (!mounted ||
        _isLoadingGroups ||
        _inFlightLoad != null ||
        _isCheckingCompanyChange) {
      return;
    }

    // Set flag to prevent concurrent checks
    _isCheckingCompanyChange = true;

    try {
      final currentCompanyId = await _apiService.getSelectedSocietyId();

      // CRITICAL FIX #2: Idempotent company change detection
      // Only proceed if company ACTUALLY changed (not just null check)
      final companyActuallyChanged = currentCompanyId != null &&
          _lastLoadedCompanyId != null &&
          currentCompanyId != _lastLoadedCompanyId;

      // CRITICAL FIX #3: First load detection (only if never loaded for this company)
      final isFirstLoad = currentCompanyId != null &&
          _lastLoadedCompanyId == null &&
          !_hasLoadedOnce;

      // Log for debugging
      debugPrint(
          '🔍 [GroupsTab] Checking company change - Current: $currentCompanyId, Last loaded: $_lastLoadedCompanyId, Has loaded once: $_hasLoadedOnce');

      // Only proceed if company actually changed OR it's the first load
      if (companyActuallyChanged || isFirstLoad) {
        if (isFirstLoad) {
          debugPrint(
              '🔄 [GroupsTab] First load for company_id: $currentCompanyId');
        } else {
          debugPrint(
              '🔄 [GroupsTab] Company changed from $_lastLoadedCompanyId to $currentCompanyId - Clearing and reloading groups');
        }

        // CRITICAL FIX #4: Only clear cache when company ACTUALLY changed
        // Don't clear on first load if we have valid cache
        if (companyActuallyChanged) {
          // Company has changed - clear existing groups immediately to prevent showing wrong data
          if (mounted) {
            setState(() {
              _groups = [];
              _filteredGroups = [];
              _isLoading = true;
              _hasError = false;
              _errorMessage = null;
            });
            // Clear cache when company changes (different company = different rooms)
            _clearRoomInfoCache();
            // Clear groups cache when company changes
            _cachedGroupsData = null;
            debugPrint('🔄 [GroupsTab] Company changed, cleared groups cache');
          }
        }

        // Use a small delay to avoid conflicts during navigation, then reload
        // For first load, we can reload immediately
        final delay = isFirstLoad
            ? Duration.zero
            : TabConstants.kCompanyChangeReloadDelay;
        _activationTimer?.cancel();
        // Increment generation to cancel any pending operations
        _activationGeneration++;
        final scheduledGeneration = _activationGeneration;
        _activationTimer = Timer(delay, () {
          // Validate generation before executing
          if (!mounted ||
              _isLoadingGroups ||
              _inFlightLoad != null ||
              scheduledGeneration != _activationGeneration) {
            if (scheduledGeneration != _activationGeneration) {
              debugPrint(
                  '⏹️ [GroupsTab] Cancelled company change reload (generation changed)');
            }
            return;
          }
          _loadGroups();
        });
      } else {
        // Company hasn't changed - no need to reload
        debugPrint(
            '✅ [GroupsTab] Company unchanged ($currentCompanyId), no reload needed');
      }
    } catch (e) {
      debugPrint('❌ [GroupsTab] Error checking company change: $e');
    } finally {
      // CRITICAL FIX: Always clear the checking flag
      _isCheckingCompanyChange = false;
    }
  }

  /// Load groups with single-flight coalescing and request throttling
  ///
  /// SINGLE-FLIGHT COALESCING: If a load is already in progress, subsequent calls
  /// return the same Future instead of starting a new request. This prevents:
  /// - Repeated taps from triggering multiple loads
  /// - Tab bouncing from creating overlapping requests
  /// - Multiple activation events from queuing loads
  ///
  /// REQUEST THROTTLING: Enforces a minimum 2-second interval between requests
  /// to prevent "too many requests" errors. This throttle is applied BEFORE
  /// starting any network call, not after.
  ///
  /// CACHE CHECK: If cache is valid, skip API call entirely (no network request)
  ///
  /// Both mechanisms work together to ensure at most 1 in-flight request per tab.
  ///
  /// FIXED: Proper mutex, correct throttling logic, idempotent checks
  Future<void> _loadGroups({bool force = false}) async {
    // CRITICAL FIX #1: Proper mutex check - prevent parallel calls
    // Check both _inFlightLoad AND _isLoadingGroups for defense in depth
    if ((_inFlightLoad != null || _isLoadingGroups) && !force) {
      debugPrint(
          '⏸️ [GroupsTab] Load already in-flight, coalescing request...');
      return _inFlightLoad ?? Future.value();
    }

    // CACHE CHECK: If cache is valid and not forcing, skip API call
    if (!force) {
      final currentCompanyId = await _apiService.getSelectedSocietyId();
      if (_cachedGroupsData != null &&
          _cachedGroupsData!.isValid(currentCompanyId)) {
        final cacheAge =
            DateTime.now().difference(_cachedGroupsData!.timestamp);
        debugPrint(
            '✅ [GroupsTab] Cache is valid (age: ${cacheAge.inSeconds}s), skipping API call');
        // Cache is valid - no need to call API
        widget.loadingNotifier?.value = false;
        return;
      }
    }

    // CRITICAL FIX #2: Correct throttling logic
    // Only throttle if timeSinceLastRequest < minInterval (not <=)
    // If remaining time is 0s or negative, allow execution
    if (_lastRequestTime != null && !force) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final remainingSeconds =
            (_minRequestInterval - timeSinceLastRequest).inSeconds;
        final remainingMs =
            (_minRequestInterval - timeSinceLastRequest).inMilliseconds;
        debugPrint(
            '⏸️ [GroupsTab] Request throttled (${remainingSeconds}s ${remainingMs}ms remaining)');
        // CRITICAL: Don't return immediately - wait for cooldown to expire
        // This prevents infinite retry loops
        await Future.delayed(_minRequestInterval - timeSinceLastRequest);
        // After waiting, check again if still needed (might have been cancelled)
        // CRITICAL: If force=true, don't cancel even if load is in progress
        if (!mounted ||
            ((_inFlightLoad != null || _isLoadingGroups) && !force)) {
          debugPrint('⏸️ [GroupsTab] Request cancelled during throttle wait');
          return;
        }
      }
    }

    // CRITICAL FIX #3: Set mutex flags BEFORE async operations
    // This prevents race conditions where multiple calls pass the check
    _isLoadingGroups = true;
    _lastRequestTime = DateTime.now(); // Set AFTER throttle check passes

    // Notify parent that loading started (prevents tab switching)
    widget.loadingNotifier?.value = true;

    // Create the load Future and store it for coalescing
    // Multiple calls to _loadGroups() will return this same Future
    _inFlightLoad = _performLoadGroups(force: force);

    try {
      await _inFlightLoad;
    } finally {
      // CRITICAL FIX #4: Clear mutex flags in finally block
      // This ensures flags are cleared even if load fails
      _inFlightLoad = null;
      _isLoadingGroups = false;

      // Notify parent that loading completed (allows tab switching)
      widget.loadingNotifier?.value = false;
    }
  }

  /// Internal method that performs the actual load
  ///
  /// This method performs the actual API calls. It should only be called
  /// through _loadGroups() which handles single-flight coalescing and throttling.
  ///
  /// NOTE: Loading state notification is handled in _loadGroups() to ensure
  /// it's set before async operations and cleared in finally block.
  Future<void> _performLoadGroups({bool force = false}) async {
    // Validate widget is still mounted before starting
    if (!mounted) {
      debugPrint('⏹️ [GroupsTab] Widget not mounted, cancelling load');
      // Ensure loading state is cleared if we're not mounted
      widget.loadingNotifier?.value = false;
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    // Notify parent about loading state

    try {
      // Get company_id (society ID)
      final companyId = await _apiService.getSelectedSocietyId();

      // Check if widget is still mounted after async operation
      if (!mounted) {
        debugPrint(
            '⏹️ [GroupsTab] Widget not mounted after company ID fetch, cancelling load');
        return;
      }

      if (companyId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Please select a society first';
            // CRITICAL FIX #6: Don't reset lastLoadedCompanyId on error
            // Only reset if company actually changed, not on validation errors
          });
        }
        // Loading completed (with error) - allow tab switching
        widget.loadingNotifier?.value = false;
        return;
      }

      // Note: We don't skip reloading here even if company_id is the same
      // This allows manual refresh (pull-to-refresh) to work properly
      // The _checkCompanyChangeAndReload() method handles automatic reloading on company change

      // Call API to get rooms where user is a member
      // This endpoint returns ONLY rooms where the current user is already a member
      // API Endpoint: GET http://13.201.27.102:7071/api/v1/rooms/all?company_id={companyId}&chat_type=group&is_member=true
      // This matches the curl command format provided
      debugPrint(
          '📡 [GroupsTab] Calling API to fetch group rooms for company_id: $companyId');
      debugPrint(
          '🌐 [GroupsTab] API URL: http://13.201.27.102:7071/api/v1/rooms/all?company_id=$companyId&chat_type=group&is_member=true');
      debugPrint(
          '🔑 [GroupsTab] Using Authorization: Bearer <token> (handled by RoomService)');
      final response = await _roomService.getAllRooms(
        companyId: companyId,
        chatType: 'group',
      );

      if (!mounted) return;

      if (response.success) {
        // PHASE 1 - INSTANT RENDER: Show groups immediately from /rooms API response
        // Use ONLY basic room data: id, name, photo_url, last_active
        // Do NOT wait for room info, members, or any other data
        // Handle both null and empty list cases - both mean no rooms
        final rooms = response.data ?? <Room>[];

        debugPrint(
            '⚡ [GroupsTab] INSTANT RENDER: Converting ${rooms.length} rooms to groups (no room info required)');

        // Convert rooms to GroupChat IMMEDIATELY - no room info needed
        // This is the FAST path - render list in <200ms
        // API already filtered by chat_type=group, so all rooms are groups
        // Use members_count directly from /rooms API response
        // CRITICAL: Seed UnreadCountManager from API unread_count so User B sees "5 new messages" on login
        for (final room in rooms) {
          if (room.unreadCount != null && room.unreadCount! > 0) {
            await _unreadManager.setUnreadCount(room.id, room.unreadCount!);
            debugPrint(
                '📥 [GroupsTab] Seeded unread count from API for group ${room.id}: ${room.unreadCount}');
            // If backend says there are unread messages, ensure this group is not treated as "opened"
            if (_openedGroups.remove(room.id)) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setStringList(
                  'opened_group_rooms', _openedGroups.toList());
            }
          }
        }

        final groupChats = <GroupChat>[];

        for (final room in rooms) {
          // API already filtered by chat_type=group, so all rooms should be groups
          // Safety check: Skip rooms with < 3 members (shouldn't happen with chat_type=group filter)
          if (room.membersCount == null || room.membersCount! < 3) {
            debugPrint(
                '⚠️ [GroupsTab] API returned room with membersCount=${room.membersCount} (expected >= 3 for group), skipping');
            continue;
          }

          // Use cached room info for members list if available (optional enhancement)
          // Otherwise members list will be empty and loaded on-demand
          final cached = _roomInfoCache[room.id];
          final cachedInfo = cached != null &&
                  DateTime.now().difference(cached.timestamp) <
                      _roomInfoCacheExpiry &&
                  cached.roomInfo != null
              ? cached.roomInfo
              : null;

          // Create lightweight GroupChat from Room data only
          // Members list will be populated from cache if available, otherwise empty
          final members = cachedInfo != null && cachedInfo.members.isNotEmpty
              ? cachedInfo.members.map((member) {
                  return IntercomContact(
                    id: member.userId,
                    name: member.username ?? 'Unknown User',
                    type: IntercomContactType.resident,
                    status: IntercomContactStatus.offline,
                    photoUrl: member.avatar,
                    numericUserId: member
                        .numericUserId, // CRITICAL: Include numeric ID for API calls
                  );
                }).toList()
              : <IntercomContact>[]; // Empty - will load on-demand

          // Use members_count directly from /rooms API response
          // This is now available in the API response, so we don't need room info for count
          groupChats.add(GroupChat(
            id: room.id,
            name: room.name,
            description: room.description,
            iconUrl: room.photoUrl,
            creatorId: room.createdBy,
            createdByUserId: room.createdByUserId,
            members: members, // From cache if available, otherwise empty
            memberCount:
                room.membersCount, // Use members_count directly from API
            createdAt: room.createdAt,
            lastMessageTime: room.lastActive ?? room.updatedAt,
            lastMessage: _unreadManager.getLastMessage(
                room.id), // Use cached last message if available
            // CRITICAL FIX: Use UnreadCountManager as source of truth for unread counts
            // This ensures unread counts are accurate from the start
            unreadCount: _unreadManager.getUnreadCount(room.id),
            isUnread: _unreadManager.getUnreadCount(room.id) > 0,
          ));
        }

        debugPrint(
            '✅ [GroupsTab] INSTANT RENDER: Showing ${groupChats.length} groups immediately (from /rooms API only)');

        // Log if we have no groups (empty state)
        if (groupChats.isEmpty) {
          debugPrint('ℹ️ [GroupsTab] No groups found - will show empty state');
        }

        // Update UI IMMEDIATELY - no waiting, no blocking
        if (!mounted) return;

        // CRITICAL: Persist lastLoadedCompanyId IMMEDIATELY
        _lastLoadedCompanyId = companyId;

        setState(() {
          _groups = groupChats;
          _filterGroups(); // Apply filtering (removes left groups and applies search)
          _isLoading = false; // Stop loading - show empty state if no groups!
          _hasError = false;
          _errorMessage = null; // Clear any error messages
        });

        debugPrint('✅ [GroupsTab] Persisted lastLoadedCompanyId: $companyId');
        debugPrint(
            '⚡ [GroupsTab] List rendered in <200ms - no room info blocking');

        // Mark as loaded
        _hasLoadedOnce = true;
        _lastLoadTime = DateTime.now();

        // Update cache with lightweight groups (from /rooms API only)
        _cachedGroupsData = _CachedGroupsData(
          groups: List.from(groupChats), // Create copy for cache
          timestamp: DateTime.now(),
          companyId: companyId,
        );
        debugPrint(
            '✅ [GroupsTab] Cache updated with ${groupChats.length} groups (lightweight, from /rooms API)');

        // Clean up expired cache entries (keep cache size manageable)
        _cleanupExpiredCache();

        // CRITICAL FIX: Do NOT fetch messages for every room on tab load
        // This causes API storms and 429 errors during rapid tab switching
        // Messages will be loaded lazily:
        // - When list item becomes visible (viewport-based lazy load)
        // - When user opens that chat
        // - Only from cache if available (UnreadCountManager)
        //
        // REMOVED: _fetchLastMessagesInBackground(groupChats, companyId);
        // This prevents the API storm that causes 429 errors
        debugPrint(
            '✅ [GroupsTab] Group list rendered - messages will load lazily (on-demand)');

        // Notify parent that loading is complete

        // Verify we're showing the right data - check company_id again
        final verifySelectedFlatState = ref.read(selectedFlatProvider);
        final verifyCompanyId = verifySelectedFlatState.selectedSociety?.socId;
        if (verifyCompanyId != null && verifyCompanyId != companyId) {
          debugPrint(
              '⚠️ [GroupsTab] WARNING: Company changed during load! Requested: $companyId, Current: $verifyCompanyId');
          // Company changed during load - reload with new company_id (cancellable with generation check)
          _activationTimer?.cancel();
          _activationGeneration++; // Increment generation to cancel stale operations
          final scheduledGeneration = _activationGeneration;
          _activationTimer = Timer(const Duration(milliseconds: 100), () {
            // Validate generation before executing
            if (!mounted || scheduledGeneration != _activationGeneration) {
              if (scheduledGeneration != _activationGeneration) {
                debugPrint(
                    '⏹️ [GroupsTab] Cancelled company change reload (generation changed)');
              }
              return;
            }
            _loadGroups();
          });
        }
      } else {
        // Handle errors
        final statusCode = response.statusCode ?? 0;
        final errorMessage = response.displayError;

        // Handle 401/403 - clear list and show toast
        if (statusCode == 401 || statusCode == 403) {
          setState(() {
            _groups = [];
            _filteredGroups = [];
            _isLoading = false;
            _hasError = false;
            _errorMessage = null;
          });
          // Clear cache on auth error
          _cachedGroupsData = null;
          // Loading completed (even with error) - allow tab switching
          widget.loadingNotifier?.value = false;

          EnhancedToast.error(
            context,
            title: 'Error',
            message: 'Unable to load groups',
          );
        } else if (statusCode == 429) {
          // Rate limit error - too many requests
          // Handle gracefully: show cached data if available, retry after delay
          debugPrint('⚠️ [GroupsTab] Rate limit error (429) detected');
          setState(() {
            _isLoading = false;
            _hasError =
                false; // Don't show error state - use cached data instead
            _errorMessage = null;
          });
          _hasLoadedOnce = true; // Mark as loaded to prevent immediate retry
          _lastLoadTime = DateTime
              .now(); // Update last load time to prevent immediate retry

          // Loading completed (even with error) - allow tab switching
          widget.loadingNotifier?.value = false;

          // If we have cached groups, keep showing them silently
          if (_groups.isNotEmpty) {
            debugPrint(
                '✅ [GroupsTab] Rate limited (429) - showing cached data (${_groups.length} groups)');
            // Silently use cached data - no toast message to avoid spam
            // User can still see the groups from cache
          } else {
            // No cached data - only show message if this is the first time or after a delay
            // Don't spam the user with repeated messages
            debugPrint(
                '⚠️ [GroupsTab] Rate limited (429) - no cached data available');
            // Don't show toast - just log it and auto-retry silently
            // The user will see the loading state, and data will load when retry succeeds
          }

          // Auto-retry after a longer delay (10 seconds) if no cached data
          if (_groups.isEmpty) {
            _activationTimer?.cancel();
            final scheduledGeneration = _activationGeneration;
            _activationTimer = Timer(const Duration(seconds: 10), () {
              if (mounted &&
                  scheduledGeneration == _activationGeneration &&
                  !_isLoadingGroups) {
                debugPrint(
                    '🔄 [GroupsTab] Auto-retrying after rate limit (10s delay)...');
                _loadGroups();
              }
            });
          }
        } else if (statusCode >= 500) {
          // Server error - keep previous list if cached, don't crash
          setState(() {
            _isLoading = false;
            _hasError = false; // Don't show error state for 500
            _errorMessage = null;
          });
          _hasLoadedOnce = true; // Mark as loaded to prevent immediate retry
          _lastLoadTime = DateTime.now(); // Update last load time

          // Loading completed (even with error) - allow tab switching
          widget.loadingNotifier?.value = false;

          // Silently fail - don't show toast for 500 to avoid spam
          debugPrint(
              '⚠️ [GroupsTab] Server error ($statusCode), keeping cached list');
        } else {
          // Other errors
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = errorMessage;
          });
          _isLoadingGroups = false;

          // Don't clear cache on error - keep showing last known data
          // Loading completed (even with error) - allow tab switching
          widget.loadingNotifier?.value = false;

          if (statusCode == 0) {
            EnhancedToast.error(
              context,
              title: 'Network Error',
              message:
                  'Unable to connect. Please check your internet connection.',
            );
          } else {
            EnhancedToast.error(
              context,
              title: 'Error',
              message: errorMessage,
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) {
        // Ensure loading state is cleared even if not mounted
        widget.loadingNotifier?.value = false;
        return;
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'An unexpected error occurred: $e';
      });
      _hasLoadedOnce = true; // Mark as loaded to prevent immediate retry
      _lastLoadTime = DateTime.now(); // Update last load time

      // Don't clear cache on error - keep showing last known data
      // Loading completed (even with error) - allow tab switching
      widget.loadingNotifier?.value = false;

      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to load groups: $e',
      );
    }
  }

  /// Convert Room to GroupChat for UI compatibility
  /// If roomInfo is provided, members will be populated from room info
  GroupChat _convertRoomToGroupChat(Room room, {RoomInfo? roomInfo}) {
    // Convert room info members to IntercomContact list
    List<IntercomContact> members = [];
    if (roomInfo != null && roomInfo.members.isNotEmpty) {
      members = roomInfo.members.map((member) {
        return IntercomContact(
          id: member.userId,
          name: member.username ?? 'Unknown User',
          type: IntercomContactType.resident, // Default type
          status: IntercomContactStatus.offline, // Default status
          photoUrl: member.avatar, // Include avatar from API response
          numericUserId: member
              .numericUserId, // CRITICAL: Include numeric ID for API calls
        );
      }).toList();

      // Also include admin if available
      if (roomInfo.admin != null && roomInfo.admin!.userId != null) {
        final adminContact = IntercomContact(
          id: roomInfo.admin!.userId!,
          name: roomInfo.admin!.username ?? roomInfo.admin!.email ?? 'Admin',
          type: IntercomContactType.resident,
          status: IntercomContactStatus.offline,
          // Note: Admin avatar not available in RoomInfoAdmin, but can be found in members list
        );
        // Only add admin if not already in members list
        if (!members.any((m) => m.id == adminContact.id)) {
          members.add(adminContact);
        }
      }
    }

    return GroupChat(
      id: room.id,
      name: room.name,
      description: room.description,
      iconUrl: room.photoUrl, // Map photo_url to iconUrl
      creatorId: room.createdBy,
      createdByUserId: room.createdByUserId, // Pass numeric user ID
      members: members, // Populated from room info if available
      memberCount: room.membersCount ??
          roomInfo
              ?.memberCount, // Use members_count from /rooms API, fallback to roomInfo
      createdAt: room.createdAt,
      // Use last_active if available, otherwise fallback to updatedAt
      lastMessageTime: room.lastActive ?? room.updatedAt,
      lastMessage: _unreadManager
          .getLastMessage(room.id), // Use cached last message if available
      // CRITICAL FIX: Use UnreadCountManager as source of truth for unread counts
      // This ensures unread counts are accurate from the start
      unreadCount: _unreadManager.getUnreadCount(room.id),
      isUnread: _unreadManager.getUnreadCount(room.id) > 0,
    );
  }

  /// Fetch room info in background and update groups incrementally
  /// This allows UI to show data immediately while fresh data loads
  Future<void> _fetchRoomInfoInBackground(
    List<Room> roomsNeedingInfo,
    List<Room> allRooms,
    int companyId,
  ) async {
    if (roomsNeedingInfo.isEmpty || !mounted) return;

    debugPrint(
        '🔄 [GroupsTab] Fetching room info in background for ${roomsNeedingInfo.length} rooms...');

    // OPTIMIZED CONCURRENCY: Process in larger batches for faster loading
    const maxConcurrentRequests = 10;
    final freshRoomInfos = <String, RoomInfo?>{}; // Map roomId -> RoomInfo

    // TOKEN REUSE: Fetch token once for the entire batch
    try {
      await KeycloakService.getAccessToken();
    } catch (e) {
      debugPrint('⚠️ [GroupsTab] Failed to pre-fetch token: $e');
    }

    // Process rooms in batches
    for (int i = 0; i < roomsNeedingInfo.length; i += maxConcurrentRequests) {
      if (!mounted) return; // Check if still mounted

      final batch =
          roomsNeedingInfo.skip(i).take(maxConcurrentRequests).toList();
      final batchFutures = batch.map((room) async {
        try {
          final roomInfoResponse = await _roomService.getRoomInfo(
            roomId: room.id,
            companyId: companyId,
          );
          final roomInfo =
              roomInfoResponse.success && roomInfoResponse.data != null
                  ? roomInfoResponse.data
                  : null;

          // Cache the result
          if (mounted) {
            _roomInfoCache[room.id] = _CachedRoomInfo(
              roomInfo: roomInfo,
              timestamp: DateTime.now(),
            );
          }

          return MapEntry(room.id, roomInfo);
        } catch (e) {
          debugPrint(
              '⚠️ [GroupsTab] Failed to fetch info for room ${room.id}: $e');
          // Cache null result
          if (mounted) {
            _roomInfoCache[room.id] = _CachedRoomInfo(
              roomInfo: null,
              timestamp: DateTime.now(),
            );
          }
          return MapEntry(room.id, null as RoomInfo?);
        }
      }).toList();

      // Wait for batch to complete
      final batchResults = await Future.wait(batchFutures);
      freshRoomInfos.addAll(Map.fromEntries(batchResults));

      // Update UI incrementally after each batch
      if (mounted) {
        _updateGroupsWithFreshRoomInfo(allRooms, freshRoomInfos, companyId);
      }
    }

    debugPrint(
        '✅ [GroupsTab] Background room info fetch completed for ${freshRoomInfos.length} rooms');
  }

  /// Update groups list with fresh room info (called incrementally)
  void _updateGroupsWithFreshRoomInfo(
    List<Room> allRooms,
    Map<String, RoomInfo?> freshRoomInfos,
    int companyId,
  ) {
    if (!mounted) return;

    // Build complete room info map (cached + fresh)
    final allRoomInfos = <String, RoomInfo?>{};
    for (final room in allRooms) {
      // Check fresh data first, then cache
      if (freshRoomInfos.containsKey(room.id)) {
        allRoomInfos[room.id] = freshRoomInfos[room.id];
      } else {
        final cached = _roomInfoCache[room.id];
        if (cached != null &&
            DateTime.now().difference(cached.timestamp) <
                _roomInfoCacheExpiry) {
          allRoomInfos[room.id] = cached.roomInfo;
        }
      }
    }

    // Convert rooms to GroupChat with fresh member information
    final updatedGroupChats = <GroupChat>[];

    for (final room in allRooms) {
      final roomInfo = allRoomInfos[room.id];

      // Skip rooms without room info
      if (roomInfo == null) {
        continue;
      }

      // Only show rooms with 3+ members (group chats)
      if (roomInfo.memberCount < 3) {
        continue;
      }

      // This is a group chat (3+ members) - include it
      final groupChat = _convertRoomToGroupChat(room, roomInfo: roomInfo);
      updatedGroupChats.add(groupChat);
    }

    // Update UI with fresh data
    if (mounted) {
      setState(() {
        _groups = updatedGroupChats;
        _filterGroups(); // Apply filtering (removes left groups and applies search)
      });

      // Update cache with fresh data
      _cachedGroupsData = _CachedGroupsData(
        groups: List.from(updatedGroupChats),
        timestamp: DateTime.now(),
        companyId: companyId,
      );

      debugPrint(
          '✅ [GroupsTab] Updated groups list with fresh data: ${updatedGroupChats.length} groups');
    }
  }

  /// Helper method to check if a message is a system message
  bool _isSystemMessage(RoomMessage roomMessage) {
    // Check message_type and event_type
    final messageType = roomMessage.messageType?.toLowerCase();
    final eventType = roomMessage.eventType?.toLowerCase();

    if (messageType == 'system' || messageType == 'event') {
      return true;
    }

    if (eventType == 'user_left' ||
        eventType == 'message_deleted' ||
        eventType == 'user_joined') {
      return true;
    }

    // Check body content for system message patterns
    final bodyLower = roomMessage.body.toLowerCase();
    if (bodyLower.contains('joined the group') ||
        bodyLower.contains('left the group') ||
        bodyLower.contains('was deleted')) {
      return true;
    }

    return false;
  }

  /// Check if a WebSocket message is a system message (should not increment unread count)
  /// System messages include: admin actions, member add/remove, etc.
  bool _isSystemMessageFromWebSocket(WebSocketMessage wsMessage) {
    // Check message_type from WebSocket data
    final messageType = wsMessage.messageType?.toLowerCase() ??
        wsMessage.data?['message_type']?.toString().toLowerCase();
    final eventType = wsMessage.data?['event_type']?.toString().toLowerCase();

    // System message types
    if (messageType == 'system' || messageType == 'event') {
      return true;
    }

    // Event types that are system messages
    if (eventType == 'user_left' ||
        eventType == 'message_deleted' ||
        eventType == 'user_joined' ||
        eventType == 'user_added' ||
        eventType == 'user_removed') {
      return true;
    }

    // Check content for system message patterns
    final content = wsMessage.content ?? wsMessage.data?['content']?.toString() ?? '';
    final contentLower = content.toLowerCase();
    if (contentLower.contains('joined the group') ||
        contentLower.contains('left the group') ||
        contentLower.contains('was deleted') ||
        (contentLower.contains('added') && contentLower.contains('to the group')) ||
        (contentLower.contains('removed') && contentLower.contains('from the group'))) {
      return true;
    }

    return false;
  }

  /// Fetch last messages for all groups in background and update UI
  Future<void> _fetchLastMessagesInBackground(
    List<GroupChat> groups,
    int companyId,
  ) async {
    if (groups.isEmpty || !mounted) return;

    debugPrint(
        '🔄 [GroupsTab] Fetching last messages for ${groups.length} groups...');

    // Process in batches to avoid overwhelming the API
    const maxConcurrentRequests = 10;
    final lastMessageData = <String, _LastMessageData>{};

    // Process groups in batches
    for (int i = 0; i < groups.length; i += maxConcurrentRequests) {
      if (!mounted) return;

      final batch = groups.skip(i).take(maxConcurrentRequests).toList();
      final batchFutures = batch.map((group) async {
        try {
          final messagesResponse = await _roomService
              .getMessages(
            roomId: group.id,
            companyId: companyId,
            limit:
                5, // Fetch a few messages to get the latest (API returns oldest first)
            offset: 0,
          )
              .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint(
                  '⏱️ [GroupsTab] Timeout fetching last message for ${group.id}');
              return ApiResponse.error('Request timeout', statusCode: 408);
            },
          );

          String? lastMessage;
          // CRITICAL FIX: Use UnreadCountManager as source of truth for unread counts
          // This ensures unread counts persist across app sessions and are accurate
          int unreadCount = _unreadManager.getUnreadCount(group.id);
          bool isUnread = unreadCount > 0;
          DateTime lastMessageTime = group.lastMessageTime;

          if (messagesResponse.success && messagesResponse.data != null) {
            final messages = messagesResponse.data!;
            if (messages.isNotEmpty) {
              // Filter out system messages
              final nonSystemMessages =
                  messages.where((msg) => !_isSystemMessage(msg)).toList();

              if (nonSystemMessages.isNotEmpty) {
                // API returns messages in chronological order (oldest first)
                // So the last item is the newest message
                final latestMessage = nonSystemMessages.last;
                final preview = ActivityPreviewHelper.fromContent(
                  latestMessage.body,
                  messageType: latestMessage.messageType,
                );
                lastMessage = preview.text.isNotEmpty ? preview.text : null;
                lastMessageTime = latestMessage.createdAt;

                // CRITICAL FIX: Update last message in UnreadCountManager if we have a new message
                // This ensures the last message is cached for future use
                if (lastMessage != null && lastMessage.isNotEmpty) {
                  _unreadManager.updateLastMessage(
                    group.id,
                    lastMessage,
                    lastMessageTime,
                  );
                }

                // CRITICAL FIX: Re-fetch unread count after updating last message
                // This ensures we have the latest count from UnreadCountManager
                unreadCount = _unreadManager.getUnreadCount(group.id);
                isUnread = unreadCount > 0;
              }
            }
          }

          return MapEntry(
            group.id,
            _LastMessageData(
              lastMessage: lastMessage,
              unreadCount: unreadCount,
              isUnread: isUnread,
              lastMessageTime: lastMessageTime,
            ),
          );
        } catch (e) {
          debugPrint(
              '⚠️ [GroupsTab] Failed to fetch last message for ${group.id}: $e');
          return MapEntry(
            group.id,
            _LastMessageData(
              lastMessage: null,
              unreadCount: 0,
              isUnread: false,
              lastMessageTime: group.lastMessageTime,
            ),
          );
        }
      }).toList();

      // Wait for batch to complete
      final batchResults = await Future.wait(batchFutures);
      lastMessageData.addAll(Map.fromEntries(batchResults));

      // Update UI incrementally after each batch
      if (mounted) {
        _updateGroupsWithLastMessages(lastMessageData);
      }
    }

    debugPrint(
        '✅ [GroupsTab] Background last message fetch completed for ${lastMessageData.length} groups');
  }

  /// Update groups list with last message data
  void _updateGroupsWithLastMessages(
    Map<String, _LastMessageData> lastMessageData,
  ) {
    if (!mounted) return;

    final updatedGroups = _groups.map((group) {
      final messageData = lastMessageData[group.id];
      if (messageData == null) {
        return group; // No update available
      }

      return group.copyWith(
        lastMessage: messageData.lastMessage,
        unreadCount: messageData.unreadCount,
        isUnread: messageData.isUnread,
        lastMessageTime: messageData.lastMessageTime,
      );
    }).toList();

    if (mounted) {
      setState(() {
        _groups = updatedGroups;
        _filterGroups(); // Apply filtering (removes left groups and applies search)
      });

      // Update cache with fresh data
      final companyId = _lastLoadedCompanyId;
      if (companyId != null) {
        _cachedGroupsData = _CachedGroupsData(
          groups: List.from(updatedGroups),
          timestamp: DateTime.now(),
          companyId: companyId,
        );
      }

      debugPrint(
          '✅ [GroupsTab] Updated groups with last messages: ${updatedGroups.length} groups');
    }
  }

  List<IntercomContact> _getMockMembers() {
    // Return mock society members for the groups
    return [
      IntercomContact(
        id: '1',
        name: 'Rahul Verma',
        unit: 'A-101',
        building: 'A',
        floor: '1',
        type: IntercomContactType.resident,
        status: IntercomContactStatus.online,
        phoneNumber: '+91 9876543101',
      ),
      IntercomContact(
        id: '2',
        name: 'Priya Sharma',
        unit: 'A-102',
        building: 'A',
        floor: '1',
        type: IntercomContactType.resident,
        phoneNumber: '+91 9876543104',
      ),
      IntercomContact(
        id: '3',
        name: 'Amit Patel',
        unit: 'B-203',
        building: 'B',
        floor: '2',
        type: IntercomContactType.resident,
        status: IntercomContactStatus.online,
        phoneNumber: '+91 9876543105',
      ),
      IntercomContact(
        id: '4',
        name: 'Neha Singh',
        unit: 'B-201',
        building: 'B',
        floor: '2',
        type: IntercomContactType.resident,
        status: IntercomContactStatus.busy,
        phoneNumber: '+91 9876543107',
      ),
      IntercomContact(
        id: '5',
        name: 'Raj Kumar',
        unit: 'C-304',
        building: 'C',
        floor: '3',
        type: IntercomContactType.resident,
        status: IntercomContactStatus.away,
        phoneNumber: '+91 9876543108',
      ),
      IntercomContact(
        id: '6',
        name: 'Sheetal Mishra',
        unit: 'D-402',
        building: 'D',
        floor: '4',
        type: IntercomContactType.resident,
        status: IntercomContactStatus.online,
        phoneNumber: '+91 9876543109',
      ),
      IntercomContact(
        id: 'c1',
        name: 'Vikram Singh',
        role: 'Chairman',
        type: IntercomContactType.committee,
        status: IntercomContactStatus.online,
        phoneNumber: '+91 9876543301',
      ),
      IntercomContact(
        id: 'c2',
        name: 'Anita Desai',
        role: 'Secretary',
        type: IntercomContactType.committee,
        status: IntercomContactStatus.busy,
        phoneNumber: '+91 9876543302',
      ),
      IntercomContact(
        id: 'c3',
        name: 'Raj Malhotra',
        role: 'Treasurer',
        type: IntercomContactType.committee,
        phoneNumber: '+91 9876543303',
      ),
      IntercomContact(
        id: 'c5',
        name: 'Akash Kumar',
        role: 'Sports Secretary',
        type: IntercomContactType.committee,
        status: IntercomContactStatus.away,
        phoneNumber: '+91 9876543305',
      ),
      if (_currentUserId != null)
        IntercomContact(
          id: _currentUserId!,
          name: 'You (Current User)',
          unit: 'B-101',
          building: 'B',
          floor: '1',
          type: IntercomContactType.resident,
          status: IntercomContactStatus.online,
          phoneNumber: '+91 9876543399',
        ),
    ];
  }

  void _navigateToGroupChat(GroupChat group) {
    if (_currentUserId == null) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'User ID not available. Please try again.',
      );
      return;
    }

    // Mark group as opened when user navigates to it
    _markGroupAsOpened(group.id);

    // Navigate to group chat and handle return with immediate refresh
    NavigationHelper.pushRoute(
      context,
      MaterialPageRoute(
        builder: (context) => GroupChatScreen(
          group: group,
          currentUserId: _currentUserId!,
          currentUserNumericId: _currentUserNumericId,
        ),
      ),
    ).then((_) {
      // CRITICAL: When user returns from GroupChatScreen, immediately check for updates
      // This handles the case where tab is already active and didChangeDependencies might not fire
      debugPrint(
          '🔄 [GroupsTab] User returned from GroupChatScreen, checking for updates...');

      // Multiple checks to ensure refresh happens:
      // 1. Immediate check (in case flag was set)
      if (mounted && GroupsTab._groupUpdated) {
        debugPrint(
            '🔄 [GroupsTab] Group update detected immediately on return - refreshing...');
        _checkGroupUpdateAndRefresh();
      }

      // 2. Post-frame callback check (ensures widget is built)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && GroupsTab._groupUpdated) {
          debugPrint(
              '🔄 [GroupsTab] Group update detected in postFrameCallback - refreshing...');
          _checkGroupUpdateAndRefresh();
        }
      });

      // 3. Delayed check as fallback (handles any timing issues)
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && GroupsTab._groupUpdated) {
          debugPrint(
              '🔄 [GroupsTab] Group update detected in delayed check - refreshing...');
          _checkGroupUpdateAndRefresh();
        }
      });
    });
  }

  void _navigateToCreateGroup() async {
    // Get available contacts
    final availableContacts = _getMockMembers();

    // Check if there are available contacts
    if (availableContacts.isEmpty) {
      // Show error if no contacts are available
      EnhancedToast.error(
        context,
        title: 'No Contacts',
        message: 'No contacts available to create a group',
      );
      return;
    }

    // Navigate to create group page with page route transition
    final result = await NavigationHelper.pushRoute(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CreateGroupPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );

    // Handle result
    if (result != null && result is GroupChat) {
      // OPTIMISTIC UPDATE: Immediately add new group to the list for instant UI feedback
      // This ensures the new group appears immediately even before API refresh completes
      if (mounted) {
        setState(() {
          // Check if group already exists (avoid duplicates)
          final exists = _groups.any((g) => g.id == result.id);
          if (!exists) {
            _groups.insert(0, result); // Add to top of list
            _filterGroups(); // Re-apply filtering
            debugPrint(
                '⚡ [GroupsTab] Optimistically added new group: ${result.name}');
          }
        });
      }

      // CRITICAL FIX: Invalidate cache immediately after group creation
      // This ensures the next _loadGroups call will fetch fresh data from API
      _invalidateGroupsCache();

      // Immediately refresh groups list from API to get latest data
      // No delay - call API immediately for fast loading like Postman
      if (mounted && !_isLoadingGroups) {
        try {
          await _loadGroups(force: true);
          debugPrint(
              '✅ [GroupsTab] Refreshed groups list after group creation (immediate)');
        } catch (e) {
          debugPrint(
              '⚠️ [GroupsTab] Failed to refresh groups list after creation: $e');
          // Optimistic update already added the group, so no fallback needed
        }
      }

      // Show success notification
      EnhancedToast.success(
        context,
        title: 'Group Created',
        message: 'Group created successfully!',
      );
    }
  }

  void _navigateToNeighbourScreen() {
    NavigationHelper.pushRoute(
      context,
      MaterialPageRoute(
        builder: (context) => const NeighbourScreen(),
      ),
    );
  }

  // Add a method to navigate to edit group page
  void _navigateToEditGroup(GroupChat group) async {
    // Only creators (admins) can edit groups
    if (group.creatorId != _currentUserId) {
      EnhancedToast.error(
        context,
        title: 'Access Denied',
        message: 'Only group admin can edit this group',
      );
      return;
    }

    // Navigate to edit group page with the existing group data
    final result = await NavigationHelper.pushRoute(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CreateGroupPage(groupToEdit: group),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );

    // Handle the updated group
    if (result != null && result is GroupChat) {
      // Immediately refresh groups list from API to get latest data
      // No delay - call API immediately for fast loading like Postman
      if (mounted && !_isLoadingGroups) {
        try {
          await _loadGroups(force: true);
          debugPrint(
              '✅ [GroupsTab] Refreshed groups list after group update (immediate)');
        } catch (e) {
          debugPrint('⚠️ [GroupsTab] Failed to refresh groups list: $e');
          // Fallback: update local state if refresh fails
          if (mounted) {
            setState(() {
              final index = _groups.indexWhere((g) => g.id == result.id);
              if (index != -1) {
                _groups[index] = result;
                // Also update filtered groups if it exists there
                final filteredIndex =
                    _filteredGroups.indexWhere((g) => g.id == result.id);
                if (filteredIndex != -1) {
                  _filteredGroups[filteredIndex] = result;
                }
              }
            });
          }
        }
      }

      // Show success notification
      EnhancedToast.success(
        context,
        title: 'Group Updated',
        message: 'Group updated successfully!',
      );
    }
  }

  /// Check if user can delete a group (only creator can delete)
  bool _canDeleteGroup(GroupChat group) {
    // First try to compare using numeric user ID (preferred)
    if (_currentUserNumericId != null && group.createdByUserId != null) {
      return _currentUserNumericId == group.createdByUserId;
    }
    // Fallback to UUID comparison for backward compatibility
    return _currentUserId != null && group.creatorId == _currentUserId;
  }

  /// Delete a group with confirmation and API call
  Future<void> _deleteGroup(GroupChat group) async {
    // Only creators can delete groups
    if (!_canDeleteGroup(group)) {
      EnhancedToast.error(
        context,
        title: 'Access Denied',
        message: 'You are not allowed to delete this group',
      );
      return;
    }

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              const Text(
                'Delete Group',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Message
              Text(
                'This group will be permanently deleted. This action cannot be undone.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Buttons
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.black,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Delete Button
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.red.shade400,
                            Colors.red.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldDelete != true || !mounted) return;

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Call delete API
      final response = await _roomService.deleteRoom(group.id);

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      if (response.success) {
        // Immediately refresh groups list from API to get latest data
        // No delay - call API immediately for fast loading like Postman
        if (mounted && !_isLoadingGroups) {
          try {
            await _loadGroups(force: true);
            debugPrint(
                '✅ [GroupsTab] Refreshed groups list after group deletion (immediate)');
          } catch (e) {
            debugPrint(
                '⚠️ [GroupsTab] Failed to refresh groups list after deletion: $e');
            // Fallback: remove from local state if refresh fails
            if (mounted) {
              setState(() {
                _groups.removeWhere((g) => g.id == group.id);
                _filteredGroups.removeWhere((g) => g.id == group.id);
              });
            }
          }
        }

        // Show success notification
        EnhancedToast.success(
          context,
          title: 'Group Deleted',
          message: 'Group deleted successfully',
        );

        // Check if user is currently in this group chat and navigate back
        // This is handled by the navigation system automatically
      } else {
        // Handle errors based on status code
        final statusCode = response.statusCode ?? 0;
        if (statusCode == 403) {
          EnhancedToast.error(
            context,
            title: 'Access Denied',
            message: 'You are not allowed to delete this group',
          );
        } else if (statusCode == 404) {
          // Group already deleted - remove from UI silently
          setState(() {
            _groups.removeWhere((g) => g.id == group.id);
            _filteredGroups.removeWhere((g) => g.id == group.id);
          });
        } else if (statusCode >= 500) {
          // Server error - show retry dialog
          _showRetryDialog(group);
        } else {
          EnhancedToast.error(
            context,
            title: 'Error',
            message: response.displayError,
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
        EnhancedToast.error(
          context,
          title: 'Error',
          message: 'Failed to delete group: $e',
        );
      }
    }
  }

  /// Show retry dialog for server errors
  void _showRetryDialog(GroupChat group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: const Text(
          'Failed to delete group due to server error. Would you like to try again?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteGroup(group);
            },
            child: const Text('RETRY'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check for company change on every build to ensure we catch changes
    // This is more reliable than didChangeDependencies which may not be called
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCompanyChangeAndReload();

      // CRITICAL: Also check for group updates on every build
      // This ensures refresh happens even if didChangeDependencies doesn't fire
      // This is especially important when navigating back from GroupChatScreen
      // while the GroupsTab is already active
      if (GroupsTab._groupUpdated) {
        debugPrint(
            '🔄 [GroupsTab] Group update detected in build() - immediately refreshing...');
        _checkGroupUpdateAndRefresh();
      }
    });

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            children: [
            // Groups info card with gradient
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with gradient
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, Color(0xFFFF9292)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Background large icon for depth effect
                          // Positioned(
                          //   right: -10,
                          //   top: -10,
                          //   child: Icon(
                          //     Icons.group_rounded,
                          //     color: Colors.white.withOpacity(0.2),
                          //     size: 64,
                          //   ),
                          // ),
                          // // Main content
                          Row(
                            children: [
                              const Icon(
                                Icons.group_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Chat Groups',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              // WebSocket connection status indicator
                              Tooltip(
                                message: _isWebSocketConnected
                                    ? 'Real-time messaging active'
                                    : 'Real-time messaging unavailable',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _isWebSocketConnected
                                            ? Colors.green.shade300
                                            : Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isWebSocketConnected
                                          ? 'Online'
                                          : 'Offline',
                                      style: GoogleFonts.montserrat(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Info content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create and join groups to communicate with other society members on specific topics.',
                            style: GoogleFonts.montserrat(
                              color: Colors.grey.shade800,
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  // boxShadow: [
                                  //   BoxShadow(
                                  //     color: Colors.red.withOpacity(0.1),
                                  //     blurRadius: 4,
                                  //     offset: const Offset(0, 2),
                                  //   ),
                                  // ],
                                ),
                                child: Text(
                                  'Total: ${_groups.length}',
                                  style: GoogleFonts.montserrat(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: AppColors.blackToGreyGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: _navigateToCreateGroup,
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Create Group',
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Enhanced search bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search groups...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: const Color(0xFFEE4D5F).withOpacity(0.7),
                    size: 20,
                  ),
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEE4D5F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color:
                            _isListening ? Colors.red : const Color(0xFFEE4D5F),
                        size: 20,
                      ),
                      onPressed:
                          _isListening ? _stopListening : _startListening,
                      tooltip: 'Voice Search',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),

            // Groups list
            Expanded(
              child: Builder(
                builder: (context) {
                  final groupsToShow =
                      _searchQuery.isEmpty ? _groups : _filteredGroups;
                  final hasGroups = groupsToShow.isNotEmpty;
                  if (_hasError && _groups.isEmpty) {
                    return _buildErrorState();
                  }
                  if (_isLoading && !hasGroups) {
                    return const Center(
                      child: AppLoader(
                        title: 'Loading Groups',
                        subtitle: 'Fetching your group chats...',
                        icon: Icons.chat_rounded,
                      ),
                    );
                  }
                  if (!hasGroups) {
                    return _buildEmptyState();
                  }
                  return _isLoading
                      ? const Center(
                          child: AppLoader(
                            title: 'Loading Groups',
                            subtitle: 'Fetching your group chats...',
                            icon: Icons.chat_rounded,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadGroups,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: groupsToShow.length,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              final group = groupsToShow[index];
                              // Match 1-to-1 logic: show indicator when unread > 0 regardless of opened flag
                              final isOpened = group.unreadCount == 0 &&
                                  _openedGroups.contains(group.id);
                              return _buildGroupCard(group, isOpened: isOpened);
                            },
                          ),
                        );
                },
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.group_outlined,
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No groups found',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a new group to start chatting',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.blackToGreyGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _navigateToCreateGroup,
                        icon: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          'Create Group',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build error state UI with retry option
  Widget _buildErrorState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.shade50,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: 28,
                        color: Colors.red.shade300,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load groups',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadGroups,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupCard(GroupChat group, {bool isOpened = false}) {
    final bool isAdmin = group.creatorId == _currentUserId;

    // Match the exact behavior from _ChatHistoryItem in chat & call history
    // If chat has been opened before, always show last message (no count, no badge, no indicator)
    // If chat hasn't been opened, show count/new messages with badge and indicator
    final lastMessagePreview =
        ActivityPreviewHelper.fromStored(group.lastMessage);
    final String lastMessageText = lastMessagePreview.text;
    String displayMessage;
    bool showIndicator = false;
    bool showBadge = false;
    bool useMessagePreview = false;
    const Color unreadAccent = AppColors.success;

    // Check if there are any messages in the group
    final hasMessages =
        lastMessageText.isNotEmpty && lastMessageText != 'No messages yet';

    if (!hasMessages) {
      // No messages in the group: show "No messages yet"
      displayMessage = 'No messages yet';
      showIndicator = false;
      showBadge = false;
    } else if (isOpened) {
      // Group has been opened: show last message only, no count, no badge, no indicator
      displayMessage = lastMessageText;
      showIndicator = false;
      showBadge = false;
      useMessagePreview = true;
    } else {
      // Group hasn't been opened: show count/new messages with badge and indicator
      if (group.unreadCount > 1) {
        // More than 1 unread message: show count with "new messages"
        displayMessage = '${group.unreadCount} new messages';
        showIndicator = true;
        showBadge = true;
      } else if (group.unreadCount == 1) {
        // Exactly 1 unread message: show first 10 characters (matching chat history behavior)
        if (lastMessageText.isNotEmpty &&
            lastMessageText != 'No messages yet') {
          displayMessage = lastMessageText.length > 10
              ? '${lastMessageText.substring(0, 10)}...'
              : lastMessageText;
        } else {
          displayMessage = 'New message';
        }
        showIndicator = true;
        showBadge = true;
        useMessagePreview = true;
      } else {
        // No unread messages: show last message (may be from sender)
        displayMessage = lastMessageText;
        showIndicator = false;
        showBadge = false;
        useMessagePreview = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.grey.shade100,
          ),
        ),
        color: Colors.white,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: () => _navigateToGroupChat(group),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar with status
                    Stack(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: group.iconUrl != null &&
                                  group.iconUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(25),
                                  child: Image.network(
                                    group.iconUrl!,
                                    key: ValueKey(
                                        '${group.id}_${group.iconUrl}'), // Force reload when iconUrl changes
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    cacheWidth: 100, // Optimize cache
                                    cacheHeight: 100,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback to initials if image fails to load
                                      return Center(
                                        child: Text(
                                          group.initials,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      );
                                    },
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      // Show initials while loading
                                      return Center(
                                        child: Text(
                                          group.initials,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    group.initials,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 12),

                    // Group details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  group.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: showIndicator
                                        ? Colors.black
                                        : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Time and badge column (matching chat history layout)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _getTimeAgo(group.lastMessageTime),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: showIndicator
                                          ? unreadAccent
                                          : Colors.grey.shade600,
                                      fontWeight: showIndicator
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  // CRITICAL FIX: Remove redundant !isOpened check
                                  // showBadge is already false when isOpened is true
                                  if (showBadge && group.unreadCount > 0) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: unreadAccent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        group.unreadCount > 99
                                            ? '99+'
                                            : group.unreadCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Members count display
                          Row(
                            children: [
                              Icon(
                                Icons.people,
                                color: Colors.grey.shade600,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                group.memberCountDisplay,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (group.creatorId == _currentUserId)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEE4D5F)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Admin',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFEE4D5F),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Last message or new messages count (matching chat history layout)
                          Row(
                            children: [
                              if (useMessagePreview &&
                                  lastMessagePreview.hasIcon) ...[
                                Icon(
                                  lastMessagePreview.icon,
                                  size: 16,
                                  color: showIndicator
                                      ? unreadAccent
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  displayMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: showIndicator
                                        ? unreadAccent
                                        : Colors.grey.shade600,
                                    fontWeight: showIndicator
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Chat button
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => _navigateToGroupChat(group),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 18,
                                color: Colors.blue,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Chat',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Delete button - only show if user is creator
                    if (_canDeleteGroup(group)) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => _deleteGroup(group),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  void _handleCreateGroup() {
    if (_currentUserId == null) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'User ID not available. Please try again.',
      );
      return;
    }
    NavigationHelper.pushRoute(
      context,
      MaterialPageRoute(
        builder: (context) => CreateGroupScreen(
          availableContacts: _getMockMembers(),
          currentUserId: _currentUserId!,
        ),
      ),
    ).then((newGroup) {
      if (newGroup != null && newGroup is GroupChat) {
        setState(() {
          _groups.insert(0, newGroup);
        });
      }
    });
  }

  void _showGroupInfoBottomSheet(GroupChat group) async {
    // Show loading bottom sheet first with OneApp global loader
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: AppLoader(),
          ),
        ),
      ),
    );

    try {
      // Get company_id for API call from selectedFlatProvider
      final selectedFlatState = ref.read(selectedFlatProvider);
      final companyId = selectedFlatState.selectedSociety?.socId;
      if (companyId == null) {
        if (mounted) {
          Navigator.pop(context);
          EnhancedToast.error(
            context,
            title: 'Error',
            message: 'Please select a society first',
          );
        }
        return;
      }

      // Check cache first
      final cached = _roomInfoCache[group.id];
      RoomInfo? roomInfo;

      if (cached != null &&
          DateTime.now().difference(cached.timestamp) < _roomInfoCacheExpiry &&
          cached.roomInfo != null) {
        // Use cached data
        roomInfo = cached.roomInfo;
        debugPrint(
            '✅ [GroupsTab] Using cached room info for info bottom sheet: ${group.id}');
        // Close loading sheet
        Navigator.pop(context);
        _showGroupInfoBottomSheetContent(group, roomInfo!);
      } else {
        // Fetch fresh data
        final response = await _roomService.getRoomInfo(
          roomId: group.id,
          companyId: companyId,
        );

        if (!mounted) return;

        // Close loading sheet
        Navigator.pop(context);

        if (!response.success || response.data == null) {
          // Handle errors
          final statusCode = response.statusCode ?? 0;
          if (statusCode == 403 || statusCode == 404) {
            EnhancedToast.error(
              context,
              title: 'Error',
              message: 'Group information unavailable',
            );
          } else {
            EnhancedToast.error(
              context,
              title: 'Error',
              message: response.displayError,
            );
          }
          return;
        }

        roomInfo = response.data!;
        // Cache the result
        _roomInfoCache[group.id] = _CachedRoomInfo(
          roomInfo: roomInfo,
          timestamp: DateTime.now(),
        );
        _showGroupInfoBottomSheetContent(group, roomInfo);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        EnhancedToast.error(
          context,
          title: 'Error',
          message: 'Group information unavailable',
        );
      }
    }
  }

  void _showGroupInfoBottomSheetContent(GroupChat group, RoomInfo roomInfo) {
    // Determine visibility rules
    final isCreator = roomInfo.createdBy == _currentUserId;
    final isMember = roomInfo.members.any((m) => m.userId == _currentUserId);
    final showLeave = isMember && !isCreator;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      elevation: 10,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -1),
            ),
          ],
        ),
        padding: const EdgeInsets.only(top: 8),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Stack(
              children: [
                // Main content
                SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),

                      // Additional top padding due to close button
                      const SizedBox(height: 16),

                      // Group header with avatar
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Row(
                          children: [
                            // Group Avatar
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: group.iconUrl != null &&
                                      group.iconUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: Image.network(
                                        group.iconUrl!,
                                        key: ValueKey(
                                            '${group.id}_${group.iconUrl}'), // Force reload when iconUrl changes
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        cacheWidth: 120, // Optimize cache
                                        cacheHeight: 120,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          // Fallback to initials if image fails to load
                                          return Center(
                                            child: Text(
                                              group.initials,
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 24,
                                              ),
                                            ),
                                          );
                                        },
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          // Show initials while loading
                                          return Center(
                                            child: Text(
                                              group.initials,
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 24,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        group.initials,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 16),

                            // Group Name and Member Count
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          roomInfo.name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (isCreator)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: AppColors.primary,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _navigateToEditGroup(group);
                                          },
                                          tooltip: 'Edit Group',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 30,
                                            minHeight: 30,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.people,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${roomInfo.memberCount} ${roomInfo.memberCount == 1 ? 'member' : 'members'}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      _buildDivider(),

                      // Group Description
                      if (roomInfo.description != null &&
                          roomInfo.description!.isNotEmpty) ...[
                        InfoSection(
                          title: 'Description',
                          icon: Icons.info_outline,
                          content: roomInfo.description!,
                          color: AppColors.primary,
                        ),
                        _buildDivider(),
                      ],

                      // Created Date
                      InfoSection(
                        title: 'Created',
                        icon: Icons.calendar_today,
                        content:
                            '${roomInfo.createdAt.day}/${roomInfo.createdAt.month}/${roomInfo.createdAt.year}',
                        color: AppColors.primary,
                      ),
                      _buildDivider(),

                      // Last Active Time
                      if (roomInfo.lastActive != null)
                        InfoSection(
                          title: 'Last Active',
                          icon: Icons.access_time,
                          content: _getTimeAgo(roomInfo.lastActive!),
                          color: AppColors.primary,
                        ),
                      if (roomInfo.lastActive != null) _buildDivider(),

                      // Group Members
                      _buildGroupMembersSectionFromInfo(group, roomInfo),
                      _buildDivider(),

                      // Group Rules section hidden
                      // _buildGroupRulesSection(),
                      // _buildDivider(),

                      // Action buttons (Delete/Leave)
                      if (isCreator || showLeave)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Column(
                            children: [
                              if (isCreator)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteGroup(group);
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Delete Group'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                      // Bottom padding
                      const SizedBox(height: 40),
                    ],
                  ),
                ),

                // Close button
                Positioned(
                  top: 16,
                  right: 16,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.grey.withOpacity(0.1),
      ),
    );
  }

  Widget _buildAdminSection(GroupChat group) {
    // Find the admin in members list
    final admin = group.members.firstWhere(
      (member) => member.id == group.creatorId,
      orElse: () => IntercomContact(
        id: 'unknown',
        name: 'Unknown Admin',
        type: IntercomContactType.resident,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Admin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    admin.name.isNotEmpty ? admin.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (admin.role != null && admin.role!.isNotEmpty)
                      Text(
                        admin.role!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSectionFromInfo(RoomInfo roomInfo) {
    final adminName = roomInfo.admin?.username ?? 'Unknown Admin';
    final adminEmail = roomInfo.admin?.email;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Admin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    adminName.isNotEmpty ? adminName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (adminEmail != null && adminEmail.isNotEmpty)
                      Text(
                        adminEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupMembersSection(GroupChat group) {
    // Show first 5 members with a "View All" option
    final displayedMembers = group.members.take(5).toList();
    final hasMore = group.members.length > 5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Members',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (hasMore)
                TextButton(
                  onPressed: () {
                    NavigationHelper.pushRoute(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupMembersScreen(group: group),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'View All (${group.members.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            color: Colors.grey.withOpacity(0.2),
            thickness: 1,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedMembers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final member = displayedMembers[index];
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey.withOpacity(0.1),
                      backgroundImage: (member.photoUrl != null &&
                              member.photoUrl!.isNotEmpty)
                          ? NetworkImage(member.photoUrl!)
                          : null,
                      onBackgroundImageError: (member.photoUrl != null &&
                              member.photoUrl!.isNotEmpty)
                          ? (exception, stackTrace) {
                              // Fallback to initials if image fails to load
                            }
                          : null,
                      child:
                          (member.photoUrl == null || member.photoUrl!.isEmpty)
                              ? Text(
                                  member.name.isNotEmpty
                                      ? member.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (member.unit != null && member.unit!.isNotEmpty)
                          Text(
                            member.unit!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                    if (member.id == group.creatorId)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupMembersSectionFromInfo(GroupChat group, RoomInfo roomInfo) {
    // Show all members with scrolling - no "View All" button
    final allMembers = roomInfo.members;

    // If members list is empty, show AppLoader as loading indicator
    if (allMembers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.people,
                  size: 20,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Members',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              color: Colors.grey.withOpacity(0.2),
              thickness: 1,
            ),
            const SizedBox(height: 24),
            const Center(
              child: AppLoader(
                title: 'Loading Members',
                subtitle: 'Fetching group members...',
                icon: Icons.people,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.people,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Members',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            color: Colors.grey.withOpacity(0.2),
            thickness: 1,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allMembers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final member = allMembers[index];
                final isAdmin = member.isAdmin;
                // Use username if available, otherwise fallback to userId
                final displayName = member.username?.isNotEmpty == true
                    ? member.username!
                    : (member.userId.isNotEmpty
                        ? member.userId.substring(
                            0,
                            member.userId.length > 10
                                ? 10
                                : member.userId.length)
                        : 'User');
                final displayText = member.username?.isNotEmpty == true
                    ? member.username!
                    : (member.userId.isNotEmpty ? member.userId : 'User');

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey.withOpacity(0.1),
                      backgroundImage:
                          (member.avatar != null && member.avatar!.isNotEmpty)
                              ? NetworkImage(member.avatar!)
                              : null,
                      onBackgroundImageError:
                          (member.avatar != null && member.avatar!.isNotEmpty)
                              ? (exception, stackTrace) {
                                  // Fallback to initials if image fails to load
                                }
                              : null,
                      child: (member.avatar == null || member.avatar!.isEmpty)
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayText,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (member.joinedAt != null)
                            Text(
                              'Joined ${_getTimeAgo(member.joinedAt!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Start voice listening
  Future<void> _startListening() async {
    final result = await NavigationHelper.pushRoute<String>(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceSearchScreen(
          onTextRecognized: (text) {
            // Update search field with recognized text in real-time
            if (mounted) {
              setState(() {
                _searchController.text = text;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: text.length),
                );
                _searchQuery = text;
                _filterGroups();
              });
            }
          },
          onFinalResult: (text) {
            // Final result - set text and filter
            if (mounted) {
              setState(() {
                _searchController.text = text;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: text.length),
                );
                _searchQuery = text;
                _filterGroups();
              });
            }
          },
        ),
      ),
    );

    // Update state after returning from voice search screen
    if (mounted && result != null) {
      setState(() {
        _isListening = false;
      });
    }
  }

  // Stop voice listening
  void _stopListening() {
    _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  // Build Group Rules Section with point-wise format
  Widget _buildGroupRulesSection() {
    // Define group rules
    final List<String> rules = [
      'Be respectful to other members at all times',
      'No spam or promotional content allowed',
      'Keep discussions relevant to the group topic',
      'No sharing of personal information without consent',
      'Follow the guidelines set by group administrators',
      'Report any inappropriate behavior to admins',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.rule,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Group Rules',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rules.asMap().entries.map((entry) {
                final index = entry.key;
                final rule = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < rules.length - 1 ? 12 : 0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6, right: 12),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          rule,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            height: 1.5,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for info sections
  Widget InfoSection({
    required String title,
    required IconData icon,
    required String content,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.5,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Screen to display all group members
class GroupMembersScreen extends StatelessWidget {
  final GroupChat group;

  const GroupMembersScreen({
    Key? key,
    required this.group,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${group.name} - Members'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Column(
        children: [
          // Header with member count
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  '${group.members.length} ${group.members.length == 1 ? 'Member' : 'Members'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: Colors.grey.withOpacity(0.2),
            thickness: 1,
            height: 1,
          ),
          // Members list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: group.members.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.grey.withOpacity(0.2),
                thickness: 1,
              ),
              itemBuilder: (context, index) {
                final member = group.members[index];
                final isAdmin = member.id == group.creatorId;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: isAdmin
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    backgroundImage:
                        (member.photoUrl != null && member.photoUrl!.isNotEmpty)
                            ? NetworkImage(member.photoUrl!)
                            : null,
                    onBackgroundImageError:
                        (member.photoUrl != null && member.photoUrl!.isNotEmpty)
                            ? (exception, stackTrace) {
                                // Fallback to initials if image fails to load
                              }
                            : null,
                    child: (member.photoUrl == null || member.photoUrl!.isEmpty)
                        ? Text(
                            member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color:
                                  isAdmin ? AppColors.primary : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  title: Row(
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: member.unit != null && member.unit!.isNotEmpty
                      ? Text(
                          member.unit!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        )
                      : member.role != null && member.role!.isNotEmpty
                          ? Text(
                              member.role!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            )
                          : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
