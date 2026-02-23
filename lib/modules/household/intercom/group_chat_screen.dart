import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform, Directory, File;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:just_audio/just_audio.dart' as audio;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'models/group_chat_model.dart';
import 'models/intercom_contact.dart';
import 'models/message_reaction_model.dart';
import 'models/room_message_model.dart';
import 'models/room_info_model.dart';
import 'models/room_model.dart';
import 'services/chat_service.dart';
import 'services/chat_websocket_service.dart';
import 'services/room_service.dart';
import 'services/unread_count_manager.dart';
import 'services/intercom_service.dart';
import 'services/room_info_cache.dart';
import '../../../../core/models/api_response.dart';
import '../../../core/theme/colors.dart';
import '../../../core/layout/app_scaffold.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/enhanced_toast.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/society_backend_api_service.dart';
import '../../../core/services/keycloak_service.dart';
import '../../../core/network/network_interceptors.dart';
import '../../../core/utils/profile_data_helper.dart';
import '../society_feed/services/post_api_client.dart';
import 'tabs/groups_tab.dart';
import 'pages/create_group_page.dart';
import '../providers/selected_flat_provider.dart';
import '../../../core/utils/navigation_helper.dart';
import '../../../core/utils/oneapp_share.dart';
import 'chat_screen.dart' hide LinkPreview;
import 'widgets/whatsapp_video_message.dart';
import 'widgets/whatsapp_audio_message.dart';
import 'video_player_screen.dart';
import 'widgets/forward_to_sheet.dart';
import 'models/forward_payload.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  final GroupChat group;
  final String currentUserId;
  final int? currentUserNumericId; // Numeric user ID for comparison
  final List<String>? forwardMessageIds; // Message IDs to forward on open
  final List<ForwardPayload>? forwardPayloads;

  const GroupChatScreen({
    Key? key,
    required this.group,
    required this.currentUserId,
    this.currentUserNumericId,
    this.forwardMessageIds,
    this.forwardPayloads,
  }) : super(key: key);

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final audio.AudioPlayer _audioPlayer = audio.AudioPlayer();
  List<GroupMessage> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false; // For pagination
  bool _hasMoreMessages = true; // Track if more messages available
  int _currentOffset = 0;
  static const int _messagesPerPage = 50;
  static const double _emojiPickerHeight = 300.0;
  final ChatService _chatService = ChatService.instance;
  final ApiService _apiService = ApiService.instance;
  final RoomService _roomService = RoomService.instance;
  final IntercomService _intercomService = IntercomService();
  bool _hasError = false;
  String? _errorMessage;
  StreamSubscription<WebSocketMessage>? _wsMessageSubscription;
  StreamSubscription<bool>? _wsConnectionSubscription;
  bool _isWebSocketConnected = false; // Track WebSocket connection status
  bool _isAtBottom = true; // Track if user is at bottom for auto-scroll
  File? _recordingFile;
  bool _isRecording = false;
  bool _isPressingMic = false;
  bool _isPlayingAudio = false;
  bool _isRemovingMember = false;
  String? _playingAudioId;
  Duration _recordingDuration = Duration.zero;
  DateTime? _recordingStartTime;
  bool _isTyping = false;
  // Track typing users: Map<userId, userName> - store both ID and name for avatar lookup
  final Map<String, String> _typingUsers = {}; // userId -> userName
  Timer? _typingIndicatorTimer; // Timer to hide typing indicator
  bool _isMuted = false;
  bool _hasLeftGroup = false;
  // Track if current user is a member of the group (based on RoomInfo check)
  bool _isUserMember =
      true; // Default to true, will be updated based on RoomInfo
  Color _chatWallpaper = Colors.grey.shade100;
  File? _chatWallpaperImage;
  ThemeMode _chatTheme = ThemeMode.light;
  double _fontSize = 14.0;
  bool _showEmojiPicker = false;
  Timer? _typingTimer; // Timer to send typing events
  Timer? _recordingTimer;
  Timer? _messageSyncTimer; // Timer to periodically sync messages from database
  GroupMessage? _replyingTo;
  // Forward/selection state
  final Set<String> _selectedMessageIds = {};
  bool _isSelectionMode = false;
  bool _isForwarding = false;
  late AnimationController _waveformController;
  List<double> _waveformData = [];
  // Upload progress tracking
  final Map<String, double> _uploadProgress = {};
  final Map<String, bool> _uploadingFiles = {};
  // CRITICAL FIX: Track read receipt requests to prevent duplicates and 429 errors
  // Contains message IDs that are either being processed or already marked as read
  final Set<String> _readReceiptInFlight = {};
  final Set<String> _readReceiptCompleted = {};
  // Track updated group icon URL after upload
  String? _updatedGroupIconUrl;
  // Local copy of group data that can be updated when fresh data is fetched
  late GroupChat _currentGroup;
  // Cache for member avatars (userId -> avatar URL) from RoomInfo API
  // CRITICAL: Always use UUID as key for consistency
  final Map<String, String?> _memberAvatarCache = {};

  // Mapping from numeric user ID to UUID (for avatar lookup)
  // Built from RoomInfo members when group info is fetched
  final Map<int, String> _numericIdToUuidMap = {};

  /// Centralized avatar caching and lookup utility
  /// Normalizes cache keys to ensure consistent lookup across all message sources
  /// - Room members: UUID primary, numeric ID fallback
  /// - WebSocket messages: UUID primary, userId fallback
  /// - API messages: UUID primary, senderId/snapshotUserId fallbacks
  String? _normalizeAvatarUrl(String? rawUrl) {
    final trimmed = rawUrl?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (RegExp(r'^\\d+$').hasMatch(trimmed)) {
      return ProfileDataHelper.buildAvatarUrlFromUserId(trimmed);
    }

    final sanitized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return ProfileDataHelper.resolveAvatarUrl({'avatar': sanitized});
  }

  void _cacheAvatarNormalized({
    String? uuid,
    String? numericId,
    required String avatarUrl,
    String? source,
  }) {
    final normalizedAvatar = _normalizeAvatarUrl(avatarUrl);
    if (normalizedAvatar == null || normalizedAvatar.isEmpty) return;

    // PRIMARY: Cache with UUID (standardized key)
    if (uuid != null && uuid.isNotEmpty) {
      _memberAvatarCache[uuid] = normalizedAvatar;
    }

    // SECONDARY: Cache with numeric ID as string (fallback key)
    if (numericId != null && numericId.isNotEmpty) {
      _memberAvatarCache[numericId] = normalizedAvatar;
      // Also update UUID mapping if we have both
      if (uuid != null && uuid.isNotEmpty) {
        final numericIdInt = int.tryParse(numericId);
        if (numericIdInt != null) {
          _numericIdToUuidMap[numericIdInt] = uuid;
        }
      }
    }

    debugPrint(
        '✅ [GroupChatScreen] Cached avatar ($source): UUID=$uuid, numericId=$numericId -> $normalizedAvatar');
  }

  /// Centralized avatar lookup utility
  /// Tries multiple key variations to find avatar
  String? _getAvatarNormalized({
    String? uuid,
    String? numericId,
    String? fallbackId,
  }) {
    // PRIORITY 1: UUID lookup (most reliable)
    if (uuid != null && uuid.isNotEmpty) {
      final avatar = _memberAvatarCache[uuid];
      if (avatar != null && avatar.isNotEmpty) {
        return avatar;
      }
    }

    // PRIORITY 2: Numeric ID lookup (as string)
    if (numericId != null && numericId.isNotEmpty) {
      final avatar = _memberAvatarCache[numericId];
      if (avatar != null && avatar.isNotEmpty) {
        return avatar;
      }
    }

    // PRIORITY 3: Fallback ID lookup (original senderId, etc.)
    if (fallbackId != null && fallbackId.isNotEmpty) {
      final avatar = _memberAvatarCache[fallbackId];
      if (avatar != null && avatar.isNotEmpty) {
        return avatar;
      }
    }

    // PRIORITY 4: UUID lookup via numeric ID mapping
    if (numericId != null && numericId.isNotEmpty) {
      final numericIdInt = int.tryParse(numericId);
      if (numericIdInt != null) {
        final mappedUuid = _numericIdToUuidMap[numericIdInt];
        if (mappedUuid != null) {
          final avatar = _memberAvatarCache[mappedUuid];
          if (avatar != null && avatar.isNotEmpty) {
            return avatar;
          }
        }
      }
    }

    return null; // Avatar not found
  }

  // Store RoomInfo membership status to handle 403 errors gracefully
  bool _isMemberFromRoomInfo = false;
  // Prevent concurrent API calls
  bool _isOpeningRoom = false;
  // Debouncing for Group Info tap
  DateTime? _lastGroupInfoTapTime;
  static const Duration _groupInfoTapDebounce = Duration(milliseconds: 500);

  // Track if group info page is currently open
  bool _isGroupInfoPageOpen = false;
  // Live, page-scoped member list for Group Info (updates immediately on removal)
  ValueNotifier<List<RoomInfoMember>>? _groupInfoMembersNotifier;
  ValueNotifier<int>? _groupInfoMemberCountNotifier;
  bool _isGroupInfoRefreshing = false;
  DateTime? _lastApiCallTime;
  int _rateLimitRetryCount = 0;
  static const Duration _minApiCallInterval =
      Duration(seconds: 2); // Minimum 2 seconds between API calls
  // Reaction fetching rate limiting
  DateTime? _lastReactionFetchTime;
  DateTime? _reactionFetchCooldownUntil; // Cooldown after 429 error
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
  final RegExp _urlRegex = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );
  List<String>? _pendingForwardMessageIds;
  List<ForwardPayload>? _pendingForwardPayloads;
  final List<String> _forwardPlaceholderIds = [];
  bool _forwardPlaceholdersInserted = false;
  bool _forwardIntentHandled = false;
  bool _forwardIntentInFlight = false;
  bool _avatarCachePrimed = false;

  @override
  void initState() {
    super.initState();
    // Initialize local group copy from widget.group
    _currentGroup = widget.group;
    _pendingForwardMessageIds = widget.forwardMessageIds;
    _pendingForwardPayloads = widget.forwardPayloads;

    // Cache avatars from initial group members if available
    // CRITICAL: Cache with member.id (could be UUID or numeric)
    for (final member in widget.group.members) {
      if (member.photoUrl != null && member.photoUrl!.isNotEmpty) {
        _cacheAvatarNormalized(
          uuid: member.id.contains('-') ? member.id : null,
          numericId: member.id.contains('-') ? null : member.id,
          avatarUrl: member.photoUrl!,
          source: 'initialGroupMembers',
        );
      }
    }

    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();
    _generateWaveformData();
    _setupScrollListener();
    _setupWebSocketListeners();
    _setupTypingIndicator();
    _setupMessageSync();
    // Load saved wallpaper from SharedPreferences for this group
    _loadSavedWallpaper();

    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) {
        _scrollToBottom();
      }
    });

    // SECURITY: Keep UI in loading state until membership is validated
    // This prevents user from typing before we know their membership status
    // Loading state will be cleared after membership validation completes

    // Load messages and connect WebSocket asynchronously (non-blocking)
    // CRITICAL: Fetch RoomInfo FIRST to check membership before opening room
    // This prevents errors on re-entry when user is already a member
    _fetchRoomInfoAndOpenRoom();

    // Ensure avatar cache is populated even if the fast RoomInfo call times out.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (!_avatarCachePrimed) {
        _fetchRoomInfoForAvatarCache();
      }
    });
  }

  /// Fetch RoomInfo FIRST to check membership, then open room (if allowed)
  /// This prevents errors on re-entry when user is already a member
  /// PERFORMANCE OPTIMIZED: RoomInfo call is non-blocking, UI shows immediately
  /// If it times out or fails, we proceed immediately to open room (if allowed)
  Future<void> _fetchRoomInfoAndOpenRoom() async {
    // CRITICAL CHECK: If user has left the group, skip room joining entirely
    if (widget.group.hasLeft || _hasLeftGroup) {
      debugPrint(
          '📖 [GroupChatScreen] User has left group ${widget.group.id}, skipping room join - read-only mode');
      await _fetchMessagesInReadOnlyMode();
      return;
    }
    // PERFORMANCE OPTIMIZATION: Get companyId from provider directly (synchronous)
    // This avoids async API call that may trigger token refresh
    int? companyId;
    try {
      final selectedFlatState = ref.read(selectedFlatProvider);
      companyId = selectedFlatState.selectedSociety?.socId;
    } catch (e) {
      debugPrint(
          '⚠️ [GroupChatScreen] Error getting companyId from provider: $e');
    }

    // Fallback to async API only if provider doesn't have it (shouldn't happen)
    if (companyId == null) {
      try {
        companyId = await _apiService.getSelectedSocietyId();
      } catch (e) {
        debugPrint('⚠️ [GroupChatScreen] Error getting companyId from API: $e');
      }
    }

    if (companyId == null) {
      // If companyId not available, still try to open room (will fail gracefully)
      debugPrint(
          '⚠️ [GroupChatScreen] CompanyId not available, proceeding anyway');
      _openRoom();
      return;
    }

    // PERFORMANCE OPTIMIZATION: Start RoomInfo call with very short timeout (2s)
    // Proceed immediately to open room - RoomInfo is only for avatar caching
    debugPrint(
        '🔄 [GroupChatScreen] Fetching RoomInfo (background, 2s timeout): ${widget.group.id}');

    // Start RoomInfo call with short timeout, completely non-blocking
    _roomService
        .getRoomInfo(
      roomId: widget.group.id,
      companyId: companyId,
    )
        .timeout(
      const Duration(seconds: 2), // Very short timeout - fail fast
      onTimeout: () {
        debugPrint(
            '⏱️ [GroupChatScreen] RoomInfo timeout after 2s - continuing without it');
        return ApiResponse.error('Request timeout', statusCode: 408);
      },
    ).then((roomInfoResponse) {
      // Process RoomInfo response in background (non-blocking)
      if (roomInfoResponse.success &&
          roomInfoResponse.data != null &&
          mounted) {
        _processRoomInfoResponse(roomInfoResponse.data!, companyId!);
      } else if (roomInfoResponse.statusCode == 403) {
        // CRITICAL FIX: Be very specific about membership errors to avoid false positives
        // Generic "access denied" or "not authorized" could be API permission issues, not membership
        final errorMessage = roomInfoResponse.displayError.toLowerCase();
        
        // Only consider it a membership error if it EXPLICITLY mentions membership/member
        // Don't use generic phrases like "access denied" which could match rate limits or API issues
        final isMembershipError = errorMessage.contains('not a member') ||
            errorMessage.contains('no longer a member') ||
            errorMessage.contains('left the group') ||
            errorMessage.contains('removed from group') ||
            errorMessage.contains('membership') ||
            (errorMessage.contains('forbidden') && errorMessage.contains('member'));

        if (isMembershipError) {
          // Genuine membership error - user has left the group
          log('🚫 [GroupChatScreen] User has left group (detected via RoomInfo 403): "$errorMessage"');
          if (mounted) {
            setState(() {
              _isUserMember = false;
              _isMemberFromRoomInfo = false;
              _hasLeftGroup = true; // Mark that user has left the group
            });
          }
        } else {
          // API permission issue, not membership - don't block user
          // This could be rate limiting, token issues, or server errors returning 403
          log('⚠️ [GroupChatScreen] RoomInfo 403 but NOT membership error (ignoring): "$errorMessage"');
          log('   Proceeding with normal flow - membership will be validated via join API');
        }
      }
    }).catchError((e) {
      debugPrint('⚠️ [GroupChatScreen] RoomInfo error (non-blocking): $e');
      // Continue - membership will be validated via join API
    });

    // PERFORMANCE OPTIMIZATION: Proceed immediately to open room without any waiting
    // Membership will be validated via join API, which is faster and more reliable
    debugPrint(
        '🚀 [GroupChatScreen] Opening room immediately (RoomInfo in background, messages loading async)');
    _openRoom(
        isMemberFromRoomInfo: false,
        loadInBackground: true); // Always validate via backend
  }

  /// Process RoomInfo response to cache avatars and update membership status
  /// This is called asynchronously and doesn't block the main flow
  /// PERFORMANCE: Now caches RoomInfo globally for reuse in Group Info screen
  void _processRoomInfoResponse(RoomInfo roomInfo, int companyId) {
    try {
      if (!mounted) return;

      // PERFORMANCE OPTIMIZATION: Cache RoomInfo globally for reuse
      // This prevents re-fetching and re-parsing when Group Info screen opens
      final roomInfoCache = RoomInfoCache();
      final avatarCache = <String, String>{};
      final numericIdToUuidMap = <int, String>{};

      // Cache member avatars from RoomInfo API
      // Use normalized caching for consistency across all message sources
      for (final member in roomInfo.members) {
        if (member.avatar != null && member.avatar!.isNotEmpty) {
          // Use normalized caching for consistency across all message sources
          _cacheAvatarNormalized(
            uuid: member.userId,
            numericId: member.numericUserId?.toString(),
            avatarUrl: member.avatar!,
            source: 'RoomInfo-init',
          );

          // Still populate RoomInfoCache avatar cache (for global cache)
          avatarCache[member.userId] =
              _normalizeAvatarUrl(member.avatar) ?? member.avatar!;
          if (member.numericUserId != null) {
            avatarCache[member.numericUserId!.toString()] =
                _normalizeAvatarUrl(member.avatar) ?? member.avatar!;
          }
          _avatarCachePrimed = true;
        }

        // Build numeric ID to UUID mapping
        if (member.numericUserId != null) {
          _numericIdToUuidMap[member.numericUserId!] = member.userId;
          numericIdToUuidMap[member.numericUserId!] = member.userId;
        }
      }

      // Cache RoomInfo globally for Group Info screen
      roomInfoCache.cacheRoomInfo(
        roomId: widget.group.id,
        companyId: companyId,
        roomInfo: roomInfo,
        avatarCache: avatarCache,
        numericIdToUuidMap: numericIdToUuidMap,
      );

      // Check if current user is already a member
      final currentUserUuid = widget.currentUserId;
      final currentUserNumericId = widget.currentUserNumericId;

      final isUserMember = roomInfo.members.any((member) {
        // Method 1: Primary check - Direct UUID match
        if (currentUserUuid.isNotEmpty &&
            member.userId.isNotEmpty &&
            member.userId == currentUserUuid) {
          return true;
        }

        // Method 2: Fallback - Check by numericUserId
        if (currentUserNumericId != null &&
            member.numericUserId != null &&
            member.numericUserId == currentUserNumericId) {
          return true;
        }

        // Method 3: Fallback - Check if member.userId is numeric string
        if (currentUserNumericId != null &&
            member.userId.isNotEmpty &&
            !member.userId.contains('-')) {
          final memberUserIdAsInt = int.tryParse(member.userId);
          if (memberUserIdAsInt != null &&
              memberUserIdAsInt == currentUserNumericId) {
            return true;
          }
        }

        return false;
      });

      // Update membership status (but don't block on it - already opened room)
      if (mounted) {
        setState(() {
          _isMemberFromRoomInfo = isUserMember;
          // Note: _isUserMember is already set by join API validation, so this is just for reference
        });
        // Reduced logging - only log summary, not per-member
        debugPrint(
            '✅ [GroupChatScreen] RoomInfo processed (async) - User is member: $isUserMember, ${roomInfo.memberCount} members');
      }
    } catch (e) {
      debugPrint('⚠️ [GroupChatScreen] Error processing RoomInfo response: $e');
    }
  }

  /// Fetch messages in read-only mode for users who left the group
  /// This fetches messages without joining the room or connecting to WebSocket
  Future<void> _fetchMessagesInReadOnlyMode() async {
    try {
      final companyId = await _apiService.getSelectedSocietyId();
      if (companyId == null) {
        debugPrint(
            '⚠️ [GroupChatScreen] Cannot fetch messages - no company ID');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Unable to load messages. Please try again.';
          });
        }
        return;
      }

      debugPrint(
          '📖 [GroupChatScreen] Fetching messages in read-only mode for group: ${widget.group.id}');

      final messagesResponse = await _roomService.getMessages(
        roomId: widget.group.id,
        companyId: companyId,
        limit: _messagesPerPage,
        offset: _currentOffset,
      );

      if (!mounted) return;

      if (messagesResponse.success && messagesResponse.data != null) {
        final roomMessages = messagesResponse.data!;

        // Convert RoomMessage to GroupMessage
        final groupMessages = roomMessages
            .map((rm) => GroupMessage(
                  id: rm.id,
                  groupId: rm.roomId,
                  senderId: rm.senderId,
                  senderName: rm.senderName,
                  senderPhotoUrl: rm.senderAvatar,
                  text: rm.body,
                  timestamp: rm.createdAt,
                  editedAt: rm.updatedAt != rm.createdAt ? rm.updatedAt : null,
                  isDeleted: rm.isDeleted,
                  status: GroupMessageStatus.sent,
                  reactions: rm.reactions, // Already List<MessageReaction>
                  isSystemMessage: rm.eventType != null,
                  snapshotUserId: rm.snapshotUserId,
                  isForwarded: rm.isForwarded,
                ))
            .toList();

        // Cache avatars from messages
        for (final rm in roomMessages) {
          if (rm.senderAvatar != null && rm.senderAvatar!.isNotEmpty) {
            // Map numeric ID to UUID if available
            if (rm.snapshotUserId != null) {
              _numericIdToUuidMap[rm.snapshotUserId!] = rm.senderId;
            }
            _cacheAvatarNormalized(
              uuid: rm.senderId.contains('-') ? rm.senderId : null,
              numericId: rm.snapshotUserId?.toString() ??
                  (rm.senderId.contains('-') ? null : rm.senderId),
              avatarUrl: rm.senderAvatar!,
              source: 'readOnlyMessages',
            );
          }
        }

        if (mounted) {
          setState(() {
            _messages = groupMessages;
            _isLoading = false;
            _hasError = false;
            _errorMessage = null;
          });
        }

        debugPrint(
            '✅ [GroupChatScreen] Loaded ${groupMessages.length} messages in read-only mode');

        // Show info message that user has left the group
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            EnhancedToast.info(
              context,
              title: 'Read-Only Mode',
              message: 'You can view messages but cannot send new ones.',
            );
          }
        });
      } else {
        debugPrint(
            '❌ [GroupChatScreen] Failed to fetch messages in read-only mode: ${messagesResponse.error}');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = messagesResponse.error ?? 'Failed to load messages';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint(
          '⚠️ [GroupChatScreen] Error fetching messages in read-only mode: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load messages';
          _isLoading = false;
        });
      }
    }
  }

  /// Fetch RoomInfo when chat opens to populate avatar cache (for refresh scenarios)
  /// This ensures avatars are available for all messages
  Future<void> _fetchRoomInfoForAvatarCache() async {
    try {
      final companyId = await _apiService.getSelectedSocietyId();
      if (companyId == null) return;

      debugPrint(
          '🔄 [GroupChatScreen] Fetching RoomInfo for avatar cache: ${widget.group.id}');

      final roomInfoResponse = await _roomService.getRoomInfo(
        roomId: widget.group.id,
        companyId: companyId,
      );

      if (roomInfoResponse.success &&
          roomInfoResponse.data != null &&
          mounted) {
        final roomInfo = roomInfoResponse.data!;

        // Cache member avatars from RoomInfo API
        // CRITICAL: Cache avatars with multiple keys (UUID, numeric ID) for reliable lookup
        for (final member in roomInfo.members) {
          if (member.avatar != null && member.avatar!.isNotEmpty) {
            _cacheAvatarNormalized(
              uuid: member.userId,
              numericId: member.numericUserId?.toString(),
              avatarUrl: member.avatar!,
              source: 'roomInfoInit',
            );
          }

          // Build numeric ID to UUID mapping
          if (member.numericUserId != null) {
            _numericIdToUuidMap[member.numericUserId!] = member.userId;
            debugPrint(
                '✅ [GroupChatScreen] Mapped numeric ID ${member.numericUserId} to UUID ${member.userId} (init)');
          }
        }

        debugPrint(
            '✅ [GroupChatScreen] Avatar cache populated: ${_memberAvatarCache.length} avatars, ${_numericIdToUuidMap.length} ID mappings');
      }
    } catch (e) {
      debugPrint(
          '⚠️ [GroupChatScreen] Failed to fetch RoomInfo for avatar cache: $e');
      // Don't block UI - continue without avatars
    }
  }

  /// Setup scroll listener for pagination (load older messages on scroll up)
  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Track if user is at bottom for auto-scroll
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        _isAtBottom = (maxScroll - currentScroll) < 100;
      }

      // Load older messages when user scrolls near the top
      if (_scrollController.position.pixels < 200 &&
          !_isLoadingMore &&
          _hasMoreMessages &&
          !_isLoading) {
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

    // Only mark messages if user is a member
    if (!_isUserMember || _hasLeftGroup) return;

    // Get unread messages from other users that haven't been processed yet
    final unreadMessagesFromOthers = _messages
        .where((message) =>
            !message.isFromUser(widget.currentUserId,
                currentUserNumericId: widget.currentUserNumericId) &&
            message.status != GroupMessageStatus.seen &&
            // CRITICAL: Skip messages already in-flight or completed
            !_readReceiptInFlight.contains(message.id) &&
            !_readReceiptCompleted.contains(message.id))
        .toList();

    if (unreadMessagesFromOthers.isEmpty) return;

    // Mark the most recent unread message as read
    final messageToMark = unreadMessagesFromOthers.last;

    // Add a small delay to avoid marking messages the user just glanced at
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && _messages.any((m) => m.id == messageToMark.id)) {
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
      log('ℹ️ [GroupChatScreen] Skipping duplicate read receipt for: $messageId');
      return;
    }
    
    // Mark as in-flight to prevent concurrent requests for same message
    _readReceiptInFlight.add(messageId);
    
    try {
      final response = await _chatService.markMessageAsRead(messageId);
      if (response.success) {
        log('✅ [GroupChatScreen] Message marked as read: $messageId');
        // Mark as completed to prevent future requests
        _readReceiptCompleted.add(messageId);

        // Update local message status to show read receipt immediately
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == messageId);
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(
                status: GroupMessageStatus.seen,
              );
            }
          });
        }
      } else {
        log('⚠️ [GroupChatScreen] Failed to mark message as read: ${response.error}');
        // Don't add to completed - allow retry later
      }
    } catch (e) {
      log('❌ [GroupChatScreen] Error marking message as read: $e');
      // Don't add to completed - allow retry later
    } finally {
      // Always remove from in-flight
      _readReceiptInFlight.remove(messageId);
    }
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
            // Show success message when connection is restored
            if (mounted) {
              EnhancedToast.success(
                context,
                title: 'Connected',
                message: 'Real-time messaging is now active',
              );
            }
          } else if (!isConnected && wasConnected) {
            log('⚠️ WebSocket disconnected - Real-time messaging unavailable');
            // Banner will show automatically via UI, no need for toast
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

  void _generateWaveformData() {
    _waveformData = List.generate(20, (index) {
      return math.Random().nextDouble() * 0.5 + 0.3;
    });
  }

  /// Setup typing indicator listener
  void _setupTypingIndicator() {
    // Note: We do NOT show typing indicator when current user types
    // Only show when OTHER members are typing (received via WebSocket)
    // _messageController.addListener(_onTextChanged); // REMOVED - don't show when current user types
  }

  /// Handle typing events from OTHER users (via WebSocket)
  /// This will be called when backend sends typing events
  void _handleOtherUserTyping(String userId, String? userName, bool isTyping) {
    // Only show typing indicator if:
    // 1. Chat screen is open (mounted)
    // 2. It's for the current room
    // 3. It's NOT the current user typing
    if (!mounted) return;

    if (userId == widget.currentUserId) {
      // Current user is typing - don't show indicator
      return;
    }

    if (isTyping) {
      // Add user to typing set
      final displayName = userName ?? 'User';
      _typingUsers[userId] = displayName;
    } else {
      // Remove user from typing set
      _typingUsers.remove(userId);
    }

    // Update typing indicator state
    if (mounted) {
      setState(() {
        _isTyping = _typingUsers.isNotEmpty;
      });
    }

    // Auto-hide typing indicator after 3 seconds if no update
    _typingIndicatorTimer?.cancel();
    if (isTyping && _typingUsers.isNotEmpty) {
      _typingIndicatorTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            // Remove this user from typing set after timeout
            _typingUsers.remove(userId);
            _isTyping = _typingUsers.isNotEmpty;
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
      if (!mounted || _isLoading || _isLoadingMore || _isOpeningRoom) return;

      // Skip sync if WebSocket is connected (real-time updates are working)
      if (_isWebSocketConnected) {
        log('⏭️ [GroupChatScreen] Skipping message sync - WebSocket is connected');
        return;
      }

      // Rate limiting: Check if enough time has passed since last API call
      if (_lastApiCallTime != null) {
        final timeSinceLastCall = DateTime.now().difference(_lastApiCallTime!);
        if (timeSinceLastCall < _minApiCallInterval) {
          log('⏭️ [GroupChatScreen] Skipping message sync - rate limit active');
          return;
        }
      }

      try {
        // Get company_id for API call
        final companyId = await _apiService.getSelectedSocietyId();
        if (companyId == null) return;

        // Fetch latest messages (just the most recent ones)
        final response = await _chatService.fetchMessages(
          roomId: widget.group.id,
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
          log('⚠️ [GroupChatScreen] Rate limit in message sync, pausing sync timer');
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

  /// Refresh group info from API (fetches latest room info)
  /// Called after group is updated to get latest data
  /// Update _currentGroup state from RoomInfo (used for immediate UI updates)
  /// This method updates UI immediately without waiting for API calls
  void _updateCurrentGroupFromRoomInfo(RoomInfo roomInfo, int companyId) {
    if (!mounted) return;

    // CRITICAL: Convert room info members to IntercomContact list
    // Backend /rooms/{id}/info now filters by status='active', so this list should only contain active members
    // BACKEND FIX: Add safety filter to ensure only active members are displayed (defensive programming)
    // No merging with widget.group.members or any other source - API is source of truth
    final members = roomInfo.members
        .where((member) =>
            member.status == null ||
            member.status!.toLowerCase() ==
                'active') // Safety filter: only include active members
        .map((member) {
      return IntercomContact(
        id: member.userId,
        name: member.username ?? 'Unknown User',
        type: IntercomContactType.resident,
        status: IntercomContactStatus.offline,
        photoUrl: member.avatar,
        numericUserId:
            member.numericUserId, // CRITICAL: Include numeric ID for API calls
      );
    }).toList();

    // Also include admin if available (from API response - admin is active if present)
    // Admin is separate field in API response, so add if not already in members list
    if (roomInfo.admin != null && roomInfo.admin!.userId != null) {
      final adminContact = IntercomContact(
        id: roomInfo.admin!.userId!,
        name: roomInfo.admin!.username ?? roomInfo.admin!.email ?? 'Admin',
        type: IntercomContactType.resident,
        status: IntercomContactStatus.offline,
      );
      // Only add if not already in members (admin might be in members list too)
      if (!members.any((m) => m.id == adminContact.id)) {
        members.add(adminContact);
      }
    }

    // Process avatars and cache them
    final avatarCache = <String, String>{};
    final numericIdToUuidMap = <int, String>{};
    for (final member in roomInfo.members) {
      if (member.avatar != null && member.avatar!.isNotEmpty) {
        // Use normalized caching for consistency across all message sources
        _cacheAvatarNormalized(
          uuid: member.userId,
          numericId: member.numericUserId?.toString(),
          avatarUrl: member.avatar!,
          source: 'RoomInfo-update',
        );

        // Still populate RoomInfoCache avatar cache (for global cache)
        avatarCache[member.userId] = member.avatar!;
        if (member.numericUserId != null) {
          avatarCache[member.numericUserId!.toString()] = member.avatar!;
        }
      }
      if (member.numericUserId != null) {
        _numericIdToUuidMap[member.numericUserId!] = member.userId;
        numericIdToUuidMap[member.numericUserId!] = member.userId;
      }
    }

    // Cache RoomInfo globally
    final roomInfoCache = RoomInfoCache();
    roomInfoCache.cacheRoomInfo(
      roomId: _currentGroup.id,
      companyId: companyId,
      roomInfo: roomInfo,
      avatarCache: avatarCache,
      numericIdToUuidMap: numericIdToUuidMap,
    );

    // Update local group state with fresh data (including memberCount)
    // CRITICAL: Always use roomInfo.memberCount from API - never derive from members.length
    // Backend returns accurate count of active members, which may differ from members.length
    // if admin is added separately or if there are any edge cases
    setState(() {
      _currentGroup = _currentGroup.copyWith(
        name: roomInfo.name,
        description: roomInfo.description,
        members: members,
        memberCount:
            roomInfo.memberCount, // CRITICAL: API memberCount is authoritative
        // Keep existing iconUrl since RoomInfo doesn't include photoUrl
      );
    });

    debugPrint(
        '⚡ [GroupChatScreen] Updated _currentGroup from RoomInfo: ${roomInfo.name} (${roomInfo.memberCount} members)');

    // Ensure all RoomInfo avatars are cached after updating members
    _ensureRoomInfoAvatarsCached();
  }

  /// Updates local _currentGroup state to reflect changes immediately
  /// [forceNetwork] skips cache to ensure we always pull the latest membership
  /// data after a destructive action like member removal.
  Future<void> _refreshGroupInfo({bool forceNetwork = false}) async {
    try {
      final companyId = await _apiService.getSelectedSocietyId();
      if (companyId == null) return;

      debugPrint(
          '🔄 [GroupChatScreen] Refreshing group info for room: ${_currentGroup.id}');

      final roomInfoCache = RoomInfoCache();

      // Only serve cached data when not explicitly forcing a network refresh.
      if (!forceNetwork) {
        final cachedRoomInfo =
            roomInfoCache.getCachedRoomInfo(_currentGroup.id, companyId);
        if (cachedRoomInfo != null) {
          debugPrint(
              '✅ [GroupChatScreen] Using cached room info (avoiding API call): ${cachedRoomInfo.name} (${cachedRoomInfo.memberCount} members)');
          // CRITICAL FIX: Update UI immediately from cached RoomInfo (including optimistic updates)
          _updateCurrentGroupFromRoomInfo(cachedRoomInfo, companyId);
          return;
        }
      } else {
        // Ensure subsequent cache lookups fetch fresh data after forced refresh
        roomInfoCache.markMemberLeft(_currentGroup.id);
      }

      // Wait a brief moment to ensure backend has processed the update
      await Future.delayed(const Duration(milliseconds: 500));

      // Fetch latest room info
      final roomInfoResponse = await _roomService.getRoomInfo(
        roomId: _currentGroup.id,
        companyId: companyId,
      );

      if (roomInfoResponse.success &&
          roomInfoResponse.data != null &&
          mounted) {
        final roomInfo = roomInfoResponse.data!;
        debugPrint(
            '✅ [GroupChatScreen] Group info refreshed: ${roomInfo.name} (${roomInfo.memberCount} members)');

        // PERFORMANCE: Cache RoomInfo globally for reuse
        final roomInfoCache = RoomInfoCache();
        final avatarCache = <String, String>{};
        final numericIdToUuidMap = <int, String>{};

        // Cache member avatars from RoomInfo API (reduced logging)
        for (final member in roomInfo.members) {
          if (member.avatar != null && member.avatar!.isNotEmpty) {
            _cacheAvatarNormalized(
              uuid: member.userId,
              numericId: member.numericUserId?.toString(),
              avatarUrl: member.avatar!,
              source: 'roomInfoRefresh',
            );
            avatarCache[member.userId] =
                _normalizeAvatarUrl(member.avatar) ?? member.avatar!;
            if (member.numericUserId != null) {
              final numericIdStr = member.numericUserId!.toString();
              avatarCache[numericIdStr] =
                  _normalizeAvatarUrl(member.avatar) ?? member.avatar!;
            }
          }

          if (member.numericUserId != null) {
            _numericIdToUuidMap[member.numericUserId!] = member.userId;
            numericIdToUuidMap[member.numericUserId!] = member.userId;
          }
        }

        // Cache RoomInfo globally
        roomInfoCache.cacheRoomInfo(
          roomId: _currentGroup.id,
          companyId: companyId,
          roomInfo: roomInfo,
          avatarCache: avatarCache,
          numericIdToUuidMap: numericIdToUuidMap,
        );

        // Update UI with fresh data from API (using shared method)
        _updateCurrentGroupFromRoomInfo(roomInfo, companyId);

        _updateGroupInfoNotifiers(roomInfo);
      }
    } catch (e) {
      debugPrint('⚠️ [GroupChatScreen] Failed to refresh group info: $e');
    }
  }

  Future<void> _refreshGroupInfoPage(
      {bool updateInPlace = false, bool forceNetwork = false}) async {
    final companyId = await _apiService.getSelectedSocietyId();
    if (companyId == null) return;

    // If the Group Info page is already open, refresh it in place without closing
    // and reopening the route. This issues a fresh GET /rooms/{id}/info call so the
    // member list and counts always reflect the backend state after an admin removes
    // a member.
    if (updateInPlace) {
      if (!_isGroupInfoPageOpen) return;
      if (mounted) {
        setState(() {
          _isGroupInfoRefreshing = true;
        });
      }
      try {
        // Force network if requested to avoid stale cache
        if (forceNetwork) {
          final cache = RoomInfoCache();
          cache.markMemberLeft(widget.group.id);
          cache.clearRoomCache(widget.group.id);
        }

        final response = await _roomService.getRoomInfo(
          roomId: widget.group.id,
          companyId: companyId,
        );

        if (response.success && response.data != null && mounted) {
          final roomInfo = response.data!;

          // Keep caches and derived state in sync with the latest RoomInfo.
          _processAndCacheRoomInfo(roomInfo, companyId);
          _updateCurrentGroupFromRoomInfo(roomInfo, companyId);

          // Update live notifiers so the open Group Info page reflects the new data.
          _updateGroupInfoNotifiers(roomInfo);
        }
      } catch (e) {
        debugPrint(
            '⚠️ [GroupChatScreen] Failed to refresh Group Info page in place: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isGroupInfoRefreshing = false;
          });
        }
      }
      return;
    }

    await _fetchAndShowGroupInfo(widget.group.id, companyId);
  }

  /// Open room for real-time chat (REST + WebSocket)
  ///
  /// Flow:
  /// 1. Ensure membership (REST) - skip if already member from RoomInfo
  /// 2. Fetch message history (REST)
  /// 3. Connect WebSocket if not connected
  /// 4. Join room via WebSocket
  ///
  /// [isMemberFromRoomInfo] - If true, user is already a member (from RoomInfo check)
  ///                          This prevents unnecessary join calls on re-entry
  /// [isRefresh] - If true, this is a refresh call (don't show loading)
  /// [loadInBackground] - If true, don't block UI, load messages asynchronously
  Future<void> _openRoom({
    bool isMemberFromRoomInfo = false,
    bool isRefresh = false,
    bool loadInBackground = false,
  }) async {
    // Prevent concurrent calls
    if (_isOpeningRoom) {
      log('⏸️ [GroupChatScreen] _openRoom already in progress, skipping...');
      return;
    }

    // Rate limiting: Check if enough time has passed since last API call
    if (_lastApiCallTime != null) {
      final timeSinceLastCall = DateTime.now().difference(_lastApiCallTime!);
      if (timeSinceLastCall < _minApiCallInterval) {
        log('⏸️ [GroupChatScreen] Rate limiting: ${_minApiCallInterval.inSeconds - timeSinceLastCall.inSeconds}s remaining before next API call');
        // Wait for the remaining time only if not loading in background
        if (!loadInBackground) {
          await Future.delayed(_minApiCallInterval - timeSinceLastCall);
        }
      }
    }

    _isOpeningRoom = true;
    _lastApiCallTime = DateTime.now();

    // PERFORMANCE OPTIMIZATION: Don't show loading state if loading in background
    // UI should already be visible, just show a subtle loading indicator if needed
    if (!isRefresh && !loadInBackground) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    } else if (loadInBackground) {
      // Clear any previous errors but don't show loading spinner
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
    }

    try {
      // Reset pagination state
      _currentOffset = 0;
      _hasMoreMessages = true;

      // PERFORMANCE OPTIMIZATION: Get company_id synchronously from provider
      // This avoids async API calls that may trigger token refresh
      final selectedFlatState = ref.read(selectedFlatProvider);
      int? companyId = selectedFlatState.selectedSociety?.socId;

      // Fallback to async API only if provider doesn't have it
      if (companyId == null) {
        try {
          companyId = await _apiService.getSelectedSocietyId();
        } catch (e) {
          debugPrint('⚠️ [GroupChatScreen] Error getting companyId: $e');
        }
      }

      if (companyId == null) {
        if (!loadInBackground && mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Please select a society first';
          });
        }
        _isOpeningRoom = false;
        return;
      }

      // Clear unread count when opening group chat (non-blocking)
      UnreadCountManager.instance
          .clearUnreadCount(widget.group.id)
          .catchError((e) {
        debugPrint('⚠️ [GroupChatScreen] Error clearing unread count: $e');
      });

      // PERFORMANCE OPTIMIZATION: Open room using ChatService (handles REST + WebSocket)
      // If user is already a member (from RoomInfo check), skip join call to prevent errors on re-entry
      // If user is not a member, validate membership via join call
      // Backend will check membership using old_gate_user_id from token and handle deduplication
      final response = await _chatService.openRoom(
        roomId: widget.group.id,
        isMember:
            isMemberFromRoomInfo, // Use membership status from RoomInfo check
        companyId: companyId,
        offset: _currentOffset,
      );

      if (!mounted) return;

      // Handle response
      if (response.success) {
        final roomMessages = response.data ?? <RoomMessage>[];

        log('📥 [GroupChatScreen] Received ${roomMessages.length} messages from API');
        for (final rm in roomMessages) {
          log('   Message ID: ${rm.id}, Content: ${rm.body.isEmpty ? "(empty)" : rm.body.substring(0, rm.body.length > 30 ? 30 : rm.body.length)}, isDeleted: ${rm.isDeleted}, messageType: ${rm.messageType ?? "null"}, eventType: ${rm.eventType ?? "null"}');
        }

        // Mark room as read when user opens chat (backend also does this in GetMessages, but we call explicitly for consistency)
        try {
          await _roomService.markRoomAsRead(widget.group.id);
          log('✅ [GroupChatScreen] Room marked as read: ${widget.group.id}');
        } catch (e) {
          log('⚠️ [GroupChatScreen] Failed to mark room as read: $e');
          // Non-critical - continue even if mark-as-read fails
        }

        // Cache avatars from messages API response
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
              // Check if we have this numeric ID mapped to a UUID
              final numericId = int.parse(rm.senderId);
              senderUuid = _numericIdToUuidMap[numericId];

              if (senderUuid == null) {
                // Try to find UUID from current group members
                for (final member in _currentGroup.members) {
                  // Check if member.id matches (could be UUID or numeric string)
                  if (member.id == rm.senderId ||
                      member.id == numericId.toString()) {
                    senderUuid = member.id.contains('-') ? member.id : null;
                    if (senderUuid != null) {
                      _numericIdToUuidMap[numericId] = senderUuid;
                      debugPrint(
                          '✅ [GroupChatScreen] Mapped numeric ID $numericId to UUID $senderUuid');
                      break;
                    }
                  }
                }
              }

              // If still not found, use numeric ID as fallback (but log warning)
              if (senderUuid == null) {
                senderUuid = rm.senderId; // Keep numeric as fallback
                debugPrint(
                    '⚠️ [GroupChatScreen] Could not find UUID for numeric senderId ${rm.senderId}, using numeric as fallback');
              }
            }

            // Use normalized caching for consistency across all message sources
            _cacheAvatarNormalized(
              uuid: senderUuid,
              numericId: rm.snapshotUserId?.toString(),
              avatarUrl: rm.senderAvatar!,
              source: 'API-message',
            );
          }
        }

        // Ensure RoomInfo avatars are available for all senders
        // This ensures avatars from RoomInfo API are used for messages that don't have avatars
        _ensureRoomInfoAvatarsCached();

        // Convert RoomMessage to GroupMessage
        // CRITICAL: Create a map of all messages from this batch first for efficient lookup
        // This ensures replies work even when both the reply and replied-to message are in the same API response
        final groupMessagesWithoutReply = roomMessages
            .map((rm) => _convertRoomMessageToGroupMessage(rm,
                forceDeliveredStatus: true))
            .toList();

        // Create a map of new messages by ID for efficient lookup
        final newMessagesMap = <String, GroupMessage>{};
        for (final gm in groupMessagesWithoutReply) {
          newMessagesMap[gm.id] = gm;
        }

        // Second pass: resolve replyTo references
        // CRITICAL: Check new messages first (same batch), then existing messages
        // This ensures replies work correctly when re-entering chat or when both messages are in same response
        // Also track replied-to messages that need to be added to the message list
        final Set<String> repliedToMessageIds = {};
        final groupMessages = groupMessagesWithoutReply.map((gm) {
          final roomMessage = roomMessages.firstWhere((rm) => rm.id == gm.id);
          if (roomMessage.replyTo != null && roomMessage.replyTo!.isNotEmpty) {
            debugPrint(
                '🔍 [GroupChatScreen] Resolving replyTo for message ${gm.id} (type: ${gm.id.contains("-") ? "UUID" : "numeric"}): looking for ${roomMessage.replyTo} (type: ${roomMessage.replyTo!.contains("-") ? "UUID" : "numeric"})');

            // First, try to find in new messages (same batch) - most common case
            GroupMessage? repliedToMessage = _findMessageById(
              roomMessage.replyTo,
              newMessagesMap,
              groupMessagesWithoutReply,
            );

            // If not found in new messages, try existing messages
            if (repliedToMessage == null) {
              repliedToMessage = _findMessageById(
                roomMessage.replyTo,
                {}, // No map for existing messages, use list search
                _messages,
              );

              if (repliedToMessage != null) {
                debugPrint(
                    '✅ [GroupChatScreen] Found replied-to message in existing messages: ${repliedToMessage.id}');
                // Mark this replied-to message to be preserved in the list
                repliedToMessageIds.add(repliedToMessage.id);
              }
            } else {
              debugPrint(
                  '✅ [GroupChatScreen] Found replied-to message in same batch: ${repliedToMessage.id}');
            }

            // If still not found, try to find the replied-to message in the API response
            if (repliedToMessage == null) {
              try {
                final repliedToRoomMessage = roomMessages.firstWhere(
                  (rm) =>
                      rm.id.trim().toLowerCase() ==
                          roomMessage.replyTo!.trim().toLowerCase() ||
                      rm.id == roomMessage.replyTo,
                );
                repliedToMessage =
                    _convertRoomMessageToGroupMessage(repliedToRoomMessage);
                debugPrint(
                    '✅ [GroupChatScreen] Found replied-to message in API response: ${repliedToMessage.id}');
              } catch (e) {
                // Message not in this batch - try to load older messages to find it
                debugPrint(
                    '⚠️ [GroupChatScreen] Reply target message ${roomMessage.replyTo} not in current batch. Will try to load older messages.');

                // Schedule async fetch of older messages to find the replied-to message
                // This ensures the reply preview is populated even if the message is in an older batch
                _fetchRepliedToMessage(roomMessage.replyTo!, gm.id);

                // Create a temporary placeholder that will be updated when the message is found
                repliedToMessage = GroupMessage(
                  id: roomMessage.replyTo!,
                  groupId: widget.group.id,
                  senderId: '',
                  senderName: 'Loading...',
                  text: 'Loading original message...',
                  timestamp: DateTime.now().subtract(const Duration(hours: 1)),
                  isDeleted: false,
                );
                debugPrint(
                    '⚠️ [GroupChatScreen] Created temporary placeholder for reply target: ${repliedToMessage.id}');
              }
            }

            return gm.copyWith(replyTo: repliedToMessage);
          }
          return gm;
        }).toList();

        // CRITICAL: Preserve replied-to messages from existing messages that are not in the new batch
        // This ensures that when re-entering chat, replied-to messages are not lost
        final preservedRepliedToMessages = <GroupMessage>[];
        for (final existingMessage in _messages) {
          if (repliedToMessageIds.contains(existingMessage.id)) {
            // Check if this message is not already in the new batch
            final isInNewBatch =
                groupMessages.any((m) => m.id == existingMessage.id);
            if (!isInNewBatch) {
              preservedRepliedToMessages.add(existingMessage);
              debugPrint(
                  '✅ [GroupChatScreen] Preserving replied-to message from existing messages: ${existingMessage.id}');
            }
          }
        }

        // CRITICAL: Also ensure replied-to messages found in the same batch are in the list
        // Extract all unique replied-to messages from the reply relationships
        final repliedToMessagesInBatch = <String, GroupMessage>{};
        for (final gm in groupMessages) {
          if (gm.replyTo != null) {
            final repliedToId = gm.replyTo!.id;
            // Check if this replied-to message is already in groupMessages
            final isRepliedToInBatch =
                groupMessages.any((m) => m.id == repliedToId);
            if (!isRepliedToInBatch &&
                !repliedToMessagesInBatch.containsKey(repliedToId)) {
              // The replied-to message is referenced but not in the batch
              // This shouldn't happen if both are in the same batch, but we handle it anyway
              debugPrint(
                  '⚠️ [GroupChatScreen] Replied-to message ${repliedToId} referenced but not in batch');
            } else if (isRepliedToInBatch) {
              // Find the replied-to message in the batch and ensure it's tracked
              final repliedToMsg =
                  groupMessages.firstWhere((m) => m.id == repliedToId);
              repliedToMessagesInBatch[repliedToId] = repliedToMsg;
            }
          }
        }

        log('✅ [GroupChatScreen] Converted to ${groupMessages.length} GroupMessages');

        // CRITICAL: Merge preserved replied-to messages with new messages
        // Sort by timestamp to maintain chronological order
        final allMessages = [...groupMessages, ...preservedRepliedToMessages];
        allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Check if there are more messages
        // Use the actual limit used (which might be doubled for initial load)
        final actualLimit =
            _currentOffset == 0 ? _messagesPerPage * 2 : _messagesPerPage;
        _hasMoreMessages = roomMessages.length >= actualLimit;

        setState(() {
          _messages = allMessages;
          _isLoading = false;
          _hasError = false;
          _currentOffset = groupMessages.length;
        });

        // Reactions are already included in the messages API response
        // No need to fetch them separately
        log('✅ [GroupChatScreen] Reactions included in API response - no separate fetch needed');

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
        await _maybeSendPendingForwardMessages();
        // Reset rate limit retry count on success
        _rateLimitRetryCount = 0;
      } else {
        // Handle errors
        _handleMessageError(response.statusCode, response.displayError);
      }
    } catch (e) {
      if (!mounted) return;
      _handleMessageError(0, 'An unexpected error occurred: $e');
    } finally {
      _isOpeningRoom = false;
    }
  }

  /// Handle incoming WebSocket messages
  Future<void> _handleWebSocketMessage(WebSocketMessage wsMessage) async {
    // Only process messages for current room
    if (wsMessage.roomId != widget.group.id) {
      return;
    }

    // CRITICAL: If user is not a member or has left, don't process any WebSocket messages
    // This prevents viewing future chats after leaving the group and prevents RangeError
    if (!_isUserMember || _hasLeftGroup) {
      log('🚫 [GroupChatScreen] Ignoring WebSocket message - user is not a member or has left group');
      return;
    }

    // Handle typing events from WebSocket (when backend supports it)
    if (wsMessage.data?['type']?.toString().toLowerCase() == 'typing' ||
        wsMessage.type?.toLowerCase() == 'typing') {
      final typingUserId =
          wsMessage.userId ?? wsMessage.data?['user_id']?.toString();
      final typingUserName = wsMessage.data?['user_name']?.toString() ??
          wsMessage.data?['sender_name']?.toString();
      final isTyping = wsMessage.data?['is_typing'] as bool? ?? true;
      if (typingUserId != null) {
        _handleOtherUserTyping(typingUserId, typingUserName, isTyping);
      }
      return; // Don't process typing events as messages
    }

    // Handle unread_count_update events from WebSocket
    final messageType = wsMessage.type?.toLowerCase() ??
        wsMessage.data?['type']?.toString().toLowerCase();
    if (messageType == 'unread_count_update' ||
        wsMessage.messageTypeEnum == WebSocketMessageType.unreadCountUpdate) {
      final roomId = wsMessage.roomId ?? wsMessage.data?['room_id']?.toString();
      final userId = wsMessage.userId ?? wsMessage.data?['user_id']?.toString();
      final unreadCount = wsMessage.data?['unread_count'] as int? ??
          (wsMessage.data?['unread_count'] is String
              ? int.tryParse(wsMessage.data!['unread_count'] as String)
              : null);

      if (roomId != null && userId != null && unreadCount != null) {
        log('📊 [GroupChatScreen] Received unread_count_update: room=$roomId, user=$userId, count=$unreadCount');

        // Update local unread count manager if this is for current user
        if (userId == widget.currentUserId) {
          if (unreadCount == 0) {
            await UnreadCountManager.instance.clearUnreadCount(roomId);
          } else {
            // Set the unread count directly (backend is source of truth)
            await UnreadCountManager.instance
                .setUnreadCount(roomId, unreadCount);
            log('📊 [GroupChatScreen] Unread count updated to $unreadCount for room $roomId');
          }
        }
      }
      return; // Don't process unread_count_update as messages
    }

    // Handle read receipt updates from WebSocket
    // This enables real-time blue checkmarks when other users read your messages
    if (messageType == 'read_receipt' ||
        messageType == 'readreceipt' ||
        wsMessage.messageTypeEnum == WebSocketMessageType.readReceipt) {
      final messageId = wsMessage.data?['message_id']?.toString();
      final userId = wsMessage.userId ?? wsMessage.data?['user_id']?.toString();
      final readAt = wsMessage.data?['read_at'];

      log('📖 [GroupChatScreen] Read receipt received: message=$messageId, user=$userId, readAt=$readAt');

      if (messageId != null && mounted) {
        // Update message status to "seen" (blue checkmarks)
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1 &&
              _messages[index].isFromUser(widget.currentUserId,
                  currentUserNumericId: widget.currentUserNumericId)) {
            _messages[index] = _messages[index].copyWith(
              status: GroupMessageStatus.seen,
            );
            log('✅ [GroupChatScreen] Updated message to SEEN status: $messageId');
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

      log('🚚 [GroupChatScreen] Delivered receipt received: message=$messageId, user=$userId');

      if (messageId != null && mounted) {
        // Update message status to "delivered" (double grey checkmarks)
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1 &&
              _messages[index].isFromUser(widget.currentUserId,
                  currentUserNumericId: widget.currentUserNumericId)) {
            // Only update if current status is sent (don't downgrade from seen)
            if (_messages[index].status == GroupMessageStatus.sent ||
                _messages[index].status == GroupMessageStatus.sending) {
              _messages[index] = _messages[index].copyWith(
                status: GroupMessageStatus.delivered,
              );
              log('✅ [GroupChatScreen] Updated message to DELIVERED status: $messageId');
            }
          }
        });
      }

      return; // Don't process delivered_receipt as regular message
    }

    // Handle presence updates from WebSocket
    if (messageType == 'presence_update' ||
        messageType == 'presenceupdate' ||
        wsMessage.messageTypeEnum == WebSocketMessageType.presenceUpdate) {
      final userId = wsMessage.data?['user_id']?.toString();
      final isOnline = wsMessage.data?['is_online'] as bool?;
      final statusString = wsMessage.data?['status']?.toString();

      log('👤 [GroupChatScreen] Presence update: user=$userId, online=$isOnline, status=$statusString');

      // Presence updates are handled by the parent tab, just log for now
      return; // Don't process presence_update as regular message
    }

    // Handle error messages (e.g., membership errors when user tries to send after leaving)
    if (wsMessage.messageTypeEnum == WebSocketMessageType.error) {
      final errorMessage = wsMessage.error ?? 'Unknown error';
      log('❌ [GroupChatScreen] WebSocket error received: $errorMessage');

      // Check if this is a membership error
      final isMembershipError =
          errorMessage.toLowerCase().contains('not a member') ||
              errorMessage.toLowerCase().contains('cannot send messages') ||
              errorMessage.toLowerCase().contains('membership');

      if (isMembershipError) {
        log('🚫 [GroupChatScreen] Membership error detected - removing optimistic messages and setting non-member status');

        // Remove all optimistic messages (messages with "sending" status from current user)
        // Also set membership status to false to hide input field
        if (mounted) {
          setState(() {
            _isUserMember = false; // User is no longer a member
            final optimisticMessages = _messages
                .where((m) =>
                    m.status == GroupMessageStatus.sending &&
                    m.isFromUser(widget.currentUserId,
                        currentUserNumericId: widget.currentUserNumericId))
                .toList();

            for (final msg in optimisticMessages) {
              _messages.removeWhere((m) => m.id == msg.id);
              log('🗑️ [GroupChatScreen] Removed optimistic message: ${msg.id}');
            }
          });
        }

        // Show error message to user
        if (mounted) {
          EnhancedToast.error(
            context,
            title: 'Access Denied',
            message: errorMessage.contains('You are not a member')
                ? errorMessage
                : 'You are not a member of this room. You cannot send messages here.',
          );
        }
      } else {
        // Other errors - just show to user
        if (mounted) {
          EnhancedToast.error(
            context,
            title: 'Error',
            message: errorMessage,
          );
        }
      }

      return; // Don't process error messages as regular messages
    }

    // Convert WebSocket message to GroupMessage
    if (wsMessage.data != null) {
      // Handle both regular messages and deleted messages
      final isDeleted = wsMessage.data!['is_deleted'] as bool? ?? false;

      // CRITICAL: Extract content - check both content field and data.content
      String content = wsMessage.content ?? '';
      if (content.isEmpty && wsMessage.data != null) {
        // Try to get content from data field
        content = wsMessage.data!['content']?.toString() ?? '';
      }

      log('📥 [GroupChatScreen] WebSocket message received - content length: ${content.length}, data keys: ${wsMessage.data?.keys.toList() ?? []}');

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
        // Ignore parsing errors for optional field
        snapshotUserId = null;
      }

      // Extract reply_to from WebSocket message data
      final replyToId = wsMessage.data?['reply_to']?.toString() ??
          wsMessage.data?['parent_message_id']?.toString();

      // Extract and cache avatar from WebSocket message data if available
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

        // Cache avatar if found using normalized caching for consistency
        if (avatarUrl != null &&
            avatarUrl.isNotEmpty &&
            wsMessage.userId != null) {
          // Extract snapshotUserId for fallback caching
          String? snapshotUserIdStr;
          if (wsMessage.data != null) {
            try {
              final snapshotUserIdValue = wsMessage.data!['snapshot_user_id'];
              if (snapshotUserIdValue != null) {
                snapshotUserIdStr = snapshotUserIdValue is int
                    ? snapshotUserIdValue.toString()
                    : snapshotUserIdValue.toString();
              }
            } catch (e) {
              // Ignore errors
            }
          }

          // Use normalized caching with WebSocket userId as primary and snapshotUserId as fallback
          _cacheAvatarNormalized(
            uuid: wsMessage.userId!.contains('-') ? wsMessage.userId : null,
            numericId: snapshotUserIdStr ??
                (wsMessage.userId!.contains('-') ? null : wsMessage.userId),
            avatarUrl: avatarUrl,
            source: 'WebSocket',
          );
        }
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

      // Extract sender name from WebSocket message data
      // user_name is now guaranteed to be present in API response
      String senderName = 'User';
      if (wsMessage.data != null) {
        // Prioritize user_name since it's always populated
        // Check for non-empty strings, not just null
        final userName = wsMessage.data!['user_name']?.toString();
        if (userName != null && userName.isNotEmpty) {
          senderName = userName;
        } else {
          final senderNameField = wsMessage.data!['sender_name']?.toString();
          if (senderNameField != null && senderNameField.isNotEmpty) {
            senderName = senderNameField;
          } else {
            final nameField = wsMessage.data!['name']?.toString();
            if (nameField != null && nameField.isNotEmpty) {
              senderName = nameField;
            }
          }
        }

        // Also try user_snapshot as fallback if still 'User'
        if (senderName == 'User' && wsMessage.data!['user_snapshot'] != null) {
          final userSnapshot = wsMessage.data!['user_snapshot'];
          if (userSnapshot is Map) {
            final snapshotMap = userSnapshot is Map<String, dynamic>
                ? userSnapshot
                : <String, dynamic>{
                    ...userSnapshot
                        .map((key, value) => MapEntry(key.toString(), value))
                  };
            final snapshotUserName = snapshotMap['user_name']?.toString();
            if (snapshotUserName != null && snapshotUserName.isNotEmpty) {
              senderName = snapshotUserName;
            } else {
              final snapshotName = snapshotMap['name']?.toString();
              if (snapshotName != null && snapshotName.isNotEmpty) {
                senderName = snapshotName;
              }
            }
          }
        }

        // Reject UUID-like strings and "user_" prefixed UUIDs - these are IDs, not names
        if (_isUuidLike(senderName)) {
          debugPrint(
              '⚠️ [GroupChatScreen] Rejected UUID-like senderName: $senderName, using "User" instead');
          senderName = 'User';
        }
      }

      // Extract message ID - CRITICAL: Must be UUID, not timestamp
      String messageId = wsMessage.data!['id'] as String? ?? '';
      // Validate message ID is UUID format (not timestamp)
      if (messageId.isEmpty) {
        debugPrint(
            '⚠️ [GroupChatScreen] WebSocket message has no ID, skipping message');
        return; // Skip messages without ID - they can't be processed
      }

      // Check if message ID is valid UUID format
      final isUuidFormat = messageId.contains('-') && messageId.length > 30;
      if (!isUuidFormat && int.tryParse(messageId) != null) {
        // Numeric ID - log warning but process it (backend might accept it)
        debugPrint(
            '⚠️ [GroupChatScreen] WebSocket message ID is numeric (not UUID): $messageId - reactions may fail');
      }

      // CRITICAL: If message ID is still empty or invalid, skip this message
      // Backend must provide valid UUID message ID for reactions to work
      if (messageId.isEmpty) {
        debugPrint(
            '⚠️ [GroupChatScreen] WebSocket message has no ID, cannot process message');
        return; // Skip messages without ID
      }

      // Extract sender avatar from WebSocket if available (already extracted above)
      final senderAvatar = avatarUrl;

      debugPrint(
          '📨 [GroupChatScreen] Processing WebSocket message: id=$messageId, senderId=${wsMessage.userId}, senderName=$senderName, hasAvatar=${senderAvatar != null}');

      // Extract message_type and event_type from WebSocket data
      final messageType = wsMessage.data!['message_type']?.toString();
      final eventType = wsMessage.data!['event_type']?.toString();

      // If content is empty but data carries file/audio info, synthesize minimal JSON content
      if ((content.isEmpty || content.trim().isEmpty)) {
        final fileUrl = wsMessage.data!['file_url']?.toString() ??
            wsMessage.data!['fileUrl']?.toString() ??
            wsMessage.data!['url']?.toString() ??
            wsMessage.data!['audio_url']?.toString();
        final mimeType = wsMessage.data!['mime_type']?.toString();
        final fileName = wsMessage.data!['file_name']?.toString();
        final fileType = wsMessage.data!['file_type']?.toString();
        final durationMs = wsMessage.data!['duration_ms'];

        if (fileUrl != null && fileUrl.isNotEmpty) {
          final synthesized = <String, dynamic>{
            'file_url': fileUrl,
            if (mimeType != null) 'mime_type': mimeType,
            if (fileName != null) 'file_name': fileName,
            if (fileType != null) 'file_type': fileType,
            if (durationMs != null) 'duration_ms': durationMs,
          };
          content = jsonEncode(synthesized);
          debugPrint(
              '🧩 [GroupChatScreen] Synthesized content from ws.data for missing body');
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
      final forwardedRaw = wsMessage.data?['is_forwarded'] ??
          wsMessage.data?['forwarded'] ??
          wsMessage.data?['forward'];
      if (forwardedRaw != null) {
        isForwarded = _parseBool(forwardedRaw);
      }

      if (!isForwarded) {
        final dataMap = wsMessage.data ?? {};
        if (_hasForwardMarker(dataMap)) {
          isForwarded = true;
        }
      }

      final lowerType = (messageType ?? wsMessage.type ?? '').toLowerCase();
      if (!isForwarded && lowerType.contains('forward')) {
        isForwarded = true;
      }

      final roomMessage = RoomMessage(
        id: messageId,
        roomId: wsMessage.roomId!,
        senderId: wsMessage.userId!,
        senderName: senderName,
        senderAvatar: senderAvatar, // Include avatar from WebSocket
        body: content,
        createdAt: wsMessage.data!['created_at'] != null
            ? DateTime.parse(wsMessage.data!['created_at'] as String)
            : DateTime.now(),
        editedAt: wsMessage.data!['edited_at'] != null
            ? DateTime.parse(wsMessage.data!['edited_at'] as String)
            : null,
        updatedAt: wsMessage.data!['updated_at'] != null
            ? DateTime.parse(wsMessage.data!['updated_at'] as String)
            : null,
        isDeleted: isDeleted,
        deletedAt: wsMessage.data!['deleted_at'] != null
            ? DateTime.parse(wsMessage.data!['deleted_at'] as String)
            : null,
        deletedBy: wsMessage.data!['deleted_by']?.toString(),
        snapshotUserId: snapshotUserId,
        replyTo: replyToId,
        reactions: reactions, // Reactions included in WebSocket message
        messageType: messageType,
        eventType: eventType,
        isForwarded: isForwarded,
      );

      // Find the message being replied to if reply_to is present
      // CRITICAL: Check existing messages to find replied-to message with UUID compatibility
      // This ensures replies work even if the replied-to message was loaded earlier
      GroupMessage? replyToMessage;
      if (roomMessage.replyTo != null && roomMessage.replyTo!.isNotEmpty) {
        debugPrint(
            '🔍 [GroupChatScreen] Resolving replyTo for WebSocket message ${roomMessage.id} (type: ${roomMessage.id.contains("-") ? "UUID" : "numeric"}): looking for ${roomMessage.replyTo} (type: ${roomMessage.replyTo!.contains("-") ? "UUID" : "numeric"})');

        replyToMessage = _findMessageById(
          roomMessage.replyTo,
          {},
          _messages,
        );

        if (replyToMessage != null) {
          debugPrint(
              '✅ [GroupChatScreen] Found replied-to message in existing messages (WebSocket): ${replyToMessage.id}');
        } else {
          // Message not found in loaded messages
          // Create a minimal placeholder that preserves the reply relationship
          // but doesn't break the UI
          replyToMessage = GroupMessage(
            id: roomMessage.replyTo!,
            groupId: widget.group.id,
            senderId: '',
            senderName: 'Unknown',
            text: 'Original message', // Placeholder text that won't break UI
            timestamp: DateTime.now()
                .subtract(const Duration(hours: 1)), // Placeholder time
            isDeleted:
                false, // Don't mark as deleted - this preserves reply display
          );
          log('⚠️ [GroupChatScreen] Reply target message ${roomMessage.replyTo} not found in loaded messages (WebSocket). Using placeholder.');
        }
      }

      final groupMessage =
          _convertRoomMessageToGroupMessage(roomMessage).copyWith(
        replyTo: replyToMessage,
      );

      // Check if message already exists (prevent duplicates)
      // CRITICAL: Match by ID, or by content/file URL for current user's optimistic messages
      // This prevents duplicate messages when WebSocket returns server-generated ID
      final isFromCurrentUser = groupMessage.isFromUser(
        widget.currentUserId,
        currentUserNumericId: widget.currentUserNumericId,
      );

      // Extract file URL from WebSocket message body for matching
      String? wsFileUrl;
      if (roomMessage.messageType == 'image' ||
          roomMessage.messageType == 'file') {
        try {
          final bodyJson =
              jsonDecode(roomMessage.body) as Map<String, dynamic>?;
          if (bodyJson != null) {
            wsFileUrl = bodyJson['file_url']?.toString();
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }

      final existingIndex = _messages.indexWhere((m) {
        // Exact ID match
        if (m.id == groupMessage.id) return true;

        // For current user's messages, also match by content/file URL
        if (isFromCurrentUser) {
          final mIsFromCurrentUser = m.isFromUser(
            widget.currentUserId,
            currentUserNumericId: widget.currentUserNumericId,
          );

          // CRITICAL: Check both sending AND sent status (message might have been updated after upload)
          if (mIsFromCurrentUser &&
              (m.status == GroupMessageStatus.sending ||
                  m.status == GroupMessageStatus.sent)) {
            // Match by timestamp (within 10 seconds to account for upload time)
            final timeDiff =
                m.timestamp.difference(groupMessage.timestamp).inSeconds.abs();
            if (timeDiff < 10) {
              // For file messages, match by file URL (most reliable)
              if (wsFileUrl != null && wsFileUrl.isNotEmpty) {
                // Match by image URL
                if (m.firstImageUrl != null && wsFileUrl == m.firstImageUrl) {
                  log('✅ [GroupChatScreen] Matched optimistic message by image URL: $wsFileUrl');
                  return true;
                }
                // Match by document URL
                if (m.documentUrl != null && wsFileUrl == m.documentUrl) {
                  log('✅ [GroupChatScreen] Matched optimistic message by document URL: $wsFileUrl');
                  return true;
                }
                // CRITICAL FIX: Match by video URL (for video messages)
                if (m.videoUrl != null && wsFileUrl == m.videoUrl) {
                  log('✅ [GroupChatScreen] Matched optimistic message by video URL: $wsFileUrl');
                  return true;
                }
              }

              // Also check if groupMessage has file URLs extracted
              if (groupMessage.firstImageUrl != null ||
                  groupMessage.documentUrl != null ||
                  groupMessage.videoUrl != null) {
                // Match by image URL
                if (groupMessage.firstImageUrl != null &&
                    m.firstImageUrl != null &&
                    groupMessage.firstImageUrl == m.firstImageUrl) {
                  log('✅ [GroupChatScreen] Matched optimistic message by image URL (from groupMessage): ${groupMessage.firstImageUrl}');
                  return true;
                }
                // Match by document URL
                if (groupMessage.documentUrl != null &&
                    m.documentUrl != null &&
                    groupMessage.documentUrl == m.documentUrl) {
                  log('✅ [GroupChatScreen] Matched optimistic message by document URL (from groupMessage): ${groupMessage.documentUrl}');
                  return true;
                }
                // CRITICAL FIX: Match by video URL (from groupMessage)
                if (groupMessage.videoUrl != null &&
                    m.videoUrl != null &&
                    groupMessage.videoUrl == m.videoUrl) {
                  log('✅ [GroupChatScreen] Matched optimistic message by video URL (from groupMessage): ${groupMessage.videoUrl}');
                  return true;
                }
              }

              // For text messages, match by content (not file/media messages)
              if (wsFileUrl == null &&
                  groupMessage.firstImageUrl == null &&
                  groupMessage.documentUrl == null &&
                  groupMessage.videoUrl == null) {
                if (groupMessage.text.isNotEmpty &&
                    m.text.isNotEmpty &&
                    groupMessage.text == m.text) {
                  log('✅ [GroupChatScreen] Matched optimistic message by text content');
                  return true;
                }
              }

              // Forward placeholder match (temp_forward_*)
              if (m.isForwarded && m.id.startsWith('temp_forward_')) {
                bool mediaMatch = false;
                if (groupMessage.firstImageUrl != null &&
                    groupMessage.firstImageUrl!.isNotEmpty &&
                    groupMessage.firstImageUrl == m.firstImageUrl) {
                  mediaMatch = true;
                }
                if (groupMessage.documentUrl != null &&
                    groupMessage.documentUrl!.isNotEmpty &&
                    groupMessage.documentUrl == m.documentUrl) {
                  mediaMatch = true;
                }
                if (groupMessage.audioUrl != null &&
                    groupMessage.audioUrl!.isNotEmpty &&
                    groupMessage.audioUrl == m.audioUrl) {
                  mediaMatch = true;
                }
                if (groupMessage.videoUrl != null &&
                    groupMessage.videoUrl!.isNotEmpty &&
                    groupMessage.videoUrl == m.videoUrl) {
                  mediaMatch = true;
                }
                if (mediaMatch ||
                    (groupMessage.text.isNotEmpty &&
                        groupMessage.text == m.text)) {
                  log('✅ [GroupChatScreen] Matched forwarded placeholder');
                  return true;
                }
              }

              // Fallback: match by timestamp if very close (within 3 seconds)
              // This catches cases where file URL matching might fail
              if (timeDiff < 3) {
                log('✅ [GroupChatScreen] Matched optimistic message by timestamp (fallback): $timeDiff seconds');
                return true;
              }
            }
          }
        }

        return false;
      });

      if (existingIndex == -1) {
        // CRITICAL FIX: Don't process messages if user has left group
        // This prevents RangeError and ensures messages aren't added after leave
        if (_hasLeftGroup || !_isUserMember) {
          log('🚫 [GroupChatScreen] Ignoring WebSocket message - user has left group');
          return;
        }

        // New message - add it and update status
        debugPrint(
            '✅ [GroupChatScreen] Adding new WebSocket message: id=${groupMessage.id}, senderId=${groupMessage.senderId}, senderName=${groupMessage.senderName}, text=${groupMessage.text.substring(0, groupMessage.text.length > 30 ? 30 : groupMessage.text.length)}');
        if (mounted) {
          setState(() {
            // Insert message in correct chronological order
            final insertIndex = _messages
                .indexWhere((m) => m.timestamp.isAfter(groupMessage.timestamp));
            if (insertIndex == -1) {
              _messages.add(groupMessage);
              debugPrint(
                  '✅ [GroupChatScreen] Added message to end of list (total: ${_messages.length})');
            } else {
              // CRITICAL FIX: Bounds check before insert
              if (insertIndex >= 0 && insertIndex <= _messages.length) {
                _messages.insert(insertIndex, groupMessage);
                debugPrint(
                    '✅ [GroupChatScreen] Inserted message at index $insertIndex (total: ${_messages.length})');
              } else {
                debugPrint(
                    '⚠️ [GroupChatScreen] Invalid insertIndex: $insertIndex (messages.length: ${_messages.length}), adding to end');
                _messages.add(groupMessage);
              }
            }

            // Update message status progression
            _updateMessageStatus(groupMessage.id);
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

          // FIX: Invalidate member cache when someone leaves the group
          // This ensures group info page shows updated member list immediately
          if (roomMessage.eventType?.toLowerCase() == 'user_left') {
            final roomInfoCache = RoomInfoCache();
            roomInfoCache.markMemberLeft(widget.group.id);
            log('🚪 [GroupChatScreen] User left group - invalidated member cache for room: ${widget.group.id}');
          }
        }
      } else {
        // Message exists - update it with real data from server
        // This replaces optimistic message with persisted message

        // CRITICAL FIX: Check bounds before accessing message by index
        // This prevents RangeError if messages were cleared (e.g., after leaving group)
        if (existingIndex < 0 || existingIndex >= _messages.length) {
          log('⚠️ [GroupChatScreen] Invalid existingIndex: $existingIndex (messages.length: ${_messages.length}), skipping update');
          return;
        }

        // CRITICAL FIX: Don't process if user has left group
        if (_hasLeftGroup || !_isUserMember) {
          log('🚫 [GroupChatScreen] Ignoring message update - user has left group');
          return;
        }

        if (mounted) {
          setState(() {
            // Get the existing optimistic message (safe access after bounds check)
            final existingMessage = _messages[existingIndex];

            // If the existing message is from current user (optimistic), preserve senderId and snapshotUserId
            // to ensure consistent identification - this ensures messages always show on the right side
            final wasFromCurrentUser = existingMessage.isFromUser(
              widget.currentUserId,
              currentUserNumericId: widget.currentUserNumericId,
            );

            // Check if this is an edited message (has editedAt timestamp)
            final isEditedMessage = groupMessage.editedAt != null;

            // For edited messages from current user, set to delivered immediately (double tick)
            // For new messages, start with sent and progress to delivered
            final initialStatus = (wasFromCurrentUser && isEditedMessage)
                ? GroupMessageStatus.delivered
                : GroupMessageStatus.sent;

            // Create updated message with correct identification
            // Use groupMessage from server but ensure senderId/snapshotUserId match current user if needed
            final updatedMessage = wasFromCurrentUser
                ? GroupMessage(
                    id: groupMessage.id,
                    groupId: groupMessage.groupId,
                    senderId: widget.currentUserId, // Use current user's UUID
                    senderName: groupMessage.senderName,
                    senderPhotoUrl: groupMessage.senderPhotoUrl,
                    text: groupMessage.text,
                    timestamp: groupMessage.timestamp,
                    editedAt: groupMessage.editedAt,
                    isDeleted: groupMessage.isDeleted,
                    imageFile: groupMessage.imageFile,
                    isLocation: groupMessage.isLocation,
                    isDocument: groupMessage.isDocument,
                    documentName: groupMessage.documentName,
                    documentType: groupMessage.documentType,
                    documentFile: groupMessage.documentFile,
                    isContact: groupMessage.isContact,
                    isAudio: groupMessage.isAudio,
                    audioFile: groupMessage.audioFile,
                    audioDuration: groupMessage.audioDuration ??
                        existingMessage.audioDuration,
                    audioUrl: groupMessage.audioUrl ?? existingMessage.audioUrl,
                    videoFile: groupMessage.videoFile,
                    videoThumbnail: groupMessage.videoThumbnail,
                    status: initialStatus,
                    reactions: groupMessage.reactions,
                    replyTo: existingMessage.replyTo ??
                        groupMessage.replyTo, // Preserve from optimistic
                    linkPreview: existingMessage.linkPreview ??
                        groupMessage.linkPreview, // Preserve from optimistic
                    imageUrls: groupMessage.imageUrls?.isNotEmpty == true
                        ? groupMessage.imageUrls
                        : existingMessage.imageUrls,
                    documentUrl: groupMessage.documentUrl?.isNotEmpty == true
                        ? groupMessage.documentUrl
                        : existingMessage.documentUrl,
                    videoUrl: groupMessage.videoUrl?.isNotEmpty == true
                        ? groupMessage.videoUrl
                        : existingMessage.videoUrl,
                    isVideo: groupMessage.isVideo || existingMessage.isVideo,
                    isRead: groupMessage.isRead,
                    isSystemMessage: groupMessage.isSystemMessage,
                    snapshotUserId: widget.currentUserNumericId,
                  )
                : groupMessage.copyWith(
                    status: initialStatus,
                    replyTo: existingMessage.replyTo ??
                        groupMessage.replyTo, // Preserve from optimistic
                    linkPreview: existingMessage.linkPreview ??
                        groupMessage.linkPreview, // Preserve from optimistic
                    // CRITICAL: Use server's imageUrls/documentUrl if available, otherwise preserve from optimistic
                    imageUrls: groupMessage.imageUrls?.isNotEmpty == true
                        ? groupMessage.imageUrls
                        : existingMessage.imageUrls,
                    documentUrl: groupMessage.documentUrl?.isNotEmpty == true
                        ? groupMessage.documentUrl
                        : existingMessage.documentUrl,
                    videoUrl: groupMessage.videoUrl?.isNotEmpty == true
                        ? groupMessage.videoUrl
                        : existingMessage.videoUrl,
                    isVideo: groupMessage.isVideo || existingMessage.isVideo,
                    audioUrl: groupMessage.audioUrl ?? existingMessage.audioUrl,
                    audioDuration: groupMessage.audioDuration ??
                        existingMessage.audioDuration,
                    isAudio: groupMessage.isAudio,
                  );

            // CRITICAL FIX: Double-check bounds before assignment (defensive programming)
            // This prevents RangeError if messages list was modified during setState
            if (existingIndex >= 0 && existingIndex < _messages.length) {
              _messages[existingIndex] = updatedMessage;
            } else {
              log('⚠️ [GroupChatScreen] Cannot update message - index out of bounds: $existingIndex (messages.length: ${_messages.length})');
            }

            // NOTE: Status transitions (sent -> delivered -> seen) are now handled by WebSocket events
            // - delivered_receipt: Backend sends when message is delivered to recipients
            // - read_receipt: Backend sends when message is read by recipients
            // This ensures status indicators reflect real read/delivered status, not fake timers

            // FIX: Invalidate member cache when someone leaves the group (for updated messages too)
            // This ensures group info page shows updated member list immediately
            if (roomMessage.eventType?.toLowerCase() == 'user_left') {
              final roomInfoCache = RoomInfoCache();
              roomInfoCache.markMemberLeft(widget.group.id);
              log('🚪 [GroupChatScreen] User left group (message update) - invalidated member cache for room: ${widget.group.id}');
            }
          });
        }
      }
    }
  }

  /// Load older messages for pagination
  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Get company_id for API call from selectedFlatProvider
      final selectedFlatState = ref.read(selectedFlatProvider);
      final companyId = selectedFlatState.selectedSociety?.socId;
      if (companyId == null) {
        if (mounted) {
          setState(() {
            _isLoadingMore = false;
          });
        }
        return;
      }

      // Load next page using ChatService
      // CRITICAL: Load more messages initially to increase chances of finding replied-to messages
      // This ensures reply previews are populated even when the replied-to message is slightly older
      final initialLimit =
          _currentOffset == 0 ? _messagesPerPage * 2 : _messagesPerPage;

      final response = await _chatService.fetchMessages(
        roomId: widget.group.id,
        companyId: companyId,
        limit: initialLimit,
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
          return;
        }

        // Cache avatars from messages API response (pagination)
        // CRITICAL: Convert numeric senderId to UUID using mapping, then cache with UUID
        for (final rm in roomMessages) {
          if (rm.senderAvatar != null &&
              rm.senderAvatar!.isNotEmpty &&
              rm.senderId.isNotEmpty) {
            // Determine UUID for this sender
            String? senderUuid = rm.senderId;

            // If senderId is numeric, try to find UUID from mapping
            if (!rm.senderId.contains('-') &&
                int.tryParse(rm.senderId) != null) {
              final numericId = int.parse(rm.senderId);
              senderUuid = _numericIdToUuidMap[numericId];

              if (senderUuid == null && rm.snapshotUserId != null) {
                // Try snapshotUserId as fallback
                senderUuid = _numericIdToUuidMap[rm.snapshotUserId];
              }

              if (senderUuid == null) {
                senderUuid = rm.senderId; // Keep numeric as fallback
                debugPrint(
                    '⚠️ [GroupChatScreen] Could not find UUID for numeric senderId ${rm.senderId} (pagination), using numeric as fallback');
              }
            }

            // Use normalized caching for consistency across all message sources
            _cacheAvatarNormalized(
              uuid: senderUuid,
              numericId: rm.snapshotUserId?.toString(),
              avatarUrl: rm.senderAvatar!,
              source: 'API-pagination',
            );
          }
        }

        // Convert RoomMessage to GroupMessage
        // CRITICAL: Create a map of all messages from this batch first for efficient lookup
        final newGroupMessagesWithoutReply = roomMessages
            .map((rm) => _convertRoomMessageToGroupMessage(rm,
                forceDeliveredStatus: true))
            .toList();

        // Create a map of new messages by ID for efficient lookup
        final newMessagesMap = <String, GroupMessage>{};
        for (final gm in newGroupMessagesWithoutReply) {
          newMessagesMap[gm.id] = gm;
        }

        // Second pass: resolve replyTo references (check new messages first, then existing)
        final newGroupMessages = newGroupMessagesWithoutReply.map((gm) {
          final roomMessage = roomMessages.firstWhere((rm) => rm.id == gm.id);
          if (roomMessage.replyTo != null && roomMessage.replyTo!.isNotEmpty) {
            debugPrint(
                '🔍 [GroupChatScreen] Resolving replyTo for message ${gm.id} (pagination, type: ${gm.id.contains("-") ? "UUID" : "numeric"}): looking for ${roomMessage.replyTo} (type: ${roomMessage.replyTo!.contains("-") ? "UUID" : "numeric"})');

            // First, try to find in new messages (same batch) - most common case
            GroupMessage? repliedToMessage = _findMessageById(
              roomMessage.replyTo,
              newMessagesMap,
              newGroupMessagesWithoutReply,
            );

            // If not found in new messages, try existing messages
            if (repliedToMessage == null) {
              repliedToMessage = _findMessageById(
                roomMessage.replyTo,
                {},
                _messages,
              );

              if (repliedToMessage != null) {
                debugPrint(
                    '✅ [GroupChatScreen] Found replied-to message in existing messages (pagination): ${repliedToMessage.id}');
              }
            } else {
              debugPrint(
                  '✅ [GroupChatScreen] Found replied-to message in same batch (pagination): ${repliedToMessage.id}');
            }

            // If still not found, try to find the replied-to message in the API response
            if (repliedToMessage == null) {
              try {
                final repliedToRoomMessage = roomMessages.firstWhere(
                  (rm) =>
                      rm.id.trim().toLowerCase() ==
                          roomMessage.replyTo!.trim().toLowerCase() ||
                      rm.id == roomMessage.replyTo,
                );
                repliedToMessage =
                    _convertRoomMessageToGroupMessage(repliedToRoomMessage);
                debugPrint(
                    '✅ [GroupChatScreen] Found replied-to message in API response (pagination): ${repliedToMessage.id}');
              } catch (e) {
                // Message not in this batch - create placeholder
                repliedToMessage = GroupMessage(
                  id: roomMessage.replyTo!,
                  groupId: widget.group.id,
                  senderId: '',
                  senderName: 'Unknown',
                  text: 'Original message', // Placeholder text
                  timestamp: DateTime.now().subtract(const Duration(hours: 1)),
                  isDeleted: false,
                );
                debugPrint(
                    '⚠️ [GroupChatScreen] Created placeholder for reply target (pagination): ${repliedToMessage.id}');
              }
            }

            return gm.copyWith(replyTo: repliedToMessage);
          }
          return gm;
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

        // Insert older messages at the beginning
        setState(() {
          _messages.insertAll(0, newGroupMessages);
          _isLoadingMore = false;
          _currentOffset += newGroupMessages.length;
        });

        // Maintain scroll position after inserting older messages
        if (_scrollController.hasClients) {
          final newMaxScrollExtent = _scrollController.position.maxScrollExtent;
          final scrollDifference = newMaxScrollExtent - maxScrollExtent;
          _scrollController.jumpTo(currentScrollPosition + scrollDifference);
        }
      } else {
        setState(() {
          _isLoadingMore = false;
        });
        _handleMessageError(response.statusCode, response.displayError);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      _handleMessageError(0, 'Failed to load older messages: $e');
    }
  }

  /// Handle message loading errors
  void _handleMessageError(int? statusCode, String errorMessage) {
    setState(() {
      _isLoading = false;
      _isLoadingMore = false;
      _hasError = true;
      _errorMessage = errorMessage;
    });

    if (statusCode == 401) {
      // Token expired - logout
      EnhancedToast.error(
        context,
        title: 'Authentication Error',
        message: 'Your session has expired. Please login again.',
      );
      // TODO: Navigate to login screen
    } else if (statusCode == 403) {
      // NOT A MEMBER ERROR - This is the critical error that blocks sending
      // RoomInfo API may fail with 403 for various reasons (timing, permissions, etc.)
      // But if join API succeeds, the user should be able to chat
      // Only set membership to false if this is a genuine membership issue

      // CRITICAL FIX: Be very specific about membership errors to avoid false positives
      // Generic "access denied" or "not authorized" could be API permission issues, not membership
      final errorLower = errorMessage.toLowerCase();
      final isMembershipError =
          errorLower.contains('not a member') ||
              errorLower.contains('no longer a member') ||
              errorLower.contains('left the group') ||
              errorLower.contains('removed from group') ||
              errorLower.contains('membership') ||
              (errorLower.contains('forbidden') && errorLower.contains('member'));

      if (!isMembershipError) {
        // This is likely an API permission issue, not actual membership
        // Could be rate limiting (403 instead of 429), token issues, or server errors
        log('⚠️ [GroupChatScreen] 403 but NOT membership error (ignoring): "$errorMessage"');
        log('   Treating as API permission issue, not membership issue');
        // Don't set _isUserMember = false - let join API determine membership
        return;
      }

      // Genuine membership error - user cannot access this group
      log('🚫 [GroupChatScreen] Genuine membership error: "$errorMessage"');
      setState(() {
        _isUserMember = false;
        _hasError = true;
        _errorMessage = 'You are not a member of this group';
      });

      EnhancedToast.error(
        context,
        title: 'Access Denied',
        message: 'You are not a member of this group',
      );
    } else if (statusCode == 404) {
      // Room not found
      EnhancedToast.error(
        context,
        title: 'Room Not Found',
        message: 'This room does not exist',
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

      log('⚠️ [GroupChatScreen] Rate limit error (429). Retry count: $_rateLimitRetryCount, Backoff: ${backoffSeconds}s');

      // Auto-retry after backoff period
      Future.delayed(Duration(seconds: backoffSeconds), () {
        if (mounted && _hasError) {
          log('🔄 [GroupChatScreen] Auto-retrying after rate limit backoff...');
          _openRoom();
        }
      });
    } else if (statusCode == 500) {
      // Server error - show retry option
      EnhancedToast.error(
        context,
        title: 'Server Error',
        message: 'Unable to load messages. Please try again.',
      );
    } else if (statusCode == 0) {
      // Network error
      EnhancedToast.error(
        context,
        title: 'Network Error',
        message: 'Unable to connect. Please check your internet connection.',
      );
    } else {
      // Other errors
      EnhancedToast.error(
        context,
        title: 'Error',
        message: errorMessage,
      );
    }
  }

  /// Fetch messages directly without join call
  /// Used when RoomInfo shows user is a member but join call fails with 403
  Future<void> _fetchMessagesDirectly() async {
    try {
      log('🔄 [GroupChatScreen] Fetching messages directly (skipping join)');

      final companyId = await _apiService.getSelectedSocietyId();
      if (companyId == null) {
        log('❌ [GroupChatScreen] Company ID not available');
        return;
      }

      // Fetch messages directly
      final messagesResponse = await _chatService.fetchMessages(
        roomId: widget.group.id,
        companyId: companyId,
        limit: _messagesPerPage,
        offset: _currentOffset,
      );

      if (messagesResponse.success && messagesResponse.data != null) {
        final roomMessages = messagesResponse.data!;
        log('✅ [GroupChatScreen] Successfully fetched ${roomMessages.length} messages directly');

        // Process messages using existing conversion method
        final chatMessages = roomMessages
            .map((rm) => _convertRoomMessageToGroupMessage(rm,
                forceDeliveredStatus: true))
            .toList();

        setState(() {
          _messages = chatMessages;
          _isLoading = false;
          _hasError = false;
          _currentOffset = chatMessages.length;
          _hasMoreMessages = roomMessages.length >= _messagesPerPage;
        });
        _insertForwardPlaceholders();
        await _maybeSendPendingForwardMessages();

        // Connect WebSocket with UUID (skip join since user is already a member)
        if (widget.group.id.isNotEmpty && widget.group.id.contains('-')) {
          log('🔌 [GroupChatScreen] Connecting WebSocket with UUID: ${widget.group.id}');
          await _chatService.openRoom(
            roomId: widget.group.id,
            isMember: true, // Skip join since we already know user is a member
            companyId: companyId,
            limit: 0, // Don't fetch messages again
            offset: 0,
          );
        }
      } else {
        log('❌ [GroupChatScreen] Failed to fetch messages directly: ${messagesResponse.error}');
        // If even direct fetch fails, show error
        _handleMessageError(
            messagesResponse.statusCode, messagesResponse.displayError);
      }
    } catch (e) {
      log('❌ [GroupChatScreen] Error fetching messages directly: $e');
      _handleMessageError(0, 'Failed to load messages: $e');
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

  /// Convert RoomMessage to GroupMessage for UI compatibility
  /// [forceDeliveredStatus] - If true, sets current user messages to delivered status (for REST API loads)
  /// If false, uses sent status (for WebSocket messages that need progression)
  GroupMessage _convertRoomMessageToGroupMessage(
    RoomMessage roomMessage, {
    bool forceDeliveredStatus = false,
  }) {
    // Check if this message is from the current user
    // This ensures consistent identification regardless of server's senderId format
    final isFromCurrentUser = _isMessageFromCurrentUser(roomMessage);

    // If message is from current user, use widget.currentUserId and widget.currentUserNumericId
    // to ensure isFromUser() always returns true
    final senderId =
        isFromCurrentUser ? widget.currentUserId : roomMessage.senderId;
    final snapshotUserId = isFromCurrentUser
        ? widget.currentUserNumericId
        : roomMessage.snapshotUserId;

    // For messages from current user loaded from REST API, set to delivered (double tick)
    // For WebSocket messages, use sent so they can progress through states
    final status = (isFromCurrentUser && forceDeliveredStatus)
        ? GroupMessageStatus.delivered
        : GroupMessageStatus.sent;

    // Get cached avatar for sender
    // CRITICAL: Convert numeric senderId to UUID for lookup
    String? senderAvatar = roomMessage.senderAvatar;

    if (senderAvatar == null || senderAvatar.isEmpty) {
      // Use normalized avatar lookup for consistency across all message sources
      String? lookupUuid = senderId;

      // If senderId is numeric, try to find UUID from mapping or current group members
      if (!senderId.contains('-') && int.tryParse(senderId) != null) {
        final numericId = int.parse(senderId);
        lookupUuid = _numericIdToUuidMap[numericId];
        if (lookupUuid == null) {
          // Try to find from current group members
          for (final member in _currentGroup.members) {
            final memberIdInt = int.tryParse(member.id);
            if (memberIdInt == numericId || member.id == senderId) {
              if (member.id.contains('-')) {
                lookupUuid = member.id;
                _numericIdToUuidMap[numericId] = lookupUuid;
                break;
              }
            }
          }
        }
      }

      // Use normalized lookup with all available keys
      senderAvatar = _getAvatarNormalized(
        uuid: lookupUuid?.contains('-') == true ? lookupUuid : null,
        numericId: roomMessage.snapshotUserId?.toString() ??
            (senderId.contains('-') ? null : senderId),
        fallbackId: senderId,
      );

      if (senderAvatar != null && senderAvatar.isNotEmpty) {
        debugPrint(
            '✅ [GroupChatScreen] Avatar found via normalized lookup: UUID=$lookupUuid, senderId=$senderId, snapshotUserId=${roomMessage.snapshotUserId}');
      } else {
        debugPrint(
            '🔍 [GroupChatScreen] Avatar lookup failed: tried UUID=$lookupUuid, senderId=$senderId, snapshotUserId=${roomMessage.snapshotUserId}');
      }

      // PRIORITY 4: Last resort - try to get avatar from _currentGroup.members (from RoomInfo)
      // This ensures we use RoomInfo avatars even if cache lookup failed
      if ((senderAvatar == null || senderAvatar.isEmpty)) {
        try {
          final member = _currentGroup.members.firstWhere(
            (m) =>
                m.id == senderId ||
                m.id == lookupUuid ||
                (lookupUuid != null &&
                    m.id.contains('-') &&
                    m.id == lookupUuid),
            orElse: () => IntercomContact(
              id: '',
              name: '',
              type: IntercomContactType.resident,
            ),
          );
          if (member.photoUrl != null && member.photoUrl!.isNotEmpty) {
            senderAvatar = member.photoUrl;
            // Cache it for future use
            if (lookupUuid != null && lookupUuid.contains('-')) {
              _memberAvatarCache[lookupUuid] = senderAvatar;
              debugPrint(
                  '✅ [GroupChatScreen] Avatar found from _currentGroup.members and cached: $senderAvatar');
            } else {
              debugPrint(
                  '✅ [GroupChatScreen] Avatar found from _currentGroup.members: $senderAvatar');
            }
          }
        } catch (e) {
          // Member not found - this is normal for historical messages from removed users
          debugPrint(
              'ℹ️ [GroupChatScreen] Avatar not found in current room members for senderId=$senderId (normal for historical/removed users)');
        }
      }
    }

    // Cache avatar from RoomMessage if available using normalized caching
    if (roomMessage.senderAvatar != null &&
        roomMessage.senderAvatar!.isNotEmpty) {
      // Determine UUID for caching
      String? cacheUuid = senderId;

      // If senderId is numeric, try to find UUID
      if (!senderId.contains('-') && int.tryParse(senderId) != null) {
        final numericId = int.parse(senderId);
        cacheUuid = _numericIdToUuidMap[numericId];
      }

      // Use normalized caching for consistency across all message sources
      _cacheAvatarNormalized(
        uuid: cacheUuid?.contains('-') == true ? cacheUuid : null,
        numericId: roomMessage.snapshotUserId?.toString() ??
            (senderId.contains('-') ? null : senderId),
        avatarUrl: roomMessage.senderAvatar!,
        source: 'RoomMessage',
      );
    }

    // Determine if this is a system message based on message_type or event_type
    // System messages include: "user_left", "message_deleted", or message_type == "system" or "event"
    final isSystemMessage =
        roomMessage.messageType?.toLowerCase() == 'system' ||
            roomMessage.messageType?.toLowerCase() == 'event' ||
            roomMessage.eventType?.toLowerCase() == 'user_left' ||
            roomMessage.eventType?.toLowerCase() == 'message_deleted' ||
            (roomMessage.body.toLowerCase().contains('left the group') ||
                roomMessage.body.toLowerCase().contains('joined the group') ||
                roomMessage.body.toLowerCase().contains('was deleted'));

    // Sanitize senderName - if it's a UUID or "user_" prefixed UUID, try to get real name from RoomInfo
    String finalSenderName = roomMessage.senderName;
    if (_isUuidLike(finalSenderName)) {
      // Try to find the real username from RoomInfo members using senderId
      try {
        final member = _currentGroup.members.firstWhere(
          (m) => m.id == senderId || m.id == senderId.toString(),
          orElse: () => IntercomContact(
            id: '',
            name: '',
            type: IntercomContactType.resident,
          ),
        );
        if (member.name.isNotEmpty && !_isUuidLike(member.name)) {
          finalSenderName = member.name;
          debugPrint(
              '✅ [GroupChatScreen] Resolved UUID senderName to real name: $finalSenderName (from RoomInfo)');
        } else {
          finalSenderName = 'User';
          debugPrint(
              '⚠️ [GroupChatScreen] Could not resolve UUID senderName, using "User"');
        }
      } catch (e) {
        finalSenderName = 'User';
        debugPrint(
            '⚠️ [GroupChatScreen] Error resolving UUID senderName: $e, using "User"');
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

    log('🔍 [GroupChatScreen] Converting RoomMessage - messageType: ${roomMessage.messageType}, body length: ${roomMessage.body.length}');
    log('   Body preview: ${roomMessage.body.length > 100 ? roomMessage.body.substring(0, 100) : roomMessage.body}');

    if (roomMessage.messageType == 'image' ||
        roomMessage.messageType == 'file' ||
        roomMessage.messageType == 'voice' ||
        roomMessage.messageType == 'audio' ||
        roomMessage.messageType == 'video') {
      log('📎 [GroupChatScreen] Processing file message - messageType: ${roomMessage.messageType}');
      try {
        final bodyJson = jsonDecode(roomMessage.body) as Map<String, dynamic>?;
        log('   Parsed JSON successfully: ${bodyJson != null}');

        if (bodyJson != null) {
          log('   JSON keys: ${bodyJson.keys.toList()}');

          String? normalizeUrl(String? url, String label) {
            if (url == null || url.isEmpty) return null;
            final transformed = RoomService.transformLocalhostUrl(url);
            if (transformed != url) {
              log('🔄 [GroupChatScreen] Transformed $label from localhost: $url -> $transformed');
            }
            return transformed;
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

          switch (roomMessage.messageType) {
            case 'image':
              imageUrl = normalizeUrl(
                bodyJson['file_url']?.toString() ??
                    bodyJson['image_url']?.toString() ??
                    bodyJson['imageUrl']?.toString(),
                'imageUrl',
              );
              log('   Extracted imageUrl: ${imageUrl != null ? (imageUrl.length > 50 ? '${imageUrl.substring(0, 50)}...' : imageUrl) : "null"}');
              break;
            case 'file':
              documentUrl = bodyJson['file_url']?.toString();
              documentUrl ??= bodyJson['fileUrl']?.toString();
              documentUrl ??= bodyJson['documentUrl']?.toString();
              documentUrl ??= bodyJson['url']?.toString();
              documentName = bodyJson['file_name']?.toString();
              documentType = bodyJson['file_type']?.toString();
              documentUrl = normalizeUrl(documentUrl, 'documentUrl');

              // Helper to check if file is a video by extension
              bool _isVideoFile(String? url, String? fileName) {
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
              bool _isAudioFile(String? url, String? fileName) {
                if (url == null && fileName == null) return false;
                final checkString = (fileName ?? url ?? '').toLowerCase();
                return checkString.endsWith('.mp3') ||
                    checkString.endsWith('.m4a') ||
                    checkString.endsWith('.aac') ||
                    checkString.endsWith('.wav') ||
                    checkString.endsWith('.ogg') ||
                    checkString.endsWith('.flac');
              }

              final mimeTypeLocal = bodyJson['mime_type']?.toString();
              final isVideoByMime = mimeTypeLocal != null &&
                  mimeTypeLocal.toLowerCase().startsWith('video');
              final isVideoByExtension =
                  _isVideoFile(documentUrl, documentName);
              final isAudioByMime = mimeTypeLocal != null &&
                  mimeTypeLocal.toLowerCase().startsWith('audio');
              final isAudioByExtension =
                  _isAudioFile(documentUrl, documentName);

              if (isAudioByMime || isAudioByExtension) {
                audioUrl = bodyJson['file_url']?.toString() ??
                    bodyJson['fileUrl']?.toString() ??
                    bodyJson['audio_url']?.toString() ??
                    bodyJson['url']?.toString();
                audioDuration = extractDuration(bodyJson['duration_ms']);
                isDocument = false;
                isVideo = false;
                videoUrl = null;
                audioUrl = normalizeUrl(audioUrl, 'audioUrl');
              } else if (isVideoByMime || isVideoByExtension) {
                videoUrl = bodyJson['file_url']?.toString() ??
                    bodyJson['fileUrl']?.toString() ??
                    bodyJson['video_url']?.toString() ??
                    bodyJson['url']?.toString();
                isVideo = videoUrl != null && videoUrl.isNotEmpty;
                isDocument = false;
                audioUrl = null;
                videoUrl = normalizeUrl(videoUrl, 'videoUrl');
              } else {
                // Only set as document if it's not video or audio
                isDocument = documentUrl != null && documentUrl.isNotEmpty;
              }

              log('   Extracted documentUrl: ${documentUrl != null ? (documentUrl.length > 50 ? '${documentUrl.substring(0, 50)}...' : documentUrl) : "null"}');
              log('   Extracted documentName: $documentName');
              log('   Extracted documentType: $documentType');

              if ((documentUrl == null || documentUrl.isEmpty) &&
                  (bodyJson['document_url'] != null ||
                      bodyJson['url'] != null ||
                      bodyJson['documentUrl'] != null)) {
                final fallbackDocumentUrl =
                    bodyJson['document_url']?.toString() ??
                        bodyJson['url']?.toString() ??
                        bodyJson['documentUrl']?.toString();
                documentUrl =
                    normalizeUrl(fallbackDocumentUrl, 'documentUrl fallback');
                if (documentUrl != null &&
                    documentUrl.isNotEmpty &&
                    !isDocument) {
                  isDocument = true;
                }
                log('   Tried alternative fields, documentUrl: ${documentUrl != null ? "found" : "still null"}');
              }
              break;
            case 'voice':
            case 'audio':
              audioUrl = bodyJson['file_url']?.toString();
              audioUrl ??= bodyJson['fileUrl']?.toString();
              audioUrl ??= bodyJson['audio_url']?.toString();
              audioUrl ??= bodyJson['url']?.toString();
              audioDuration = extractDuration(bodyJson['duration_ms']);
              audioUrl = normalizeUrl(audioUrl, 'audioUrl');
              log('   Extracted audioUrl: ${audioUrl != null ? (audioUrl.length > 50 ? '${audioUrl.substring(0, 50)}...' : audioUrl) : "null"}');
              break;
            case 'video':
              videoUrl = bodyJson['file_url']?.toString() ??
                  bodyJson['fileUrl']?.toString() ??
                  bodyJson['video_url']?.toString() ??
                  bodyJson['url']?.toString();
              isVideo = videoUrl != null && videoUrl.isNotEmpty;
              videoUrl = normalizeUrl(videoUrl, 'videoUrl');
              log('   Extracted videoUrl: ${videoUrl != null ? (videoUrl.length > 50 ? '${videoUrl.substring(0, 50)}...' : videoUrl) : "null"}');
              isDocument = false;
              break;
            default:
              break;
          }
        } else {
          log('⚠️ [GroupChatScreen] bodyJson is null after parsing');
        }
      } catch (e, stackTrace) {
        log('❌ [GroupChatScreen] Failed to parse body as JSON for message ${roomMessage.id}: $e');
        log('   Stack trace: $stackTrace');
        log('   Body that failed to parse: ${roomMessage.body.length > 200 ? roomMessage.body.substring(0, 200) + "..." : roomMessage.body}');
        if (roomMessage.body.trim().startsWith('http://') ||
            roomMessage.body.trim().startsWith('https://')) {
          log('   Body appears to be a direct URL, using it as file_url');
          if (roomMessage.messageType == 'image') {
            imageUrl =
                RoomService.transformLocalhostUrl(roomMessage.body.trim());
          } else if (roomMessage.messageType == 'file') {
            documentUrl =
                RoomService.transformLocalhostUrl(roomMessage.body.trim());
            isDocument = true;
          } else if (roomMessage.messageType == 'voice' ||
              roomMessage.messageType == 'audio') {
            audioUrl =
                RoomService.transformLocalhostUrl(roomMessage.body.trim());
          }
        }
      }
    } else {
      log('ℹ️ [GroupChatScreen] Not a file message - messageType: ${roomMessage.messageType}');
    }

    log('✅ [GroupChatScreen] Final extracted URLs - imageUrl: ${imageUrl != null ? "present" : "null"}, documentUrl: ${documentUrl != null ? "present" : "null"}, audioUrl: ${audioUrl != null ? "present" : "null"}, videoUrl: ${videoUrl != null ? "present" : "null"}, isVideo: $isVideo');

    // Determine text to display - hide JSON if we have file URLs
    String displayText = roomMessage.isDeleted ? '' : roomMessage.body;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      displayText = '';
    } else if (documentUrl != null && documentUrl.isNotEmpty) {
      displayText = documentName ?? '📎 Document';
    } else if (audioUrl != null && audioUrl.isNotEmpty) {
      displayText = '🎤 Voice note';
    } else if ((roomMessage.messageType == 'voice' ||
            roomMessage.messageType == 'audio') &&
        (displayText.isEmpty || displayText.trim().isEmpty)) {
      displayText = '🎤 Voice note';
    } else if ((roomMessage.messageType == 'image' ||
            roomMessage.messageType == 'file' ||
            roomMessage.messageType == 'voice' ||
            roomMessage.messageType == 'audio') &&
        roomMessage.body.trim().startsWith('{') &&
        roomMessage.body.trim().endsWith('}')) {
      try {
        jsonDecode(roomMessage.body);
        displayText = '';
      } catch (_) {
        // Not JSON, keep original text
      }
    }

    senderAvatar = _normalizeAvatarUrl(senderAvatar);

    final groupMessage = GroupMessage(
      id: roomMessage.id,
      groupId: roomMessage.roomId,
      senderId: senderId,
      senderName: finalSenderName,
      senderPhotoUrl: senderAvatar, // Include avatar from message or cache
      text: displayText,
      timestamp: roomMessage.createdAt,
      editedAt: roomMessage.editedAt,
      isDeleted: roomMessage.isDeleted,
      status: status,
      snapshotUserId: snapshotUserId,
      reactions:
          roomMessage.reactions, // Reactions included in the API response
      isSystemMessage: isSystemMessage, // Mark system messages from API
      imageUrls: imageUrl != null && imageUrl.isNotEmpty ? [imageUrl] : null,
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
      isForwarded: _isForwardedRoomMessage(roomMessage),
    );

    // CRITICAL: Log the final message state to debug rendering issues
    log('📝 [GroupChatScreen] Created GroupMessage: id=${groupMessage.id}, imageUrls=${groupMessage.imageUrls != null ? "present (${groupMessage.imageUrls!.length} items)" : "null"}, documentUrl=${groupMessage.documentUrl != null ? "present (${groupMessage.documentUrl!.length} chars)" : "null"}, isDocument=${groupMessage.isDocument}');

    return groupMessage;
  }

  /// Get avatar URL for a given sender ID, trying multiple lookup strategies
  /// CRITICAL: Converts numeric IDs to UUIDs for consistent lookup
  /// PRIORITY: RoomInfo cache > Message avatar > _currentGroup.members
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
        debugPrint(
            '🔍 [GroupChatScreen] _getAvatarForSender: converted numeric $numericId to UUID $lookupUuid, found=${avatar != null}');
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
          debugPrint(
              '🔍 [GroupChatScreen] _getAvatarForSender: found avatar via reverse lookup (UUID -> numeric $numericId)');
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
            debugPrint(
                '🔍 [GroupChatScreen] _getAvatarForSender: found avatar via snapshotUserId -> UUID mapping');
          }
        }
      }
    }

    // For historical messages, don't check current room members as this will fail for removed users
    // The avatar cache should contain all necessary avatars from message loading or RoomInfo
    // If not found in cache, avatar resolution will fall back to initials (perfectly acceptable)

    if ((avatar == null || avatar.isEmpty) && isNumeric) {
      avatar = _normalizeAvatarUrl(normalizedSenderId);
    }

    return _normalizeAvatarUrl(avatar);
  }

  /// Ensure RoomInfo avatars are cached for all members
  /// This method ensures avatars from RoomInfo API are available in cache
  void _ensureRoomInfoAvatarsCached() {
    // Cache avatars from _currentGroup.members (populated from RoomInfo) using normalized caching
    for (final member in _currentGroup.members) {
      if (member.photoUrl != null &&
          member.photoUrl!.isNotEmpty &&
          member.id.isNotEmpty) {
        // Only cache if not already cached to avoid unnecessary operations
        final existingAvatar = _getAvatarNormalized(
            uuid: member.id.contains('-') ? member.id : null);
        if (existingAvatar == null || existingAvatar.isEmpty) {
          // Use normalized caching for consistency across all message sources
          _cacheAvatarNormalized(
            uuid: member.id.contains('-') ? member.id : null,
            numericId: member.id.contains('-') ? null : member.id,
            avatarUrl: member.photoUrl!,
            source: 'ensureRoomInfo',
          );
        }
      }
    }
  }

  /// Check if a RoomMessage is from the current user
  /// This handles different senderId formats (UUID vs numeric string)
  bool _isMessageFromCurrentUser(RoomMessage roomMessage) {
    // Priority 1: Check snapshot_user_id (most reliable)
    if (roomMessage.snapshotUserId != null &&
        widget.currentUserNumericId != null) {
      if (roomMessage.snapshotUserId == widget.currentUserNumericId) {
        return true;
      }
    }

    // Priority 2: Check if senderId matches currentUserId (UUID comparison)
    if (roomMessage.senderId == widget.currentUserId) {
      return true;
    }

    // Priority 3: Check if senderId is numeric and matches currentUserNumericId
    if (widget.currentUserNumericId != null) {
      final senderIdInt = int.tryParse(roomMessage.senderId);
      if (senderIdInt != null && senderIdInt == widget.currentUserNumericId) {
        return true;
      }
    }

    return false;
  }

  /// Send message via WebSocket
  ///
  /// Message is automatically persisted by backend
  /// Sender receives their own message via WebSocket (source of truth)
  /// Do NOT re-append from REST after sending
  Future<void> _sendMessage() async {
    // Don't send if user is not a member
    if (!_isUserMember) {
      EnhancedToast.error(
        context,
        title: 'Access Denied',
        message:
            'You are not a member of this room. You cannot send messages here.',
      );
      return;
    }

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
    final optimisticMessage = GroupMessage(
      id: tempMessageId,
      groupId: widget.group.id,
      senderId: widget.currentUserId,
      senderName: 'You',
      text: text,
      timestamp: DateTime.now(),
      status: GroupMessageStatus.sending,
      replyTo: replyTo,
      linkPreview: linkPreview,
      snapshotUserId: widget.currentUserNumericId,
    );

    setState(() {
      _messages.add(optimisticMessage);
    });

    _scrollToBottom();

    // Send via WebSocket
    // Get reply_to ID if replying to a message
    final replyToId = replyTo?.id;

    final sent = await _chatService.sendMessage(
      roomId: widget.group.id,
      content: text,
      messageType: 'text',
      replyTo: replyToId,
    );

    if (!sent) {
      // Failed to send - keep message with sending status so user can retry
      // The message will remain in "sending" status and can be retried
      if (mounted) {
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

  /// Update message status progression (sending -> sent -> delivered -> seen)
  void _updateMessageStatus(String messageId) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1 &&
          _messages[index].status == GroupMessageStatus.sending) {
        setState(() {
          _messages[index] = _messages[index].copyWith(
            status: GroupMessageStatus.sent,
          );
        });

        // Progress to delivered
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            final deliveredIndex =
                _messages.indexWhere((m) => m.id == messageId);
            if (deliveredIndex != -1) {
              setState(() {
                _messages[deliveredIndex] = _messages[deliveredIndex].copyWith(
                  status: GroupMessageStatus.delivered,
                );
              });

              // Progress to seen
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  final seenIndex =
                      _messages.indexWhere((m) => m.id == messageId);
                  if (seenIndex != -1) {
                    setState(() {
                      _messages[seenIndex] = _messages[seenIndex].copyWith(
                        status: GroupMessageStatus.seen,
                      );
                    });
                  }
                }
              });
            }
          }
        });
      }
    });
  }

  void _scrollToBottom() {
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

  void _toggleEmojiPanel() {
    final shouldShow = !_showEmojiPicker;
    setState(() {
      _showEmojiPicker = shouldShow;
    });
    if (shouldShow) {
      _messageFocusNode.unfocus();
      _scrollToBottom();
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

  @override
  @override
  void dispose() {
    _wsMessageSubscription?.cancel();
    _wsConnectionSubscription?.cancel();
    _messageSyncTimer?.cancel();
    _chatService.leaveRoom(widget.group.id);
    _waveformController.dispose();
    _typingTimer?.cancel();
    _typingIndicatorTimer?.cancel();
    _recordingTimer?.cancel();
    _audioStateSubscription?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    // Clear typing state on dispose (screen is closing)
    _isTyping = false;
    _typingUsers.clear();
    super.dispose();
  }

  PreferredSizeWidget _buildGroupSelectionAppBar() {
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

  @override
  Widget build(BuildContext context) {
    // Use _currentGroup for display properties (name, icon, members) which can be updated
    // Use widget.group.id for room operations (ID never changes)
    final displayGroup = _currentGroup;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final listBottomPadding =
        16.0 + bottomInset + (_showEmojiPicker ? _emojiPickerHeight : 0.0);

    return AppScaffold.internal(
      title: displayGroup.name,
      customAppBar: _isSelectionMode
          ? _buildGroupSelectionAppBar()
          : AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  if (_isSelectionMode) {
                    _clearSelection();
                    return;
                  }
                  Navigator.pop(context);
                },
              ),
              title: Row(
                children: [
                  GestureDetector(
                    onTap: (_updatedGroupIconUrl ?? displayGroup.iconUrl) !=
                                null &&
                            (_updatedGroupIconUrl ?? displayGroup.iconUrl)!
                                .isNotEmpty
                        ? () {
                            _showGroupImagePreview(
                              (_updatedGroupIconUrl ?? displayGroup.iconUrl)!,
                            );
                          }
                        : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: (_updatedGroupIconUrl ?? displayGroup.iconUrl) !=
                                  null &&
                              (_updatedGroupIconUrl ?? displayGroup.iconUrl)!
                                  .isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                (_updatedGroupIconUrl ?? displayGroup.iconUrl)!,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback to initials if image fails to load
                                  return Center(
                                    child: Text(
                                      displayGroup.initials,
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
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
                                      displayGroup.initials,
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Text(
                                displayGroup.initials,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayGroup.name,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isMuted) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.notifications_off,
                                size: 18,
                                color: Colors.orange.shade700,
                              ),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            // WebSocket connection status indicator
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isWebSocketConnected
                                    ? Colors.green
                                    : Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isWebSocketConnected ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: _isWebSocketConnected
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              displayGroup.memberCountDisplay,
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
                  onSelected: (value) {
                    if (value == 'clear') {
                      _showClearChatDialog();
                    } else if (value == 'customize') {
                      _showCustomizationOptions();
                    } else if (value == 'leave') {
                      _leaveGroup();
                    } else if (value == 'upload_image') {
                      _showUploadGroupImageDialog();
                    } else if (value == 'add_member') {
                      _showAddMemberDialog();
                    } else if (value == 'group_info') {
                      _showGroupInfo();
                    }
                  },
                  itemBuilder: (context) {
                    // Check if current user is admin (creator) of the group
                    final isAdmin = _isCurrentUserAdmin();

                    return [
                      const PopupMenuItem(
                        value: 'group_info',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Group Info'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'upload_image',
                        child: Row(
                          children: [
                            const Icon(Icons.image, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              (_updatedGroupIconUrl ?? _currentGroup.iconUrl) !=
                                          null &&
                                      (_updatedGroupIconUrl ??
                                              _currentGroup.iconUrl)!
                                          .isNotEmpty
                                  ? 'Change Group Image'
                                  : 'Upload Group Image',
                            ),
                          ],
                        ),
                      ),
                      // Only show "Add Member" option if current user is admin
                      if (isAdmin)
                        const PopupMenuItem(
                          value: 'add_member',
                          child: Row(
                            children: [
                              Icon(Icons.person_add, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Add Member'),
                            ],
                          ),
                        ),
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
                            Icon(Icons.palette, color: Colors.purple),
                            SizedBox(width: 8),
                            Text('Customize Chat'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.exit_to_app, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Leave Group'),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
      body: _isLoading
          ? const Center(
              child: AppLoader(
                title: 'Loading Chat',
                subtitle: 'Fetching group messages...',
                icon: Icons.chat_rounded,
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
                        color: Colors.orange.shade50,
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi_off,
                              size: 16,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Real-time messaging unavailable. Messages will sync when connection is restored.',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Chat messages
                    Expanded(
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (_) => _dismissEmojiAndKeyboard(),
                        child: Stack(
                          children: [
                            // Background image layer
                            Positioned.fill(
                              child: Container(
                                color: const Color(0xFFF0F2F5),
                                child: _chatWallpaperImage != null
                                    ? Opacity(
                                        opacity: 0.75,
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
                                        opacity: 0.75,
                                        child: Image.asset(
                                          'assets/images/oscar/oscar_chat.png',
                                          repeat: ImageRepeat.repeat,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            debugPrint(
                                                'Failed to load background image: $error');
                                            return Container(
                                                color: Colors.white);
                                          },
                                        ),
                                      ),
                              ),
                            ),
                            // Content layer
                            if (_hasError && _messages.isEmpty)
                              _buildErrorState()
                            else if (_messages.isEmpty)
                              _buildEmptyState()
                            else
                              RefreshIndicator(
                                onRefresh: () => _openRoom(isRefresh: true),
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: EdgeInsets.fromLTRB(
                                      16, 16, 16, listBottomPadding),
                                  itemCount: _messages.length +
                                      (_isTyping ? 1 : 0) +
                                      (_isLoadingMore ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index == 0 && _isLoadingMore) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    final messageIndex =
                                        _isLoadingMore ? index - 1 : index;

                                    if (messageIndex < 0 ||
                                        messageIndex >= _messages.length) {
                                      if (messageIndex == _messages.length &&
                                          _isTyping) {
                                        return _buildTypingIndicator();
                                      }
                                      debugPrint(
                                          '⚠️ [GroupChatScreen] Message index out of bounds: $messageIndex (messages.length: ${_messages.length})');
                                      return const SizedBox.shrink();
                                    }

                                    if (messageIndex == _messages.length &&
                                        _isTyping) {
                                      return _buildTypingIndicator();
                                    }

                                    final message = _messages[messageIndex];
                                    return _buildMessageBubble(message);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Reply preview bar
                    if (_replyingTo != null && !_hasLeftGroup && _isUserMember)
                      _buildReplyPreviewBar(),
                    // Message input or non-member message (only show input if user is a member)
                    if (_isUserMember && !_hasLeftGroup)
                      _buildMessageInputArea()
                    else if (!_isUserMember)
                      _buildNonMemberMessage(),
                  ],
                ),
                // Voice recording overlay
                if (_isRecording && _isPressingMic)
                  _buildVoiceRecordingOverlay(),
              ],
            ),
    );
  }

  // Build message bubble with all features
  Widget _buildMessageBubble(GroupMessage message) {
    final isDarkTheme = _chatTheme == ThemeMode.dark ||
        (_chatTheme == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final isCurrentUser = message.isFromUser(
      widget.currentUserId,
      currentUserNumericId: widget.currentUserNumericId,
    );
    final isSelected = _selectedMessageIds.contains(message.id);
    final selectionActive = _isSelectionMode;

    // System messages are displayed differently
    if (message.isSystemMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Check if we need to show date separator
    final messageIndex = _messages.indexOf(message);
    final showDateSeparator = messageIndex == 0 ||
        _messages[messageIndex - 1].timestamp.day != message.timestamp.day ||
        _messages[messageIndex - 1].timestamp.month !=
            message.timestamp.month ||
        _messages[messageIndex - 1].timestamp.year != message.timestamp.year;

    // Check if we need to show sender name
    final showSender = !isCurrentUser &&
        (messageIndex == 0 ||
            _messages[messageIndex - 1].senderId != message.senderId);

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
                : (isCurrentUser
                    ? DismissDirection.endToStart
                    : DismissDirection.startToEnd),
            confirmDismiss: (direction) async {
              if (selectionActive) return false;
              setState(() {
                _replyingTo = message;
              });
              EnhancedToast.info(
                context,
                title: 'Replying',
                message: 'Tap to send your reply',
              );
              return false;
            },
            background: Container(
              alignment:
                  isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
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
                mainAxisAlignment: isCurrentUser
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isCurrentUser) ...[
                    Builder(
                      builder: (context) {
                        // Try multiple lookup strategies to find avatar
                        String? avatarUrl = message.senderPhotoUrl;

                        if (avatarUrl == null || avatarUrl.isEmpty) {
                          // Use helper method for consistent multi-key lookup
                          avatarUrl = _getAvatarForSender(
                            message.senderId,
                            snapshotUserId: message.snapshotUserId,
                          );

                          // Debug logging for avatar lookup (reduced verbosity for normal cases)
                          if (avatarUrl == null || avatarUrl.isEmpty) {
                            // This is normal for historical messages from removed users - don't spam logs
                            debugPrint(
                                'ℹ️ [GroupChatScreen] Avatar not available for senderId=${message.senderId} (normal for historical/removed users)');
                          } else {
                            debugPrint(
                                '✅ [GroupChatScreen] Found avatar for ${message.senderId}: $avatarUrl');
                          }
                        } else {
                          debugPrint(
                              '✅ [GroupChatScreen] Using avatar from message.senderAvatar: $avatarUrl');
                        }

                        final hasAvatar =
                            avatarUrl != null && avatarUrl.isNotEmpty;

                        return CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          // Use cached avatar from RoomInfo API, WebSocket message, or Messages API
                          // Priority: message.senderAvatar > _memberAvatarCache > initials
                          backgroundImage:
                              hasAvatar ? NetworkImage(avatarUrl!) : null,
                          onBackgroundImageError: hasAvatar
                              ? (exception, stackTrace) {
                                  debugPrint(
                                      '⚠️ [GroupChatScreen] Failed to load avatar for ${message.senderId}: $exception');
                                  debugPrint('   Avatar URL: $avatarUrl');
                                }
                              : null,
                          child: !hasAvatar
                              ? Text(
                                  message.senderInitials,
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
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
                            color: isCurrentUser
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
                              // Sender name for group messages
                              if (showSender && !isCurrentUser)
                                Text(
                                  message.senderName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkTheme
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade700,
                                  ),
                                ),
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
                              // Image
                              if (message.imageFile != null ||
                                  message.firstImageUrl != null) ...[
                                Builder(
                                  builder: (context) {
                                    // Debug logging for image rendering
                                    if (message.firstImageUrl != null) {
                                      log('🖼️ [GroupChatScreen] Rendering image - firstImageUrl: ${message.firstImageUrl!.length > 50 ? message.firstImageUrl!.substring(0, 50) + "..." : message.firstImageUrl}');
                                    }
                                    return Stack(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            if (message.imageFile != null) {
                                              _previewImage(message.imageFile!);
                                            } else if (message.firstImageUrl !=
                                                null) {
                                              log('👆 [GroupChatScreen] Image tapped - previewing: ${message.firstImageUrl}');
                                              _previewImageUrl(
                                                  message.firstImageUrl!);
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
                                                      log('❌ [GroupChatScreen] Failed to load local image file: $error');
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
                                                    message.firstImageUrl!),
                                          ),
                                        ),
                                        // Download button overlay (like WhatsApp) - only show if not uploading
                                        if (message.firstImageUrl != null &&
                                            !_uploadingFiles
                                                .containsKey(message.id))
                                          Positioned(
                                            bottom: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _downloadImageFromUrl(
                                                      message.firstImageUrl!),
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
                              // Video
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
                                  isFromMe: message.isFromUser(
                                    widget.currentUserId,
                                    currentUserNumericId:
                                        widget.currentUserNumericId,
                                  ),
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
                                      if (message.videoFile != null) {
                                        _previewVideo(message.videoFile!);
                                      } else if (message.videoUrl != null &&
                                          message.videoUrl!.isNotEmpty) {
                                        _openVideoUrl(message.videoUrl!);
                                      }
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
                              // Audio (local file or remote URL)
                              if (message.isAudio &&
                                  (message.audioFile != null ||
                                      (message.audioUrl?.isNotEmpty ??
                                          false))) ...[
                                WhatsAppAudioMessage(
                                  audioFile: message.audioFile,
                                  audioUrl: message.audioUrl,
                                  duration: message.audioDuration,
                                  isFromMe: message.isFromUser(
                                    widget.currentUserId,
                                    currentUserNumericId:
                                        widget.currentUserNumericId,
                                  ),
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
                              // Document (only show if NOT a video)
                              if ((message.isDocument &&
                                      message.documentFile != null) ||
                                  (message.documentUrl != null &&
                                      !message.isVideo)) ...[
                                _buildDocumentPreview(message),
                                const SizedBox(height: 8),
                              ],
                              // Location
                              if (message.isLocation) ...[
                                _buildLocationPreview(message),
                                const SizedBox(height: 8),
                              ],
                              // Contact
                              if (message.isContact) ...[
                                _buildContactPreview(message),
                                const SizedBox(height: 8),
                              ],
                              // Message text (hide if we have file URLs to avoid showing JSON)
                              if (!message.isDeleted &&
                                  message.text.isNotEmpty &&
                                  message.firstImageUrl == null &&
                                  message.documentUrl == null)
                                message.text.isNotEmpty
                                    ? Text(
                                        message.text,
                                        style: TextStyle(
                                          color: isCurrentUser
                                              ? (isDarkTheme
                                                  ? Colors.white
                                                  : Colors.black)
                                              : (isDarkTheme
                                                  ? Colors.white
                                                  : Colors.black),
                                          fontSize: _fontSize,
                                        ),
                                      )
                                    : Text(
                                        '(Empty message)',
                                        style: TextStyle(
                                          color: isCurrentUser
                                              ? (isDarkTheme
                                                  ? Colors.white70
                                                  : Colors.black54)
                                              : (isDarkTheme
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600),
                                          fontSize: _fontSize,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                              if (message.isDeleted)
                                Text(
                                  'This message was deleted',
                                  style: TextStyle(
                                    color: isDarkTheme
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                    fontSize: _fontSize,
                                  ),
                                ),
                              // Edited indicator
                              if (message.editedAt != null &&
                                  !message.isDeleted)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
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
                                          fontSize: 10,
                                          color: isDarkTheme
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 4),
                              // Timestamp and status
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat('h:mm a')
                                        .format(_toIST(message.timestamp)),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isCurrentUser
                                          ? (isDarkTheme
                                              ? Colors.white70
                                              : Colors.black54)
                                          : (isDarkTheme
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600),
                                    ),
                                  ),
                                  if (isCurrentUser) ...[
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
                        ), // Container
                      ], // Stack children
                    ), // Stack
                  ), // Flexible
                ], // Row children
              ),
            ), // Padding
          ), // Dismissible
        ), // GestureDetector
      ],
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

  // Helper methods for message features
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

  Widget _buildMessageStatus(GroupMessageStatus status) {
    IconData icon;
    Color color;
    String? tooltip;

    switch (status) {
      case GroupMessageStatus.sending:
        icon = Icons.access_time;
        color = Colors.grey;
        tooltip = 'Sending...';
        break;
      case GroupMessageStatus.sent:
        icon = Icons.check;
        color = Colors.grey.shade700;
        tooltip = 'Sent';
        break;
      case GroupMessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey.shade700;
        tooltip = 'Delivered';
        break;
      case GroupMessageStatus.seen:
        // Message read by receiver - show blue double check icon (WhatsApp style)
        // Consistent with 1-to-1 chat styling
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

  Widget _buildReactions(GroupMessage message) {
    if (message.reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get unique reaction types with counts
    final reactionCounts = _getReactionCounts(message.reactions);
    final uniqueReactionTypes = reactionCounts.keys.toList();

    // Debug logging for cancel icon visibility
    if (widget.currentUserId.isNotEmpty) {
      for (final reactionType in uniqueReactionTypes) {
        final hasUserReacted = _hasUserReacted(message, reactionType);
        if (hasUserReacted) {
          log('🔍 [GroupChatScreen] User has reacted with $reactionType - cancel icon should show');
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

  Widget _buildReplyPreview(GroupMessage replyTo) {
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
                replyTo.isFromUser(widget.currentUserId)
                    ? 'You'
                    : replyTo.senderName,
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

  Widget _buildReplyReactions(GroupMessage message) {
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

  Widget _buildTypingIndicator() {
    // Show typing indicator only if OTHER users are typing (not current user)
    if (_typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get first typing user's info for avatar and name
    final firstTypingUserId = _typingUsers.keys.first;
    final firstTypingUserName = _typingUsers[firstTypingUserId] ?? 'User';

    // Get avatar for typing user
    String? typingUserAvatar = _getAvatarForSender(firstTypingUserId);
    final typingUserInitials = firstTypingUserName.isNotEmpty
        ? firstTypingUserName[0].toUpperCase()
        : 'U';

    // Get typing text: show member name if single user, or count if multiple
    final typingText = _typingUsers.length == 1
        ? '$firstTypingUserName is typing...'
        : '${_typingUsers.length} people are typing...';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            // Show typing member's avatar, not group avatar
            backgroundImage:
                typingUserAvatar != null && typingUserAvatar.isNotEmpty
                    ? NetworkImage(typingUserAvatar)
                    : null,
            onBackgroundImageError:
                typingUserAvatar != null && typingUserAvatar.isNotEmpty
                    ? (exception, stackTrace) {
                        debugPrint(
                            '⚠️ [GroupChatScreen] Failed to load typing user avatar: $exception');
                      }
                    : null,
            child: typingUserAvatar == null || typingUserAvatar.isEmpty
                ? Text(
                    typingUserInitials,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
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
                  typingText,
                  style: TextStyle(
                    color: Colors.grey.shade700,
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
        final value = ((_waveformController.value + delay) % 1.0);
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade600.withOpacity(0.3 + (value * 0.7)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  // Placeholder methods for attachments - will be implemented
  Widget _buildAudioPlayer(GroupMessage message) {
    final isPlaying = _isPlayingAudio && _playingAudioId == message.id;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () => _toggleAudioPlayback(message),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Voice Message',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (message.audioDuration != null)
                  Text(
                    _formatDuration(message.audioDuration!),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview(GroupMessage message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _getDocumentIcon(message.documentType ?? 'file'),
            color: _getDocumentColor(message.documentType ?? 'file'),
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.documentName ?? 'Document',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (message.documentFile != null)
                  Text(
                    _formatFileSize(message.documentFile!.lengthSync()),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  )
                else if (message.documentUrl != null)
                  Text(
                    'Tap to download',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              if (message.documentFile != null) {
                _downloadFile(
                  message.documentFile!,
                  message.documentName ?? 'document',
                );
              } else if (message.documentUrl != null) {
                _downloadDocumentFromUrl(
                  message.documentUrl!,
                  message.documentName ?? 'Document',
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPreview(GroupMessage message) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 48, color: AppColors.primary),
            SizedBox(height: 8),
            Text(
              'Location Shared',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactPreview(GroupMessage message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contact Shared',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getDocumentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getDocumentColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Message input area
  Widget _buildMessageInputArea() {
    return Builder(
      builder: (context) {
        final isDarkTheme = _chatTheme == ThemeMode.dark ||
            (_chatTheme == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness == Brightness.dark);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDarkTheme ? Colors.grey.shade900 : Colors.white,
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
                    icon: const Icon(Icons.attach_file, color: Colors.red),
                    onPressed: _showAttachmentOptions,
                  ),
                  IconButton(
                    icon: Icon(
                      _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                      color: _showEmojiPicker
                          ? AppColors.primary
                          : (isDarkTheme ? Colors.grey.shade300 : Colors.grey),
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
                        color: isDarkTheme ? Colors.white : Colors.black,
                        fontSize: _fontSize,
                      ),
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: _replyingTo != null
                            ? 'Reply to ${_replyingTo!.isFromUser(widget.currentUserId) ? "your message" : _replyingTo!.senderName}...'
                            : 'Type a message...',
                        hintStyle: TextStyle(
                          color: isDarkTheme
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDarkTheme
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_messageController.text.trim().isNotEmpty)
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
                        EnhancedToast.info(
                          context,
                          title: 'Voice Note',
                          message: 'Hold to record a voice message',
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _isPressingMic
                              ? AppColors.primary.withOpacity(0.8)
                              : AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: _isPressingMic
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.4),
                                    spreadRadius: 4,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
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
                  height: _emojiPickerHeight,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.grey.shade900 : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  child: _buildEmojiPicker(),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Build message widget to display when user is not a member
  Widget _buildNonMemberMessage() {
    final isDarkTheme = _chatTheme == ThemeMode.dark ||
        (_chatTheme == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isDarkTheme ? Colors.grey.shade900 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.grey.shade600,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You cannot send messages to this group because you are no longer a member.',
              style: TextStyle(
                color:
                    isDarkTheme ? Colors.grey.shade300 : Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreviewBar() {
    final isDarkTheme = _chatTheme == ThemeMode.dark ||
        (_chatTheme == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkTheme ? Colors.grey.shade900 : Colors.white,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _replyingTo!.isFromUser(widget.currentUserId)
                      ? 'You'
                      : _replyingTo!.senderName,
                  style: const TextStyle(
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
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                size: 20, color: isDarkTheme ? Colors.white : Colors.black),
            onPressed: () {
              setState(() {
                _replyingTo = null;
              });
            },
          ),
        ],
      ),
    );
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

  Widget _buildVoiceRecordingOverlay() {
    return Container(
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

  Future<void> _startVoiceRecording() async {
    // Prevent voice recording if user is not a member
    if (!_isUserMember) {
      EnhancedToast.error(
        context,
        title: 'Access Denied',
        message:
            'You cannot send messages to this group because you are no longer a member.',
      );
      return;
    }
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
      setState(() {
        _isRecording = false;
        _isPressingMic = false;
      });
    }
  }

  Future<void> _endVoiceRecording() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();

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

    _recordingTimer?.cancel();

    try {
      await _audioRecorder.stop();
      if (_recordingFile != null && await _recordingFile!.exists()) {
        await _recordingFile!.delete();
      }

      setState(() {
        _isPressingMic = false;
        _isRecording = false;
        _recordingFile = null;
        _recordingDuration = Duration.zero;
        _recordingStartTime = null;
      });
    } catch (e) {
      // Ignore errors on cancel
      setState(() {
        _isPressingMic = false;
        _isRecording = false;
        _recordingFile = null;
        _recordingDuration = Duration.zero;
        _recordingStartTime = null;
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
        final messageId = DateTime.now().millisecondsSinceEpoch.toString();
        final message = GroupMessage(
          id: messageId,
          groupId: widget.group.id,
          senderId: widget.currentUserId,
          senderName: 'You',
          text: '🎤 Voice message',
          timestamp: DateTime.now(),
          isAudio: true,
          audioFile: _recordingFile,
          audioDuration: duration,
          status: GroupMessageStatus.sending,
          snapshotUserId: widget.currentUserNumericId,
        );

        setState(() {
          _messages.add(message);
          _uploadingFiles[messageId] = true;
          _uploadProgress[messageId] = 0.0;
        });

        _messageController.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        try {
          log('📤 [GroupChatScreen] Uploading voice note to S3 for room: ${widget.group.id}');
          final uploadResponse = await _roomService.uploadFileToS3(
            roomId: widget.group.id,
            file: _recordingFile!,
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
            log('❌ [GroupChatScreen] Failed to upload voice note: ${uploadResponse.error}');
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
                  'Failed to upload voice note. Please try again.',
            );
            return;
          }

          var fileUrl = uploadResponse.data!['file_url'] as String?;
          final fileKey = uploadResponse.data!['file_key'] as String?;
          final mimeType = uploadResponse.data!['mime_type'] as String?;
          final size = uploadResponse.data!['size'] as int?;

          if (fileUrl == null || fileUrl.isEmpty) {
            log('❌ [GroupChatScreen] No file_url in upload response');
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
            log('🔄 [GroupChatScreen] Transformed audio fileUrl from localhost: $originalUrl -> $fileUrl');
          }

          final fileName = _recordingFile!.path.split('/').last;
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

          log('📤 [GroupChatScreen] Sending WebSocket voice message with file_url: $fileUrl');
          final sent = await _chatService.sendMessage(
            roomId: widget.group.id,
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
                status:
                    sent ? GroupMessageStatus.sent : GroupMessageStatus.sending,
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
          log('❌ [GroupChatScreen] Error uploading/sending voice note: $e');
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1 && mounted) {
            setState(() {
              _uploadingFiles[messageId] = false;
              _uploadProgress.remove(messageId);
            });
          }
          EnhancedToast.error(
            context,
            title: 'Error',
            message: 'Failed to send voice message: ${e.toString()}',
          );
        }
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
        _recordingFile = null;
      });
    }
  }

  void _previewImage(File imageFile) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: Image.file(imageFile),
        ),
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

  // Download progress tracking
  final Set<String> _videoDownloadInProgress = {};
  final Map<String, double> _videoDownloadProgress = {};

  void _previewVideo(File videoFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoFile: videoFile),
      ),
    );
  }

  Future<void> _openVideoUrl(String url) async {
    // Find the message with this video URL
    final message = _messages.firstWhere(
      (m) => m.videoUrl == url,
      orElse: () => _messages.first,
    );

    if (_videoDownloadInProgress.contains(message.id)) {
      return;
    }

    File? localFile = message.videoFile;
    if (localFile != null && await localFile.exists()) {
      _previewVideo(localFile);
      return;
    }

    // Download and play
    await _downloadVideoWithProgress(message, playAfterDownload: true);
  }

  Future<void> _downloadVideoWithProgress(GroupMessage message,
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
        'group_video_${message.id}',
        (progress) {
          if (mounted) {
            setState(() {
              _videoDownloadProgress[message.id] = progress;
            });
          }
        },
      );

      if (downloaded != null) {
        _updateGroupMessageWithVideo(message.id, downloaded);
        if (playAfterDownload) {
          _previewVideo(downloaded);
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

  void _updateGroupMessageWithVideo(String messageId, File file) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    setState(() {
      _messages[index] = _messages[index].copyWith(
        videoFile: file,
        isVideo: true,
      );
    });
  }

  void _toggleMessageSelection(GroupMessage message) {
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
    if (_selectedMessageIds.isEmpty && !_isSelectionMode) return;
    setState(() {
      _selectedMessageIds.clear();
      _isSelectionMode = false;
    });
  }

  List<GroupMessage> _getSelectedMessagesInOrder() {
    if (_selectedMessageIds.isEmpty) return <GroupMessage>[];
    return _messages.where((m) => _selectedMessageIds.contains(m.id)).toList();
  }

  Future<void> _maybeSendPendingForwardMessages() async {
    if (_forwardIntentHandled ||
        _forwardIntentInFlight ||
        _pendingForwardMessageIds == null ||
        _pendingForwardMessageIds!.isEmpty) {
      return;
    }
    if (_hasLeftGroup || !_isUserMember) {
      _forwardIntentHandled = true;
      _pendingForwardMessageIds = null;
      _pendingForwardPayloads = null;
      return;
    }

    _insertForwardPlaceholders();

    _forwardIntentInFlight = true;
    _forwardIntentHandled = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final isMember = await _chatService.ensureMembership(widget.group.id);
      if (!isMember) {
        throw Exception('You are not a member of this group');
      }

      int success = 0;
      final failures = <String>[];
      final List<RoomMessage> createdMessages = [];

      for (final id in _pendingForwardMessageIds!) {
        final response = await _chatService.forwardMessage(
          messageId: id,
          targetRoomIds: [widget.group.id],
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
          message:
              'Message${success > 1 ? 's' : ''} forwarded to ${widget.group.name}.',
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
        final roomMessage = createdMessages[i];
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          final groupMessage = _convertRoomMessageToGroupMessage(roomMessage)
              .copyWith(status: GroupMessageStatus.delivered);
          _messages[idx] = groupMessage;
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
            status: GroupMessageStatus.delivered,
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
    final List<GroupMessage> placeholders = [];

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
        GroupMessage(
          id: tempId,
          groupId: widget.group.id,
          senderId: widget.currentUserId,
          senderName: 'You',
          text: displayText,
          timestamp: now,
          isDeleted: false,
          status: GroupMessageStatus.sending,
          reactions: const [],
          replyTo: null,
          linkPreview: null,
          imageUrls: payload.imageUrl != null && payload.imageUrl!.isNotEmpty
              ? [payload.imageUrl!]
              : null,
          documentUrl: payload.documentUrl,
          isDocument: isDoc && !isVideo,
          documentName: payload.documentName,
          documentType: payload.documentType,
          isAudio: isAudio,
          audioUrl: payload.audioUrl,
          audioDuration: payload.audioDuration,
          isVideo: isVideo,
          videoUrl: payload.videoUrl,
          isSystemMessage: false,
          snapshotUserId: widget.currentUserNumericId,
          isForwarded: true,
        ),
      );
    }

    setState(() {
      _messages.addAll(placeholders);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _startForwardSelection(GroupMessage message) {
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

    final payloads = selectedMessages.map(_buildForwardPayload).toList();

    final companyId = await _apiService.getSelectedSocietyId();
    if (companyId == null) {
      EnhancedToast.warning(
        context,
        title: 'Society Required',
        message: 'Select a society before forwarding messages.',
      );
      return;
    }

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

  ForwardPayload _buildForwardPayload(GroupMessage m) {
    final isImage = m.firstImageUrl != null && m.firstImageUrl!.isNotEmpty;
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
      imageUrl: m.firstImageUrl,
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
    NavigationHelper.pushRoute(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(
          group: _convertRoomToGroupChat(room),
          currentUserId: widget.currentUserId,
          currentUserNumericId: widget.currentUserNumericId,
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
      Room targetRoom, List<GroupMessage> messages) async {
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

  /// Build network image with proper error handling and retry logic
  Widget _buildNetworkImage(String imageUrl) {
    // Normalize URL - transform localhost URLs to server URLs
    String normalizedUrl =
        RoomService.transformLocalhostUrl(imageUrl) ?? imageUrl;
    if (normalizedUrl != imageUrl) {
      log('🔄 [GroupChatScreen] Normalized image URL: $imageUrl -> $normalizedUrl');
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
        log('❌ [GroupChatScreen] Failed to load image: $url, error: $error');

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
      log('🔄 [GroupChatScreen] Normalized preview image URL: $imageUrl -> $normalizedUrl');
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
        log('❌ [GroupChatScreen] Failed to load preview image: $url, error: $error');
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
        log('⚠️ [GroupChatScreen] Attempting to download from localhost URL: $imageUrl');
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
      log('❌ [GroupChatScreen] Error downloading image from URL: $e');
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
        log('⚠️ [GroupChatScreen] Attempting to download from localhost URL: $documentUrl');
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
      log('❌ [GroupChatScreen] Error downloading document from URL: $e');
      EnhancedToast.error(
        context,
        title: 'Download Failed',
        message:
            'Failed to download document. Please check your connection and try again.',
      );
    }
  }

  StreamSubscription<audio.PlayerState>? _audioStateSubscription;

  Future<void> _toggleAudioPlayback(GroupMessage message) async {
    final hasLocalFile = message.audioFile != null;
    final hasRemoteUrl =
        message.audioUrl != null && message.audioUrl!.isNotEmpty;
    if (!hasLocalFile && !hasRemoteUrl) return;

    try {
      if (_playingAudioId == message.id && _isPlayingAudio) {
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
        if (hasLocalFile) {
          await _audioPlayer.setFilePath(message.audioFile!.path);
        } else if (hasRemoteUrl) {
          await _audioPlayer.setUrl(message.audioUrl!);
        }

        await _audioPlayer.play();
        setState(() {
          _playingAudioId = message.id;
          _isPlayingAudio = true;
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

  void _showMessageOptions(GroupMessage message) {
    // Check if message is from current user using both UUID and numeric ID
    final isCurrentUser = message.isFromUser(
      widget.currentUserId,
      currentUserNumericId: widget.currentUserNumericId,
    );

    // Debug logging
    log('🔍 [GroupChatScreen] _showMessageOptions:');
    log('   message.senderId: ${message.senderId}');
    log('   widget.currentUserId: ${widget.currentUserId}');
    log('   widget.currentUserNumericId: ${widget.currentUserNumericId}');
    log('   isCurrentUser: $isCurrentUser');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                  leading: const Icon(Icons.add_reaction, color: Colors.orange),
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
                if (isCurrentUser) ...[
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
                      Navigator.pop(context); // Close bottom sheet immediately
                      _deleteMessage(message); // Call API to delete
                    },
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showReactionPicker(GroupMessage message) {
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
      {'emoji': '😱', 'name': 'Screaming'},
      {'emoji': '😨', 'name': 'Fearful'},
      {'emoji': '😰', 'name': 'Anxious'},
      {'emoji': '😥', 'name': 'Sad Relieved'},
      {'emoji': '😓', 'name': 'Downcast Sweat'},
      // Angry reactions
      {'emoji': '😡', 'name': 'Angry'},
      {'emoji': '😠', 'name': 'Pouting'},
      {'emoji': '🤬', 'name': 'Swearing'},
      {'emoji': '😤', 'name': 'Huffing'},
      {'emoji': '💢', 'name': 'Anger Symbol'},
      // Other popular reactions
      {'emoji': '😮', 'name': 'Wow'},
      {'emoji': '😲', 'name': 'Astonished'},
      {'emoji': '🤯', 'name': 'Exploding Head'},
      {'emoji': '😳', 'name': 'Flushed'},
      {'emoji': '🥵', 'name': 'Hot'},
      {'emoji': '🥶', 'name': 'Cold'},
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
      builder: (context) => Container(
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
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
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
                                final updatedMessage = _messages[updatedIndex];

                                // Check again with loaded reactions
                                final hasUserReactedAny =
                                    _hasUserReactedAny(updatedMessage);
                                final userReaction =
                                    _getUserReaction(updatedMessage);

                                if (isAlreadyReacted && reactionType != null) {
                                  // User tapped their own reaction - remove it
                                  _removeReaction(updatedMessage, reactionType);
                                } else if (hasUserReactedAny &&
                                    userReaction != null) {
                                  // User has reacted with different type - UPDATE (PUT)
                                  log('🔄 [GroupChatScreen] User updating reaction from ${userReaction.reactionType} to $reactionType');
                                  _addReaction(updatedMessage, emoji);
                                } else {
                                  // User hasn't reacted - ADD (POST)
                                  log('➕ [GroupChatScreen] User adding new reaction: $reactionType');
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
      ),
    );
  }

  /// Map emoji to API reaction_type
  /// API now supports any emoji string
  String? _emojiToReactionType(String emoji) {
    // API now limits lifted - return the emoji directly
    return emoji;
  }

  /// Show who reacted to a message
  void _showWhoReacted(GroupMessage message) async {
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
                                                    debugPrint(
                                                        '⚠️ [GroupChatScreen] Failed to load avatar for ${reaction.userId}: $exception');
                                                    debugPrint(
                                                        '   Avatar URL: $avatarUrl');
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
  bool _hasUserReacted(GroupMessage message, String reactionType) {
    if (widget.currentUserId.isEmpty) return false;
    final normalizedCurrentUserId = widget.currentUserId.trim();
    return message.reactions.any(
      (r) =>
          r.userId.trim() == normalizedCurrentUserId &&
          r.reactionType == reactionType,
    );
  }

  /// Check if current user has reacted to this message (any reaction type)
  bool _hasUserReactedAny(GroupMessage message) {
    if (widget.currentUserId.isEmpty) return false;
    final normalizedCurrentUserId = widget.currentUserId.trim();
    return message.reactions
        .any((r) => r.userId.trim() == normalizedCurrentUserId);
  }

  /// Get current user's existing reaction for this message
  MessageReaction? _getUserReaction(GroupMessage message) {
    if (widget.currentUserId.isEmpty) return null;
    try {
      final normalizedCurrentUserId = widget.currentUserId.trim();
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
      List<GroupMessage> messages) async {
    if (messages.isEmpty) return;

    // Only fetch for recent messages (last 20) to avoid overwhelming API
    final messagesToFetch = messages.length > 20
        ? messages.sublist(messages.length - 20)
        : messages;

    log('🔄 [GroupChatScreen] Fetching reactions for ${messagesToFetch.length} messages on entry');

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
          log('⏸️ [GroupChatScreen] Reaction fetch on cooldown. ${remainingSeconds}s remaining. Stopping batch fetch.');
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

    log('✅ [GroupChatScreen] Completed reaction fetching for messages on entry');
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
      log('⏭️ [GroupChatScreen] Reaction fetch already in progress for message: $messageId');
      return;
    }

    // Check cooldown period (after 429 error)
    if (_reactionFetchCooldownUntil != null) {
      final now = DateTime.now();
      if (now.isBefore(_reactionFetchCooldownUntil!)) {
        final remainingSeconds =
            _reactionFetchCooldownUntil!.difference(now).inSeconds;
        log('⏸️ [GroupChatScreen] Reaction fetch on cooldown. ${remainingSeconds}s remaining');
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
        log('⏸️ [GroupChatScreen] Rate limiting reaction fetch. Waiting ${waitTime.inMilliseconds}ms');
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
        log('⚠️ [GroupChatScreen] Rate limit (429) on reaction fetch. Cooldown until: $_reactionFetchCooldownUntil');

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

          log('🔄 [GroupChatScreen] Updating reactions for message $messageId: ${updatedReactions.length} reactions');
          log('   Current user ID: ${widget.currentUserId}');
          for (final reaction in updatedReactions) {
            log('   Reaction: ${reaction.reactionType} by user ${reaction.userId} (${reaction.userName})');
            if (reaction.userId.trim() == widget.currentUserId.trim()) {
              log('   ✓ This is current user\'s reaction!');
            }
          }

          setState(() {
            // Create a new message instance with updated reactions
            _messages[msgIndex] = _messages[msgIndex].copyWith(
              reactions: updatedReactions,
            );
          });

          // Force a rebuild by checking the updated message
          final updatedMessage = _messages[msgIndex];
          log('✅ [GroupChatScreen] Reactions updated. Message now has ${updatedMessage.reactions.length} reactions');
          log('   User has reacted: ${_hasUserReactedAny(updatedMessage)}');
          if (_hasUserReactedAny(updatedMessage)) {
            final userReaction = _getUserReaction(updatedMessage);
            log('   User reaction type: ${userReaction?.reactionType}');
            // Log all reaction types the user has reacted with
            final userReactions = updatedReactions
                .where((r) => r.userId.trim() == widget.currentUserId.trim())
                .toList();
            log('   User has ${userReactions.length} reaction(s): ${userReactions.map((r) => r.reactionType).join(", ")}');
          }
        } else {
          log('⚠️ [GroupChatScreen] Message not found or not mounted: $messageId');
        }
        // Reset cooldown on success
        _reactionFetchCooldownUntil = null;
      }
    } catch (e) {
      log('❌ [GroupChatScreen] Exception loading reactions: $e');
      // Fail silently
    } finally {
      _reactionsFetchInProgress.remove(messageId);
    }
  }

  Future<void> _addReaction(GroupMessage message, String reaction) async {
    // Check if message is deleted
    if (message.isDeleted) {
      EnhancedToast.warning(
        context,
        title: 'Cannot React',
        message: 'Deleted messages cannot be reacted to.',
      );
      return;
    }

    // CRITICAL: Validate message ID is UUID format (not timestamp/numeric)
    // Reaction API requires UUID format message ID
    if (message.id.isEmpty ||
        (!message.id.contains('-') && int.tryParse(message.id) != null)) {
      log('⚠️ [GroupChatScreen] Invalid message ID format for reaction: ${message.id}');
      EnhancedToast.error(
        context,
        title: 'Invalid Message',
        message: 'Cannot react to this message. Invalid message ID format.',
      );
      return;
    }

    // Map emoji to reaction_type
    final reactionType = _emojiToReactionType(reaction);
    if (reactionType == null) {
      log('⚠️ [GroupChatScreen] Unsupported emoji for reaction: $reaction');
      EnhancedToast.warning(
        context,
        title: 'Unsupported Reaction',
        message: 'This reaction type is not supported.',
      );
      return;
    }

    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) {
      log('⚠️ [GroupChatScreen] Message not found: ${message.id}');
      return;
    }

    // Rate limiting: Check if already updating this message
    if (_reactionsUpdateInProgress.contains(message.id)) {
      log('⏭️ [GroupChatScreen] Reaction update already in progress for message: ${message.id}');
      return;
    }

    // Rate limiting: Check cooldown period
    if (_reactionUpdateCooldownUntil != null) {
      final now = DateTime.now();
      if (now.isBefore(_reactionUpdateCooldownUntil!)) {
        final remainingSeconds =
            _reactionUpdateCooldownUntil!.difference(now).inSeconds;
        log('⏸️ [GroupChatScreen] Reaction update on cooldown. ${remainingSeconds}s remaining');
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
        log('⏸️ [GroupChatScreen] Rate limiting reaction update. Waiting ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      }
    }

    // Decision logic: PUT if user already reacted, POST if new
    final hasUserReacted = _hasUserReactedAny(message);
    final existingReaction = _getUserReaction(message);

    log('🔍 [GroupChatScreen] Reaction decision logic:');
    log('   hasUserReacted: $hasUserReacted');
    log('   existingReaction: ${existingReaction?.reactionType ?? "none"}');
    log('   new reactionType: $reactionType');
    log('   message.reactions.length: ${message.reactions.length}');

    // If user already reacted with the same type, remove it (toggle behavior)
    if (existingReaction != null &&
        existingReaction.reactionType == reactionType) {
      log('🗑️ [GroupChatScreen] User toggling same reaction - removing');
      _removeReaction(message, reactionType);
      return;
    }

    // Optimistic UI update
    final currentReactions = List<MessageReaction>.from(message.reactions);
    MessageReaction? optimisticReaction;

    if (hasUserReacted && existingReaction != null) {
      optimisticReaction = MessageReaction(
        id: existingReaction.id,
        messageId: message.id,
        userId: widget.currentUserId,
        reactionType: reactionType,
        userName: existingReaction.userName,
      );
      currentReactions.removeWhere((r) => r.id == existingReaction!.id);
      currentReactions.add(optimisticReaction);
    } else {
      optimisticReaction = MessageReaction(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        messageId: message.id,
        userId: widget.currentUserId,
        reactionType: reactionType,
        userName: 'You',
      );
      currentReactions.add(optimisticReaction);
    }

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
        log('🔄 [GroupChatScreen] Calling PUT API to UPDATE reaction: ${existingReaction.reactionType} → $reactionType (message ${message.id})');
        response = await _roomService.updateReaction(
          messageId: message.id,
          reactionType: reactionType,
        );
      } else {
        // User hasn't reacted - ADD new reaction (POST API)
        log('➕ [GroupChatScreen] Calling POST API to ADD reaction: $reactionType → message ${message.id}');
        response = await _roomService.addReaction(
          messageId: message.id,
          reactionType: reactionType,
        );
      }

      if (response.statusCode == 429) {
        _reactionUpdateCooldownUntil =
            DateTime.now().add(_reactionUpdateCooldown);
        log('⚠️ [GroupChatScreen] Rate limit (429) on reaction update. Cooldown until: $_reactionUpdateCooldownUntil');

        setState(() {
          _messages[index] = _messages[index].copyWith(
            reactions: message.reactions,
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
        setState(() {
          _messages[index] = _messages[index].copyWith(
            reactions: message.reactions,
          );
        });

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
      } else {
        if (response.data != null) {
          final serverReaction = response.data!;
          final updatedReactions =
              List<MessageReaction>.from(message.reactions);

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

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            loadReactionsForMessage(message.id);
          }
        });
      }
    } catch (e) {
      setState(() {
        _messages[index] = _messages[index].copyWith(
          reactions: message.reactions,
        );
      });
      log('❌ [GroupChatScreen] Exception ${hasUserReacted ? 'updating' : 'adding'} reaction: $e');
    } finally {
      _reactionsUpdateInProgress.remove(message.id);
    }
  }

  Future<void> _removeReaction(
      GroupMessage message, String reactionType) async {
    // Check if message is deleted
    if (message.isDeleted) {
      EnhancedToast.warning(
        context,
        title: 'Cannot Remove Reaction',
        message: 'Deleted messages cannot have reactions removed.',
      );
      return;
    }

    // CRITICAL: Validate message ID is UUID format (not timestamp/numeric)
    // Reaction API requires UUID format message ID
    if (message.id.isEmpty ||
        (!message.id.contains('-') && int.tryParse(message.id) != null)) {
      log('⚠️ [GroupChatScreen] Invalid message ID format for remove reaction: ${message.id}');
      EnhancedToast.error(
        context,
        title: 'Invalid Message',
        message: 'Cannot remove reaction. Invalid message ID format.',
      );
      return;
    }

    // Find message by ID
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) {
      log('⚠️ [GroupChatScreen] Message not found: ${message.id}');
      return;
    }

    // Rate limiting: Check if already updating this message
    if (_reactionsUpdateInProgress.contains(message.id)) {
      log('⏭️ [GroupChatScreen] Reaction update already in progress for message: ${message.id}');
      return;
    }

    // Rate limiting: Check cooldown period
    if (_reactionUpdateCooldownUntil != null) {
      final now = DateTime.now();
      if (now.isBefore(_reactionUpdateCooldownUntil!)) {
        final remainingSeconds =
            _reactionUpdateCooldownUntil!.difference(now).inSeconds;
        log('⏸️ [GroupChatScreen] Reaction update on cooldown. ${remainingSeconds}s remaining');
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
        log('⏸️ [GroupChatScreen] Rate limiting reaction delete. Waiting ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      }
    }

    // Optimistic UI update
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
      log('🗑️ [GroupChatScreen] Deleting reaction for message: ${message.id}');
      final response = await _roomService.deleteReaction(messageId: message.id);

      if (response.statusCode == 429) {
        _reactionUpdateCooldownUntil =
            DateTime.now().add(_reactionUpdateCooldown);
        log('⚠️ [GroupChatScreen] Rate limit (429) on reaction delete. Cooldown until: $_reactionUpdateCooldownUntil');

        setState(() {
          _messages[index] = _messages[index].copyWith(
            reactions: message.reactions,
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
        setState(() {
          _messages[index] = _messages[index].copyWith(
            reactions: message.reactions,
          );
        });

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
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            loadReactionsForMessage(message.id);
          }
        });
      }
    } catch (e) {
      setState(() {
        _messages[index] = _messages[index].copyWith(
          reactions: message.reactions,
        );
      });
      log('❌ [GroupChatScreen] Exception deleting reaction: $e');
    } finally {
      _reactionsUpdateInProgress.remove(message.id);
    }
  }

  Future<void> _editMessage(GroupMessage message) async {
    // Check if message is from current user using snapshot_user_id (most reliable)
    final isCurrentUser = message.isFromUser(
      widget.currentUserId,
      currentUserNumericId: widget.currentUserNumericId,
    );

    if (!isCurrentUser) {
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
                                    log('📝 [GroupChatScreen] Editing message: ${message.id}');
                                    final response =
                                        await _roomService.editMessage(
                                      messageId: message.id,
                                      content: updatedText,
                                    );

                                    if (!mounted) return;

                                    if (response.success &&
                                        response.data != null) {
                                      log('✅ [GroupChatScreen] Message edited successfully');
                                      // Update message in-place
                                      final index = _messages.indexWhere(
                                        (m) => m.id == message.id,
                                      );
                                      if (index != -1) {
                                        final existingMessage =
                                            _messages[index];
                                        final updatedRoomMessage =
                                            response.data!;
                                        final updatedGroupMessage =
                                            _convertRoomMessageToGroupMessage(
                                          updatedRoomMessage,
                                          forceDeliveredStatus: true,
                                        );

                                        // Ensure senderId and snapshotUserId are preserved for current user messages
                                        // This ensures the edited message always shows on the right side
                                        final isFromCurrentUser =
                                            existingMessage.isFromUser(
                                          widget.currentUserId,
                                          currentUserNumericId:
                                              widget.currentUserNumericId,
                                        );

                                        final finalMessage = isFromCurrentUser
                                            ? GroupMessage(
                                                id: updatedGroupMessage.id,
                                                groupId:
                                                    updatedGroupMessage.groupId,
                                                senderId: widget
                                                    .currentUserId, // Preserve current user's UUID
                                                senderName: updatedGroupMessage
                                                    .senderName,
                                                senderPhotoUrl:
                                                    updatedGroupMessage
                                                        .senderPhotoUrl,
                                                text: updatedGroupMessage.text,
                                                timestamp: updatedGroupMessage
                                                    .timestamp,
                                                editedAt: updatedGroupMessage
                                                    .editedAt,
                                                isDeleted: updatedGroupMessage
                                                    .isDeleted,
                                                imageFile: updatedGroupMessage
                                                    .imageFile,
                                                isLocation: updatedGroupMessage
                                                    .isLocation,
                                                isDocument: updatedGroupMessage
                                                    .isDocument,
                                                documentName:
                                                    updatedGroupMessage
                                                        .documentName,
                                                documentType:
                                                    updatedGroupMessage
                                                        .documentType,
                                                documentFile:
                                                    updatedGroupMessage
                                                        .documentFile,
                                                isContact: updatedGroupMessage
                                                    .isContact,
                                                isAudio:
                                                    updatedGroupMessage.isAudio,
                                                audioFile: updatedGroupMessage
                                                    .audioFile,
                                                audioDuration:
                                                    updatedGroupMessage
                                                        .audioDuration,
                                                isVideo:
                                                    updatedGroupMessage.isVideo,
                                                videoFile: updatedGroupMessage
                                                    .videoFile,
                                                videoThumbnail:
                                                    updatedGroupMessage
                                                        .videoThumbnail,
                                                status: GroupMessageStatus
                                                    .delivered, // Show double tick for edited messages
                                                reactions: updatedGroupMessage
                                                    .reactions,
                                                replyTo:
                                                    updatedGroupMessage.replyTo,
                                                linkPreview: updatedGroupMessage
                                                    .linkPreview,
                                                imageUrls: updatedGroupMessage
                                                    .imageUrls,
                                                isRead:
                                                    updatedGroupMessage.isRead,
                                                isSystemMessage:
                                                    updatedGroupMessage
                                                        .isSystemMessage,
                                                snapshotUserId: widget
                                                    .currentUserNumericId, // Preserve current user's numeric ID
                                              )
                                            : updatedGroupMessage;

                                        setState(() {
                                          _messages[index] = finalMessage;
                                        });

                                        // Show success toast
                                        EnhancedToast.success(
                                          context,
                                          title: 'Message Edited',
                                          message:
                                              'Your message has been updated.',
                                        );
                                      }

                                      // Close dialog
                                      Navigator.pop(context);
                                    } else {
                                      // Show error but keep dialog open
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
                                    log('❌ [GroupChatScreen] Error editing message: $e');
                                    if (!mounted) return;

                                    // Show error but keep dialog open
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

  Future<void> _deleteMessage(GroupMessage message) async {
    // Check if message is from current user using snapshot_user_id (most reliable)
    final isCurrentUser = message.isFromUser(
      widget.currentUserId,
      currentUserNumericId: widget.currentUserNumericId,
    );

    if (!isCurrentUser) {
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
      log('🗑️ [GroupChatScreen] Deleting message: ${message.id}');
      final response = await _roomService.deleteMessage(
        messageId: message.id,
      );

      if (!mounted) return;

      if (response.success && response.data != null) {
        log('✅ [GroupChatScreen] Message deleted successfully');
        // Update message in-place (soft delete)
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          final deletedRoomMessage = response.data!;
          final deletedGroupMessage = _convertRoomMessageToGroupMessage(
            deletedRoomMessage,
          );

          setState(() {
            _messages[index] = deletedGroupMessage;
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
      log('❌ [GroupChatScreen] Error deleting message: $e');
      if (!mounted) return;

      // Show error but don't change message UI
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to delete message: $e',
      );
    }
  }

  void _showAttachmentOptions() {
    // Prevent attachments if user is not a member
    if (!_isUserMember) {
      EnhancedToast.error(
        context,
        title: 'Access Denied',
        message:
            'You cannot send messages to this group because you are no longer a member.',
      );
      return;
    }
    final isDarkTheme = _chatTheme == ThemeMode.dark ||
        (_chatTheme == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        final sheetColor = isDarkTheme ? Colors.grey.shade900 : Colors.white;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return AnimatedPadding(
          padding: EdgeInsets.only(bottom: bottomInset),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2),
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
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildAttachmentOption(
                              Icons.photo_library,
                              'Gallery',
                              () => _pickMultipleMedia(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAttachmentOption(
                              Icons.camera_alt,
                              'Camera',
                              () => _pickImage(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAttachmentOption(
                              Icons.insert_drive_file,
                              'Document',
                              _pickDocument,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildAttachmentOption(
                              Icons.videocam,
                              'Video',
                              _pickVideo,
                            ),
                          ),
                          const Spacer(),
                          const Spacer(),
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        // Show preview before sending
        final previewResult =
            await _showMediaPreview(pickedFile, isVideo: false);
        if (previewResult == true) {
          final file = File(pickedFile.path);
          // Compress image before sending
          final compressedFile = await _compressImage(file);
          if (compressedFile != null) {
            await _sendImageMessageWithProgress(compressedFile);
          } else {
            await _sendImageMessageWithProgress(file);
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

  Future<void> _sendImageMessageWithProgress(File imageFile) async {
    final roomId = widget.group.id;
    if (roomId == null || roomId.isEmpty) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Room ID not available. Please try again.',
      );
      return;
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = GroupMessage(
      id: messageId,
      groupId: roomId,
      senderId: widget.currentUserId,
      senderName: 'You',
      text: '',
      timestamp: DateTime.now(),
      imageFile: imageFile,
      status: GroupMessageStatus.sending,
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
      log('📤 [GroupChatScreen] Uploading image to S3 for room: $roomId');
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
        log('❌ [GroupChatScreen] Failed to upload image to S3: ${uploadResponse.error}');
        // Update message to show error
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

      final fileUrl = uploadResponse.data!['file_url'] as String?;
      final fileKey = uploadResponse.data!['file_key'] as String?;
      final mimeType = uploadResponse.data!['mime_type'] as String?;
      final size = uploadResponse.data!['size'] as int?;

      if (fileUrl == null || fileUrl.isEmpty) {
        log('❌ [GroupChatScreen] No file_url in upload response');
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

      log('✅ [GroupChatScreen] Image uploaded to S3: $fileUrl');

      // Step 2: Send message via WebSocket with file_url
      // Build content as JSON string with file metadata
      final contentMap = {
        'file_url': fileUrl,
        if (fileKey != null) 'file_key': fileKey,
        if (mimeType != null) 'mime_type': mimeType,
        if (size != null) 'size': size,
      };
      final content = jsonEncode(contentMap);

      log('📤 [GroupChatScreen] Sending WebSocket message with file_url: $fileUrl');
      final sent = await _chatService.sendMessage(
        roomId: roomId,
        content: content,
        messageType: 'image',
        replyTo: _replyingTo?.id,
      );

      if (!mounted) return;

      if (sent) {
        log('✅ [GroupChatScreen] WebSocket message sent successfully');
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
              status: GroupMessageStatus
                  .sending, // Keep as sending for duplicate detection
              imageUrls: [fileUrl], // Store S3 URL so image renders immediately
              text:
                  '', // Clear text to hide JSON - image will be rendered instead
            );
          });
        }
      } else {
        log('❌ [GroupChatScreen] Failed to send WebSocket message');
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
      log('❌ [GroupChatScreen] Error uploading/sending image: $e');
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

  Future<void> _pickDocument() async {
    try {
      // Pick file using file_picker
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

        await _sendDocumentMessageWithProgress(file, fileName, fileType);
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Failed to pick document: ${e.toString()}',
      );
    }
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

  Future<void> _sendVideoMessageWithProgress(File videoFile) async {
    final roomId = widget.group.id;
    if (roomId.isEmpty) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Room ID not available. Please try again.',
      );
      return;
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = GroupMessage(
      id: messageId,
      groupId: roomId,
      senderId: widget.currentUserId,
      senderName: 'You',
      text: '🎥 Video',
      timestamp: DateTime.now(),
      isVideo: true,
      videoFile: videoFile,
      status: GroupMessageStatus.sending,
      replyTo: _replyingTo,
      snapshotUserId: widget.currentUserNumericId,
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
      log('📤 [GroupChatScreen] Uploading video to S3 for room: $roomId');
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
        log('❌ [GroupChatScreen] Failed to upload video: ${uploadResponse.error}');
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
        log('❌ [GroupChatScreen] No file_url in upload response');
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
        log('🔄 [GroupChatScreen] Transformed video fileUrl from localhost: $originalUrl -> $fileUrl');
      }

      final fileName = videoFile.path.split('/').last;
      final contentMap = {
        'file_url': fileUrl,
        if (fileKey != null) 'file_key': fileKey,
        if (mimeType != null) 'mime_type': mimeType,
        if (mimeType != null) 'file_type': mimeType,
        if (size != null) 'size': size,
        'file_name': fileName,
      };
      final content = jsonEncode(contentMap);

      log('📤 [GroupChatScreen] Sending WebSocket video message with file_url: $fileUrl');
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
            status: sent ? GroupMessageStatus.sent : GroupMessageStatus.sending,
            videoUrl: fileUrl,
            isVideo: true,
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
      log('❌ [GroupChatScreen] Error uploading/sending video: $e');
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1 && mounted) {
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

  Future<void> _sendDocumentMessageWithProgress(
      File file, String fileName, String fileType) async {
    final roomId = widget.group.id;
    if (roomId == null || roomId.isEmpty) {
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Room ID not available. Please try again.',
      );
      return;
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = GroupMessage(
      id: messageId,
      groupId: roomId,
      senderId: widget.currentUserId,
      senderName: 'You',
      text: '📎 $fileName',
      timestamp: DateTime.now(),
      isDocument: true,
      documentFile: file,
      documentName: fileName,
      documentType: fileType,
      status: GroupMessageStatus.sending,
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
      log('📤 [GroupChatScreen] Uploading document to S3 for room: $roomId');
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
        log('❌ [GroupChatScreen] Failed to upload document to S3: ${uploadResponse.error}');
        // Update message to show error
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

      final fileUrl = uploadResponse.data!['file_url'] as String?;
      final fileKey = uploadResponse.data!['file_key'] as String?;
      final mimeType = uploadResponse.data!['mime_type'] as String?;
      final size = uploadResponse.data!['size'] as int?;

      if (fileUrl == null || fileUrl.isEmpty) {
        log('❌ [GroupChatScreen] No file_url in upload response');
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

      log('✅ [GroupChatScreen] Document uploaded to S3: $fileUrl');

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

      log('📤 [GroupChatScreen] Sending WebSocket message with file_url: $fileUrl');
      final sent = await _chatService.sendMessage(
        roomId: roomId,
        content: content,
        messageType: 'file',
        replyTo: _replyingTo?.id,
      );

      if (!mounted) return;

      if (sent) {
        log('✅ [GroupChatScreen] WebSocket message sent successfully');
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
              status: GroupMessageStatus
                  .sending, // Keep as sending for duplicate detection
              documentUrl:
                  fileUrl, // Store S3 URL so document renders immediately
              text: '📎 ${fileName}', // Show file name instead of JSON
            );
          });
        }
      } else {
        log('❌ [GroupChatScreen] Failed to send WebSocket message');
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
      log('❌ [GroupChatScreen] Error uploading/sending document: $e');
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

  Future<void> _shareLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final message = GroupMessage(
        groupId: widget.group.id,
        senderId: widget.currentUserId,
        senderName: 'You',
        text: 'Location: ${position.latitude}, ${position.longitude}',
        timestamp: DateTime.now(),
        isLocation: true,
      );
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    } catch (e) {
      EnhancedToast.error(context,
          title: 'Error', message: 'Failed to get location');
    }
  }

  Future<void> _shareContact() async {
    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        final message = GroupMessage(
          groupId: widget.group.id,
          senderId: widget.currentUserId,
          senderName: 'You',
          text:
              '${contact.displayName} - ${contact.phones.isNotEmpty ? contact.phones.first.number : "No phone"}',
          timestamp: DateTime.now(),
          isContact: true,
        );
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
      }
    } catch (e) {
      EnhancedToast.error(context,
          title: 'Error', message: 'Failed to pick contact');
    }
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final message = GroupMessage(
        groupId: widget.group.id,
        senderId: widget.currentUserId,
        senderName: 'You',
        text: 'Audio file',
        timestamp: DateTime.now(),
        isAudio: true,
        audioFile: file,
        audioDuration: const Duration(seconds: 30), // Placeholder
      );
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
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
                Icons.chat_bubble_outline,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No messages yet',
              style: TextStyle(
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

  /// Build error state UI with retry option
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Unable to load messages',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
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
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
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
                'Are you sure you want to clear all messages from this group chat? This action cannot be undone.',
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

      // Call API to clear chat
      log('Clearing chat for room: ${widget.group.id}');
      final response = await _chatService.clearChat(
        roomId: widget.group.id,
        companyId: companyId,
      );

      if (!mounted) return;

      if (response.success) {
        // Clear messages locally after successful API call
        setState(() {
          _messages.clear();
        });

        log('Chat cleared for room: ${widget.group.id}');

        // Mark group as updated so GroupsTab refreshes when user returns
        // This ensures the groups list shows the latest data (e.g., last message cleared)
        GroupsTab.markGroupUpdated();

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
                // Theme Settings option hidden
                // ListTile(
                //   leading: const Icon(Icons.dark_mode, color: Colors.blue),
                //   title: const Text('Theme Settings'),
                //   onTap: () {
                //     Navigator.pop(context);
                //     _showThemeOptions();
                //   },
                // ),
                // Font Size option hidden
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
      // Blue, Green, and Purple options hidden
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
                              width:
                                  1, // Thin border for both selected and unselected
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
  /// Uses group.id to store wallpaper per group
  Future<void> _saveWallpaperToStorage(String wallpaperPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'group_chat_wallpaper_${widget.group.id}';
      await prefs.setString(key, wallpaperPath);
      debugPrint(
          '✅ [GroupChatScreen] Wallpaper saved to SharedPreferences: $key -> $wallpaperPath');
    } catch (e) {
      debugPrint(
          '❌ [GroupChatScreen] Error saving wallpaper to SharedPreferences: $e');
    }
  }

  /// Load saved wallpaper from SharedPreferences
  /// Uses group.id to load wallpaper for the specific group
  Future<void> _loadSavedWallpaper() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'group_chat_wallpaper_${widget.group.id}';
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
            debugPrint(
                '✅ [GroupChatScreen] Wallpaper loaded from SharedPreferences: $wallpaperPath');
          }
        } else {
          // File doesn't exist, remove from preferences
          await prefs.remove(key);
          debugPrint(
              '⚠️ [GroupChatScreen] Wallpaper file not found, removed from preferences: $wallpaperPath');
        }
      }
    } catch (e) {
      debugPrint(
          '❌ [GroupChatScreen] Error loading wallpaper from SharedPreferences: $e');
    }
  }

  /// Clear saved wallpaper from SharedPreferences
  Future<void> _clearWallpaperFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'group_chat_wallpaper_${widget.group.id}';
      await prefs.remove(key);
      debugPrint(
          '✅ [GroupChatScreen] Wallpaper cleared from SharedPreferences: $key');
    } catch (e) {
      debugPrint(
          '❌ [GroupChatScreen] Error clearing wallpaper from SharedPreferences: $e');
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

  /// Show full-screen preview of group image
  void _showGroupImagePreview(String imageUrl) {
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
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show group info by fetching room info from API
  /// MEMBER ACCURACY PRIORITY: Always fetches fresh data to ensure member list is current
  /// No caching for member data - prevents showing users who have left the group
  /// Same functionality and UI as groups tab
  void _showGroupInfo() async {
    // DEBOUNCE: Prevent rapid taps on Group Info
    final now = DateTime.now();
    if (_lastGroupInfoTapTime != null &&
        now.difference(_lastGroupInfoTapTime!) < _groupInfoTapDebounce) {
      debugPrint('⚡ [GroupChatScreen] Group Info tap debounced');
      return;
    }
    _lastGroupInfoTapTime = now;

    try {
      // Get company_id for API call
      final companyId = await _apiService.getSelectedSocietyId();
      if (companyId == null) {
        EnhancedToast.error(
          context,
          title: 'Error',
          message: 'Please select a society first',
        );
        return;
      }

      // FORCE FRESH DATA: Skip cache for member accuracy - always fetch latest from API
      // This ensures group info shows current members (no stale data for left members)
      debugPrint(
          '🔄 [GroupChatScreen] Forcing fresh API call for Group Info (member accuracy priority)');

      // No cache, no in-flight - show UI immediately with basic data, fetch in background
      debugPrint(
          '📡 [GroupChatScreen] No cached RoomInfo - showing UI immediately, fetching in background');

      // Show UI immediately with basic group data (from widget.group)
      // Show loader only in Members section while fetching
      _showGroupInfoContentWithBasicData(isLoadingMembers: true);

      // Fetch RoomInfo in background and update UI
      _fetchAndShowGroupInfo(widget.group.id, companyId);
    } catch (e) {
      debugPrint('❌ [GroupChatScreen] Error showing group info: $e');
      EnhancedToast.error(
        context,
        title: 'Error',
        message: 'Group information unavailable',
      );
    }
  }

  /// Show group info with basic data immediately (non-blocking)
  /// [isLoadingMembers] - if true, shows loader only in Members section
  ///
  /// CRITICAL: Do NOT use widget.group.members as it may contain inactive/removed members.
  /// Backend /rooms/{id}/info now returns only active members, so we must wait for API response.
  /// This fallback shows empty members list to prevent stale data from appearing.
  void _showGroupInfoContentWithBasicData({bool isLoadingMembers = false}) {
    // Create a minimal RoomInfo from widget.group for immediate rendering
    // CRITICAL FIX: Use empty members list - do NOT use widget.group.members
    // which may contain inactive/removed members. Backend API is authoritative.
    final basicRoomInfo = RoomInfo(
      id: widget.group.id,
      name: widget.group.name,
      description: widget.group.description,
      createdAt: widget.group.createdAt ?? DateTime.now(),
      lastActive: widget.group.lastMessageTime,
      // Use memberCount from widget.group if available, otherwise 0 (will be updated by API)
      memberCount: widget.group.memberCount ?? 0,
      createdBy: widget.group.creatorId ?? '',
      // CRITICAL: Empty members list - API response is authoritative for active members
      // This prevents stale/inactive members from appearing in Group Info
      members: <RoomInfoMember>[],
      admin: null,
    );

    _showGroupInfoContent(basicRoomInfo, isLoadingMembers: isLoadingMembers);
  }

  /// Fetch RoomInfo and show content (background, non-blocking)
  Future<void> _fetchAndShowGroupInfo(String roomId, int companyId) async {
    final roomInfoCache = RoomInfoCache();

    try {
      // Mark request as in-flight
      final future = _roomService
          .getRoomInfo(
        roomId: roomId,
        companyId: companyId,
      )
          .then((response) {
        if (response.success && response.data != null) {
          return response.data!;
        }
        return null;
      });

      roomInfoCache.trackInFlightRequest(roomId, future);

      final roomInfo = await future;

      if (!mounted || roomInfo == null) return;

      // Process and cache RoomInfo (off UI thread)
      _processAndCacheRoomInfo(roomInfo, companyId);

      // Update UI with fresh data (close existing page first if open, then show new)
      if (mounted) {
        if (_isGroupInfoPageOpen) {
          Navigator.pop(context); // Close existing group info page if open
          _isGroupInfoPageOpen = false; // Reset flag before reopening
        }
        _showGroupInfoContent(
            roomInfo); // Show with full data (isLoadingMembers = false by default)
      }
    } catch (e) {
      debugPrint(
          '⚠️ [GroupChatScreen] Error fetching RoomInfo for Group Info: $e');
      // UI already shown with basic data, so no error toast needed
    }
  }

  /// Process and cache RoomInfo (off UI thread, non-blocking)
  void _processAndCacheRoomInfo(RoomInfo roomInfo, int companyId) {
    // Run heavy processing in background
    Future.microtask(() {
      final roomInfoCache = RoomInfoCache();
      final avatarCache = <String, String>{};
      final numericIdToUuidMap = <int, String>{};

      // Process members (off UI thread)
      for (final member in roomInfo.members) {
        if (member.avatar != null && member.avatar!.isNotEmpty) {
          _cacheAvatarNormalized(
            uuid: member.userId,
            numericId: member.numericUserId?.toString(),
            avatarUrl: member.avatar!,
            source: 'roomInfoProcess',
          );
          avatarCache[member.userId] =
              _normalizeAvatarUrl(member.avatar) ?? member.avatar!;
          if (member.numericUserId != null) {
            final numericIdStr = member.numericUserId!.toString();
            avatarCache[numericIdStr] =
                _normalizeAvatarUrl(member.avatar) ?? member.avatar!;
          }
        }

        if (member.numericUserId != null) {
          _numericIdToUuidMap[member.numericUserId!] = member.userId;
          numericIdToUuidMap[member.numericUserId!] = member.userId;
        }
      }

      // Cache RoomInfo globally
      roomInfoCache.cacheRoomInfo(
        roomId: widget.group.id,
        companyId: companyId,
        roomInfo: roomInfo,
        avatarCache: avatarCache,
        numericIdToUuidMap: numericIdToUuidMap,
      );
    });
  }

  /// Push latest room info into the live notifiers and trigger rebuild if page is open
  void _updateGroupInfoNotifiers(RoomInfo roomInfo) {
    if (!_isGroupInfoPageOpen) return;

    _groupInfoMembersNotifier ??=
        ValueNotifier<List<RoomInfoMember>>(roomInfo.members);
    _groupInfoMemberCountNotifier ??=
        ValueNotifier<int>(roomInfo.memberCount ?? roomInfo.members.length);

    _groupInfoMembersNotifier!.value =
        List<RoomInfoMember>.from(roomInfo.members);
    _groupInfoMemberCountNotifier!.value =
        roomInfo.memberCount ?? roomInfo.members.length;

    // Ensure the scaffold rebuilds so any widgets outside the ValueListenableBuilder
    // (e.g., icons/menus that depend on count) also update.
    if (mounted) {
      setState(() {});
    }

    debugPrint(
        '⚡ [GroupChatScreen] Group Info notifiers refreshed with latest members (${roomInfo.memberCount ?? roomInfo.members.length})');
  }

  /// Refresh group info in background (non-blocking)
  /// Updates cache with fresh data - next time group info is opened, it will use fresh data
  Future<void> _refreshGroupInfoInBackground(
      String roomId, int companyId) async {
    try {
      final response = await _roomService.getRoomInfo(
        roomId: roomId,
        companyId: companyId,
      );

      if (response.success && response.data != null && mounted) {
        final roomInfo = response.data!;
        _processAndCacheRoomInfo(roomInfo, companyId);

        // Update cached data - will be used when group info page is opened next time
        // CRITICAL: Cache is updated with fresh data, so next open will show correct members
        debugPrint(
            '🔄 [GroupChatScreen] RoomInfo refreshed in background - cached data updated with ${roomInfo.memberCount} members');
      }
    } catch (e) {
      debugPrint('⚠️ [GroupChatScreen] Error refreshing Group Info: $e');
      // Silent fail - cached data is already shown
    }
  }

  /// Show group info content with room info from API
  /// Same UI as groups tab - NOW AS FULL PAGE INSTEAD OF BOTTOM SHEET
  /// [isLoadingMembers] - if true, shows loader only in Members section
  void _showGroupInfoContent(RoomInfo roomInfo,
      {bool isLoadingMembers = false}) {
    // Leave Group button is hidden per requirements
    final showLeave = false;

    debugPrint('📱 [GroupChatScreen] Opening Group Info as full page');

    // Initialize live notifiers so UI can update immediately on member changes
    final safeMembers = roomInfo.members;
    final safeMemberCount = roomInfo.memberCount;

    _groupInfoMembersNotifier ??=
        ValueNotifier<List<RoomInfoMember>>(safeMembers);
    _groupInfoMemberCountNotifier ??= ValueNotifier<int>(safeMemberCount);

    // Refresh values even if notifiers already exist
    _groupInfoMembersNotifier?.value = safeMembers;
    _groupInfoMemberCountNotifier?.value = safeMemberCount;

    // Mark that group info page is open
    _isGroupInfoPageOpen = true;

    // Navigate to full page instead of bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () {
                _isGroupInfoPageOpen = false; // Mark as closed
                Navigator.pop(context);
              },
            ),
            title: const Text(
              'Group Info',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        child: (_updatedGroupIconUrl ?? widget.group.iconUrl) !=
                                    null &&
                                (_updatedGroupIconUrl ?? widget.group.iconUrl)!
                                    .isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: Image.network(
                                  (_updatedGroupIconUrl ??
                                      widget.group.iconUrl)!,
                                  key: ValueKey(
                                      '${widget.group.id}_${_updatedGroupIconUrl ?? widget.group.iconUrl}'),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  cacheWidth: 120,
                                  cacheHeight: 120,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        widget.group.initials,
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
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: Text(
                                        widget.group.initials,
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
                                  widget.group.initials,
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
                                if (_groupInfoMemberCountNotifier != null)
                                  ValueListenableBuilder<int>(
                                    valueListenable:
                                        _groupInfoMemberCountNotifier!,
                                    builder: (context, count, _) {
                                      return Text(
                                        '$count ${count == 1 ? 'member' : 'members'}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      );
                                    },
                                  )
                                else
                                  Text(
                                    '${roomInfo.memberCount ?? roomInfo.members.length} ${((roomInfo.memberCount ?? roomInfo.members.length) == 1) ? 'member' : 'members'}',
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

                _buildGroupInfoDivider(),

                // Group Description
                if (roomInfo.description != null &&
                    roomInfo.description!.isNotEmpty) ...[
                  _buildGroupInfoSection(
                    title: 'Description',
                    icon: Icons.info_outline,
                    content: roomInfo.description!,
                  ),
                  _buildGroupInfoDivider(),
                ],

                // Created Date
                _buildGroupInfoSection(
                  title: 'Created',
                  icon: Icons.calendar_today,
                  content:
                      '${roomInfo.createdAt.day}/${roomInfo.createdAt.month}/${roomInfo.createdAt.year}',
                ),
                _buildGroupInfoDivider(),

                // Last Active Time
                if (roomInfo.lastActive != null) ...[
                  _buildGroupInfoSection(
                    title: 'Last Active',
                    icon: Icons.access_time,
                    content: _getTimeAgo(roomInfo.lastActive!),
                  ),
                  _buildGroupInfoDivider(),
                ],

                // Group Members (with optional loading state)
                if (_groupInfoMembersNotifier != null)
                  ValueListenableBuilder<List<RoomInfoMember>>(
                    valueListenable: _groupInfoMembersNotifier!,
                    builder: (context, members, _) {
                      return _buildGroupMembersSection(
                        roomInfo,
                        isLoadingMembers:
                            isLoadingMembers || _isGroupInfoRefreshing,
                        overrideMembers: members,
                        overrideMemberCount:
                            _groupInfoMemberCountNotifier?.value,
                      );
                    },
                  )
                else
                  _buildGroupMembersSection(
                    roomInfo,
                    isLoadingMembers:
                        isLoadingMembers || _isGroupInfoRefreshing,
                  ),
                _buildGroupInfoDivider(),

                // Leave Group Button (only show if user is member but not creator)
                if (showLeave) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close group info page
                          _leaveGroup(); // Show leave confirmation dialog
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.exit_to_app, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Leave Group',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildGroupInfoDivider(),
                ],

                // Bottom padding
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      // Mark group info page as closed when navigation completes
      _isGroupInfoPageOpen = false;
      _groupInfoMembersNotifier = null;
      _groupInfoMemberCountNotifier = null;
    });
  }

  /// Helper widget for divider in group info
  Widget _buildGroupInfoDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.grey.withOpacity(0.1),
      ),
    );
  }

  /// Helper widget for info section in group info
  Widget _buildGroupInfoSection({
    required String title,
    required IconData icon,
    required String content,
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
                color: AppColors.primary,
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

  /// Build members section from room info
  /// [isLoadingMembers] - if true, shows loader inside Members section
  Widget _buildGroupMembersSection(
    RoomInfo roomInfo, {
    bool isLoadingMembers = false,
    List<RoomInfoMember>? overrideMembers,
    int? overrideMemberCount,
  }) {
    // CRITICAL: Use roomInfo.members directly from API - backend filters by status='active'
    // BACKEND FIX: Add safety filter to ensure only active members are displayed (defensive programming)
    // Show all members with scrolling - no "View All" button
    final allMembers = (overrideMembers ?? roomInfo.members)
        .where((member) =>
            member.status == null ||
            member.status!.toLowerCase() ==
                'active') // Safety filter: only include active members
        .toList();

    // If loading and no members yet, show AppLoader
    if (isLoadingMembers && allMembers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Text(
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

    // If members list is empty, show AppLoader as loading indicator
    if (allMembers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Text(
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
          Row(
            children: [
              Icon(
                Icons.people,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
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
          if (isLoadingMembers)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 16, bottom: 16),
              child: const Center(
                child: AppLoader(
                  title: 'Loading Members',
                  subtitle: 'Fetching group members...',
                  icon: Icons.people,
                ),
              ),
            ),
          if (!isLoadingMembers) const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allMembers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final member = allMembers[index];
                final isCurrentUser = member.userId == widget.currentUserId;
                final isAdmin = member.isAdmin;
                final effectiveMemberCount =
                    roomInfo.memberCount ?? roomInfo.members.length;
                final canDeleteMembers =
                    (roomInfo.admin?.userId == widget.currentUserId ||
                            roomInfo.createdBy == widget.currentUserId) &&
                        effectiveMemberCount >= 4 &&
                        !isCurrentUser;

                // PERFORMANCE OPTIMIZATION: Immediate rendering with simple name resolution
                // No blocking lookups - use data directly from RoomInfo

                // Phase 1: Immediate rendering - simple name from RoomInfo
                // Use member.username directly (already from API), with minimal fallback
                String displayName;
                if (isCurrentUser) {
                  displayName = 'You';
                } else if (member.username != null &&
                    member.username!.isNotEmpty &&
                    !member.username!.startsWith('user_') &&
                    !_isUuidLike(member.username!)) {
                  // Use username from RoomInfo if it's not UUID-like
                  displayName = member.username!;
                } else {
                  // Simple fallback - no complex lookups
                  displayName = 'User';
                }

                // Avatar URL from RoomInfo (already available, no blocking)
                final avatarUrl = member.avatar;
                final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey.withOpacity(0.1),
                      backgroundImage:
                          hasAvatar ? NetworkImage(avatarUrl) : null,
                      onBackgroundImageError: hasAvatar
                          ? (exception, stackTrace) {
                              // Silent fail - avatar will fallback to initials
                              // Removed verbose logging that was contributing to UI delay
                            }
                          : null,
                      child: !hasAvatar
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
                            displayName,
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
                    // Show Admin badge for admins, Delete icon for regular members (if user is admin)
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
                        child: Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else if (canDeleteMembers)
                      // Show delete icon for non-admin members if current user is the group admin
                      // Only for group rooms (not 1-to-1) and not for self-removal
                      IconButton(
                        onPressed: () =>
                            _showRemoveMemberConfirmation(member, displayName),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Remove member',
                      )
                    else
                      // Debug: Not showing delete icon - just empty space
                      const SizedBox.shrink(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Show confirmation dialog for removing a member
  void _showRemoveMemberConfirmation(
      RoomInfoMember member, String displayName) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Remove Member',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove "$displayName" from the group?',
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This member will no longer receive messages from this group.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeMemberFromGroup(member);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Remove a member from the group
  Future<void> _removeMemberFromGroup(RoomInfoMember member) async {
    try {
      // Show loading indicator
      if (mounted) {
        setState(() => _isRemovingMember = true);
      }

      final companyId = await _apiService.getSelectedSocietyId();
      if (companyId == null) {
        if (mounted) {
          EnhancedToast.error(
            context,
            title: 'Error',
            message: 'Please select a society first',
          );
        }
        return;
      }

      // Call API to remove member
      // Backend expects member UUID from RoomInfo.user_id
      final memberIdToUse = member.userId;
      final response = await _chatService.removeMemberFromGroup(
        groupId: widget.group.id,
        memberId: memberIdToUse,
        companyId: companyId,
      );

      if (!mounted) return;

      if (response.success) {
        if (mounted) {
          EnhancedToast.success(
            context,
            title: 'Success',
            message: 'Member removed from group',
          );
        }

        // Optimistically update the open Group Info page immediately
        if (_isGroupInfoPageOpen && mounted) {
          final previousMembers = _groupInfoMembersNotifier?.value ?? [];
          final updatedMembers =
              previousMembers.where((m) => m.userId != member.userId).toList();
          final removedCount = previousMembers.length - updatedMembers.length;
          if (removedCount > 0) {
            _groupInfoMembersNotifier?.value = updatedMembers;
            if (_groupInfoMemberCountNotifier != null) {
              final currentCount = _groupInfoMemberCountNotifier!.value;
              final newCount = currentCount - removedCount;
              _groupInfoMemberCountNotifier!.value =
                  newCount < 0 ? 0 : newCount;
            }
          }
        }

        // Immediately refetch Group Info so the members list updates on the Group Info page
        if (_isGroupInfoPageOpen && mounted) {
          await _refreshGroupInfoPage(
            updateInPlace: true,
            forceNetwork: true,
          );
        }

        // PERFORMANCE OPTIMIZATION: Use selective invalidation instead of full cache clearing
        // Remove the specific member from cached RoomInfo immediately
        // This avoids unnecessary API calls while keeping cache accurate
        final roomInfoCache = RoomInfoCache();
        roomInfoCache.removeMemberOptimistically(
          roomId: widget.group.id,
          memberUserId: member.userId,
        );
        // Force subsequent fetches to hit the network (no stale cache)
        roomInfoCache.markMemberLeft(widget.group.id);
        roomInfoCache.clearRoomCache(widget.group.id);

        // Mark group as updated so GroupsTab refreshes when user returns
        // This ensures the member count is updated in the groups list
        GroupsTab.markGroupUpdated();

        // If the Group Info page isn't open, refresh data in the background
        // so other surfaces pick up the change.
        if (!_isGroupInfoPageOpen && mounted) {
          // Group info page is not open - just refresh background data
          if (mounted) {
            final coordinator = RoomRefreshCoordinator();
            coordinator.requestRefresh(
              roomId: widget.group.id,
              source: 'user_action',
              // After removal we still want a real fetch even if an optimistic
              // update just ran; otherwise the refresh is skipped and UI can stay stale.
              skipIfOptimisticUpdate: false,
              refreshAction: () async {
                // Force a network refresh so member list reflects removal immediately
                await _refreshGroupInfo(forceNetwork: true);
              },
            );
          }
        }

        // Immediately fetch fresh RoomInfo from backend so UI reflects removal
        await _refreshGroupInfo(forceNetwork: true);
      } else {
        if (mounted) {
          EnhancedToast.error(
            context,
            title: 'Error',
            message: response.error ?? 'Failed to remove member',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        EnhancedToast.error(
          context,
          title: 'Error',
          message: 'Failed to remove member: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRemovingMember = false);
      }
    }
  }

  /// Get time ago string
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

  /// Check if a string looks like a UUID (e.g., contains hyphens in UUID pattern or starts with "user_")
  bool _isUuidLike(String text) {
    if (text.isEmpty) return false;
    // Check if it starts with "user_" followed by UUID pattern
    if (text.startsWith('user_')) return true;
    // Check if it matches UUID pattern (8-4-4-4-12 format with hyphens)
    final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    return uuidPattern.hasMatch(text);
  }

  /// Infer forwarded flag from RoomMessage when API omits explicit is_forwarded.
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

    final lowerType = rm.messageType?.toLowerCase() ?? '';
    if (lowerType.contains('forward')) return true;

    final lowerEvent = rm.eventType?.toLowerCase() ?? '';
    if (lowerEvent.contains('forward')) return true;

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

  /// Helper function to find message by ID with UUID/numeric compatibility
  /// Handles cases where message IDs might be in different formats (UUID vs numeric)
  /// or have case/whitespace differences
  GroupMessage? _findMessageById(String? targetId,
      Map<String, GroupMessage> messageMap, List<GroupMessage> messageList) {
    if (targetId == null || targetId.isEmpty) return null;

    final normalizedTargetId = targetId.trim().toLowerCase();

    // Try direct match first
    if (messageMap.containsKey(targetId)) {
      return messageMap[targetId];
    }

    // Try normalized match
    if (messageMap.containsKey(normalizedTargetId)) {
      return messageMap[normalizedTargetId];
    }

    // Try in message list with normalization
    try {
      return messageList.firstWhere(
        (m) =>
            m.id.trim().toLowerCase() == normalizedTargetId || m.id == targetId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Fetch a specific replied-to message by loading older messages if needed
  /// This ensures reply previews are populated even when the replied-to message is in an older batch
  Future<void> _fetchRepliedToMessage(
      String replyToId, String replyMessageId) async {
    try {
      debugPrint(
          '🔄 [GroupChatScreen] Fetching replied-to message: $replyToId for reply: $replyMessageId');

      final companyId = await _apiService.getSelectedSocietyId();
      if (companyId == null) {
        debugPrint(
            '⚠️ [GroupChatScreen] Cannot fetch replied-to message: company_id not available');
        return;
      }

      // Try to find the message by loading more messages with a wider offset range
      // Load messages in batches to find the replied-to message
      // CRITICAL: Also check offset 0 (initial batch) in case it wasn't found during initial load
      // This handles cases where the message might have been missed due to UUID/numeric ID mismatch
      for (int offset = 0;
          offset < _messagesPerPage * 5;
          offset += _messagesPerPage) {
        final response = await _chatService.fetchMessages(
          roomId: widget.group.id,
          companyId: companyId,
          limit: _messagesPerPage,
          offset: offset,
        );

        if (!mounted) return;

        if (response.success && response.data != null) {
          final roomMessages = response.data!;

          // Check if the replied-to message is in this batch
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
            final repliedToGroupMessage =
                _convertRoomMessageToGroupMessage(repliedToRoomMessage);

            // Update the reply message with the found replied-to message
            // CRITICAL: Also ensure the replied-to message is in the message list
            if (mounted) {
              setState(() {
                final replyIndex =
                    _messages.indexWhere((m) => m.id == replyMessageId);
                if (replyIndex != -1) {
                  _messages[replyIndex] = _messages[replyIndex].copyWith(
                    replyTo: repliedToGroupMessage,
                  );
                  debugPrint(
                      '✅ [GroupChatScreen] Updated reply message ${replyMessageId} with found replied-to message: ${repliedToGroupMessage.id}');
                }

                // CRITICAL: Ensure the replied-to message is also in the message list
                // This ensures it's visible when re-entering the chat
                final repliedToIndex = _messages
                    .indexWhere((m) => m.id == repliedToGroupMessage.id);
                if (repliedToIndex == -1) {
                  // CRITICAL FIX: Check if user has left group before accessing messages
                  // This prevents RangeError if messages were cleared after user left
                  if (_hasLeftGroup || !_isUserMember) {
                    debugPrint(
                        '⚠️ [GroupChatScreen] User has left group, skipping replied-to message insertion');
                    return;
                  }

                  // Insert the replied-to message in chronological order
                  int insertIndex = _messages.length;
                  for (int i = 0; i < _messages.length; i++) {
                    if (_messages[i]
                        .timestamp
                        .isAfter(repliedToGroupMessage.timestamp)) {
                      insertIndex = i;
                      break;
                    }
                  }

                  // CRITICAL FIX: Bounds check before insert
                  if (insertIndex >= 0 && insertIndex <= _messages.length) {
                    _messages.insert(insertIndex, repliedToGroupMessage);
                    debugPrint(
                        '✅ [GroupChatScreen] Added replied-to message to message list: ${repliedToGroupMessage.id} at index $insertIndex');
                  } else {
                    debugPrint(
                        '⚠️ [GroupChatScreen] Invalid insertIndex: $insertIndex (messages.length: ${_messages.length})');
                  }
                } else {
                  debugPrint(
                      '✅ [GroupChatScreen] Replied-to message already in list: ${repliedToGroupMessage.id}');
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

      debugPrint(
          '⚠️ [GroupChatScreen] Could not find replied-to message $replyToId in older messages');
    } catch (e) {
      debugPrint('❌ [GroupChatScreen] Error fetching replied-to message: $e');
    }
  }

  void _leaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Leave Group',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to leave "${widget.group.name}"?',
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will no longer receive messages from this group.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // CRITICAL FIX: Close dialog BEFORE showing loading to avoid context conflicts
              Navigator.pop(context); // Close confirmation dialog

              // CRITICAL FIX: Use screen context, not dialog context, for loading sheet
              // Dialog context becomes invalid after Navigator.pop()
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;

                // Show loading indicator using screen context
                showModalBottomSheet(
                  context:
                      this.context, // Use screen context, not dialog context
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
              });

              try {
                // Call API to leave the room
                final response = await _roomService.leaveRoom(widget.group.id);

                if (!mounted) return;

                // Close loading indicator first
                Navigator.pop(this.context); // Use screen context

                if (response.success) {
                  // CRITICAL: Clear membership status to prevent re-entry
                  // This ensures the user cannot access this group anymore
                  if (mounted) {
                    setState(() {
                      _isUserMember = false;
                      _isMemberFromRoomInfo = false;
                      _hasLeftGroup = true; // Mark that user left the group
                    });
                  }

                  // PERSIST LEAVE STATUS: Mark in GroupsTab so it persists across navigation
                  GroupsTab.markUserLeftGroup(widget.group.id);

                  // Clean up WebSocket connection
                  await _chatService.leaveRoom(widget.group.id);

                  // CRITICAL FIX: Get current user UUID to remove from cache
                  String? currentUserUuid;
                  try {
                    final userData = await KeycloakService.getUserData();
                    if (userData != null && userData['sub'] != null) {
                      currentUserUuid = userData['sub'].toString();
                      debugPrint(
                          '✅ [GroupChatScreen] Current user UUID: $currentUserUuid');
                    }
                  } catch (e) {
                    debugPrint(
                        '⚠️ [GroupChatScreen] Error getting current user UUID: $e');
                  }

                  // CRITICAL FIX: Optimistically remove leaving user from cache
                  // This updates cache immediately, then we clear it so admins get fresh data from API
                  final roomInfoCache = RoomInfoCache();
                  if (currentUserUuid != null) {
                    roomInfoCache.removeMemberOptimistically(
                      roomId: widget.group.id,
                      memberUserId: currentUserUuid,
                    );
                    debugPrint(
                        '✅ [GroupChatScreen] Removed leaving user from cache: $currentUserUuid');
                  }

                  // CRITICAL FIX: Mark that a member left - this forces fresh API fetch for 30 seconds
                  // This ensures admins viewing the group see updated member list immediately
                  roomInfoCache.markMemberLeft(widget.group.id);

                  // CRITICAL FIX: Clear cache so all admins get fresh data from API
                  // This ensures admins viewing the group see updated member list (only active members)
                  roomInfoCache.clearRoomCache(widget.group.id);
                  debugPrint(
                      '✅ [GroupChatScreen] Cleared cache and marked member left for room - admins will get fresh data from API');

                  // CRITICAL FIX: Decrement member count in GroupsTab
                  // This ensures member count is updated immediately in groups list
                  GroupsTab.decrementGroupMemberCount(widget.group.id, 1);

                  // Remove room locally from groups list
                  GroupsTab.removeGroup(widget.group.id);

                  // Invalidate groups cache for consistency
                  // This ensures the groups list is refreshed with accurate data
                  GroupsTab.invalidateGroupsCache();

                  // Mark group as updated so GroupsTab refreshes when user returns
                  GroupsTab.markGroupUpdated();

                  // Cancel any pending refreshes for this room since user left
                  final coordinator = RoomRefreshCoordinator();
                  coordinator.cancelPendingRefresh(widget.group.id);

                  // Check if still mounted before showing toast and navigating
                  if (!mounted) return;

                  // CRITICAL FIX: Clear messages and state FIRST before navigation
                  // This prevents RangeError when ListView tries to access cleared messages
                  // Clear messages and any other cached data for this room
                  // This prevents any potential data leakage or stale state
                  _messages.clear();
                  _memberAvatarCache.clear();
                  _numericIdToUuidMap.clear();

                  // CRITICAL FIX: Update UI state immediately to reflect cleared messages
                  // This ensures ListView rebuilds with empty itemCount before navigation
                  // This prevents RangeError when ListView.builder tries to access _messages[index]
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _hasError = false;
                      _isLoadingMore = false;
                      _isTyping = false;
                    });
                    debugPrint(
                        '✅ [GroupChatScreen] Cleared messages and updated UI state');
                  }

                  // CRITICAL FIX: Show toast FIRST while context is definitely valid
                  // Then navigate after a short delay to ensure toast is visible
                  try {
                    // Show success toast immediately while context is valid
                    EnhancedToast.success(
                      context,
                      title: 'Left Group',
                      message: 'Leave Group Successfully',
                      duration: const Duration(seconds: 3),
                    );

                    debugPrint(
                        '✅ [GroupChatScreen] Success toast shown: Leave Group Successfully');

                    // Navigate after a short delay to ensure toast is visible
                    // This gives the toast time to appear before navigation
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (mounted) {
                        try {
                          final navigator = Navigator.of(context);
                          if (navigator.canPop()) {
                            navigator.pop();
                            debugPrint(
                                '✅ [GroupChatScreen] Navigated back to GroupsTab');
                          }
                        } catch (navError) {
                          debugPrint(
                              '⚠️ [GroupChatScreen] Error navigating: $navError');
                        }
                      }
                    });
                  } catch (e) {
                    debugPrint('⚠️ [GroupChatScreen] Error showing toast: $e');
                    // Still navigate even if toast fails
                    if (mounted) {
                      try {
                        final navigator = Navigator.of(context);
                        if (navigator.canPop()) {
                          navigator.pop();
                        }
                      } catch (navError) {
                        debugPrint(
                            '⚠️ [GroupChatScreen] Error navigating: $navError');
                      }
                    }
                  }
                } else {
                  // Close loading indicator first
                  if (mounted) {
                    try {
                      Navigator.pop(this.context); // Use screen context
                    } catch (e) {
                      debugPrint(
                          '⚠️ [GroupChatScreen] Error closing loading indicator: $e');
                    }
                  }

                  // Show error message - only if still mounted and context is valid
                  if (mounted) {
                    try {
                      final overlay = Overlay.maybeOf(this.context);
                      if (overlay != null) {
                        EnhancedToast.error(
                          this.context, // Use screen context
                          title: 'Error',
                          message: response.error ?? 'Failed to leave group',
                        );
                      } else {
                        debugPrint(
                            '⚠️ [GroupChatScreen] Cannot show error toast - overlay unavailable');
                      }
                    } catch (e) {
                      debugPrint(
                          '⚠️ [GroupChatScreen] Error showing error toast: $e');
                    }
                  }
                }
              } catch (e) {
                if (!mounted) return;

                // Close loading indicator first - wrap in try-catch to prevent widget lifecycle errors
                if (mounted) {
                  try {
                    Navigator.pop(this.context); // Use screen context
                  } catch (popError) {
                    debugPrint(
                        '⚠️ [GroupChatScreen] Error closing loading indicator in catch: $popError');
                  }
                }

                // Show error message - only if still mounted and context is valid
                if (mounted) {
                  try {
                    final overlay = Overlay.maybeOf(this.context);
                    if (overlay != null) {
                      // Only show error if it's not a widget lifecycle error
                      final errorMessage = e.toString();
                      if (!errorMessage.contains('deactivated widget') &&
                          !errorMessage.contains('widget tree') &&
                          !errorMessage.contains('ancestor is unsafe')) {
                        EnhancedToast.error(
                          this.context, // Use screen context
                          title: 'Error',
                          message: 'Failed to leave group: $e',
                        );
                      } else {
                        debugPrint(
                            '⚠️ [GroupChatScreen] Widget lifecycle error during leave group - not showing toast: $e');
                        // Don't show error toast for widget lifecycle errors - operation likely succeeded
                      }
                    } else {
                      debugPrint(
                          '⚠️ [GroupChatScreen] Cannot show error toast - overlay unavailable');
                    }
                  } catch (toastError) {
                    debugPrint(
                        '⚠️ [GroupChatScreen] Error showing error toast: $toastError');
                    // Don't re-throw - operation may have succeeded despite toast error
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Leave Group',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleMuteNotifications() {
    setState(() {
      _isMuted = !_isMuted;
    });

    if (_isMuted) {
      EnhancedToast.success(
        context,
        title: 'Notifications Muted',
        message:
            'You will not receive notifications from "${widget.group.name}"',
      );
    } else {
      EnhancedToast.success(
        context,
        title: 'Notifications Unmuted',
        message: 'You will receive notifications from "${widget.group.name}"',
      );
    }
  }

  /// Show dialog to select image source for group image upload
  void _showUploadGroupImageDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _uploadGroupImage(ImageSource.camera);
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _uploadGroupImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  /// Build image source option widget
  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if current user is admin (creator) of the group
  /// Compares both UUID (creatorId) and numeric ID (createdByUserId) for reliability
  bool _isCurrentUserAdmin() {
    // First try to compare using numeric user ID (preferred)
    if (widget.currentUserNumericId != null &&
        widget.group.createdByUserId != null) {
      return widget.currentUserNumericId == widget.group.createdByUserId;
    }
    // Fallback to UUID comparison for backward compatibility
    return widget.group.creatorId == widget.currentUserId;
  }

  /// Show dialog to add members to the group
  /// Opens CreateGroupPage in edit mode with pre-filled data
  void _showAddMemberDialog() async {
    // Double-check admin status before opening (security check)
    if (!_isCurrentUserAdmin()) {
      EnhancedToast.error(
        context,
        title: 'Access Denied',
        message: 'Only group admin can add members',
      );
      return;
    }

    debugPrint(
        '✅ [GroupChatScreen] Opening CreateGroupPage in edit mode for group: ${widget.group.name}');
    // Navigate to CreateGroupPage in edit mode with add member mode flag
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CreateGroupPage(
          groupToEdit: widget.group,
          isAddMemberMode: true, // Set flag to disable group information card
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        fullscreenDialog: true,
      ),
    );

    // Handle result if group was updated
    if (result != null && result is GroupChat) {
      debugPrint('✅ [GroupChatScreen] Group updated from add member flow');

      // OPTIMISTIC UPDATE: Immediately refresh UI from cache (no delay)
      // This provides instant feedback as optimistic updates are already in cache
      await _refreshGroupInfo(); // This now uses cached optimistic data immediately

      // Mark that group was updated - this will trigger refresh when user returns to GroupsTab
      // DO NOT force refresh here as it would overwrite optimistic updates with stale API data
      GroupsTab.markGroupUpdated();
      debugPrint(
          '✅ [GroupChatScreen] Group marked as updated - will refresh when tab becomes active');
    }
  }

  /// Upload group image
  Future<void> _uploadGroupImage(ImageSource source) async {
    try {
      // Pick image (no loading needed for image picker)
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (!mounted) return;

      if (image == null) {
        return; // User cancelled
      }

      final imageFile = File(image.path);

      // Get company_id (society ID) from selectedFlatProvider - required for the API
      final selectedFlatState = ref.read(selectedFlatProvider);
      final companyId = selectedFlatState.selectedSociety?.socId;
      if (companyId == null) {
        if (mounted) {
          EnhancedToast.error(
            context,
            title: 'Error',
            message: 'Please select a society first',
          );
        }
        return;
      }

      // Show OneApp global loader for upload
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const AppLoader(
              title: 'Uploading Image',
              subtitle: 'Please wait while we upload your group photo...',
              icon: Icons.image_rounded,
            ),
          ),
        ),
      );

      // First, upload the image file to get a URL
      String? imageUrl;
      try {
        imageUrl = await _uploadImageFileToGetUrl(imageFile);
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          EnhancedToast.error(
            context,
            title: 'Error',
            message: 'Failed to upload image: ${e.toString()}',
          );
        }
        return;
      }

      if (imageUrl == null || imageUrl.isEmpty) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          EnhancedToast.error(
            context,
            title: 'Error',
            message: 'Failed to get image URL',
          );
        }
        return;
      }

      // Upload group photo using JSON API with image_url
      final response = await _roomService.uploadRoomPhoto(
        roomId: widget.group.id,
        imageUrl: imageUrl,
        companyId: companyId,
        isPrimary: true,
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      if (response.success) {
        // Extract photo_url from response if available, otherwise use the uploaded imageUrl
        String? updatedPhotoUrl;
        if (response.data != null && response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          updatedPhotoUrl = data['photo_url'] as String? ?? imageUrl;
        } else {
          updatedPhotoUrl = imageUrl;
        }

        // Update local state with new icon URL
        if (mounted) {
          setState(() {
            _updatedGroupIconUrl = updatedPhotoUrl;
          });
        }

        // Update the specific group's iconUrl in GroupsTab immediately
        try {
          GroupsTab.updateGroupIconUrl(widget.group.id, updatedPhotoUrl);
          debugPrint('✅ [GroupChatScreen] Updated group iconUrl in GroupsTab');
        } catch (e) {
          debugPrint('⚠️ [GroupChatScreen] Failed to update group iconUrl: $e');
        }

        // Mark that group was updated (image upload) - this will trigger immediate API call when user returns to GroupsTab
        GroupsTab.markGroupUpdated();

        // Also mark image upload for backward compatibility
        GroupsTab.markImageUploaded();

        // Also refresh groups list to ensure consistency (with a small delay to let API update)
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            GroupsTab.refreshGroups();
            debugPrint('✅ [GroupChatScreen] Refreshed groups list');
          } catch (e) {
            debugPrint(
                '⚠️ [GroupChatScreen] Failed to refresh groups list: $e');
          }
        });

        EnhancedToast.success(
          context,
          title: 'Success',
          message: 'Group image uploaded successfully',
        );
      } else {
        EnhancedToast.error(
          context,
          title: 'Error',
          message: response.displayError.isNotEmpty
              ? response.displayError
              : 'Failed to upload group image',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        EnhancedToast.error(
          context,
          title: 'Error',
          message: 'Failed to upload group image: ${e.toString()}',
        );
      }
    }
  }

  /// Upload image file to get a URL
  /// This is a helper method to convert File to URL before calling uploadRoomPhoto
  Future<String?> _uploadImageFileToGetUrl(File imageFile) async {
    try {
      // Using the same image upload service as posts
      final postApiClient = PostApiClient(
        Dio()..interceptors.add(AuthInterceptor()),
      );

      final imageUrl = await postApiClient.uploadImage(imageFile);
      debugPrint('✅ [GroupChatScreen] Image uploaded, URL: $imageUrl');
      return imageUrl;
    } catch (e) {
      debugPrint('⚠️ [GroupChatScreen] Error uploading image file: $e');
      return null;
    }
  }
}

/// Screen for adding members to a room
class _AddMemberScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;
  final String currentUserId;

  const _AddMemberScreen({
    required this.roomId,
    required this.roomName,
    required this.currentUserId,
  });

  @override
  ConsumerState<_AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends ConsumerState<_AddMemberScreen> {
  final IntercomService _intercomService = IntercomService();
  final RoomService _roomService = RoomService.instance;
  final SocietyBackendApiService _societyBackendApiService =
      SocietyBackendApiService.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<IntercomContact> _allMembers = [];
  List<IntercomContact> _filteredMembers = [];
  final Set<String> _selectedMemberIds = {};
  Set<String> _existingMemberIds = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isAdding = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _perPage = 50;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _searchController.addListener(_filterMembers);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        !_isLoading &&
        _hasMore) {
      _loadMoreMembers();
    }
  }

  /// Load all available members and existing room members
  Future<void> _loadMembers({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
        _hasMore = true;
        _allMembers.clear();
      });
    } else {
      setState(() {
        _isLoadingMore = true;
        _currentPage++;
      });
    }

    try {
      // Get existing room members (only on first load)
      if (reset) {
        final selectedFlatStateForRoom = ref.read(selectedFlatProvider);
        final companyId = selectedFlatStateForRoom.selectedSociety?.socId;
        if (companyId != null) {
          final roomInfoResponse = await _roomService.getRoomInfo(
            roomId: widget.roomId,
            companyId: companyId,
          );

          if (roomInfoResponse.success && roomInfoResponse.data != null) {
            final roomInfo = roomInfoResponse.data!;
            _existingMemberIds = {
              ...roomInfo.members.map((m) => m.userId),
              if (roomInfo.admin?.userId != null) roomInfo.admin!.userId!,
            };
          }
        }
      }

      // Get the selected society ID from selectedFlatProvider
      final selectedFlatState = ref.read(selectedFlatProvider);
      final societyId = selectedFlatState.selectedSociety?.socId;
      if (societyId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLoadingMore = false;
            _errorMessage =
                'No society ID found. Please select a society first.';
          });
        }
        return;
      }

      // Call the API with pagination
      final response = await _societyBackendApiService.getMembers(
        page: _currentPage,
        perPage: _perPage,
        societyId: societyId.toString(),
      );

      // Map API response to IntercomContact
      final newMembers = response.members
          .map((memberData) {
            // Extract name
            String? extractedName;
            final firstName =
                memberData['member_first_name']?.toString().trim() ??
                    memberData['first_name']?.toString().trim();
            final lastName =
                memberData['member_last_name']?.toString().trim() ??
                    memberData['last_name']?.toString().trim();

            if (firstName != null && firstName.isNotEmpty) {
              extractedName = (lastName != null && lastName.isNotEmpty)
                  ? '$firstName $lastName'
                  : firstName;
            } else if (lastName != null && lastName.isNotEmpty) {
              extractedName = lastName;
            } else if (memberData['member_name'] != null) {
              final memberName = memberData['member_name'].toString();
              final nameMatch = RegExp(r'^([^(]+)').firstMatch(memberName);
              if (nameMatch != null) {
                extractedName = nameMatch.group(1)?.trim();
              } else {
                extractedName = memberName;
              }
            }

            extractedName ??= memberData['name']?.toString() ??
                memberData['full_name']?.toString() ??
                'Unknown';

            // Extract unit
            final unit = memberData['unit_flat_number']?.toString() ??
                memberData['flat_number']?.toString() ??
                memberData['unit']?.toString() ??
                memberData['unit_number']?.toString();

            // Extract building
            final building = memberData['soc_building_name']?.toString() ??
                memberData['building_name']?.toString();

            // Extract building letter from unit (e.g., 'A' from 'A-101')
            String? buildingLetter;
            if (unit != null && unit.contains('-')) {
              buildingLetter = unit.split('-')[0].trim();
            } else if (building != null && building.contains('-')) {
              buildingLetter = building.split('-')[0].trim();
            }

            // Extract phone
            final phone = memberData['member_mobile_number']?.toString() ??
                memberData['mobile']?.toString() ??
                memberData['phone']?.toString() ??
                memberData['phone_number']?.toString();

            // Extract member ID
            final memberId = memberData['member_id']?.toString() ??
                memberData['id']?.toString() ??
                memberData['user_id']?.toString() ??
                'unknown';

            // Check if user_id is actually null (not just the string "null")
            // This is critical: members without user_id are not OneApp users
            final userIdValue =
                memberData['user_id']; // Get raw value, not string
            final userIdStr = userIdValue?.toString();
            final hasUserId = userIdValue != null &&
                userIdStr != null &&
                userIdStr != 'null' &&
                userIdStr.isNotEmpty;

            // Extract numeric user ID for API calls that require it
            int? numericUserId;
            final oldGateUserIdStr = memberData['old_gate_user_id']?.toString();
            final userAccountId = memberData['user_account_id']?.toString();

            // Priority 1: old_gate_user_id (matches what will be in x-user-id header)
            if (oldGateUserIdStr != null &&
                oldGateUserIdStr != 'null' &&
                oldGateUserIdStr.isNotEmpty) {
              numericUserId = int.tryParse(oldGateUserIdStr);
            }
            // Priority 2: user_id from member listing
            else if (hasUserId && userIdStr != null) {
              numericUserId = int.tryParse(userIdStr);
            }
            // Priority 3: user_account_id
            else if (userAccountId != null &&
                userAccountId != 'null' &&
                userAccountId.isNotEmpty) {
              numericUserId = int.tryParse(userAccountId);
            }

            return IntercomContact(
              id: memberId,
              name: extractedName,
              unit: unit,
              building: buildingLetter ?? building,
              floor: memberData['floor']?.toString(),
              type: IntercomContactType.resident,
              phoneNumber: phone,
              numericUserId: numericUserId,
              hasUserId: hasUserId, // Track if user_id is null from API
            );
          })
          .where((contact) =>
              contact.name != 'Unknown' &&
              contact.id != widget.currentUserId &&
              !_existingMemberIds.contains(contact.id))
          .toList();

      // Remove duplicates based on ID
      final seenIds = <String>{};
      final uniqueNewMembers = newMembers.where((member) {
        if (seenIds.contains(member.id)) {
          return false;
        }
        seenIds.add(member.id);
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          if (reset) {
            _allMembers = uniqueNewMembers;
          } else {
            _allMembers.addAll(uniqueNewMembers);
          }
          _hasMore = response.hasMore;
          _isLoading = false;
          _isLoadingMore = false;
        });

        // Apply current search filter
        _filterMembers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = 'Failed to load members: $e';
        });
      }
    }
  }

  Future<void> _loadMoreMembers() async {
    await _loadMembers(reset: false);
  }

  /// Filter members based on search query
  void _filterMembers() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredMembers = List.from(_allMembers);
      });
      return;
    }

    setState(() {
      _filteredMembers = _allMembers
          .where((member) =>
              member.name.toLowerCase().contains(query) ||
              (member.unit != null &&
                  member.unit!.toLowerCase().contains(query)) ||
              (member.role != null &&
                  member.role!.toLowerCase().contains(query)))
          .toList();
    });
  }

  /// Toggle member selection
  void _toggleMemberSelection(String memberId) {
    // Find the member by ID
    final member = _allMembers.firstWhere(
      (m) => m.id == memberId,
      orElse: () => _filteredMembers.firstWhere(
        (m) => m.id == memberId,
        orElse: () => IntercomContact(
          id: memberId,
          name: 'Unknown',
          type: IntercomContactType.resident,
        ),
      ),
    );

    // Disable selection for members without user_id (not OneApp users)
    // CRITICAL: Check hasUserId field which tracks if user_id was null in API response
    if (!member.hasUserId) {
      debugPrint(
          '🔒 [AddMemberScreen] Cannot select member without user_id: ${member.name} (${member.id})');
      EnhancedToast.info(
        context,
        title: 'Cannot Select',
        message:
            '${member.name} is not a OneApp user and cannot be added to the group',
      );
      return;
    }

    setState(() {
      if (_selectedMemberIds.contains(memberId)) {
        _selectedMemberIds.remove(memberId);
      } else {
        _selectedMemberIds.add(memberId);
      }
    });
  }

  /// Add selected members to the room
  Future<void> _addMembers() async {
    if (_selectedMemberIds.isEmpty) {
      EnhancedToast.warning(
        context,
        title: 'No Selection',
        message: 'Please select at least one member to add',
      );
      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      // Get selected member details from _allMembers
      final selectedMembers = _allMembers
          .where((member) => _selectedMemberIds.contains(member.id))
          .toList();

      // Build payload using only valid numeric IDs (backend requires int user_id)
      final membersPayload = <Map<String, dynamic>>[];
      final skippedInvalidIds = <String>[];

      for (final member in selectedMembers) {
        // CRITICAL FIX: Use numericUserId (old_gate_user_id) for membership validation consistency
        final numericId = member.numericUserId ?? int.tryParse(member.id);
        if (numericId == null) {
          skippedInvalidIds.add(member.id);
          continue;
        }
        membersPayload.add({
          'user_id': numericId,
          'name': member.name,
          'phone': member.phoneNumber ?? '',
        });
      }

      if (membersPayload.isEmpty) {
        if (mounted) {
          EnhancedToast.warning(
            context,
            title: 'Invalid Selection',
            message:
                'Selected members could not be added (invalid member IDs). Please reselect.',
          );
        }
        return;
      }

      if (selectedMembers.isEmpty) {
        if (mounted) {
          EnhancedToast.warning(
            context,
            title: 'Error',
            message: 'Selected members not found',
          );
        }
        return;
      }

      debugPrint(
          '📤 [AddMemberScreen] Adding ${membersPayload.length} members to room: ${widget.roomId}');

      // Call the API to add members
      final response = await _roomService.addMembersToRoom(
        roomId: widget.roomId,
        members: membersPayload,
      );

      if (!mounted) return;

      if (response.success) {
        final addedCount = membersPayload.length;
        EnhancedToast.success(
          context,
          title: 'Success',
          message: skippedInvalidIds.isEmpty
              ? 'Added $addedCount member(s) to the group'
              : 'Added $addedCount member(s). Skipped ${skippedInvalidIds.length} with invalid IDs.',
        );

        // Mark group as updated so GroupsTab refreshes with new member count
        GroupsTab.markGroupUpdated();

        // Optimistically update member count
        GroupsTab.incrementGroupMemberCount(widget.roomId, addedCount);

        // Close the screen and return success
        Navigator.of(context).pop(true);
      } else {
        EnhancedToast.error(
          context,
          title: 'Error',
          message: response.error ?? 'Failed to add members',
        );
      }
    } catch (e) {
      debugPrint('❌ [AddMemberScreen] Error adding members: $e');
      if (mounted) {
        EnhancedToast.error(
          context,
          title: 'Error',
          message: 'Failed to add members: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Members'),
            Text(
              widget.roomName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedMemberIds.isNotEmpty)
            TextButton(
              onPressed: _isAdding ? null : _addMembers,
              child: _isAdding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Add (${_selectedMemberIds.length})',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: AppLoader(
                title: 'Loading Members',
                subtitle: 'Fetching available members...',
                icon: Icons.people,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadMembers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Search bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkTheme
                            ? Colors.grey.shade900
                            : Colors.grey.shade50,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search members...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor:
                              isDarkTheme ? Colors.grey.shade800 : Colors.white,
                        ),
                      ),
                    ),
                    // Members list
                    Expanded(
                      child: _filteredMembers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? 'No members found'
                                        : 'No members available',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(8),
                              itemCount: _filteredMembers.length +
                                  (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _filteredMembers.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final member = _filteredMembers[index];
                                final isSelected =
                                    _selectedMemberIds.contains(member.id);
                                // Disable if user_id is null (not a OneApp user)
                                // CRITICAL: Use hasUserId field which tracks if user_id was null in API response
                                final isDisabled = !member.hasUserId;

                                return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          AppColors.primary.withOpacity(
                                              isSelected ? 1.0 : 0.1),
                                      child: member.photoUrl != null
                                          ? ClipOval(
                                              child: Image.network(
                                                member.photoUrl!,
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Text(
                                                    member.initials,
                                                    style: TextStyle(
                                                      color: isSelected
                                                          ? Colors.white
                                                          : AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  );
                                                },
                                              ),
                                            )
                                          : Text(
                                              member.initials,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                    title: Text(
                                      member.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.typeLabel +
                                              (member.unit != null
                                                  ? ' • ${member.unit}'
                                                  : ''),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (isDisabled)
                                          Text(
                                            'Not a OneApp user',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: isDisabled
                                        ? ElevatedButton.icon(
                                            onPressed: () =>
                                                OneAppShare.shareInvite(
                                                  name: member.name,
                                                ),
                                            icon: const Icon(
                                              Icons.person_add,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Invite',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              elevation: 0,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              minimumSize: const Size(0, 0),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          )
                                        : Checkbox(
                                            value: isSelected,
                                            onChanged: (_) =>
                                                _toggleMemberSelection(
                                                    member.id),
                                            activeColor: AppColors.primary,
                                          ),
                                    onTap: isDisabled
                                        ? null
                                        : () =>
                                            _toggleMemberSelection(member.id),
                                  );
                              },
                            ),
                    ),
                  ],
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
