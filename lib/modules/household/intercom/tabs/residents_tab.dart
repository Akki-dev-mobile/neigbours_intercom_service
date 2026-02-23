import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_loader.dart';
import '../models/intercom_contact.dart';
import '../chat_screen.dart';
import '../widgets/voice_search_screen.dart';
import '../services/intercom_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/user_search_provider.dart';
import '../../providers/selected_flat_provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../../../core/widgets/enhanced_toast.dart';
import 'dart:async'; // For Debouncer's Timer
import '../../../../core/utils/navigation_helper.dart';
import '../../../../core/utils/oneapp_share.dart';
import '../../../../core/services/society_backend_api_service.dart';
import '../../../../core/services/api_service.dart';
import 'tab_constants.dart';
import 'tab_activation_mixin.dart';
import 'tab_lifecycle_controller.dart';
import 'dart:developer' as developer;
import '../services/chat_service.dart';
import '../services/chat_websocket_service.dart';
import '../services/unread_count_manager.dart';
import '../utils/activity_preview_helper.dart';
import '../../../../core/services/keycloak_service.dart';
import '../widgets/call_bottom_sheet.dart';

class ResidentsTab extends ConsumerStatefulWidget {
  final ValueNotifier<int>? activeTabNotifier;
  final int? tabIndex;
  final ValueNotifier<bool>?
      loadingNotifier; // Notify parent when loading state changes

  const ResidentsTab({
    Key? key,
    this.activeTabNotifier,
    this.tabIndex,
    this.loadingNotifier,
  }) : super(key: key);

  @override
  ConsumerState<ResidentsTab> createState() => _ResidentsTabState();
}

/// Cached data for residents and buildings with timestamp
class _CachedResidentsData {
  final List<IntercomContact> residents;
  final List<Map<String, dynamic>> buildings;
  final DateTime timestamp;
  final int? companyId;

  _CachedResidentsData({
    required this.residents,
    required this.buildings,
    required this.timestamp,
    required this.companyId,
  });

  bool isValid(int? currentCompanyId) {
    if (companyId != currentCompanyId) return false;
    final now = DateTime.now();
    return now.difference(timestamp) < TabConstants.kDataCacheExpiry;
  }
}

