import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform, Directory, File;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:just_audio/just_audio.dart' as audio;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/layout/app_scaffold.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/enhanced_toast.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/loading_dialog.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/keycloak_service.dart';
import 'models/intercom_contact.dart';
import 'models/message_reaction_model.dart';
import 'models/room_message_model.dart';
import 'models/room_model.dart';
import 'models/group_chat_model.dart';
import 'services/chat_service.dart';
import 'services/chat_websocket_service.dart';
import 'services/room_service.dart';
import 'services/unread_count_manager.dart';
import 'services/message_cache.dart';
import '../../../../core/models/api_response.dart';
import 'services/intercom_service.dart';
import '../../../core/utils/navigation_helper.dart';
import 'intercom_screen.dart';
import 'group_chat_screen.dart';
import 'video_player_screen.dart';
import 'widgets/whatsapp_video_message.dart';
import 'widgets/whatsapp_audio_message.dart';
import 'widgets/forward_to_sheet.dart';
import 'models/forward_payload.dart';

class ChatScreen extends StatefulWidget {
  final IntercomContact contact;
  final String? roomId; // Optional roomId to restore chat directly
  final bool returnToHistory; // If true, back button navigates to history page
  final List<String>? forwardMessageIds; // Message IDs to forward on open
  final List<ForwardPayload>? forwardPayloads; // Payload data to show instantly

