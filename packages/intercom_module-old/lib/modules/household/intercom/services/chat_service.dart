import 'dart:developer';
import 'dart:async';
import '../models/room_model.dart';
import '../models/room_message_model.dart';
import '../models/membership_validation_result.dart';
import 'room_service.dart';
import 'chat_websocket_service.dart';
import '../../../../core/models/api_response.dart';
import 'rooms_cache.dart';
import '../../../../core/services/request_scheduler.dart';
import '../../../../core/storage/storage_service.dart';

/// Unified Chat Service combining REST and WebSocket
///
/// Architecture:
/// - REST: Fetch rooms, fetch message history, join room
/// - WebSocket: Real-time messaging, room joining
///
/// Single WebSocket connection per user (shared across all rooms)
class ChatService {
  static ChatService? _instance;
  static const String _logName = 'ChatService';

  final RoomService _roomService = RoomService.instance;
  final ChatWebSocketService _wsService = ChatWebSocketService.instance;

  final Map<String, Timer> _joinRetryTimers = {};
  static const Duration _membershipWaitCap = Duration(seconds: 8);

  ChatService._();

  /// Get singleton instance
  static ChatService get instance {
    _instance ??= ChatService._();
    return _instance!;
  }

  /// Initialize WebSocket connection (call on app launch)
  Future<bool> initializeWebSocket() async {
    log('Initializing WebSocket connection', name: _logName);
    return await _wsService.connect();
  }

  /// Fetch all rooms (REST) with caching and request coalescing
  ///
  /// GET /rooms/all?company_id=12345&is_member=true
  ///
  /// CRITICAL FIX: Uses global cache to prevent duplicate API calls
  /// - Checks cache first (45-second TTL)
  /// - Coalesces in-flight requests (shares Future if request already in progress)
  /// - Handles 429 gracefully (uses cached data, retries with backoff)
  ///
  /// This prevents API storm when Chat History and Chat Screen both request rooms
  Future<ApiResponse<List<Room>>> fetchRooms({
    int? companyId,
    String? chatType,
  }) async {
    if (companyId == null) {
      log(
        '⚠️ [ChatService] Company ID is null, cannot fetch rooms',
        name: _logName,
      );
      return ApiResponse.error('Company ID is required', statusCode: 400);
    }

    final cache = RoomsCache();

    // Step 1: Check cache first
    final cachedRooms = cache.getCachedRooms(companyId, chatType);
    if (cachedRooms != null) {
      log(
        '✅ [ChatService] Using cached rooms (${cachedRooms.length} rooms)',
        name: _logName,
      );
      return ApiResponse.success(
        cachedRooms,
        message: 'Rooms fetched from cache',
        statusCode: 200,
      );
    }

    // Step 2: Check if request is already in-flight (request coalescing)
    final inFlightRequest = cache.getInFlightRequest(companyId, chatType);
    if (inFlightRequest != null) {
      log(
        '⏸️ [ChatService] Request already in-flight for companyId=$companyId, chatType=$chatType - coalescing request',
        name: _logName,
      );
      // Return the existing future - this prevents duplicate API calls
      return inFlightRequest;
    }

    // Step 3: Make API call via RequestScheduler (with concurrency limits and priority)
    log(
      '🌐 [ChatService] Fetching rooms from API: companyId=$companyId, chatType=$chatType',
      name: _logName,
    );

    // Determine priority based on context (default to visibleTab for room list)
    final priority = RequestPriority.visibleTab;
    final feature = RequestFeature.chat;

    // Generate request key for deduplication
    final requestKey =
        'GET_/rooms_companyId=${companyId}_chatType=${chatType ?? "all"}';

    // Schedule via RequestScheduler (handles concurrency, deduplication, cancellation)
    final future = RequestScheduler().schedule<ApiResponse<List<Room>>>(
      requestKey: requestKey,
      priority: priority,
      feature: feature,
      execute: () =>
          _roomService.getAllRooms(companyId: companyId, chatType: chatType),
      ownerId: null, // Global request, not tied to specific tab
    );

    // Mark as in-flight (for request coalescing in RoomsCache)
    cache.markRequestInFlight(companyId, chatType, future);

    try {
      final response = await future;

      // Step 4: Cache successful responses
      if (response.success && response.data != null) {
        cache.cacheRooms(companyId, response.data!, chatType);
        log(
          '✅ [ChatService] Cached ${response.data!.length} rooms: companyId=$companyId, chatType=$chatType',
          name: _logName,
        );
      } else if (response.statusCode == 429) {
        // CRITICAL: On 429, try to use cached data even if expired (better than nothing)
        final expiredCache = cache.getCachedRooms(companyId, chatType);
        if (expiredCache != null) {
          log(
            '⚠️ [ChatService] 429 error - using expired cache (${expiredCache.length} rooms)',
            name: _logName,
          );
          return ApiResponse.success(
            expiredCache,
            message: 'Rate limited - using cached data',
            statusCode: 200, // Return success with cached data
          );
        }
        log(
          '⚠️ [ChatService] 429 error and no cached data available',
          name: _logName,
        );
      }

      return response;
    } catch (e) {
      log('❌ [ChatService] Error fetching rooms: $e', name: _logName);

      // On error, try to use cached data as fallback
      final cachedRooms = cache.getCachedRooms(companyId, chatType);
      if (cachedRooms != null) {
        log(
          '✅ [ChatService] Error occurred - using cached data (${cachedRooms.length} rooms) as fallback',
          name: _logName,
        );
        return ApiResponse.success(
          cachedRooms,
          message: 'Using cached data due to error',
          statusCode: 200,
        );
      }

      return ApiResponse.error('Failed to fetch rooms: $e', statusCode: 0);
    }
  }

