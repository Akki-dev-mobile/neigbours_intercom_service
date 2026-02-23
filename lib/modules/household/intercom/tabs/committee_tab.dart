import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_loader.dart';
import '../models/intercom_contact.dart';
import '../chat_screen.dart';
import '../widgets/voice_search_screen.dart';
import '../services/intercom_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/enhanced_toast.dart';
import '../../../../core/utils/navigation_helper.dart';
import '../../../../core/utils/oneapp_share.dart';
import 'tab_constants.dart';
import 'tab_activation_mixin.dart';
import 'tab_lifecycle_controller.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../services/chat_service.dart';
import '../services/chat_websocket_service.dart';
import '../services/unread_count_manager.dart';
import '../utils/activity_preview_helper.dart';
import '../services/committee_member_cache.dart';
import '../../../../core/services/keycloak_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../widgets/call_bottom_sheet.dart';

class CommitteeTab extends ConsumerStatefulWidget {
  final ValueNotifier<int>? activeTabNotifier;
  final int? tabIndex;
  final ValueNotifier<bool>?
      loadingNotifier; // Notify parent when loading state changes

  const CommitteeTab({
    Key? key,
    this.activeTabNotifier,
    this.tabIndex,
    this.loadingNotifier,
  }) : super(key: key);

  @override
  ConsumerState<CommitteeTab> createState() => _CommitteeTabState();
}

/// Cached data for committee members with timestamp
class _CachedCommitteeData {
  final List<IntercomContact> members;
  final DateTime timestamp;
  final int? companyId;

  _CachedCommitteeData({
    required this.members,
    required this.timestamp,
    required this.companyId,
  });

  bool isValid(int? currentCompanyId) {
    if (companyId != currentCompanyId) return false;
    final now = DateTime.now();
    return now.difference(timestamp) < TabConstants.kDataCacheExpiry;
  }
}

