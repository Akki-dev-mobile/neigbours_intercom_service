import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../../../../core/services/auth_token_manager.dart';
import '../../../../core/constants.dart';

/// WebSocket message types
enum WebSocketMessageType {
  join,
  message,
  error,
  unreadCountUpdate,
  readReceipt,
  presenceUpdate,
  unknown,
}

/// WebSocket message model
class WebSocketMessage {
  final String? type;
  final String? roomId;
  final String? userId;
  final String? content;
  final String? messageType;
  final Map<String, dynamic>? data;
  final String? error;

  WebSocketMessage({
    this.type,
    this.roomId,
    this.userId,
    this.content,
    this.messageType,
    this.data,
    this.error,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    // Helpers for flexible key lookup
    String? getStringFlex(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      // Also check nested "data" map for the same keys
      final data = json['data'];
      if (data is Map<String, dynamic>) {
        for (final k in keys) {
          final v = data[k];
          if (v != null && v.toString().trim().isNotEmpty) return v.toString();
        }
      }
      return null;
    }

    final resolvedType = getStringFlex(['type', 'message_type']);
    final resolvedRoomId = getStringFlex(['room_id', 'roomId']);
    final resolvedUserId = getStringFlex(['user_id', 'userId']);
    final resolvedContent = getStringFlex(['content', 'message']);
    final resolvedMessageType = getStringFlex(['message_type', 'type']);
    final resolvedError = getStringFlex(['error']);

    return WebSocketMessage(
      type: resolvedType,
      roomId: resolvedRoomId,
      userId: resolvedUserId,
      content: resolvedContent,
      messageType: resolvedMessageType,
      data: json['data'] as Map<String, dynamic>?,
      error: resolvedError,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (type != null) json['type'] = type;
    if (roomId != null) json['room_id'] = roomId;
    if (userId != null) json['user_id'] = userId;
    if (content != null) json['content'] = content;
    if (messageType != null) json['message_type'] = messageType;
    if (data != null) json['data'] = data;
    if (error != null) json['error'] = error;
    return json;
  }

  WebSocketMessageType get messageTypeEnum {
    switch (type?.toLowerCase()) {
      case 'join':
        return WebSocketMessageType.join;
      case 'message':
        return WebSocketMessageType.message;
      case 'error':
        return WebSocketMessageType.error;
      case 'unread_count_update':
      case 'unreadcountupdate':
        return WebSocketMessageType.unreadCountUpdate;
      case 'read_receipt':
      case 'readreceipt':
        return WebSocketMessageType.readReceipt;
      case 'presence_update':
      case 'presenceupdate':
        return WebSocketMessageType.presenceUpdate;
      case 'reaction':
      case 'reply':
      case 'file':
      case 'image':
      case 'photo':
      case 'video':
      case 'audio':
      case 'voice':
      case 'document':
        return WebSocketMessageType.message; // treat as message for UI updates
      default:
        return WebSocketMessageType.unknown;
    }
  }
}

/// WebSocket Service for real-time chat
///
/// WebSocket Endpoint: ws://{{base_url_without_protocol}}/api/v1/ws?token={{access_token}}&room_id={{room_id}}
///
/// URL Format:
/// ws://13.201.27.102:7071/api/v1/ws?token=<access_token>&room_id=<room_id>
///
/// Flow (as per backend specification):
/// 1. Connect: Client connects to WebSocket endpoint with authentication token and room_id in query parameters
/// 2. Join Room: If room_id not in connection URL, client sends a message to join: {"type": "join", "room_id": "..."}
/// 3. Send Messages: Client sends messages to the room: {"type": "message", "room_id": "...", "content": "...", "message_type": "text"}
/// 4. Receive Messages: Client receives messages broadcasted to the room (format: {room_id, user_id, content, message_type, data: {...}})
/// 5. Disconnect: Client disconnects or connection is closed
///
/// Message Formats:
/// - Join Room: {"type": "join", "room_id": "550e8400-e29b-41d4-a716-446655440000"}
/// - Send Message: {"type": "message", "room_id": "...", "content": "...", "message_type": "text"}
/// - Receive Message: {room_id, user_id, content, message_type, data: {id, room_id, user_id, content, message_type, created_at, updated_at}}
class ChatWebSocketService {
  static ChatWebSocketService? _instance;
  static const String _logName = 'ChatWebSocketService';

  // WebSocket configuration - matches REST API base URL
  // WebSocket Endpoint: ws://13.201.27.102:7071/api/v1/ws?token={token}&room_id={room_id}
  static String get _wsBaseUrl {
    // Match the REST API base URL pattern
    final restBaseUrl = AppConstants.roomServiceBaseUrl;
    // Convert http:// to ws:// for WebSocket
    // Final URL format: ws://13.201.27.102:7071/api/v1/ws?token={token}&room_id={room_id}
    return '${restBaseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://')}/ws';
  }