  /// Invalidate cached rooms for a given company and optional chatType.
  /// Useful when the rooms list changes (e.g. a new 1-1 room is created) so
  /// subsequent fetchRooms() calls hit the API instead of stale cache.
  void invalidateRoomsCache({required int companyId, String? chatType}) {
    RoomsCache().invalidateEntry(companyId, chatType);
  }

  /// Fetch message history for a room (REST)
  ///
  /// GET /rooms/{roomId}/messages?company_id={companyId}&limit=50&offset=0
  Future<ApiResponse<List<RoomMessage>>> fetchMessages({
    required String roomId,
    int? companyId,
    int limit = 50,
    int offset = 0,
  }) async {
    return await _roomService.getMessages(
      roomId: roomId,
      companyId: companyId,
      limit: limit,
      offset: offset,
    );
  }

  /// Validate membership via POST /rooms/join with typed result.
  Future<MembershipValidationResult> validateMembership(
    String roomId, {
    bool isMember = false,
    int? companyId,
  }) async {
    final start = DateTime.now();
    log(
      '🔍 [ChatService] Membership validation start room=$roomId isMember=$isMember',
      name: _logName,
    );

    final response = await _roomService.joinRoom(
      roomId,
      companyId: companyId,
    );
    final duration = DateTime.now().difference(start);

    if (response.success) {
      log(
        '✅ [ChatService] Membership success in ${duration.inMilliseconds}ms',
        name: _logName,
      );
      return MembershipValidationResult(
        type: MembershipValidationType.success,
        statusCode: response.statusCode,
        message: response.message,
        duration: duration,
      );
    }

    final statusCode = response.statusCode;
    final errorMessage = (response.error ?? response.message ?? '').toLowerCase();

    log(
      '🔍 [ChatService] Membership validation end ${duration.inMilliseconds}ms '
      'status=$statusCode error=$errorMessage',
      name: _logName,
    );

    if (statusCode == 409 ||
        errorMessage.contains('already a member') ||
        errorMessage.contains('already member')) {
      return MembershipValidationResult(
        type: MembershipValidationType.success,
        statusCode: statusCode ?? 409,
        message: response.message,
        duration: duration,
      );
    }

    if (statusCode == 403 && _isExplicitMembershipDenial(errorMessage)) {
      return MembershipValidationResult(
        type: MembershipValidationType.notMember,
        statusCode: statusCode,
        message: response.error ?? response.message,
        duration: duration,
      );
    }

    if (statusCode == 404) {
      return MembershipValidationResult(
        type: MembershipValidationType.notMember,
        statusCode: statusCode,
        message: response.error ?? response.message,
        duration: duration,
      );
    }

    if (statusCode == 429) {
      if (isMember) {
        log(
          '✅ [ChatService] 429 but isMember=true — treating as success',
          name: _logName,
        );
        return MembershipValidationResult(
          type: MembershipValidationType.success,
          statusCode: statusCode,
          message: response.message,
          duration: duration,
        );
      }
      return MembershipValidationResult(
        type: MembershipValidationType.networkTimeout,
        statusCode: statusCode,
        message: response.error ?? response.message,
        duration: duration,
      );
    }

    if (_isNetworkFailure(statusCode, errorMessage)) {
      log(
        '⚠️ [ChatService] Membership network failure — chat may continue '
        '(not treating as notMember)',
        name: _logName,
      );
      return MembershipValidationResult(
        type: MembershipValidationType.networkTimeout,
        statusCode: statusCode,
        message: response.error ?? response.message,
        duration: duration,
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return MembershipValidationResult(
        type: MembershipValidationType.serverError,
        statusCode: statusCode,
        message: response.error ?? response.message,
        duration: duration,
      );
    }

    return MembershipValidationResult(
      type: MembershipValidationType.unknownError,
      statusCode: statusCode,
      message: response.error ?? response.message,
      duration: duration,
    );
  }

  bool _isExplicitMembershipDenial(String errorLower) {
    return errorLower.contains('not a member') ||
        errorLower.contains('no longer a member') ||
        errorLower.contains('left the group') ||
        errorLower.contains('removed from group') ||
        errorLower.contains('not member of') ||
        (errorLower.contains('forbidden') && errorLower.contains('member'));
  }

  bool _isNetworkFailure(int? statusCode, String errorLower) {
    if (statusCode == null || statusCode == 0 || statusCode == 408) {
      return true;
    }
    return errorLower.contains('timeout') ||
        errorLower.contains('connection') ||
        errorLower.contains('socket') ||
        errorLower.contains('network') ||
        errorLower.contains('cancel');
  }

  /// Ensure user is a member of the room (REST) — legacy bool API.
  Future<bool> ensureMembership(String roomId, {bool isMember = false}) async {
    final result = await validateMembership(roomId, isMember: isMember);
    return result.isSuccess;
  }

  void _scheduleJoinRetry({
    required String roomId,
    int? companyId,
    bool isMember = false,
    int attempt = 1,
  }) {
    _joinRetryTimers[roomId]?.cancel();
    if (attempt > 5) {
      log(
        '⚠️ [ChatService] Join retry exhausted for room $roomId',
        name: _logName,
      );
      return;
    }

    final delay = Duration(seconds: (2 * attempt).clamp(2, 30));
    log(
      '🔄 [ChatService] Scheduling join retry #$attempt in ${delay.inSeconds}s '
      'for room $roomId',
      name: _logName,
    );

    _joinRetryTimers[roomId] = Timer(delay, () async {
      final result = await validateMembership(
        roomId,
        isMember: isMember,
        companyId: companyId,
      );
      if (result.isSuccess) {
        log(
          '✅ [ChatService] Join retry #$attempt succeeded for $roomId',
          name: _logName,
        );
        if (_isUuid(roomId)) {
          await _ensureWebSocketConnection(roomId);
        }
        return;
      }
      if (result.isTransientFailure) {
        _scheduleJoinRetry(
          roomId: roomId,
          companyId: companyId,
          isMember: isMember,
          attempt: attempt + 1,
        );
      }
    });
  }

  Future<void> _maybeConnectWebSocket({
    required String roomId,
    required bool hasValidUuid,
    required MembershipValidationResult membership,
    required ApiResponse<List<RoomMessage>> messagesResponse,
    required bool isMember,
    required bool allowNewRoom,
  }) async {
    if (!hasValidUuid) return;

    final messagesOk = messagesResponse.success;
    final membershipOk = membership.isSuccess;
    final canConnect =
        membershipOk || allowNewRoom || isMember || messagesOk;

    if (!canConnect) return;

    final wsStart = DateTime.now();
    log('🔌 [ChatService] WebSocket connect start room=$roomId', name: _logName);
    await _ensureWebSocketConnection(roomId);
    log(
      '🔌 [ChatService] WebSocket connect end ${DateTime.now().difference(wsStart).inMilliseconds}ms',
      name: _logName,
    );
  }

  /// Open a room for real-time chat
  ///
  /// Flow:
  /// 1. Ensure membership (REST) - try to join, but allow proceeding if room doesn't exist yet
  /// 2. Fetch message history (REST)
  /// 3. Connect WebSocket if not connected (CRITICAL for 1-to-1 chats)
  /// 4. Join room via WebSocket
  Future<ApiResponse<List<RoomMessage>>> openRoom({
    required String roomId,
    bool isMember = false,
    int? companyId,
    int limit = 50,
    int offset = 0,
    bool allowNewRoom =
        false, // For 1-to-1 chats, allow proceeding if room doesn't exist
  }) async {
    try {
      final roomOpenStart = DateTime.now();
      log(
        '📂 [ChatService] Room open start room=$roomId isMember=$isMember '
        'allowNewRoom=$allowNewRoom time=${roomOpenStart.toIso8601String()}',
        name: _logName,
      );

      if (await _hasUserLeftGroup(roomId)) {
        log(
          '🚫 [ChatService] User has left group $roomId - blocking access',
          name: _logName,
        );
        return ApiResponse.error(
          'You have left this group and cannot re-enter. Contact an admin to be re-added.',
          statusCode: 403,
        );
      }

      final hasValidUuid = _isUuid(roomId);

      // Membership + messages in parallel — messages must not wait for join.
      final membershipFuture = validateMembership(
        roomId,
        isMember: isMember,
        companyId: companyId,
      );

      final messagesStart = DateTime.now();
      log(
        '📡 [ChatService] Messages API start room=$roomId',
        name: _logName,
      );
      final messagesFuture = fetchMessages(
        roomId: roomId,
        companyId: companyId,
        limit: limit,
        offset: offset,
      );

      final messagesResponse = await messagesFuture;
      final messagesDuration = DateTime.now().difference(messagesStart);
      log(
        '📥 [ChatService] Messages API end ${messagesDuration.inMilliseconds}ms '
        'success=${messagesResponse.success} '
        'count=${messagesResponse.data?.length ?? 0}',
        name: _logName,
      );

      MembershipValidationResult membership;
      try {
        membership = await membershipFuture.timeout(
          _membershipWaitCap,
          onTimeout: () {
            log(
              '⏱️ [ChatService] /rooms/join still running after '
              '${_membershipWaitCap.inSeconds}s — not blocking chat',
              name: _logName,
            );
            unawaited(
              membershipFuture.then((lateResult) async {
                log(
                  '🔍 [ChatService] Late membership result: $lateResult',
                  name: _logName,
                );
                if (lateResult.isSuccess || messagesResponse.success) {
                  await _maybeConnectWebSocket(
                    roomId: roomId,
                    hasValidUuid: hasValidUuid,
                    membership: lateResult,
                    messagesResponse: messagesResponse,
                    isMember: isMember,
                    allowNewRoom: allowNewRoom,
                  );
                }
                if (lateResult.isTransientFailure) {
                  _scheduleJoinRetry(
                    roomId: roomId,
                    companyId: companyId,
                    isMember: isMember,
                  );
                }
              }),
            );
            return MembershipValidationResult(
              type: MembershipValidationType.networkTimeout,
              message: 'Join still in progress',
              duration: _membershipWaitCap,
            );
          },
        );
      } catch (e) {
        membership = MembershipValidationResult(
          type: MembershipValidationType.unknownError,
          message: e.toString(),
          duration: DateTime.now().difference(roomOpenStart),
        );
      }

      log(
        '🔍 [ChatService] Membership result: ${membership.type} '
        '(${membership.duration.inMilliseconds}ms)',
        name: _logName,
      );

      if (membership.isNotMember && !allowNewRoom && !messagesResponse.success) {
        log(
          '❌ [ChatService] Genuine notMember — blocking chat',
          name: _logName,
        );
        return ApiResponse.error(
          membership.message ?? 'You are not a member of this group',
          statusCode: membership.statusCode ?? 403,
        );
      }

      if (membership.isTransientFailure) {
        log(
          '⚠️ [ChatService] Chat continues — failure is network-related '
          '(type=${membership.type}), not membership denial',
          name: _logName,
        );
        _scheduleJoinRetry(
          roomId: roomId,
          companyId: companyId,
          isMember: isMember,
        );
      }

      await _maybeConnectWebSocket(
        roomId: roomId,
        hasValidUuid: hasValidUuid,
        membership: membership,
        messagesResponse: messagesResponse,
        isMember: isMember,
        allowNewRoom: allowNewRoom,
      );

      if (!messagesResponse.success && allowNewRoom) {
        log(
          '⚠️ [ChatService] allowNewRoom — returning empty messages',
          name: _logName,
        );
        return ApiResponse.success(
          <RoomMessage>[],
          message: 'Room is new, no messages yet',
          statusCode: 200,
        );
      }

      if (messagesResponse.success) {
        log(
          '✅ [ChatService] Room open complete in '
          '${DateTime.now().difference(roomOpenStart).inMilliseconds}ms',
          name: _logName,
        );
        return messagesResponse;
      }

      if (membership.isTransientFailure) {
        return ApiResponse.error(
          messagesResponse.error ?? 'Unable to load messages',
          statusCode: messagesResponse.statusCode ?? 0,
        );
      }

      return messagesResponse;
    } catch (e) {
      log('Error opening room: $e', name: _logName);
      return ApiResponse.error('Failed to open room: $e', statusCode: 0);
    }
  }

  /// Send a message via WebSocket
  ///
  /// Message is automatically persisted by backend
  /// Sender receives their own message via WebSocket
  ///
  /// CRITICAL: Backend requires UUID for room_id in WebSocket connection URL.
  /// For 1-to-1 chat, roomId MUST be UUID. If numeric, room will be created on first message
  /// and UUID will be returned via WebSocket response.
  Future<bool> sendMessage({
    required String roomId,
    required String content,
    String messageType = 'text',
    String? replyTo, // ID of the message this is replying to
  }) async {
    log(
      '📤 [ChatService] sendMessage called with roomId: $roomId',
      name: _logName,
    );
    log('   RoomId is UUID: ${_isUuid(roomId)}', name: _logName);
    log(
      '   Current WebSocket connection roomId: ${_wsService.currentConnectionRoomId}',
      name: _logName,
    );
    log('   WebSocket is connected: ${_wsService.isConnected}', name: _logName);

    // CRITICAL: For 1-to-1 chats, ensure WebSocket is connected to the correct room
    // If roomId is UUID, WebSocket MUST be connected with that room_id in the URL
    if (_isUuid(roomId)) {
      // Check if WebSocket is connected to a different room
      final currentConnectionRoomId = _wsService.currentConnectionRoomId;
      final isConnectedToDifferentRoom =
          _wsService.isConnected &&
          currentConnectionRoomId != null &&
          currentConnectionRoomId != roomId;

      if (isConnectedToDifferentRoom) {
        log(
          '⚠️ [ChatService] WebSocket connected to different room ($currentConnectionRoomId), reconnecting with correct room_id: $roomId',
          name: _logName,
        );
        // Reconnect with correct room_id before sending message
        await _ensureWebSocketConnection(roomId);
      } else if (!_wsService.isConnected) {
        log(
          '⚠️ [ChatService] WebSocket not connected, connecting with room_id: $roomId',
          name: _logName,
        );
        // Connect WebSocket before sending message
        await _ensureWebSocketConnection(roomId);
      } else {
        log(
          '✅ [ChatService] WebSocket connected to correct room: $roomId',
          name: _logName,
        );
      }
    } else {
      // Numeric room_id - room should have been created first
      log(
        '⚠️ [ChatService] Sending first message with numeric roomId: $roomId',
        name: _logName,
      );
      log(
        '   This is the first message - backend will create room and return UUID',
        name: _logName,
      );
      log(
        '   WebSocket will connect without room_id, send message, then reconnect with UUID',
        name: _logName,
      );
    }

    return await _wsService.sendMessage(
      roomId: roomId,
      content: content,
      messageType: messageType,
      replyTo: replyTo,
    );
  }

  /// Get WebSocket message stream
  Stream<WebSocketMessage> get messageStream => _wsService.messageStream;

  /// Get connection state stream
  Stream<bool> get connectionStateStream => _wsService.connectionStateStream;

  /// Check if WebSocket is connected
  bool get isWebSocketConnected => _wsService.isConnected;

  /// Forward an existing message to one or more rooms using REST API
  ///
  /// Delegates to RoomService.forwardMessage. Enforces the server limit
  /// (maximum 5 target rooms) and returns the API response for UI handling.
  Future<ApiResponse<Map<String, dynamic>>> forwardMessage({
    required String messageId,
    required List<String> targetRoomIds,
  }) async {
    if (targetRoomIds.isEmpty) {
      return ApiResponse.error(
        'At least one target room is required',
        statusCode: 400,
      );
    }

    if (targetRoomIds.length > 5) {
      return ApiResponse.error(
        'Forwarding limit exceeded: max 5 chats per forward',
        statusCode: 400,
      );
    }

    return _roomService.forwardMessage(
      messageId: messageId,
      targetRoomIds: targetRoomIds,
    );
  }

  /// Ensure WebSocket is connected for a room (extracted for reuse)
  Future<void> _ensureWebSocketConnection(String roomId) async {
    final isAlreadyJoined = _wsService.joinedRooms.contains(roomId);

    // Check if websocket is connected to a different room
    // This is critical for resident chat when switching from group chat
    // Use currentConnectionRoomId to check which room is in the connection URL
    final currentConnectionRoomId = _wsService.currentConnectionRoomId;
    final isConnectedToDifferentRoom =
        _wsService.isConnected &&
        currentConnectionRoomId != null &&
        currentConnectionRoomId != roomId;

    log(
      '🔌 [ChatService] Ensuring WebSocket connection for room: $roomId',
      name: _logName,
    );
    log(
      '   Current connection roomId: $currentConnectionRoomId',
      name: _logName,
    );
    log('   Is connected: ${_wsService.isConnected}', name: _logName);
    log('   Is already joined: $isAlreadyJoined', name: _logName);
    log(
      '   Is connected to different room: $isConnectedToDifferentRoom',
      name: _logName,
    );

    // CRITICAL FIX: Always check for different room connection FIRST
    // This ensures WebSocket reconnects when switching between chats (1-to-1 or group)
    if (isConnectedToDifferentRoom) {
      // WebSocket is connected to a different room - must reconnect with correct room_id
      log(
        '🔄 [ChatService] WebSocket connected to different room ($currentConnectionRoomId), reconnecting with room_id: $roomId',
        name: _logName,
      );
      await _wsService.disconnect();
      // Fall through to connect with correct room_id below
    }

    // Connect WebSocket if not connected or was disconnected above
    if (!_wsService.isConnected) {
      log(
        '🔌 [ChatService] Connecting WebSocket with room_id: $roomId...',
        name: _logName,
      );
      // Connect with room_id in the connection URL as per backend specification
      // Format: ws://{{base_url_without_protocol}}/api/v1/ws?token={{access_token}}&room_id={{room_id}}
      final connected = await _wsService.connect(roomId: roomId);
      if (!connected) {
        log(
          '❌ [ChatService] WebSocket connection FAILED for room: $roomId',
          name: _logName,
        );
        log(
          '⚠️ Continuing with REST API only - messages may not be real-time',
          name: _logName,
        );
        // Continue without WebSocket - user can still see messages via REST
      } else {
        log(
          '✅ [ChatService] WebSocket connected successfully with room_id: $roomId',
          name: _logName,
        );
        // Wait for connection to stabilize
        await Future.delayed(const Duration(milliseconds: 500));
        // Mark room as joined since it's in the connection URL
        _wsService.markRoomJoined(roomId);
        log('✅ [ChatService] Room marked as joined: $roomId', name: _logName);
      }
    } else if (!isAlreadyJoined) {
      // WebSocket is connected to the correct room but we haven't marked it as joined yet
      // This can happen if connection was established but room wasn't marked
      log(
        '✅ [ChatService] WebSocket connected to correct room, marking as joined: $roomId',
        name: _logName,
      );
      _wsService.markRoomJoined(roomId);
    } else {
      log(
        '✅ [ChatService] WebSocket already connected and room already joined: $roomId',
        name: _logName,
      );
    }
  }

  /// Check if user has left a specific group (persisted state)
  Future<bool> _hasUserLeftGroup(String groupId) async {
    try {
      final storage = StorageService.instance;
      final leftGroupsJson = await storage.getJson('left_groups');
      if (leftGroupsJson != null && leftGroupsJson['groups'] is List) {
        final groups = (leftGroupsJson['groups'] as List).cast<String>();
        return groups.contains(groupId);
      }
      return false;
    } catch (e) {
      log(
        '❌ [ChatService] Error checking if user left group $groupId: $e',
        name: _logName,
      );
      return false; // Default to false on error to allow access
    }
  }

  /// Helper to check if a string is a valid UUID format
  bool _isUuid(String? str) {
    if (str == null || str.isEmpty) return false;
    // UUID format: 8-4-4-4-12 hex digits with dashes
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(str);
  }

  /// Leave a room (cleanup when user navigates away)
  Future<void> leaveRoom(String roomId) async {
    await _wsService.leaveRoom(roomId);
  }

  /// Disconnect WebSocket (call on app close or logout)
  Future<void> disconnect() async {
    await _wsService.disconnect();
  }

  /// Clear chat for a room (user-specific)
  ///
  /// POST /api/v1/rooms/clear?company_id={companyId}
  ///
  /// Remove a member from a group
  Future<ApiResponse<void>> removeMemberFromGroup({
    required String groupId,
    required String memberId,
    required int companyId,
  }) async {
    return _roomService.removeRoomMember(roomId: groupId, userId: memberId);
  }

  /// This clears chat only for the current user.
  /// Other members will still see their chat history.
  /// WebSocket connection remains active.
  Future<ApiResponse<void>> clearChat({
    required String roomId,
    required int companyId,
  }) async {
    log('Clearing chat for room: $roomId', name: _logName);
    return await _roomService.clearChat(roomId: roomId, companyId: companyId);
  }

  /// Get read receipts for a specific message
  ///
  /// Returns a list of users who have read the message with their read timestamps.
  /// This is useful for showing "seen by" information in group chats.
  ///
  /// GET /api/v1/messages/{messageId}/read-receipts
  Future<ApiResponse<List<Map<String, dynamic>>>> getReadReceipts(
    String messageId,
  ) async {
    log(
      '📖 [ChatService] Fetching read receipts for message: $messageId',
      name: _logName,
    );
    return await _roomService.getReadReceipts(messageId);
  }

  /// Mark a specific message as read
  ///
  /// This marks a specific message as read for the current user.
  /// The backend will track this and update read receipts accordingly.
  ///
  /// POST /api/v1/messages/{messageId}/read
  Future<ApiResponse<void>> markMessageAsRead(String messageId) async {
    log('📖 [ChatService] Marking message as read: $messageId', name: _logName);
    return await _roomService.markMessageAsRead(messageId);
  }

  /// Update user's online presence status
  ///
  /// Sets the current user's online/offline status.
  /// Call this when app comes to foreground or user becomes active.
  ///
  /// POST /api/v1/presence
  Future<ApiResponse<void>> updatePresence({
    required bool isOnline,
    required String status,
  }) async {
    log(
      '👤 [ChatService] Updating presence: isOnline=$isOnline, status=$status',
      name: _logName,
    );
    return await _roomService.updatePresence(
      isOnline: isOnline,
      status: status,
    );
  }

  /// Get presence status for multiple users
  ///
  /// Fetches online/offline status for a list of user IDs.
  /// Use this to show presence indicators in contact lists.
  ///
  /// GET /api/v1/presence?user_ids=uuid1,uuid2
  Future<ApiResponse<List<Map<String, dynamic>>>> getPresence(
    List<String> userIds,
  ) async {
    log(
      '👥 [ChatService] Fetching presence for ${userIds.length} users',
      name: _logName,
    );
    return await _roomService.getPresence(userIds);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _wsService.dispose();
  }
}