  const ChatScreen({
    Key? key,
    required this.contact,
    this.roomId, // If provided, use this roomId directly to restore chat
    this.returnToHistory =
        false, // Default to false to maintain existing behavior
    this.forwardMessageIds,
    this.forwardPayloads,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late IntercomContact
      _contact; // Local copy of contact to support state updates (presence)
  static const double _emojiPickerHeight = 300.0;
  List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final audio.AudioPlayer _audioPlayer = audio.AudioPlayer();
  final ChatService _chatService = ChatService.instance;
  final IntercomService _intercomService = IntercomService();
  final ApiService _apiService = ApiService.instance;
  final RoomService _roomService = RoomService.instance;
  File? _recordingFile;
  bool _isRecording = false;
  bool _isPressingMic = false;
  bool _isPlayingAudio = false;
  String? _playingAudioId;
  Duration _recordingDuration = Duration.zero;
  DateTime? _recordingStartTime;
  bool _isTyping = false;
  bool _isBlocked = false;
  Color _chatWallpaper = Colors.grey.shade100;
  File? _chatWallpaperImage;
  ThemeMode _chatTheme = ThemeMode.light;
  double _fontSize = 14.0;
  bool _showEmojiPicker = false;
  Timer? _typingTimer;
  Timer? _typingIndicatorTimer; // Timer to hide typing indicator
  Timer? _recordingTimer;
  Timer? _messageSyncTimer; // Timer to periodically sync messages from database
  // Forward/selection state
  final Set<String> _selectedMessageIds = {};
  bool _isSelectionMode = false;
  bool _isForwarding = false;
  List<String>? _pendingForwardMessageIds;
  List<ForwardPayload>? _pendingForwardPayloads;
  final List<String> _forwardPlaceholderIds = [];
  bool _forwardPlaceholdersInserted = false;
  bool _forwardIntentHandled = false;
  bool _forwardIntentInFlight = false;
  ChatMessage? _replyingTo;
  late AnimationController _waveformController;
  List<double> _waveformData = [];
  // Upload progress tracking
  final Map<String, double> _uploadProgress = {};
  final Map<String, bool> _uploadingFiles = {};
  // CRITICAL FIX: Track read receipt requests to prevent duplicates and 429 errors
  final Set<String> _readReceiptInFlight = {};
  final Set<String> _readReceiptCompleted = {};
  // Download progress tracking
  final Set<String> _videoDownloadInProgress = {};
  final Map<String, double> _videoDownloadProgress = {};
  final RegExp _urlRegex = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );

  // WebSocket state
  StreamSubscription<WebSocketMessage>? _wsMessageSubscription;
  StreamSubscription<bool>? _wsConnectionSubscription;
  bool _isWebSocketConnected = false; // Track WebSocket connection status
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isLoaderDialogShown = false; // Track if global loader dialog is shown
  String? _currentUserId; // Current user UUID
  int? _currentUserNumericId; // Current user numeric ID
  bool _isAtBottom = true; // Track if user is at bottom for auto-scroll
  String? _currentRoomId; // Store the room_id for this 1-to-1 chat
  String?
      _memberName; // Store the member name (person you're chatting with) - not your own name
  String? _memberAvatar; // Store the member avatar URL from API
  // Avatar cache (like group chat) - maps user IDs to avatar URLs
  final Map<String, String?> _memberAvatarCache = {};
  // Numeric ID to UUID mapping (like group chat)
  final Map<int, String> _numericIdToUuidMap = {};
  // Pagination state (like group chat)
  bool _isLoadingMore = false; // For pagination
  bool _hasMoreMessages = true; // Track if more messages available
  int _currentOffset = 0;
  static const int _messagesPerPage = 50;
  // Prevent concurrent API calls
  bool _isOpeningRoom = false;
  DateTime? _lastApiCallTime;
  int _rateLimitRetryCount = 0;
  static const Duration _minApiCallInterval =
      Duration(seconds: 2); // Minimum 2 seconds between API calls

  // REQUEST DEDUPLICATION: Track in-flight room creation to prevent duplicates
  // Key: contactId, Value: Future<String?> (roomId)
  static final Map<String, Future<String?>> _inFlightRoomCreations = {};
  // Reaction fetching rate limiting
  DateTime? _lastReactionFetchTime;
  DateTime? _reactionFetchCooldownUntil; // Cooldown after 429 error
  Timer? _presenceTimer; // Timer to periodically fetch user presence

  final Set<String> _reactionsFetchInProgress = {}; // Track ongoing fetches
  static const Duration _reactionFetchMinInterval =
      Duration(milliseconds: 500); // Minimum 500ms between reaction fetches
  static const Duration _reactionFetchCooldown =
      Duration(seconds: 30); // 30s cooldown after 429

  // Reaction update rate limiting (PUT/POST)
  DateTime? _lastReactionUpdateTime;
  DateTime? _reactionUpdateCooldownUntil; // Cooldown after 429 error on update
  final Set<String> _reactionsUpdateInProgress = {}; // Track ongoing updates
  static const Duration _reactionUpdateMinInterval =
      Duration(milliseconds: 1000); // Minimum 1s between reaction updates
  static const Duration _reactionUpdateCooldown =
      Duration(seconds: 30); // 30s cooldown after 429

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
    // Start presence fetching
    _fetchContactPresence();
    _presenceTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchContactPresence();
    });

    _pendingForwardMessageIds = widget.forwardMessageIds;
    _pendingForwardPayloads = widget.forwardPayloads;
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();
    _generateWaveformData();
    _setupScrollListener();
    _loadCurrentUserId();
    _setupWebSocketListeners();
    _setupTypingIndicator();
    _setupMessageSync();
    // Load saved wallpaper from SharedPreferences
    _loadSavedWallpaper();

    // PERFORMANCE OPTIMIZATION: Show UI immediately, load data asynchronously (like GroupChatScreen)
    // Set loading to false after initial setup to render UI immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLoading = false; // Show chat UI immediately
        });
      }
    });

    // CRITICAL: Fetch RoomInfo FIRST to get member name and check membership before opening room
    // This matches group chat behavior and ensures we call GET RoomInfo API on entry
    // OPTIMIZATION: Called asynchronously - doesn't block UI rendering
    _fetchRoomInfoAndOpenRoom();

    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });
  }

  /// Fetch contact presence status
  Future<void> _fetchContactPresence() async {
    // Only fetch if we have a valid contact ID and it's not a temporary/local user
    if (widget.contact.id.isEmpty || !mounted) return;

    try {
      final response = await _chatService.getPresence([widget.contact.id]);

      if (response.success &&
          response.data != null &&
          response.data!.isNotEmpty &&
          mounted) {
        final presence = response.data!.first;
        final isOnline = presence['is_online'] == true;
        final statusStr =
            presence['status']?.toString().toLowerCase() ?? 'offline';
        final lastSeenStr = presence['last_seen'];

        IntercomContactStatus status;
        if (isOnline) {
          status = IntercomContactStatus.online;
        } else if (statusStr == 'away') {
          status = IntercomContactStatus.away;
        } else if (statusStr == 'busy') {
          status = IntercomContactStatus.busy;
        } else {
          status = IntercomContactStatus.offline;
        }

        DateTime? lastSeen;
        if (lastSeenStr != null) {
          try {
            lastSeen = DateTime.parse(lastSeenStr);
          } catch (e) {
            log('⚠️ [ChatScreen] Error parsing last seen: $e');
          }
        }

        // Only update if something changed
        if (_contact.status != status ||
            _contact.isOnline != isOnline ||
            _contact.lastSeenAt != lastSeen) {
          log('👤 [ChatScreen] Updating presence: $isOnline ($status) - Last seen: $lastSeen');
          setState(() {
            _contact = _contact.copyWith(
              status: status,
              isOnline: isOnline,
              lastSeenAt: lastSeen,
            );
          });
        }
      }
    } catch (e) {
      log('⚠️ [ChatScreen] Failed to fetch presence: $e');
    }
  }

  /// Setup scroll listener for auto-scroll tracking and pagination
  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Track if user is at bottom for auto-scroll
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        _isAtBottom = (maxScroll - currentScroll) < 100;
      }

      // Load older messages when user scrolls near the top (like group chat)
      if (_scrollController.hasClients &&
          _scrollController.position.pixels < 200 &&
          !_isLoadingMore &&
          _hasMoreMessages &&
          !_isLoading &&
          !_isOpeningRoom) {
        _loadOlderMessages();
      }

      // Mark visible messages as read when scrolling
      _markVisibleMessagesAsRead();
    });
  }

  /// Mark messages as read when they become visible to the user
  /// CRITICAL FIX: Added pre-check for already processed messages to reduce unnecessary delays
  void _markVisibleMessagesAsRead() {
    if (!mounted || _messages.isEmpty) return;

    // Only mark messages if we have a current room
    if (_currentRoomId == null) return;

    // Get unread messages from other users that haven't been processed yet
    final unreadMessagesFromOthers = _messages
        .where((message) => !message.isMe && 
            message.status != MessageStatus.seen &&
            // CRITICAL: Skip messages already in-flight or completed
            !_readReceiptInFlight.contains(message.id) &&
            !_readReceiptCompleted.contains(message.id))
        .toList();

    if (unreadMessagesFromOthers.isEmpty) return;

    // Mark the most recent unread message as read (simplified approach)
    // In a more sophisticated implementation, you'd check which messages are actually visible
    final messageToMark = unreadMessagesFromOthers.last; // Most recent unread message

    // Add a small delay to avoid marking messages the user just glanced at
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && _messages.contains(messageToMark)) {
        _markMessageAsRead(messageToMark.id);
      }
    });
  }

  /// Mark a specific message as read
  /// CRITICAL FIX: Added deduplication to prevent 429 rate limit errors
  Future<void> _markMessageAsRead(String messageId) async {
    // CRITICAL: Check if already in-flight or completed to prevent duplicate requests
    if (_readReceiptInFlight.contains(messageId) || 
        _readReceiptCompleted.contains(messageId)) {
      log('ℹ️ [ChatScreen] Skipping duplicate read receipt for: $messageId');
      return;
    }
    
    // Mark as in-flight to prevent concurrent requests for same message
    _readReceiptInFlight.add(messageId);
    
    try {
      final response = await _chatService.markMessageAsRead(messageId);
      if (response.success) {
        log('✅ [ChatScreen] Message marked as read: $messageId');
        // Mark as completed to prevent future requests
        _readReceiptCompleted.add(messageId);

        // Update local message status to show read receipt immediately
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == messageId);
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(
                status: MessageStatus.seen,
              );
            }
          });
        }
      } else {
        log('⚠️ [ChatScreen] Failed to mark message as read: ${response.error}');
        // Don't add to completed - allow retry later
      }
    } catch (e) {
      log('❌ [ChatScreen] Error marking message as read: $e');
      // Don't add to completed - allow retry later
    } finally {
      // Always remove from in-flight
      _readReceiptInFlight.remove(messageId);
    }
  }

  /// Load current user ID from auth service
  /// For chat, we need UUID (sub field from Keycloak) for room identification
  Future<void> _loadCurrentUserId() async {
    try {
      // Priority 1: Decode token directly to get UUID (sub field) - most reliable method
      // This ensures we always get the UUID from the token payload
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
                    _currentUserId = subStr; // UUID for chat
                  });
                  log('✅ [ChatScreen] Current user UUID loaded: $subStr (decoded from token)');
                }
              } else {
                log('⚠️ [ChatScreen] Sub field is not a valid UUID: $subStr');
              }
            } else {
              log('⚠️ [ChatScreen] No sub field found in decoded token');
            }
          } catch (e) {
            log('⚠️ [ChatScreen] Error decoding token: $e');
          }
        } else {
          log('⚠️ [ChatScreen] No access token available');
        }
      } catch (e) {
        log('⚠️ [ChatScreen] Error getting access token: $e');
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
                  log('✅ [ChatScreen] Current user UUID loaded from getUserInfo: $subStr');
                }
              }
            }
          }
        } catch (e) {
          log('⚠️ [ChatScreen] Error getting userInfo: $e');
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
                  log('✅ [ChatScreen] Current user UUID loaded from getUserData: $subStr');
                }
              }
            }
          }
        } catch (e) {
          log('⚠️ [ChatScreen] Error getting userData: $e');
        }
      }

      // Final fallback: If UUID still not found, try getUserId() (but this returns numeric ID)
      if (_currentUserId == null) {
        try {
          final userId = await _apiService.getUserId();
          if (mounted && userId != null) {
            setState(() {
              _currentUserId = userId.toString();
            });
            log('⚠️ [ChatScreen] Using fallback user ID (may be numeric): $userId');
            log('⚠️ [ChatScreen] WARNING: UUID not available, 1-to-1 chat may not work properly');
          }
        } catch (e) {
          log('⚠️ [ChatScreen] Error getting fallback user ID: $e');
        }
      }

      // Also load numeric user ID from Keycloak token/user data for message comparison
      try {
        final userData = await KeycloakService.getUserData();
        if (userData != null) {
          final candidates = [
            userData['user_id'],
            userData['old_gate_user_id'],
            userData['old_sso_user_id'],
            userData['gate_user_id'],
            userData['sso_user_id'],
          ];

          if (userData['chsone_session'] is Map) {
            final chsoneSession = userData['chsone_session'] as Map;
            candidates.add(chsoneSession['user_id']);
          }

          for (final candidate in candidates) {
            if (candidate != null) {
              final candidateStr = candidate.toString();
              // Skip UUIDs (they contain '-' and are longer)
              if (!candidateStr.contains('-')) {
                final parsed = int.tryParse(candidateStr);
                if (parsed != null && mounted) {
                  setState(() {
                    _currentUserNumericId = parsed;
                  });
                  log('✅ [ChatScreen] Current numeric user ID loaded: $parsed (from: $candidateStr)');
                  break;
                }
              }
            }
          }
        }
      } catch (e) {
        log('⚠️ [ChatScreen] Error loading numeric user ID: $e');
      }
    } catch (e) {
      log('❌ [ChatScreen] Error loading current user ID: $e');
    }
  }

  /// Helper to check if a string is a valid UUID format
  bool _isUuid(String? str) {
    if (str == null || str.isEmpty) return false;
    // UUID format: 8-4-4-4-12 hex digits with dashes
    final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    return uuidRegex.hasMatch(str);
  }

  /// Infer forwarded flag from a RoomMessage even if backend omitted explicit is_forwarded.
  bool _isForwardedRoomMessage(RoomMessage rm) {
    if (rm.isForwarded) return true;

    bool hasForwardMarkerMap(Map<dynamic, dynamic>? map) {
      if (map == null || map.isEmpty) return false;
      final keys = map.keys.map((k) => k.toString().toLowerCase()).toSet();
      const forwardKeys = {
        'is_forwarded',
        'forwarded',
        'forward',
        'forwarded_from',
        'forwardedfrom',
        'forwarded_message_id',
        'forwarded_room_id',
        'original_room_id',
        'original_message_id',
        'forward_message_id',
      };
      if (keys.any(forwardKeys.contains)) return true;
      for (final entry in map.entries) {
        final value = entry.value;
        if (value is Map && hasForwardMarkerMap(value)) return true;
      }
      return false;
    }

    // messageType hint
    final lowerType = rm.messageType?.toLowerCase() ?? '';
    if (lowerType.contains('forward')) return true;

    // eventType hint
    final lowerEvent = rm.eventType?.toLowerCase() ?? '';
    if (lowerEvent.contains('forward')) return true;

    // body JSON hint
    if (rm.body.trim().startsWith('{') && rm.body.trim().endsWith('}')) {
      try {
        final bodyJson = jsonDecode(rm.body);
        if (bodyJson is Map && hasForwardMarkerMap(bodyJson)) return true;
      } catch (_) {
        // ignore
      }
    }

    return false;
  }

  /// Helper to check if a string is numeric (not UUID)
  bool _isNumeric(String? str) {
    if (str == null || str.isEmpty) return false;
    return int.tryParse(str) != null && !str.contains('-');
  }

  /// Setup WebSocket listeners for real-time messages
  void _setupWebSocketListeners() {
    // Listen to incoming messages
    _wsMessageSubscription = _chatService.messageStream.listen(
      (wsMessage) {
        _handleWebSocketMessage(wsMessage);
      },
      onError: (error) {
        log('WebSocket message stream error: $error');
      },
    );

    // Listen to connection state changes
    _wsConnectionSubscription = _chatService.connectionStateStream.listen(
      (isConnected) {
        if (mounted) {
          final wasConnected = _isWebSocketConnected;
          setState(() {
            _isWebSocketConnected = isConnected;
          });

          // Show user-friendly messages for connection changes
          if (isConnected && !wasConnected) {
            log('✅ WebSocket connected - Real-time messaging active');
            if (mounted) {
              EnhancedToast.success(
                context,
                title: 'Connected',
                message: 'Real-time messaging is now active',
              );
            }
          } else if (!isConnected && wasConnected) {
            log('⚠️ WebSocket disconnected - Real-time messaging unavailable');
          }
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

  /// Setup typing indicator listener
  void _setupTypingIndicator() {
    // Listen for typing events from WebSocket (when backend supports it)
    // Note: We do NOT show typing indicator when current user types
    // Only show when OTHER user is typing (received via WebSocket)
    // _messageController.addListener(_onTextChanged); // REMOVED - don't show when current user types
  }

  /// Handle typing events from OTHER user (via WebSocket)
  /// This will be called when backend sends typing events
  void _handleOtherUserTyping(String userId, bool isTyping) {
    // Only show typing indicator if:
    // 1. Chat screen is open (mounted)
    // 2. It's for the current room
    // 3. It's NOT the current user typing
    if (!mounted || _currentRoomId == null) return;

    if (userId == _currentUserId) {
      // Current user is typing - don't show indicator
      return;
    }

    // Other user is typing - show indicator
    if (mounted) {
      setState(() {
        _isTyping = isTyping;
      });
    }

    // Auto-hide typing indicator after 3 seconds if no update
    _typingIndicatorTimer?.cancel();
    if (isTyping) {
      _typingIndicatorTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isTyping = false;
          });
        }
      });
    }
  }

  /// Periodically sync messages from database to ensure we have latest
  void _setupMessageSync() {
    // Sync messages every 60 seconds (increased from 30s to reduce API calls)
    // Only sync if WebSocket is not connected or if we haven't received messages recently
    _messageSyncTimer =
        Timer.periodic(const Duration(seconds: 60), (timer) async {
      if (!mounted || _isLoading || _isOpeningRoom) return;

      // Skip sync if WebSocket is connected (real-time updates are working)
      if (_isWebSocketConnected) {
        log('⏭️ [ChatScreen] Skipping message sync - WebSocket is connected');
        return;
      }

      // Rate limiting: Check if enough time has passed since last API call
      if (_lastApiCallTime != null) {
        final timeSinceLastCall = DateTime.now().difference(_lastApiCallTime!);
        if (timeSinceLastCall < _minApiCallInterval) {
          log('⏭️ [ChatScreen] Skipping message sync - rate limit active');
          return;
        }
      }

      try {
        // Get company_id for API call
        final companyId = await _apiService.getSelectedSocietyId();
        if (companyId == null) return;

        // Use cached room_id if available, otherwise use contact.id
        final roomId = _currentRoomId ?? widget.contact.id;

        // Fetch latest messages (just the most recent ones)
        final response = await _chatService.fetchMessages(
          roomId: roomId,
          companyId: companyId,
          limit: 5, // Reduced from 10 to 5 to minimize API payload
          offset: 0,
        );

        if (response.success && response.data != null && mounted) {
          final latestMessages = response.data!;
          if (latestMessages.isNotEmpty) {
            // Check if we have any new messages
            final latestMessageId = latestMessages.first.id;
            final hasNewMessage =
                !_messages.any((m) => m.id == latestMessageId);

            if (hasNewMessage) {
              // We have new messages, refresh the full list
              log('🔄 New messages detected, refreshing chat history...');
              // Use a small delay to avoid immediate API call after sync
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted && !_isOpeningRoom) {
                await _openRoom(isRefresh: true);
              }
            }
          }
        } else if (response.statusCode == 429) {
          // Rate limit error - stop syncing for a while
          log('⚠️ [ChatScreen] Rate limit in message sync, pausing sync timer');
          _messageSyncTimer?.cancel();
          // Restart sync after 2 minutes
          Future.delayed(const Duration(minutes: 2), () {
            if (mounted) {
              _setupMessageSync();
            }
          });
        }
      } catch (e) {
        log('Error syncing messages: $e');
        // Silent fail - don't disrupt user experience
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final window = WidgetsBinding.instance.window;
    final bottomInset = window.viewInsets.bottom / window.devicePixelRatio;
    if (bottomInset > 0 && _messageFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  /// Fetch RoomInfo FIRST to get member name and check membership, then open room
  /// This matches group chat behavior and ensures we call GET RoomInfo API on entry
  /// For 1-to-1 chats (exactly 2 members):
  /// - Identifies which member is the current user
  /// - Uses the other member's name as the room name
  /// - Prefers user_snapshot.user_name, falls back to users.username
  ///
  /// PERFORMANCE OPTIMIZATION: Non-blocking - opens room immediately, RoomInfo loads in background
  /// This matches GroupChatScreen behavior for instant UI rendering
  Future<void> _fetchRoomInfoAndOpenRoom() async {
    try {
      final companyId = await _apiService.getSelectedSocietyId();
      if (companyId == null) {
        // If companyId not available, still try to open room (will fail gracefully)
        _openRoom();
        return;
      }

      // PERFORMANCE: Don't wait for current user ID - it will load in background
      // API calls can proceed without waiting, improving instant response
      // If _currentUserId is null, it will be available later from token decoding
      if (_currentUserId == null) {
        log('ℹ️ [ChatScreen] Current user ID not yet loaded, proceeding anyway (will load in background)');
        // Continue - don't block API calls
      }

      // We need a room ID to fetch RoomInfo
      // If we have widget.roomId, use it; otherwise we'll fetch RoomInfo after room is determined
      String? roomIdToFetch;

      if (widget.roomId != null && _isUuid(widget.roomId!)) {
        roomIdToFetch = widget.roomId;
        _currentRoomId = widget.roomId;
        log('✅ [ChatScreen] Using provided roomId from chat history for RoomInfo: $roomIdToFetch');
      } else if (_currentRoomId != null && _isUuid(_currentRoomId)) {
        roomIdToFetch = _currentRoomId;
        log('✅ [ChatScreen] Using cached roomId for RoomInfo: $roomIdToFetch');
      } else if (_isUuid(widget.contact.id)) {
        // Check if contact.id is a valid room ID
        roomIdToFetch = widget.contact.id;
        log('✅ [ChatScreen] Using contact.id as roomId for RoomInfo: $roomIdToFetch');
      }

      // PERFORMANCE OPTIMIZATION: Start RoomInfo call with timeout, completely non-blocking (like GroupChatScreen)
      // Open room immediately without waiting for RoomInfo - it will load in background
      if (roomIdToFetch != null) {
        log('🔄 [ChatScreen] Fetching RoomInfo (background, 2s timeout): $roomIdToFetch');

        // Start RoomInfo call with short timeout, completely non-blocking
        RoomService.instance
            .getRoomInfo(
          roomId: roomIdToFetch,
          companyId: companyId,
        )
            .timeout(
          const Duration(seconds: 2), // Very short timeout - fail fast
          onTimeout: () {
            log('⏱️ [ChatScreen] RoomInfo timeout after 2s - continuing without it');
            return ApiResponse.error('Request timeout', statusCode: 408);
          },
        ).then((roomInfoResponse) {
          // Process RoomInfo response in background (non-blocking)
          if (roomInfoResponse.success &&
              roomInfoResponse.data != null &&
              mounted) {
            final roomInfo = roomInfoResponse.data!;

            // For 1-to-1 chats: use backend peer_user when available (source of truth), else derive from members.
            if (roomInfo.memberCount == 2 && roomInfo.members.length == 2) {
              log('✅ [ChatScreen] RoomInfo shows 1-to-1 chat with 2 members');

              if (roomInfo.peerUser != null) {
                // Backend returns peer_user for 1-to-1; use it for title and avatar
                _memberName =
                    roomInfo.peerUser!.userName?.trim().isNotEmpty == true
                        ? roomInfo.peerUser!.userName!
                        : widget.contact.name;
                _memberAvatar =
                    roomInfo.peerUser!.avatar?.trim().isNotEmpty == true
                        ? roomInfo.peerUser!.avatar
                        : null;
                log('✅ [ChatScreen] Using peer_user from API: $_memberName');
                if (_memberAvatar != null && _memberAvatar!.isNotEmpty) {
                  if (roomInfo.peerUser!.userId != null) {
                    _memberAvatarCache[roomInfo.peerUser!.userId.toString()] =
                        _memberAvatar;
                  }
                }
                for (final member in roomInfo.members) {
                  if (member.avatar != null &&
                      member.avatar!.isNotEmpty &&
                      member.userId.isNotEmpty) {
                    _memberAvatarCache[member.userId] = member.avatar;
                    if (member.numericUserId != null) {
                      _memberAvatarCache[member.numericUserId.toString()] =
                          member.avatar;
                      _numericIdToUuidMap[member.numericUserId!] =
                          member.userId;
                    }
                  }
                }
                if (mounted) setState(() {});
              } else if (_currentUserId != null) {
                try {
                  final otherMember = roomInfo.members.firstWhere(
                    (m) => !m.isCurrentUser(_currentUserId),
                    orElse: () => roomInfo.members.first,
                  );
                  _memberName = otherMember.username ?? widget.contact.name;
                  _memberAvatar = otherMember.avatar;
                  log('✅ [ChatScreen] Found other member name: $_memberName (async)');
                  if (_memberAvatar != null && _memberAvatar!.isNotEmpty) {
                    if (otherMember.userId.isNotEmpty) {
                      _memberAvatarCache[otherMember.userId] = _memberAvatar;
                    }
                    if (otherMember.numericUserId != null) {
                      _memberAvatarCache[otherMember.numericUserId.toString()] =
                          _memberAvatar;
                      _numericIdToUuidMap[otherMember.numericUserId!] =
                          otherMember.userId;
                    }
                  }
                  for (final member in roomInfo.members) {
                    if (member.avatar != null &&
                        member.avatar!.isNotEmpty &&
                        member.userId.isNotEmpty) {
                      _memberAvatarCache[member.userId] = member.avatar;
                      if (member.numericUserId != null) {
                        _memberAvatarCache[member.numericUserId.toString()] =
                            member.avatar;
                        _numericIdToUuidMap[member.numericUserId!] =
                            member.userId;
                      }
                    }
                  }
                  if (mounted) setState(() {});
                } catch (e) {
                  log('⚠️ [ChatScreen] Error finding other member: $e');
                }
              }
            }
          }
        }).catchError((e) {
          log('⚠️ [ChatScreen] RoomInfo error (non-blocking): $e');
          // Continue - will use contact name as fallback
        });

        // PERFORMANCE OPTIMIZATION: Open room immediately without waiting for RoomInfo
        // This matches GroupChatScreen behavior - screen shows immediately, data loads in background
        log('🚀 [ChatScreen] Opening room immediately (RoomInfo in background, messages loading async)');
        _openRoom();
      } else {
        // No room ID yet - will determine during _openRoom()
        log('⚠️ [ChatScreen] No room ID available yet for RoomInfo, will fetch after room is determined');
        _memberName = widget.contact.name;
        _memberAvatar = null;

        // Open room immediately - will determine room ID and fetch RoomInfo if needed
        log('🚀 [ChatScreen] Opening room immediately (will determine room ID)');
        _openRoom();
      }
    } catch (e) {
      log('⚠️ [ChatScreen] Error fetching RoomInfo: $e');
      // Still try to open room - will determine room ID and fetch member name during openRoom
      _openRoom();
    }
  }

  /// Open room for real-time chat (REST + WebSocket)
  ///
  /// Flow for 1-to-1 chat:
  /// 1. List all rooms to find the room for this contact
  /// 2. Join the room via REST API
  /// 3. Fetch message history (REST)
  /// 4. Connect WebSocket if not connected
  /// 5. Join room via WebSocket
  ///
  /// CRITICAL FIX: Added request guard and debounce to prevent API storm during rapid tab switching
  /// This ensures chat opens reliably even when background tabs are making API calls
  /// PERFORMANCE: Removed debounce delay for initial load - API calls instantly when screen opens
  Future<void> _openRoom({bool isRefresh = false}) async {
    // REQUEST GUARD: Prevent concurrent calls
    if (_isOpeningRoom) {
      log('⏸️ [ChatScreen] _openRoom already in progress, skipping...');
      return;
    }

    // PERFORMANCE OPTIMIZATION: Only debounce on refresh, not on initial load
    // This ensures messages API is called instantly when chat screen opens
    if (isRefresh) {
      // REQUEST GUARD: Add debounce before firing chat APIs for refresh only (300-500ms)
      // This prevents API storm when chat icon is tapped immediately after tab switching
      const debounceDelay = Duration(milliseconds: 400);
      await Future.delayed(debounceDelay);

      // Double-check after debounce - might have been cancelled or already opened
      if (_isOpeningRoom || !mounted) {
        log('⏸️ [ChatScreen] _openRoom cancelled during debounce or widget not mounted');
        return;
      }
    } else {
      // Initial load - no debounce, call API instantly
      log('⚡ [ChatScreen] Initial load - calling messages API instantly (no debounce)');
    }

    // Rate limiting: Check if enough time has passed since last API call
    if (_lastApiCallTime != null) {
      final timeSinceLastCall = DateTime.now().difference(_lastApiCallTime!);
      if (timeSinceLastCall < _minApiCallInterval) {
        log('⏸️ [ChatScreen] Rate limiting: ${_minApiCallInterval.inSeconds - timeSinceLastCall.inSeconds}s remaining before next API call');
        // Wait for the remaining time
        await Future.delayed(_minApiCallInterval - timeSinceLastCall);
      }
    }

    _isOpeningRoom = true;
    _lastApiCallTime = DateTime.now();

    // CRITICAL: Preserve existing messages when reopening (like group chat)
    // This ensures messages are not lost when reopening the same chat
    // For refresh: preserve all existing messages
    // For reopen: preserve messages if they exist (e.g., when reopening with same roomId)
    final existingMessages = List<ChatMessage>.from(_messages);
    log('📋 [ChatScreen] Preserving ${existingMessages.length} existing messages (isRefresh: $isRefresh)');

    // PERFORMANCE OPTIMIZATION: Don't show loader dialog on first load (like GroupChatScreen)
    // UI is already visible from initState, messages load in background
    // Only clear errors on first load, don't block UI
    if (!isRefresh) {
      // Don't show loading state - UI is already visible
      // Just clear any previous errors
      setState(() {
        _hasError = false;
        _errorMessage = null;
        // CRITICAL: Don't clear _messages here - preserve them until new ones are loaded
        // This ensures messages are visible while loading new ones
        // CRITICAL: Don't set _isLoading = true - UI should remain visible
      });
      // REMOVED: showEmergencyLoadingDialog - blocks UI like group chat used to do
      // GroupChatScreen doesn't show loader - it renders immediately, loads data in background
    }

    try {
      // Get company_id for API call
      final companyId = await _apiService.getSelectedSocietyId();

      // Validate companyId is available
      if (companyId == null) {
        log('❌ [ChatScreen] Company ID not available, cannot proceed');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Please select a society first';
          });
          _hideLoaderDialog();
        }
        return;
      }

      // Step 1: Determine room_id - match group chat flow exactly
      // Group chat: Uses widget.group.id (UUID) directly
      // 1-to-1 chat: Priority: 1) widget.roomId (from chat history), 2) _currentRoomId (cached), 3) contact.id if UUID, 4) find existing room, 5) create new
      String? roomId;
      bool roomExists = false;

      // CRITICAL: If roomId was provided from chat history, use it directly to restore chat
      // This matches group chat behavior where widget.group.id is always available
      if (widget.roomId != null && _isUuid(widget.roomId!)) {
        log('✅ [ChatScreen] Using provided roomId from chat history: ${widget.roomId}');
        log('   This will restore chat by calling messages API: GET /api/v1/rooms/${widget.roomId}/messages');
        log('   Preserving ${existingMessages.length} existing messages during load');
        roomId = widget.roomId;
        _currentRoomId = widget.roomId;
        roomExists = true; // Assume room exists if provided from history

        // Register room-to-contact mapping and clear unread count
        await UnreadCountManager.instance
            .mapRoomToContact(widget.roomId!, widget.contact.id);
        await UnreadCountManager.instance.clearUnreadCount(widget.roomId!);
      }
      // Otherwise, try cached room_id or find/create it
      else {
        roomId = _currentRoomId;

        if (roomId == null) {
          log('🔍 [ChatScreen] Determining room_id for contact: ${widget.contact.id}');
          log('   Contact ID type: ${_isNumeric(widget.contact.id) ? "numeric" : _isUuid(widget.contact.id) ? "UUID" : "unknown"}');

          // If contact.id is UUID, first check if it exists as a room
          // If not, search for existing 1-to-1 room with this contact
          if (_isUuid(widget.contact.id)) {
            log('✅ [ChatScreen] Contact ID is UUID - checking if room exists');

            // CRITICAL FIX: Use cached rooms (via RoomsCache) - prevents duplicate API calls
            // Cache will return in-flight request if Chat History tab already called /rooms
            // This eliminates the API burst that causes 429 errors
            final roomsResponse = await _chatService.fetchRooms(
                companyId: companyId, chatType: '1-1');

            // CRITICAL: Handle 429 gracefully - don't proceed with room creation if fetch failed
            if (!roomsResponse.success) {
              if (roomsResponse.statusCode == 429) {
                log('⚠️ [ChatScreen] 429 error when fetching rooms - not attempting room creation');
                log('   Will wait for cache to populate from Chat History tab');
                // Don't create room if /rooms call failed with 429
                // Wait and retry later, or use cached data if available
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                    _errorMessage =
                        'Too many requests. Please wait a moment and try again.';
                  });
                }
                _isOpeningRoom = false;
                return;
              }
              log('⚠️ [ChatScreen] Failed to fetch rooms: ${roomsResponse.error}');
              // Continue - will try to create room if needed (but not on 429)
            }

            if (roomsResponse.success && roomsResponse.data != null) {
              roomExists = roomsResponse.data!
                  .any((room) => room.id == widget.contact.id);
              if (roomExists) {
                log('   Room exists with contact ID as room ID: ${widget.contact.id}');
                roomId = widget.contact.id;
              } else {
                log('   Room does not exist with contact ID - searching for existing 1-to-1 room');
                // Search for existing 1-to-1 room with this contact (similar to numeric IDs)
                final currentUserUuid = _currentUserId;
                if (currentUserUuid != null && _isUuid(currentUserUuid)) {
                  final rooms = roomsResponse.data!;
                  log('   Searching through ${rooms.length} rooms for 1-to-1 room...');

                  Room? foundRoom;
                  int checked = 0;
                  final maxCheck = rooms.length > 10 ? 10 : rooms.length;

                  for (final room in rooms) {
                    if (!_isUuid(room.id) || checked >= maxCheck) {
                      if (checked >= maxCheck) {
                        log('   Reached max check limit ($maxCheck), stopping search');
                      }
                      break;
                    }
                    checked++;

                    // Add small delay between API calls to prevent rate limiting
                    if (checked > 1) {
                      await Future.delayed(const Duration(milliseconds: 200));
                    }

                    try {
                      final roomInfo = await RoomService.instance.getRoomInfo(
                        roomId: room.id,
                        companyId: companyId,
                      );

                      if (roomInfo.success && roomInfo.data != null) {
                        final roomData = roomInfo.data!;
                        // Check if it's a 1-to-1 room (2 members) and includes current user
                        // Also check if the other member matches the contact UUID
                        if (roomData.memberCount == 2 &&
                            roomData.members.length == 2 &&
                            roomData.members
                                .any((m) => m.userId == currentUserUuid)) {
                          // Check if the other member matches the contact UUID
                          final otherMember = roomData.members.firstWhere(
                            (m) => m.userId != currentUserUuid,
                            orElse: () => roomData.members.first,
                          );
                          if (otherMember.userId == widget.contact.id) {
                            foundRoom = room;
                            log('   Found existing 1-to-1 room with contact UUID: ${room.id}');
                            break;
                          }
                        }
                      }
                    } catch (e) {
                      // If rate limit error, stop searching
                      if (e.toString().contains('429') ||
                          e.toString().contains('rate limit')) {
                        log('⚠️ [ChatScreen] Rate limit error during room search, stopping');
                        break;
                      }
                      // Continue searching other rooms for other errors
                      continue;
                    }
                  }

                  if (foundRoom != null) {
                    roomId = foundRoom.id;
                    roomExists = true;
                    log('✅ [ChatScreen] Found existing 1-to-1 room: $roomId');
                  } else {
                    log('⚠️ [ChatScreen] No existing 1-to-1 room found after checking $checked rooms');
                    roomId = null; // Will trigger room creation below
                  }
                } else {
                  log('⚠️ [ChatScreen] Current user UUID not available, cannot search for 1-to-1 room');
                  roomId = null; // Will trigger room creation below
                }
              }
            } else {
              log('⚠️ [ChatScreen] Failed to fetch rooms list, will try to create room');
              roomId = null; // Will trigger room creation below
            }
          } else if (_isNumeric(widget.contact.id)) {
            // For numeric contact IDs, try to find existing 1-to-1 room
            log('⚠️ [ChatScreen] Contact ID is numeric - searching for existing 1-to-1 room');

            final currentUserUuid = _currentUserId;
            if (currentUserUuid == null || !_isUuid(currentUserUuid)) {
              log('❌ [ChatScreen] Current user UUID not available, cannot find 1-to-1 room');
              roomId = null;
            } else {
              // CRITICAL FIX: Reuse cached rooms (via RoomsCache) - prevents duplicate API calls
              // Use 1-1 filter to get only 1-to-1 rooms (faster, less data)
              final roomsResponse = await _chatService.fetchRooms(
                  companyId: companyId, chatType: '1-1');

              // CRITICAL: Handle 429 gracefully - don't create room if fetch failed with 429
              if (!roomsResponse.success) {
                if (roomsResponse.statusCode == 429) {
                  log('⚠️ [ChatScreen] 429 error when fetching rooms (numeric ID) - not attempting room creation');
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _hasError = true;
                      _errorMessage =
                          'Too many requests. Please wait a moment and try again.';
                    });
                  }
                  _isOpeningRoom = false;
                  return;
                }
                log('⚠️ [ChatScreen] Failed to fetch rooms: ${roomsResponse.error}');
              }

              if (roomsResponse.success && roomsResponse.data != null) {
                final rooms = roomsResponse.data!;

                log('   Searching through ${rooms.length} rooms for 1-to-1 room...');

                // Find 1-to-1 room (2 members, includes current user)
                // OPTIMIZATION: Reduce API calls by limiting search and adding delays
                Room? foundRoom;
                int checked = 0;
                // Reduced from 20 to 10 to minimize API calls
                final maxCheck = rooms.length > 10 ? 10 : rooms.length;

                for (final room in rooms) {
                  if (!_isUuid(room.id) || checked >= maxCheck) {
                    if (checked >= maxCheck) {
                      log('   Reached max check limit ($maxCheck), stopping search');
                    }
                    break;
                  }
                  checked++;

                  // Add small delay between API calls to prevent rate limiting
                  if (checked > 1) {
                    await Future.delayed(const Duration(milliseconds: 200));
                  }

                  try {
                    final roomInfo = await RoomService.instance.getRoomInfo(
                      roomId: room.id,
                      companyId: companyId,
                    );

                    if (roomInfo.success && roomInfo.data != null) {
                      final roomData = roomInfo.data!;

                      // CRITICAL: Build numeric ID to UUID mapping from RoomInfo members
                      // This helps match contacts with numeric IDs to members with UUIDs
                      for (final member in roomData.members) {
                        if (member.numericUserId != null) {
                          _numericIdToUuidMap[member.numericUserId!] =
                              member.userId;
                          log('   📝 Mapped numeric ID ${member.numericUserId} to UUID ${member.userId}');
                        }
                      }

                      // Check if it's a 1-to-1 room (2 members) and includes current user
                      if (roomData.memberCount == 2 &&
                          roomData.members.length == 2 &&
                          roomData.members
                              .any((m) => m.userId == currentUserUuid)) {
                        // CRITICAL: Verify the other member matches the contact ID
                        // Find the other member (not the current user)
                        final otherMember = roomData.members.firstWhere(
                          (m) => m.userId != currentUserUuid,
                          orElse: () => roomData.members.first,
                        );

                        // CRITICAL: Match contact ID with member using both numeric ID and UUID
                        // Contact ID can be either numeric (361) or UUID (3f508d6f-...)
                        // Member has both numericUserId and userId (UUID)
                        bool memberMatches = false;

                        // Check if contact ID is numeric - match with numericUserId
                        final contactIdNumeric =
                            int.tryParse(widget.contact.id);
                        if (contactIdNumeric != null &&
                            otherMember.numericUserId != null) {
                          memberMatches =
                              otherMember.numericUserId == contactIdNumeric;
                          if (memberMatches) {
                            log('   ✅ Found matching 1-to-1 room (numeric match): ${room.id}');
                            log('      Other member numericUserId: ${otherMember.numericUserId} matches contact ID: ${widget.contact.id}');
                          }
                        }

                        // Check if contact ID is UUID - match with userId
                        if (!memberMatches && _isUuid(widget.contact.id)) {
                          memberMatches =
                              otherMember.userId == widget.contact.id;
                          if (memberMatches) {
                            log('   ✅ Found matching 1-to-1 room (UUID match): ${room.id}');
                            log('      Other member userId: ${otherMember.userId} matches contact ID: ${widget.contact.id}');
                          }
                        }

                        // Also check if we have a mapping (contact numeric -> member UUID or vice versa)
                        if (!memberMatches) {
                          // If contact is numeric and member has UUID, check if we can map it
                          if (contactIdNumeric != null &&
                              _isUuid(otherMember.userId)) {
                            // Check if this numeric ID maps to the member's UUID
                            // This handles cases where contact has numeric ID but member is stored with UUID
                            final mappedUuid =
                                _numericIdToUuidMap[contactIdNumeric];
                            if (mappedUuid != null &&
                                mappedUuid == otherMember.userId) {
                              memberMatches = true;
                              log('   ✅ Found matching 1-to-1 room (mapped numeric->UUID): ${room.id}');
                              log('      Contact numeric ID: ${widget.contact.id} maps to member UUID: ${otherMember.userId}');
                            }
                          }

                          // If contact is UUID and member has numeric ID, check reverse mapping
                          if (!memberMatches &&
                              _isUuid(widget.contact.id) &&
                              otherMember.numericUserId != null) {
                            // Check if member's numeric ID maps to contact UUID
                            final memberMappedUuid =
                                _numericIdToUuidMap[otherMember.numericUserId!];
                            if (memberMappedUuid != null &&
                                memberMappedUuid == widget.contact.id) {
                              memberMatches = true;
                              log('   ✅ Found matching 1-to-1 room (mapped UUID->numeric): ${room.id}');
                              log('      Member numeric ID: ${otherMember.numericUserId} maps to contact UUID: ${widget.contact.id}');
                            }
                          }
                        }

                        if (memberMatches) {
                          foundRoom = room;
                          break;
                        } else {
                          log('   ⚠️ Found 1-to-1 room but member mismatch: ${room.id}');
                          log('      Other member: numericUserId=${otherMember.numericUserId}, userId=${otherMember.userId}');
                          log('      Contact ID: ${widget.contact.id} (type: ${_isUuid(widget.contact.id) ? "UUID" : "numeric"})');
                          // Continue searching for the correct room
                        }
                      }
                    }
                  } catch (e) {
                    // If rate limit error, stop searching
                    if (e.toString().contains('429') ||
                        e.toString().contains('rate limit')) {
                      log('⚠️ [ChatScreen] Rate limit error during room search, stopping');
                      break;
                    }
                    // Continue searching other rooms for other errors
                    continue;
                  }
                }

                if (foundRoom != null) {
                  roomId = foundRoom.id;
                  roomExists = true;
                  log('✅ [ChatScreen] Found existing 1-to-1 room: $roomId');
                } else {
                  log('⚠️ [ChatScreen] No existing 1-to-1 room found after checking $checked rooms');
                  roomId = null;
                }
              }
            }
          } else {
            log('❌ [ChatScreen] Contact ID format unknown: ${widget.contact.id}');
            roomId = null;
          }

          // Cache valid UUID room_id (after finding/creating it)
          if (roomId != null && _isUuid(roomId)) {
            _currentRoomId = roomId;
          } else {
            _currentRoomId = null;
          }
        } else {
          // roomId is not null (we have cached roomId)
          log('✅ [ChatScreen] Using cached room_id: $roomId');
          // Validate cached room_id
          if (!_isUuid(roomId)) {
            log('⚠️ [ChatScreen] Cached room_id is not UUID, clearing');
            _currentRoomId = null;
            roomId = null;
          } else {
            // CRITICAL FIX: Reuse cached rooms - cache will return existing Future if in-flight
            // No need to fetch again - cache handles deduplication
            final roomsResponse = await _chatService.fetchRooms(
                companyId: companyId, chatType: '1-1');

            // Handle 429 gracefully - use cached roomId even if fetch failed
            if (roomsResponse.success && roomsResponse.data != null) {
              roomExists = roomsResponse.data!.any((room) => room.id == roomId);
            } else if (roomsResponse.statusCode == 429) {
              // On 429, assume room exists (we have cached roomId)
              log('⚠️ [ChatScreen] 429 when validating cached room - assuming room exists');
              roomExists = true; // Use cached roomId despite 429
            }
          }
        }
      }

      // CRITICAL: 1-to-1 chat MUST always use UUID room_id (like group chat)
      // Backend requires room_id in WebSocket connection URL (HTTP 400 if missing)
      // If we don't have UUID, create room in background first
      if (roomId == null || !_isUuid(roomId)) {
        log('⚠️ [ChatScreen] No valid UUID room_id found for contact: ${widget.contact.id}');

        // Try to create room for both numeric and UUID contact IDs
        if (_isNumeric(widget.contact.id) || _isUuid(widget.contact.id)) {
          final contactIdType =
              _isNumeric(widget.contact.id) ? 'numeric' : 'UUID';
          log('   Contact has $contactIdType ID - creating 1-to-1 room in background...');

          // REQUEST DEDUPLICATION: Check if room creation is already in-flight for this contact
          final contactId = widget.contact.id;
          final inFlightCreation = _inFlightRoomCreations[contactId];
          if (inFlightCreation != null) {
            log('⏸️ [ChatScreen] Room creation already in-flight for contact $contactId - awaiting existing request');
            try {
              final newRoomId = await inFlightCreation;
              if (newRoomId != null) {
                roomId = newRoomId;
                roomExists = true;
                _currentRoomId = newRoomId;
                log('✅ [ChatScreen] Room creation completed (deduplicated): $newRoomId');
                // Continue with room opening below
              } else {
                log('⚠️ [ChatScreen] In-flight room creation failed - will not retry');
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                    _errorMessage =
                        'Failed to create chat room. Please try again later.';
                  });
                }
                _isOpeningRoom = false;
                return;
              }
            } catch (e) {
              log('⚠️ [ChatScreen] In-flight room creation error: $e');
              // Continue - will try to create below
            }
          } else {
            // No in-flight creation - create room now
            try {
              // Create Future for room creation (for deduplication)
              final createFuture = RoomService.instance
                  .createOneToOneRoom(
                contactName: widget.contact.name,
                contactId: widget.contact.id,
                companyId: companyId,
                contactPhone: widget.contact.phoneNumber,
              )
                  .then((createResponse) {
                // Remove from in-flight when complete
                _inFlightRoomCreations.remove(contactId);

                if (createResponse.success && createResponse.data != null) {
                  return createResponse.data!;
                } else {
                  // Handle 429 gracefully - don't fail hard
                  if (createResponse.statusCode == 429) {
                    log('⚠️ [ChatScreen] 429 when creating room - will retry later');
                    return null; // Return null on 429, will retry
                  }
                  log('❌ [ChatScreen] Failed to create 1-to-1 room: ${createResponse.error}');
                  log('   statusCode: ${createResponse.statusCode}, message: ${createResponse.message}');
                  return null;
                }
              }).catchError((e, stackTrace) {
                // Remove from in-flight on error
                _inFlightRoomCreations.remove(contactId);
                log('❌ [ChatScreen] Exception creating 1-to-1 room: $e');
                if (stackTrace != null) {
                  log('   Stack: $stackTrace');
                }
                return null;
              });

              // Mark as in-flight (for deduplication)
              _inFlightRoomCreations[contactId] = createFuture;

              final newRoomId = await createFuture;

              if (newRoomId != null) {
                log('✅ [ChatScreen] 1-to-1 room created successfully: $newRoomId');
                roomId = newRoomId;
                roomExists = true;
                _currentRoomId = newRoomId;
                log('   Room created - proceeding with WebSocket connection');

                // IMPORTANT: Invalidate 1-1 rooms cache so Chat & Calls History
                // sees this new chat immediately after user navigates back.
                if (companyId != null) {
                  ChatService.instance.invalidateRoomsCache(
                    companyId: companyId,
                    chatType: '1-1',
                  );
                }

                // Continue to openRoom() below with the new UUID
              } else {
                log('❌ [ChatScreen] Failed to create 1-to-1 room');
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                    _errorMessage =
                        'Failed to create chat room. Please try again later.';
                  });
                  _hideLoaderDialog();
                }
                _isOpeningRoom = false;
                return;
              }
            } catch (e) {
              // Remove from in-flight on exception
              _inFlightRoomCreations.remove(contactId);
              log('❌ [ChatScreen] Exception creating 1-to-1 room: $e');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasError = true;
                  _errorMessage = 'Failed to create chat room: $e';
                });
                _hideLoaderDialog();
              }
              _isOpeningRoom = false;
              return;
            }
          }
        } else {
          // Unknown format - show error
          log('❌ [ChatScreen] Cannot proceed - contact ID format is unknown');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage =
                  'Unable to start chat. Contact identifier is missing or invalid.';
            });
            _hideLoaderDialog();
          }
          return;
        }
      }

      // Step 2-5: Open room using ChatService (handles join, fetch messages, WebSocket)
      // roomId is guaranteed to be non-null and UUID format at this point
      // This matches the group chat flow exactly - just like group chat calls openRoom(widget.group.id)
      // CRITICAL: Store room_id before calling openRoom (like group chat stores widget.group.id)
      _currentRoomId = roomId!;

      // Register room-to-contact mapping for unread count tracking
      await UnreadCountManager.instance
          .mapRoomToContact(roomId!, widget.contact.id);
      // Clear unread count when opening chat
      await UnreadCountManager.instance.clearUnreadCount(roomId!);

      // Load saved wallpaper for this room after roomId is set
      _loadSavedWallpaper();

      log('🔌 [ChatScreen] Opening room with UUID: $_currentRoomId (like group chat uses widget.group.id)');
      log('📡 [ChatScreen] Calling messages API: GET /api/v1/rooms/$_currentRoomId/messages?company_id=$companyId&limit=$_messagesPerPage&offset=0');

      // Reset pagination state (like group chat)
      _currentOffset = 0;
      _hasMoreMessages = true;

      // Fetch room info to get the member name (person you're chatting with)
      // This ensures we show the member name, not the user's own name
      if (_currentRoomId != null && _isUuid(_currentRoomId!)) {
        try {
          final roomInfoResponse = await RoomService.instance.getRoomInfo(
            roomId: _currentRoomId!,
            companyId: companyId,
          );

          if (roomInfoResponse.success && roomInfoResponse.data != null) {
            final roomInfo = roomInfoResponse.data!;

            // For 1-to-1 chats: prefer backend peer_user (source of truth), else derive from members.
            if (roomInfo.memberCount == 2 && roomInfo.members.length == 2) {
              if (roomInfo.peerUser != null) {
                _memberName =
                    roomInfo.peerUser!.userName?.trim().isNotEmpty == true
                        ? roomInfo.peerUser!.userName!
                        : widget.contact.name;
                _memberAvatar =
                    roomInfo.peerUser!.avatar?.trim().isNotEmpty == true
                        ? roomInfo.peerUser!.avatar
                        : null;
                log('✅ [ChatScreen] Using peer_user from API: $_memberName');
                if (mounted) setState(() {});
              } else if (_currentUserId != null) {
                try {
                  final otherMember = roomInfo.members.firstWhere(
                    (m) => !m.isCurrentUser(_currentUserId),
                    orElse: () => roomInfo.members.first,
                  );
                  _memberName = otherMember.username ?? widget.contact.name;
                  _memberAvatar = otherMember.avatar;
                  log('✅ [ChatScreen] Found other member name: $_memberName (not current user name)');
                  if (_memberAvatar != null && _memberAvatar!.isNotEmpty) {
                    log('✅ [ChatScreen] Found member avatar: $_memberAvatar');
                  } else {
                    log('⚠️ [ChatScreen] Member avatar is null or empty');
                  }
                  if (mounted) setState(() {});
                } catch (e) {
                  log('⚠️ [ChatScreen] Error finding other member: $e');
                  _memberName = widget.contact.name;
                  _memberAvatar = null;
                  if (mounted) setState(() {});
                }
              } else {
                log('⚠️ [ChatScreen] Current user ID not available for member identification');
                _memberName = widget.contact.name;
                _memberAvatar = null;
                if (mounted) setState(() {});
              }
            } else {
              log('⚠️ [ChatScreen] RoomInfo shows ${roomInfo.memberCount} members (expected 2 for 1-to-1 chat)');
              _memberName = widget.contact.name;
              _memberAvatar = null;
              if (mounted) {
                setState(() {});
              }
            }
          } else {
            _memberName = widget.contact.name;
            _memberAvatar = null;
            if (mounted) {
              setState(() {});
            }
          }
        } catch (e) {
          log('⚠️ [ChatScreen] Error fetching room info for member name: $e');
          _memberName = widget.contact.name; // Fallback to contact name
          _memberAvatar = null;
          if (mounted) {
            setState(() {});
          }
        }
      } else {
        _memberName = widget.contact.name; // Fallback to contact name
        _memberAvatar = null;
        if (mounted) {
          setState(() {});
        }
      }

      // PERFORMANCE OPTIMIZATION: Check cache first before API call
      final messageCache = MessageCache();
      final cachedMessages = messageCache.getCachedMessages(
        _currentRoomId!,
        companyId,
        _currentOffset,
        _messagesPerPage,
      );

      // Call openRoom which internally calls the messages API
      // API: GET /api/v1/rooms/{roomId}/messages?company_id={companyId}&limit={limit}&offset={offset}
      // CRITICAL: Always check membership first before connecting with UUID
      // Backend will validate membership using old_gate_user_id from token
      ApiResponse<List<RoomMessage>>? response;
      List<RoomMessage> roomMessages;

      // PERFORMANCE OPTIMIZATION: Check cache first before API call
      if (cachedMessages != null) {
        // Use cached messages - render immediately
        log('✅ [ChatScreen] Using cached messages (${cachedMessages.length} messages)');
        roomMessages = cachedMessages;

        // Still need to open room for WebSocket connection, but don't wait for messages
        // Open room in background (non-blocking)
        _chatService
            .openRoom(
          roomId: _currentRoomId!,
          isMember: false,
          companyId: companyId,
          limit: _messagesPerPage,
          offset: _currentOffset,
          allowNewRoom: !roomExists,
        )
            .then((openRoomResponse) {
          // Update cache if we got fresh messages
          if (openRoomResponse.success &&
              openRoomResponse.data != null &&
              mounted) {
            final freshMessages = openRoomResponse.data!;
            if (freshMessages.isNotEmpty) {
              messageCache.cacheMessages(
                _currentRoomId!,
                companyId,
                _currentOffset,
                _messagesPerPage,
                freshMessages,
              );
              // Check if we have new messages not in cache
              final newMessageIds = freshMessages.map((m) => m.id).toSet();
              final cachedMessageIds = cachedMessages.map((m) => m.id).toSet();
              if (newMessageIds.difference(cachedMessageIds).isNotEmpty) {
                // We have new messages - reload by calling _fetchRoomInfoAndOpenRoom again
                // But only if we're not already loading
                if (!_isLoading && !_isOpeningRoom && mounted) {
                  _fetchRoomInfoAndOpenRoom();

                  WidgetsBinding.instance.addObserver(this);
                  _messageFocusNode.addListener(() {
                    if (_messageFocusNode.hasFocus) {
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _scrollToBottom());
                    }
                  });
                }
              }
            }
          }
        });
        // Create a success response for cached messages
        response = ApiResponse.success(roomMessages);
      } else {
        // No cache - fetch from API
        log('📡 [ChatScreen] No cached messages - fetching from API');
        response = await _chatService.openRoom(
          roomId: _currentRoomId!,
          isMember:
              false, // Always validate membership first - backend handles deduplication
          companyId: companyId,
          limit: _messagesPerPage,
          offset: _currentOffset,
          allowNewRoom:
              !roomExists, // Allow proceeding if room doesn't exist yet (for 1-to-1 chats)
        );

        if (!mounted) return;

        // Handle response
        if (response.success) {
          roomMessages = response.data ?? <RoomMessage>[];

          // Cache the messages for future use
          if (roomMessages.isNotEmpty) {
            messageCache.cacheMessages(
              _currentRoomId!,
              companyId,
              _currentOffset,
              _messagesPerPage,
              roomMessages,
            );
          }

          // Mark room as read when user opens chat (backend also does this in GetMessages, but we call explicitly for consistency)
          if (_currentRoomId != null) {
            try {
              await _roomService.markRoomAsRead(_currentRoomId!);
              log('✅ [ChatScreen] Room marked as read: $_currentRoomId');
            } catch (e) {
              log('⚠️ [ChatScreen] Failed to mark room as read: $e');
              // Non-critical - continue even if mark-as-read fails
            }
          }
        } else {
          roomMessages = <RoomMessage>[];
        }
      }

      if (!mounted) return;

      // Handle response
      if (roomMessages.isNotEmpty) {
        log('📥 [ChatScreen] Received ${roomMessages.length} messages from API');
        if (roomMessages.isNotEmpty) {
          log('   First message (oldest): ${roomMessages.first.createdAt} - ${roomMessages.first.body.isEmpty ? "(empty)" : roomMessages.first.body.substring(0, roomMessages.first.body.length > 30 ? 30 : roomMessages.first.body.length)}');
          log('   Last message (newest): ${roomMessages.last.createdAt} - ${roomMessages.last.body.isEmpty ? "(empty)" : roomMessages.last.body.substring(0, roomMessages.last.body.length > 30 ? 30 : roomMessages.last.body.length)}');
        }
        for (final rm in roomMessages) {
          log('   Message ID: ${rm.id}, Created: ${rm.createdAt}, Content: ${rm.body.isEmpty ? "(empty)" : rm.body.substring(0, rm.body.length > 30 ? 30 : rm.body.length)}, ReplyTo: ${rm.replyTo ?? "null"}');
        }

        // Cache avatars from messages API response (like group chat)
        // CRITICAL: Convert numeric senderId to UUID using RoomInfo mapping, then cache with UUID
        for (final rm in roomMessages) {
          if (rm.senderAvatar != null &&
              rm.senderAvatar!.isNotEmpty &&
              rm.senderId.isNotEmpty) {
            // Determine UUID for this sender
            String? senderUuid = rm.senderId;

            // If senderId is numeric, try to find UUID from RoomInfo members
            if (!rm.senderId.contains('-') &&
                int.tryParse(rm.senderId) != null) {
              // Numeric ID - try to find UUID from cached RoomInfo
              final numericId = int.parse(rm.senderId);
              senderUuid = _numericIdToUuidMap[numericId];

              // If still not found, use numeric ID as fallback (but log warning)
              if (senderUuid == null) {
                senderUuid = rm.senderId; // Keep numeric as fallback
                log('⚠️ [ChatScreen] Could not find UUID for numeric senderId ${rm.senderId}, using numeric as fallback');
              }
            }

            // Cache with UUID (primary) and numeric ID (fallback)
            if (senderUuid != null && senderUuid.isNotEmpty) {
              _memberAvatarCache[senderUuid] = rm.senderAvatar;
              log('✅ [ChatScreen] Cached avatar with UUID $senderUuid for senderId ${rm.senderId}: ${rm.senderAvatar}');
            }

            // Also cache with original senderId (numeric) as fallback
            if (rm.senderId != senderUuid) {
              _memberAvatarCache[rm.senderId] = rm.senderAvatar;
            }

            // Also cache with snapshotUserId (numeric) as fallback
            if (rm.snapshotUserId != null) {
              _memberAvatarCache[rm.snapshotUserId.toString()] =
                  rm.senderAvatar;
              // Try to map snapshotUserId to UUID if we can find it
              final uuidForSnapshot = _numericIdToUuidMap[rm.snapshotUserId];
              if (uuidForSnapshot != null) {
                _memberAvatarCache[uuidForSnapshot] = rm.senderAvatar;
              }
            }
          }
        }

        // Ensure RoomInfo avatars are available for all senders
        // This ensures avatars from RoomInfo API are used for messages that don't have avatars
        _ensureRoomInfoAvatarsCached();

        // Convert RoomMessage to ChatMessage
        // Messages are already sorted ascending (oldest first, newest last) by RoomService
        // FILTER: For 1-to-1 chats, filter out system messages like "joined the group"
        final filteredRoomMessages = roomMessages.where((rm) {
          // In 1-to-1 chats, filter out system messages
          final isSystemMessage = _isSystemMessage(rm);
          if (isSystemMessage) {
            log('🚫 [ChatScreen] Filtering out system message: ${rm.body.substring(0, rm.body.length > 50 ? 50 : rm.body.length)}');
            return false; // Filter out system messages
          }
          return true; // Keep regular messages
        }).toList();

        // First pass: create all messages without replyTo (reactions are included from API)
        final chatMessagesWithoutReply = filteredRoomMessages.map((rm) {
          final isFromCurrentUser = _isMessageFromCurrentUser(rm);
          String? imageUrl;
          String? documentUrl;
          String? documentName;
          String? documentType;
          bool isDocument = false;
          String? audioUrl;
          Duration? audioDuration;
          String? videoUrl;
          bool isVideo = false;

          if (rm.messageType == 'image' ||
              rm.messageType == 'file' ||
              rm.messageType == 'voice' ||
              rm.messageType == 'audio' ||
              rm.messageType == 'video') {
            final content = rm.body;
            try {
              final bodyJson = jsonDecode(content) as Map<String, dynamic>?;
              if (bodyJson != null) {
                // Helper to safely transform URLs that contain localhost
                String? normalizeUrl(String? url) {
                  if (url == null || url.isEmpty) return null;
                  return RoomService.transformLocalhostUrl(url);
                }

                Duration? extractDuration(dynamic value) {
                  if (value is int) {
                    return Duration(milliseconds: value);
                  } else if (value is String) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) {
                      return Duration(milliseconds: parsed);
                    }
                  }
                  return null;
                }

                switch (rm.messageType) {
                  case 'image':
                    imageUrl = normalizeUrl(
                      bodyJson['file_url']?.toString() ??
                          bodyJson['image_url']?.toString() ??
                          bodyJson['imageUrl']?.toString(),
                    );
                    break;
                  case 'file':
                    documentUrl = bodyJson['file_url']?.toString();
                    documentUrl ??= bodyJson['fileUrl']?.toString();
                    documentUrl ??= bodyJson['documentUrl']?.toString();
                    documentUrl ??= bodyJson['url']?.toString();
                    documentUrl = normalizeUrl(documentUrl);
                    documentName = bodyJson['file_name']?.toString();
                    documentType = bodyJson['file_type']?.toString();

                    // Helper to check if file is a video by extension
                    bool isVideoFile(String? url, String? fileName) {
                      if (url == null && fileName == null) return false;
                      final checkString = (fileName ?? url ?? '').toLowerCase();
                      return checkString.endsWith('.mp4') ||
                          checkString.endsWith('.mov') ||
                          checkString.endsWith('.avi') ||
                          checkString.endsWith('.mkv') ||
                          checkString.endsWith('.webm') ||
                          checkString.endsWith('.m4v') ||
                          checkString.endsWith('.3gp');
                    }

                    // Helper to check if file is an audio by extension
                    bool isAudioFile(String? url, String? fileName) {
                      if (url == null && fileName == null) return false;
                      final checkString = (fileName ?? url ?? '').toLowerCase();
                      return checkString.endsWith('.mp3') ||
                          checkString.endsWith('.m4a') ||
                          checkString.endsWith('.aac') ||
                          checkString.endsWith('.wav') ||
                          checkString.endsWith('.ogg') ||
                          checkString.endsWith('.flac');
                    }

                    final mimeType = bodyJson['mime_type']?.toString();
                    final isVideoByMime = mimeType != null &&
                        mimeType.toLowerCase().startsWith('video');
                    final isVideoByExtension =
                        isVideoFile(documentUrl, documentName);
                    final isAudioByMime = mimeType != null &&
                        mimeType.toLowerCase().startsWith('audio');
                    final isAudioByExtension =
                        isAudioFile(documentUrl, documentName);

                    if (isAudioByMime || isAudioByExtension) {
                      audioUrl = bodyJson['file_url']?.toString() ??
                          bodyJson['fileUrl']?.toString() ??
                          bodyJson['audio_url']?.toString() ??
                          bodyJson['url']?.toString();
                      audioDuration = extractDuration(bodyJson['duration_ms']);
                      isDocument = false;
                      isVideo = false;
                      videoUrl = null;
                      audioUrl = normalizeUrl(audioUrl);
                    } else if (isVideoByMime || isVideoByExtension) {
                      videoUrl = bodyJson['file_url']?.toString() ??
                          bodyJson['fileUrl']?.toString() ??
                          bodyJson['video_url']?.toString() ??
                          bodyJson['url']?.toString();
                      isVideo = videoUrl != null && videoUrl.isNotEmpty;
                      isDocument = false;
                      audioUrl = null;
                      videoUrl = normalizeUrl(videoUrl);
                    } else {
                      // Only set as document if it's not video or audio
                      isDocument =
                          documentUrl != null && documentUrl.isNotEmpty;
                    }
                    break;
                  case 'voice':
                  case 'audio':
                    audioUrl = bodyJson['file_url']?.toString();
                    audioUrl ??= bodyJson['fileUrl']?.toString();
                    audioUrl ??= bodyJson['audio_url']?.toString();
                    audioUrl ??= bodyJson['url']?.toString();
                    audioDuration = extractDuration(bodyJson['duration_ms']);
                    audioUrl = normalizeUrl(audioUrl);
                    break;
                  case 'video':
                    videoUrl = bodyJson['file_url']?.toString() ??
                        bodyJson['fileUrl']?.toString() ??
                        bodyJson['video_url']?.toString() ??
                        bodyJson['url']?.toString();
                    isVideo = videoUrl != null && videoUrl.isNotEmpty;
                    videoUrl = normalizeUrl(videoUrl);
                    break;
                  default:
                    break;
                }
              } else {
                log('⚠️ [ChatScreen] bodyJson parsed as null for message ${rm.id}');
              }
            } catch (e, stackTrace) {
              log('❌ [ChatScreen] Failed to parse message ${rm.id} body as JSON: $e');
              log('   Stack trace: $stackTrace');
              if ((rm.messageType == 'voice' || rm.messageType == 'audio') &&
                  (content.trim().startsWith('http://') ||
                      content.trim().startsWith('https://'))) {
                audioUrl = RoomService.transformLocalhostUrl(content.trim());
              }
            }
          }

          String displayText = rm.isDeleted ? '' : rm.body;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            displayText = '';
          } else if (documentUrl != null && documentUrl.isNotEmpty) {
            displayText = documentName ?? '📎 Document';
          } else if (audioUrl != null && audioUrl.isNotEmpty) {
            displayText = '🎤 Voice note';
          } else if (isVideo && videoUrl != null && videoUrl.isNotEmpty) {
            displayText = '🎥 Video';
          } else if ((rm.messageType == 'image' ||
                  rm.messageType == 'file' ||
                  rm.messageType == 'voice' ||
                  rm.messageType == 'audio') &&
              rm.body.trim().startsWith('{') &&
              rm.body.trim().endsWith('}')) {
            try {
              jsonDecode(rm.body);
              displayText = '';
            } catch (_) {
              // Keep original displayText if not valid JSON
            }
          }

          final isForwardedFinal = _isForwardedRoomMessage(rm);

          return ChatMessage(
            id: rm.id,
            text: displayText,
            isMe: isFromCurrentUser,
            timestamp: rm.createdAt,
            editedAt: rm.editedAt,
            isDeleted: rm.isDeleted,
            status: isFromCurrentUser
                ? MessageStatus.delivered
                : MessageStatus.seen,
            isOnline: widget.contact.status == IntercomContactStatus.online,
            reactions: rm.reactions,
            imageUrl: imageUrl,
            documentUrl: documentUrl,
            isAudio: audioUrl != null && audioUrl.isNotEmpty,
            audioUrl: audioUrl,
            audioDuration: audioDuration,
            isVideo: isVideo,
            videoUrl: videoUrl,
            // CRITICAL: Never mark as document if it's a video
            isDocument: isDocument && !isVideo,
            documentName: documentName,
            documentType: documentType,
            isForwarded: isForwardedFinal,
          );
        }).toList();

        // Second pass: resolve replyTo references
        // CRITICAL: Check both new messages and already loaded messages to find replied-to messages
        // This ensures replies work even if the replied-to message is from a previous page
        // Track replied-to message IDs that need to be preserved
        final Set<String> repliedToMessageIds = {};
        // CRITICAL: Include existing messages (preserved from reopening) in lookup
        // This matches group chat behavior and ensures messages are preserved when reopening
        final allMessagesForLookup = [
          ...existingMessages,
          ..._messages,
          ...chatMessagesWithoutReply
        ];
        final chatMessages = chatMessagesWithoutReply.map((cm) {
          final roomMessage =
              filteredRoomMessages.firstWhere((rm) => rm.id == cm.id);
          if (roomMessage.replyTo != null && roomMessage.replyTo!.isNotEmpty) {
            log('🔍 [ChatScreen] Resolving replyTo for message ${cm.id}: looking for ${roomMessage.replyTo}');
            // Track this replied-to message ID
            repliedToMessageIds.add(roomMessage.replyTo!);

            // First, try to find in already loaded messages (includes pagination)
            ChatMessage? repliedToMessage;
            try {
              repliedToMessage = allMessagesForLookup.firstWhere(
                (m) => m.id == roomMessage.replyTo,
              );
              log('✅ [ChatScreen] Found replied-to message: ${repliedToMessage.id} - "${repliedToMessage.text.substring(0, repliedToMessage.text.length > 20 ? 20 : repliedToMessage.text.length)}"');
            } catch (e) {
              // Message not found in loaded messages
              // Try to find it in the API response first
              try {
                final repliedToRoomMessage = roomMessages.firstWhere(
                  (rm) =>
                      rm.id.trim().toLowerCase() ==
                          roomMessage.replyTo!.trim().toLowerCase() ||
                      rm.id == roomMessage.replyTo,
                );
                repliedToMessage = ChatMessage(
                  id: repliedToRoomMessage.id,
                  text: repliedToRoomMessage.isDeleted
                      ? ''
                      : repliedToRoomMessage.body,
                  isMe: _isMessageFromCurrentUser(repliedToRoomMessage),
                  timestamp: repliedToRoomMessage.createdAt,
                  editedAt: repliedToRoomMessage.editedAt,
                  isDeleted: repliedToRoomMessage.isDeleted,
                  status: MessageStatus.delivered,
                  reactions: repliedToRoomMessage.reactions,
                );
                log('✅ [ChatScreen] Found replied-to message in API response: ${repliedToMessage.id}');
              } catch (e2) {
                // Message not in this batch - try to load older messages to find it
                log('⚠️ [ChatScreen] Reply target message ${roomMessage.replyTo} not in current batch. Will try to load older messages.');

                // Schedule async fetch of older messages to find the replied-to message
                // This ensures the reply preview is populated even if the message is in an older batch
                _fetchRepliedToMessage(roomMessage.replyTo!, cm.id);

                // Create a temporary placeholder that will be updated when the message is found
                repliedToMessage = ChatMessage(
                  id: roomMessage.replyTo!,
                  text: 'Loading original message...',
                  isMe: false,
                  timestamp: DateTime.now().subtract(const Duration(hours: 1)),
                  isDeleted: false,
                );
                log('⚠️ [ChatScreen] Created temporary placeholder for reply target: ${repliedToMessage.id}');
              }
            }
            final messageWithReply = cm.copyWith(replyTo: repliedToMessage);
            log('✅ [ChatScreen] Message ${messageWithReply.id} now has replyTo: ${messageWithReply.replyTo != null ? messageWithReply.replyTo!.id : "null"}');
            return messageWithReply;
          }
          return cm;
        }).toList();

        // CRITICAL: Preserve replied-to messages from existing messages that are not in the new batch
        // This ensures that when re-entering chat, replied-to messages are not lost
        // Also preserve any existing messages that aren't in the new batch (for both refresh and reopen scenarios)
        final preservedRepliedToMessages = <ChatMessage>[];
        // Use existingMessages (which includes all _messages) for preservation
        final allExistingMessages = existingMessages;

        for (final existingMessage in allExistingMessages) {
          // Preserve if it's a replied-to message or if it's not in the new batch
          final isRepliedTo = repliedToMessageIds.contains(existingMessage.id);
          final isInNewBatch =
              chatMessages.any((m) => m.id == existingMessage.id);

          if (isRepliedTo && !isInNewBatch) {
            preservedRepliedToMessages.add(existingMessage);
            log('✅ [ChatScreen] Preserving replied-to message from existing messages: ${existingMessage.id}');
          } else if (!isInNewBatch) {
            // Preserve existing messages that aren't in the new batch (for both refresh and reopen)
            // This ensures messages aren't lost when reopening or refreshing
            preservedRepliedToMessages.add(existingMessage);
            log('✅ [ChatScreen] Preserving existing message (not in new batch): ${existingMessage.id}');
          }
        }

        // CRITICAL: Merge preserved messages with new messages (like group chat)
        // Sort by timestamp to maintain chronological order
        final allMessages = [...chatMessages, ...preservedRepliedToMessages];
        // Remove duplicates by ID (in case a message appears in both lists)
        final uniqueMessages = <String, ChatMessage>{};
        for (final msg in allMessages) {
          uniqueMessages[msg.id] = msg;
        }
        final finalMessages = uniqueMessages.values.toList();
        finalMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        log('✅ [ChatScreen] Converted to ${chatMessages.length} ChatMessages');
        log('   Preserved ${preservedRepliedToMessages.length} existing messages');
        log('   Total messages after merge: ${finalMessages.length}');
        // Log messages with replies for debugging
        for (final cm in finalMessages) {
          if (cm.replyTo != null) {
            log('   📎 Message ${cm.id} has replyTo: ${cm.replyTo!.id} - "${cm.replyTo!.text.substring(0, cm.replyTo!.text.length > 20 ? 20 : cm.replyTo!.text.length)}"');
          }
        }

        // Check if there are more messages (like group chat)
        // Use the actual limit used (which might be doubled for initial load)
        // Use filteredRoomMessages length for pagination check (after filtering system messages)
        final actualLimit =
            _currentOffset == 0 ? _messagesPerPage * 2 : _messagesPerPage;
        _hasMoreMessages = filteredRoomMessages.length >= actualLimit;

        setState(() {
          _messages = finalMessages;
          _isLoading = false;
          _hasError = false;
          _currentOffset = chatMessages.length; // Update offset for pagination
        });
        _hideLoaderDialog();

        // Reactions are already included in the messages API response
        // No need to fetch them separately
        log('✅ [ChatScreen] Reactions included in API response - no separate fetch needed');

        // Scroll to bottom after messages are loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && _messages.isNotEmpty) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
            _isAtBottom = true;
          }

          // Mark visible messages as read after chat opens
          _markVisibleMessagesAsRead();
        });

        _insertForwardPlaceholders();
        await _maybeSendPendingForwardMessages();
      } else {
        // Handle errors
        // CRITICAL: If we already have a UUID room_id (from room creation or chat history), keep it
        // Don't set _currentRoomId to null if we have a valid UUID
        // CRITICAL: Preserve existing messages if we have them (for reopening scenarios)
        if (_currentRoomId != null && _isUuid(_currentRoomId)) {
          log('⚠️ [ChatScreen] openRoom failed, but we have UUID room_id: $_currentRoomId');
          log('   Keeping room_id and preserving ${existingMessages.length} existing messages');
          log('   Attempting to fetch messages directly as fallback...');

          // CRITICAL: Try to fetch messages directly as fallback
          // This ensures messages are loaded even if membership validation had issues
          try {
            final messagesResponse = await _roomService.getMessages(
              roomId: _currentRoomId!,
              companyId: companyId,
              limit:
                  _messagesPerPage * 2, // Fetch more messages for initial load
              offset: 0,
            );

            if (messagesResponse.success && messagesResponse.data != null) {
              final roomMessages = messagesResponse.data!;
              log('✅ [ChatScreen] Successfully fetched ${roomMessages.length} messages directly (fallback)');

              // Mark room as read when user opens chat
              try {
                await _roomService.markRoomAsRead(_currentRoomId!);
                log('✅ [ChatScreen] Room marked as read (fallback path): $_currentRoomId');
              } catch (e) {
                log('⚠️ [ChatScreen] Failed to mark room as read (fallback): $e');
                // Non-critical - continue even if mark-as-read fails
              }

              // Process messages the same way as in successful openRoom
              // Convert RoomMessage to ChatMessage
              final chatMessagesWithoutReply = roomMessages.map((rm) {
                return ChatMessage(
                  id: rm.id,
                  text: rm.isDeleted ? '' : rm.body,
                  isMe: _isMessageFromCurrentUser(rm),
                  timestamp: rm.createdAt,
                  editedAt: rm.editedAt,
                  isDeleted: rm.isDeleted,
                  status: MessageStatus.delivered,
                  reactions: rm.reactions,
                  isForwarded: rm.isForwarded,
                );
              }).toList();

              // Resolve replyTo references
              final Set<String> repliedToMessageIds = {};
              final allMessagesForLookup = [
                ...existingMessages,
                ...chatMessagesWithoutReply
              ];
              final chatMessages = chatMessagesWithoutReply.map((cm) {
                final roomMessage =
                    roomMessages.firstWhere((rm) => rm.id == cm.id);
                if (roomMessage.replyTo != null &&
                    roomMessage.replyTo!.isNotEmpty) {
                  repliedToMessageIds.add(roomMessage.replyTo!);
                  ChatMessage? repliedToMessage;
                  try {
                    repliedToMessage = allMessagesForLookup.firstWhere(
                      (m) => m.id == roomMessage.replyTo,
                    );
                  } catch (e) {
                    // Message not found - create placeholder
                    repliedToMessage = ChatMessage(
                      id: roomMessage.replyTo!,
                      text: 'Loading original message...',
                      isMe: false,
                      timestamp:
                          DateTime.now().subtract(const Duration(hours: 1)),
                      isDeleted: false,
                    );
                  }
                  return cm.copyWith(replyTo: repliedToMessage);
                }
                return cm;
              }).toList();

              // Preserve existing messages that aren't in the new batch
              final preservedMessages = <ChatMessage>[];
              for (final existingMessage in existingMessages) {
                final isInNewBatch =
                    chatMessages.any((m) => m.id == existingMessage.id);
                if (!isInNewBatch) {
                  preservedMessages.add(existingMessage);
                }
              }

              // Merge and sort
              final allMessages = [...chatMessages, ...preservedMessages];
              final uniqueMessages = <String, ChatMessage>{};
              for (final msg in allMessages) {
                uniqueMessages[msg.id] = msg;
              }
              final finalMessages = uniqueMessages.values.toList();
              finalMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

              if (mounted) {
                setState(() {
                  _messages = finalMessages;
                  _isLoading = false;
                  _hasError = false;
                  _currentOffset = chatMessages.length;
                  _hasMoreMessages =
                      roomMessages.length >= _messagesPerPage * 2;
                });
                _hideLoaderDialog();
              }

              if (mounted) {
                await _maybeSendPendingForwardMessages();
              }

              // Try to connect WebSocket after successfully fetching messages
              Future.delayed(const Duration(milliseconds: 500), () async {
                if (mounted && _currentRoomId != null) {
                  log('🔌 [ChatScreen] Attempting WebSocket connection after fallback message fetch');
                  // Ensure membership and connect WebSocket
                  final isMember =
                      await _chatService.ensureMembership(_currentRoomId!);
                  if (isMember) {
                    await _chatService.initializeWebSocket();
                    // WebSocket join will happen automatically when messages are sent/received
                  }
                }
              });

              return; // Successfully loaded messages via fallback
            } else {
              log('⚠️ [ChatScreen] Direct message fetch also failed: ${messagesResponse.error}');
            }
          } catch (e) {
            log('⚠️ [ChatScreen] Exception during fallback message fetch: $e');
          }

          // If fallback also failed, preserve existing messages
          log('   Fallback failed - preserving ${existingMessages.length} existing messages');
          final messagesToPreserve = existingMessages.isNotEmpty
              ? existingMessages
              : _messages.isNotEmpty
                  ? _messages
                  : <ChatMessage>[];

          if (mounted) {
            setState(() {
              _messages = messagesToPreserve;
              _isLoading = false;
              _hasError = false;
            });
            _hideLoaderDialog();
          }
        } else if ((_isNumeric(widget.contact.id) ||
                _isUuid(widget.contact.id)) &&
            (response.statusCode == 400 || response.statusCode == 404)) {
          // For numeric or UUID contact IDs without room, try to create room now
          final contactIdType =
              _isNumeric(widget.contact.id) ? 'numeric' : 'UUID';
          log('⚠️ [ChatScreen] openRoom failed for $contactIdType contact ID - creating room now');

          try {
            final createResponse =
                await RoomService.instance.createOneToOneRoom(
              contactName: widget.contact.name,
              contactId: widget.contact.id,
              companyId: companyId!,
              contactPhone: widget.contact.phoneNumber,
            );

            if (createResponse.success && createResponse.data != null) {
              final newRoomId = createResponse.data!;
              log('✅ [ChatScreen] Room created successfully: $newRoomId');

              if (mounted) {
                setState(() {
                  _messages = [];
                  _isLoading = false;
                  _hasError = false;
                  _currentRoomId = newRoomId; // Set the UUID room_id
                });
                _hideLoaderDialog();

                // Try to connect WebSocket with the new room_id
                // CRITICAL: Check membership first before connecting with UUID
                Future.delayed(const Duration(milliseconds: 500), () async {
                  if (mounted && _currentRoomId != null) {
                    log('🔌 [ChatScreen] Connecting WebSocket with newly created room: $_currentRoomId');
                    log('   Validating membership first before connecting with UUID');
                    await _chatService.openRoom(
                      roomId: _currentRoomId!,
                      isMember:
                          false, // Always validate membership first - backend handles deduplication
                      companyId: companyId!,
                      limit: 0, // Don't fetch messages, just connect WebSocket
                      offset: 0,
                      allowNewRoom: false,
                    );
                  }
                });
              }
            } else {
              log('❌ [ChatScreen] Failed to create room: ${createResponse.error}');
              _handleMessageError(response.statusCode, response.displayError);
            }
          } catch (e) {
            log('❌ [ChatScreen] Exception creating room: $e');
            _handleMessageError(0, 'Failed to create chat room: $e');
          }
        } else {
          // For other errors, show error
          _handleMessageError(response.statusCode, response.displayError);
        }
        // Reset rate limit retry count on success
        _rateLimitRetryCount = 0;
      }
    } catch (e) {
      if (!mounted) return;
      log('❌ [ChatScreen] Error opening room: $e');
      _handleMessageError(0, 'An unexpected error occurred: $e');
    } finally {
      _isOpeningRoom = false;
    }
  }

  /// Check if a RoomMessage is from the current user
  /// This handles different senderId formats (UUID vs numeric string)
  /// Check if a message is a system message (like "joined the group")
  /// For 1-to-1 chats, we filter these out
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

  bool _isMessageFromCurrentUser(RoomMessage roomMessage) {
    // Priority 1: Check snapshot_user_id (most reliable)
    if (roomMessage.snapshotUserId != null && _currentUserNumericId != null) {
      if (roomMessage.snapshotUserId == _currentUserNumericId) {
        return true;
      }
    }

    // Priority 2: Check if senderId matches currentUserId (UUID comparison)
    if (_currentUserId != null && roomMessage.senderId == _currentUserId) {
      return true;
    }

    // Priority 3: Check if senderId is numeric and matches currentUserNumericId
    if (_currentUserNumericId != null) {
      final senderIdInt = int.tryParse(roomMessage.senderId);
      if (senderIdInt != null && senderIdInt == _currentUserNumericId) {
        return true;
      }
    }

    return false;
  }

  /// Get avatar for sender (like group chat)
  /// This method looks up avatars from cache, handling UUID/numeric ID conversions
  String? _getAvatarForSender(String senderId, {int? snapshotUserId}) {
    // Normalize senderId (trim whitespace)
    final normalizedSenderId = senderId.trim();

    // Try primary senderId first (could be UUID or numeric)
    String? avatar = _memberAvatarCache[normalizedSenderId];

    // Determine if senderId is UUID or numeric
    final isUuid =
        normalizedSenderId.contains('-') && normalizedSenderId.length > 30;
    final isNumeric = !isUuid && int.tryParse(normalizedSenderId) != null;

    String? lookupUuid = normalizedSenderId;

    // If senderId is numeric, try to find UUID and lookup
    if ((avatar == null || avatar.isEmpty) && isNumeric) {
      final numericId = int.parse(normalizedSenderId);
      lookupUuid = _numericIdToUuidMap[numericId];
      if (lookupUuid != null) {
        avatar = _memberAvatarCache[lookupUuid];
        log('🔍 [ChatScreen] _getAvatarForSender: converted numeric $numericId to UUID $lookupUuid, found=${avatar != null}');
      }
    }

    // If senderId is UUID, also try to find numeric ID and lookup
    if ((avatar == null || avatar.isEmpty) && isUuid) {
      // Try to find numeric ID for this UUID (reverse lookup)
      int? numericId;
      _numericIdToUuidMap.forEach((key, value) {
        if (value == normalizedSenderId) {
          numericId = key;
        }
      });

      if (numericId != null) {
        avatar = _memberAvatarCache[numericId.toString()];
        if (avatar != null && avatar.isNotEmpty) {
          log('🔍 [ChatScreen] _getAvatarForSender: found avatar via reverse lookup (UUID -> numeric $numericId)');
        }
      }
    }

    // If not found and snapshotUserId available, try numeric ID
    if ((avatar == null || avatar.isEmpty) && snapshotUserId != null) {
      avatar = _memberAvatarCache[snapshotUserId.toString()];
      // Also try UUID mapped from snapshotUserId
      if (avatar == null || avatar.isEmpty) {
        final uuid = _numericIdToUuidMap[snapshotUserId];
        if (uuid != null) {
          avatar = _memberAvatarCache[uuid];
          if (avatar != null && avatar.isNotEmpty) {
            lookupUuid = uuid;
            log('🔍 [ChatScreen] _getAvatarForSender: found avatar via snapshotUserId -> UUID mapping');
          }
        }
      }
    }

    // Last resort: Check widget.contact for avatar (from RoomInfo)
    if ((avatar == null || avatar.isEmpty)) {
      // For 1-to-1 chat, check if this is the other member
      // Match by UUID, numeric ID, or contact ID
      final contactId = widget.contact.id.trim();
      if (contactId == normalizedSenderId ||
          contactId == lookupUuid ||
          (lookupUuid != null && contactId == lookupUuid) ||
          (isNumeric && contactId == normalizedSenderId) ||
          (isUuid && contactId == normalizedSenderId)) {
        avatar = widget.contact.photoUrl ?? _memberAvatar;
        if (avatar != null && avatar.isNotEmpty) {
          log('✅ [ChatScreen] _getAvatarForSender: Found avatar from widget.contact: $avatar');
          // Cache it for future lookups
          if (normalizedSenderId.isNotEmpty) {
            _memberAvatarCache[normalizedSenderId] = avatar;
            if (lookupUuid != null && lookupUuid != normalizedSenderId) {
              _memberAvatarCache[lookupUuid] = avatar;
            }
          }
        }
      }
    }

    return avatar;
  }

  /// Ensure RoomInfo avatars are cached for all members (like group chat)
  /// This method ensures avatars from RoomInfo API are available in cache
  void _ensureRoomInfoAvatarsCached() {
    // Cache avatar from _memberAvatar (populated from RoomInfo)
    if (_memberAvatar != null && _memberAvatar!.isNotEmpty) {
      // Cache with widget.contact.id if available
      if (widget.contact.id.isNotEmpty) {
        if (!_memberAvatarCache.containsKey(widget.contact.id) ||
            _memberAvatarCache[widget.contact.id] == null ||
            _memberAvatarCache[widget.contact.id]!.isEmpty) {
          _memberAvatarCache[widget.contact.id] = _memberAvatar;
          log('✅ [ChatScreen] Cached avatar from _memberAvatar: ${widget.contact.id} -> $_memberAvatar');
        }
      }
      // Also cache with widget.contact.photoUrl if available
      if (widget.contact.photoUrl != null &&
          widget.contact.photoUrl!.isNotEmpty) {
        if (widget.contact.id.isNotEmpty) {
          _memberAvatarCache[widget.contact.id] = widget.contact.photoUrl;
        }
      }
    }
  }

  /// Handle incoming WebSocket messages
  ///
  /// Matches group chat pattern exactly:
  /// - Simple room_id check (like group chat checks widget.group.id)
  /// - Only process messages for current room
  Future<void> _handleWebSocketMessage(WebSocketMessage wsMessage) async {
    // Only process messages for current room (like group chat)
    // _currentRoomId should always be UUID (set in _openRoom before WebSocket connects)
    if (_currentRoomId == null) {
      log('⚠️ [ChatScreen] No current room_id set, ignoring message');
      return;
    }

    if (wsMessage.roomId != _currentRoomId) {
      log('⚠️ [ChatScreen] Ignoring message - different room_id: ${wsMessage.roomId} (current: $_currentRoomId)');
      return;
    }

    // Handle typing events from WebSocket (when backend supports it)
    // Check for typing events in the type field or data.type field
    final messageType = wsMessage.type?.toLowerCase() ??
        wsMessage.data?['type']?.toString().toLowerCase();
    if (messageType == 'typing') {
      final typingUserId =
          wsMessage.userId ?? wsMessage.data?['user_id']?.toString();
      final isTyping = wsMessage.data?['is_typing'] as bool? ?? true;
      if (typingUserId != null) {
        _handleOtherUserTyping(typingUserId, isTyping);
      }
      return; // Don't process typing events as messages
    }

    // Handle unread_count_update events from WebSocket
    if (messageType == 'unread_count_update' ||
        wsMessage.messageTypeEnum == WebSocketMessageType.unreadCountUpdate) {
      final roomId = wsMessage.roomId ?? wsMessage.data?['room_id']?.toString();
      final userId = wsMessage.userId ?? wsMessage.data?['user_id']?.toString();
      final unreadCount = wsMessage.data?['unread_count'] as int? ??
          (wsMessage.data?['unread_count'] is String
              ? int.tryParse(wsMessage.data!['unread_count'] as String)
              : null);

      if (roomId != null && userId != null && unreadCount != null) {
        log('📊 [ChatScreen] Received unread_count_update: room=$roomId, user=$userId, count=$unreadCount');

        // Update local unread count manager if this is for current user
        if (userId == _currentUserId) {
          if (unreadCount == 0) {
            await UnreadCountManager.instance.clearUnreadCount(roomId);
          } else {
            // Set the unread count directly (backend is source of truth)
            await UnreadCountManager.instance
                .setUnreadCount(roomId, unreadCount);
            log('📊 [ChatScreen] Unread count updated to $unreadCount for room $roomId');
          }
        }
      }
      return; // Don't process unread_count_update as messages
    }

    // CRITICAL FIX: Handle read receipt updates from WebSocket
    // This enables real-time blue checkmarks when other users read your messages
    if (messageType == 'read_receipt' ||
        messageType == 'readreceipt' ||
        wsMessage.messageTypeEnum == WebSocketMessageType.readReceipt) {
      final messageId = wsMessage.data?['message_id']?.toString();
      final userId = wsMessage.userId ?? wsMessage.data?['user_id']?.toString();
      final readAt = wsMessage.data?['read_at'];

      log('📖 [ChatScreen] Read receipt received: message=$messageId, user=$userId, readAt=$readAt');

      if (messageId != null && mounted) {
        // Update message status to "seen" (blue checkmarks)
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1 && _messages[index].isMe) {
            _messages[index] = _messages[index].copyWith(
              status: MessageStatus.seen, // Blue double checkmarks
            );
            log('✅ [ChatScreen] Updated message to SEEN status: $messageId');
          }
        });
      }

      return; // Don't process read_receipt as regular message
    }

    // Handle delivered receipt updates from WebSocket
    if (messageType == 'delivered_receipt' ||
        messageType == 'deliveredreceipt' ||
        messageType == 'message_delivered') {
      final messageId = wsMessage.data?['message_id']?.toString();
      final userId = wsMessage.userId ?? wsMessage.data?['user_id']?.toString();

      log('🚚 [ChatScreen] Delivered receipt received: message=$messageId, user=$userId');

      if (messageId != null && mounted) {
        // Update message status to "delivered" (double grey checkmarks)
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1 && _messages[index].isMe) {
            // Only update if current status is sent (don't downgrade from seen)
            if (_messages[index].status == MessageStatus.sent) {
              _messages[index] = _messages[index].copyWith(
                status: MessageStatus.delivered,
              );
              log('✅ [ChatScreen] Updated message to DELIVERED status: $messageId');
            }
          }
        });
      }

      return; // Don't process delivered_receipt as regular message
    }

    log('✅ [ChatScreen] Processing WebSocket message for room: ${wsMessage.roomId}');

    // Convert WebSocket message to ChatMessage
    // Handle messages with or without data field
    if (wsMessage.data != null || wsMessage.content != null) {
      // Handle both regular messages and deleted messages
      final isDeleted = wsMessage.data?['is_deleted'] as bool? ?? false;

      // CRITICAL: Extract content - check both content field and data.content
      String content = wsMessage.content ?? '';
      if (content.isEmpty && wsMessage.data != null) {
        // Try to get content from data field
        content = wsMessage.data!['content']?.toString() ?? '';
      }

      log('📥 [ChatScreen] WebSocket message received - content length: ${content.length}, data keys: ${wsMessage.data?.keys.toList() ?? []}');

      // Extract snapshot_user_id from WebSocket data if available
      int? snapshotUserId;
      try {
        final snapshotUserIdValue = wsMessage.data!['snapshot_user_id'];
        if (snapshotUserIdValue != null) {
          if (snapshotUserIdValue is int) {
            snapshotUserId = snapshotUserIdValue;
          } else if (snapshotUserIdValue is String) {
            snapshotUserId = int.tryParse(snapshotUserIdValue);
          }
        }
      } catch (e) {
        snapshotUserId = null;
      }

      // Extract reply_to from WebSocket message data
      final replyToId = wsMessage.data?['reply_to']?.toString() ??
          wsMessage.data?['parent_message_id']?.toString();

      // Extract and cache avatar from WebSocket message data if available (like group chat)
      // Check multiple possible fields: avatar, photo_url, sender_avatar, user_avatar
      String? avatarUrl;
      if (wsMessage.data != null) {
        avatarUrl = wsMessage.data!['avatar']?.toString() ??
            wsMessage.data!['photo_url']?.toString() ??
            wsMessage.data!['sender_avatar']?.toString() ??
            wsMessage.data!['user_avatar']?.toString();

        // Also check user_snapshot for avatar
        if (avatarUrl == null && wsMessage.data!['user_snapshot'] != null) {
          final userSnapshot = wsMessage.data!['user_snapshot'];
          if (userSnapshot is Map) {
            final snapshotMap = userSnapshot is Map<String, dynamic>
                ? userSnapshot
                : <String, dynamic>{
                    ...userSnapshot
                        .map((key, value) => MapEntry(key.toString(), value))
                  };
            avatarUrl = snapshotMap['avatar']?.toString() ??
                snapshotMap['photo_url']?.toString();
          }
        }

        // Cache avatar if found (cache with userId from WebSocket)
        if (avatarUrl != null &&
            avatarUrl.isNotEmpty &&
            wsMessage.userId != null) {
          // Cache with WebSocket userId (could be UUID or numeric)
          _memberAvatarCache[wsMessage.userId!] = avatarUrl;
          log('✅ [ChatScreen] Cached avatar from WebSocket for ${wsMessage.userId}: $avatarUrl');

          // Also try to cache with snapshotUserId if available in data
          if (wsMessage.data != null) {
            try {
              final snapshotUserIdValue = wsMessage.data!['snapshot_user_id'];
              if (snapshotUserIdValue != null) {
                final snapshotUserId = snapshotUserIdValue is int
                    ? snapshotUserIdValue.toString()
                    : snapshotUserIdValue.toString();
                _memberAvatarCache[snapshotUserId] = avatarUrl;
                log('✅ [ChatScreen] Also cached avatar with snapshotUserId from WebSocket: $snapshotUserId');
              }
            } catch (e) {
              // Ignore errors
            }
          }
        }
      }

      // Extract sender name from WebSocket message data
      // user_name is now guaranteed to be present in API response
      // Check for non-empty strings, not just null
      String senderName;
      final userName = wsMessage.data?['user_name']?.toString();
      if (userName != null && userName.isNotEmpty) {
        senderName = userName;
      } else {
        final senderNameField = wsMessage.data?['sender_name']?.toString();
        if (senderNameField != null && senderNameField.isNotEmpty) {
          senderName = senderNameField;
        } else {
          senderName = widget.contact.name;
        }
      }

      // Reject UUID-like strings and "user_" prefixed UUIDs
      // Check for: UUID format (contains dashes and is long), or "user_" prefix followed by UUID
      final isUuidLike = senderName.contains('-') && senderName.length > 30;
      final isUserPrefixedUuid = senderName.startsWith('user_') &&
          senderName.length > 36 && // "user_" (5) + UUID (36) = 41
          senderName.substring(5).contains('-');

      if (isUuidLike || isUserPrefixedUuid) {
        log('⚠️ [ChatScreen] Rejected UUID-like senderName: $senderName, using contact name instead');
        senderName = widget.contact.name;
      }

      // Parse reactions from WebSocket message (if included)
      List<MessageReaction> reactions = [];
      try {
        if (wsMessage.data?['reactions'] != null &&
            wsMessage.data!['reactions'] is List) {
          reactions = (wsMessage.data!['reactions'] as List)
              .map((item) {
                try {
                  if (item is Map<String, dynamic>) {
                    return MessageReaction.fromJson(item);
                  }
                  return null;
                } catch (e) {
                  return null;
                }
              })
              .whereType<MessageReaction>()
              .toList();
        }
      } catch (e) {
        reactions = [];
      }

      // Extract message ID - CRITICAL: Must be UUID, not timestamp
      String messageId = wsMessage.data?['id'] as String? ?? '';
      // Validate message ID is UUID format (not timestamp)
      if (messageId.isEmpty) {
        log('⚠️ [ChatScreen] WebSocket message has no ID, skipping message');
        return; // Skip messages without ID - they can't be processed
      }

      // Check if message ID is valid UUID format
      final isUuidFormat = messageId.contains('-') && messageId.length > 30;
      if (!isUuidFormat && int.tryParse(messageId) != null) {
        // Numeric ID - log warning but process it (backend might accept it)
        log('⚠️ [ChatScreen] WebSocket message ID is numeric (not UUID): $messageId - reactions may fail');
      }

      // CRITICAL: If message ID is still empty or invalid, skip this message
      // Backend must provide valid UUID message ID for reactions to work
      if (messageId.isEmpty) {
        log('⚠️ [ChatScreen] WebSocket message has no ID, cannot process message');
        return; // Skip messages without ID
      }

      // Extract sender avatar from WebSocket if available (already extracted above)
      final senderAvatar = avatarUrl;

      log('📨 [ChatScreen] Processing WebSocket message: id=$messageId, senderId=${wsMessage.userId}, senderName=$senderName, hasAvatar=${senderAvatar != null}');

      // Extract message_type and event_type from WebSocket data
      final messageType = wsMessage.data?['message_type']?.toString();
      final eventType = wsMessage.data?['event_type']?.toString();

      // If content is empty but data includes file fields for audio/image/doc, synthesize minimal JSON content
      if ((content.isEmpty || content.trim().isEmpty) &&
          wsMessage.data != null) {
        final data = wsMessage.data!;
        final fileUrl = data['file_url']?.toString() ??
            data['fileUrl']?.toString() ??
            data['url']?.toString() ??
            data['audio_url']?.toString();
        final mimeType = data['mime_type']?.toString();
        final fileName = data['file_name']?.toString();
        final fileType = data['file_type']?.toString();
        final durationMs = data['duration_ms'];

        if (fileUrl != null && fileUrl.isNotEmpty) {
          final synthesized = <String, dynamic>{
            'file_url': fileUrl,
            if (mimeType != null) 'mime_type': mimeType,
            if (fileName != null) 'file_name': fileName,
            if (fileType != null) 'file_type': fileType,
            if (durationMs != null) 'duration_ms': durationMs,
          };
          content = jsonEncode(synthesized);
          log('🧩 [ChatScreen] Synthesized content from ws.data for missing body');
        }
      }

      bool _parseBool(dynamic value) {
        if (value is bool) return value;
        if (value is num) return value == 1;
        if (value is String) {
          final v = value.toLowerCase();
          return v == 'true' || v == '1';
        }
        return false;
      }

      bool _hasForwardMarker(Map<dynamic, dynamic>? map) {
        if (map == null || map.isEmpty) return false;
        final keys = map.keys.map((k) => k.toString().toLowerCase()).toSet();
        const forwardKeys = {
          'is_forwarded',
          'forwarded',
          'forward',
          'forwarded_from',
          'forwardedfrom',
          'forwarded_message_id',
          'forwarded_room_id',
          'original_room_id',
          'original_message_id',
          'forward_message_id',
        };
        if (keys.any(forwardKeys.contains)) return true;
        for (final entry in map.entries) {
          final value = entry.value;
          if (value is Map && _hasForwardMarker(value)) return true;
        }
        return false;
      }

      bool isForwarded = false;
      // Prefer explicit flags
      final forwardedRaw = wsMessage.data?['is_forwarded'] ??
          wsMessage.data?['forwarded'] ??
          wsMessage.data?['forward'];
      if (forwardedRaw != null) {
        isForwarded = _parseBool(forwardedRaw);
      }

      // Look for forward metadata in data map
      if (!isForwarded && wsMessage.data != null) {
        final dataMap = wsMessage.data!;
        if (_hasForwardMarker(dataMap)) {
          isForwarded = true;
        }
      }

      // Infer from messageType / type fields
      final lowerType = (messageType ?? wsMessage.type ?? '').toLowerCase();
      if (!isForwarded && lowerType.contains('forward')) {
        isForwarded = true;
      }

      final roomMessage = RoomMessage(
        id: messageId,
        roomId: _currentRoomId!,
        senderId: wsMessage.userId ?? '',
        senderName: senderName,
        senderAvatar:
            senderAvatar, // Include avatar from WebSocket (like group chat)
        body: content,
        createdAt: wsMessage.data?['created_at'] != null
            ? DateTime.parse(wsMessage.data!['created_at'] as String)
            : DateTime.now(),
        editedAt: wsMessage.data?['edited_at'] != null
            ? DateTime.parse(wsMessage.data!['edited_at'] as String)
            : null,
        updatedAt: wsMessage.data?['updated_at'] != null
            ? DateTime.parse(wsMessage.data!['updated_at'] as String)
            : null,
        isDeleted: isDeleted,
        deletedAt: wsMessage.data?['deleted_at'] != null
            ? DateTime.parse(wsMessage.data!['deleted_at'] as String)
            : null,
        deletedBy: wsMessage.data?['deleted_by']?.toString(),
        snapshotUserId: snapshotUserId,
        replyTo: replyToId,
        reactions: reactions, // Reactions included in WebSocket message
        messageType:
            messageType, // Include messageType for system message detection
        eventType: eventType, // Include eventType for system message detection
        isForwarded: isForwarded,
      );

      // FILTER: For 1-to-1 chats, filter out system messages like "joined the group"
      final isSystemMessage = _isSystemMessage(roomMessage);
      if (isSystemMessage) {
        log('🚫 [ChatScreen] Filtering out system message from WebSocket: ${roomMessage.body.substring(0, roomMessage.body.length > 50 ? 50 : roomMessage.body.length)}');
        return; // Skip system messages in 1-to-1 chats
      }

      final isFromCurrentUser = _isMessageFromCurrentUser(roomMessage);

      // Find the message being replied to if reply_to is present
      // CRITICAL: Check existing messages to find replied-to message
      // This ensures replies work even if the replied-to message was loaded earlier
      ChatMessage? replyToMessage;
      if (roomMessage.replyTo != null && roomMessage.replyTo!.isNotEmpty) {
        try {
          replyToMessage = _messages.firstWhere(
            (m) => m.id == roomMessage.replyTo,
          );
        } catch (e) {
          // Message not found in loaded messages
          // Create a minimal placeholder that preserves the reply relationship
          // but doesn't break the UI
          replyToMessage = ChatMessage(
            id: roomMessage.replyTo!,
            text: 'Original message', // Placeholder text that won't break UI
            isMe: false,
            timestamp: DateTime.now()
                .subtract(const Duration(hours: 1)), // Placeholder time
            isDeleted:
                false, // Don't mark as deleted - this preserves reply display
          );
          log('⚠️ [ChatScreen] Reply target message ${roomMessage.replyTo} not found in loaded messages (WebSocket). Using placeholder.');
        }
      }

      // Parse file URLs from JSON body if messageType is media/file
      String? imageUrl;
      String? documentUrl;
      String? documentName;
      String? documentType;
      bool isDocument = false;
      String? audioUrl;
      Duration? audioDuration;
      String? videoUrl;
      bool isVideo = false;

      log('🔍 [ChatScreen] WebSocket message parsing - messageType: $messageType, content length: ${content.length}');
      log('   Content preview: ${content.length > 100 ? content.substring(0, 100) : content}');

      if (messageType == 'image' ||
          messageType == 'file' ||
          messageType == 'voice' ||
          messageType == 'audio' ||
          messageType == 'video') {
        log('📎 [ChatScreen] Processing file message - messageType: $messageType');
        try {
          // Try to parse content as JSON
          final bodyJson = jsonDecode(content) as Map<String, dynamic>?;
          log('   Parsed JSON successfully: ${bodyJson != null}');

          if (bodyJson != null) {
            log('   JSON keys: ${bodyJson.keys.toList()}');

            if (messageType == 'image') {
              imageUrl = bodyJson['file_url']?.toString();
              log('   Extracted imageUrl: ${imageUrl != null ? (imageUrl!.length > 50 ? imageUrl!.substring(0, 50) + "..." : imageUrl) : "null"}');

              // Also try alternative field names
              if (imageUrl == null || imageUrl.isEmpty) {
                imageUrl = bodyJson['image_url']?.toString() ??
                    bodyJson['url']?.toString() ??
                    bodyJson['imageUrl']?.toString();
                log('   Tried alternative fields, imageUrl: ${imageUrl != null ? "found" : "still null"}');
              }

              // Transform localhost URLs to proper server URLs
              if (imageUrl != null && imageUrl.isNotEmpty) {
                final transformedUrl =
                    RoomService.transformLocalhostUrl(imageUrl);
                if (transformedUrl != imageUrl) {
                  log('🔄 [ChatScreen] Transformed imageUrl from localhost: $imageUrl -> $transformedUrl');
                  imageUrl = transformedUrl;
                }
              }
            } else if (messageType == 'file') {
              documentUrl = bodyJson['file_url']?.toString();
              // Additional fallbacks (camelCase / generic)
              documentUrl ??= bodyJson['fileUrl']?.toString();
              documentUrl ??= bodyJson['documentUrl']?.toString();
              documentName = bodyJson['file_name']?.toString();
              documentType = bodyJson['file_type']?.toString();

              // Helper to check if file is a video by extension
              bool isVideoFile(String? url, String? fileName) {
                if (url == null && fileName == null) return false;
                final checkString = (fileName ?? url ?? '').toLowerCase();
                return checkString.endsWith('.mp4') ||
                    checkString.endsWith('.mov') ||
                    checkString.endsWith('.avi') ||
                    checkString.endsWith('.mkv') ||
                    checkString.endsWith('.webm') ||
                    checkString.endsWith('.m4v') ||
                    checkString.endsWith('.3gp');
              }

              // Helper to check if file is an audio by extension
              bool isAudioFile(String? url, String? fileName) {
                if (url == null && fileName == null) return false;
                final checkString = (fileName ?? url ?? '').toLowerCase();
                return checkString.endsWith('.mp3') ||
                    checkString.endsWith('.m4a') ||
                    checkString.endsWith('.aac') ||
                    checkString.endsWith('.wav') ||
                    checkString.endsWith('.ogg') ||
                    checkString.endsWith('.flac');
              }

              // If mime indicates audio/video, treat accordingly instead of document
              final mimeType = bodyJson['mime_type']?.toString();
              final isVideoByMime = mimeType != null &&
                  mimeType.toLowerCase().startsWith('video');
              final isVideoByExtension = isVideoFile(documentUrl, documentName);
              final isAudioByMime = mimeType != null &&
                  mimeType.toLowerCase().startsWith('audio');
              final isAudioByExtension = isAudioFile(documentUrl, documentName);

              if (isAudioByMime || isAudioByExtension) {
                audioUrl = documentUrl;
                // Fallback to plain url if file_url missing
                audioUrl ??= bodyJson['url']?.toString();
                audioUrl ??= bodyJson['fileUrl']?.toString();
                audioUrl ??= bodyJson['audio_url']?.toString();
                final durationMs = bodyJson['duration_ms'];
                if (durationMs is int) {
                  audioDuration = Duration(milliseconds: durationMs);
                } else if (durationMs is String) {
                  final parsed = int.tryParse(durationMs);
                  if (parsed != null) {
                    audioDuration = Duration(milliseconds: parsed);
                  }
                }
                isDocument = false;
                isVideo = false;
                videoUrl = null;
                if (audioUrl != null && audioUrl!.isNotEmpty) {
                  audioUrl = RoomService.transformLocalhostUrl(audioUrl!);
                }
              } else if (isVideoByMime || isVideoByExtension) {
                videoUrl = documentUrl;
                videoUrl ??= bodyJson['url']?.toString();
                videoUrl ??= bodyJson['fileUrl']?.toString();
                videoUrl ??= bodyJson['video_url']?.toString();
                isVideo = videoUrl != null && videoUrl!.isNotEmpty;
                isDocument = false;
                audioUrl = null;
                if (videoUrl != null && videoUrl!.isNotEmpty) {
                  videoUrl = RoomService.transformLocalhostUrl(videoUrl!);
                }
              } else {
                // Only set as document if it's not video or audio
                isDocument = documentUrl != null && documentUrl.isNotEmpty;
              }

              log('   Extracted documentUrl: ${documentUrl != null ? (documentUrl!.length > 50 ? documentUrl!.substring(0, 50) + "..." : documentUrl) : "null"}');
              log('   Extracted documentName: $documentName');
              log('   Extracted documentType: $documentType');

              // Also try alternative field names
              if (documentUrl == null || documentUrl.isEmpty) {
                documentUrl = bodyJson['document_url']?.toString() ??
                    bodyJson['url']?.toString() ??
                    bodyJson['documentUrl']?.toString();
                log('   Tried alternative fields, documentUrl: ${documentUrl != null ? "found" : "still null"}');
              }

              // Transform localhost URLs to proper server URLs
              if (documentUrl != null && documentUrl.isNotEmpty) {
                final transformedUrl =
                    RoomService.transformLocalhostUrl(documentUrl);
                if (transformedUrl != documentUrl) {
                  log('🔄 [ChatScreen] Transformed documentUrl from localhost: $documentUrl -> $transformedUrl');
                  documentUrl = transformedUrl;
                }
              }
            } else if (messageType == 'voice' || messageType == 'audio') {
              audioUrl = bodyJson['file_url']?.toString();
              // Fallbacks used by some payloads
              audioUrl ??= bodyJson['url']?.toString();
              audioUrl ??= bodyJson['audio_url']?.toString();
              audioUrl ??= bodyJson['fileUrl']?.toString();

              final durationMs = bodyJson['duration_ms'];
              if (durationMs is int) {
                audioDuration = Duration(milliseconds: durationMs);
              } else if (durationMs is String) {
                final parsed = int.tryParse(durationMs);
                if (parsed != null) {
                  audioDuration = Duration(milliseconds: parsed);
                }
              }

              if (audioUrl != null && audioUrl!.isNotEmpty) {
                final transformedUrl =
                    RoomService.transformLocalhostUrl(audioUrl!);
                if (transformedUrl != audioUrl) {
                  log('🔄 [ChatScreen] Transformed audioUrl from localhost: $audioUrl -> $transformedUrl');
                  audioUrl = transformedUrl;
                }
              }
            } else if (messageType == 'video') {
              videoUrl = bodyJson['file_url']?.toString() ??
                  bodyJson['url']?.toString() ??
                  bodyJson['video_url']?.toString();
              isVideo = videoUrl != null && videoUrl!.isNotEmpty;
              if (videoUrl != null && videoUrl!.isNotEmpty) {
                final transformedUrl =
                    RoomService.transformLocalhostUrl(videoUrl!);
                if (transformedUrl != videoUrl) {
                  log('🔄 [ChatScreen] Transformed videoUrl from localhost: $videoUrl -> $transformedUrl');
                  videoUrl = transformedUrl;
                }
              }
            }
          } else {
            log('⚠️ [ChatScreen] bodyJson is null after parsing');
          }
        } catch (e, stackTrace) {
          // Body is not JSON, treat as regular text message
          log('❌ [ChatScreen] Failed to parse WebSocket content as JSON for message $messageId: $e');
          log('   Stack trace: $stackTrace');
          log('   Content that failed to parse: ${content.length > 200 ? content.substring(0, 200) + "..." : content}');

          // Try to extract URL from content even if it's not valid JSON
          // Sometimes the content might be a plain URL or malformed JSON
          if (content.trim().startsWith('http://') ||
              content.trim().startsWith('https://')) {
            log('   Content appears to be a direct URL, using it as file_url');
            if (messageType == 'image') {
              imageUrl = content.trim();
              // Transform localhost URLs
              if (imageUrl != null && imageUrl.isNotEmpty) {
                imageUrl = RoomService.transformLocalhostUrl(imageUrl);
              }
            } else if (messageType == 'file') {
              documentUrl = content.trim();
              // Transform localhost URLs
              if (documentUrl != null && documentUrl.isNotEmpty) {
                documentUrl = RoomService.transformLocalhostUrl(documentUrl);
              }
              isDocument = true;
            } else if (messageType == 'voice' || messageType == 'audio') {
              audioUrl = RoomService.transformLocalhostUrl(content.trim());
            }
          }
        }

        // FINAL FALLBACK: if still no audioUrl and messageType is audio/voice, try pulling from WebSocket data directly
        if ((messageType == 'voice' || messageType == 'audio') &&
            (audioUrl == null || audioUrl!.isEmpty) &&
            wsMessage.data != null) {
          audioUrl = wsMessage.data!['file_url']?.toString() ??
              wsMessage.data!['fileUrl']?.toString() ??
              wsMessage.data!['url']?.toString() ??
              wsMessage.data!['audio_url']?.toString();

          final durationMs = wsMessage.data!['duration_ms'];
          if (durationMs is int) {
            audioDuration = Duration(milliseconds: durationMs);
          } else if (durationMs is String) {
            final parsed = int.tryParse(durationMs);
            if (parsed != null) {
              audioDuration = Duration(milliseconds: parsed);
            }
          }

          if (audioUrl != null && audioUrl!.isNotEmpty) {
            audioUrl = RoomService.transformLocalhostUrl(audioUrl!);
            log('✅ [ChatScreen] Fallback audioUrl extracted from ws.data');
          }
        }
      } else {
        log('ℹ️ [ChatScreen] Not a file message - messageType: $messageType');
      }

      log('✅ [ChatScreen] Final extracted URLs - imageUrl: ${imageUrl != null ? "present" : "null"}, documentUrl: ${documentUrl != null ? "present" : "null"}, audioUrl: ${audioUrl != null ? "present" : "null"}, videoUrl: ${videoUrl != null ? "present" : "null"}');

      // Determine text to display - hide JSON if we have file URLs
      String displayText = roomMessage.isDeleted ? '' : roomMessage.body;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Hide JSON text for images - show empty or placeholder
        displayText = '';
      } else if (documentUrl != null && documentUrl.isNotEmpty) {
        // For documents, show file name if available, otherwise hide JSON
        displayText = documentName ?? '📎 Document';
      } else if (audioUrl != null && audioUrl.isNotEmpty) {
        displayText = '🎤 Voice note';
      } else if (videoUrl != null && videoUrl.isNotEmpty) {
        displayText = '🎥 Video';
      } else if ((messageType == 'voice' || messageType == 'audio') &&
          (displayText.isEmpty || displayText.trim().isEmpty)) {
        // Ensure audio messages always show a label even if URL missing
        displayText = '🎤 Voice note';
      } else if ((messageType == 'image' ||
              messageType == 'file' ||
              messageType == 'voice' ||
              messageType == 'audio' ||
              messageType == 'video') &&
          roomMessage.body.trim().startsWith('{') &&
          roomMessage.body.trim().endsWith('}')) {
        // If body looks like JSON but we couldn't parse it, hide it
        try {
          jsonDecode(roomMessage.body);
          displayText = ''; // Hide JSON
        } catch (e) {
          // Not JSON, keep original text
        }
      }

      final chatMessage = ChatMessage(
        id: roomMessage.id,
        text: displayText,
        isMe: isFromCurrentUser,
        timestamp: roomMessage.createdAt,
        editedAt: roomMessage.editedAt,
        isDeleted: roomMessage.isDeleted,
        status: isFromCurrentUser
            ? MessageStatus.delivered // Show delivered for current user
            : MessageStatus.seen, // Show seen for receiver
        isOnline: widget.contact.status == IntercomContactStatus.online,
        reactions: roomMessage.reactions, // Reactions included in API response
        replyTo: replyToMessage,
        imageUrl: imageUrl,
        documentUrl: documentUrl,
        isAudio: audioUrl != null && audioUrl.isNotEmpty,
        audioUrl: audioUrl,
        audioDuration: audioDuration,
        isVideo: videoUrl != null && videoUrl.isNotEmpty,
        videoUrl: videoUrl,
        // CRITICAL: Never mark as document if it's a video
        isDocument: isDocument && !(videoUrl != null && videoUrl.isNotEmpty),
        documentName: documentName,
        documentType: documentType,
        isForwarded: roomMessage.isForwarded,
      );

      // CRITICAL: Log the final message state to debug rendering issues
      log('📝 [ChatScreen] Created ChatMessage: id=${chatMessage.id}, imageUrl=${chatMessage.imageUrl != null ? "present (${chatMessage.imageUrl!.length} chars)" : "null"}, documentUrl=${chatMessage.documentUrl != null ? "present (${chatMessage.documentUrl!.length} chars)" : "null"}, isDocument=${chatMessage.isDocument}');

      // Check if message already exists (prevent duplicates)
      // CRITICAL: Match by ID, or by content/file URL for current user's optimistic messages
      // This prevents duplicate messages when WebSocket returns server-generated ID

      // Extract file URL from WebSocket message body for matching
      String? wsFileUrl;
      if (messageType == 'image' || messageType == 'file') {
        try {
          final bodyJson = jsonDecode(content) as Map<String, dynamic>?;
          if (bodyJson != null) {
            wsFileUrl = bodyJson['file_url']?.toString();
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }

      final existingIndex = _messages.indexWhere((m) {
        // Exact ID match
        if (m.id == chatMessage.id) {
          log('✅ [ChatScreen] Exact ID match: ${chatMessage.id}');
          return true;
        }

        // CRITICAL FIX: Only match optimistic messages from current user
        // Don't try to deduplicate messages from other users
        if (!chatMessage.isMe || !m.isMe) {
          return false;
        }

        // Only match messages with "sending" or "sent" status (optimistic messages)
        if (m.status != MessageStatus.sending &&
            m.status != MessageStatus.sent) {
          return false;
        }

        // CRITICAL FIX: Tightened timestamp window from 10s to 3s
        // This prevents matching unrelated messages sent close together
        final timeDiff =
            m.timestamp.difference(chatMessage.timestamp).inSeconds.abs();
        if (timeDiff > 3) {
          return false; // Too far apart in time
        }

        log('🔍 [ChatScreen] Potential match - timeDiff: ${timeDiff}s, checking content...');

        // Match by file URLs (most reliable for media messages)
        if (chatMessage.imageUrl != null && chatMessage.imageUrl!.isNotEmpty) {
          if (m.imageUrl == chatMessage.imageUrl) {
            log('✅ [ChatScreen] Matched by imageUrl: ${chatMessage.imageUrl}');
            return true;
          }
        }

        if (chatMessage.documentUrl != null &&
            chatMessage.documentUrl!.isNotEmpty) {
          if (m.documentUrl == chatMessage.documentUrl) {
            log('✅ [ChatScreen] Matched by documentUrl: ${chatMessage.documentUrl}');
            return true;
          }
        }

        if (chatMessage.audioUrl != null && chatMessage.audioUrl!.isNotEmpty) {
          if (m.audioUrl == chatMessage.audioUrl) {
            log('✅ [ChatScreen] Matched by audioUrl: ${chatMessage.audioUrl}');
            return true;
          }
        }

        if (chatMessage.videoUrl != null && chatMessage.videoUrl!.isNotEmpty) {
          if (m.videoUrl == chatMessage.videoUrl) {
            log('✅ [ChatScreen] Matched by videoUrl: ${chatMessage.videoUrl}');
            return true;
          }
        }

        // Match by text content (for text messages)
        if (chatMessage.text.isNotEmpty && m.text.isNotEmpty) {
          if (chatMessage.text.trim() == m.text.trim()) {
            log('✅ [ChatScreen] Matched by text content: "${chatMessage.text}"');
            return true;
          }
        }

        // CRITICAL FIX: Handle empty text messages (voice notes, files without caption)
        // If both have empty text and same timestamp (within 2s), likely same message
        if (chatMessage.text.isEmpty && m.text.isEmpty && timeDiff <= 2) {
          log('✅ [ChatScreen] Matched by empty text + close timestamp (${timeDiff}s)');
          return true;
        }

        // Handle forwarded messages
        if (m.isForwarded && m.id.startsWith('temp_forward_')) {
          bool mediaMatch = false;
          if (chatMessage.imageUrl != null &&
              chatMessage.imageUrl!.isNotEmpty &&
              chatMessage.imageUrl == m.imageUrl) {
            mediaMatch = true;
          }
          if (chatMessage.documentUrl != null &&
              chatMessage.documentUrl!.isNotEmpty &&
              chatMessage.documentUrl == m.documentUrl) {
            mediaMatch = true;
          }
          if (chatMessage.audioUrl != null &&
              chatMessage.audioUrl!.isNotEmpty &&
              chatMessage.audioUrl == m.audioUrl) {
            mediaMatch = true;
          }
          if (chatMessage.videoUrl != null &&
              chatMessage.videoUrl!.isNotEmpty &&
              chatMessage.videoUrl == m.videoUrl) {
            mediaMatch = true;
          }
          if (mediaMatch ||
              (chatMessage.text.isNotEmpty && chatMessage.text == m.text)) {
            log('✅ [ChatScreen] Matched forwarded placeholder');
            return true;
          }
        }

        // No match found
        log('❌ [ChatScreen] No match found for message (timeDiff: ${timeDiff}s)');
        return false;
      });

      if (existingIndex == -1) {
        // New message - add it
        if (mounted) {
          setState(() {
            // Insert message in correct chronological order
            final insertIndex = _messages
                .indexWhere((m) => m.timestamp.isAfter(chatMessage.timestamp));
            if (insertIndex == -1) {
              _messages.add(chatMessage);
            } else {
              _messages.insert(insertIndex, chatMessage);
            }
          });

          // Auto-scroll only if user is at bottom
          if (_isAtBottom) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }

          // CRITICAL FIX: Auto-mark messages from other users as read
          // This triggers read receipt updates via WebSocket
          if (!chatMessage.isMe && _currentRoomId != null) {
            // Mark as read after a short delay (user has seen it)
            Future.delayed(const Duration(milliseconds: 500), () async {
              if (!mounted) return;
              try {
                await _chatService.markMessageAsRead(chatMessage.id);
                log('📖 [ChatScreen] Auto-marked message as read: ${chatMessage.id}');
              } catch (e) {
                log('⚠️ [ChatScreen] Failed to auto-mark message as read: $e');
              }
            });
          }
        }
      } else {
        // Message exists - update it with real data from server
        // This replaces optimistic message with persisted message
        if (mounted) {
          final existingMessage = _messages[existingIndex];
          final wasFromCurrentUser = existingMessage.isMe;

          // For edited messages from current user, set to delivered immediately
          final isEditedMessage = chatMessage.editedAt != null;
          final initialStatus = (wasFromCurrentUser && isEditedMessage)
              ? MessageStatus.delivered
              : (wasFromCurrentUser ? MessageStatus.sent : MessageStatus.seen);

          setState(() {
            _messages[existingIndex] = chatMessage.copyWith(
              status: initialStatus,
              replyTo: existingMessage.replyTo ?? chatMessage.replyTo,
              linkPreview:
                  existingMessage.linkPreview ?? chatMessage.linkPreview,
              // CRITICAL: Use server's imageUrl/documentUrl if available, otherwise preserve from optimistic
              // This ensures file URLs are always present when loading from API
              imageUrl: chatMessage.imageUrl?.isNotEmpty == true
                  ? chatMessage.imageUrl
                  : existingMessage.imageUrl,
              documentUrl: chatMessage.documentUrl?.isNotEmpty == true
                  ? chatMessage.documentUrl
                  : existingMessage.documentUrl,
              audioUrl: chatMessage.audioUrl?.isNotEmpty == true
                  ? chatMessage.audioUrl
                  : existingMessage.audioUrl,
              audioDuration:
                  chatMessage.audioDuration ?? existingMessage.audioDuration,
              isAudio: chatMessage.isAudio || existingMessage.isAudio,
              videoUrl: chatMessage.videoUrl?.isNotEmpty == true
                  ? chatMessage.videoUrl
                  : existingMessage.videoUrl,
              isVideo: chatMessage.isVideo || existingMessage.isVideo,
            );
          });

          // Progress status to delivered after a short delay (only for non-edited messages)
          if (!isEditedMessage && chatMessage.isMe) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                final index =
                    _messages.indexWhere((m) => m.id == chatMessage.id);
                if (index != -1) {
                  setState(() {
                    _messages[index] = _messages[index].copyWith(
                      status: MessageStatus.delivered, // Single check (grey)
                    );
                  });

                  // Progress to seen after another delay (simulated read receipt)
                  // In real implementation, this should be based on actual read receipt from backend
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) {
                      final seenIndex =
                          _messages.indexWhere((m) => m.id == chatMessage.id);
                      if (seenIndex != -1) {
                        log('✅ [ChatScreen] Updating message status to SEEN (green double check icon): ${chatMessage.id}');
                        setState(() {
                          _messages[seenIndex] = _messages[seenIndex].copyWith(
                            status: MessageStatus
                                .seen, // Green double check icon (read by receiver)
                          );
                        });
                      }
                    }
                  });
                }
              }
            });
          }
        }
      }
    }
  }

  /// Load older messages for pagination (like group chat)
  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _currentRoomId == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Get company_id for API call
      final companyId = await _apiService.getSelectedSocietyId();
      if (companyId == null) {
        setState(() {
          _isLoadingMore = false;
        });
        return;
      }

      // Load next page using ChatService (like group chat)
      final response = await _chatService.fetchMessages(
        roomId: _currentRoomId!,
        companyId: companyId,
        limit: _messagesPerPage,
        offset: _currentOffset,
      );

      if (!mounted) return;

      if (response.success) {
        final roomMessages = response.data ?? <RoomMessage>[];

        if (roomMessages.isEmpty) {
          // No more messages
          setState(() {
            _hasMoreMessages = false;
            _isLoadingMore = false;
          });
          log('📥 [ChatScreen] No more older messages to load');
          return;
        }

        log('📥 [ChatScreen] Loaded ${roomMessages.length} older messages (offset: $_currentOffset)');

        // Cache the messages for future use
        if (roomMessages.isNotEmpty) {
          final messageCache = MessageCache();
          messageCache.cacheMessages(
            _currentRoomId!,
            companyId,
            _currentOffset,
            _messagesPerPage,
            roomMessages,
          );
        }

        // Convert RoomMessage to ChatMessage
        // First pass: create all messages without replyTo (reactions are included from API)
        final newChatMessagesWithoutReply = roomMessages.map((rm) {
          final isFromCurrentUser = _isMessageFromCurrentUser(rm);
          return ChatMessage(
            id: rm.id,
            text: rm.isDeleted ? '' : rm.body,
            isMe: isFromCurrentUser,
            timestamp: rm.createdAt,
            editedAt: rm.editedAt,
            isDeleted: rm.isDeleted,
            status: isFromCurrentUser
                ? MessageStatus.delivered
                : MessageStatus.seen,
            isOnline: widget.contact.status == IntercomContactStatus.online,
            reactions:
                rm.reactions, // Reactions are included in the API response
            isForwarded: rm.isForwarded,
          );
        }).toList();

        // Second pass: resolve replyTo references (check both existing and new messages)
        final allMessagesForLookup = [
          ..._messages,
          ...newChatMessagesWithoutReply
        ];
        final newChatMessages = newChatMessagesWithoutReply.map((cm) {
          final roomMessage = roomMessages.firstWhere((rm) => rm.id == cm.id);
          if (roomMessage.replyTo != null && roomMessage.replyTo!.isNotEmpty) {
            // First, try to find in already loaded messages (includes existing messages and new ones)
            ChatMessage? repliedToMessage;
            try {
              repliedToMessage = allMessagesForLookup.firstWhere(
                (m) => m.id == roomMessage.replyTo,
              );
            } catch (e) {
              // Message not found in loaded messages
              // Create a minimal placeholder that preserves the reply relationship
              // but doesn't break the UI
              repliedToMessage = ChatMessage(
                id: roomMessage.replyTo!,
                text:
                    'Original message', // Placeholder text that won't break UI
                isMe: false,
                timestamp: DateTime.now()
                    .subtract(const Duration(hours: 1)), // Placeholder time
                isDeleted:
                    false, // Don't mark as deleted - this preserves reply display
              );
              log('⚠️ [ChatScreen] Reply target message ${roomMessage.replyTo} not found in loaded messages (pagination). Using placeholder.');
            }
            return cm.copyWith(replyTo: repliedToMessage);
          }
          return cm;
        }).toList();

        // Check if there are more messages
        _hasMoreMessages = roomMessages.length >= _messagesPerPage;

        // Get current scroll position to maintain it after inserting older messages
        final currentScrollPosition = _scrollController.hasClients
            ? _scrollController.position.pixels
            : 0.0;
        final maxScrollExtent = _scrollController.hasClients
            ? _scrollController.position.maxScrollExtent
            : 0.0;

        // Insert older messages at the beginning (like group chat)
        setState(() {
          _messages.insertAll(0, newChatMessages);
          _isLoadingMore = false;
          _currentOffset += newChatMessages.length;
        });

        log('✅ [ChatScreen] Inserted ${newChatMessages.length} older messages at beginning. Total: ${_messages.length}');

        // Maintain scroll position after inserting older messages (like group chat)
        if (_scrollController.hasClients) {
          final newMaxScrollExtent = _scrollController.position.maxScrollExtent;
          final scrollDifference = newMaxScrollExtent - maxScrollExtent;
          _scrollController.jumpTo(currentScrollPosition + scrollDifference);
        }
      } else {
        setState(() {
          _isLoadingMore = false;
        });
        log('❌ [ChatScreen] Failed to load older messages: ${response.error}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      log('❌ [ChatScreen] Error loading older messages: $e');
    }
  }

  /// Fetch replied-to message from older messages (matches group chat behavior)
  /// This ensures reply previews are populated even when the replied-to message is in an older batch
  Future<void> _fetchRepliedToMessage(
      String replyToId, String replyMessageId) async {
    try {
      log('🔄 [ChatScreen] Fetching replied-to message: $replyToId for reply: $replyMessageId');

      final companyId = await _apiService.getSelectedSocietyId();
      if (companyId == null) {
        log('⚠️ [ChatScreen] Cannot fetch replied-to message: company_id not available');
        return;
      }

      if (_currentRoomId == null || !_isUuid(_currentRoomId)) {
        log('⚠️ [ChatScreen] Cannot fetch replied-to message: room_id not available');
        return;
      }

      // PERFORMANCE OPTIMIZATION: Check cache first before making API calls
      final messageCache = MessageCache();

      // Try to find the message by loading more messages with a wider offset range
      // Load messages in batches to find the replied-to message
      // CRITICAL: Also check offset 0 (initial batch) in case it wasn't found during initial load
      // This handles cases where the message might have been missed due to UUID/numeric ID mismatch
      for (int offset = 0;
          offset < _messagesPerPage * 5;
          offset += _messagesPerPage) {
        // Check cache first
        final cachedMessages = messageCache.getCachedMessages(
          _currentRoomId!,
          companyId,
          offset,
          _messagesPerPage,
        );

        List<RoomMessage> roomMessages;
        if (cachedMessages != null) {
          // Use cached messages
          log('✅ [ChatScreen] Using cached messages for replied-to search (offset: $offset)');
          roomMessages = cachedMessages;
        } else {
          // No cache - fetch from API
          final response = await _chatService.fetchMessages(
            roomId: _currentRoomId!,
            companyId: companyId,
            limit: _messagesPerPage,
            offset: offset,
          );

          if (!mounted) return;

          if (!response.success || response.data == null) {
            continue; // Skip this batch
          }

          roomMessages = response.data!;

          // Cache the messages for future use
          if (roomMessages.isNotEmpty) {
            messageCache.cacheMessages(
              _currentRoomId!,
              companyId,
              offset,
              _messagesPerPage,
              roomMessages,
            );
          }
        }

        if (!mounted) return;

        // Check if the replied-to message is in this batch
        if (roomMessages.isNotEmpty) {
          // CRITICAL: Use UUID/numeric compatibility for matching
          try {
            final normalizedReplyToId = replyToId.trim().toLowerCase();
            final repliedToRoomMessage = roomMessages.firstWhere(
              (rm) {
                final normalizedRmId = rm.id.trim().toLowerCase();
                return normalizedRmId == normalizedReplyToId ||
                    rm.id == replyToId;
              },
            );

            // Found it! Convert and update the reply
            final isFromCurrentUser =
                _isMessageFromCurrentUser(repliedToRoomMessage);
            final repliedToChatMessage = ChatMessage(
              id: repliedToRoomMessage.id,
              text: repliedToRoomMessage.isDeleted
                  ? ''
                  : repliedToRoomMessage.body,
              isMe: isFromCurrentUser,
              timestamp: repliedToRoomMessage.createdAt,
              editedAt: repliedToRoomMessage.editedAt,
              isDeleted: repliedToRoomMessage.isDeleted,
              status: MessageStatus.delivered,
              reactions: repliedToRoomMessage.reactions,
            );

            // Update the reply message with the found replied-to message
            // CRITICAL: Also ensure the replied-to message is in the message list
            if (mounted) {
              setState(() {
                final replyIndex =
                    _messages.indexWhere((m) => m.id == replyMessageId);
                if (replyIndex != -1) {
                  _messages[replyIndex] = _messages[replyIndex].copyWith(
                    replyTo: repliedToChatMessage,
                  );
                  log('✅ [ChatScreen] Updated reply message ${replyMessageId} with found replied-to message: ${repliedToChatMessage.id}');
                }

                // CRITICAL: Ensure the replied-to message is also in the message list
                // This ensures it's visible when re-entering the chat
                final repliedToIndex = _messages
                    .indexWhere((m) => m.id == repliedToChatMessage.id);
                if (repliedToIndex == -1) {
                  // Insert the replied-to message in chronological order
                  int insertIndex = _messages.length;
                  for (int i = 0; i < _messages.length; i++) {
                    if (_messages[i]
                        .timestamp
                        .isAfter(repliedToChatMessage.timestamp)) {
                      insertIndex = i;
                      break;
                    }
                  }
                  _messages.insert(insertIndex, repliedToChatMessage);
                  log('✅ [ChatScreen] Added replied-to message to message list: ${repliedToChatMessage.id} at index $insertIndex');
                } else {
                  log('✅ [ChatScreen] Replied-to message already in list: ${repliedToChatMessage.id}');
                }
              });
            }

            return; // Found, exit
          } catch (e) {
            // Not in this batch, continue searching
            continue;
          }
        } else {
          // No more messages or error
          break;
        }
      }

      log('⚠️ [ChatScreen] Could not find replied-to message $replyToId in older messages');
    } catch (e) {
      log('❌ [ChatScreen] Error fetching replied-to message: $e');
    }
  }

  /// Hide global loader dialog if shown
  void _hideLoaderDialog() {
    if (_isLoaderDialogShown && mounted) {
      _isLoaderDialogShown = false;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  /// Handle message loading errors
  void _handleMessageError(int? statusCode, String? errorMessage) {
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = errorMessage ?? 'Failed to load messages';
    });
    _hideLoaderDialog();

    if (statusCode == 401) {
      EnhancedToast.error(
        context,
        title: 'Authentication Error',
        message: 'Your session has expired. Please login again.',
      );
    } else if (statusCode == 403) {
      EnhancedToast.error(
        context,
        title: 'Access Denied',
        message: 'You are not authorized to access this chat',
      );
    } else if (statusCode == 404) {
      EnhancedToast.error(
        context,
        title: 'Chat Not Found',
        message: 'This chat does not exist',
      );
    } else if (statusCode == 429) {
      // Rate limit error - too many requests
      _rateLimitRetryCount++;
      final backoffSeconds = _calculateBackoffSeconds(_rateLimitRetryCount);

      setState(() {
        _errorMessage = 'Too many requests. Please try again later.';
      });

      EnhancedToast.error(
        context,
        title: 'Error',
        message:
            'Too many requests. Please wait ${backoffSeconds}s before retrying.',
      );

      log('⚠️ [ChatScreen] Rate limit error (429). Retry count: $_rateLimitRetryCount, Backoff: ${backoffSeconds}s');

      // Auto-retry after backoff period
      Future.delayed(Duration(seconds: backoffSeconds), () {
        if (mounted && _hasError && !_isOpeningRoom) {
          log('🔄 [ChatScreen] Auto-retrying after rate limit backoff...');
          _openRoom();
        }
      });
    } else if (statusCode == 500) {
      EnhancedToast.error(
        context,
        title: 'Server Error',
        message: 'Unable to load messages. Please try again.',
      );
    } else if (statusCode == 0) {
      EnhancedToast.error(
        context,
        title: 'Network Error',
        message: 'Unable to connect. Please check your internet connection.',
      );
    } else {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: errorMessage ?? 'Failed to load messages',
      );
    }
  }

  /// Calculate exponential backoff seconds for rate limit retries
  int _calculateBackoffSeconds(int retryCount) {
    // Exponential backoff: 5s, 10s, 20s, 30s (max)
    if (retryCount == 1) return 5;
    if (retryCount == 2) return 10;
    if (retryCount == 3) return 20;
    return 30; // Max 30 seconds
  }

  void _initializeNotifications() {
    // This would integrate with your notification service
    // For now, it's a placeholder for future implementation
    // You can integrate with flutter_local_notifications here
  }

  void _generateWaveformData() {
    _waveformData = List.generate(20, (index) {
      return math.Random().nextDouble() * 0.5 + 0.3;
    });
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _messageSyncTimer?.cancel();
    _waveformController.dispose();
    _typingTimer?.cancel();
    _typingIndicatorTimer?.cancel();
    _recordingTimer?.cancel();
    _wsMessageSubscription?.cancel();
    _wsConnectionSubscription?.cancel();
    _audioStateSubscription?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // Clear typing state on dispose (screen is closing)
    _isTyping = false;
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleEmojiPanel() {
    final shouldShow = !_showEmojiPicker;
    setState(() {
      _showEmojiPicker = shouldShow;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
    if (shouldShow) {
      _messageFocusNode.unfocus();
    } else {
      FocusScope.of(context).requestFocus(_messageFocusNode);
    }
  }

  void _dismissEmojiAndKeyboard() {
    if (_showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
    }
    if (_messageFocusNode.hasFocus) {
      _messageFocusNode.unfocus();
    }
  }

  /// Send message via WebSocket
  ///
  /// Message is automatically persisted by backend
  /// Sender receives their own message via WebSocket (source of truth)
  /// Do NOT re-append from REST after sending
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text.trim();

    // Clear input immediately for better UX
    _messageController.clear();
    final replyTo = _replyingTo;
    _replyingTo = null;

    // Detect URL and create link preview
    LinkPreview? linkPreview;
    if (_urlRegex.hasMatch(text)) {
      final url = _urlRegex.firstMatch(text)!.group(0)!;
      linkPreview = LinkPreview(url: url);
    }

    // Optimistic UI: Add message immediately with "sending" status
    // This will be replaced by the actual message from WebSocket
    final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimisticMessage = ChatMessage(
      id: tempMessageId,
      text: text,
      isMe: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      replyTo: replyTo,
      linkPreview: linkPreview,
    );

    setState(() {
      _messages.add(optimisticMessage);
    });

    _scrollToBottom();

    // Send via WebSocket
    // Match group chat pattern: Always use UUID room_id (like group chat uses widget.group.id)
    // If _currentRoomId is not available, try to create room first
    if (_currentRoomId == null || !_isUuid(_currentRoomId)) {
      log('⚠️ [ChatScreen] No valid UUID room_id available - creating room now');

      // Try to create room if we have numeric or UUID contact ID
      if (_isNumeric(widget.contact.id) || _isUuid(widget.contact.id)) {
        try {
          final companyId = await _apiService.getSelectedSocietyId();
          if (companyId == null) {
            log('❌ [ChatScreen] Company ID not available');
            if (mounted) {
              setState(() {
                _messages.removeWhere((m) => m.id == tempMessageId);
              });
              EnhancedToast.error(
                context,
                title: 'Error',
                message: 'Please select a society first',
              );
            }
            return;
          }

          log('🔨 [ChatScreen] Creating 1-to-1 room before sending message...');
          final createResponse = await RoomService.instance.createOneToOneRoom(
            contactName: widget.contact.name,
            contactId: widget.contact.id,
            companyId: companyId,
            contactPhone: widget.contact.phoneNumber,
          );

          if (createResponse.success && createResponse.data != null) {
            final newRoomId = createResponse.data!;
            log('✅ [ChatScreen] Room created successfully: $newRoomId');

            // Set room_id and connect WebSocket
            _currentRoomId = newRoomId;

            // CRITICAL: Check membership first before connecting with UUID
            log('🔌 [ChatScreen] Validating membership first before connecting WebSocket with UUID: $_currentRoomId');
            await _chatService.openRoom(
              roomId: _currentRoomId!,
              isMember:
                  false, // Always validate membership first - backend handles deduplication
              companyId: companyId,
              limit: 0, // Don't fetch messages, just connect WebSocket
              offset: 0,
              allowNewRoom: false,
            );

            log('✅ [ChatScreen] WebSocket connected, ready to send message');
          } else {
            log('❌ [ChatScreen] Failed to create room: ${createResponse.error}');
            if (mounted) {
              setState(() {
                _messages.removeWhere((m) => m.id == tempMessageId);
              });
              EnhancedToast.error(
                context,
                title: 'Error',
                message: 'Failed to create chat room. Please try again.',
              );
            }
            return;
          }
        } catch (e) {
          log('❌ [ChatScreen] Exception creating room: $e');
          if (mounted) {
            setState(() {
              _messages.removeWhere((m) => m.id == tempMessageId);
            });
            EnhancedToast.error(
              context,
              title: 'Error',
              message: 'Failed to create chat room: $e',
            );
          }
          return;
        }
      } else {
        // Contact ID format is unknown - cannot create room
        log('❌ [ChatScreen] Cannot send message - no valid UUID room_id available and contact ID format is unknown');
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m.id == tempMessageId);
          });
          EnhancedToast.error(
            context,
            title: 'Error',
            message: 'Chat room not ready. Please wait and try again.',
          );
        }
        return;
      }
    }

    log('📤 [ChatScreen] Sending message with roomId: $_currentRoomId (UUID)');

    // Get reply_to ID if replying to a message
    final replyToId = replyTo?.id;

    final sent = await _chatService.sendMessage(
      roomId: _currentRoomId!,
      content: text,
      messageType: 'text',
      replyTo: replyToId,
    );

    if (!sent) {
      // Failed to send - remove optimistic message and show error
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == tempMessageId);
        });

        EnhancedToast.error(
          context,
          title: 'Failed to send',
          message: 'Please check your connection and try again',
        );
      }
    }
    // If sent successfully, the message will be received via WebSocket
    // and the optimistic message will be replaced/updated with proper status
  }

  /// Handle back button press (both app back button and system back button)
  Future<void> _handleBackButton() async {
    log('🔙 [ChatScreen] Back button pressed, returnToHistory: ${widget.returnToHistory}');

    if (_isSelectionMode) {
      _clearSelection();
      return;
    }

    if (!mounted) {
      log('⚠️ [ChatScreen] Context not mounted, cannot handle back button');
      return;
    }

    if (widget.returnToHistory) {
      // Navigate to history page instead of just popping
      // Use NavigationHelper to work with GoRouter (page-based routing)
      log('🔙 [ChatScreen] Navigating to CallHistoryPage using NavigationHelper');
      NavigationHelper.replaceWithWidget(
        context,
        (context) => const CallHistoryPage(),
        fullscreenDialog: true,
      );
    } else {
      // Default behavior - use NavigationHelper.pop for GoRouter compatibility
      log('🔙 [ChatScreen] Default pop behavior using NavigationHelper');
      NavigationHelper.pop(context);
    }
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.red),
        onPressed: _clearSelection,
      ),
      title: Text(
        '${_selectedMessageIds.length} selected',
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (_isForwarding)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.forward, color: Colors.purple),
            onPressed: _forwardSelectedMessages,
          ),
      ],
    );
  }

  PreferredSizeWidget _buildDefaultAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      centerTitle: false,
      automaticallyImplyLeading:
          false, // Disable automatic leading to use our custom back button
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () {
          log('🔙 [ChatScreen] AppBar back button pressed');
          _handleBackButton();
        },
      ),
      title: Row(
        children: [
          GestureDetector(
            onTap: () {
              // Preview member avatar when tapped
              final baseAvatarUrl =
                  (_memberAvatar != null && _memberAvatar!.isNotEmpty)
                      ? _memberAvatar!
                      : (widget.contact.photoUrl != null &&
                              widget.contact.photoUrl!.isNotEmpty
                          ? widget.contact.photoUrl!
                          : null);

              if (baseAvatarUrl != null) {
                final previewUrl = _getHighResAvatarUrl(baseAvatarUrl);
                _previewAvatar(previewUrl);
              }
            },
            child: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              radius: 16,
              backgroundImage:
                  (_memberAvatar != null && _memberAvatar!.isNotEmpty)
                      ? NetworkImage(_memberAvatar!)
                      : (widget.contact.photoUrl != null &&
                              widget.contact.photoUrl!.isNotEmpty
                          ? NetworkImage(widget.contact.photoUrl!)
                          : null),
              onBackgroundImageError:
                  ((_memberAvatar != null && _memberAvatar!.isNotEmpty) ||
                          (widget.contact.photoUrl != null &&
                              widget.contact.photoUrl!.isNotEmpty))
                      ? (exception, stackTrace) {
                          log('⚠️ [ChatScreen] Failed to load avatar image: $exception');
                        }
                      : null,
              child: (_memberAvatar == null || _memberAvatar!.isEmpty) &&
                      (widget.contact.photoUrl == null ||
                          widget.contact.photoUrl!.isEmpty)
                  ? Text(
                      widget.contact.initials,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _memberName ??
                      widget.contact
                          .name, // Show member name (person you're chatting with), not user name
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _contact.statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _contact.statusText,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.black),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Clear Chat'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'customize',
              child: Row(
                children: [
                  Icon(Icons.palette, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Customize Chat'),
                ],
              ),
            ),
            // Block user option removed for 1-to-1 chat screen only
            // Group chat screens can still have this option
          ],
          onSelected: (value) {
            if (value == 'clear') {
              _showClearChatDialog();
            } else if (value == 'customize') {
              _showCustomizationOptions();
            }
            // Block user option handler removed for 1-to-1 chat screen only
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with PopScope to handle system back button (Android back button)
    return PopScope(
      canPop: false, // Prevent default back behavior
      onPopInvoked: (bool didPop) {
        log('🔙 [ChatScreen] PopScope triggered, didPop: $didPop');
        if (!didPop) {
          // Handle back button press
          if (mounted) {
            _handleBackButton();
          } else {
            log('⚠️ [ChatScreen] Widget not mounted when PopScope triggered');
          }
        } else {
          log('✅ [ChatScreen] PopScope handled automatically by Flutter');
        }
      },
      child: AppScaffold.internal(
        // 1-to-1: signed-in user = sender, selected contact = receiver; title = receiver's name
        title: _memberName ??
            widget
                .contact.name, // Receiver's name (person you're chatting with)
        customAppBar:
            _isSelectionMode ? _buildSelectionAppBar() : _buildDefaultAppBar(),
        body: _isBlocked
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.block,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You have blocked ${widget.contact.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You will not receive messages from this user',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isBlocked = false;
                        });
                      },
                      child: const Text('Unblock User'),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  Column(
                    children: [
                      // WebSocket connection status banner
                      if (!_isWebSocketConnected)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: Colors.orange.shade100,
                          child: Row(
                            children: [
                              Icon(
                                Icons.wifi_off,
                                size: 16,
                                color: Colors.orange.shade800,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Reconnecting... Messages may be delayed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Chat messages
                      Expanded(
                        child: Builder(builder: (context) {
                          final bottomInset =
                              MediaQuery.of(context).viewInsets.bottom;
                          final emojiHeight =
                              _showEmojiPicker ? _emojiPickerHeight : 0.0;
                          final listPadding = EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            16 + bottomInset + emojiHeight + 120,
                          );
                          return Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (_) => _dismissEmojiAndKeyboard(),
                            child: Stack(
                              children: [
                                // Background image layer
                                Positioned.fill(
                                  child: Container(
                                    color: const Color(
                                        0xFFF0F2F5), // Base color to prevent blank spaces
                                    child: _chatWallpaperImage != null
                                        ? Opacity(
                                            opacity:
                                                0.75, // Same opacity as group chat
                                            child: Image.file(
                                              _chatWallpaperImage!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return const SizedBox.shrink();
                                              },
                                            ),
                                          )
                                        : Opacity(
                                            opacity:
                                                0.75, // Same opacity as group chat
                                            child: Image.asset(
                                              'assets/images/oscar/oscar_chat.png',
                                              repeat: ImageRepeat.repeat,
                                              // No fit parameter - image repeats at its natural size without stretching
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                debugPrint(
                                                    'Failed to load background image: $error');
                                                // Fallback to white background if image fails to load
                                                return Container(
                                                    color: Colors.white);
                                              },
                                            ),
                                          ),
                                  ),
                                ),
                                // Content layer
                                // Note: Global loader dialog is shown when _isLoading is true
                                // No need to show CircularProgressIndicator here
                                _hasError && _messages.isEmpty
                                    ? _buildErrorState()
                                    : _messages.isEmpty
                                        ? _buildEmptyState()
                                        : ListView.builder(
                                            controller: _scrollController,
                                            padding: listPadding,
                                            itemCount: _messages.length +
                                                (_isTyping ? 1 : 0) +
                                                (_isLoadingMore ? 1 : 0),
                                            itemBuilder: (context, index) {
                                              // Loading indicator for pagination at top (like group chat)
                                              if (index == 0 &&
                                                  _isLoadingMore) {
                                                return const Padding(
                                                  padding: EdgeInsets.all(16.0),
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                );
                                              }
                                              // Adjust index if loading indicator is shown
                                              final messageIndex =
                                                  _isLoadingMore
                                                      ? index - 1
                                                      : index;

                                              // Typing indicator
                                              if (messageIndex ==
                                                      _messages.length &&
                                                  _isTyping) {
                                                return _buildTypingIndicator();
                                              }

                                              final message =
                                                  _messages[messageIndex];
                                              return _buildMessageBubble(
                                                  message);
                                            },
                                          ),
                              ],
                            ),
                          );
                        }),
                      ),

                      // Reply preview
                      if (_replyingTo != null)
                        Builder(
                          builder: (context) {
                            final isDarkTheme = _chatTheme == ThemeMode.dark ||
                                (_chatTheme == ThemeMode.system &&
                                    MediaQuery.of(context).platformBrightness ==
                                        Brightness.dark);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDarkTheme
                                    ? Colors.grey.shade900
                                    : Colors.white,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _replyingTo!.isMe
                                              ? 'You'
                                              : widget.contact.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _replyingTo!.isDeleted
                                              ? 'This message was deleted'
                                              : _replyingTo!.text,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDarkTheme
                                                ? Colors.grey.shade300
                                                : Colors.grey.shade700,
                                          ),
                                          maxLines: null,
                                          overflow: TextOverflow.visible,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close,
                                        size: 20,
                                        color: isDarkTheme
                                            ? Colors.white
                                            : Colors.black),
                                    onPressed: () {
                                      setState(() {
                                        _replyingTo = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      // Message input
                      if (!_isBlocked)
                        Builder(
                          builder: (context) {
                            final isDarkTheme = _chatTheme == ThemeMode.dark ||
                                (_chatTheme == ThemeMode.system &&
                                    MediaQuery.of(context).platformBrightness ==
                                        Brightness.dark);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDarkTheme
                                    ? Colors.grey.shade900
                                    : Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 1,
                                    offset: const Offset(0, -1),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.attach_file,
                                            color: Colors.red),
                                        onPressed: _showAttachmentOptions,
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _showEmojiPicker
                                              ? Icons.keyboard
                                              : Icons.emoji_emotions,
                                          color: _showEmojiPicker
                                              ? AppColors.primary
                                              : (isDarkTheme
                                                  ? Colors.grey.shade300
                                                  : Colors.grey),
                                        ),
                                        onPressed: _toggleEmojiPanel,
                                      ),
                                      Expanded(
                                        child: TextField(
                                          focusNode: _messageFocusNode,
                                          onTap: () {
                                            if (_showEmojiPicker) {
                                              setState(() {
                                                _showEmojiPicker = false;
                                              });
                                            }
                                          },
                                          controller: _messageController,
                                          onChanged: (value) => setState(() {}),
                                          style: TextStyle(
                                            color: isDarkTheme
                                                ? Colors.white
                                                : Colors.black,
                                            fontSize: _fontSize,
                                          ),
                                          minLines: 1,
                                          maxLines: 5,
                                          textInputAction:
                                              TextInputAction.newline,
                                          keyboardType: TextInputType.multiline,
                                          decoration: InputDecoration(
                                            hintText: _replyingTo != null
                                                ? 'Reply to ${_replyingTo!.isMe ? "your message" : widget.contact.name}...'
                                                : 'Type a message...',
                                            hintStyle: TextStyle(
                                              color: isDarkTheme
                                                  ? Colors.grey.shade500
                                                  : Colors.grey.shade600,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: isDarkTheme
                                                ? Colors.grey.shade800
                                                : Colors.grey.shade100,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                          ),
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (_messageController.text
                                          .trim()
                                          .isNotEmpty)
                                        CircleAvatar(
                                          backgroundColor: AppColors.primary,
                                          child: IconButton(
                                            icon: const Icon(Icons.send),
                                            color: Colors.white,
                                            onPressed: _sendMessage,
                                          ),
                                        )
                                      else
                                        GestureDetector(
                                          onLongPressStart: (details) {
                                            _startVoiceRecording();
                                            // Haptic feedback
                                            HapticFeedback.mediumImpact();
                                          },
                                          onLongPressEnd: (details) {
                                            _endVoiceRecording();
                                            HapticFeedback.lightImpact();
                                          },
                                          onLongPressCancel: () {
                                            _cancelVoiceRecording();
                                            HapticFeedback.lightImpact();
                                          },
                                          onTap: () {
                                            // Show hint for long press
                                            EnhancedToast.info(
                                              context,
                                              title: 'Voice Note',
                                              message:
                                                  'Hold to record a voice message',
                                            );
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: _isPressingMic
                                                  ? AppColors.primary
                                                      .withOpacity(0.8)
                                                  : AppColors.primary,
                                              shape: BoxShape.circle,
                                              boxShadow: _isPressingMic
                                                  ? [
                                                      BoxShadow(
                                                        color: AppColors.primary
                                                            .withOpacity(0.4),
                                                        spreadRadius: 4,
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 2),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Icon(
                                              Icons.mic,
                                              color: Colors.white,
                                              size: _isPressingMic ? 26 : 24,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (_showEmojiPicker)
                                    Container(
                                      height: 300,
                                      margin: const EdgeInsets.only(top: 8),
                                      decoration: BoxDecoration(
                                        color: isDarkTheme
                                            ? Colors.grey.shade900
                                            : Colors.white,
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: _buildEmojiPicker(),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  // Voice recording overlay
                  if (_isRecording && _isPressingMic)
                    _buildVoiceRecordingOverlay(),
                ],
              ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isDarkTheme = _chatTheme == ThemeMode.dark ||
        (_chatTheme == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final isSelected = _selectedMessageIds.contains(message.id);
    final selectionActive = _isSelectionMode;

    // Check if we need to show date separator
    final messageIndex = _messages.indexOf(message);
    final showDateSeparator = messageIndex == 0 ||
        _messages[messageIndex - 1].timestamp.day != message.timestamp.day ||
        _messages[messageIndex - 1].timestamp.month !=
            message.timestamp.month ||
        _messages[messageIndex - 1].timestamp.year != message.timestamp.year;

    return Column(
      children: [
        if (showDateSeparator) _buildDateSeparator(message.timestamp),
        GestureDetector(
          onTap: () {
            if (selectionActive) {
              _toggleMessageSelection(message);
            }
          },
          onLongPress: () {
            if (selectionActive) {
              _toggleMessageSelection(message);
            } else {
              _showMessageOptions(message);
            }
          },
          onDoubleTap: () => _showReactionPicker(message),
          child: Dismissible(
            key: Key('${message.id}_${_replyingTo?.id ?? 'none'}'),
            direction: selectionActive
                ? DismissDirection.none
                : (message.isMe
                    ? DismissDirection.endToStart
                    : DismissDirection.startToEnd),
            confirmDismiss: (direction) async {
              // Handle the swipe action without removing the widget
              if (selectionActive) return false;
              setState(() {
                _replyingTo = message;
              });
              EnhancedToast.info(
                context,
                title: 'Replying',
                message: 'Tap to send your reply',
              );
              // Return false to prevent the widget from being removed
              return false;
            },
            background: Container(
              alignment:
                  message.isMe ? Alignment.centerRight : Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: AppColors.primary.withOpacity(0.1),
              child: const Icon(
                Icons.reply,
                color: AppColors.primary,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: message.isMe
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!message.isMe) ...[
                    Builder(
                      builder: (context) {
                        // Get avatar from cache (like group chat)
                        // For 1-to-1 chat, use contact ID to lookup avatar
                        String? avatarUrl =
                            _getAvatarForSender(widget.contact.id);

                        // Fallback to _memberAvatar or widget.contact.photoUrl
                        if (avatarUrl == null || avatarUrl.isEmpty) {
                          avatarUrl = _memberAvatar ?? widget.contact.photoUrl;
                        }

                        final hasAvatar =
                            avatarUrl != null && avatarUrl.isNotEmpty;

                        return GestureDetector(
                          onTap: hasAvatar && avatarUrl != null
                              ? () => _previewAvatar(
                                    _getHighResAvatarUrl(avatarUrl!),
                                  )
                              : null,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.1),
                                // Use cached avatar from RoomInfo API, WebSocket message, or Messages API
                                // Priority: _memberAvatarCache > _memberAvatar > widget.contact.photoUrl > initials
                                backgroundImage:
                                    hasAvatar ? NetworkImage(avatarUrl!) : null,
                                onBackgroundImageError: hasAvatar
                                    ? (exception, stackTrace) {
                                        log('⚠️ [ChatScreen] Failed to load avatar for ${widget.contact.id}: $exception');
                                        log('   Avatar URL: $avatarUrl');
                                      }
                                    : null,
                                child: !hasAvatar
                                    ? Text(
                                        widget.contact.initials,
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              if (message.isOnline)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Stack(
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxWidth: 280),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: message.isMe
                                ? (isDarkTheme
                                    ? const Color.fromRGBO(0, 132, 255, 1.0)
                                    : const Color.fromRGBO(255, 179, 179, 0.4))
                                : (isDarkTheme
                                    ? Colors.grey.shade800
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(18),
                            border: isSelected
                                ? Border.all(color: AppColors.primary, width: 1)
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Reply to message
                              if (message.replyTo != null) ...[
                                GestureDetector(
                                  onDoubleTap: () =>
                                      _showReactionPicker(message.replyTo!),
                                  onLongPress: () =>
                                      _showMessageOptions(message.replyTo!),
                                  child: _buildReplyPreview(message.replyTo!),
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (message.isForwarded) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.forward,
                                        size: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Forwarded',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              // Link preview
                              if (message.linkPreview != null) ...[
                                _buildLinkPreview(message.linkPreview!),
                                const SizedBox(height: 8),
                              ],
                              if (message.imageFile != null ||
                                  message.imageUrl != null) ...[
                                Builder(
                                  builder: (context) {
                                    // Debug logging for image rendering
                                    if (message.imageUrl != null) {
                                      log('🖼️ [ChatScreen] Rendering image - imageUrl: ${message.imageUrl!.length > 50 ? message.imageUrl!.substring(0, 50) + "..." : message.imageUrl}');
                                    }
                                    return Stack(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            if (message.imageFile != null) {
                                              _previewImage(message.imageFile!);
                                            } else if (message.imageUrl !=
                                                null) {
                                              log('👆 [ChatScreen] Image tapped - previewing: ${message.imageUrl}');
                                              _previewImageUrl(
                                                  message.imageUrl!);
                                            }
                                          },
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: message.imageFile != null
                                                ? Image.file(
                                                    message.imageFile!,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      log('❌ [ChatScreen] Failed to load local image file: $error');
                                                      return Container(
                                                        height: 150,
                                                        color: Colors
                                                            .grey.shade300,
                                                        child: const Icon(
                                                            Icons.broken_image),
                                                      );
                                                    },
                                                  )
                                                : _buildNetworkImage(
                                                    message.imageUrl!),
                                          ),
                                        ),
                                        // Download button overlay (like WhatsApp)
                                        if (message.imageUrl != null &&
                                            !_uploadingFiles
                                                .containsKey(message.id))
                                          Positioned(
                                            bottom: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _downloadImageFromUrl(
                                                      message.imageUrl!),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.download,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        // Upload progress overlay
                                        if (_uploadingFiles[message.id] ==
                                                true &&
                                            _uploadProgress
                                                .containsKey(message.id))
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.5),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Colors.white),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      '${(_uploadProgress[message.id]! * 100).toInt()}%',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (message.isVideo &&
                                  (message.videoFile != null ||
                                      (message.videoUrl?.isNotEmpty ??
                                          false))) ...[
                                WhatsAppVideoMessage(
                                  videoFile: message.videoFile,
                                  videoUrl: message.videoUrl,
                                  thumbnailUrl: message.videoThumbnail,
                                  duration:
                                      null, // TODO: Extract video duration if available
                                  isFromMe: message.isMe,
                                  isUploading:
                                      _uploadingFiles[message.id] == true,
                                  uploadProgress: _uploadProgress[message.id],
                                  isDownloading: _videoDownloadInProgress
                                      .contains(message.id),
                                  downloadProgress:
                                      _videoDownloadProgress[message.id],
                                  onTap: () {
                                    // Only allow tap if not uploading or downloading
                                    if (_uploadingFiles[message.id] != true &&
                                        !_videoDownloadInProgress
                                            .contains(message.id)) {
                                      _handleChatVideoTap(message);
                                    }
                                  },
                                  onDownload: (message.videoUrl != null &&
                                              message.videoUrl!.isNotEmpty &&
                                              message.videoFile == null) &&
                                          _uploadingFiles[message.id] != true &&
                                          !_videoDownloadInProgress
                                              .contains(message.id)
                                      ? () {
                                          // Download video from URL
                                          _downloadVideoWithProgress(message);
                                        }
                                      : null,
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (message.isLocation) ...[
                                Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 48,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Location Shared',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              // Document (only show if NOT a video)
                              if ((message.isDocument ||
                                      message.documentUrl != null) &&
                                  !message.isVideo) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          if (message.documentFile != null) {
                                            // Show options: Open or Download
                                            _showDocumentOptions(
                                                message.documentFile!,
                                                message.documentName ??
                                                    'Document');
                                          } else if (message.documentUrl !=
                                              null) {
                                            // Download document from S3 URL
                                            _downloadDocumentFromUrl(
                                              message.documentUrl!,
                                              message.documentName ??
                                                  'Document',
                                            );
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: _getDocumentColor(
                                                    message.documentType ??
                                                        'other')
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _getDocumentColor(
                                                      message.documentType ??
                                                          'other')
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _getDocumentIcon(
                                                    message.documentType ??
                                                        'other'),
                                                color: _getDocumentColor(
                                                    message.documentType ??
                                                        'other'),
                                                size: 32,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      message.documentName ??
                                                          'Document',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      message.documentFile !=
                                                              null
                                                          ? 'Tap to open'
                                                          : 'Tap to download',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.download,
                                                  color: Colors.grey,
                                                ),
                                                onPressed: () {
                                                  if (message.documentFile !=
                                                      null) {
                                                    _downloadFile(
                                                      message.documentFile!,
                                                      message.documentName ??
                                                          'document',
                                                    );
                                                  } else if (message
                                                          .documentUrl !=
                                                      null) {
                                                    _downloadDocumentFromUrl(
                                                      message.documentUrl!,
                                                      message.documentName ??
                                                          'Document',
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (message.isContact) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Contact Shared',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Tap to view details',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (message.isAudio &&
                                  (message.audioFile != null ||
                                      (message.audioUrl?.isNotEmpty ??
                                          false))) ...[
                                WhatsAppAudioMessage(
                                  audioFile: message.audioFile,
                                  audioUrl: message.audioUrl,
                                  duration: message.audioDuration,
                                  isFromMe: message.isMe,
                                  audioPlayer: _audioPlayer,
                                  messageId: message.id,
                                  isPlaying: _isPlayingAudio &&
                                      _playingAudioId == message.id,
                                  onTogglePlayback: () =>
                                      _toggleAudioPlayback(message),
                                  onDownload: message.audioFile != null
                                      ? () => _downloadFile(
                                            message.audioFile!,
                                            'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
                                          )
                                      : null,
                                ),
                                const SizedBox(height: 8),
                              ],
                              // Message text or deleted placeholder
                              // Hide text if we have file URLs (to avoid showing JSON)
                              if (message.isDeleted)
                                Row(
                                  children: [
                                    Icon(Icons.block,
                                        size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'This message was deleted',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                )
                              else if (message.text.isNotEmpty &&
                                  message.imageUrl == null &&
                                  message.documentUrl == null)
                                Text(
                                  message.text,
                                  style: TextStyle(
                                    color: isDarkTheme
                                        ? (message.isMe
                                            ? Colors.white
                                            : Colors.white)
                                        : (message.isMe
                                            ? Colors.black
                                            : Colors.black),
                                    fontSize: _fontSize,
                                  ),
                                ),
                              if (message.editedAt != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      size: 10,
                                      color: isDarkTheme
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'edited',
                                      style: TextStyle(
                                        color: isDarkTheme
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                        fontSize: 9,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(message.timestamp),
                                    style: TextStyle(
                                      color: isDarkTheme
                                          ? (message.isMe
                                              ? Colors.white.withOpacity(0.7)
                                              : Colors.grey.shade400)
                                          : (message.isMe
                                              ? Colors.black.withOpacity(0.7)
                                              : Colors.grey),
                                      fontSize: 10,
                                    ),
                                  ),
                                  if (message.isMe) ...[
                                    const SizedBox(width: 4),
                                    _buildMessageStatus(message.status),
                                  ],
                                ],
                              ),
                              // Reactions
                              if (message.reactions.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                _buildReactions(message),
                              ],
                            ],
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
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
        ),
      ],
    );
  }

  Widget _buildReplyPreview(ChatMessage replyTo) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                replyTo.isMe ? 'You' : widget.contact.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (replyTo.reactions.isNotEmpty) _buildReplyReactions(replyTo),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            replyTo.isDeleted ? 'This message was deleted' : replyTo.text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }

  Widget _buildReplyReactions(ChatMessage message) {
    if (message.reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get unique reaction types
    final reactionCounts = _getReactionCounts(message.reactions);
    final uniqueReactionTypes = reactionCounts.keys.take(3).toList();

    return GestureDetector(
      onTap: () => _showReactionPicker(message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: const BoxDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...uniqueReactionTypes.map((reactionType) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _reactionIcon(reactionType),
                )),
            if (reactionCounts.length > 3)
              Text(
                '+${reactionCounts.length - 3}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkPreview(LinkPreview preview) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(preview.url)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (preview.imageUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                child: Image.network(
                  preview.imageUrl!,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview.title != null)
                    Text(
                      preview.title!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (preview.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      preview.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    preview.url,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactions(ChatMessage message) {
    if (message.reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get unique reaction types with counts
    final reactionCounts = _getReactionCounts(message.reactions);
    final uniqueReactionTypes = reactionCounts.keys.toList();

    // Debug logging for cancel icon visibility
    if (_currentUserId != null) {
      for (final reactionType in uniqueReactionTypes) {
        final hasUserReacted = _hasUserReacted(message, reactionType);
        if (hasUserReacted) {
          log('🔍 [ChatScreen] User has reacted with $reactionType - cancel icon should show');
        }
      }
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: uniqueReactionTypes.map((reactionType) {
        final count = reactionCounts[reactionType]!;
        final hasUserReacted = _hasUserReacted(message, reactionType);

        return GestureDetector(
          onTap: () {
            if (hasUserReacted) {
              // Remove user's reaction
              _removeReaction(message, reactionType);
            } else {
              // Show reaction picker to add reaction
              _showReactionPicker(message);
            }
          },
          onLongPress: () => _showReactionPicker(message),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _reactionIcon(reactionType),
                if (count > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasUserReacted
                          ? AppColors.primary
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
                // Add cancel icon (❌) if user has reacted to this reaction type
                if (hasUserReacted) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      // Call DELETE API to remove reaction
                      _removeReaction(message, reactionType);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    // Convert to IST for date comparison
    final istDate = _toIST(date);
    final now = DateTime.now();
    // Convert current time to IST for comparison
    final istNow = _toIST(now.toUtc());
    final today = DateTime(istNow.year, istNow.month, istNow.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(istDate.year, istDate.month, istDate.day);

    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMMM d, yyyy').format(istDate);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _buildMessageStatus(MessageStatus status) {
    IconData icon;
    Color color;
    String? tooltip;

    switch (status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = Colors.grey;
        tooltip = 'Sending...';
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.grey.shade700;
        tooltip = 'Sent';
        break;
      case MessageStatus.delivered:
        // Message delivered but not read - show double grey check icon (WhatsApp style)
        icon = Icons.done_all;
        color = Colors.grey.shade600;
        tooltip = 'Delivered';
        break;
      case MessageStatus.seen:
        // Message read by receiver - show blue double check icon (WhatsApp style)
        icon = Icons.done_all;
        color = Colors.blue;
        tooltip = 'Read';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 14, color: color),
    );
  }

  void _toggleMessageSelection(ChatMessage message) {
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id);
      }
      _isSelectionMode = _selectedMessageIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    if (!_isSelectionMode && _selectedMessageIds.isEmpty) return;
    setState(() {
      _selectedMessageIds.clear();
      _isSelectionMode = false;
    });
  }

  List<ChatMessage> _getSelectedMessagesInOrder() {
    if (_selectedMessageIds.isEmpty) return <ChatMessage>[];
    return _messages.where((m) => _selectedMessageIds.contains(m.id)).toList();
  }

  Future<void> _maybeSendPendingForwardMessages() async {
    if (_forwardIntentHandled ||
        _forwardIntentInFlight ||
        _pendingForwardMessageIds == null ||
        _pendingForwardMessageIds!.isEmpty) {
      return;
    }
    if (_currentRoomId == null || _isLoading) return;
    _insertForwardPlaceholders();

    _forwardIntentInFlight = true;
    _forwardIntentHandled = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final isMember = await _chatService.ensureMembership(_currentRoomId!);
      if (!isMember) {
        throw Exception('You are not a member of this chat');
      }

      int success = 0;
      final failures = <String>[];
      final List<RoomMessage> createdMessages = [];

      for (final id in _pendingForwardMessageIds!) {
        final response = await _chatService.forwardMessage(
          messageId: id,
          targetRoomIds: [_currentRoomId!],
        );
        if (response.success) {
          success++;
          // Use API response created_messages so we have real id and is_forwarded from server
          final data = response.data;
          if (data != null && data['created_messages'] is List) {
            for (final item in data['created_messages'] as List) {
              if (item is Map<String, dynamic>) {
                try {
                  createdMessages.add(RoomMessage.fromJson(item));
                } catch (_) {}
              } else if (item is Map) {
                try {
                  createdMessages.add(RoomMessage.fromJson(
                      Map<String, dynamic>.from(
                          item.map((k, v) => MapEntry(k.toString(), v)))));
                } catch (_) {}
              }
            }
          }
        } else {
          failures.add(response.displayError);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // close loader

      if (createdMessages.isNotEmpty) {
        _replaceForwardPlaceholdersWithCreatedMessages(createdMessages);
      } else if (success > 0) {
        _markForwardPlaceholdersDelivered();
      }

      if (success == (_pendingForwardMessageIds?.length ?? 0)) {
        EnhancedToast.success(
          context,
          title: 'Forwarded',
          message: 'Message${success > 1 ? 's' : ''} forwarded successfully.',
        );
      } else if (success > 0) {
        EnhancedToast.warning(
          context,
          title: 'Partially sent',
          message:
              '$success of ${_pendingForwardMessageIds!.length} sent. ${failures.isNotEmpty ? failures.first : ''}',
        );
      } else {
        EnhancedToast.error(
          context,
          title: 'Failed',
          message: failures.isNotEmpty
              ? failures.first
              : 'Could not forward right now.',
        );
      }

      // Scroll to bottom so the forwarded message is visible once it arrives via WebSocket.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to forward message: $e',
      );
    } finally {
      _pendingForwardMessageIds = null;
      _pendingForwardPayloads = null;
      _forwardIntentInFlight = false;
    }
  }

  /// Replaces temp forward placeholders with real messages from API response
  /// so the list has real ids and is_forwarded from server (persists on re-entry).
  void _replaceForwardPlaceholdersWithCreatedMessages(
      List<RoomMessage> createdMessages) {
    if (createdMessages.isEmpty) return;
    setState(() {
      for (int i = 0;
          i < createdMessages.length && i < _forwardPlaceholderIds.length;
          i++) {
        final tempId = _forwardPlaceholderIds[i];
        final rm = createdMessages[i];
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          final chatMessage = ChatMessage(
            id: rm.id,
            text: rm.isDeleted ? '' : rm.body,
            isMe: true,
            timestamp: rm.createdAt,
            editedAt: rm.editedAt,
            isDeleted: rm.isDeleted,
            status: MessageStatus.delivered,
            reactions: rm.reactions,
            isForwarded: rm.isForwarded,
            imageUrl: rm.body.startsWith('http') ? rm.body : null,
            documentUrl: null,
          );
          _messages[idx] = chatMessage;
        }
      }
    });
  }

  void _markForwardPlaceholdersDelivered() {
    setState(() {
      for (final id in _forwardPlaceholderIds) {
        final idx = _messages.indexWhere((m) => m.id == id);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            status: MessageStatus.delivered,
          );
        }
      }
    });
  }

  void _insertForwardPlaceholders() {
    if (_forwardPlaceholdersInserted) return;
    if (_pendingForwardPayloads == null || _pendingForwardPayloads!.isEmpty) {
      return;
    }
    _forwardPlaceholdersInserted = true;

    final now = DateTime.now();
    final List<ChatMessage> placeholders = [];

    for (final payload in _pendingForwardPayloads!) {
      final tempId =
          'temp_forward_${payload.messageId}_${now.microsecondsSinceEpoch}_${_forwardPlaceholderIds.length}';
      _forwardPlaceholderIds.add(tempId);

      String displayText = payload.text;
      final isImage = payload.isImage;
      final isDoc = payload.isDocument;
      final isAudio = payload.isAudio;
      final isVideo = payload.isVideo;

      if (isImage) {
        displayText = '';
      } else if (isDoc) {
        displayText = payload.documentName ?? '📎 Document';
      } else if (isAudio) {
        displayText = '🎤 Voice note';
      } else if (isVideo) {
        displayText = '🎥 Video';
      }

      placeholders.add(
        ChatMessage(
          id: tempId,
          text: displayText,
          isMe: true,
          timestamp: now,
          isDeleted: false,
          status: MessageStatus.sending,
          reactions: const [],
          replyTo: null,
          linkPreview: null,
          isOnline: true,
          imageUrl: payload.imageUrl,
          documentUrl: payload.documentUrl,
          isDocument: isDoc && !isVideo,
          documentName: payload.documentName,
          documentType: payload.documentType,
          isAudio: isAudio,
          audioUrl: payload.audioUrl,
          audioDuration: payload.audioDuration,
          isVideo: isVideo,
          videoUrl: payload.videoUrl,
          videoThumbnail: payload.videoThumbnail,
          isForwarded: true,
        ),
      );
    }

    setState(() {
      _messages.addAll(placeholders);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _startForwardSelection(ChatMessage message) {
    setState(() {
      _selectedMessageIds
        ..clear()
        ..add(message.id);
      _isSelectionMode = true;
    });
    EnhancedToast.info(
      context,
      title: 'Selected',
      message: 'Select more messages or tap the forward icon',
    );
  }

  Future<void> _forwardSelectedMessages() async {
    final selectedMessages = _getSelectedMessagesInOrder();
    if (selectedMessages.isEmpty) {
      EnhancedToast.warning(
        context,
        title: 'Nothing selected',
        message: 'Choose at least one message to forward.',
      );
      return;
    }

    final companyId = await _apiService.getSelectedSocietyId();
    if (companyId == null) {
      EnhancedToast.warning(
        context,
        title: 'Society Required',
        message: 'Select a society before forwarding messages.',
      );
      return;
    }

    final payloads = selectedMessages.map(_buildForwardPayload).toList();

    final selection = await ForwardToBottomSheet.show(
      context: context,
      companyId: companyId,
      chatService: _chatService,
      intercomService: _intercomService,
    );

    if (selection == null) return;

    final ids = selectedMessages.map((m) => m.id).toList();
    _clearSelection();

    if (selection.type == ForwardTargetType.group && selection.room != null) {
      await _navigateToGroupForForward(selection.room!, ids, payloads);
    } else if (selection.type == ForwardTargetType.member &&
        selection.contact != null) {
      await _navigateToContactForForward(selection.contact!, ids, payloads);
    }
  }

  ForwardPayload _buildForwardPayload(ChatMessage m) {
    final isImage = m.imageUrl != null && m.imageUrl!.isNotEmpty;
    final isDoc = m.documentUrl != null && m.documentUrl!.isNotEmpty;
    final isAudio = m.audioUrl != null && m.audioUrl!.isNotEmpty;
    final isVideo = m.videoUrl != null && m.videoUrl!.isNotEmpty;
    return ForwardPayload(
      messageId: m.id,
      text: m.text,
      isImage: isImage,
      isDocument: isDoc && !isVideo,
      isAudio: isAudio,
      isVideo: isVideo,
      imageUrl: m.imageUrl,
      documentUrl: m.documentUrl,
      documentName: m.documentName,
      documentType: m.documentType,
      audioUrl: m.audioUrl,
      audioDuration: m.audioDuration,
      videoUrl: m.videoUrl,
      videoThumbnail: m.videoThumbnail,
    );
  }

  Future<void> _navigateToContactForForward(IntercomContact contact,
      List<String> messageIds, List<ForwardPayload> payloads) async {
    NavigationHelper.pushRoute(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          contact: contact,
          forwardMessageIds: messageIds,
          forwardPayloads: payloads,
        ),
      ),
    );
  }

  Future<void> _navigateToGroupForForward(
      Room room, List<String> messageIds, List<ForwardPayload> payloads) async {
    if (_currentUserId == null) {
      await _loadCurrentUserId();
    }
    if (_currentUserId == null) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'User information not ready. Please try again.',
      );
      return;
    }

    final group = _convertRoomToGroupChat(room);
    NavigationHelper.pushRoute(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(
          group: group,
          currentUserId: _currentUserId!,
          currentUserNumericId: _currentUserNumericId,
          forwardMessageIds: messageIds,
          forwardPayloads: payloads,
        ),
      ),
    );
  }

  GroupChat _convertRoomToGroupChat(Room room) {
    return GroupChat(
      id: room.id,
      name: room.name,
      description: room.description,
      iconUrl: room.photoUrl,
      creatorId: room.createdBy,
      createdByUserId: room.createdByUserId,
      members: const [],
      memberCount: room.membersCount,
      createdAt: room.createdAt,
      lastMessageTime: room.lastActive ?? room.updatedAt,
      lastMessage: null,
      isUnread: (room.unreadCount ?? 0) > 0,
      unreadCount: room.unreadCount ?? 0,
      hasLeft: false,
    );
  }

  Future<void> _forwardMessagesToRoom(
      Room targetRoom, List<ChatMessage> messages) async {
    final forwardable =
        messages.where((m) => !m.isDeleted && m.id.isNotEmpty).toList();
    if (forwardable.isEmpty) {
      EnhancedToast.warning(
        context,
        title: 'Nothing to send',
        message: 'Selected messages are empty or deleted.',
      );
      return;
    }

    if (_isForwarding) return;
    setState(() {
      _isForwarding = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final isMember = await _chatService.ensureMembership(targetRoom.id);
      if (!isMember) {
        throw Exception('You are not a member of ${targetRoom.name}');
      }

      int successCount = 0;
      final List<String> failures = [];

      for (final msg in forwardable) {
        final response = await _chatService.forwardMessage(
          messageId: msg.id,
          targetRoomIds: [targetRoom.id],
        );

        if (response.success) {
          successCount++;
        } else {
          failures.add(response.displayError);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // close loader
      setState(() {
        _isForwarding = false;
      });

      if (successCount == forwardable.length) {
        _clearSelection();
        EnhancedToast.success(
          context,
          title: 'Forwarded',
          message:
              'Message${messages.length > 1 ? 's' : ''} sent to ${targetRoom.name}.',
        );
      } else if (successCount > 0) {
        EnhancedToast.warning(
          context,
          title: 'Partially sent',
          message:
              '$successCount of ${forwardable.length} message(s) forwarded. ${failures.isNotEmpty ? failures.first : ''}',
        );
      } else {
        EnhancedToast.error(
          context,
          title: 'Failed',
          message: failures.isNotEmpty
              ? failures.first
              : 'Could not forward right now. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {
        _isForwarding = false;
      });
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to forward message: $e',
      );
    }
  }

  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (!message.isDeleted) ...[
                  ListTile(
                    leading: const Icon(Icons.reply, color: Colors.blue),
                    title: const Text('Reply'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _replyingTo = message;
                      });
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.forward, color: Colors.purple),
                    title: const Text('Forward'),
                    onTap: () {
                      Navigator.pop(context);
                      _startForwardSelection(message);
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.add_reaction, color: Colors.orange),
                    title: const Text('Add Reaction'),
                    onTap: () {
                      Navigator.pop(context);
                      _showReactionPicker(message);
                    },
                  ),
                  // Show "Remove Reaction" option if user has reacted
                  if (_hasUserReactedAny(message)) ...[
                    ListTile(
                      leading: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      title: const Text('Remove Reaction'),
                      onTap: () {
                        Navigator.pop(context);
                        final userReaction = _getUserReaction(message);
                        if (userReaction != null) {
                          _removeReaction(message, userReaction.reactionType);
                        }
                      },
                    ),
                  ],
                  // Show "View Who Reacted" option - always show for non-deleted messages
                  // API will fetch reactions even if not loaded locally
                  ListTile(
                    leading: const Icon(Icons.people, color: Colors.blue),
                    title: const Text('View Who Reacted'),
                    onTap: () {
                      Navigator.pop(context);
                      _showWhoReacted(message);
                    },
                  ),
                ],
                if (message.replyTo != null && !message.replyTo!.isDeleted) ...[
                  ListTile(
                    leading:
                        const Icon(Icons.add_reaction, color: Colors.orange),
                    title: const Text('Add Reaction to Reply'),
                    onTap: () {
                      Navigator.pop(context);
                      _showReactionPicker(message.replyTo!);
                    },
                  ),
                ],
                if (message.isMe && !message.isDeleted) ...[
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.green),
                    title: const Text('Edit Message'),
                    onTap: () {
                      Navigator.pop(context);
                      _editMessage(message);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete Message'),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessage(message);
                    },
                  ),
                ],
                if (message.isAudio) ...[
                  ListTile(
                    leading: Icon(
                      _isPlayingAudio && _playingAudioId == message.id
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.purple,
                    ),
                    title: Text(_isPlayingAudio && _playingAudioId == message.id
                        ? 'Pause'
                        : 'Play'),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleAudioPlayback(message);
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show who reacted to a message
  void _showWhoReacted(ChatMessage message) async {
    // Show loading indicator
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = MediaQuery.of(context).size.height;
              final targetHeight = (screenHeight * 0.28).clamp(140.0, 200.0);
              final sheetHeight =
                  targetHeight > constraints.maxHeight && constraints.maxHeight > 0
                      ? constraints.maxHeight
                      : targetHeight;
              final loaderSize =
                  (sheetHeight - 32).clamp(80.0, 140.0);
              return Container(
                height: sheetHeight,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AppLoader(size: loaderSize),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    try {
      // Fetch reactions from API
      final response = await _roomService.getMessageReactions(
        messageId: message.id,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading indicator

      if (response.success && response.data != null) {
        final reactions = response.data!;

        if (reactions.isEmpty) {
          EnhancedToast.info(
            context,
            title: 'No Reactions',
            message: 'No one has reacted to this message yet',
          );
          return;
        }

        // Group reactions by reaction type
        final groupedReactions = <String, List<MessageReaction>>{};
        for (final reaction in reactions) {
          final reactionType = reaction.reactionType;
          if (!groupedReactions.containsKey(reactionType)) {
            groupedReactions[reactionType] = [];
          }
          groupedReactions[reactionType]!.add(reaction);
        }

        // Show bottom sheet with reactions
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            'Reactions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: groupedReactions.length,
                        itemBuilder: (context, index) {
                          final reactionType =
                              groupedReactions.keys.elementAt(index);
                          final reactionList = groupedReactions[reactionType]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...reactionList.map((reaction) {
                                // Sanitize user name - reject UUID-like names
                                String displayName = reaction.userName;
                                if (_isUuidLike(displayName)) {
                                  displayName = 'User';
                                }

                                // Get avatar URL for this user
                                String? avatarUrl =
                                    _getAvatarForSender(reaction.userId);

                                // Get initials for fallback
                                final initials = displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U';

                                final hasAvatar =
                                    avatarUrl != null && avatarUrl.isNotEmpty;

                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: AppColors.primary
                                                .withOpacity(0.1),
                                            // Use avatar image if available, otherwise show initials
                                            backgroundImage: hasAvatar
                                                ? NetworkImage(avatarUrl!)
                                                : null,
                                            onBackgroundImageError: hasAvatar
                                                ? (exception, stackTrace) {
                                                    log('⚠️ [ChatScreen] Failed to load avatar for ${reaction.userId}: $exception');
                                                    log('   Avatar URL: $avatarUrl');
                                                  }
                                                : null,
                                            child: !hasAvatar
                                                ? Text(
                                                    initials,
                                                    style: TextStyle(
                                                      color: AppColors.primary,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              displayName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          // Show reaction emoji after member name
                                          Text(
                                            reactionType,
                                            style:
                                                const TextStyle(fontSize: 20),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Add divider line with each member (grey color with 0.1 opacity)
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Colors.grey.withOpacity(0.1),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        }
      } else {
        EnhancedToast.error(
          context,
          title: 'Error',
          message: response.error ?? 'Failed to fetch reactions',
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading indicator if still open
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Helper method to check if a string is UUID-like
  bool _isUuidLike(String str) {
    if (str.isEmpty) return false;

    // Check for UUID format (contains dashes and is long)
    final isUuidFormat = str.contains('-') && str.length > 30;

    // Check for "user_" prefix followed by UUID
    final isUserPrefixedUuid = str.startsWith('user_') &&
        str.length > 36 && // "user_" (5) + UUID (36) = 41
        str.substring(5).contains('-');

    return isUuidFormat || isUserPrefixedUuid;
  }

  void _showReactionPicker(ChatMessage message) {
    // Lazy load reactions if not already loaded (when user interacts with message)
    // This ensures reactions are available when picker opens
    if (message.reactions.isEmpty) {
      // Fetch reactions in background - don't block UI
      loadReactionsForMessage(message.id);
    }
    // Expanded reaction list - all available emojis mapped to API reaction types
    final reactions = [
      // Like reactions
      {'emoji': '👍', 'name': 'Like'},
      {'emoji': '👎', 'name': 'Dislike'},
      {'emoji': '👌', 'name': 'OK'},
      {'emoji': '✌️', 'name': 'Peace'},
      {'emoji': '🤝', 'name': 'Handshake'},
      {'emoji': '🙌', 'name': 'Raised Hands'},
      {'emoji': '👏', 'name': 'Clap'},
      {'emoji': '🙏', 'name': 'Pray'},
      {'emoji': '💪', 'name': 'Muscle'},
      {'emoji': '🤞', 'name': 'Crossed Fingers'},
      {'emoji': '🤟', 'name': 'Love You'},
      {'emoji': '🤘', 'name': 'Rock On'},
      {'emoji': '👊', 'name': 'Fist Bump'},
      {'emoji': '✊', 'name': 'Raised Fist'},
      {'emoji': '🤲', 'name': 'Palms Up'},
      {'emoji': '👐', 'name': 'Open Hands'},
      // Love reactions
      {'emoji': '❤️', 'name': 'Love'},
      {'emoji': '💕', 'name': 'Two Hearts'},
      {'emoji': '💖', 'name': 'Sparkling Heart'},
      {'emoji': '💗', 'name': 'Growing Heart'},
      {'emoji': '💓', 'name': 'Beating Heart'},
      {'emoji': '💞', 'name': 'Revolving Hearts'},
      {'emoji': '💝', 'name': 'Heart with Ribbon'},
      {'emoji': '💘', 'name': 'Cupid'},
      {'emoji': '💟', 'name': 'Heart Decoration'},
      {'emoji': '❣️', 'name': 'Heart Exclamation'},
      {'emoji': '💔', 'name': 'Broken Heart'},
      {'emoji': '🧡', 'name': 'Orange Heart'},
      {'emoji': '💛', 'name': 'Yellow Heart'},
      {'emoji': '💚', 'name': 'Green Heart'},
      {'emoji': '💙', 'name': 'Blue Heart'},
      {'emoji': '💜', 'name': 'Purple Heart'},
      {'emoji': '🖤', 'name': 'Black Heart'},
      {'emoji': '🤍', 'name': 'White Heart'},
      {'emoji': '🤎', 'name': 'Brown Heart'},
      {'emoji': '😍', 'name': 'Heart Eyes'},
      {'emoji': '🥰', 'name': 'Smiling with Hearts'},
      {'emoji': '😘', 'name': 'Kiss'},
      {'emoji': '😗', 'name': 'Kissing'},
      {'emoji': '😙', 'name': 'Kissing Smile'},
      {'emoji': '😚', 'name': 'Kissing Closed Eyes'},
      // Laugh reactions
      {'emoji': '😂', 'name': 'Laugh'},
      {'emoji': '🤣', 'name': 'Rolling Laugh'},
      {'emoji': '😄', 'name': 'Grin'},
      {'emoji': '😃', 'name': 'Big Grin'},
      {'emoji': '😀', 'name': 'Grinning'},
      {'emoji': '😁', 'name': 'Beaming'},
      {'emoji': '😆', 'name': 'Squinting Laugh'},
      {'emoji': '😅', 'name': 'Sweat Grin'},
      {'emoji': '😊', 'name': 'Smiling'},
      {'emoji': '😋', 'name': 'Yum'},
      {'emoji': '😛', 'name': 'Tongue Out'},
      {'emoji': '😝', 'name': 'Squinting Tongue'},
      {'emoji': '😜', 'name': 'Winking Tongue'},
      {'emoji': '🤪', 'name': 'Zany'},
      {'emoji': '🤗', 'name': 'Hugging'},
      {'emoji': '🤭', 'name': 'Hand Over Mouth'},
      // Sad reactions
      {'emoji': '😢', 'name': 'Sad'},
      {'emoji': '😭', 'name': 'Crying'},
      {'emoji': '😞', 'name': 'Disappointed'},
      {'emoji': '😔', 'name': 'Pensive'},
      {'emoji': '😟', 'name': 'Worried'},
      {'emoji': '😕', 'name': 'Confused'},
      {'emoji': '🙁', 'name': 'Slight Frown'},
      {'emoji': '☹️', 'name': 'Frown'},
      {'emoji': '😣', 'name': 'Persevering'},
      {'emoji': '😖', 'name': 'Confounded'},
      {'emoji': '😫', 'name': 'Tired'},
      {'emoji': '😩', 'name': 'Weary'},
      {'emoji': '🥺', 'name': 'Pleading'},
      // Angry reactions
      {'emoji': '😡', 'name': 'Angry'},
      {'emoji': '😠', 'name': 'Pouting'},
      {'emoji': '🤬', 'name': 'Swearing'},
      {'emoji': '😤', 'name': 'Huffing'},
      {'emoji': '💢', 'name': 'Anger Symbol'},
      // Other popular reactions
      {'emoji': '😮', 'name': 'Wow'},
      {'emoji': '😲', 'name': 'Astonished'},
      {'emoji': '😱', 'name': 'Screaming'},
      {'emoji': '🤯', 'name': 'Exploding Head'},
      {'emoji': '😳', 'name': 'Flushed'},
      {'emoji': '🥵', 'name': 'Hot'},
      {'emoji': '🥶', 'name': 'Cold'},
      {'emoji': '😨', 'name': 'Fearful'},
      {'emoji': '😰', 'name': 'Anxious'},
      {'emoji': '😥', 'name': 'Sad Relieved'},
      {'emoji': '😓', 'name': 'Downcast Sweat'},
      {'emoji': '🤔', 'name': 'Think'},
      {'emoji': '🤨', 'name': 'Raised Eyebrow'},
      {'emoji': '🧐', 'name': 'Monocle'},
      {'emoji': '🤓', 'name': 'Nerd'},
      {'emoji': '😎', 'name': 'Cool'},
      {'emoji': '🤩', 'name': 'Star Struck'},
      {'emoji': '🥳', 'name': 'Party'},
      {'emoji': '🎉', 'name': 'Party Popper'},
      {'emoji': '🎊', 'name': 'Confetti'},
      {'emoji': '🔥', 'name': 'Fire'},
      {'emoji': '💯', 'name': '100'},
      {'emoji': '✅', 'name': 'Check'},
      {'emoji': '❌', 'name': 'Cross'},
      {'emoji': '⭐', 'name': 'Star'},
      {'emoji': '🌟', 'name': 'Glowing Star'},
      {'emoji': '✨', 'name': 'Sparkles'},
      {'emoji': '💫', 'name': 'Dizzy'},
      {'emoji': '🎈', 'name': 'Balloon'},
      {'emoji': '🎁', 'name': 'Gift'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Add Reaction',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 400, // Fixed height for scrollable grid
                    child: GridView.builder(
                      shrinkWrap: false,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: reactions.length,
                      itemBuilder: (context, index) {
                        final reaction = reactions[index];
                        final emoji = reaction['emoji']!;
                        final reactionType = _emojiToReactionType(emoji);
                        final isAlreadyReacted = reactionType != null &&
                            _hasUserReacted(message, reactionType);
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              Navigator.pop(context);

                              // Ensure reactions are loaded before processing
                              // This is critical to determine if we should call PUT or POST
                              if (message.reactions.isEmpty) {
                                await loadReactionsForMessage(message.id);
                                // Get updated message from state
                                final updatedIndex = _messages
                                    .indexWhere((m) => m.id == message.id);
                                if (updatedIndex != -1) {
                                  final updatedMessage =
                                      _messages[updatedIndex];

                                  // Check again with loaded reactions
                                  final hasUserReactedAny =
                                      _hasUserReactedAny(updatedMessage);
                                  final userReaction =
                                      _getUserReaction(updatedMessage);

                                  if (isAlreadyReacted &&
                                      reactionType != null) {
                                    // User tapped their own reaction - remove it
                                    _removeReaction(
                                        updatedMessage, reactionType);
                                  } else if (hasUserReactedAny &&
                                      userReaction != null) {
                                    // User has reacted with different type - UPDATE (PUT)
                                    log('🔄 [ChatScreen] User updating reaction from ${userReaction.reactionType} to $reactionType');
                                    _addReaction(updatedMessage, emoji);
                                  } else {
                                    // User hasn't reacted - ADD (POST)
                                    log('➕ [ChatScreen] User adding new reaction: $reactionType');
                                    _addReaction(updatedMessage, emoji);
                                  }
                                } else {
                                  // Fallback if message not found
                                  _addReaction(message, emoji);
                                }
                              } else {
                                // Reactions already loaded - process normally
                                if (isAlreadyReacted && reactionType != null) {
                                  _removeReaction(message, reactionType);
                                } else {
                                  _addReaction(message, emoji);
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isAlreadyReacted
                                    ? AppColors.primary.withOpacity(0.1)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isAlreadyReacted
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: isAlreadyReacted ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    reaction['emoji']!,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    reaction['name']!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: isAlreadyReacted
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// API now supports any emoji string
  String? _emojiToReactionType(String emoji) {
    // API now limits lifted - return the emoji directly
    return emoji;
  }

  /// Map reaction_type to emoji icon
  Widget _reactionIcon(String reactionType) {
    switch (reactionType.toLowerCase()) {
      case 'like':
        return const Text('👍', style: TextStyle(fontSize: 16));
      case 'love':
        return const Text('❤️', style: TextStyle(fontSize: 16));
      case 'laugh':
        return const Text('😂', style: TextStyle(fontSize: 16));
      case 'angry':
        return const Text('😡', style: TextStyle(fontSize: 16));
      case 'sad':
        return const Text('😢', style: TextStyle(fontSize: 16));
      default:
        // Render the emoji directly for new reactions
        return Text(reactionType, style: const TextStyle(fontSize: 16));
    }
  }

  /// Get unique reaction types with counts from a list of reactions
  Map<String, int> _getReactionCounts(List<MessageReaction> reactions) {
    final counts = <String, int>{};
    for (final reaction in reactions) {
      counts[reaction.reactionType] = (counts[reaction.reactionType] ?? 0) + 1;
    }
    return counts;
  }

  /// Check if current user has reacted with a specific reaction type
  bool _hasUserReacted(ChatMessage message, String reactionType) {
    if (_currentUserId == null) {
      return false;
    }
    // Normalize both IDs for comparison (trim whitespace, handle case)
    final normalizedCurrentUserId = _currentUserId!.trim();
    final hasReacted = message.reactions.any(
      (r) {
        return r.userId.trim() == normalizedCurrentUserId &&
            r.reactionType == reactionType;
      },
    );
    return hasReacted;
  }

  /// Check if current user has reacted to this message (any reaction type)
  bool _hasUserReactedAny(ChatMessage message) {
    if (_currentUserId == null) return false;
    final normalizedCurrentUserId = _currentUserId!.trim();
    return message.reactions
        .any((r) => r.userId.trim() == normalizedCurrentUserId);
  }

  /// Get current user's existing reaction for this message
  MessageReaction? _getUserReaction(ChatMessage message) {
    if (_currentUserId == null) return null;
    try {
      final normalizedCurrentUserId = _currentUserId!.trim();
      return message.reactions.firstWhere(
        (r) => r.userId.trim() == normalizedCurrentUserId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Fetch reactions for messages when entering chat room (smart batching)
  ///
  /// Fetches reactions in batches to avoid rate limiting:
  /// - Fetches for recent messages first (last 20 messages)
  /// - Batches of 5 messages with 500ms delay between batches
  /// - Respects cooldown periods
  Future<void> _fetchReactionsForMessagesOnEntry(
      List<ChatMessage> messages) async {
    if (messages.isEmpty) return;

    // Only fetch for recent messages (last 20) to avoid overwhelming API
    final messagesToFetch = messages.length > 20
        ? messages.sublist(messages.length - 20)
        : messages;

    log('🔄 [ChatScreen] Fetching reactions for ${messagesToFetch.length} messages on entry');

    // Process in batches of 5 with delay between batches
    const batchSize = 5;
    const delayBetweenBatches = Duration(milliseconds: 500);

    for (int i = 0; i < messagesToFetch.length; i += batchSize) {
      if (!mounted) break;

      // Check cooldown before each batch
      if (_reactionFetchCooldownUntil != null) {
        final now = DateTime.now();
        if (now.isBefore(_reactionFetchCooldownUntil!)) {
          final remainingSeconds =
              _reactionFetchCooldownUntil!.difference(now).inSeconds;
          log('⏸️ [ChatScreen] Reaction fetch on cooldown. ${remainingSeconds}s remaining. Stopping batch fetch.');
          break;
        } else {
          _reactionFetchCooldownUntil = null;
        }
      }

      final batch = messagesToFetch.skip(i).take(batchSize).toList();

      // Fetch reactions for batch in parallel (but with rate limiting)
      for (final message in batch) {
        if (!mounted) break;

        // Skip if already fetching or if cooldown active
        if (_reactionsFetchInProgress.contains(message.id)) continue;
        if (_reactionFetchCooldownUntil != null &&
            DateTime.now().isBefore(_reactionFetchCooldownUntil!)) break;

        // Fetch with rate limiting
        await loadReactionsForMessage(message.id);

        // Small delay between individual fetches
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Delay between batches (except for last batch)
      if (i + batchSize < messagesToFetch.length) {
        await Future.delayed(delayBetweenBatches);
      }
    }

    log('✅ [ChatScreen] Completed reaction fetching for messages on entry');
  }

  /// Load reactions for a specific message (lazy loading - only when needed)
  ///
  /// This is called:
  /// - After adding/updating/deleting a reaction
  /// - When user interacts with a message (long press, tap reaction)
  /// - When entering chat room (batched fetching)
  Future<void> loadReactionsForMessage(String messageId) async {
    // Check if already fetching for this message
    if (_reactionsFetchInProgress.contains(messageId)) {
      log('⏭️ [ChatScreen] Reaction fetch already in progress for message: $messageId');
      return;
    }

    // Check cooldown period (after 429 error)
    if (_reactionFetchCooldownUntil != null) {
      final now = DateTime.now();
      if (now.isBefore(_reactionFetchCooldownUntil!)) {
        final remainingSeconds =
            _reactionFetchCooldownUntil!.difference(now).inSeconds;
        log('⏸️ [ChatScreen] Reaction fetch on cooldown. ${remainingSeconds}s remaining');
        return;
      } else {
        // Cooldown expired, clear it
        _reactionFetchCooldownUntil = null;
      }
    }

    // Rate limiting: Check minimum interval between reaction fetches
    if (_lastReactionFetchTime != null) {
      final timeSinceLastFetch =
          DateTime.now().difference(_lastReactionFetchTime!);
      if (timeSinceLastFetch < _reactionFetchMinInterval) {
        final waitTime = _reactionFetchMinInterval - timeSinceLastFetch;
        log('⏸️ [ChatScreen] Rate limiting reaction fetch. Waiting ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      }
    }

    _reactionsFetchInProgress.add(messageId);
    _lastReactionFetchTime = DateTime.now();

    try {
      final response =
          await _roomService.getMessageReactions(messageId: messageId);

      if (response.statusCode == 429) {
        // Rate limit error - set cooldown
        _reactionFetchCooldownUntil =
            DateTime.now().add(_reactionFetchCooldown);
        log('⚠️ [ChatScreen] Rate limit (429) on reaction fetch. Cooldown until: $_reactionFetchCooldownUntil');

        if (mounted) {
          EnhancedToast.warning(
            context,
            title: 'Too Many Requests',
            message: 'Please wait 30s before retrying.',
          );
        }
        return;
      }

      if (response.success && response.data != null) {
        final msgIndex = _messages.indexWhere((m) => m.id == messageId);
        if (msgIndex != -1 && mounted) {
          // Create a new list to ensure Flutter detects the change
          final updatedReactions = List<MessageReaction>.from(response.data!);

          log('🔄 [ChatScreen] Updating reactions for message $messageId: ${updatedReactions.length} reactions');
          log('   Current user ID: $_currentUserId');
          for (final reaction in updatedReactions) {
            log('   Reaction: ${reaction.reactionType} by user ${reaction.userId} (${reaction.userName})');
            if (reaction.userId == _currentUserId) {
              log('   ✓ This is current user\'s reaction!');
            }
          }

          setState(() {
            // Create a new message instance with updated reactions
            _messages[msgIndex] = _messages[msgIndex].copyWith(
              reactions: updatedReactions,
            );

            // Update replyTo references
            for (int i = 0; i < _messages.length; i++) {
              if (_messages[i].replyTo?.id == messageId) {
                _messages[i] = _messages[i].copyWith(
                  replyTo: _messages[msgIndex],
                );
              }
            }
          });

          // Force a rebuild by checking the updated message
          final updatedMessage = _messages[msgIndex];
          log('✅ [ChatScreen] Reactions updated. Message now has ${updatedMessage.reactions.length} reactions');
          log('   User has reacted: ${_hasUserReactedAny(updatedMessage)}');
          if (_hasUserReactedAny(updatedMessage)) {
            final userReaction = _getUserReaction(updatedMessage);
            log('   User reaction type: ${userReaction?.reactionType}');
          }
        } else {
          log('⚠️ [ChatScreen] Message not found or not mounted: $messageId');
        }
        // Reset cooldown on success
        _reactionFetchCooldownUntil = null;
      } else {
        log('❌ [ChatScreen] Failed to load reactions: ${response.error}');
      }
    } catch (e) {
      log('❌ [ChatScreen] Exception loading reactions: $e');
      // Fail silently
    } finally {
      _reactionsFetchInProgress.remove(messageId);
    }
  }

  Future<void> _addReaction(ChatMessage message, String reaction) async {
    // Check if message is deleted
    if (message.isDeleted) {
      EnhancedToast.warning(
        context,
        title: 'Cannot React',
        message: 'Deleted messages cannot be reacted to.',
      );
      return;
    }

    // Map emoji to reaction_type
    final reactionType = _emojiToReactionType(reaction);
    if (reactionType == null) {
      log('⚠️ [ChatScreen] Unsupported emoji for reaction: $reaction');
      EnhancedToast.warning(
        context,
        title: 'Unsupported Reaction',
        message: 'This reaction type is not supported.',
      );
      return;
    }

    // Find message by ID
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) {
      log('⚠️ [ChatScreen] Message not found: ${message.id}');
      return;
    }

    // Rate limiting: Check if already updating this message
    if (_reactionsUpdateInProgress.contains(message.id)) {
      log('⏭️ [ChatScreen] Reaction update already in progress for message: ${message.id}');
      return;
    }

    // Rate limiting: Check cooldown period (after 429 error)
    if (_reactionUpdateCooldownUntil != null) {
      final now = DateTime.now();
      if (now.isBefore(_reactionUpdateCooldownUntil!)) {
        final remainingSeconds =
            _reactionUpdateCooldownUntil!.difference(now).inSeconds;
        log('⏸️ [ChatScreen] Reaction update on cooldown. ${remainingSeconds}s remaining');
        EnhancedToast.warning(
          context,
          title: 'Too Many Requests',
          message:
              'Please wait ${remainingSeconds}s before updating reactions.',
        );
        return;
      } else {
        // Cooldown expired, clear it
        _reactionUpdateCooldownUntil = null;
      }
    }

    // Rate limiting: Check minimum interval between reaction updates
    if (_lastReactionUpdateTime != null) {
      final timeSinceLastUpdate =
          DateTime.now().difference(_lastReactionUpdateTime!);
      if (timeSinceLastUpdate < _reactionUpdateMinInterval) {
        final waitTime = _reactionUpdateMinInterval - timeSinceLastUpdate;
        log('⏸️ [ChatScreen] Rate limiting reaction update. Waiting ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      }
    }

    // Decision logic: PUT if user already reacted, POST if new
    final hasUserReacted = _hasUserReactedAny(message);
    final existingReaction = _getUserReaction(message);

    log('🔍 [ChatScreen] Reaction decision logic:');
    log('   hasUserReacted: $hasUserReacted');
    log('   existingReaction: ${existingReaction?.reactionType ?? "none"}');
    log('   new reactionType: $reactionType');
    log('   message.reactions.length: ${message.reactions.length}');

    // If user already reacted with the same type, remove it (toggle behavior)
    if (existingReaction != null &&
        existingReaction.reactionType == reactionType) {
      log('🗑️ [ChatScreen] User toggling same reaction - removing');
      _removeReaction(message, reactionType);
      return;
    }

    // Optimistic UI update - update local state immediately
    final currentReactions = List<MessageReaction>.from(message.reactions);
    MessageReaction? optimisticReaction;

    if (hasUserReacted && existingReaction != null) {
      // Update existing reaction optimistically
      optimisticReaction = MessageReaction(
        id: existingReaction.id,
        messageId: message.id,
        userId: _currentUserId ?? existingReaction.userId,
        reactionType: reactionType,
        userName: existingReaction.userName,
      );
      // Remove old reaction and add new one
      currentReactions.removeWhere((r) => r.id == existingReaction!.id);
      currentReactions.add(optimisticReaction);
    } else {
      // Add new reaction optimistically
      optimisticReaction = MessageReaction(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        messageId: message.id,
        userId: _currentUserId ?? '',
        reactionType: reactionType,
        userName: 'You', // Will be updated from server
      );
      currentReactions.add(optimisticReaction);
    }

    // Update UI immediately (optimistic update)
    setState(() {
      _messages[index] = _messages[index].copyWith(
        reactions: currentReactions,
      );
    });

    _reactionsUpdateInProgress.add(message.id);
    _lastReactionUpdateTime = DateTime.now();

    // Call appropriate API
    try {
      ApiResponse<MessageReaction> response;
      if (hasUserReacted && existingReaction != null) {
        // User already reacted with different type - UPDATE existing reaction (PUT API)
        log('🔄 [ChatScreen] Calling PUT API to UPDATE reaction: ${existingReaction.reactionType} → $reactionType (message ${message.id})');
        response = await _roomService.updateReaction(
          messageId: message.id,
          reactionType: reactionType,
        );
      } else {
        // User hasn't reacted - ADD new reaction (POST API)
        log('➕ [ChatScreen] Calling POST API to ADD reaction: $reactionType → message ${message.id}');
        response = await _roomService.addReaction(
          messageId: message.id,
          reactionType: reactionType,
        );
      }

      if (response.statusCode == 429) {
        // Rate limit error - set cooldown and revert optimistic update
        _reactionUpdateCooldownUntil =
            DateTime.now().add(_reactionUpdateCooldown);
        log('⚠️ [ChatScreen] Rate limit (429) on reaction update. Cooldown until: $_reactionUpdateCooldownUntil');

        // Revert optimistic update
        setState(() {
          _messages[index] = _messages[index].copyWith(
            reactions: message.reactions, // Revert to original
          );
        });

        if (mounted) {
          EnhancedToast.warning(
            context,
            title: 'Too Many Requests',
            message: 'Please wait 30s before updating reactions again.',
          );
        }
        return;
      }

      if (!response.success) {
        // Revert optimistic update on error
        setState(() {
          _messages[index] = _messages[index].copyWith(
            reactions: message.reactions, // Revert to original
          );
        });

        // Show error only for non-network errors
        if (response.statusCode != null &&
            response.statusCode! >= 400 &&
            response.statusCode! < 500) {
          if (response.statusCode == 401) {
            EnhancedToast.error(
              context,
              title: 'Unauthorized',
              message: 'Please log in again.',
            );
          } else if (response.statusCode == 400) {
            EnhancedToast.error(
              context,
              title: 'Invalid Reaction',
              message: response.error ?? 'Invalid reaction type.',
            );
          } else {
            EnhancedToast.error(
              context,
              title: 'Error',
              message: response.error ??
                  'Failed to ${hasUserReacted ? 'update' : 'add'} reaction.',
            );
          }
        }
        // Network errors fail silently (no toast)
      } else {
        // Success - update with server response (more accurate than optimistic update)
        if (response.data != null) {
          final serverReaction = response.data!;
          final updatedReactions =
              List<MessageReaction>.from(message.reactions);

          // Remove optimistic reaction and add server reaction
          if (hasUserReacted && existingReaction != null) {
            updatedReactions.removeWhere((r) =>
                r.id == existingReaction!.id || r.id == optimisticReaction!.id);
          } else {
            updatedReactions.removeWhere((r) => r.id == optimisticReaction!.id);
          }
          updatedReactions.add(serverReaction);

          setState(() {
            _messages[index] = _messages[index].copyWith(
              reactions: updatedReactions,
            );
          });
        }

        // Don't immediately fetch reactions - use server response instead
        // Only fetch if we need to get all reactions (e.g., other users' reactions)
        // Add a delay before fetching to avoid rate limits
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            loadReactionsForMessage(message.id);
          }
        });
      }
    } catch (e) {
      // Revert optimistic update on exception
      setState(() {
        _messages[index] = _messages[index].copyWith(
          reactions: message.reactions, // Revert to original
        );
      });
      // Network failure - fail silently
      log('❌ [ChatScreen] Exception ${hasUserReacted ? 'updating' : 'adding'} reaction: $e');
    } finally {
      _reactionsUpdateInProgress.remove(message.id);
    }
  }

  Widget _buildEmojiPicker() {
    final isDarkTheme = _chatTheme == ThemeMode.dark ||
        (_chatTheme == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    // Comprehensive emoji list organized by categories with icons
    final emojiCategories = {
      'Smileys': {
        'icon': '😀',
        'emojis': [
          '😀',
          '😃',
          '😄',
          '😁',
          '😆',
          '😅',
          '😂',
          '🤣',
          '😊',
          '😇',
          '🙂',
          '🙃',
          '😉',
          '😌',
          '😍',
          '🥰',
          '😘',
          '😗',
          '😙',
          '😚',
          '😋',
          '😛',
          '😝',
          '😜',
          '🤪',
          '🤨',
          '🧐',
          '🤓',
          '😎',
          '🤩',
          '🥳',
          '😏',
          '😒',
          '😞',
          '😔',
          '😟',
          '😕',
          '🙁',
          '☹️',
          '😣',
          '😖',
          '😫',
          '😩',
          '🥺',
          '😢',
          '😭',
          '😤',
          '😠',
          '😡',
          '🤬',
          '🤯',
          '😳',
          '🥵',
          '🥶',
          '😱',
          '😨',
          '😰',
          '😥',
          '😓'
        ]
      },
      'Gestures': {
        'icon': '🤗',
        'emojis': [
          '🤗',
          '🤔',
          '🤭',
          '🤫',
          '🤥',
          '😶',
          '😐',
          '😑',
          '😬',
          '🙄',
          '😯',
          '😦',
          '😧',
          '😮',
          '😲',
          '🥱',
          '😴',
          '🤤',
          '😪',
          '😵',
          '🤐',
          '🥴',
          '🤢',
          '🤮',
          '🤧',
          '😷',
          '🤒',
          '🤕',
          '🤑',
          '🤠',
          '😈',
          '👿',
          '👹',
          '👺',
          '🤡',
          '💩',
          '👻',
          '💀',
          '☠️',
          '👽',
          '👾',
          '🤖',
          '🎃'
        ]
      },
      'Hearts': {
        'icon': '❤️',
        'emojis': [
          '❤️',
          '🧡',
          '💛',
          '💚',
          '💙',
          '💜',
          '🖤',
          '🤍',
          '🤎',
          '💔',
          '❣️',
          '💕',
          '💞',
          '💓',
          '💗',
          '💖',
          '💘',
          '💝',
          '💟'
        ]
      },
      'Hands': {
        'icon': '👋',
        'emojis': [
          '👋',
          '🤚',
          '🖐',
          '✋',
          '🖖',
          '👌',
          '🤏',
          '✌️',
          '🤞',
          '🤟',
          '🤘',
          '🤙',
          '👈',
          '👉',
          '👆',
          '🖕',
          '👇',
          '☝️',
          '👍',
          '👎',
          '✊',
          '👊',
          '🤛',
          '🤜',
          '👏',
          '🙌',
          '👐',
          '🤲',
          '🤝',
          '🙏'
        ]
      },
      'Activities': {
        'icon': '🎮',
        'emojis': [
          '🎮',
          '🕹️',
          '🎯',
          '🎲',
          '🧩',
          '♟️',
          '🎨',
          '🖼️',
          '🎭',
          '🎪',
          '🎬',
          '🎤',
          '🎧',
          '🎼',
          '🎹',
          '🥁',
          '🎷',
          '🎺',
          '🎸',
          '🪕',
          '🎻'
        ]
      },
      'Food': {
        'icon': '🍕',
        'emojis': [
          '🍏',
          '🍎',
          '🍐',
          '🍊',
          '🍋',
          '🍌',
          '🍉',
          '🍇',
          '🍓',
          '🍈',
          '🍒',
          '🍑',
          '🥭',
          '🍍',
          '🥥',
          '🥝',
          '🍅',
          '🍆',
          '🥑',
          '🥦',
          '🥬',
          '🥒',
          '🌶️',
          '🌽',
          '🥕',
          '🥔',
          '🍠',
          '🥐',
          '🥯',
          '🍞',
          '🥖',
          '🥨',
          '🧀',
          '🥚',
          '🍳',
          '🥞',
          '🥓',
          '🥩',
          '🍗',
          '🍖',
          '🌭',
          '🍔',
          '🍟',
          '🍕',
          '🥪',
          '🥙',
          '🌮',
          '🌯',
          '🥗',
          '🥘',
          '🥫',
          '🍝',
          '🍜',
          '🍲',
          '🍛',
          '🍣',
          '🍱',
          '🥟',
          '🍤',
          '🍙',
          '🍚',
          '🍘',
          '🍥',
          '🥠',
          '🥮',
          '🍢',
          '🍡',
          '🍧',
          '🍨',
          '🍦',
          '🥧',
          '🍰',
          '🎂',
          '🍮',
          '🍭',
          '🍬',
          '🍫',
          '🍿',
          '🍩',
          '🍪',
          '🌰',
          '🥜',
          '🍯',
          '🥛',
          '🍼',
          '☕',
          '🍵',
          '🧃',
          '🥤',
          '🍶',
          '🍺',
          '🍻',
          '🥂',
          '🍷',
          '🥃',
          '🍸',
          '🍹',
          '🧉',
          '🍾',
          '🧊'
        ]
      },
      'Travel': {
        'icon': '🚗',
        'emojis': [
          '🚗',
          '🚕',
          '🚙',
          '🚌',
          '🚎',
          '🏎️',
          '🚓',
          '🚑',
          '🚒',
          '🚐',
          '🚚',
          '🚛',
          '🚜',
          '🛴',
          '🚲',
          '🛵',
          '🏍️',
          '🛺',
          '🚨',
          '🚔',
          '🚍',
          '🚘',
          '🚖',
          '🚡',
          '🚠',
          '🚟',
          '🚃',
          '🚋',
          '🚞',
          '🚝',
          '🚄',
          '🚅',
          '🚈',
          '🚂',
          '🚆',
          '🚇',
          '🚊',
          '🚉',
          '✈️',
          '🛫',
          '🛬',
          '🛩️',
          '💺',
          '🚁',
          '🚟',
          '🚠',
          '🚡',
          '🛰️',
          '🚀',
          '🛸'
        ]
      },
      'Symbols': {
        'icon': '✅',
        'emojis': [
          '✅',
          '☑️',
          '✔️',
          '❌',
          '❎',
          '➕',
          '➖',
          '➗',
          '✖️',
          '💯',
          '➰',
          '➿',
          '〽️',
          '✳️',
          '✴️',
          '❇️',
          '‼️',
          '⁉️',
          '❓',
          '❔',
          '❕',
          '❗',
          '〰️',
          '💱',
          '💲',
          '⚕️',
          '♻️',
          '🔱',
          '📛',
          '🔰',
          '⭕'
        ]
      },
    };

    final Map<String, GlobalKey> categoryKeys = {};

    // Initialize keys for each category
    for (var category in emojiCategories.keys) {
      categoryKeys[category] = GlobalKey();
    }

    return StatefulBuilder(
      builder: (context, setPickerState) {
        String selectedCategory = emojiCategories.keys.first;
        final ScrollController emojiScrollController = ScrollController();

        // Update selected category based on scroll position
        void updateSelectedCategoryOnScroll() {
          if (!emojiScrollController.hasClients) return;

          final scrollPosition = emojiScrollController.offset;
          double accumulatedHeight = 0;

          for (var entry in emojiCategories.entries) {
            final category = entry.key;
            final emojis = entry.value['emojis'] as List<String>;

            // Calculate approximate height for this category
            final rows = (emojis.length / 8).ceil();
            final categoryHeight =
                (rows * 50) + 60; // 50px per row + header height

            if (scrollPosition >= accumulatedHeight &&
                scrollPosition < accumulatedHeight + categoryHeight) {
              if (selectedCategory != category) {
                setPickerState(() {
                  selectedCategory = category;
                });
              }
              break;
            }

            accumulatedHeight += categoryHeight;
          }
        }

        // Listen to scroll changes
        emojiScrollController.addListener(updateSelectedCategoryOnScroll);

        void scrollToCategory(String category) {
          final key = categoryKeys[category];
          if (key?.currentContext != null) {
            Scrollable.ensureVisible(
              key!.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          setPickerState(() {
            selectedCategory = category;
          });
        }

        return Column(
          children: [
            // Enhanced Category tabs with names
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade50,
                border: Border(
                  bottom: BorderSide(
                    color: isDarkTheme
                        ? Colors.grey.shade700
                        : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: emojiCategories.length,
                itemBuilder: (context, index) {
                  final category = emojiCategories.keys.elementAt(index);
                  final isSelected = selectedCategory == category;

                  return GestureDetector(
                    onTap: () {
                      scrollToCategory(category);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDarkTheme
                                ? AppColors.primary.withOpacity(0.2)
                                : AppColors.primary.withOpacity(0.1))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: AppColors.primary,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: isSelected ? 14 : 13,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : (isDarkTheme
                                    ? Colors.white70
                                    : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Enhanced Emoji grid with better spacing and hover effects
            Expanded(
              child: ListView(
                controller: emojiScrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: emojiCategories.entries.map((entry) {
                  final category = entry.key;
                  final emojis = entry.value['emojis'] as List<String>;

                  return Column(
                    key: categoryKeys[category],
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 4, top: 12, bottom: 8),
                        child: Row(
                          children: [
                            Text(
                              entry.value['icon'] as String,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              category,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDarkTheme ? Colors.white : Colors.black87,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: emojis.length,
                        itemBuilder: (context, index) {
                          final emoji = emojis[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                final currentText = _messageController.text;
                                _messageController.text = currentText + emoji;
                                setState(() {});
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeReaction(ChatMessage message, String reactionType) async {
    // Check if message is deleted
    if (message.isDeleted) {
      EnhancedToast.warning(
        context,
        title: 'Cannot Remove Reaction',
        message: 'Deleted messages cannot have reactions removed.',
      );
      return;
    }

    // Find message by ID
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) {
      log('⚠️ [ChatScreen] Message not found: ${message.id}');
      return;
    }

    // Rate limiting: Check if already updating this message
    if (_reactionsUpdateInProgress.contains(message.id)) {
      log('⏭️ [ChatScreen] Reaction update already in progress for message: ${message.id}');
      return;
    }

    // Rate limiting: Check cooldown period
    if (_reactionUpdateCooldownUntil != null) {
      final now = DateTime.now();
      if (now.isBefore(_reactionUpdateCooldownUntil!)) {
        final remainingSeconds =
            _reactionUpdateCooldownUntil!.difference(now).inSeconds;
        log('⏸️ [ChatScreen] Reaction update on cooldown. ${remainingSeconds}s remaining');
        EnhancedToast.warning(
          context,
          title: 'Too Many Requests',
          message:
              'Please wait ${remainingSeconds}s before updating reactions.',
        );
        return;
      } else {
        _reactionUpdateCooldownUntil = null;
      }
    }

    // Rate limiting: Check minimum interval
    if (_lastReactionUpdateTime != null) {
      final timeSinceLastUpdate =
          DateTime.now().difference(_lastReactionUpdateTime!);
      if (timeSinceLastUpdate < _reactionUpdateMinInterval) {
        final waitTime = _reactionUpdateMinInterval - timeSinceLastUpdate;
        log('⏸️ [ChatScreen] Rate limiting reaction delete. Waiting ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      }
    }

    // Optimistic UI update - remove reaction immediately
    final userReaction = _getUserReaction(message);
    final currentReactions = List<MessageReaction>.from(message.reactions);
    if (userReaction != null) {
      currentReactions.removeWhere((r) => r.id == userReaction.id);
    }

    setState(() {
      _messages[index] = _messages[index].copyWith(
        reactions: currentReactions,
      );
    });

    _reactionsUpdateInProgress.add(message.id);
    _lastReactionUpdateTime = DateTime.now();

    // Call DELETE API to remove reaction
    try {
      log('🗑️ [ChatScreen] Deleting reaction for message: ${message.id}');
      final response = await _roomService.deleteReaction(messageId: message.id);

      if (response.statusCode == 429) {
        // Rate limit error - set cooldown and revert optimistic update
        _reactionUpdateCooldownUntil =
            DateTime.now().add(_reactionUpdateCooldown);
        log('⚠️ [ChatScreen] Rate limit (429) on reaction delete. Cooldown until: $_reactionUpdateCooldownUntil');

        // Revert optimistic update
        setState(() {
          _messages[index] = _messages[index].copyWith(
            reactions: message.reactions, // Revert to original
          );
        });

        if (mounted) {
          EnhancedToast.warning(
            context,
            title: 'Too Many Requests',
            message: 'Please wait 30s before updating reactions again.',
          );
        }
        return;
      }

      if (!response.success) {
        // Revert optimistic update on error
        setState(() {
          _messages[index] = _messages[index].copyWith(
            reactions: message.reactions, // Revert to original
          );
        });

        // Show error only for non-network errors
        if (response.statusCode != null &&
            response.statusCode! >= 400 &&
            response.statusCode! < 500) {
          if (response.statusCode == 401) {
            EnhancedToast.error(
              context,
              title: 'Unauthorized',
              message: 'Please log in again.',
            );
          } else {
            EnhancedToast.error(
              context,
              title: 'Error',
              message: response.error ?? 'Failed to remove reaction.',
            );
          }
        }
        // Network errors fail silently (no toast)
      } else {
        // Success - add delay before fetching to avoid rate limits
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            loadReactionsForMessage(message.id);
          }
        });
      }
    } catch (e) {
      // Revert optimistic update on exception
      setState(() {
        _messages[index] = _messages[index].copyWith(
          reactions: message.reactions, // Revert to original
        );
      });
      // Network failure - fail silently
      log('❌ [ChatScreen] Exception deleting reaction: $e');
    } finally {
      _reactionsUpdateInProgress.remove(message.id);
    }
  }

  Future<void> _editMessage(ChatMessage message) async {
    // Check if message is from current user
    if (!message.isMe) {
      EnhancedToast.warning(
        context,
        title: 'Cannot Edit',
        message: 'You can only edit your own messages.',
      );
      return;
    }

    // Cannot edit deleted messages
    if (message.isDeleted) {
      EnhancedToast.warning(
        context,
        title: 'Cannot Edit',
        message: 'Deleted messages cannot be edited.',
      );
      return;
    }

    final isDarkTheme = _chatTheme == ThemeMode.dark ||
        (_chatTheme == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final controller = TextEditingController(text: message.text);
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkTheme ? Colors.grey.shade900 : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Edit Message',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDarkTheme ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                // Text field
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 5,
                  enabled: !isSaving,
                  style: TextStyle(
                    color: isDarkTheme ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Edit your message...',
                    hintStyle: TextStyle(
                      color: isDarkTheme
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 1,
                      ),
                    ),
                    filled: true,
                    fillColor: isDarkTheme
                        ? Colors.grey.shade800
                        : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed:
                            isSaving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDarkTheme
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.blackToGreyGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final updatedText = controller.text.trim();
                                  if (updatedText.isEmpty) {
                                    EnhancedToast.warning(
                                      context,
                                      title: 'Invalid',
                                      message: 'Message cannot be empty',
                                    );
                                    return;
                                  }

                                  if (updatedText == message.text) {
                                    // No changes, just close
                                    Navigator.pop(context);
                                    return;
                                  }

                                  // Disable save button and show loading
                                  setDialogState(() {
                                    isSaving = true;
                                  });

                                  try {
                                    // Call API to edit message
                                    log('📝 [ChatScreen] Editing message: ${message.id}');
                                    final response =
                                        await _roomService.editMessage(
                                      messageId: message.id,
                                      content: updatedText,
                                    );

                                    if (!mounted) return;

                                    if (response.success &&
                                        response.data != null) {
                                      log('✅ [ChatScreen] Message edited successfully');
                                      // Update message in-place
                                      final index = _messages.indexWhere(
                                        (m) => m.id == message.id,
                                      );
                                      if (index != -1) {
                                        final existingMessage =
                                            _messages[index];
                                        final updatedRoomMessage =
                                            response.data!;
                                        final updatedChatMessage = ChatMessage(
                                          id: updatedRoomMessage.id,
                                          text: updatedRoomMessage.isDeleted
                                              ? ''
                                              : updatedRoomMessage.body,
                                          isMe: _isMessageFromCurrentUser(
                                              updatedRoomMessage),
                                          timestamp:
                                              updatedRoomMessage.createdAt,
                                          editedAt: updatedRoomMessage.editedAt,
                                          isDeleted:
                                              updatedRoomMessage.isDeleted,
                                          status: existingMessage.status,
                                          reactions:
                                              updatedRoomMessage.reactions,
                                        );

                                        setState(() {
                                          _messages[index] = updatedChatMessage;
                                        });

                                        Navigator.pop(context);

                                        // Show success toast
                                        EnhancedToast.success(
                                          context,
                                          title: 'Message Edited',
                                          message:
                                              'Your message has been updated.',
                                        );
                                      }
                                    } else {
                                      // Re-enable save button on error
                                      setDialogState(() {
                                        isSaving = false;
                                      });

                                      EnhancedToast.error(
                                        context,
                                        title: 'Failed to Edit',
                                        message: response.displayError ??
                                            'Failed to edit message. Please try again.',
                                      );
                                    }
                                  } catch (e) {
                                    log('❌ [ChatScreen] Error editing message: $e');
                                    if (!mounted) return;

                                    // Re-enable save button on error
                                    setDialogState(() {
                                      isSaving = false;
                                    });

                                    EnhancedToast.error(
                                      context,
                                      title: 'Error',
                                      message: 'Failed to edit message: $e',
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            elevation: 0,
                          ),
                          child: isSaving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    // Check if message is from current user
    if (!message.isMe) {
      EnhancedToast.warning(
        context,
        title: 'Cannot Delete',
        message: 'You can only delete your own messages.',
      );
      return;
    }

    // Cannot delete already deleted messages
    if (message.isDeleted) {
      EnhancedToast.warning(
        context,
        title: 'Already Deleted',
        message: 'This message has already been deleted.',
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
              const Text(
                'Delete Message',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete this message? This action cannot be undone.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
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
                        onPressed: () => Navigator.of(context).pop(true),
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

    // If user cancelled, return
    if (shouldDelete != true) {
      return;
    }

    try {
      // Call API to delete message
      log('🗑️ [ChatScreen] Deleting message: ${message.id}');
      final response = await _roomService.deleteMessage(
        messageId: message.id,
      );

      if (!mounted) return;

      if (response.success && response.data != null) {
        log('✅ [ChatScreen] Message deleted successfully');
        // Update message in-place (soft delete)
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          final deletedRoomMessage = response.data!;
          final deletedChatMessage = ChatMessage(
            id: deletedRoomMessage.id,
            text: deletedRoomMessage.isDeleted ? '' : deletedRoomMessage.body,
            isMe: _isMessageFromCurrentUser(deletedRoomMessage),
            timestamp: deletedRoomMessage.createdAt,
            editedAt: deletedRoomMessage.editedAt,
            isDeleted: deletedRoomMessage.isDeleted,
            status: message.status,
            reactions: deletedRoomMessage.reactions,
          );

          setState(() {
            _messages[index] = deletedChatMessage;
          });

          // Show success toast
          EnhancedToast.success(
            context,
            title: 'Message Deleted',
            message: 'Your message has been deleted.',
          );
        }
      } else {
        // Show error but don't change message UI
        EnhancedToast.error(
          context,
          title: 'Failed to Delete',
          message: response.displayError ??
              'Failed to delete message. Please try again.',
        );
      }
    } catch (e) {
      log('❌ [ChatScreen] Error deleting message: $e');
      if (!mounted) return;

      // Show error but don't change message UI
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to delete message: $e',
      );
    }
  }

  StreamSubscription<audio.PlayerState>? _audioStateSubscription;

  Future<void> _toggleAudioPlayback(ChatMessage message) async {
    if (message.audioFile == null &&
        (message.audioUrl == null || message.audioUrl!.isEmpty)) {
      return;
    }

    try {
      if (_isPlayingAudio && _playingAudioId == message.id) {
        // Pause current message
        await _audioPlayer.pause();
        setState(() {
          _isPlayingAudio = false;
          _playingAudioId = null;
        });
        _audioStateSubscription?.cancel();
        _audioStateSubscription = null;
      } else {
        // Stop any currently playing audio
        if (_playingAudioId != null && _playingAudioId != message.id) {
          await _audioPlayer.stop();
          _audioStateSubscription?.cancel();
        }

        // Load and play new audio
        if (message.audioFile != null) {
          await _audioPlayer.setFilePath(message.audioFile!.path);
        } else if (message.audioUrl != null) {
          await _audioPlayer.setUrl(message.audioUrl!);
        }

        await _audioPlayer.play();
        setState(() {
          _isPlayingAudio = true;
          _playingAudioId = message.id;
        });

        // Listen for completion - only for this message
        _audioStateSubscription?.cancel();
        _audioStateSubscription =
            _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == audio.ProcessingState.completed) {
            if (mounted && _playingAudioId == message.id) {
              setState(() {
                _isPlayingAudio = false;
                _playingAudioId = null;
              });
            }
            _audioStateSubscription?.cancel();
            _audioStateSubscription = null;
          }
        });
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to play audio: ${e.toString()}',
      );
      setState(() {
        _isPlayingAudio = false;
        _playingAudioId = null;
      });
      _audioStateSubscription?.cancel();
      _audioStateSubscription = null;
    }
  }

  Widget _buildTypingIndicator() {
    final isDarkTheme = _chatTheme == ThemeMode.dark ||
        (_chatTheme == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              widget.contact.initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkTheme ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
                const SizedBox(width: 8),
                Text(
                  'Typing...',
                  style: TextStyle(
                    color: isDarkTheme
                        ? Colors.grey.shade400
                        : Colors.grey.shade700,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, child) {
        final delay = index * 0.2;
        final value = (_waveformController.value + delay) % 1.0;
        final opacity = (math.sin(value * math.pi * 2) + 1) / 2;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3 + opacity * 0.7),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildVoiceRecordingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Recording...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDuration(_recordingDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              _buildWaveform(),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Cancel button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: GestureDetector(
                      onTap: _cancelVoiceRecording,
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                  // Send button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: GestureDetector(
                      onTap: _sendVoiceMessage,
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 32,
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
  }

  Widget _buildWaveform() {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _waveformData.asMap().entries.map((entry) {
            final index = entry.key;
            final baseHeight = entry.value;
            final animationValue =
                (_waveformController.value + index * 0.1) % 1.0;
            final height = baseHeight *
                (0.5 + 0.5 * math.sin(animationValue * math.pi * 2));
            return Container(
              width: 3,
              height: 20 + height * 40,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Convert UTC DateTime to Indian Standard Time (IST - UTC+5:30)
  DateTime _toIST(DateTime dateTime) {
    // If the DateTime is already in UTC (has isUtc flag), convert to IST
    // Otherwise, assume it's UTC and convert to IST
    final utcDateTime = dateTime.isUtc ? dateTime : dateTime.toUtc();
    // IST is UTC+5:30
    return utcDateTime.add(const Duration(hours: 5, minutes: 30));
  }

  String _formatTime(DateTime timestamp) {
    // Convert to IST before formatting
    final istTime = _toIST(timestamp);
    // Use 12-hour format with AM/PM (same as chat history page)
    return DateFormat('h:mm a').format(istTime);
  }

  Widget _buildErrorState() {
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
                color: Colors.red.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 28,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load messages',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Please check your connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isOpeningRoom || _isLoading
                  ? null // Disable button while loading
                  : () {
                      // Reset error state before retry
                      setState(() {
                        _hasError = false;
                        _errorMessage = null;
                      });
                      _openRoom();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
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
              child: Icon(
                Icons.chat_bubble_outline,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation',
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

  void _showClearChatDialog() {
    showDialog(
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
                'Clear Chat',
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
                'Are you sure you want to clear all messages from this chat? This action cannot be undone.',
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
                        onPressed: () => Navigator.of(context).pop(),
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
                  // Clear Button
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
                        onPressed: () {
                          Navigator.of(context).pop();
                          _clearChat();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Clear',
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
  }

  Future<void> _clearChat() async {
    try {
      // Get company_id for API call
      final companyId = await _apiService.getSelectedSocietyId();
      if (companyId == null) {
        if (mounted) {
          EnhancedToast.error(
            context,
            title: 'Error',
            message: 'Unable to get society ID. Please try again.',
          );
        }
        return;
      }

      // Ensure we have a valid room ID
      if (_currentRoomId == null || !_isUuid(_currentRoomId)) {
        if (mounted) {
          EnhancedToast.error(
            context,
            title: 'Error',
            message: 'Chat room not available. Please try again.',
          );
        }
        return;
      }

      // Call API to clear chat
      log('Clearing chat for room: $_currentRoomId');
      final response = await _chatService.clearChat(
        roomId: _currentRoomId!,
        companyId: companyId,
      );

      if (!mounted) return;

      if (response.success) {
        // Clear messages locally after successful API call
        setState(() {
          _messages.clear();
        });

        log('Chat cleared for room: $_currentRoomId');

        EnhancedToast.success(
          context,
          title: 'Chat Cleared',
          message: 'All messages have been cleared successfully.',
        );
      } else {
        // Show error if API call failed
        EnhancedToast.error(
          context,
          title: 'Error',
          message: response.error ?? 'Failed to clear chat. Please try again.',
        );
      }
    } catch (e) {
      log('Error clearing chat: $e');
      if (mounted) {
        EnhancedToast.error(
          context,
          title: 'Error',
          message: 'An error occurred while clearing chat. Please try again.',
        );
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      isDismissible: true,
      enableDrag: true,
      builder: (BuildContext context) {
        final isDarkTheme = _chatTheme == ThemeMode.dark ||
            (_chatTheme == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness == Brightness.dark);
        final sheetColor = isDarkTheme ? Colors.grey.shade900 : Colors.white;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        return AnimatedPadding(
          padding: EdgeInsets.only(bottom: bottomInset),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: FractionallySizedBox(
            widthFactor: 1,
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          _buildAttachmentOption(Icons.photo_library, 'Gallery',
                              () => _pickMultipleMedia()),
                          _buildAttachmentOption(Icons.camera_alt, 'Camera',
                              () => _pickImage(ImageSource.camera)),
                          _buildAttachmentOption(Icons.insert_drive_file,
                              'Document', _pickDocument),
                          _buildAttachmentOption(
                              Icons.videocam, 'Video', _pickVideo),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption(
      IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Multiple media selection from gallery
  Future<void> _pickMultipleMedia() async {
    try {
      // Use pickMultipleMedia to support both images and videos
      final List<XFile> pickedFiles = await _imagePicker.pickMultipleMedia(
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        // Process each file based on its type
        for (var xFile in pickedFiles) {
          final file = File(xFile.path);

          // Check if it's a video by extension or mime type
          final pathLower = xFile.path.toLowerCase();
          final isVideo = pathLower.endsWith('.mp4') ||
              pathLower.endsWith('.mov') ||
              pathLower.endsWith('.avi') ||
              pathLower.endsWith('.mkv') ||
              pathLower.endsWith('.webm') ||
              pathLower.endsWith('.m4v') ||
              pathLower.endsWith('.3gp') ||
              (xFile.mimeType != null && xFile.mimeType!.startsWith('video/'));

          if (isVideo) {
            // Handle video
            if (pickedFiles.length == 1) {
              // Single video - show preview
              final previewResult =
                  await _showMediaPreview(xFile, isVideo: true);
              if (previewResult == true) {
                await _sendVideoMessageWithProgress(file);
              }
            } else {
              // Multiple files - send without preview
              await _sendVideoMessageWithProgress(file);
            }
          } else {
            // Handle image
            if (pickedFiles.length == 1) {
              // Single image - show preview
              final previewResult =
                  await _showMediaPreview(xFile, isVideo: false);
              if (previewResult == true) {
                final compressedFile = await _compressImage(file);
                if (compressedFile != null) {
                  await _sendImageMessageWithProgress(compressedFile);
                } else {
                  await _sendImageMessageWithProgress(file);
                }
              }
            } else {
              // Multiple files - send without preview
              final compressedFile = await _compressImage(file);
              if (compressedFile != null) {
                await _sendImageMessageWithProgress(compressedFile);
              } else {
                await _sendImageMessageWithProgress(file);
              }
            }
          }

          // Small delay between uploads to avoid overwhelming the server
          if (pickedFiles.indexOf(xFile) < pickedFiles.length - 1) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to pick media: ${e.toString()}',
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Show preview before sending
        final previewResult =
            await _showMediaPreview(pickedFile, isVideo: false);
        if (previewResult == true) {
          // Compress image before sending
          final compressedFile = await _compressImage(File(pickedFile.path));
          if (compressedFile != null) {
            await _sendImageMessageWithProgress(compressedFile);
          } else {
            await _sendImageMessageWithProgress(File(pickedFile.path));
          }
        }
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to pick image: ${e.toString()}',
      );
    }
  }

  // Show media preview before sending
  Future<bool?> _showMediaPreview(XFile file, {required bool isVideo}) async {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        final isDarkTheme = _chatTheme == ThemeMode.dark ||
            (_chatTheme == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness == Brightness.dark);

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            decoration: BoxDecoration(
              color: isDarkTheme ? Colors.grey.shade900 : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Preview
                Flexible(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: isVideo
                        ? _VideoPreviewWidget(videoFile: File(file.path))
                        : Image.file(
                            File(file.path),
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
                // Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.send),
                        label: const Text('Send'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<File?> _compressImage(File file) async {
    try {
      final filePath = file.absolute.path;
      final lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
      final splitted = filePath.substring(0, (lastIndex));
      final outPath = "${splitted}_compressed.jpg";

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      return compressedFile != null ? File(compressedFile.path) : null;
    } catch (e) {
      return null;
    }
  }

  // Send image with upload progress
  Future<void> _sendImageMessageWithProgress(File imageFile) async {
    // Ensure we have a room ID
    final roomId = _currentRoomId ?? widget.contact.id;
    if (roomId == null || roomId.isEmpty) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Room ID not available. Please try again.',
      );
      return;
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = ChatMessage(
      id: messageId,
      text: '📷 Image',
      isMe: true,
      timestamp: DateTime.now(),
      imageFile: imageFile,
      status: MessageStatus.sending,
      replyTo: _replyingTo,
    );

    setState(() {
      _messages.add(message);
      _uploadingFiles[messageId] = true;
      _uploadProgress[messageId] = 0.0;
      _replyingTo = null;
    });

    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      // Step 1: Upload file to S3 via API
      log('📤 [ChatScreen] Uploading image to S3 for room: $roomId');
      final uploadResponse = await _roomService.uploadFileToS3(
        roomId: roomId,
        file: imageFile,
        onSendProgress: (sent, total) {
          if (mounted && total > 0) {
            final progress = sent / total;
            setState(() {
              _uploadProgress[messageId] = progress;
            });
          }
        },
      );

      if (!mounted) return;

      if (!uploadResponse.success || uploadResponse.data == null) {
        log('❌ [ChatScreen] Failed to upload image to S3: ${uploadResponse.error}');
        // Update message to show error - keep as sending to indicate failure
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          setState(() {
            _uploadingFiles[messageId] = false;
            _uploadProgress.remove(messageId);
            // Keep status as sending to indicate it failed
          });
        }
        EnhancedToast.error(
          context,
          title: 'Upload Failed',
          message: uploadResponse.error ??
              'Failed to upload image. Please try again.',
        );
        return;
      }

      var fileUrl = uploadResponse.data!['file_url'] as String?;
      final fileKey = uploadResponse.data!['file_key'] as String?;
      final mimeType = uploadResponse.data!['mime_type'] as String?;
      final size = uploadResponse.data!['size'] as int?;

      if (fileUrl == null || fileUrl.isEmpty) {
        log('❌ [ChatScreen] No file_url in upload response');
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          setState(() {
            _uploadingFiles[messageId] = false;
            _uploadProgress.remove(messageId);
            // Keep status as sending to indicate it failed
          });
        }
        EnhancedToast.error(
          context,
          title: 'Upload Failed',
          message: 'Invalid response from server. Please try again.',
        );
        return;
      }

      // Transform localhost URLs to proper server URLs
      final originalUrl = fileUrl;
      fileUrl = RoomService.transformLocalhostUrl(fileUrl);
      if (fileUrl != originalUrl) {
        log('🔄 [ChatScreen] Transformed fileUrl from localhost: $originalUrl -> $fileUrl');
      }

      log('✅ [ChatScreen] Image uploaded to S3: $fileUrl');

      // Step 2: Send message via WebSocket with file_url
      // Build content as JSON string with file metadata
      final contentMap = {
        'file_url': fileUrl,
        if (fileKey != null) 'file_key': fileKey,
        if (mimeType != null) 'mime_type': mimeType,
        if (size != null) 'size': size,
      };
      final content = jsonEncode(contentMap);

      log('📤 [ChatScreen] Sending WebSocket message with file_url: $fileUrl');
      final sent = await _chatService.sendMessage(
        roomId: roomId,
        content: content,
        messageType: 'image',
        replyTo: _replyingTo?.id,
      );

      if (!mounted) return;

      if (sent) {
        log('✅ [ChatScreen] WebSocket message sent successfully');
        // Update message with file URL and status so it renders immediately
        // This fixes issue where image doesn't show after upload
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          setState(() {
            _uploadingFiles[messageId] = false;
            _uploadProgress.remove(messageId);
            // CRITICAL: Keep status as sending temporarily so duplicate detection can match it
            // Status will be updated to sent when WebSocket confirms the message
            _messages[index] = _messages[index].copyWith(
              status: MessageStatus
                  .sending, // Keep as sending for duplicate detection
              imageUrl: fileUrl, // Store S3 URL so image renders immediately
              text:
                  '', // Clear text to hide JSON - image will be rendered instead
            );
          });
        }
      } else {
        log('❌ [ChatScreen] Failed to send WebSocket message');
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          setState(() {
            _uploadingFiles[messageId] = false;
            _uploadProgress.remove(messageId);
            // Keep status as sending to indicate it failed
          });
        }
        EnhancedToast.error(
          context,
          title: 'Send Failed',
          message: 'Failed to send message. Please try again.',
        );
      }
    } catch (e) {
      log('❌ [ChatScreen] Error uploading/sending image: $e');
      if (!mounted) return;
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        setState(() {
          _uploadingFiles[messageId] = false;
          _uploadProgress.remove(messageId);
          // Keep status as sending to indicate it failed
        });
      }
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to upload image: ${e.toString()}',
      );
    }
  }

  void _sendImageMessage(File imageFile) {
    _sendImageMessageWithProgress(imageFile);
  }

  // Simulate file upload with progress
  Future<void> _simulateFileUpload(String messageId, File file) async {
    final fileSize = await file.length();
    const chunkSize = 1024 * 100; // 100KB chunks
    final chunks = (fileSize / chunkSize).ceil();

    for (int i = 0; i <= chunks; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) break;

      final progress = (i / chunks).clamp(0.0, 1.0);
      setState(() {
        _uploadProgress[messageId] = progress;
      });
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (pickedFile != null) {
        // Show preview before sending (like WhatsApp)
        final previewResult =
            await _showMediaPreview(pickedFile, isVideo: true);
        if (previewResult == true) {
          final file = File(pickedFile.path);
          await _sendVideoMessageWithProgress(file);
        }
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to pick video: ${e.toString()}',
      );
    }
  }

  Future<void> _sendVideoMessageWithProgress(File videoFile) async {
    final roomId = _currentRoomId ?? widget.contact.id;
    if (roomId == null || roomId.isEmpty) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Room ID not available. Please try again.',
      );
      return;
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = ChatMessage(
      id: messageId,
      text: '🎥 Video',
      isMe: true,
      timestamp: DateTime.now(),
      isVideo: true,
      videoFile: videoFile,
      status: MessageStatus.sending,
      replyTo: _replyingTo,
    );

    setState(() {
      _messages.add(message);
      _uploadingFiles[messageId] = true;
      _uploadProgress[messageId] = 0.0;
      _replyingTo = null;
    });

    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      log('📤 [ChatScreen] Uploading video to S3 for room: $roomId');
      final uploadResponse = await _roomService.uploadFileToS3(
        roomId: roomId,
        file: videoFile,
        onSendProgress: (sent, total) {
          if (mounted && total > 0) {
            final progress = sent / total;
            setState(() {
              _uploadProgress[messageId] = progress;
            });
          }
        },
      );

      if (!mounted) return;

      if (!uploadResponse.success || uploadResponse.data == null) {
        log('❌ [ChatScreen] Failed to upload video to S3: ${uploadResponse.error}');
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          setState(() {
            _uploadingFiles[messageId] = false;
            _uploadProgress.remove(messageId);
          });
        }
        EnhancedToast.error(
          context,
          title: 'Upload Failed',
          message: uploadResponse.error ??
              'Failed to upload video. Please try again.',
        );
        return;
      }

      var fileUrl = uploadResponse.data!['file_url'] as String?;
      final fileKey = uploadResponse.data!['file_key'] as String?;
      final mimeType = uploadResponse.data!['mime_type'] as String?;
      final size = uploadResponse.data!['size'] as int?;

      if (fileUrl == null || fileUrl.isEmpty) {
        log('❌ [ChatScreen] No file_url in upload response');
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          setState(() {
            _uploadingFiles[messageId] = false;
            _uploadProgress.remove(messageId);
          });
        }
        EnhancedToast.error(
          context,
          title: 'Upload Failed',
          message: 'Invalid response from server. Please try again.',
        );
        return;
      }

      final originalUrl = fileUrl;
      fileUrl = RoomService.transformLocalhostUrl(fileUrl);
      if (fileUrl != originalUrl) {
        log('🔄 [ChatScreen] Transformed video fileUrl from localhost: $originalUrl -> $fileUrl');
      }

      final contentMap = {
        'file_url': fileUrl,
        if (fileKey != null) 'file_key': fileKey,
        if (mimeType != null) 'mime_type': mimeType,
        if (mimeType != null) 'file_type': mimeType,
        if (size != null) 'size': size,
        'file_name': videoFile.path.split('/').last,
      };
      final content = jsonEncode(contentMap);

      log('📤 [ChatScreen] Sending WebSocket video message with file_url: $fileUrl');
      final sent = await _chatService.sendMessage(
        roomId: roomId,
        content: content,
        messageType: 'file',
        replyTo: _replyingTo?.id,
      );

      if (!mounted) return;

      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        setState(() {
          _uploadingFiles[messageId] = false;
          _uploadProgress.remove(messageId);
          _messages[index] = _messages[index].copyWith(
            status: sent ? MessageStatus.sent : MessageStatus.sending,
            documentUrl: _messages[index].documentUrl,
            imageUrl: _messages[index].imageUrl,
            isVideo: true,
            videoUrl: fileUrl,
          );
        });
      }

      if (!sent) {
        EnhancedToast.error(
          context,
          title: 'Send Failed',
          message: 'Uploaded, but failed to send video. Please retry.',
        );
      }
    } catch (e) {
      log('❌ [ChatScreen] Error uploading/sending video: $e');
      if (!mounted) return;
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        setState(() {
          _uploadingFiles[messageId] = false;
          _uploadProgress.remove(messageId);
        });
      }
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to send video: ${e.toString()}',
      );
    }
  }

  Future<void> _pickDocument() async {
    try {
      // Pick file using file_picker (no permission needed on most platforms)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt'
        ],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileExtension = fileName.split('.').last.toLowerCase();
        final fileType = _getFileTypeFromExtension(fileExtension);

        // Check file size (limit to 10MB)
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) {
          EnhancedToast.warning(
            context,
            title: 'File Too Large',
            message: 'File size must be less than 10MB.',
          );
          return;
        }

        // Show document preview with file info
        final shouldSend =
            await _showDocumentPreview(file, fileName, fileSize, fileType);
        if (shouldSend == true) {
          await _sendDocumentMessageWithProgress(file, fileName, fileType);
        }
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to pick document: ${e.toString()}',
      );
    }
  }

  // Show document preview with file details
  Future<bool?> _showDocumentPreview(
      File file, String fileName, int fileSize, String fileType) async {
    final isDarkTheme = _chatTheme == ThemeMode.dark ||
        (_chatTheme == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkTheme ? Colors.grey.shade900 : Colors.white,
          title: Text(
            'Document Preview',
            style: TextStyle(color: isDarkTheme ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getDocumentColor(fileType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getDocumentIcon(fileType),
                      color: _getDocumentColor(fileType),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: TextStyle(
                            color: isDarkTheme ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFileSize(fileSize),
                          style: TextStyle(
                            color: isDarkTheme
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                    color: isDarkTheme
                        ? Colors.grey.shade300
                        : Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getFileTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
        return 'doc';
      case 'xls':
      case 'xlsx':
        return 'xls';
      case 'ppt':
      case 'pptx':
        return 'ppt';
      default:
        return 'other';
    }
  }

  // Send document with upload progress
  Future<void> _sendDocumentMessageWithProgress(
      File file, String fileName, String fileType) async {
    // Ensure we have a room ID
    final roomId = _currentRoomId ?? widget.contact.id;
    if (roomId == null || roomId.isEmpty) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Room ID not available. Please try again.',
      );
      return;
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = ChatMessage(
      id: messageId,
      text: '📎 $fileName',
      isMe: true,
      timestamp: DateTime.now(),
      isDocument: true,
      documentName: fileName,
      documentType: fileType,
      documentFile: file,
      status: MessageStatus.sending,
      replyTo: _replyingTo,
    );

    setState(() {
      _messages.add(message);
      _uploadingFiles[messageId] = true;
      _uploadProgress[messageId] = 0.0;
      _replyingTo = null;
    });

    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      // Step 1: Upload file to S3 via API
      log('📤 [ChatScreen] Uploading document to S3 for room: $roomId');
      final uploadResponse = await _roomService.uploadFileToS3(
        roomId: roomId,
        file: file,
        onSendProgress: (sent, total) {
          if (mounted && total > 0) {
            final progress = sent / total;
            setState(() {
              _uploadProgress[messageId] = progress;
            });
          }
        },
      );

      if (!mounted) return;

      if (!uploadResponse.success || uploadResponse.data == null) {
        log('❌ [ChatScreen] Failed to upload document to S3: ${uploadResponse.error}');
        // Update message to show error - keep as sending to indicate failure
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          setState(() {
            _uploadingFiles[messageId] = false;
            _uploadProgress.remove(messageId);
            // Keep status as sending to indicate it failed
          });
        }
        EnhancedToast.error(
          context,
          title: 'Upload Failed',
          message: uploadResponse.error ??
              'Failed to upload document. Please try again.',
        );
        return;
      }

      var fileUrl = uploadResponse.data!['file_url'] as String?;
      final fileKey = uploadResponse.data!['file_key'] as String?;
      final mimeType = uploadResponse.data!['mime_type'] as String?;
      final size = uploadResponse.data!['size'] as int?;

      if (fileUrl == null || fileUrl.isEmpty) {
        log('❌ [ChatScreen] No file_url in upload response');
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          setState(() {
            _uploadingFiles[messageId] = false;
            _uploadProgress.remove(messageId);
            // Keep status as sending to indicate it failed
          });
        }
        EnhancedToast.error(
          context,
          title: 'Upload Failed',
          message: 'Invalid response from server. Please try again.',
        );
        return;
      }

      // Transform localhost URLs to proper server URLs
      final originalUrl = fileUrl;
      fileUrl = RoomService.transformLocalhostUrl(fileUrl);
      if (fileUrl != originalUrl) {
        log('🔄 [ChatScreen] Transformed fileUrl from localhost: $originalUrl -> $fileUrl');
      }

      log('✅ [ChatScreen] Document uploaded to S3: $fileUrl');

      // Step 2: Send message via WebSocket with file_url
      // Build content as JSON string with file metadata
      final contentMap = {
        'file_url': fileUrl,
        'file_name': fileName,
        'file_type': fileType,
        if (fileKey != null) 'file_key': fileKey,
        if (mimeType != null) 'mime_type': mimeType,
        if (size != null) 'size': size,
      };
      final content = jsonEncode(contentMap);

      log('📤 [ChatScreen] Sending WebSocket message with file_url: $fileUrl');
      final sent = await _chatService.sendMessage(
        roomId: roomId,
        content: content,
        messageType: 'file',
        replyTo: _replyingTo?.id,
      );

      if (!mounted) return;

      if (sent) {
        log('✅ [ChatScreen] WebSocket message sent successfully');
        // Update message with file URL and status so it renders immediately
        // This fixes issue where document doesn't show after upload
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          setState(() {
            _uploadingFiles[messageId] = false;
            _uploadProgress.remove(messageId);
            // CRITICAL: Keep status as sending temporarily so duplicate detection can match it
            // Status will be updated to sent when WebSocket confirms the message
            _messages[index] = _messages[index].copyWith(
              status: MessageStatus
                  .sending, // Keep as sending for duplicate detection
              documentUrl:
                  fileUrl, // Store S3 URL so document renders immediately
              text: '📎 ${fileName}', // Show file name instead of JSON
            );
          });
        }
      } else {
        log('❌ [ChatScreen] Failed to send WebSocket message');
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          setState(() {
            _uploadingFiles[messageId] = false;
            _uploadProgress.remove(messageId);
            // Keep status as sending to indicate it failed
          });
        }
        EnhancedToast.error(
          context,
          title: 'Send Failed',
          message: 'Failed to send message. Please try again.',
        );
      }
    } catch (e) {
      log('❌ [ChatScreen] Error uploading/sending document: $e');
      if (!mounted) return;
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        setState(() {
          _uploadingFiles[messageId] = false;
          _uploadProgress.remove(messageId);
          // Keep status as sending to indicate it failed
        });
      }
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to upload document: ${e.toString()}',
      );
    }
  }

  void _sendDocumentMessage(File file, String fileName, String fileType) {
    _sendDocumentMessageWithProgress(file, fileName, fileType);
  }

  IconData _getDocumentIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
        return Icons.description;
      case 'xls':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getDocumentColor(String type) {
    switch (type) {
      case 'pdf':
        return Colors.red;
      case 'doc':
        return Colors.blue;
      case 'xls':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  Future<void> _shareLocation() async {
    try {
      EnhancedToast.info(
        context,
        title: 'Getting Location',
        message: 'Fetching your current location...',
      );

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        EnhancedToast.warning(
          context,
          title: 'Location Disabled',
          message: 'Please enable location services to share your location.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          EnhancedToast.warning(
            context,
            title: 'Permission Denied',
            message: 'Location permission is required to share location.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        EnhancedToast.warning(
          context,
          title: 'Permission Required',
          message: 'Please enable location permission in settings.',
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Show location preview with map
      final shouldSend = await _showLocationPreview(position);
      if (shouldSend == true) {
        final locationMessage =
            '📍 Location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}\n\nView on map: https://maps.google.com/?q=${position.latitude},${position.longitude}';

        setState(() {
          _messages.add(
            ChatMessage(
              text: locationMessage,
              isMe: true,
              timestamp: DateTime.now(),
              isLocation: true,
              replyTo: _replyingTo,
            ),
          );
          _replyingTo = null;
        });

        _messageController.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to get location: ${e.toString()}',
      );
    }
  }

  Future<void> _shareContact() async {
    try {
      // Check and request permission
      bool hasPermission = await FlutterContacts.requestPermission();

      if (!hasPermission) {
        EnhancedToast.warning(
          context,
          title: 'Permission Required',
          message: 'Contact permission is required to share contacts.',
        );
        return;
      }

      // Open contact picker
      final Contact? contact = await FlutterContacts.openExternalPick();

      if (contact != null) {
        String contactInfo = '👤 ${contact.displayName}\n\n';

        if (contact.phones.isNotEmpty) {
          contactInfo += '📞 Phone:\n';
          for (var phone in contact.phones) {
            contactInfo += '  • ${phone.number}\n';
          }
        }

        if (contact.emails.isNotEmpty) {
          contactInfo += '\n📧 Email:\n';
          for (var email in contact.emails) {
            contactInfo += '  • ${email.address}\n';
          }
        }

        if (contact.addresses.isNotEmpty) {
          contactInfo += '\n📍 Address:\n';
          for (var address in contact.addresses) {
            final addressParts = [
              address.street,
              address.city,
              address.postalCode,
            ].where((part) => part.isNotEmpty).join(', ');
            contactInfo += '  • $addressParts\n';
          }
        }

        setState(() {
          _messages.add(
            ChatMessage(
              text: contactInfo.trim(),
              isMe: true,
              timestamp: DateTime.now(),
              isContact: true,
            ),
          );
        });

        _messageController.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        // Simulate response
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          setState(() {
            _messages.add(
              ChatMessage(
                text: 'Contact saved!',
                isMe: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
        });
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to share contact: ${e.toString()}',
      );
    }
  }

  // Show location preview with map
  Future<bool?> _showLocationPreview(Position position) async {
    final isDarkTheme = _chatTheme == ThemeMode.dark ||
        (_chatTheme == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkTheme ? Colors.grey.shade900 : Colors.white,
          title: Text(
            'Share Location',
            style: TextStyle(color: isDarkTheme ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map,
                            size: 48,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Map Preview',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current Location',
                      style: TextStyle(
                        color: isDarkTheme ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                    color: isDarkTheme
                        ? Colors.grey.shade300
                        : Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Location'),
            ),
          ],
        );
      },
    );
  }

  // Show audio options (voice note or file picker)
  void _showAudioOptions() {
    final isDarkTheme = _chatTheme == ThemeMode.dark ||
        (_chatTheme == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkTheme ? Colors.grey.shade900 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.mic, color: AppColors.primary),
                    ),
                    title: const Text('Voice Note'),
                    subtitle: const Text('Hold the mic button to record'),
                    onTap: () {
                      Navigator.pop(context);
                      EnhancedToast.info(
                        context,
                        title: 'Voice Note',
                        message: 'Hold the mic button to record',
                      );
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.pink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.audiotrack, color: Colors.pink),
                    ),
                    title: const Text('Audio File'),
                    subtitle: const Text('Select an audio file from storage'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAudioFile();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Pick audio file from storage
  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = await file.length();

        // Check file size (limit to 10MB)
        if (fileSize > 10 * 1024 * 1024) {
          EnhancedToast.warning(
            context,
            title: 'File Too Large',
            message: 'Audio file size must be less than 10MB.',
          );
          return;
        }

        // Get audio duration
        Duration? duration;
        try {
          final player = audio.AudioPlayer();
          await player.setFilePath(file.path);
          duration = player.duration;
          await player.dispose();
        } catch (e) {
          duration = null;
        }

        await _sendAudioMessage(file, fileName, duration ?? Duration.zero);
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to pick audio file: ${e.toString()}',
      );
    }
  }

  // Send audio message
  Future<void> _sendAudioMessage(
      File audioFile, String fileName, Duration duration) async {
    // Ensure we have a room ID
    final roomId = _currentRoomId ?? widget.contact.id;
    if (roomId == null || roomId.isEmpty) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Room ID not available. Please try again.',
      );
      return;
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = ChatMessage(
      id: messageId,
      text: '🎵 $fileName',
      isMe: true,
      timestamp: DateTime.now(),
      isAudio: true,
      audioFile: audioFile,
      audioDuration: duration,
      status: MessageStatus.sending,
      replyTo: _replyingTo,
    );

    setState(() {
      _messages.add(message);
      _uploadingFiles[messageId] = true;
      _uploadProgress[messageId] = 0.0;
      _replyingTo = null;
    });

    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      log('📤 [ChatScreen] Uploading audio to S3 for room: $roomId');
      final uploadResponse = await _roomService.uploadFileToS3(
        roomId: roomId,
        file: audioFile,
        onSendProgress: (sent, total) {
          if (mounted && total > 0) {
            final progress = sent / total;
            setState(() {
              _uploadProgress[messageId] = progress;
            });
          }
        },
      );

      if (!mounted) return;

      if (!uploadResponse.success || uploadResponse.data == null) {
        log('❌ [ChatScreen] Failed to upload audio to S3: ${uploadResponse.error}');
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          setState(() {
            _uploadingFiles[messageId] = false;
            _uploadProgress.remove(messageId);
          });
        }
        EnhancedToast.error(
          context,
          title: 'Upload Failed',
          message: uploadResponse.error ??
              'Failed to upload audio. Please try again.',
        );
        return;
      }

      var fileUrl = uploadResponse.data!['file_url'] as String?;
      final fileKey = uploadResponse.data!['file_key'] as String?;
      final mimeType = uploadResponse.data!['mime_type'] as String?;
      final size = uploadResponse.data!['size'] as int?;

      if (fileUrl == null || fileUrl.isEmpty) {
        log('❌ [ChatScreen] No file_url in upload response');
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          setState(() {
            _uploadingFiles[messageId] = false;
            _uploadProgress.remove(messageId);
          });
        }
        EnhancedToast.error(
          context,
          title: 'Upload Failed',
          message: 'Invalid response from server. Please try again.',
        );
        return;
      }

      final originalUrl = fileUrl;
      fileUrl = RoomService.transformLocalhostUrl(fileUrl);
      if (fileUrl != originalUrl) {
        log('🔄 [ChatScreen] Transformed audio fileUrl from localhost: $originalUrl -> $fileUrl');
      }

      final contentMap = {
        'file_url': fileUrl,
        if (fileKey != null) 'file_key': fileKey,
        if (mimeType != null) 'mime_type': mimeType,
        if (mimeType != null) 'file_type': mimeType,
        if (size != null) 'size': size,
        'duration_ms': duration.inMilliseconds,
        'file_name': fileName,
      };
      final content = jsonEncode(contentMap);

      log('📤 [ChatScreen] Sending WebSocket voice message with file_url: $fileUrl');
      final sent = await _chatService.sendMessage(
        roomId: roomId,
        content: content,
        messageType: 'audio',
        replyTo: _replyingTo?.id,
      );

      if (!mounted) return;

      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        setState(() {
          _uploadingFiles[messageId] = false;
          _uploadProgress.remove(messageId);
          _messages[index] = _messages[index].copyWith(
            status: sent ? MessageStatus.sent : MessageStatus.sending,
            audioUrl: fileUrl,
            audioDuration: duration,
            isAudio: true,
          );
        });
      }

      if (!sent) {
        EnhancedToast.error(
          context,
          title: 'Send Failed',
          message: 'Uploaded, but failed to send voice note. Please retry.',
        );
      }
    } catch (e) {
      log('❌ [ChatScreen] Error uploading/sending audio: $e');
      if (!mounted) return;
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        setState(() {
          _uploadingFiles[messageId] = false;
          _uploadProgress.remove(messageId);
        });
      }
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to send audio: ${e.toString()}',
      );
    }
  }

  Future<void> _recordAudio() async {
    if (_isRecording) {
      // Stop recording
      await _stopRecording();
    } else {
      // Start recording
      await _startRecording();
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecording) return;

    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${directory.path}/audio_$timestamp.m4a';
        _recordingFile = File(filePath);

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );

        _recordingStartTime = DateTime.now();
        _recordingDuration = Duration.zero;

        setState(() {
          _isRecording = true;
          _isPressingMic = true;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted && _isRecording && _recordingStartTime != null) {
            setState(() {
              _recordingDuration =
                  DateTime.now().difference(_recordingStartTime!);
            });
          } else {
            timer.cancel();
          }
        });
      } else {
        EnhancedToast.warning(
          context,
          title: 'Permission Required',
          message: 'Microphone permission is required.',
        );
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to start recording: ${e.toString()}',
      );
    }
  }

  Future<void> _endVoiceRecording() async {
    if (!_isRecording) return;

    // Only send if recording duration is at least 0.5 seconds
    if (_recordingDuration.inMilliseconds < 500) {
      // Too short, cancel instead
      await _cancelVoiceRecording();
      return;
    }

    await _sendVoiceMessage();
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_isRecording) return;

    try {
      await _audioRecorder.stop();
      if (_recordingFile != null && await _recordingFile!.exists()) {
        await _recordingFile!.delete();
      }

      setState(() {
        _isRecording = false;
        _isPressingMic = false;
        _recordingFile = null;
        _recordingDuration = Duration.zero;
        _recordingStartTime = null;
      });

      _recordingTimer?.cancel();
    } catch (e) {
      // Ignore errors on cancel
      setState(() {
        _isRecording = false;
        _isPressingMic = false;
        _recordingFile = null;
      });
    }
  }

  Future<void> _sendVoiceMessage() async {
    if (!_isRecording || _recordingFile == null) return;

    try {
      await _audioRecorder.stop();
      final duration = _recordingDuration;

      setState(() {
        _isRecording = false;
        _isPressingMic = false;
      });

      if (_recordingFile != null && await _recordingFile!.exists()) {
        final fileName = _recordingFile!.path.split('/').last;
        await _sendAudioMessage(_recordingFile!, fileName, duration);
      }

      _recordingFile = null;
      _recordingDuration = Duration.zero;
      _recordingStartTime = null;
      _recordingTimer?.cancel();
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to send voice message: ${e.toString()}',
      );
      setState(() {
        _isRecording = false;
        _isPressingMic = false;
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      // Check if recorder is available
      if (await _audioRecorder.hasPermission()) {
        // Get temporary directory for recording
        final directory = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${directory.path}/audio_$timestamp.m4a';
        _recordingFile = File(filePath);

        // Start recording
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );

        _recordingStartTime = DateTime.now();
        _recordingDuration = Duration.zero;

        setState(() {
          _isRecording = true;
        });

        // Update duration every second
        _updateRecordingDuration();

        EnhancedToast.info(
          context,
          title: 'Recording',
          message: 'Recording audio... Tap attachment button again to stop.',
        );
      } else {
        EnhancedToast.warning(
          context,
          title: 'Permission Required',
          message: 'Microphone permission is required to record audio.',
        );
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to start recording: ${e.toString()}',
      );
    }
  }

  void _updateRecordingDuration() {
    if (_isRecording && _recordingStartTime != null) {
      Future.delayed(const Duration(seconds: 1), () {
        if (_isRecording && mounted) {
          setState(() {
            _recordingDuration =
                DateTime.now().difference(_recordingStartTime!);
          });
          _updateRecordingDuration();
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      // Stop recording
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
      });

      if (path != null && _recordingFile != null) {
        final duration = _formatDuration(_recordingDuration);

        setState(() {
          _messages.add(
            ChatMessage(
              text: '🎤 Audio Message ($duration)',
              isMe: true,
              timestamp: DateTime.now(),
              isAudio: true,
              audioFile: _recordingFile,
              audioDuration: _recordingDuration,
            ),
          );
        });

        _messageController.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        // Simulate response
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          setState(() {
            _messages.add(
              ChatMessage(
                text: 'Audio received!',
                isMe: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
        });

        _recordingFile = null;
        _recordingDuration = Duration.zero;
        _recordingStartTime = null;
      } else {
        EnhancedToast.warning(
          context,
          title: 'Recording Failed',
          message: 'No audio was recorded.',
        );
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to stop recording: ${e.toString()}',
      );
      setState(() {
        _isRecording = false;
      });
    }
  }

  void _previewImage(File imageFile) {
    NavigationHelper.pushRoute(
      context,
      MaterialPageRoute(
        builder: (context) => _ImagePreviewScreen(imageFile: imageFile),
        fullscreenDialog: true,
      ),
    );
  }

  void _previewImageUrl(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                color: Colors.transparent,
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 3.0,
                    child: _buildPreviewNetworkImage(imageUrl),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.download, color: Colors.white, size: 30),
                onPressed: () {
                  Navigator.of(context).pop();
                  _downloadImageFromUrl(imageUrl);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build network image with proper error handling and retry logic
  Widget _buildNetworkImage(String imageUrl) {
    // Normalize URL - transform localhost URLs to server URLs
    String normalizedUrl =
        RoomService.transformLocalhostUrl(imageUrl) ?? imageUrl;
    if (normalizedUrl != imageUrl) {
      log('🔄 [ChatScreen] Normalized image URL: $imageUrl -> $normalizedUrl');
    }

    return CachedNetworkImage(
      imageUrl: normalizedUrl,
      width: double.infinity,
      fit: BoxFit.cover,
      httpHeaders: {
        // Add headers if needed for authentication
        'Accept': 'image/*',
      },
      placeholder: (context, url) => Container(
        height: 150,
        color: Colors.grey.shade300,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) {
        log('❌ [ChatScreen] Failed to load image: $url, error: $error');

        // Try http if https failed
        if (url.startsWith('https://')) {
          final httpUrl = url.replaceFirst('https://', 'http://');
          return CachedNetworkImage(
            imageUrl: httpUrl,
            width: double.infinity,
            fit: BoxFit.cover,
            httpHeaders: {'Accept': 'image/*'},
            placeholder: (context, url) => Container(
              height: 150,
              color: Colors.grey.shade300,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => _buildImageErrorWidget(),
          );
        }

        return _buildImageErrorWidget();
      },
    );
  }

  Widget _buildImageErrorWidget() {
    return Container(
      height: 150,
      color: Colors.grey.shade300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            'Failed to load image',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  /// Build network image for full-screen preview
  Widget _buildPreviewNetworkImage(String imageUrl) {
    // Normalize URL - transform localhost URLs to server URLs
    String normalizedUrl =
        RoomService.transformLocalhostUrl(imageUrl) ?? imageUrl;
    if (normalizedUrl != imageUrl) {
      log('🔄 [ChatScreen] Normalized preview image URL: $imageUrl -> $normalizedUrl');
    }

    return CachedNetworkImage(
      imageUrl: normalizedUrl,
      fit: BoxFit.contain,
      httpHeaders: {'Accept': 'image/*'},
      placeholder: (context, url) => Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      errorWidget: (context, url, error) {
        log('❌ [ChatScreen] Failed to load preview image: $url, error: $error');
        // Try http if https failed
        if (url.startsWith('https://')) {
          final httpUrl = url.replaceFirst('https://', 'http://');
          return CachedNetworkImage(
            imageUrl: httpUrl,
            fit: BoxFit.contain,
            httpHeaders: {'Accept': 'image/*'},
            placeholder: (context, url) => Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.black,
              child: const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          );
        }
        return Container(
          color: Colors.black,
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 64,
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadImageFromUrl(String imageUrl) async {
    try {
      // Try to download even if localhost (for development/testing)
      // Log warning but don't block the download attempt
      if (imageUrl.contains('localhost') || imageUrl.contains('127.0.0.1')) {
        log('⚠️ [ChatScreen] Attempting to download from localhost URL: $imageUrl');
        log('   This may fail on mobile devices if not on same network.');
      }

      EnhancedToast.info(
        context,
        title: 'Downloading',
        message: 'Downloading image to gallery...',
      );

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        // Get Pictures directory (Android) or Documents directory (iOS)
        final directory = Platform.isAndroid
            ? await getExternalStorageDirectory()
            : await getApplicationDocumentsDirectory();

        if (directory == null) {
          throw Exception('Unable to access storage directory');
        }

        // Try to get file extension from URL or content type
        String extension = 'jpg';
        if (imageUrl.contains('.')) {
          final parts = imageUrl.split('.');
          if (parts.length > 1) {
            extension = parts.last
                .split('?')
                .first
                .split('/')
                .first; // Remove query params and path
            // Validate extension
            if (!['jpg', 'jpeg', 'png', 'gif', 'webp']
                .contains(extension.toLowerCase())) {
              extension = 'jpg';
            }
          }
        }

        // Create Pictures/WhatsApp directory on Android, or use Documents on iOS
        final savePath = Platform.isAndroid
            ? '${directory.path}/Pictures/WhatsApp'
            : '${directory.path}';

        final saveDir = Directory(savePath);
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }

        final fileName =
            'IMG_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final file = File('$savePath/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        // Note: On Android 10+, files saved to Pictures directory are automatically scanned
        // On older Android versions, user may need to manually refresh gallery

        EnhancedToast.success(
          context,
          title: 'Downloaded',
          message: 'Image saved to gallery',
        );
      } else {
        throw Exception(
            'Failed to download image: HTTP ${response.statusCode}');
      }
    } catch (e) {
      log('❌ [ChatScreen] Error downloading image from URL: $e');
      EnhancedToast.error(
        context,
        title: 'Download Failed',
        message:
            'Failed to download image. Please check your connection and try again.',
      );
    }
  }

  Future<void> _downloadDocumentFromUrl(
      String documentUrl, String fileName) async {
    try {
      // Try to download even if localhost (for development/testing)
      // Log warning but don't block the download attempt
      if (documentUrl.contains('localhost') ||
          documentUrl.contains('127.0.0.1')) {
        log('⚠️ [ChatScreen] Attempting to download from localhost URL: $documentUrl');
        log('   This may fail on mobile devices if not on same network.');
      }

      EnhancedToast.info(
        context,
        title: 'Downloading',
        message: 'Downloading document...',
      );

      final response = await http.get(Uri.parse(documentUrl));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        // Ensure fileName has proper extension
        String finalFileName = fileName;
        if (!fileName.contains('.')) {
          // Try to get extension from URL
          if (documentUrl.contains('.')) {
            final parts = documentUrl.split('.');
            if (parts.length > 1) {
              final ext = parts.last.split('?').first.split('/').first;
              finalFileName = '$fileName.$ext';
            }
          }
        }
        final file = File('${directory.path}/$finalFileName');
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles([XFile(file.path)], text: 'Document');
        EnhancedToast.success(
          context,
          title: 'Downloaded',
          message: 'Document saved successfully',
        );
      } else {
        throw Exception(
            'Failed to download document: HTTP ${response.statusCode}');
      }
    } catch (e) {
      log('❌ [ChatScreen] Error downloading document from URL: $e');
      EnhancedToast.error(
        context,
        title: 'Download Failed',
        message:
            'Failed to download document. Please check your connection and try again.',
      );
    }
  }

  /// Get a high-resolution avatar URL for preview if possible.
  /// Backend typically returns avatar_* or image_* variants (small/medium/large).
  String _getHighResAvatarUrl(String avatarUrl) {
    // Prefer explicit *large variants when we detect *medium or *small patterns
    String url = avatarUrl;

    // Common cubeone patterns: avatar_XXXX_medium.jpg / image_medium.jpg
    if (url.contains('_medium.')) {
      url = url.replaceFirst('_medium.', '_large.');
    } else if (url.contains('_small.')) {
      url = url.replaceFirst('_small.', '_large.');
    } else if (url.contains('image_medium.')) {
      url = url.replaceFirst('image_medium.', 'image_large.');
    } else if (url.contains('image_small.')) {
      url = url.replaceFirst('image_small.', 'image_large.');
    }

    return url;
  }

  /// Preview member avatar with full-screen interactive viewer
  /// Shows the *full* image (not cropped to a circle), with zoom & pan.
  void _previewAvatar(String avatarUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                color: Colors.black,
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          avatarUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            log('⚠️ [ChatScreen] Failed to load avatar preview: $error');
                            return const Icon(
                              Icons.broken_image,
                              color: Colors.white70,
                              size: 80,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previewVideo(File videoFile) {
    NavigationHelper.pushRoute(
      context,
      MaterialPageRoute(
        builder: (context) => _VideoPreviewScreen(videoFile: videoFile),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _handleChatVideoTap(ChatMessage message) async {
    if (_videoDownloadInProgress.contains(message.id)) {
      return;
    }

    File? localFile = message.videoFile;
    if (localFile != null && await localFile.exists()) {
      _openVideoPlayer(localFile);
      return;
    }

    final remoteUrl = message.videoUrl;
    if (remoteUrl == null || remoteUrl.isEmpty) return;

    // Download and play
    await _downloadVideoWithProgress(message, playAfterDownload: true);
  }

  Future<void> _downloadVideoWithProgress(ChatMessage message,
      {bool playAfterDownload = false}) async {
    if (_videoDownloadInProgress.contains(message.id)) {
      return;
    }

    final remoteUrl = message.videoUrl;
    if (remoteUrl == null || remoteUrl.isEmpty) return;

    _videoDownloadInProgress.add(message.id);
    _videoDownloadProgress[message.id] = 0.0;
    setState(() {});

    try {
      final downloaded = await _downloadVideoFromUrlWithProgress(
        remoteUrl,
        'chat_video_${message.id}',
        (progress) {
          if (mounted) {
            setState(() {
              _videoDownloadProgress[message.id] = progress;
            });
          }
        },
      );

      if (downloaded != null) {
        _updateChatMessageWithVideo(message.id, downloaded);
        if (playAfterDownload) {
          _openVideoPlayer(downloaded);
        }
      } else {
        EnhancedToast.error(
          context,
          title: 'Download Failed',
          message: 'Unable to download video. Try again.',
        );
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Download Failed',
        message: 'Unable to download video.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _videoDownloadInProgress.remove(message.id);
          _videoDownloadProgress.remove(message.id);
        });
      }
    }
  }

  Future<File?> _downloadVideoFromUrl(String url, String name) async {
    return _downloadVideoFromUrlWithProgress(url, name, null);
  }

  Future<File?> _downloadVideoFromUrlWithProgress(
    String url,
    String name,
    void Function(double)? onProgress,
  ) async {
    try {
      final directory = await getTemporaryDirectory();
      final target = File('${directory.path}/$name.mp4');
      if (await target.exists()) {
        return target;
      }

      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) return null;

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      int downloadedBytes = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;

        if (onProgress != null && contentLength > 0) {
          final progress = downloadedBytes / contentLength;
          onProgress(progress.clamp(0.0, 1.0));
        }
      }

      await target.writeAsBytes(bytes, flush: true);
      return target;
    } catch (_) {
      return null;
    }
  }

  void _updateChatMessageWithVideo(String messageId, File file) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    setState(() {
      _messages[index] =
          _messages[index].copyWith(videoFile: file, isVideo: true);
    });
  }

  void _openVideoPlayer(File file) {
    NavigationHelper.pushRoute(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoFile: file),
      ),
    );
  }

  Future<void> _openVideoUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Unable to open video link',
      );
    }
  }

  void _showDocumentOptions(File file, String fileName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.blue),
                  title: const Text('Download'),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadFile(file, fileName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.green),
                  title: const Text('Share'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareFile(file, fileName);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadFile(File file, String fileName) async {
    try {
      // Get downloads directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        EnhancedToast.error(
          context,
          title: 'Error',
          message: 'Unable to access storage directory.',
        );
        return;
      }

      // Create downloads folder path
      final downloadsPath = '${directory.path}/Downloads';
      final downloadsDir = Directory(downloadsPath);
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Copy file to downloads
      final destinationPath = '$downloadsPath/$fileName';
      final destinationFile = await file.copy(destinationPath);

      EnhancedToast.success(
        context,
        title: 'Downloaded',
        message: 'File saved to Downloads: $fileName',
      );

      // Also share the file so user can save it
      await Share.shareXFiles(
        [XFile(destinationFile.path)],
        text: 'Downloaded: $fileName',
      );
    } catch (e) {
      // If direct save fails, use share as fallback
      await _shareFile(file, fileName);
    }
  }

  Future<void> _shareFile(File file, String fileName) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: fileName,
        subject: fileName,
      );
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to share file: ${e.toString()}',
      );
    }
  }

  void _showCustomizationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Chat Customization',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.wallpaper, color: Colors.purple),
                  title: const Text('Change Background Wallpaper'),
                  onTap: () {
                    Navigator.pop(context);
                    _showWallpaperOptions();
                  },
                ),
                // Theme Settings option hidden (matches group chat)
                // ListTile(
                //   leading: const Icon(Icons.dark_mode, color: Colors.blue),
                //   title: const Text('Theme Settings'),
                //   onTap: () {
                //     Navigator.pop(context);
                //     _showThemeOptions();
                //   },
                // ),
                // Font Size option hidden (matches group chat)
                // ListTile(
                //   leading: const Icon(Icons.text_fields, color: Colors.orange),
                //   title: const Text('Font Size'),
                //   onTap: () {
                //     Navigator.pop(context);
                //     _showFontSizeOptions();
                //   },
                // ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWallpaperOptions() {
    final wallpapers = [
      {'name': 'Default', 'color': Colors.grey.shade100},
      // Blue, Green, and Purple options hidden (matches group chat)
      // {'name': 'Blue', 'color': Colors.blue.shade50},
      // {'name': 'Green', 'color': Colors.green.shade50},
      // {'name': 'Purple', 'color': Colors.purple.shade50},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select Wallpaper',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Gallery option
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _pickWallpaperImage(ImageSource.gallery);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _chatWallpaperImage != null
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _chatWallpaperImage != null
                              ? AppColors.primary
                              : Colors.grey.shade300,
                          width: _chatWallpaperImage != null ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.shade200,
                              ),
                            ),
                            child: _chatWallpaperImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _chatWallpaperImage!,
                                      fit: BoxFit.cover,
                                      width: 60,
                                      height: 60,
                                    ),
                                  )
                                : const Icon(
                                    Icons.photo_library,
                                    color: Colors.blue,
                                    size: 30,
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.photo_library,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Choose from Gallery',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_chatWallpaperImage != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Active',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _chatWallpaperImage != null
                                      ? 'Tap to change image'
                                      : 'Select an image from your gallery',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Camera option
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _pickWallpaperImage(ImageSource.camera);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.shade200,
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.green,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Take Photo',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Capture a new photo with camera',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    color: Colors.grey.withOpacity(0.2),
                  ),
                  // Color wallpapers
                  GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: wallpapers.length,
                    itemBuilder: (context, index) {
                      final wallpaper = wallpapers[index];
                      final isSelected = _chatWallpaperImage == null &&
                          _chatWallpaper == wallpaper['color'];
                      return GestureDetector(
                        onTap: () async {
                          // Clear saved wallpaper from storage when selecting color
                          await _clearWallpaperFromStorage();

                          setState(() {
                            _chatWallpaper = wallpaper['color'] as Color;
                            _chatWallpaperImage =
                                null; // Clear image when selecting color
                          });
                          Navigator.pop(context);
                          EnhancedToast.success(
                            context,
                            title: 'Wallpaper Changed',
                            message: 'Wallpaper set to ${wallpaper['name']}',
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: wallpaper['color'] as Color,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  wallpaper['name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickWallpaperImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image != null) {
        final wallpaperFile = File(image.path);

        // Save wallpaper path to SharedPreferences
        await _saveWallpaperToStorage(wallpaperFile.path);

        setState(() {
          _chatWallpaperImage = wallpaperFile;
          _chatWallpaper = Colors.grey.shade100; // Reset to default color
        });

        EnhancedToast.success(
          context,
          title: 'Wallpaper Changed',
          message: source == ImageSource.camera
              ? 'Camera wallpaper applied'
              : 'Gallery wallpaper applied',
        );
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message:
            'Failed to ${source == ImageSource.camera ? "capture" : "pick"} image: ${e.toString()}',
      );
    }
  }

  /// Save wallpaper path to SharedPreferences
  /// Uses roomId to store wallpaper per chat room
  Future<void> _saveWallpaperToStorage(String wallpaperPath) async {
    try {
      if (_currentRoomId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_wallpaper_${_currentRoomId}';
      await prefs.setString(key, wallpaperPath);
      log('✅ [ChatScreen] Wallpaper saved to SharedPreferences: $key -> $wallpaperPath');
    } catch (e) {
      log('❌ [ChatScreen] Error saving wallpaper to SharedPreferences: $e');
    }
  }

  /// Load saved wallpaper from SharedPreferences
  /// Uses roomId to load wallpaper for the specific chat room
  Future<void> _loadSavedWallpaper() async {
    try {
      // Wait for roomId to be available
      if (_currentRoomId == null) {
        // Try again after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _currentRoomId != null) {
            _loadSavedWallpaper();
          }
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_wallpaper_${_currentRoomId}';
      final wallpaperPath = prefs.getString(key);

      if (wallpaperPath != null && wallpaperPath.isNotEmpty) {
        final wallpaperFile = File(wallpaperPath);

        // Check if file still exists
        if (await wallpaperFile.exists()) {
          if (mounted) {
            setState(() {
              _chatWallpaperImage = wallpaperFile;
              _chatWallpaper = Colors
                  .grey.shade100; // Reset to default color when image is loaded
            });
            log('✅ [ChatScreen] Wallpaper loaded from SharedPreferences: $wallpaperPath');
          }
        } else {
          // File doesn't exist, remove from preferences
          await prefs.remove(key);
          log('⚠️ [ChatScreen] Wallpaper file not found, removed from preferences: $wallpaperPath');
        }
      }
    } catch (e) {
      log('❌ [ChatScreen] Error loading wallpaper from SharedPreferences: $e');
    }
  }

  /// Clear saved wallpaper from SharedPreferences
  Future<void> _clearWallpaperFromStorage() async {
    try {
      if (_currentRoomId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_wallpaper_${_currentRoomId}';
      await prefs.remove(key);
      log('✅ [ChatScreen] Wallpaper cleared from SharedPreferences: $key');
    } catch (e) {
      log('❌ [ChatScreen] Error clearing wallpaper from SharedPreferences: $e');
    }
  }

  void _showThemeOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select Theme',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(
                      Icons.light_mode,
                      color: _chatTheme == ThemeMode.light
                          ? AppColors.primary
                          : Colors.orange,
                    ),
                    title: const Text('Light'),
                    trailing: _chatTheme == ThemeMode.light
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _chatTheme = ThemeMode.light;
                      });
                      Navigator.pop(context);
                      EnhancedToast.info(context,
                          title: 'Theme', message: 'Light theme selected');
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.dark_mode,
                      color: _chatTheme == ThemeMode.dark
                          ? AppColors.primary
                          : Colors.blue,
                    ),
                    title: const Text('Dark'),
                    trailing: _chatTheme == ThemeMode.dark
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _chatTheme = ThemeMode.dark;
                      });
                      Navigator.pop(context);
                      EnhancedToast.info(context,
                          title: 'Theme', message: 'Dark theme selected');
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFontSizeOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Font Size',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.text_decrease),
                    title: const Text('Small'),
                    subtitle: const Text('12px'),
                    trailing: _fontSize == 12.0
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _fontSize = 12.0;
                      });
                      Navigator.pop(context);
                      EnhancedToast.info(context,
                          title: 'Font Size', message: 'Small font selected');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.text_fields),
                    title: const Text('Medium'),
                    subtitle: const Text('14px'),
                    trailing: _fontSize == 14.0
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _fontSize = 14.0;
                      });
                      Navigator.pop(context);
                      EnhancedToast.info(context,
                          title: 'Font Size', message: 'Medium font selected');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.text_increase),
                    title: const Text('Large'),
                    subtitle: const Text('16px'),
                    trailing: _fontSize == 16.0
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _fontSize = 16.0;
                      });
                      Navigator.pop(context);
                      EnhancedToast.info(context,
                          title: 'Font Size', message: 'Large font selected');
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Block User'),
          content: Text(
              'Are you sure you want to block ${widget.contact.name}? You will no longer receive messages from this user.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _blockUser();
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Block'),
            ),
          ],
        );
      },
    );
  }

  void _blockUser() {
    setState(() {
      _isBlocked = true;
    });
    EnhancedToast.success(
      context,
      title: 'User Blocked',
      message: '${widget.contact.name} has been blocked',
    );
  }

  void _unblockUser() {
    setState(() {
      _isBlocked = false;
    });
    EnhancedToast.success(
      context,
      title: 'User Unblocked',
      message: '${widget.contact.name} has been unblocked',
    );
  }
}

enum MessageStatus { sending, sent, delivered, seen }

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final DateTime? editedAt;
  final bool isDeleted;
  final File? imageFile;
  final bool isLocation;
  final bool isDocument;
  final String? documentName;
  final String? documentType;
  final File? documentFile;
  final bool isContact;
  final bool isAudio;
  final File? audioFile;
  final Duration? audioDuration;
  final String? audioUrl; // S3 URL for audio / voice notes
  final bool isVideo;
  final File? videoFile;
  final String? videoThumbnail;
  final String? videoUrl; // S3 URL for videos
  final MessageStatus status;
  final List<MessageReaction> reactions; // Message reactions
  final ChatMessage? replyTo; // Reply to another message
  final LinkPreview? linkPreview; // Link preview data
  final bool isOnline; // Online status
  final String? imageUrl; // S3 URL for images
  final String? documentUrl; // S3 URL for documents
  final bool isForwarded; // Forwarded marker

  ChatMessage({
    String? id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.editedAt,
    this.isDeleted = false,
    this.imageFile,
    this.isLocation = false,
    this.isDocument = false,
    this.documentName,
    this.documentType,
    this.documentFile,
    this.isContact = false,
    this.isAudio = false,
    this.audioFile,
    this.audioDuration,
    this.audioUrl,
    this.isVideo = false,
    this.videoFile,
    this.videoThumbnail,
    this.videoUrl,
    this.status = MessageStatus.sent,
    this.reactions = const [],
    this.replyTo,
    this.linkPreview,
    this.isOnline = false,
    this.imageUrl,
    this.documentUrl,
    this.isForwarded = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  ChatMessage copyWith({
    String? text,
    MessageStatus? status,
    DateTime? editedAt,
    bool? isDeleted,
    List<MessageReaction>? reactions,
    ChatMessage? replyTo,
    LinkPreview? linkPreview,
    bool? isOnline,
    String? imageUrl,
    String? documentUrl,
    String? audioUrl,
    bool? isAudio,
    Duration? audioDuration,
    bool? isVideo,
    File? videoFile,
    String? videoUrl,
    bool? isForwarded,
  }) {
    return ChatMessage(
      id: id,
      text: text ?? this.text,
      isMe: isMe,
      timestamp: timestamp,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      imageFile: imageFile,
      isLocation: isLocation,
      isDocument: isDocument,
      documentName: documentName,
      documentType: documentType,
      documentFile: documentFile,
      isContact: isContact,
      isAudio: isAudio ?? this.isAudio,
      audioFile: audioFile,
      audioDuration: audioDuration ?? this.audioDuration,
      audioUrl: audioUrl ?? this.audioUrl,
      isVideo: isVideo ?? this.isVideo,
      videoFile: videoFile ?? this.videoFile,
      videoThumbnail: videoThumbnail,
      videoUrl: videoUrl ?? this.videoUrl,
      status: status ?? this.status,
      reactions: reactions != null
          ? List<MessageReaction>.from(reactions)
          : this.reactions,
      replyTo: replyTo ?? this.replyTo,
      linkPreview: linkPreview ?? this.linkPreview,
      isOnline: isOnline ?? this.isOnline,
      imageUrl: imageUrl ?? this.imageUrl,
      documentUrl: documentUrl ?? this.documentUrl,
      isForwarded: isForwarded ?? this.isForwarded,
    );
  }
}

class LinkPreview {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;

  LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
  });
}

class _VideoThumbnailWidget extends StatelessWidget {
  final File videoFile;

  const _VideoThumbnailWidget({required this.videoFile});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.videocam,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }
}

class _ImagePreviewScreen extends StatelessWidget {
  final File imageFile;

  const _ImagePreviewScreen({required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () async {
              try {
                final directory = await getExternalStorageDirectory();
                if (directory == null) return;

                final downloadsPath = '${directory.path}/Downloads';
                final downloadsDir = Directory(downloadsPath);
                if (!await downloadsDir.exists()) {
                  await downloadsDir.create(recursive: true);
                }

                final fileName =
                    'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
                final destinationPath = '$downloadsPath/$fileName';
                await imageFile.copy(destinationPath);

                if (context.mounted) {
                  EnhancedToast.success(
                    context,
                    title: 'Downloaded',
                    message: 'Image saved to Downloads',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  EnhancedToast.error(
                    context,
                    title: 'Error',
                    message: 'Failed to download image: ${e.toString()}',
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () async {
              try {
                await Share.shareXFiles(
                  [XFile(imageFile.path)],
                  text: 'Image from chat',
                );
              } catch (e) {
                if (context.mounted) {
                  EnhancedToast.error(
                    context,
                    title: 'Error',
                    message: 'Failed to share image: ${e.toString()}',
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4.0,
          child: Image.file(
            imageFile,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Video preview widget for preview dialog (shows thumbnail)
class _VideoPreviewWidget extends StatefulWidget {
  final File videoFile;

  const _VideoPreviewWidget({required this.videoFile});

  @override
  State<_VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<_VideoPreviewWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(widget.videoFile);
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        // Seek to middle frame for better thumbnail
        final duration = _controller!.value.duration;
        if (duration.inMilliseconds > 0) {
          await _controller!
              .seekTo(Duration(milliseconds: duration.inMilliseconds ~/ 2));
          await _controller!.pause();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white54,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        // Play button overlay
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoPreviewScreen extends StatelessWidget {
  final File videoFile;

  const _VideoPreviewScreen({required this.videoFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam,
              color: Colors.white,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Video Preview',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Video player integration needed',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditMessageDialog extends StatefulWidget {
  final String initialText;
  final bool isDarkTheme;

  const _EditMessageDialog({
    required this.initialText,
    required this.isDarkTheme,
  });

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDarkTheme ? Colors.grey.shade900 : Colors.white,
      title: Text(
        'Edit Message',
        style:
            TextStyle(color: widget.isDarkTheme ? Colors.white : Colors.black),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 5,
        style:
            TextStyle(color: widget.isDarkTheme ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: 'Edit your message...',
          hintStyle: TextStyle(
              color: widget.isDarkTheme
                  ? Colors.grey.shade500
                  : Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          filled: true,
          fillColor:
              widget.isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade50,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(
            'Cancel',
            style: TextStyle(
                color: widget.isDarkTheme
                    ? Colors.grey.shade300
                    : Colors.grey.shade700),
          ),
        ),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) {
              EnhancedToast.warning(
                context,
                title: 'Invalid',
                message: 'Message cannot be empty.',
              );
              return;
            }

            if (text == widget.initialText) {
              Navigator.pop(context);
              return;
            }

            Navigator.pop(context, text);
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