  WebSocketChannel? _channel;
  WebSocket?
      _webSocket; // Store reference to underlying WebSocket for state checks
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _isConnecting = false;
  final Set<String> _joinedRooms = {};
  String?
      _currentConnectionRoomId; // Track which room_id was used in the connection URL

  // Reconnection state
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  // Message stream controller
  final StreamController<WebSocketMessage> _messageController =
      StreamController<WebSocketMessage>.broadcast();

  // Connection state stream controller
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  // Callbacks
  Function(WebSocketMessage)? onMessage;
  Function(String)? onError;
  Function()? onConnected;
  Function()? onDisconnected;

  ChatWebSocketService._();

  /// Get singleton instance
  static ChatWebSocketService get instance {
    _instance ??= ChatWebSocketService._();
    return _instance!;
  }

  /// Check if WebSocket is connected
  bool get isConnected {
    // Verify actual connection state
    final isActuallyConnected = _isConnected &&
        _channel != null &&
        _webSocket != null &&
        _webSocket?.readyState == WebSocket.open;

    // Update internal state if mismatch
    if (_isConnected && !isActuallyConnected) {
      log('⚠️ Connection state mismatch detected, correcting...',
          name: _logName);
      _isConnected = false;
      _connectionStateController.add(false);
    }

    return isActuallyConnected;
  }

  /// Get list of joined rooms
  Set<String> get joinedRooms => Set.from(_joinedRooms);

  /// Get the room_id that was used in the connection URL (if any)
  /// This is different from joinedRooms - it only tracks rooms connected via URL parameter
  String? get currentConnectionRoomId => _currentConnectionRoomId;

  /// Stream of incoming messages
  Stream<WebSocketMessage> get messageStream => _messageController.stream;

  /// Stream of connection state changes
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  /// Connect to WebSocket server

  /// Generate a hash of the token for URL shortening
  /// Note: This is a temporary solution - proper session tokens should be used