class _ResidentsTabState extends ConsumerState<ResidentsTab>
    with TabActivationMixin {
  // Search related state
  final TextEditingController _searchController = TextEditingController();
  // Riverpod now manages: _searchResults, _isSearching, _searchError, and UserProvider interaction
  final Debouncer _debouncer = Debouncer(milliseconds: 500);
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _searchQuery = '';
  List<IntercomContact> _filteredResidents = [];

  String? _selectedBuildingId; // Store building ID instead of name
  List<Map<String, dynamic>> _buildings = []; // API-based buildings
  bool _isLoadingBuildings = false;

  // Data for residents
  List<IntercomContact> _residents = [];
  bool _isLoading = true;
  final Set<String> _callStartingContactIds = <String>{};
  final IntercomService _intercomService = IntercomService();

  final SocietyBackendApiService _societyBackendApiService =
      SocietyBackendApiService.instance;
  final ApiService _apiService = ApiService.instance;

  // Cache for residents and buildings data
  _CachedResidentsData? _cachedData;
  int? _lastLoadedCompanyId; // Track company ID for cache invalidation

  // Request throttling: Minimum interval between requests (2-3 seconds)
  static const Duration _minRequestInterval = Duration(seconds: 2);
  DateTime? _lastRequestTime;

  // WebSocket state (copied from chat_screen.dart pattern)
  final ChatService _chatService = ChatService.instance;
  final UnreadCountManager _unreadManager = UnreadCountManager.instance;
  StreamSubscription<WebSocketMessage>? _wsMessageSubscription;
  StreamSubscription<bool>? _wsConnectionSubscription;
  bool _isWebSocketConnected = false;
  String? _currentUserUuid;
  int? _currentUserNumericId;

  // Presence state for real-time status updates
  Map<String, Map<String, dynamic>> _presenceMap = {};
  Timer? _presenceTimer;

  // TabActivationMixin implementation
  @override
  ValueNotifier<int>? get activeTabNotifier => widget.activeTabNotifier;

  @override
  int? get tabIndex => widget.tabIndex;

  @override
  bool get isLoading => _isLoading || _isLoadingBuildings;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeSpeech();
    _loadCurrentUserIds();
    // Initialize tab activation (handles initial load and listener setup)
    initializeTabActivation();
    _setupWebSocketListeners();
    _setupPresenceUpdates();
  }

  Future<void> _loadCurrentUserIds() async {
    try {
      // Try UUID from Keycloak token (sub)
      final accessToken = await KeycloakService.getAccessToken();
      if (accessToken != null) {
        final decoded = JwtDecoder.decode(accessToken);
        final sub = decoded['sub']?.toString();
        if (sub != null && sub.contains('-')) {
          _currentUserUuid = sub;
        }
      }
    } catch (_) {}

    try {
      final numericId = await _apiService.getUserId();
      if (numericId != null) {
        _currentUserNumericId = int.tryParse(numericId.toString());
      }
    } catch (_) {}
  }

  /// Called by TabActivationMixin when tab becomes active
  ///
  /// CRITICAL: This must render cached data IMMEDIATELY (if available)
  /// before any network calls. This ensures UI is never empty when data exists.
  ///
  /// FIX: Only call API if cache is expired or missing (like GroupsTab)
  /// This prevents multiple API calls when rapidly switching tabs
  @override
  void onTabBecameActive({required bool shouldFetchFromNetwork}) {
    // STEP 1: Render cached data immediately (if available)
    // This must happen synchronously, before any async operations
    // CRITICAL: Always render cached data, even if expired - this ensures UI is never blank
    _renderCachedDataIfAvailable();

    // STEP 2: Check if API call is needed
    // Only call API if cache is expired or missing (like GroupsTab)
    _apiService.getSelectedSocietyId().then((currentCompanyId) {
      if (!mounted) return;

      // Check if we have valid cached data
      final hasValidCache =
          _cachedData != null && _cachedData!.isValid(currentCompanyId);

      if (hasValidCache) {
        final cacheAge = DateTime.now().difference(_cachedData!.timestamp);
        debugPrint(
            '✅ [ResidentsTab] Cache is valid (age: ${cacheAge.inSeconds}s), skipping API call');

        // CRITICAL FIX: Always ensure state is restored, even if cache is valid
        // When returning from Group chat, state might be cleared even though cache exists
        // Re-render cached data to ensure UI is updated (handles navigation back scenario)
        if (_residents.isEmpty || _buildings.isEmpty) {
          debugPrint(
              '🔄 [ResidentsTab] State is empty but cache is valid, re-rendering cached data (returning from navigation)');
          _renderCachedDataIfAvailable();
        }

        // Cache is valid - no need to call API
        widget.loadingNotifier?.value = false;
        return;
      }

      // Cache is expired or missing - need to call API
      // CRITICAL: Even if cache is expired, ensure expired data is shown while loading
      // This prevents blank UI during API call
      if (_cachedData != null && (_residents.isEmpty || _buildings.isEmpty)) {
        debugPrint(
            '🔄 [ResidentsTab] Cache expired but state is empty, showing expired cache while loading fresh data');
        _renderCachedDataIfAvailable(); // Show expired cache as fallback
      }

      debugPrint(
          '🔄 [ResidentsTab] Cache expired/missing, triggering API call (will respect throttling)');
      _checkCacheAndLoad();
    });
  }

  /// Render cached data immediately if available
  ///
  /// This ensures UI is never empty when cached data exists.
  /// Called synchronously on tab activation, before any network calls.
  ///
  /// CRITICAL: This method MUST always render cached data if it exists,
  /// regardless of cache expiry. This fixes the "Residents blank state" issue.
  ///
  /// Why Residents was going blank:
  /// - Previously, _hasLoadedOnce blocked UI from showing cached data
  /// - Network fetch was required before rendering, causing blank UI during fetch
  /// - Rapid tab switching cancelled fetches, leaving UI empty
  ///
  /// How it's prevented:
  /// - Cached data renders IMMEDIATELY (synchronously) on activation
  /// - Network fetch happens separately (asynchronously) if needed
  /// - UI is never blank when cached data exists, even if expired
  /// - _hasLoadedOnce only gates network fetch, NOT rendering
  void _renderCachedDataIfAvailable() {
    if (_cachedData == null) {
      debugPrint(
          'ℹ️ [ResidentsTab] No cached data available for immediate rendering');
      return; // No cached data
    }

    // ALWAYS render cached data if it exists, even if expired
    // This prevents blank UI. Network fetch will validate expiry and refresh if needed.
    // This ensures "last known data" is always shown immediately when returning to tab.
    final hasResidents = _cachedData!.residents.isNotEmpty;
    final hasBuildings = _cachedData!.buildings.isNotEmpty;

    if (hasResidents || hasBuildings) {
      debugPrint(
          '✅ [ResidentsTab] Rendering cached data immediately on activation (${_cachedData!.residents.length} residents, ${_cachedData!.buildings.length} buildings)');

      if (mounted) {
        setState(() {
          // Render cached data immediately - this ensures UI is never blank
          _residents = List.from(_cachedData!.residents);
          _buildings = List.from(_cachedData!.buildings);
          // CRITICAL: Set loading state to false to show data, not loading spinner
          _isLoading = false;
          _isLoadingBuildings = false;

          // Auto-select first building if none selected
          if (_selectedBuildingId == null && _buildings.isNotEmpty) {
            _selectedBuildingId = _buildings.first['id']?.toString() ??
                _buildings.first['soc_building_id']?.toString();
          }

          // CRITICAL: Apply filtering to populate _filteredResidents
          // This ensures groups are populated and data is shown
          _filterResidents();

          // VERIFY: Ensure _filteredResidents is populated
          // If building filter results in empty, reset building selection to show all residents
          if (_filteredResidents.isEmpty &&
              _residents.isNotEmpty &&
              _selectedBuildingId != null) {
            debugPrint(
                '⚠️ [ResidentsTab] Building filter resulted in empty residents, resetting building selection');
            _selectedBuildingId = null;
            // Re-filter with no building selection
            _filterResidents();
          }

          // FINAL CHECK: If still empty after reset, ensure we show all residents
          if (_filteredResidents.isEmpty && _residents.isNotEmpty) {
            debugPrint(
                '⚠️ [ResidentsTab] Filtered residents still empty, showing all residents');
            _filteredResidents = List.from(_residents);
          }
        });

        // Log final state for debugging
        debugPrint(
            '✅ [ResidentsTab] Cached data rendered: ${_residents.length} residents, ${_buildings.length} buildings, ${_filteredResidents.length} filtered residents');
      }
    } else {
      debugPrint(
          'ℹ️ [ResidentsTab] Cached data exists but is empty - will show loading state');
      // If no cached data, ensure loading state is shown
      if (mounted) {
        setState(() {
          _isLoading = true;
          _isLoadingBuildings = true;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // CRITICAL FIX: Restore cached data if state is empty (handles navigation back scenario)
    // When returning from Group chat, state might be cleared even though cache exists
    // This ensures data is always visible when returning to the tab
    if (mounted &&
        (_residents.isEmpty || _buildings.isEmpty) &&
        _cachedData != null) {
      debugPrint(
          '🔄 [ResidentsTab] didChangeDependencies: State is empty but cache exists, restoring cached data');
      _renderCachedDataIfAvailable();
    }

    // Check if company/society has changed and invalidate cache if needed
    _checkCompanyChangeAndReload();
  }

  /// Check if company/society has changed and reload if needed
  Future<void> _checkCompanyChangeAndReload() async {
    if (!mounted || _isLoading || _isLoadingBuildings) return;

    try {
      final currentCompanyId = await _apiService.getSelectedSocietyId();
      if (currentCompanyId != null &&
          currentCompanyId != _lastLoadedCompanyId) {
        debugPrint(
            '🔄 [ResidentsTab] Company changed from $_lastLoadedCompanyId to $currentCompanyId - Clearing cache and reloading');

        // Clear cache and reset state
        _cachedData = null;
        resetLoadState(); // This cancels all pending operations
        _lastLoadedCompanyId = null;

        // Clear unread mappings to avoid stale badges across companies
        try {
          await _unreadManager.clearAll();
        } catch (e) {
          debugPrint('⚠️ [ResidentsTab] Failed to clear unread state: $e');
        }

        // Clear existing data to prevent showing wrong data
        if (mounted) {
          setState(() {
            _residents = [];
            _buildings = [];
            _filteredResidents = [];
            _selectedBuildingId = null;
            _isLoading = true;
            _isLoadingBuildings = true;
          });
        }

        // Reload after a delay (cancellable)
        scheduleDelayed(
          delay: TabConstants.kCompanyChangeReloadDelay,
          callback: () {
            if (mounted && !_isLoading && !_isLoadingBuildings) {
              _loadBuildings();
              _loadContacts();
            }
          },
        );
      }
    } catch (e) {
      debugPrint('❌ [ResidentsTab] Error checking company change: $e');
    }
  }

  /// Check cache validity and load data if needed
  ///
  /// This is called after cached data has been rendered (if available).
  /// It validates cache and triggers network fetch if needed.
  Future<void> _checkCacheAndLoad() async {
    // REQUEST THROTTLING: Enforce minimum interval between requests
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final remainingSeconds =
            (_minRequestInterval - timeSinceLastRequest).inSeconds;
        debugPrint(
            '⏸️ [ResidentsTab] Request throttled (${remainingSeconds}s remaining)');
        return; // Ignore request - too soon after last one
      }
    }

    // Try to acquire request lock - prevents concurrent requests
    final token = tryAcquireRequestLock();
    if (token == null) {
      debugPrint('⏸️ [ResidentsTab] Request already in-flight, skipping');
      return;
    }

    // Update last request time
    _lastRequestTime = DateTime.now();

    // Notify parent that loading started (prevents tab switching)
    widget.loadingNotifier?.value = true;

    try {
      final currentCompanyId = await _apiService.getSelectedSocietyId();

      // Check if token is still valid (tab might have become inactive)
      if (!token.isValid(lifecycleController.generation)) {
        debugPrint('⏹️ [ResidentsTab] Tab became inactive, cancelling load');
        return;
      }

      // Cache invalid or missing - load fresh data
      // This ensures buildings list API (apigw.cubeone.in/api/admin/building/list)
      // and residents API are called when cache is expired or missing
      debugPrint(
          '📡 [ResidentsTab] Cache expired/missing, loading buildings and residents from API...');
      await Future.wait([
        _loadBuildings(token: token),
        _loadContacts(token: token),
      ]);
    } catch (e) {
      debugPrint('❌ [ResidentsTab] Error checking cache: $e');
      // Fallback to loading if cache check fails
      await Future.wait([
        _loadBuildings(token: token),
        _loadContacts(token: token),
      ]);
    } finally {
      // Release lock after both operations complete
      releaseRequestLock();

      // Notify parent that loading completed (allows tab switching)
      widget.loadingNotifier?.value = false;
    }
  }

  @override
  void dispose() {
    _wsMessageSubscription?.cancel();
    _wsConnectionSubscription?.cancel();
    _presenceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debouncer.dispose();
    _speech.stop();
    // Clean up tab activation listener
    disposeTabActivation();
    super.dispose();
  }

  /// Setup WebSocket listeners for real-time updates (copied from chat_screen.dart)
  void _setupWebSocketListeners() {
    // Listen to incoming messages
    _wsMessageSubscription = _chatService.messageStream.listen(
      (wsMessage) {
        _handleWebSocketMessage(wsMessage);
      },
      onError: (error) {
        developer.log('WebSocket message stream error: $error');
      },
    );

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

    // Initialize connection status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isWebSocketConnected = _chatService.isWebSocketConnected;
        });
      }
    });
  }

  /// Setup presence updates with periodic fetching
  void _setupPresenceUpdates() {
    _fetchPresence();
    // Refresh presence every 30 seconds
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchPresence());
  }

  /// Fetch presence data for all contacts
  Future<void> _fetchPresence() async {
    // Extract user IDs from residents that have valid user IDs
    final userIds = _residents
        .where((c) => c.hasUserId && c.id.isNotEmpty)
        .map((c) => c.id)
        .toList();

    if (userIds.isEmpty) {
      debugPrint('ℹ️ [ResidentsTab] No valid user IDs to fetch presence for');
      return;
    }

    try {
      debugPrint('👥 [ResidentsTab] Fetching presence for ${userIds.length} users');
      final response = await _chatService.getPresence(userIds);

      if (response.success && response.data != null) {
        setState(() {
          _presenceMap = {
            for (var presence in response.data!)
              presence['user_id'] as String: presence
          };
        });

        // Update contact statuses with fetched presence data
        _updateContactsPresence();

        debugPrint('✅ [ResidentsTab] Successfully fetched presence for ${response.data!.length} users');
      } else {
        debugPrint('⚠️ [ResidentsTab] Failed to fetch presence: ${response.error}');
      }
    } catch (e) {
      debugPrint('❌ [ResidentsTab] Error fetching presence: $e');
      // Don't show error toast - presence is not critical functionality
    }
  }

  /// Update contact presence data in the residents list
  void _updateContactsPresence() {
    if (!mounted) return;

    setState(() {
      for (var i = 0; i < _residents.length; i++) {
        final contact = _residents[i];
        final presence = _presenceMap[contact.id];

        if (presence != null) {
          final isOnline = presence['is_online'] == true;
          final statusString = presence['status'] as String?;
          final lastSeenString = presence['last_seen'] as String?;

          // Convert string status to enum
          final status = _convertPresenceStatusToEnum(statusString);

          // Parse last seen time
          DateTime? lastSeenAt;
          if (lastSeenString != null) {
            try {
              lastSeenAt = DateTime.parse(lastSeenString);
            } catch (e) {
              debugPrint('⚠️ [ResidentsTab] Failed to parse last_seen time: $e');
            }
          }

          _residents[i] = contact.copyWith(
            status: status,
            isOnline: isOnline,
            lastSeenAt: lastSeenAt,
          );
        }
      }

      // Re-filter residents after updating presence data
      _filterResidents();
    });
  }

  /// Convert presence API string status to IntercomContactStatus enum
  IntercomContactStatus _convertPresenceStatusToEnum(String? statusString) {
    switch (statusString?.toLowerCase()) {
      case 'online':
        return IntercomContactStatus.online;
      case 'busy':
        return IntercomContactStatus.busy;
      case 'away':
        return IntercomContactStatus.away;
      case 'offline':
      default:
        return IntercomContactStatus.offline;
    }
  }

  /// Handle incoming WebSocket messages - update contact status, unread counts, and last messages
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
        developer.log(
            '📊 [ResidentsTab] Received unread_count_update: room=$updateRoomId, user=$userId, count=$unreadCount');

        // Update local unread count manager if this is for current user
        bool isForCurrentUser = false;
        if (_currentUserUuid != null && userId == _currentUserUuid) {
          isForCurrentUser = true;
        } else if (_currentUserNumericId != null &&
            int.tryParse(userId) == _currentUserNumericId) {
          isForCurrentUser = true;
        }

        if (isForCurrentUser) {
          if (unreadCount == 0) {
            await _unreadManager.clearUnreadCount(updateRoomId);
          } else {
            // Backend is source of truth - update local cache with exact count
            await _unreadManager.setUnreadCount(updateRoomId, unreadCount);
            developer.log(
                '📊 [ResidentsTab] Unread count updated to $unreadCount for room $updateRoomId');
          }

          // Update contact in residents list
          final contactId = _unreadManager.getContactIdForRoom(updateRoomId);
          if (contactId != null) {
            _updateContactFromWebSocket(contactId, updateRoomId);
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

      if (userId != null && mounted) {
        debugPrint('👤 [ResidentsTab] Presence update: user=$userId, online=$isOnline, status=$statusString');

        // Update presence map with real-time data
        setState(() {
          _presenceMap[userId] = {
            'user_id': userId,
            'is_online': isOnline,
            'status': statusString,
            'last_seen': DateTime.now().toIso8601String(),
          };
        });

        // Update contact presence data
        _updateContactsPresence();
      }
      return; // Don't process presence_update as regular messages
    }

    developer
        .log('📨 [ResidentsTab] Received WebSocket message for room: $roomId');

    // Get contact ID for this room
    final contactId = _unreadManager.getContactIdForRoom(roomId);
    if (contactId == null) {
      // Room not mapped to a contact yet - might be a group chat or new room
      return;
    }

    // Check if this message is from current user (UUID or numeric)
    bool isFromCurrentUser = false;
    if (_currentUserUuid != null &&
        wsMessage.userId != null &&
        wsMessage.userId == _currentUserUuid) {
      isFromCurrentUser = true;
    } else if (_currentUserNumericId != null &&
        wsMessage.userId != null &&
        int.tryParse(wsMessage.userId!) == _currentUserNumericId) {
      isFromCurrentUser = true;
    }

    // Check if this is a system message (should not increment unread count)
    final isSystemMessage = _isSystemMessageFromWebSocket(wsMessage);

    // Build activity preview for any incoming activity
    final activityPreview = _buildActivityPreview(wsMessage);
    await _unreadManager.updateLastMessage(
      roomId,
      activityPreview,
      DateTime.now(),
    );

    // Backend is source of truth for unread counts (DB + unread_count_update).
    // Do not increment locally. Indicator comes from unread_count_update / API seed.

    // Update contact in residents list
    _updateContactFromWebSocket(contactId, roomId);
  }

  /// Check if a WebSocket message is a system message (should not increment unread count)
  bool _isSystemMessageFromWebSocket(WebSocketMessage wsMessage) {
    final messageType = wsMessage.messageType?.toLowerCase() ??
        wsMessage.data?['message_type']?.toString().toLowerCase();
    final eventType = wsMessage.data?['event_type']?.toString().toLowerCase();

    if (messageType == 'system' || messageType == 'event') return true;
    if (eventType == 'user_left' ||
        eventType == 'message_deleted' ||
        eventType == 'user_joined' ||
        eventType == 'user_added' ||
        eventType == 'user_removed') {
      return true;
    }

    final content =
        wsMessage.content ?? wsMessage.data?['content']?.toString() ?? '';
    final contentLower = content.toLowerCase();
    if (contentLower.contains('joined the group') ||
        contentLower.contains('left the group') ||
        contentLower.contains('was deleted') ||
        (contentLower.contains('added') &&
            contentLower.contains('to the group')) ||
        (contentLower.contains('removed') &&
            contentLower.contains('from the group'))) {
      return true;
    }
    return false;
  }

  /// Update a contact in the residents list based on WebSocket message
  void _updateContactFromWebSocket(String contactId, String roomId) {
    if (!mounted) return;

    final contactIndex = _residents.indexWhere((c) => c.id == contactId);
    if (contactIndex == -1) return; // Contact not in list

    final unreadCount = _unreadManager.getUnreadCount(roomId);
    final lastMessage = _unreadManager.getLastMessage(roomId);
    final lastMessageTime = _unreadManager.getLastMessageTime(roomId);

    // Create updated contact with new unread count and last message
    // CRITICAL: Preserve hasUserId and numericUserId fields when updating
    final updatedContact = IntercomContact(
      id: _residents[contactIndex].id,
      name: _residents[contactIndex].name,
      unit: _residents[contactIndex].unit,
      role: _residents[contactIndex].role,
      building: _residents[contactIndex].building,
      floor: _residents[contactIndex].floor,
      type: _residents[contactIndex].type,
      status: _residents[contactIndex].status,
      hasUnreadMessages: unreadCount > 0,
      photoUrl: _residents[contactIndex].photoUrl,
      lastContact: lastMessageTime,
      phoneNumber: _residents[contactIndex].phoneNumber,
      familyMembers: _residents[contactIndex].familyMembers,
      isPrimary: _residents[contactIndex].isPrimary,
      numericUserId:
          _residents[contactIndex].numericUserId, // Preserve numericUserId
      hasUserId: _residents[contactIndex].hasUserId, // Preserve hasUserId
    );

    setState(() {
      _residents[contactIndex] = updatedContact;
      _filteredResidents = List.from(_residents);
    });

    developer.log(
        '✅ [ResidentsTab] Updated contact $contactId: unread=$unreadCount, lastMsg=${lastMessage?.substring(0, lastMessage.length > 20 ? 20 : lastMessage.length)}');
  }

  /// Build a user-facing preview for incoming activity
  String _buildActivityPreview(WebSocketMessage wsMessage) {
    final preview = ActivityPreviewHelper.fromWebSocket(
      content: wsMessage.content,
      messageType: wsMessage.messageType,
      data: wsMessage.data,
    );
    return preview.text;
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

  Future<void> _loadBuildings({TabCancellationToken? token}) async {
    // Token should be provided by caller (from _checkCacheAndLoad)
    // If not provided, this is a standalone call - acquire lock
    bool shouldReleaseLock = false;
    if (token == null) {
      token = tryAcquireRequestLock();
      if (token == null) {
        debugPrint(
            '⏸️ [ResidentsTab] Request lock already held for buildings, skipping');
        return;
      }
      shouldReleaseLock = true;
    }

    // Set loading state - this will show loading indicator while fetching
    if (mounted) {
      setState(() {
        _isLoadingBuildings = true;
      });
    }

    try {
      // Get the selected society ID
      final societyId = await _apiService.getSelectedSocietyId();

      // Check if token is still valid
      if (!token.isValid(lifecycleController.generation)) {
        debugPrint(
            '⏹️ [ResidentsTab] Tab became inactive during buildings load, cancelling');
        return;
      }

      if (societyId == null) {
        debugPrint(
            '⚠️ [ResidentsTab] No society ID found, cannot load buildings');
        if (mounted) {
          setState(() {
            _isLoadingBuildings = false;
          });
        }
        return;
      }

      debugPrint('🏢 [ResidentsTab] Loading buildings for society: $societyId');
      debugPrint(
          '🌐 [ResidentsTab] API URL: https://apigw.cubeone.in/api/admin/building/list?page=1&per_page=${TabConstants.kBuildingsPerPage}');
      debugPrint(
          '🔑 [ResidentsTab] Using cookies: id_token, x-access-token, company_id (handled by SocietyBackendApiService)');
      final response = await _societyBackendApiService.getBuildings(
        page: 1,
        perPage: TabConstants.kBuildingsPerPage,
        societyId: societyId.toString(),
      );

      // Check token validity again before updating state
      if (!token.isValid(lifecycleController.generation)) {
        debugPrint(
            '⏹️ [ResidentsTab] Tab became inactive after buildings load, discarding result');
        return;
      }

      if (mounted) {
        final currentCompanyId = await _apiService.getSelectedSocietyId();

        setState(() {
          _buildings = response.buildings;
          _isLoadingBuildings = false;
          // Auto-select first building if none selected
          if (_selectedBuildingId == null && _buildings.isNotEmpty) {
            _selectedBuildingId = _buildings.first['id']?.toString() ??
                _buildings.first['soc_building_id']?.toString();
          }
          debugPrint(
              '✅ [ResidentsTab] Loaded ${_buildings.length} buildings from API');
        });

        // Update cache with buildings (if we have residents, update cache)
        if (_cachedData != null && currentCompanyId != null) {
          _cachedData = _CachedResidentsData(
            residents: _cachedData!.residents,
            buildings: List.from(response.buildings),
            timestamp: _cachedData!.timestamp,
            companyId: currentCompanyId,
          );
        }

        // Apply filtering after buildings are loaded and building is auto-selected
        if (mounted) {
          _filterResidents();
        }
      }
    } catch (e) {
      debugPrint('❌ [ResidentsTab] Error loading buildings: $e');
      if (mounted && token.isValid(lifecycleController.generation)) {
        setState(() {
          _isLoadingBuildings = false;
        });
      }
    } finally {
      // Release lock only if we acquired it (standalone call)
      if (shouldReleaseLock) {
        releaseRequestLock();
      }
    }
  }

  Future<void> _loadContacts({TabCancellationToken? token}) async {
    // Token should be provided by caller (from _checkCacheAndLoad)
    // If not provided, this is a standalone call - acquire lock
    bool shouldReleaseLock = false;
    if (token == null) {
      token = tryAcquireRequestLock();
      if (token == null) {
        debugPrint(
            '⏸️ [ResidentsTab] Request lock already held for contacts, skipping');
        return;
      }
      shouldReleaseLock = true;
    }

    // Set loading state - show loading indicator while fetching fresh data
    // This ensures user sees that data is being refreshed when returning to tab
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      debugPrint('👥 [ResidentsTab] Loading residents from API...');
      debugPrint(
          '🌐 [ResidentsTab] API: SocietyBackendApiService.getMembers() -> /admin/member/list');
      final residents = await _intercomService.getResidents();

      // Check token validity before updating state
      if (!token.isValid(lifecycleController.generation)) {
        debugPrint(
            '⏹️ [ResidentsTab] Tab became inactive during contacts load, discarding result');
        return;
      }

      if (mounted) {
        final currentCompanyId = await _apiService.getSelectedSocietyId();

        setState(() {
          _residents = residents;
          _isLoading = false;
        });

        // Apply filtering after loading residents
        _filterResidents();

        // Update cache with fresh data
        if (currentCompanyId != null) {
          _cachedData = _CachedResidentsData(
            residents: List.from(residents), // Create copy for cache
            buildings: List.from(_buildings), // Use already loaded buildings
            timestamp: DateTime.now(),
            companyId: currentCompanyId,
          );
          _lastLoadedCompanyId = currentCompanyId;
        }

        // Mark data as loaded (updates debounce tracking)
        markDataLoaded();
      }
    } catch (e) {
      if (mounted && token.isValid(lifecycleController.generation)) {
        setState(() {
          _isLoading = false;
          // Don't clear existing data on error - keep what we have
          // This prevents showing "No residents" when there's a temporary error
        });

        // Check for rate limit errors (429)
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('429') ||
            errorStr.contains('too many requests')) {
          // Handle rate limit gracefully
          if (_residents.isNotEmpty) {
            debugPrint(
                '✅ [ResidentsTab] Rate limited (429) - showing cached data (${_residents.length} residents)');
            // Silently use cached data - no error toast
          } else {
            debugPrint(
                '⚠️ [ResidentsTab] Rate limited (429) - no cached data, will retry silently');
            // Don't show toast - just log it and let the system retry
            // The user will see the loading state, and data will load when retry succeeds
          }
        } else {
          // Other errors
          // Only show error if we have no data
          if (_residents.isEmpty) {
            EnhancedToast.error(
              context,
              title: 'Error',
              message: 'Failed to load residents: ${e.toString()}',
            );
          } else {
            // If we have cached data, show a less intrusive error
            debugPrint('⚠️ [ResidentsTab] Failed to refresh residents: $e');
          }
        }
      }
    } finally {
      // Release lock only if we acquired it (standalone call)
      if (shouldReleaseLock) {
        releaseRequestLock();
      }
    }
  }

  List<IntercomContact> get filteredResidents {
    if (_selectedBuildingId == null) {
      return _residents;
    }
    // Find building name from ID
    final selectedBuilding = _buildings.firstWhere(
      (b) =>
          (b['id']?.toString() ?? b['soc_building_id']?.toString()) ==
          _selectedBuildingId,
      orElse: () => <String, dynamic>{},
    );
    final buildingName = selectedBuilding['soc_building_name']?.toString() ??
        selectedBuilding['building_name']?.toString();

    if (buildingName == null) return _residents;

    return _residents
        .where((resident) => resident.building == buildingName)
        .toList();
  }

  // Group residents by floor
  Map<String, List<IntercomContact>> get groupedResidents {
    // Use _filteredResidents which already handles both building and search filtering
    final filteredByBuilding = _filteredResidents;
    final Map<String, List<IntercomContact>> result = {};

    for (final resident in filteredByBuilding) {
      // Handle null floor - omit floor if null/empty
      final buildingText =
          resident.building != null && resident.building!.isNotEmpty
              ? resident.building!
              : 'Building';
      // Use building name from API as-is (it may already include "Wing" if needed)
      // Only include floor if it's not null/empty
      final key = resident.floor != null && resident.floor!.isNotEmpty
          ? '$buildingText - Floor ${resident.floor}'
          : buildingText;
      if (!result.containsKey(key)) {
        result[key] = [];
      }
      result[key]!.add(resident);
    }

    return result;
  }

  Future<void> _performSearch() async {
    final searchQuery = _searchController.text.trim();
    setState(() {
      _searchQuery = searchQuery;
      // Apply local filtering immediately
      _filterResidents();
    });

    // Clear API search when search query is empty
    if (searchQuery.isEmpty) {
      ref.read(userSearchProvider.notifier).clearSearch();
    }
    // Note: We're using local filtering (_filterResidents) instead of API search
    // to provide instant results. API search can be enabled if needed.
  }

  void _filterResidents() {
    // First get building-filtered residents
    final buildingFiltered = filteredResidents;

    if (_searchQuery.isEmpty) {
      _filteredResidents = buildingFiltered;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredResidents = buildingFiltered.where((resident) {
        final matchesName = resident.name.toLowerCase().contains(query);
        final matchesUnit = resident.unit != null &&
            resident.unit!.toLowerCase().contains(query);
        final matchesBuilding = resident.building != null &&
            resident.building!.toLowerCase().contains(query);
        final matchesPhone = resident.phoneNumber != null &&
            resident.phoneNumber!.toLowerCase().contains(query);

        return matchesName || matchesUnit || matchesBuilding || matchesPhone;
      }).toList();
    }
  }

  void _onSearchChanged() {
    _debouncer.run(_performSearch);
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
                _filterResidents();
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
                _filterResidents();
              });

              // Trigger search if text is not empty
              if (text.isNotEmpty) {
                _performSearch();
              }
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

  @override
  Widget build(BuildContext context) {
    final groups = groupedResidents;
    final sortedKeys = groups.keys.toList()..sort();

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Building filter chips
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              margin: const EdgeInsets.only(top: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    // Building chips from API
                    if (_isLoadingBuildings)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      ..._buildings.map((building) {
                        final buildingId = building['id']?.toString() ??
                            building['soc_building_id']?.toString();
                        final buildingName =
                            building['soc_building_name']?.toString() ??
                                building['building_name']?.toString() ??
                                'Building';
                        final isSelected = buildingId == _selectedBuildingId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              buildingName,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedBuildingId = buildingId;
                              });
                              // Re-apply filters when building selection changes
                              _filterResidents();
                            },
                            backgroundColor: Colors.white,
                            selectedColor: AppColors.primary,
                            checkmarkColor: Colors.white,
                            showCheckmark: false,
                            elevation: 0,
                            pressElevation: 3,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        );
                      }).toList(),
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
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search residents...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.primary.withOpacity(0.7),
                    size: 20,
                  ),
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
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
                        color: _isListening ? Colors.red : AppColors.primary,
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

            // Contact list grouped by floor with improved styling
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: AppLoader(
                        title: 'Loading Residents',
                        subtitle: 'Fetching resident information...',
                        icon: Icons.people_rounded,
                      ),
                    )
                  : groups.isEmpty
                      ? _searchQuery.isNotEmpty
                          ? _buildEmptyState(
                              icon: Icons.search_off,
                              title: 'No residents found',
                              subtitle:
                                  'No residents match your search query. Try a different search term.',
                            )
                          : _selectedBuildingId != null
                              ? _buildEmptyState(
                                  icon: Icons.people_outline,
                                  title: 'No residents found',
                                  subtitle:
                                      'Select a different building to view residents',
                                )
                              : _buildEmptyState(
                                  icon: Icons.people_outline,
                                  title: 'No residents',
                                  subtitle: 'No residents available',
                                )
                      : ListView.builder(
                          itemCount: sortedKeys.length,
                          itemBuilder: (context, index) {
                            final key = sortedKeys[index];
                            final residentsInGroup = groups[key]!;
                            // The following Container was previously misplaced with a 'return'
                            return Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                // gradient: AppColors.lightGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Group header with gradient background
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    // decoration: BoxDecoration(
                                    //   gradient: AppColors.lightGradient,
                                    //   border: Border(
                                    //     bottom: BorderSide(
                                    //       color: Colors.grey.shade200,
                                    //       width: 1,
                                    //     ),
                                    //   ),
                                    // ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Building name label (left side)
                                        Expanded(
                                          child: Text(
                                            key,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        // Resident count badge (right side, opposite to building label)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.coolGrey
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${residentsInGroup.length} residents',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // List of residents in this group
                                  ...residentsInGroup.map((resident) =>
                                      _buildResidentItem(resident)),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(IntercomContactStatus? status) {
    switch (status) {
      case IntercomContactStatus.online:
        return Colors.green;
      case IntercomContactStatus.busy:
        return Colors.red;
      case IntercomContactStatus.away:
        return Colors.orange;
      case IntercomContactStatus.offline:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _handleChat(IntercomContact contact) {
    NavigationHelper.pushRoute(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          contact: contact,
          returnToHistory: true, // Navigate back to history page on back button
        ),
      ),
    );
  }

  void _handleCall(IntercomContact contact) {
    if (contact.phoneNumber != null) {
      _launchPhoneCall(contact.phoneNumber!);
    } else {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'No phone number available for ${contact.name}',
      );
    }
  }

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      await launchUrl(launchUri);
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Could not launch phone dialer: $e',
      );
    }
  }

  /// Show popup menu with Audio and Video Call options using Jitsi SDK
  /// 
  /// This method shows the CallBottomSheet which:
  /// - Displays audio and video call options
  /// - Handles permissions
  /// - Initiates calls via CallManager
  /// - Joins Jitsi meetings via JitsiCallController
  Future<void> _showCallOptionsPopup(IntercomContact contact) async {
    // Get current user's display name from Keycloak token
    String displayName = 'User';
    String? userEmail;
    String? avatarUrl;
    
    try {
      final userData = await KeycloakService.getUserData();
      if (userData != null) {
        displayName = userData['name'] as String? ?? 
                      userData['preferred_username'] as String? ?? 
                      'User';
        userEmail = userData['email'] as String?;
      }
    } catch (e) {
      debugPrint('⚠️ [ResidentsTab] Error getting user data: $e');
    }
    
    if (!mounted) return;
    
    // Show the call bottom sheet
    unawaited(CallBottomSheet.show(
      context: context,
      contact: contact,
      displayName: displayName,
      avatarUrl: avatarUrl,
      userEmail: userEmail,
    ));
  }

  // Note: Video call functionality is now handled by CallBottomSheet
  // which uses Jitsi SDK via CallManager and JitsiCallController

  Future<void> _onCallPressed(IntercomContact contact) async {
    if (!contact.hasUserId) return;
    if (_callStartingContactIds.contains(contact.id)) return;

    setState(() {
      _callStartingContactIds.add(contact.id);
    });

    try {
      await _showCallOptionsPopup(contact);
    } finally {
      if (mounted) {
        setState(() {
          _callStartingContactIds.remove(contact.id);
        });
      }
    }
  }

  Widget _buildResidentItem(IntercomContact resident) {
    final bool isExpanded = resident.familyMembers?.isNotEmpty ?? false;
    // Disable entire card if member is not a OneApp user
    final isDisabled = !resident.hasUserId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: isDisabled
              ? null // Disable tap for non-OneApp users
              : () {
                  // Toggle expansion when card is tapped
                  setState(() {
                    // Using a unique ID to track expanded state
                    resident.isExpanded = !(resident.isExpanded ?? false);
                  });
                },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Main resident information section
              _buildResidentMainInfo(resident),

              // Family members section (if any and expanded)
              if ((resident.familyMembers?.isNotEmpty ?? false) &&
                  (resident.isExpanded ?? false))
                _buildFamilyMembersSection(resident),
            ],
          ),
        ),
      ),
    );
  }

  // Main resident information widget
  Widget _buildResidentMainInfo(IntercomContact resident) {
    return Column(
      children: [
        // Resident info with avatar, name, etc.
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with status indicator (use same member photo as 1-to-1 chat when available)
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: (resident.photoUrl != null &&
                              resident.photoUrl!.isNotEmpty)
                          ? Image.network(
                              resident.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to initials if image fails to load
                                return Center(
                                  child: Text(
                                    resident.initials,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Text(
                                resident.initials,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                    ),
                  ),
                  // Status indicator
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: _getStatusColor(resident.status),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Favorite indicator
                  if (resident.isFavorite)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 12),

              // Resident details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            resident.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (resident.familyMembers?.isNotEmpty ?? false)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.shade100,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.family_restroom,
                                  size: 12,
                                  color: Colors.red.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Family Member',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Unit info
                    Text(
                      (resident.unit ?? 'No Unit'),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Show indicator if member is not a OneApp user
                    if (!resident.hasUserId)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Not a oneapp user',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!resident.hasUserId) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () =>
                      OneAppShare.shareInvite(name: resident.name),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text(
                    'Invite',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Action buttons
        const Divider(height: 1, color: Colors.black12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // Chat button - disabled if not a OneApp user
              Expanded(
                child: TextButton.icon(
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: !resident.hasUserId
                        ? Colors.grey.shade400
                        : Colors.blue,
                  ),
                  label: Text(
                    'Chat',
                    style: TextStyle(
                      color: !resident.hasUserId
                          ? Colors.grey.shade400
                          : Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: !resident.hasUserId
                      ? null // Disable chat for non-OneApp users
                      : () => _handleChat(resident),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              // Vertical divider
              Container(
                height: 24,
                width: 1,
                color: Colors.black12,
              ),

              // Call button - disabled if not a OneApp user
              Expanded(
                child: TextButton(
                  onPressed: (!resident.hasUserId ||
                          _callStartingContactIds.contains(resident.id))
                      ? null // Disable call for non-OneApp users
                      : () => _onCallPressed(resident),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _callStartingContactIds.contains(resident.id)
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.green,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.phone_in_talk,
                          size: 22,
                          color: !resident.hasUserId
                              ? Colors.grey.shade400
                              : Colors.green,
                        ),
                ),
              ),

              // Expand family members button
              if (resident.familyMembers?.isNotEmpty ?? false)
                SizedBox(
                  height: 40,
                  width: 40,
                  child: IconButton(
                    icon: Icon(
                      (resident.isExpanded ?? false)
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () {
                      // Toggle family members view
                      setState(() {
                        resident.isExpanded = !(resident.isExpanded ?? false);
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Family members section
  Widget _buildFamilyMembersSection(IntercomContact resident) {
    final familyMembers = resident.familyMembers ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Family section header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              top: BorderSide(color: Colors.black.withOpacity(0.1)),
              bottom: BorderSide(color: Colors.black.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.family_restroom,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'Family Members',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${familyMembers.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Family members list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: familyMembers.length,
          separatorBuilder: (context, index) => Divider(
            color: Colors.black.withOpacity(0.1),
            height: 1,
            indent: 68,
            endIndent: 16,
          ),
          itemBuilder: (context, index) =>
              _buildFamilyMemberItem(familyMembers[index]),
        ),
      ],
    );
  }

  // Individual family member item
  Widget _buildFamilyMemberItem(FamilyMember member) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar with status
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    member.initials,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(member.status),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Member name
                Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                // Relation badge below member name
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getRelationIcon(member.relation),
                        size: 12,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        member.relation,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Phone number
                Text(
                  member.phoneNumber ?? 'No phone number',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Row(
            children: [
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                color: const Color(0xFFFF3B30),
                onTap: () {
                  // Navigate to chat screen for this family member
                  NavigationHelper.pushRoute(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        contact: IntercomContact(
                          id: member.id,
                          name: member.name,
                          type: IntercomContactType.resident,
                          status: member.status,
                          phoneNumber: member.phoneNumber,
                          // Note: FamilyMember doesn't have hasUserId, default to true
                          hasUserId: true,
                        ),
                        returnToHistory:
                            true, // Navigate back to history page on back button
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.phone_in_talk,
                color: Colors.green,
                onTap: () {
                  // Handle call to family member
                  if (member.phoneNumber != null) {
                    _launchPhoneCall(member.phoneNumber!);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStatusText(IntercomContactStatus? status) {
    switch (status) {
      case IntercomContactStatus.online:
        return 'Online';
      case IntercomContactStatus.busy:
        return 'Busy';
      case IntercomContactStatus.away:
        return 'Away';
      case IntercomContactStatus.offline:
        return 'Offline';
      default:
        return 'Offline';
    }
  }

  IconData _getRelationIcon(String relation) {
    switch (relation.toLowerCase()) {
      case 'spouse':
        return Icons.favorite;
      case 'son':
        return Icons.child_care;
      case 'daughter':
        return Icons.child_care;
      case 'parent':
      case 'father':
      case 'mother':
        return Icons.family_restroom;
      default:
        return Icons.person;
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
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
              child: Icon(
                icon,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Debouncer class to delay search execution
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