class _CommitteeTabState extends ConsumerState<CommitteeTab>
    with TabActivationMixin {
  // Data for committee members
  List<IntercomContact> _committeeMembers = [];
  final TextEditingController _searchController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _searchQuery = '';
  List<IntercomContact> _filteredMembers = [];
  bool _isLoading = true;
  final Set<String> _callStartingContactIds = <String>{};
  final IntercomService _intercomService = IntercomService();
  final ApiService _apiService = ApiService.instance;

  // Cache for committee members data
  _CachedCommitteeData? _cachedData;
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

  // TabActivationMixin implementation
  @override
  ValueNotifier<int>? get activeTabNotifier => widget.activeTabNotifier;

  @override
  int? get tabIndex => widget.tabIndex;

  @override
  bool get isLoading => _isLoading;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeSpeech();
    _loadCurrentUserIds();
    // Initialize tab activation (handles initial load and listener setup)
    initializeTabActivation();
    _setupWebSocketListeners();
  }

  Future<void> _loadCurrentUserIds() async {
    try {
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
            '✅ [CommitteeTab] Cache is valid (age: ${cacheAge.inSeconds}s), skipping API call');

        // CRITICAL FIX: Always ensure state is restored, even if cache is valid
        // When returning from Group chat, state might be cleared even though cache exists
        // Re-render cached data to ensure UI is updated (handles navigation back scenario)
        if (_committeeMembers.isEmpty || _filteredMembers.isEmpty) {
          debugPrint(
              '🔄 [CommitteeTab] State is empty but cache is valid, re-rendering cached data (returning from navigation)');
          _renderCachedDataIfAvailable();
        }

        // Cache is valid - no need to call API
        widget.loadingNotifier?.value = false;
        return;
      }

      // Cache is expired or missing - need to call API
      // CRITICAL: Even if cache is expired, ensure expired data is shown while loading
      // This prevents blank UI during API call
      if (_cachedData != null &&
          (_committeeMembers.isEmpty || _filteredMembers.isEmpty)) {
        debugPrint(
            '🔄 [CommitteeTab] Cache expired but state is empty, showing expired cache while loading fresh data');
        _renderCachedDataIfAvailable(); // Show expired cache as fallback
      }

      debugPrint(
          '🔄 [CommitteeTab] Cache expired/missing, triggering API call (will respect throttling)');
      _checkCacheAndLoad();
    });
  }

  /// Render cached data immediately if available
  ///
  /// This ensures UI is never empty when cached data exists.
  /// Called synchronously on tab activation, before any network calls.
  ///
  /// CRITICAL: This method MUST always render cached data if it exists,
  /// regardless of cache expiry. Network fetch will validate and refresh if needed.
  void _renderCachedDataIfAvailable() {
    if (_cachedData == null) {
      debugPrint(
          'ℹ️ [CommitteeTab] No cached data available for immediate rendering');
      return; // No cached data
    }

    // ALWAYS render cached data if it exists, even if expired
    // This prevents blank UI. Network fetch will refresh if needed.
    if (_cachedData!.members.isNotEmpty) {
      debugPrint(
          '✅ [CommitteeTab] Rendering cached data immediately on activation (${_cachedData!.members.length} members)');

      if (mounted) {
        setState(() {
          // Render cached data immediately - this ensures UI is never blank
          _committeeMembers = List.from(_cachedData!.members);
          _filteredMembers = List.from(_cachedData!.members);
          _isLoading = false;
        });
      }
    } else {
      debugPrint('ℹ️ [CommitteeTab] Cached data exists but is empty');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // CRITICAL FIX: Restore cached data if state is empty (handles navigation back scenario)
    // When returning from Group chat, state might be cleared even though cache exists
    // This ensures data is always visible when returning to the tab
    if (mounted &&
        (_committeeMembers.isEmpty || _filteredMembers.isEmpty) &&
        _cachedData != null) {
      debugPrint(
          '🔄 [CommitteeTab] didChangeDependencies: State is empty but cache exists, restoring cached data');
      _renderCachedDataIfAvailable();
    }

    // Check if company/society has changed and invalidate cache if needed
    _checkCompanyChangeAndReload();
  }

  /// Check if company/society has changed and reload if needed
  Future<void> _checkCompanyChangeAndReload() async {
    if (!mounted || _isLoading) return;

    try {
      final currentCompanyId = await _apiService.getSelectedSocietyId();
      if (currentCompanyId != null &&
          currentCompanyId != _lastLoadedCompanyId) {
        debugPrint(
            '🔄 [CommitteeTab] Company changed from $_lastLoadedCompanyId to $currentCompanyId - Clearing cache and reloading');

        // Clear cache and reset state
        final oldCompanyId = _lastLoadedCompanyId;
        _cachedData = null;
        resetLoadState();
        _lastLoadedCompanyId = null;

        // Clear unread mappings to avoid stale badges across companies
        try {
          await _unreadManager.clearAll();
        } catch (e) {
          debugPrint('⚠️ [CommitteeTab] Failed to clear unread state: $e');
        }

        // Clear per-committee cache for old company
        if (oldCompanyId != null) {
          CommitteeMemberCache().clearForCompany(oldCompanyId);
        }

        // Clear existing data to prevent showing wrong data
        if (mounted) {
          setState(() {
            _committeeMembers = [];
            _filteredMembers = [];
            _isLoading = true;
          });
        }

        // Reload after a delay (cancellable)
        scheduleDelayed(
          delay: TabConstants.kCompanyChangeReloadDelay,
          callback: () {
            if (mounted && !_isLoading) {
              _loadCommitteeMembers();
            }
          },
        );
      }
    } catch (e) {
      debugPrint('❌ [CommitteeTab] Error checking company change: $e');
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
            '⏸️ [CommitteeTab] Request throttled (${remainingSeconds}s remaining)');
        return; // Ignore request - too soon after last one
      }
    }

    // Try to acquire request lock - prevents concurrent requests
    final token = tryAcquireRequestLock();
    if (token == null) {
      debugPrint('⏸️ [CommitteeTab] Request already in-flight, skipping');
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
        debugPrint('⏹️ [CommitteeTab] Tab became inactive, cancelling load');
        return;
      }

      // Cache invalid or missing - load fresh data
      // This ensures committee members API is called when cache is expired or missing
      debugPrint(
          '📡 [CommitteeTab] Cache expired/missing, loading committee members from API...');
      await _loadCommitteeMembers(token: token);
    } catch (e) {
      debugPrint('❌ [CommitteeTab] Error checking cache: $e');
      // Fallback to loading if cache check fails
      await _loadCommitteeMembers(token: token);
    } finally {
      // Release lock after operation completes
      releaseRequestLock();

      // Notify parent that loading completed (allows tab switching)
      widget.loadingNotifier?.value = false;
    }
  }

  @override
  void dispose() {
    _wsMessageSubscription?.cancel();
    _wsConnectionSubscription?.cancel();
    _searchController.dispose();
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
            '📊 [CommitteeTab] Received unread_count_update: room=$updateRoomId, user=$userId, count=$unreadCount');

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
            await _unreadManager.setUnreadCount(updateRoomId, unreadCount);
          }

          // Update contact in committee members list
          final contactId = _unreadManager.getContactIdForRoom(updateRoomId);
          if (contactId != null) {
            _updateContactFromWebSocket(contactId, updateRoomId);
          }
        }
      }
      return; // Don't process unread_count_update as messages
    }

    developer
        .log('📨 [CommitteeTab] Received WebSocket message for room: $roomId');

    // Get contact ID for this room
    final contactId = _unreadManager.getContactIdForRoom(roomId);
    if (contactId == null) return;

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

    // Build activity preview for any incoming activity
    final activityPreview = _buildActivityPreview(wsMessage);
    await _unreadManager.updateLastMessage(
      roomId,
      activityPreview,
      DateTime.now(),
    );

    // Check if this is a system message (should not increment unread count)
    final isSystemMessage = _isSystemMessageFromWebSocket(wsMessage);

    // Backend is source of truth for unread counts (DB + unread_count_update).
    // Do not increment locally. Indicator comes from unread_count_update / API seed.

    // Update contact in committee members list
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

  /// Update a contact in the committee members list based on WebSocket message
  void _updateContactFromWebSocket(String contactId, String roomId) {
    if (!mounted) return;

    final contactIndex = _committeeMembers.indexWhere((c) => c.id == contactId);
    if (contactIndex == -1) return;

    final unreadCount = _unreadManager.getUnreadCount(roomId);
    final lastMessageTime = _unreadManager.getLastMessageTime(roomId);

    // CRITICAL: Preserve hasUserId and numericUserId fields when updating
    final updatedContact = IntercomContact(
      id: _committeeMembers[contactIndex].id,
      name: _committeeMembers[contactIndex].name,
      unit: _committeeMembers[contactIndex].unit,
      role: _committeeMembers[contactIndex].role,
      building: _committeeMembers[contactIndex].building,
      floor: _committeeMembers[contactIndex].floor,
      type: _committeeMembers[contactIndex].type,
      status: _committeeMembers[contactIndex].status,
      hasUnreadMessages: unreadCount > 0,
      photoUrl: _committeeMembers[contactIndex].photoUrl,
      lastContact: lastMessageTime,
      phoneNumber: _committeeMembers[contactIndex].phoneNumber,
      familyMembers: _committeeMembers[contactIndex].familyMembers,
      isPrimary: _committeeMembers[contactIndex].isPrimary,
      numericUserId: _committeeMembers[contactIndex]
          .numericUserId, // Preserve numericUserId
      hasUserId:
          _committeeMembers[contactIndex].hasUserId, // Preserve hasUserId
    );

    setState(() {
      _committeeMembers[contactIndex] = updatedContact;
      _filteredMembers = List.from(_committeeMembers);
    });
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

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterMembers();
    });
  }

  void _filterMembers() {
    if (_searchQuery.isEmpty) {
      _filteredMembers = _committeeMembers;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredMembers = _committeeMembers.where((member) {
        final matchesName = member.name.toLowerCase().contains(query);
        final matchesRole =
            member.role != null && member.role!.toLowerCase().contains(query);
        final matchesPhone = member.phoneNumber != null &&
            member.phoneNumber!.toLowerCase().contains(query);

        return matchesName || matchesRole || matchesPhone;
      }).toList();
    }
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
                _filterMembers();
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
                _filterMembers();
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

  Future<void> _loadCommitteeMembers({TabCancellationToken? token}) async {
    // Token should be provided by caller (from _checkCacheAndLoad)
    // If not provided, this is a standalone call - acquire lock
    bool shouldReleaseLock = false;
    if (token == null) {
      token = tryAcquireRequestLock();
      if (token == null) {
        debugPrint('⏸️ [CommitteeTab] Request lock already held, skipping');
        return;
      }
      shouldReleaseLock = true;
    }

    // PERFORMANCE OPTIMIZATION: Render UI immediately with cached data
    // Do NOT block UI waiting for all API calls - show data progressively
    final hasExistingData = _committeeMembers.isNotEmpty;
    if (!hasExistingData) {
      // Only show loading if we have NO data at all
      // This allows immediate rendering when cache exists
      setState(() {
        _isLoading = true;
      });
    } else {
      // We have cached data - UI is already visible
      // Load fresh data in background without blocking
      debugPrint(
          '🔄 [CommitteeTab] Loading fresh data in background (UI already visible with ${_committeeMembers.length} members)');
    }

    try {
      // PERFORMANCE OPTIMIZATION: Use concurrency-limited fetching with caching
      // This replaces the "26 parallel requests" pattern that caused timeouts
      // - Max 4 concurrent requests (prevents server overload)
      // - Per-committee caching (10-minute TTL)
      // - Progressive loading (data appears as it loads)
      final members = await _loadCommitteeMembersParallel();

      // Check token validity before updating state
      if (!token.isValid(lifecycleController.generation)) {
        debugPrint(
            '⏹️ [CommitteeTab] Tab became inactive during load, discarding result');
        return;
      }

      if (mounted) {
        final currentCompanyId = await _apiService.getSelectedSocietyId();

        setState(() {
          _committeeMembers = members;
          _filteredMembers = members;
          _isLoading = false;
        });

        // Update cache with fresh data
        if (currentCompanyId != null) {
          _cachedData = _CachedCommitteeData(
            members: List.from(members), // Create copy for cache
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
          // This prevents showing "No committee members" when there's a temporary error
        });

        // Check for rate limit errors (429)
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('429') ||
            errorStr.contains('too many requests')) {
          // Handle rate limit gracefully
          if (_committeeMembers.isNotEmpty) {
            debugPrint(
                '✅ [CommitteeTab] Rate limited (429) - showing cached data (${_committeeMembers.length} members)');
            // Silently use cached data - no error toast
          } else {
            debugPrint(
                '⚠️ [CommitteeTab] Rate limited (429) - no cached data, will retry silently');
            // Don't show toast - just log it and let the system retry
            // The user will see the loading state, and data will load when retry succeeds
          }
        } else {
          // Other errors
          // Only show error if we have no data
          if (_committeeMembers.isEmpty) {
            EnhancedToast.error(
              context,
              title: 'Error',
              message: 'Failed to load committee members: ${e.toString()}',
            );
          } else {
            // If we have cached data, show a less intrusive error
            debugPrint(
                '⚠️ [CommitteeTab] Failed to refresh committee members: $e');
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

  /// Load committee members with concurrency limiting and caching
  ///
  /// PERFORMANCE OPTIMIZATION:
  /// - Concurrency limit: Max 4 concurrent requests (prevents server overload)
  /// - Per-committee caching: 10-minute TTL (reduces API calls)
  /// - Progressive loading: Data appears as it loads (no blocking)
  /// - Cache-first: Uses cached data when available (instant rendering)
  ///
  /// This replaces the previous "26 parallel requests" pattern that caused timeouts.
  /// The IntercomService now handles concurrency limiting and caching internally.
  Future<List<IntercomContact>> _loadCommitteeMembersParallel() async {
    return await _intercomService.getCommitteeMembers();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Committee info card with gradient
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
                            // // ),
                            // Main content
                            Row(
                              children: [
                                const Icon(
                                  Icons.groups_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Committee Members',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Progress bar showing availability ratio
                      Container(
                        height: 4,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, Color(0xFFFF9292)],
                          ),
                        ),
                      ),

                      // Info content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contact your society committee members for society-related matters.',
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
                                    // // boxShadow: [
                                    // //   BoxShadow(
                                    // //     color:
                                    // //         AppColors.primary.withOpacity(0.1),
                                    // //     blurRadius: 4,
                                    // //     offset: const Offset(0, 2),
                                    // //   ),
                                    // ],
                                  ),
                                  child: Text(
                                    'Total: ${_committeeMembers.length}',
                                    style: GoogleFonts.montserrat(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    // boxShadow: [
                                    //   BoxShadow(
                                    //     color: Colors.green.withOpacity(0.1),
                                    //     blurRadius: 4,
                                    //     offset: const Offset(0, 2),
                                    //   ),
                                    // ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.green.withOpacity(0.3),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Available: ${_committeeMembers.where((m) => m.status == IntercomContactStatus.online).length}',
                                        style: GoogleFonts.montserrat(
                                          color: Colors.green,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
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
                    hintText: 'Search committee members...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: const Color(0xFFB71C1C).withOpacity(0.7),
                      size: 20,
                    ),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB71C1C).withOpacity(0.1),
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
                          color: _isListening
                              ? Colors.red
                              : const Color(0xFFB71C1C),
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              // Committee members list with enhanced cards
              _isLoading
                  ? const Center(
                      child: AppLoader(
                        title: 'Loading Committee',
                        subtitle: 'Fetching committee members...',
                        icon: Icons.groups_rounded,
                      ),
                    )
                  : (_searchQuery.isEmpty
                              ? _committeeMembers
                              : _filteredMembers)
                          .isEmpty
                      ? _buildEmptyState()
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: (_searchQuery.isEmpty
                                    ? _committeeMembers
                                    : _filteredMembers)
                                .map((member) {
                              return _buildCommitteeMemberCard(member);
                            }).toList(),
                          ),
                        ),

              const SizedBox(height: 20), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  /// Card UI aligned with Residents tab: same container, divider, and action row layout.
  Widget _buildCommitteeMemberCard(IntercomContact member) {
    final isDisabled = !member.hasUserId;
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
          onTap: null,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Member info (same structure as Residents)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
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
                            child: (member.photoUrl != null &&
                                    member.photoUrl!.isNotEmpty)
                                ? Image.network(
                                    member.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Text(
                                          _getInitials(member.name),
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
                                      _getInitials(member.name),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: _getStatusColor(member.status),
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
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                _getRoleIcon(member.role ?? ''),
                                color: Colors.grey.shade600,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                member.role ?? 'Committee Member',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (member.unit != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Unit ${member.unit}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (!member.hasUserId)
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
                    if (!member.hasUserId) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () =>
                            OneAppShare.shareInvite(name: member.name),
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text(
                          'Invite',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
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
              // Action buttons (same as Residents: full-width row with divider)
              const Divider(height: 1, color: Colors.black12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: !member.hasUserId
                              ? Colors.grey.shade400
                              : Colors.blue,
                        ),
                        label: Text(
                          'Chat',
                          style: TextStyle(
                            color: !member.hasUserId
                                ? Colors.grey.shade400
                                : Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: !member.hasUserId
                            ? null
                            : () => _handleChat(member),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.black12,
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: (!member.hasUserId ||
                                _callStartingContactIds.contains(member.id))
                            ? null
                            : () => _onCallPressed(member),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _callStartingContactIds.contains(member.id)
                            ? const SizedBox(
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
                                color: !member.hasUserId
                                    ? Colors.grey.shade400
                                    : Colors.green,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final nameParts = name.split(' ');
    if (nameParts.isEmpty) return '';

    String result = '';
    if (nameParts.isNotEmpty) {
      result += nameParts.first[0];
      if (nameParts.length > 1) {
        result += nameParts.last[0];
      }
    }

    return result.toUpperCase();
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

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'chairman':
        return Icons.star;
      case 'secretary':
        return Icons.description;
      case 'treasurer':
        return Icons.account_balance_wallet;
      case 'joint secretary':
        return Icons.description_outlined;
      case 'sports secretary':
        return Icons.sports_soccer;
      case 'cultural secretary':
        return Icons.music_note;
      default:
        return Icons.person;
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

  /// Show popup with Audio and Video Call options using Jitsi SDK (same as Residents tab)
  Future<void> _showCallOptionsPopup(IntercomContact contact) async {
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
      developer.log('CommitteeTab: Error getting user data: $e');
    }

    if (!mounted) return;

    unawaited(CallBottomSheet.show(
      context: context,
      contact: contact,
      displayName: displayName,
      avatarUrl: avatarUrl,
      userEmail: userEmail,
    ));
  }

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

  Widget _buildEmptyState() {
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
              child: const Icon(
                Icons.groups_outlined,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No committee members available',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Committee members will appear here when available',
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