  /// Connect to WebSocket server
  ///
  /// Uses token from query parameter (required for browser compatibility)
  /// Optionally includes room_id in connection URL if provided
  ///
  /// URL format: ws://{{base_url_without_protocol}}/api/v1/ws?token={{access_token}}&room_id={{room_id}}
  Future<bool> connect({String? roomId}) async {
    // If already connected, check if we need to reconnect with a different room_id
    if (_isConnected) {
      // Determine if we need to reconnect:
      // 1. If roomId is UUID and different from current connection UUID -> reconnect
      // 2. If roomId is numeric and current connection has UUID -> reconnect (need to connect without room_id)
      // 3. If roomId is UUID and current connection has no room_id -> reconnect (need to connect with UUID)
      // 4. If roomId is numeric and current connection has no room_id -> stay connected (already correct)
      // 5. If roomId matches current connection -> stay connected

      final needsReconnect = (roomId != null &&
              roomId.isNotEmpty &&
              _isUuid(roomId) &&
              _currentConnectionRoomId != roomId) ||
          (roomId != null &&
              roomId.isNotEmpty &&
              !_isUuid(roomId) &&
              _currentConnectionRoomId != null) ||
          (roomId == null && _currentConnectionRoomId != null);

      if (needsReconnect) {
        log('⚠️ WebSocket already connected to different room ($_currentConnectionRoomId), reconnecting with new room_id: ${roomId ?? "none"}',
            name: _logName);
        await disconnect();
        // Continue to connect with new room_id below
      } else {
        log('✅ Already connected to WebSocket${roomId != null ? " (room: $roomId)" : " (no room_id)"}',
            name: _logName);
        // If roomId is UUID and matches or no roomId needed, just mark as joined if not already
        if (roomId != null &&
            roomId.isNotEmpty &&
            _isUuid(roomId) &&
            !_joinedRooms.contains(roomId)) {
          markRoomJoined(roomId);
        }
        return true;
      }
    }

    if (_isConnecting) {
      log('⏳ Connection already in progress, waiting...', name: _logName);
      // Wait for existing connection attempt
      int waitCount = 0;
      while (_isConnecting && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
        if (_isConnected) return true;
      }
      return _isConnected;
    }

    try {
      _isConnecting = true;
      _reconnectAttempts = 0; // Reset on manual connect

      // Get authentication token
      final token = await AuthTokenManager.getBestAvailableToken();
      if (token == null || token.isEmpty) {
        log('❌ No token available for WebSocket connection', name: _logName);
        _isConnecting = false;
        onError?.call('Authentication token not found');
        return false;
      }

      // Build WebSocket URL with optimized token to avoid URL length limits
      // Format: ws://13.201.27.102:7071/api/v1/ws?token={optimized_token}&room_id={room_id}

      // Use the full token - JWT tokens must remain intact for signature verification
      // WebSocket servers should accept the same tokens as REST APIs
      String tokenParam = Uri.encodeComponent(token);

      log('🔑 [WebSocket] Using full token (${token.length} chars) for authentication',
          name: _logName);

      String wsUrl = '$_wsBaseUrl?token=$tokenParam';

      // Add room_id to URL if provided (required for 1-to-1 chat and group chat)
      if (roomId != null && roomId.isNotEmpty) {
        final encodedRoomId = Uri.encodeComponent(roomId);
        wsUrl += '&room_id=$encodedRoomId';
        _currentConnectionRoomId =
            roomId; // Store the room_id used in connection
        log('  Room ID: $roomId (included in connection URL)', name: _logName);
        log('  WebSocket URL format: ws://13.201.27.102:7071/api/v1/ws?token={token}&room_id={room_id}',
            name: _logName);
        log('  Full URL: ws://13.201.27.102:7071/api/v1/ws?token=***&room_id=$roomId',
            name: _logName);
      } else {
        _currentConnectionRoomId = null; // No room_id in connection
        log('⚠️ Warning: No room_id provided in WebSocket connection URL',
            name: _logName);
        log('  For 1-to-1 chat and group chat, room_id should be provided (typically contact.id or group.id)',
            name: _logName);
        log('  URL without room_id: ws://13.201.27.102:7071/api/v1/ws?token=***',
            name: _logName);
      }

      // Log connection details (without full token for security)
      log('🔌 WebSocket Connection Details:', name: _logName);
      log('  Base URL: $_wsBaseUrl', name: _logName);
      log('  Server: 13.201.27.102:7071', name: _logName);
      log('  Endpoint: /api/v1/ws', name: _logName);
      log('  Token available: ✅ (${token.length} chars)', name: _logName);
      log('  Full URL length: ${wsUrl.length} characters', name: _logName);
      log('  Connection URL format: ws://13.201.27.102:7071/api/v1/ws?token={token}&room_id={room_id}',
          name: _logName);
      log('  Note: Token and room_id are passed in query parameters as per backend specification',
          name: _logName);

      // Log URL length for debugging
      if (wsUrl.length > 2000) {
        log('📏 [WebSocket] URL is long (${wsUrl.length} chars) but using full token for auth',
            name: _logName);
      }

      // Log the actual URL (with masked token for debugging)
      final maskedUrl = wsUrl.length > 100
          ? '${wsUrl.substring(0, 50)}...${wsUrl.substring(wsUrl.length - 20)}'
          : wsUrl.replaceAll(RegExp(r'token=[^&]+'), 'token=***');
      log('  Connection URL: $maskedUrl', name: _logName);

      // Parse and validate URI
      final uri = Uri.parse(wsUrl);
      if (!uri.scheme.startsWith('ws')) {
        throw Exception(
            'Invalid WebSocket URL scheme: ${uri.scheme}. Must be ws:// or wss://');
      }

      log('🌐 Connecting to: ${uri.host}:${uri.port}${uri.path}',
          name: _logName);

      // Create HttpClient with proper configuration
      final httpClient = HttpClient();
      httpClient.userAgent = 'Flutter-WebSocket-Client/1.0';
      httpClient.connectionTimeout = const Duration(seconds: 10);
      httpClient.idleTimeout = const Duration(seconds: 30);

      // Add Authorization header if server requires it (some servers accept both query param and header)
      // Note: Most WebSocket servers use query params, but we'll add header as fallback
      httpClient.autoUncompress = false;

      // Attempt WebSocket connection with timeout
      // WebSocket.connect() will use the HttpClient for the upgrade request
      // We can add custom headers by intercepting the upgrade request
      WebSocket? webSocket;
      try {
        // For WebSocket connections, we need to manually handle the upgrade
        // to add custom headers. However, WebSocket.connect() doesn't directly
        // support headers, so we rely on query parameter authentication.
        // If server requires Authorization header, we'd need to use a different approach.

        webSocket = await WebSocket.connect(
          wsUrl,
          customClient: httpClient,
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            httpClient.close(force: true);
            throw TimeoutException(
                'WebSocket connection timed out after 15 seconds');
          },
        );
      } catch (e) {
        httpClient.close(force: true);
        rethrow;
      }

      // Verify connection was established
      if (webSocket.readyState != WebSocket.open) {
        await webSocket.close();
        throw Exception(
            'WebSocket connection failed: readyState = ${webSocket.readyState}');
      }

      // Store references
      _webSocket = webSocket;
      _channel = IOWebSocketChannel(webSocket);

      // Set up message listener
      _subscription?.cancel(); // Cancel any existing subscription
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      // Wait for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 300));

      // Final verification
      if (_webSocket?.readyState != WebSocket.open || _channel == null) {
        await disconnect();
        throw Exception('WebSocket connection verification failed');
      }

      // Mark as connected
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;

      log('✅ WebSocket connected successfully', name: _logName);
      log('📊 Connection state: OPEN (readyState: ${_webSocket?.readyState})',
          name: _logName);

      _connectionStateController.add(true);
      onConnected?.call();

      return true;
    } catch (e) {
      log('❌ Failed to connect WebSocket: $e', name: _logName);
      log('Error type: ${e.runtimeType}', name: _logName);

      // Detailed error logging
      if (e is WebSocketException) {
        log('WebSocketException details:', name: _logName);
        log('  Message: ${e.message}', name: _logName);

        if (e.toString().contains('400')) {
          log('⚠️ HTTP 400 Bad Request - Possible causes:', name: _logName);
          log('  1. Invalid token format', name: _logName);
          log('  2. Server endpoint not configured for WebSocket',
              name: _logName);
          log('  3. Token expired or invalid', name: _logName);
        } else if (e.toString().contains('401')) {
          log('⚠️ HTTP 401 Unauthorized - Token authentication failed',
              name: _logName);
        } else if (e.toString().contains('403')) {
          log('⚠️ HTTP 403 Forbidden - Access denied', name: _logName);
        }
      } else if (e is SocketException) {
        log('⚠️ SocketException - Network connectivity issue', name: _logName);
        log('  OS Error: ${e.osError}', name: _logName);
      } else if (e is TimeoutException) {
        log('⚠️ Connection timeout - Server may be unreachable',
            name: _logName);
      }

      // Clean up failed connection
      _isConnecting = false;
      _isConnected = false;
      _connectionStateController.add(false);

      await _cleanupConnection();

      final errorMessage = 'Failed to connect to WebSocket: ${e.toString()}';
      onError?.call(errorMessage);

      // Only retry for network errors, not auth/config errors
      final shouldRetry = !errorMessage.toLowerCase().contains('auth') &&
          !errorMessage.toLowerCase().contains('401') &&
          !errorMessage.toLowerCase().contains('403') &&
          !errorMessage.toLowerCase().contains('400') &&
          !errorMessage.toLowerCase().contains('timeout');

      if (shouldRetry) {
        _scheduleReconnect();
      } else {
        log('⏸️ Not scheduling reconnection due to configuration/auth error',
            name: _logName);
      }

      return false;
    }
  }

  /// Clean up connection resources
  Future<void> _cleanupConnection() async {
    try {
      _subscription?.cancel();
      _subscription = null;

      await _channel?.sink.close();
      _channel = null;

      await _webSocket?.close();
      _webSocket = null;
    } catch (e) {
      log('Error during connection cleanup: $e', name: _logName);
    }
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    log('🔌 Disconnecting WebSocket', name: _logName);
    _reconnectTimer?.cancel();
    _isConnecting = false;
    _isConnected = false;
    _joinedRooms.clear();
    _currentConnectionRoomId = null; // Clear connection room_id

    await _cleanupConnection();

    _connectionStateController.add(false);
    onDisconnected?.call();
  }

  /// Join a room (REQUIRED before sending messages)
  ///
  /// {
  ///   "type": "join",
  ///   "room_id": "550e8400-e29b-41d4-a716-446655440000"
  /// }
  Future<bool> joinRoom(String roomId) async {
    if (roomId.isEmpty) {
      log('❌ Cannot join room: roomId is empty', name: _logName);
      return false;
    }

    // Ensure connection first
    if (!isConnected) {
      log('🚪 WebSocket not connected, attempting to connect...',
          name: _logName);
      final connected = await connect();
      if (!connected) {
        log('❌ Failed to connect before joining room', name: _logName);
        return false;
      }
      // Wait for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Verify connection is still valid
    if (!isConnected) {
      log('❌ Connection lost before joining room', name: _logName);
      return false;
    }

    // Check if already joined
    if (_joinedRooms.contains(roomId)) {
      log('✅ Already joined room: $roomId', name: _logName);
      return true;
    }

    try {
      final joinMessage = {
        'type': 'join',
        'room_id': roomId,
      };

      final joinMessageJson = jsonEncode(joinMessage);
      _channel!.sink.add(joinMessageJson);
      _joinedRooms.add(roomId);

      log('✅ Sent join request for room: $roomId', name: _logName);

      // Wait for join confirmation
      await Future.delayed(const Duration(milliseconds: 200));

      return true;
    } catch (e, stackTrace) {
      log('❌ Failed to join room: $e',
          name: _logName, error: e, stackTrace: stackTrace);

      // Remove from joined rooms if join failed
      _joinedRooms.remove(roomId);

      // If connection issue, mark as disconnected
      if (e.toString().contains('SocketException') ||
          e.toString().contains('WebSocket') ||
          e.toString().contains('connection') ||
          e.toString().contains('Broken pipe')) {
        log('🔌 Connection issue during join, marking as disconnected',
            name: _logName);
        _isConnected = false;
        _connectionStateController.add(false);
        await _cleanupConnection();
      }

      onError?.call('Failed to join room: $e');
      return false;
    }
  }

  /// Mark a room as joined (used when room_id is in connection URL)
  void markRoomJoined(String roomId) {
    if (roomId.isNotEmpty && !_joinedRooms.contains(roomId)) {
      _joinedRooms.add(roomId);
      log('✅ Room marked as joined (from connection URL): $roomId',
          name: _logName);
    }
  }

  /// Leave a room
  Future<bool> leaveRoom(String roomId) async {
    if (!_isConnected || _channel == null) {
      return false;
    }

    _joinedRooms.remove(roomId);
    log('Left room: $roomId', name: _logName);
    return true;
  }

  /// Send a message via WebSocket
  ///
  /// {
  ///   "type": "message",
  ///   "room_id": "550e8400-e29b-41d4-a716-446655440000",
  ///   "content": "Hello everyone!",
  ///   "message_type": "text"
  /// }
  /// Helper to check if a string is a valid UUID format
  bool _isUuid(String? str) {
    if (str == null || str.isEmpty) return false;
    final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    return uuidRegex.hasMatch(str);
  }

  Future<bool> sendMessage({
    required String roomId,
    required String content,
    String messageType = 'text',
    String? replyTo, // ID of the message this is replying to
  }) async {
    log('📤 [WebSocket] sendMessage called', name: _logName);
    log('   Room ID: $roomId', name: _logName);
    log('   Room ID is UUID: ${_isUuid(roomId)}', name: _logName);
    log('   Current connection room ID: $_currentConnectionRoomId',
        name: _logName);
    log('   Is connected: $_isConnected', name: _logName);
    log('   Channel exists: ${_channel != null}', name: _logName);
    log('   Room is joined: ${_joinedRooms.contains(roomId)}', name: _logName);

    // CRITICAL: For UUID room_id, ensure WebSocket is connected to the CORRECT room
    // Backend requires room_id in WebSocket URL to match the room_id in the message
    if (_isUuid(roomId)) {
      // Check if connected to wrong room
      final isConnectedToWrongRoom = _isConnected &&
          _currentConnectionRoomId != null &&
          _currentConnectionRoomId != roomId;

      if (isConnectedToWrongRoom) {
        log('⚠️ [WebSocket] Connected to wrong room ($_currentConnectionRoomId), reconnecting with correct room_id: $roomId',
            name: _logName);
        await disconnect();
        // Fall through to connect below
      }

      // If not connected or was disconnected above, connect with correct room_id
      if (!_isConnected || _channel == null) {
        log('🔌 [WebSocket] Connecting with UUID room_id: $roomId...',
            name: _logName);
        // Connect with room_id in the connection URL (required for message persistence)
        final connected = await connect(roomId: roomId);
        if (!connected) {
          log('❌ [WebSocket] Failed to connect WebSocket, cannot send message',
              name: _logName);
          return false;
        }
        // Mark room as joined since it's in the connection URL
        markRoomJoined(roomId);
        log('✅ [WebSocket] Connected and room marked as joined: $roomId',
            name: _logName);
        // Wait a brief moment for connection to stabilize
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        // Connected to correct room - verify room is joined
        if (!_joinedRooms.contains(roomId)) {
          log('⚠️ [WebSocket] Connected but room not marked as joined, marking now: $roomId',
              name: _logName);
          markRoomJoined(roomId);
        }
        log('✅ [WebSocket] Already connected to correct room: $roomId',
            name: _logName);
      }
    } else {
      // Numeric room_id - room should have been created first to get UUID
      // If we still have numeric ID, room creation might have failed
      log('❌ [WebSocket] Cannot send message: WebSocket requires UUID room_id in connection URL',
          name: _logName);
      log('   Numeric room_id: $roomId - room should have been created first',
          name: _logName);
      log('   Backend rejects WebSocket connection without room_id (HTTP 400)',
          name: _logName);
      log('   Please ensure room is created before sending messages',
          name: _logName);
      return false;
    }

    // Verify connection is still valid after reconnect attempt
    if (!_isConnected || _channel == null) {
      log('❌ [WebSocket] Connection failed after reconnect attempt',
          name: _logName);
      return false;
    }

    // CRITICAL: Verify we're connected to the correct room
    // The connection room_id MUST match the message room_id for messages to be delivered
    if (_currentConnectionRoomId != roomId) {
      log('❌ [WebSocket] CRITICAL ERROR: Connection room_id ($_currentConnectionRoomId) does not match message room_id ($roomId)',
          name: _logName);
      log('   This will cause message delivery failure - reconnecting...',
          name: _logName);
      await disconnect();
      final connected = await connect(roomId: roomId);
      if (!connected) {
        log('❌ [WebSocket] Failed to reconnect with correct room_id',
            name: _logName);
        return false;
      }
      markRoomJoined(roomId);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Verify room is marked as joined (should be true if connected with room_id in URL)
    if (!_joinedRooms.contains(roomId)) {
      log('⚠️ [WebSocket] Room not marked as joined, marking now: $roomId',
          name: _logName);
      markRoomJoined(roomId);
    }

    log('✅ [WebSocket] Ready to send message - connected to room: $roomId',
        name: _logName);

    // Retry logic: attempt to send up to 3 times
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        // Verify channel is still valid before each attempt
        if (_channel == null) {
          log('❌ Channel is null, attempting to reconnect...', name: _logName);
          // Reconnect - only if we have UUID (backend requires room_id in URL)
          if (_isUuid(roomId)) {
            final connected = await connect(roomId: roomId);
            if (!connected) {
              log('❌ Failed to reconnect, cannot send message', name: _logName);
              return false;
            }
            markRoomJoined(roomId);
            await Future.delayed(const Duration(milliseconds: 500));
          } else {
            log('❌ Cannot reconnect: Numeric room_id requires UUID for WebSocket connection',
                name: _logName);
            return false;
          }
        }

        // Verify connection state one more time
        if (!_isConnected || _channel == null) {
          log('❌ Connection lost before send attempt', name: _logName);
          if (retryCount < maxRetries - 1) {
            retryCount++;
            log('🔄 Retrying send (attempt $retryCount/$maxRetries)...',
                name: _logName);
            await Future.delayed(Duration(milliseconds: 500 * retryCount));
            continue;
          }
          return false;
        }

        // Build message according to backend specification
        // Format: {"type": "message", "room_id": "...", "content": "...", "message_type": "text", "reply_to_id": "..."}
        final message = {
          'type': 'message',
          'room_id': roomId,
          'content': content,
          'message_type': messageType,
          if (replyTo != null && replyTo.isNotEmpty) 'reply_to_id': replyTo,
        };

        final messageJson = jsonEncode(message);

        // CRITICAL: Verify connection room_id matches message room_id one more time
        if (_currentConnectionRoomId != roomId) {
          log('❌ [WebSocket] CRITICAL: Connection room_id mismatch detected just before sending!',
              name: _logName);
          log('   Connection room_id: $_currentConnectionRoomId',
              name: _logName);
          log('   Message room_id: $roomId', name: _logName);
          log('   This will cause message delivery failure', name: _logName);
          // Don't send - this will fail
          throw Exception('Connection room_id does not match message room_id');
        }

        // Log the exact message being sent (for debugging)
        log('📤 [WebSocket] Sending message:', name: _logName);
        log('   Room ID: $roomId', name: _logName);
        log('   Connection Room ID: $_currentConnectionRoomId', name: _logName);
        log('   Content: ${content.substring(0, content.length > 100 ? 100 : content.length)}${content.length > 100 ? "..." : ""}',
            name: _logName);
        log('   Message Type: $messageType', name: _logName);
        log('   Reply To ID: ${replyTo ?? "null"}', name: _logName);
        log('   JSON: $messageJson', name: _logName);
        log('   Connection URL includes room_id: ${_currentConnectionRoomId == roomId ? "Yes (matches)" : "No (MISMATCH!)"}',
            name: _logName);
        log('   Room is joined: ${_joinedRooms.contains(roomId)}',
            name: _logName);

        // Verify channel is still valid
        if (_channel == null) {
          throw Exception('Channel is null - cannot send message');
        }

        // Attempt to send the message
        _channel!.sink.add(messageJson);

        log('✅ [WebSocket] Message sent successfully to room: $roomId (attempt ${retryCount + 1})',
            name: _logName);
        log('   Message should be persisted by backend automatically',
            name: _logName);
        log('   Waiting for confirmation via WebSocket...', name: _logName);

        return true;
      } catch (e, stackTrace) {
        retryCount++;
        log('❌ Failed to send message (attempt $retryCount/$maxRetries): $e',
            name: _logName, error: e, stackTrace: stackTrace);

        // If sending failed due to connection issue, mark as disconnected
        final isConnectionError = e.toString().contains('SocketException') ||
            e.toString().contains('WebSocket') ||
            e.toString().contains('connection') ||
            e.toString().contains('Broken pipe') ||
            e.toString().contains('Connection closed');

        if (isConnectionError) {
          log('🔌 Connection issue detected, marking as disconnected',
              name: _logName);
          _isConnected = false;
          _connectionStateController.add(false);

          // Clean up broken connection
          try {
            _subscription?.cancel();
            _channel?.sink.close();
          } catch (_) {}
          _channel = null;
          _subscription = null;
          _joinedRooms.clear();
          _currentConnectionRoomId = null; // Clear connection room_id

          // If we have retries left, attempt to reconnect
          // Only reconnect if we have UUID (backend requires room_id in URL)
          if (retryCount < maxRetries) {
            log('🔄 Attempting to reconnect before retry...', name: _logName);
            if (_isUuid(roomId)) {
              final connected = await connect(roomId: roomId);
              if (connected) {
                markRoomJoined(roomId);
                await Future.delayed(const Duration(milliseconds: 500));
                continue; // Retry sending
              }
            } else {
              log('❌ Cannot reconnect: Numeric room_id requires UUID for WebSocket connection',
                  name: _logName);
            }
          }
        }

        // If this was the last retry, give up
        if (retryCount >= maxRetries) {
          onError
              ?.call('Failed to send message after $maxRetries attempts: $e');
          return false;
        }

        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }

    log('❌ All send attempts failed', name: _logName);
    return false;
  }

  /// Handle incoming WebSocket messages
  ///
  /// According to README, server sends messages in this format:
  /// {
  ///   "room_id": "...",
  ///   "user_id": "...",
  ///   "content": "...",
  ///   "message_type": "text",
  ///   "data": { ... }
  /// }
  ///
  /// Messages may or may not have a "type" field. If they have room_id, user_id, and content,
  /// they should be treated as chat messages.
  void _handleMessage(dynamic message) {
    try {
      final String messageStr;
      if (message is String) {
        messageStr = message;
      } else {
        messageStr = message.toString();
      }

      final json = jsonDecode(messageStr) as Map<String, dynamic>;

      // Log raw message for debugging
      log('📥 Raw WebSocket message received', name: _logName);
      log('   Keys: ${json.keys.toList()}', name: _logName);

      // Parse message according to README format
      final wsMessage = WebSocketMessage.fromJson(json);

      // Determine message type:
      // 1. If explicit "type" field exists, use it
      // 2. If "type" is missing but has room_id, user_id, content -> it's a message
      // 3. If "type" is "join" -> join confirmation
      // 4. If "type" is "error" -> error message

      WebSocketMessageType messageType = wsMessage.messageTypeEnum;

      // If no explicit type but has message fields, treat as message
      if (messageType == WebSocketMessageType.unknown &&
          wsMessage.roomId != null &&
          wsMessage.userId != null) {
        messageType = WebSocketMessageType.message;
        log('📨 Message detected (no explicit type field)', name: _logName);
      }

      final contentPreview =
          (wsMessage.content ?? wsMessage.data?['content']?.toString() ?? '')
              .toString();

      log('📬 Processing message type: $messageType', name: _logName);
      log('   Raw type: ${wsMessage.type}', name: _logName);
      log('   Message type: ${wsMessage.messageType}', name: _logName);
      log('   Room ID: ${wsMessage.roomId}', name: _logName);
      log('   User ID: ${wsMessage.userId}', name: _logName);
      if (contentPreview.isNotEmpty) {
        log('   Content: ${contentPreview.substring(0, contentPreview.length > 50 ? 50 : contentPreview.length)}...',
            name: _logName);
      } else {
        log('   Content: <empty>', name: _logName);
      }

      // Handle different message types
      switch (messageType) {
        case WebSocketMessageType.join:
          log('✅ Room join confirmed: ${wsMessage.roomId}', name: _logName);
          // Optionally broadcast join confirmation
          break;
        case WebSocketMessageType.message:
          // Broadcast message to listeners (matches README format)
          log('📤 Broadcasting message to listeners', name: _logName);
          _messageController.add(wsMessage);
          onMessage?.call(wsMessage);
          break;
        case WebSocketMessageType.unreadCountUpdate:
          // Broadcast unread count update to listeners
          log('📊 Broadcasting unread count update', name: _logName);
          log('   Room ID: ${wsMessage.roomId}', name: _logName);
          log('   User ID: ${wsMessage.userId}', name: _logName);
          log('   Data: ${wsMessage.data}', name: _logName);
          _messageController.add(wsMessage);
          onMessage?.call(wsMessage);
          break;
        case WebSocketMessageType.readReceipt:
          // Broadcast read receipt update to listeners
          log('📖 Broadcasting read receipt update', name: _logName);
          log('   Room ID: ${wsMessage.roomId}', name: _logName);
          log('   User ID: ${wsMessage.userId}', name: _logName);
          log('   Message ID: ${wsMessage.data?['message_id']}',
              name: _logName);
          log('   Data: ${wsMessage.data}', name: _logName);
          _messageController.add(wsMessage);
          onMessage?.call(wsMessage);
          break;
        case WebSocketMessageType.presenceUpdate:
          // Broadcast presence update to listeners
          log('👤 Broadcasting presence update', name: _logName);
          log('   User ID: ${wsMessage.userId}', name: _logName);
          log('   Online: ${wsMessage.data?['is_online']}', name: _logName);
          log('   Status: ${wsMessage.data?['status']}', name: _logName);
          log('   Data: ${wsMessage.data}', name: _logName);
          _messageController.add(wsMessage);
          onMessage?.call(wsMessage);
          break;
        case WebSocketMessageType.error:
          log('❌ WebSocket error: ${wsMessage.error}', name: _logName);
          log('   Room ID: ${wsMessage.roomId}', name: _logName);
          // Broadcast error message through message stream so listeners can handle with room_id context
          _messageController.add(wsMessage);
          onMessage?.call(wsMessage);
          // Also call onError callback for backward compatibility
          onError?.call(wsMessage.error ?? 'Unknown error');
          break;
        case WebSocketMessageType.unknown:
          // Treat any unknown-but-structured message as a chat event so UI can update badges
          if (wsMessage.roomId != null ||
              wsMessage.content != null ||
              wsMessage.data != null) {
            log('⚠️ Unknown message type, treating as message for UI',
                name: _logName);
            _messageController.add(wsMessage);
            onMessage?.call(wsMessage);
          } else {
            log('⚠️ Unknown message type with no recognizable fields: ${json.keys}',
                name: _logName);
          }
          break;
      }
    } catch (e, stackTrace) {
      log('❌ Error handling WebSocket message: $e',
          name: _logName, error: e, stackTrace: stackTrace);
      log('   Message was: ${message.toString().substring(0, message.toString().length > 200 ? 200 : message.toString().length)}',
          name: _logName);
      onError?.call('Error parsing message: $e');
    }
  }

  /// Handle WebSocket errors
  void _handleError(dynamic error) {
    log('WebSocket error: $error', name: _logName);
    _isConnected = false;
    _connectionStateController.add(false);

    // Clear joined rooms since connection is broken
    // They will need to be rejoined after reconnection
    // Rooms will be automatically rejoined when sendMessage is called
    _joinedRooms.clear();
    _currentConnectionRoomId = null; // Clear connection room_id

    onError?.call(error.toString());
    onDisconnected?.call();

    // Attempt reconnection
    // After reconnection, rooms will be rejoined when sendMessage is called
    _scheduleReconnect();
  }

  /// Handle WebSocket disconnect
  void _handleDisconnect() {
    log('WebSocket disconnected', name: _logName);
    _isConnected = false;
    _connectionStateController.add(false);

    // Clear joined rooms since connection is broken
    // They will need to be rejoined after reconnection
    // Rooms will be automatically rejoined when sendMessage is called
    _joinedRooms.clear();
    _currentConnectionRoomId = null; // Clear connection room_id

    onDisconnected?.call();

    // Attempt reconnection
    // After reconnection, rooms will be rejoined when sendMessage is called
    _scheduleReconnect();
  }

  /// Schedule reconnection with exponential backoff
  ///
  /// 1st retry → 1s
  /// 2nd retry → 3s
  /// 3rd retry → 5s
  /// Max retries → 5
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      log('Max reconnection attempts reached', name: _logName);
      return;
    }

    _reconnectAttempts++;

    // Calculate delay: 1s, 3s, 5s, 5s, 5s
    final delay = _reconnectAttempts == 1
        ? 1
        : _reconnectAttempts == 2
            ? 3
            : 5;

    log('Scheduling reconnection attempt $_reconnectAttempts in ${delay}s',
        name: _logName);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), () async {
      if (!_isConnected && !_isConnecting) {
        log('Attempting reconnection...', name: _logName);
        final connected = await connect();
        if (connected) {
          // Re-join all previously joined rooms
          for (final roomId in _joinedRooms.toList()) {
            await joinRoom(roomId);
          }
        }
      }
    });
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _connectionStateController.close();
  }
}
