import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/colors.dart';
import '../../../core/layout/app_scaffold.dart';
import '../../../core/widgets/responsive_tab_bar.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/keycloak_service.dart';
import '../../../core/utils/navigation_helper.dart';
import '../../../core/utils/profile_data_helper.dart';
import '../../../../core/models/api_response.dart';
import 'tabs/residents_tab.dart';
import 'tabs/committee_tab.dart';
import 'tabs/gatekeepers_tab.dart';
import 'tabs/posts_tab.dart';
import 'tabs/society_office_tab.dart';
import 'tabs/lobbies_tab.dart';
import 'tabs/groups_tab.dart';
import 'models/call_history_entry.dart';
import 'models/call_status.dart';
import 'models/intercom_contact.dart';
import 'models/room_message_model.dart';
import 'models/room_model.dart';
import 'models/room_info_model.dart';
import 'services/call_history_service.dart';
import 'services/chat_service.dart';
import 'services/chat_websocket_service.dart';
import 'services/unread_count_manager.dart';
import 'services/room_service.dart';
import 'utils/activity_preview_helper.dart';
import 'chat_screen.dart';
import 'dart:async';

String? _normalizeAvatarUrl(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
    return null;
  }

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }

  // Some APIs may return just a numeric user id for avatars; build the expected S3 URL.
  if (RegExp(r'^\\d+$').hasMatch(trimmed)) {
    return ProfileDataHelper.buildAvatarUrlFromUserId(trimmed);
  }

  // Handle leading slash paths from backend (e.g. "/avatar_1_large.jpg")
  final sanitized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  return ProfileDataHelper.resolveAvatarUrl({'avatar': sanitized});
}

class IntercomScreen extends StatefulWidget {
  final bool showGatekeeperTab;
  final bool fromOneGateCard;
  final bool fromNeighborsCard;

  const IntercomScreen({
    Key? key,
    this.showGatekeeperTab = true,
    this.fromOneGateCard = false,
    this.fromNeighborsCard = false,
  }) : super(key: key);

  @override
  State<IntercomScreen> createState() => _IntercomScreenState();
}

class _IntercomScreenState extends State<IntercomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  late List<String> _tabTitles;
  late List<IconData> _tabIcons;
  // ValueNotifier to notify tabs when they become visible
  final ValueNotifier<int> _activeTabNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _initializeTabs();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
    _tabController.addListener(_handleTabChange);

    // Set initial tab index after a frame to ensure tabs are built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _activeTabNotifier.value = _tabController.index;
      }
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      final newIndex = _tabController.index;
      setState(() {
        _currentIndex = newIndex;
      });
      // Notify tabs that a new tab has become active
      _activeTabNotifier.value = newIndex;
    }
  }

  void _initializeTabs() {
    if (widget.fromNeighborsCard) {
      // When accessed from Neighbors Card, show Residents, Committee and Groups tabs
      _tabTitles = [
        'Residents',
        'Committee',
        'Groups',
      ];
      _tabIcons = [
        Icons.people_rounded,
        Icons.groups_rounded,
        Icons.chat_rounded,
      ];
    } else if (widget.fromOneGateCard) {
      // When accessed from OneGate Card, show only Gatekeepers tab
      _tabTitles = [
        'Gatekeepers',
        'Society Office',
        'Lobbies',
      ];
      _tabIcons = [
        Icons.security_rounded,
        Icons.business_rounded,
        Icons.meeting_room_rounded,
      ];
    } else if (widget.showGatekeeperTab) {
      // Normal mode with gatekeeper tab
      _tabTitles = [
        'Posts',
        'Residents',
        'Committee',
        'Gatekeepers',
      ];
      _tabIcons = [
        Icons.forum_rounded,
        Icons.people_rounded,
        Icons.groups_rounded,
        Icons.security_rounded,
      ];
    } else {
      // Normal mode without gatekeeper tab
      _tabTitles = [
        'Posts',
        'Residents',
        'Committee',
      ];
      _tabIcons = [
        Icons.forum_rounded,
        Icons.people_rounded,
        Icons.groups_rounded,
      ];
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _activeTabNotifier.dispose();
    super.dispose();
  }

  // Check if Groups tab is currently selected
  bool get _isGroupsTabSelected {
    if (_tabTitles.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _tabTitles.length) {
      return false;
    }
    return _tabTitles[_currentIndex] == 'Groups';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold.internal(
      title: widget.fromNeighborsCard ? 'Neighbors' : 'Intercom',
      actions: _isGroupsTabSelected
          ? null // Hide chat history icon when Groups tab is selected
          : [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () {
                  // Show call history
                  _showCallHistory();
                },
                tooltip: 'Chat History',
              ),
            ],
      body: Column(
        children: [
          // Modern Segmented Control Tabs
          ResponsiveTabBar(
            controller: _tabController,
            tabLabels: _tabTitles,
            tabIcons: _tabIcons,
            currentIndex: _currentIndex,
            padding: EdgeInsets.zero,
          ),

          // Tab content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: TabBarView(
                controller: _tabController,
                children: _buildTabContentList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTabContentList() {
    if (widget.fromNeighborsCard) {
      // When accessed from Neighbors Card, show Residents, Committee and Groups tabs
      return [
        ResidentsTab(
          activeTabNotifier: _activeTabNotifier,
          tabIndex: 0,
        ),
        CommitteeTab(
          activeTabNotifier: _activeTabNotifier,
          tabIndex: 1,
        ),
        GroupsTab(
          activeTabNotifier: _activeTabNotifier,
          tabIndex: 2,
        ),
      ];
    } else if (widget.fromOneGateCard) {
      // When accessed from OneGate Card
      return [
        GatekeepersTab(
          activeTabNotifier: _activeTabNotifier,
          tabIndex: 0,
        ),
        const SocietyOfficeTab(),
        const LobbiesTab(),
      ];
    } else if (widget.showGatekeeperTab) {
      // Normal mode with gatekeeper tab
      return [
        const PostsTab(),
        ResidentsTab(
          activeTabNotifier: _activeTabNotifier,
          tabIndex: 1,
        ),
        CommitteeTab(
          activeTabNotifier: _activeTabNotifier,
          tabIndex: 2,
        ),
        GatekeepersTab(
          activeTabNotifier: _activeTabNotifier,
          tabIndex: 3,
        ),
      ];
    } else {
      // Normal mode without gatekeeper tab
      return [
        const PostsTab(),
        ResidentsTab(
          activeTabNotifier: _activeTabNotifier,
          tabIndex: 1,
        ),
        CommitteeTab(
          activeTabNotifier: _activeTabNotifier,
          tabIndex: 2,
        ),
      ];
    }
  }

  void _showCallHistory() {
    // Navigate to full page instead of bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CallHistoryPage(),
        fullscreenDialog: true,
      ),
    );
  }
}

/// Full page for Call & Chat History
class CallHistoryPage extends StatefulWidget {
  const CallHistoryPage({Key? key}) : super(key: key);

  @override
  State<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends State<CallHistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ScrollController _chatHistoryScrollController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chatHistoryScrollController = ScrollController();
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentIndex = _tabController.index;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _chatHistoryScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background for the page
      appBar: AppBar(
        title: const Text(
          'Chats & Calls History',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          ResponsiveTabBar(
            controller: _tabController,
            tabLabels: const ['Chats', 'Calls'],
            tabIcons: const [Icons.chat, Icons.call],
            currentIndex: _currentIndex,
            padding: EdgeInsets.zero,
          ),

          // Tab content
          Expanded(
            child: Container(
              color: Colors.white, // White background for tab content
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Chats Tab - Show actual 1-to-1 chat history (first tab)
                  _ChatHistoryTab(
                      scrollController: _chatHistoryScrollController),

                  // Calls Tab (second tab)
                  const _CallsHistoryTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IntercomSearchDelegate extends SearchDelegate<String> {
  final List<String> tabTitles;

  IntercomSearchDelegate(this.tabTitles);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return const Center(
      child: Text('Search not implemented in this demo'),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text('Type to search for residents, committee, or groups'),
    );
  }
}

class _CallsHistoryTab extends StatefulWidget {
  const _CallsHistoryTab();

  @override
  State<_CallsHistoryTab> createState() => _CallsHistoryTabState();
}

class _CallsHistoryTabState extends State<_CallsHistoryTab> {
  final CallHistoryService _historyService = CallHistoryService.instance;
  late final Future<void> _initialLoad;

  @override
  void initState() {
    super.initState();
    _initialLoad = _historyService.ensureInitialized();
  }

  Future<void> _refresh() => _historyService.reload();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialLoad,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        return ValueListenableBuilder<List<CallHistoryEntry>>(
          valueListenable: _historyService.historyListenable,
          builder: (context, entries, child) {
            if (entries.isEmpty) {
              return const _CallsEmptyState();
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                itemCount: entries.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0x1A000000),
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _CallHistoryItem(entry: entry);
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _CallsEmptyState extends StatelessWidget {
  const _CallsEmptyState();

  @override
  Widget build(BuildContext context) {
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
                Icons.call_outlined,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No call history',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your call history will appear here',
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

class _CallHistoryItem extends StatelessWidget {
  final CallHistoryEntry entry;

  const _CallHistoryItem({
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final status = entry.status;

    // Treat "Calling" (initiated but never connected) as a Missed call in UI.
    final showAsMissed =
        status == CallStatus.missed || status == CallStatus.initiated;
    final isDeclined = status == CallStatus.declined;

    final callTypeLabel = entry.callType.displayName;
    final statusLabel =
        showAsMissed ? 'Missed' : status.displayName;

    // Icon: use missed icons for missed/declined, arrows otherwise.
    final IconData statusIcon;
    if (showAsMissed || isDeclined) {
      statusIcon = entry.isOutgoing
          ? Icons.call_missed_outgoing
          : Icons.call_missed;
    } else {
      statusIcon =
          entry.isOutgoing ? Icons.call_made : Icons.call_received;
    }
    final Color statusIconColor =
        (showAsMissed || isDeclined) ? Colors.red : AppColors.success;

    // Build styled preview text: call type (grey) · status (colored) · duration (grey).
    final baseStyle = TextStyle(color: Colors.grey.shade600);
    final TextStyle statusStyle;
    if (showAsMissed) {
      // Missed (including former "Calling") → blue label
      statusStyle = baseStyle.copyWith(color: Colors.blue);
    } else if (status == CallStatus.ended) {
      // Ended → green label
      statusStyle = baseStyle.copyWith(color: AppColors.success);
    } else if (status == CallStatus.declined) {
      // Declined → red label
      statusStyle = baseStyle.copyWith(color: Colors.red);
    } else {
      statusStyle = baseStyle;
    }

    final spans = <InlineSpan>[
      TextSpan(text: callTypeLabel, style: baseStyle),
      const TextSpan(text: ' · ', style: TextStyle()),
      TextSpan(text: statusLabel, style: statusStyle),
    ];
    // Do not show duration for Missed/Declined calls.
    if (entry.duration != null && !showAsMissed && !isDeclined) {
      spans.add(
        TextSpan(
          text: ' · ${_formatDuration(entry.duration!)}',
          style: baseStyle,
        ),
      );
    }

    final timeText = DateFormat('jm').format(_toIndiaTime(entry.initiatedAt));
    final avatarUrl = _normalizeAvatarUrl(entry.contactAvatar);
    final dateTimeText = '${_formatIndiaDate(entry.initiatedAt)} · $timeText';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.1),
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        onBackgroundImageError: avatarUrl != null
            ? (exception, stackTrace) {
                // Fallback to icon if image fails to load
              }
            : null,
        child: avatarUrl != null
            ? null
            : Icon(
                Icons.person,
                color: AppColors.primary,
              ),
      ),
      title: Text(
        entry.contactName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                statusIcon,
                size: 14,
                color: statusIconColor,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text.rich(
                  TextSpan(children: spans),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dateTimeText,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      onTap: () {
        // Optional: handle tap on call history item
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes == 0 && seconds == 0) {
      return '0s';
    }

    if (minutes == 0) {
      return '${seconds}s';
    }

    if (seconds == 0) {
      return '${minutes}m';
    }

    return '${minutes}m ${seconds}s';
  }

  DateTime _toIndiaTime(DateTime dateTime) {
    final utcTime = dateTime.isUtc ? dateTime : dateTime.toUtc();
    return utcTime.add(const Duration(hours: 5, minutes: 30));
  }

  String _formatIndiaDate(DateTime dateTime) {
    final indiaTime = _toIndiaTime(dateTime);
    return DateFormat('dd MMM, yyyy').format(indiaTime);
  }
}

/// Data class for chat history items
class _ChatHistoryData {
  final String roomId;
  final String contactName;
  final String contactId;
  final String? contactAvatar; // Avatar URL for the contact
  final String lastMessage;
  final String time;
  final DateTime lastActive;
  final int unreadCount;

  _ChatHistoryData({
    required this.roomId,
    required this.contactName,
    required this.contactId,
    this.contactAvatar, // Optional avatar
    required this.lastMessage,
    required this.time,
    required this.lastActive,
    this.unreadCount = 0,
  });
}

/// Result class for parallel room processing
class _RoomProcessingResult {
  final _ChatHistoryData? chatData;
  final String? error;

  _RoomProcessingResult({this.chatData, this.error});
}

/// Widget to display 1-to-1 chat history
class _ChatHistoryTab extends StatefulWidget {
  final ScrollController scrollController;

  const _ChatHistoryTab({
    required this.scrollController,
  });

  @override
  State<_ChatHistoryTab> createState() => _ChatHistoryTabState();
}

class _ChatHistoryTabState extends State<_ChatHistoryTab> {
  final ChatService _chatService = ChatService.instance;
  final RoomService _roomService = RoomService.instance;
  final ApiService _apiService = ApiService.instance;
  final UnreadCountManager _unreadManager = UnreadCountManager.instance;

  List<_ChatHistoryData> _chatHistory = [];
  bool _isLoading = true;
  String? _currentUserId;
  int? _companyId;
  final Map<String, Room> _roomsById = {};
  final Set<String> _roomInfoPrefetchRequested = {};
  bool _isLoaderDialogShown = false;
  Set<String> _openedChats = {}; // Track which chats have been opened

  // WebSocket state
  StreamSubscription<WebSocketMessage>? _wsMessageSubscription;
  StreamSubscription<bool>? _wsConnectionSubscription;
  bool _isWebSocketConnected = false;

  // PERFORMANCE OPTIMIZATION: Caching and request management
  final Map<String, RoomInfo> _roomInfoCache = {}; // Cache room info by room ID
  final Set<String> _pendingRoomInfoRequests =
      {}; // Track rooms being fetched to prevent duplicates
  final Map<String, DateTime> _roomInfoCacheTimestamps = {}; // Track cache age
  static const Duration _roomInfoCacheTTL =
      Duration(minutes: 5); // Cache validity: 5 minutes
  static const int _maxConcurrentRequests = 5; // Maximum concurrent API calls
  DateTime? _lastRateLimitError; // Track last 429 error time
  static const Duration _rateLimitBackoff =
      Duration(minutes: 2); // Backoff after 429 error

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadOpenedChats();
    // PERFORMANCE OPTIMIZATION: Show UI immediately, load data asynchronously
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLoading = false; // Show UI immediately
        });
      }
    });
    _loadChatHistory(); // Load data in background
    _setupWebSocketListeners();
  }

  @override
  void dispose() {
    _wsMessageSubscription?.cancel();
    _wsConnectionSubscription?.cancel();
    super.dispose();
  }

  /// Setup WebSocket listeners for real-time updates
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

  /// Handle incoming WebSocket messages - update chat history with real-time data
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
            '📊 [ChatHistoryTab] Received unread_count_update: room=$updateRoomId, user=$userId, count=$unreadCount');

        // Update local unread count manager if this is for current user
        if (userId == _currentUserId) {
          if (unreadCount == 0) {
            await _unreadManager.clearUnreadCount(updateRoomId);
          } else {
            // Backend is source of truth - update local cache with exact count
            await _unreadManager.setUnreadCount(updateRoomId, unreadCount);
            developer.log(
                '📊 [ChatHistoryTab] Unread count updated to $unreadCount for room $updateRoomId');
          }

          // Update chat history UI with new unread count
          _updateChatHistoryFromWebSocket(updateRoomId);
        }
      }
      return; // Don't process unread_count_update as messages
    }

    developer.log(
        '📨 [ChatHistoryTab] Received WebSocket message for room: $roomId');

    // Check if this message is from current user
    final isFromCurrentUser = wsMessage.userId == _currentUserId;

    // Check if this is a system message (should not increment unread count)
    final isSystemMessage = _isSystemMessageFromWebSocket(wsMessage);

    // Build a preview for any activity (message/reply/reaction/attachment)
    final activityPreview = _buildActivityPreview(wsMessage);
    await _unreadManager.updateLastMessage(
      roomId,
      activityPreview,
      DateTime.now(),
    );

    // Backend is source of truth for unread counts (DB + unread_count_update).
    // Only clear "opened" flag so indicator can reappear; count is applied via unread_count_update.
    if (!isFromCurrentUser && !isSystemMessage) {
      await _clearChatOpenedFlag(roomId);
    }

    // Update chat history item
    _updateChatHistoryFromWebSocket(roomId);
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
    final msgContent =
        wsMessage.content ?? wsMessage.data?['content']?.toString() ?? '';
    final msgContentLower = msgContent.toLowerCase();
    if (msgContentLower.contains('joined the group') ||
        msgContentLower.contains('left the group') ||
        msgContentLower.contains('was deleted') ||
        (msgContentLower.contains('added') &&
            msgContentLower.contains('to the group')) ||
        (msgContentLower.contains('removed') &&
            msgContentLower.contains('from the group'))) {
      return true;
    }

    return false;
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

  /// Update a chat history item based on WebSocket message
  void _updateChatHistoryFromWebSocket(String roomId) {
    if (!mounted) return;

    final chatIndex = _chatHistory.indexWhere((chat) => chat.roomId == roomId);
    if (chatIndex == -1) return; // Chat not in history

    final unreadCount = _unreadManager.getUnreadCount(roomId);
    final lastMessage = _unreadManager.getLastMessage(roomId);
    final lastMessageTime =
        _unreadManager.getLastMessageTime(roomId) ?? DateTime.now();
    final isOpened = _openedChats.contains(roomId);

    // Update chat history item
    final updatedChat = _ChatHistoryData(
      roomId: _chatHistory[chatIndex].roomId,
      contactName: _chatHistory[chatIndex].contactName,
      contactId: _chatHistory[chatIndex].contactId,
      contactAvatar: _chatHistory[chatIndex].contactAvatar,
      lastMessage: lastMessage ?? _chatHistory[chatIndex].lastMessage,
      time: _formatTime(lastMessageTime),
      lastActive: lastMessageTime,
      unreadCount: isOpened ? 0 : unreadCount, // Hide unread count if opened
    );

    setState(() {
      _chatHistory[chatIndex] = updatedChat;
      // Sort by last active time (most recent first)
      _chatHistory.sort((a, b) => b.lastActive.compareTo(a.lastActive));
    });

    developer.log(
        '✅ [ChatHistoryTab] Updated chat history for room $roomId: unread=$unreadCount');
  }

  /// Load the set of opened chat room IDs from SharedPreferences
  Future<void> _loadOpenedChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final openedChatsList = prefs.getStringList('opened_chat_rooms') ?? [];
      setState(() {
        _openedChats = openedChatsList.toSet();
      });
      developer
          .log('✅ [ChatHistoryTab] Loaded ${_openedChats.length} opened chats');
    } catch (e) {
      developer.log('⚠️ [ChatHistoryTab] Error loading opened chats: $e');
    }
  }

  /// Mark a chat as opened and save to SharedPreferences
  Future<void> _markChatAsOpened(String roomId) async {
    try {
      // CRITICAL FIX: Update the chat's unreadCount to 0 immediately
      // This ensures the indicator is cleared on first open, not after multiple opens
      final chatIndex = _chatHistory.indexWhere((c) => c.roomId == roomId);
      if (chatIndex != -1 && _chatHistory[chatIndex].unreadCount > 0) {
        setState(() {
          _openedChats.add(roomId);
          // Create updated chat with unreadCount = 0
          _chatHistory[chatIndex] = _ChatHistoryData(
            roomId: _chatHistory[chatIndex].roomId,
            contactName: _chatHistory[chatIndex].contactName,
            contactId: _chatHistory[chatIndex].contactId,
            contactAvatar: _chatHistory[chatIndex].contactAvatar,
            lastMessage: _chatHistory[chatIndex].lastMessage,
            time: _chatHistory[chatIndex].time,
            lastActive: _chatHistory[chatIndex].lastActive,
            unreadCount: 0, // Clear unread count immediately
          );
        });
        developer.log(
            '✅ [ChatHistoryTab] Cleared unreadCount for chat $roomId on open');
      } else if (!_openedChats.contains(roomId)) {
        // Just add to opened set if not already there
        setState(() {
          _openedChats.add(roomId);
        });
      }

      // Also clear in UnreadCountManager to keep in sync
      await _unreadManager.clearUnreadCount(roomId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('opened_chat_rooms', _openedChats.toList());
      developer.log('✅ [ChatHistoryTab] Marked chat $roomId as opened');
    } catch (e) {
      developer.log('⚠️ [ChatHistoryTab] Error marking chat as opened: $e');
    }
  }

  /// Remove the opened flag when a new message arrives so indicators reappear
  Future<void> _clearChatOpenedFlag(String roomId) async {
    if (!_openedChats.contains(roomId)) {
      return;
    }

    final removed = _openedChats.remove(roomId);
    if (!removed) {
      return;
    }

    if (mounted) {
      setState(() {});
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('opened_chat_rooms', _openedChats.toList());
      developer.log('ℹ️ [ChatHistoryTab] Cleared opened flag for chat $roomId');
    } catch (e) {
      developer.log(
          '⚠️ [ChatHistoryTab] Error clearing opened flag for chat $roomId: $e');
    }
  }

  /// DEPRECATED: Process a single room for chat history
  /// This method is no longer used - replaced by _loadRoomInfoForChat for better performance
  /// Kept for backward compatibility but not called in optimized flow
  @Deprecated('Use _loadRoomInfoForChat instead for better performance')
  Future<_RoomProcessingResult> _processRoomForHistory({
    required Room room,
    required int companyId,
  }) async {
    try {
      // Fetch room info with reduced timeout for faster failure
      final roomInfoResponse = await _roomService
          .getRoomInfo(
        roomId: room.id,
        companyId: companyId,
      )
          .timeout(
        const Duration(seconds: 8), // Reduced timeout for faster failure
        onTimeout: () {
          developer.log(
              '⏱️ [ChatHistoryTab] Timeout fetching room info for ${room.id}');
          return ApiResponse.error('Request timeout', statusCode: 408);
        },
      );

      if (!roomInfoResponse.success || roomInfoResponse.data == null) {
        developer.log(
            '⚠️ [ChatHistoryTab] Failed to get room info for ${room.id}: ${roomInfoResponse.error}');
        // Use basic room data as fallback
        return _RoomProcessingResult(
          chatData: _ChatHistoryData(
            roomId: room.id,
            contactName: room.name,
            contactId: room.createdBy,
            lastMessage: 'No messages yet',
            time: _formatTime(room.lastActive ?? room.updatedAt),
            lastActive: room.lastActive ?? room.updatedAt,
            unreadCount: 0,
          ),
        );
      }

      final roomInfo = roomInfoResponse.data!;

      // For 1-to-1: prefer backend peer_user (source of truth), else derive from members
      String? otherMemberName;
      String? otherMemberId;
      String? otherMemberAvatar;

      if (roomInfo.peerUser != null) {
        otherMemberName = roomInfo.peerUser!.userName?.trim().isNotEmpty == true
            ? roomInfo.peerUser!.userName
            : 'Unknown User';
        otherMemberId = roomInfo.peerUser!.userId != null
            ? roomInfo.peerUser!.userId.toString()
            : null;
        otherMemberAvatar = roomInfo.peerUser!.avatar?.trim().isNotEmpty == true
            ? roomInfo.peerUser!.avatar
            : null;
      }
      if (otherMemberName == null || otherMemberId == null) {
        if (_currentUserId != null) {
          try {
            final otherMember = roomInfo.members.firstWhere(
              (m) => !m.isCurrentUser(_currentUserId),
              orElse: () => roomInfo.members.first,
            );
            otherMemberName = otherMember.username ?? 'Unknown User';
            otherMemberId = otherMember.userId;
            otherMemberAvatar = otherMember.avatar;
          } catch (e) {
            if (roomInfo.members.isNotEmpty) {
              otherMemberName =
                  roomInfo.members.first.username ?? 'Unknown User';
              otherMemberId = roomInfo.members.first.userId;
              otherMemberAvatar = roomInfo.members.first.avatar;
            }
          }
        } else if (roomInfo.members.isNotEmpty) {
          otherMemberName = roomInfo.members.first.username ?? 'Unknown User';
          otherMemberId = roomInfo.members.first.userId;
          otherMemberAvatar = roomInfo.members.first.avatar;
        }
      }

      if (otherMemberName != null && otherMemberId != null) {
        // PERFORMANCE OPTIMIZATION: Do NOT fetch messages here
        // Messages will be loaded when user opens the chat
        // Use cached last message from UnreadCountManager or placeholder
        final lastMessage =
            _unreadManager.getLastMessage(room.id) ?? 'Tap to open chat';
        final lastMessageTime = _unreadManager.getLastMessageTime(room.id) ??
            (roomInfo.lastActive ?? room.updatedAt);
        final unreadCount = _unreadManager.getUnreadCount(room.id);
        final timeStr = _formatTime(lastMessageTime);

        return _RoomProcessingResult(
          chatData: _ChatHistoryData(
            roomId: room.id,
            contactName: otherMemberName,
            contactId: otherMemberId,
            contactAvatar: otherMemberAvatar,
            lastMessage: lastMessage,
            time: timeStr,
            lastActive: lastMessageTime,
            unreadCount: unreadCount,
          ),
        );
      } else {
        return _RoomProcessingResult(
          error: 'Could not determine other member',
        );
      }
    } catch (e, stackTrace) {
      developer.log('❌ [ChatHistoryTab] Error processing room ${room.id}: $e');
      developer.log('   Stack trace: $stackTrace');
      return _RoomProcessingResult(
        error: e.toString(),
      );
    }
  }

  /// Check if a message is a system message (like "joined the group")
  /// For 1-to-1 chats, we filter these out from chat history
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

  Future<void> _loadCurrentUserId() async {
    try {
      final accessToken = await KeycloakService.getAccessToken();
      if (accessToken != null) {
        // Decode token to get UUID (sub field)
        final decodedToken = JwtDecoder.decode(accessToken);
        final sub = decodedToken['sub'];
        if (sub != null && sub.toString().trim().isNotEmpty) {
          setState(() {
            _currentUserId = sub.toString();
          });
        }
      }
    } catch (e) {
      developer.log('Error loading current user ID: $e');
    }
  }

  void _maybePrefetchRoomInfoForChat(_ChatHistoryData chat, int index) {
    // Keep this extremely conservative to avoid API storms and 429s.
    if (_companyId == null) return;
    if (index >= 8) return; // only prefetch first few visible chats
    if (_lastRateLimitError != null &&
        DateTime.now().difference(_lastRateLimitError!) < _rateLimitBackoff) {
      return;
    }
    if (chat.contactAvatar != null && chat.contactAvatar!.trim().isNotEmpty) {
      return;
    }
    if (_roomInfoPrefetchRequested.contains(chat.roomId)) return;

    final room = _roomsById[chat.roomId];
    if (room == null) return;

    _roomInfoPrefetchRequested.add(chat.roomId);
    Future.microtask(() => _loadRoomInfoForChat(room, _companyId!));
  }

  Future<void> _loadChatHistory() async {
    // PERFORMANCE OPTIMIZATION: Don't block UI - show list immediately
    // Data will be loaded incrementally in background

    try {
      // PERFORMANCE OPTIMIZATION: Check rate limit backoff
      if (_lastRateLimitError != null) {
        final timeSinceRateLimit =
            DateTime.now().difference(_lastRateLimitError!);
        if (timeSinceRateLimit < _rateLimitBackoff) {
          developer.log(
              '⏸️ [ChatHistoryTab] Skipping load - rate limit backoff active (${_rateLimitBackoff.inMinutes - timeSinceRateLimit.inMinutes}min remaining)');
          return;
        }
      }

      final companyId = await _apiService.getSelectedSocietyId();
      if (companyId == null) {
        developer.log(
            '❌ [ChatHistoryTab] Company ID is null, cannot load chat history');
        return;
      }
      _companyId = companyId;

      developer.log(
          '📡 [ChatHistoryTab] Fetching 1-to-1 chats for company_id: $companyId');

      // Fetch 1-to-1 chats using chat_type=1-1 filter
      final roomsResponse = await _chatService.fetchRooms(
        companyId: companyId,
        chatType: '1-1',
      );

      if (!mounted) {
        developer
            .log('⚠️ [ChatHistoryTab] Widget not mounted, cancelling load');
        return;
      }

      if (!roomsResponse.success) {
        developer.log(
            '❌ [ChatHistoryTab] Failed to fetch rooms: ${roomsResponse.error}');
        // Don't show error - UI is already visible with empty state
        return;
      }

      if (roomsResponse.data == null || roomsResponse.data!.isEmpty) {
        developer.log('ℹ️ [ChatHistoryTab] No rooms found');
        if (mounted) {
          setState(() {
            _chatHistory = [];
          });
        }
        return;
      }

      final rooms = roomsResponse.data!;
      _roomsById
        ..clear()
        ..addEntries(rooms.map((r) => MapEntry(r.id, r)));
      developer.log('✅ [ChatHistoryTab] Fetched ${rooms.length} 1-to-1 chats');

      if (!mounted) return;

      // PERFORMANCE OPTIMIZATION: Show UI immediately with basic room data
      // Use room name and last active from fetchRooms response (no API calls needed)
      // CRITICAL: Seed UnreadCountManager from API unread_count so User B sees "5 new messages" on login
      for (final room in rooms) {
        if (room.unreadCount != null && room.unreadCount! > 0) {
          await _unreadManager.setUnreadCount(room.id, room.unreadCount!);
          developer.log(
              '📥 [ChatHistoryTab] Seeded unread count from API for room ${room.id}: ${room.unreadCount}');
          // If backend says there are unread messages, ensure this chat is not treated as "opened"
          if (_openedChats.remove(room.id)) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setStringList(
                'opened_chat_rooms', _openedChats.toList());
          }
        }
      }

      final initialChats = rooms.map((room) {
        // Use UnreadCountManager (now seeded from API on load) for unread count
        final lastMessage = _unreadManager.getLastMessage(room.id);
        final lastMessageTime = _unreadManager.getLastMessageTime(room.id) ??
            (room.lastActive ?? room.updatedAt);
        final unreadCount = _unreadManager.getUnreadCount(room.id);
        // A chat is considered "opened" only when backend says there are NO unread messages
        final isOpened = unreadCount == 0 && _openedChats.contains(room.id);

        // For 1-to-1: use backend peer_user when available (source of truth)
        final String contactName = (room.peerUser?.userName != null &&
                room.peerUser!.userName!.trim().isNotEmpty)
            ? room.peerUser!.userName!
            : room.name;
        final String contactId = room.peerUser?.userId != null
            ? room.peerUser!.userId.toString()
            : room.createdBy;
        final String? contactAvatar = (room.peerUser?.avatar != null &&
                room.peerUser!.avatar!.trim().isNotEmpty)
            ? room.peerUser!.avatar
            : null;

        return _ChatHistoryData(
          roomId: room.id,
          contactName: contactName,
          contactId: contactId,
          contactAvatar: contactAvatar,
          lastMessage: lastMessage ??
              'Tap to open chat', // Placeholder, no messages API call
          time: _formatTime(lastMessageTime),
          lastActive: lastMessageTime,
          unreadCount: isOpened ? 0 : unreadCount,
        );
      }).toList();

      // Sort by last active time (most recent first)
      initialChats.sort((a, b) => b.lastActive.compareTo(a.lastActive));

      if (mounted) {
        setState(() {
          _chatHistory = initialChats;
        });
        developer.log(
            '✅ [ChatHistoryTab] UI rendered immediately with ${initialChats.length} chats');
      }

      // CRITICAL FIX: Do NOT fetch room info for every room on tab load
      // This causes API storms and 429 errors during rapid tab switching
      // Room info will be loaded lazily:
      // - When list item becomes visible (viewport-based lazy load)
      // - When user opens that chat
      // - Only for first few visible items (if needed for preview)
      //
      // REMOVED: _loadRoomInfoInBatches(rooms, companyId);
      // This prevents the API storm that causes 429 errors
      developer.log(
          '✅ [ChatHistoryTab] Room list rendered - room info will load lazily (on-demand)');
    } catch (e, stackTrace) {
      developer.log('❌ [ChatHistoryTab] Error loading chat history: $e');
      developer.log('   Stack trace: $stackTrace');
      // Don't show error state - UI is already visible
    }
  }

  /// Load room info in batches to avoid rate limiting
  /// PERFORMANCE OPTIMIZATION: Process max 5 rooms concurrently, then wait before next batch
  Future<void> _loadRoomInfoInBatches(List<Room> rooms, int companyId) async {
    if (!mounted) return;

    // Filter out rooms that are already cached and still valid
    final roomsNeedingInfo = rooms.where((room) {
      final cached = _roomInfoCache[room.id];
      if (cached == null) return true; // Not cached

      final cacheTime = _roomInfoCacheTimestamps[room.id];
      if (cacheTime == null) return true; // No timestamp, need to refresh

      final cacheAge = DateTime.now().difference(cacheTime);
      return cacheAge > _roomInfoCacheTTL; // Cache expired
    }).toList();

    if (roomsNeedingInfo.isEmpty) {
      developer.log(
          '✅ [ChatHistoryTab] All rooms already cached, skipping room info fetch');
      return;
    }

    developer.log(
        '🔄 [ChatHistoryTab] Loading room info for ${roomsNeedingInfo.length} rooms in batches (max $_maxConcurrentRequests concurrent)');

    // Process rooms in batches
    for (int i = 0; i < roomsNeedingInfo.length; i += _maxConcurrentRequests) {
      if (!mounted) break; // Stop if widget disposed

      final batch =
          roomsNeedingInfo.skip(i).take(_maxConcurrentRequests).toList();
      developer.log(
          '📦 [ChatHistoryTab] Processing batch ${(i ~/ _maxConcurrentRequests) + 1}: ${batch.length} rooms');

      // Process batch in parallel (max 5 concurrent)
      final batchFutures =
          batch.map((room) => _loadRoomInfoForChat(room, companyId)).toList();

      try {
        await Future.wait(batchFutures);
      } catch (e) {
        developer.log('⚠️ [ChatHistoryTab] Error in batch processing: $e');
      }

      // PERFORMANCE OPTIMIZATION: Small delay between batches to avoid rate limits
      if (i + _maxConcurrentRequests < roomsNeedingInfo.length) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    developer.log('✅ [ChatHistoryTab] Batch room info loading complete');
  }

  /// Load room info for a single chat and update UI incrementally
  /// PERFORMANCE OPTIMIZATION: Skip if cached, handle 429 errors, no messages API call
  Future<void> _loadRoomInfoForChat(Room room, int companyId) async {
    // Skip if already being fetched (deduplication)
    if (_pendingRoomInfoRequests.contains(room.id)) {
      developer.log(
          '⏭️ [ChatHistoryTab] Room info already being fetched for ${room.id}, skipping');
      return;
    }

    // Check cache first
    final cached = _roomInfoCache[room.id];
    final cacheTime = _roomInfoCacheTimestamps[room.id];
    if (cached != null && cacheTime != null) {
      final cacheAge = DateTime.now().difference(cacheTime);
      if (cacheAge <= _roomInfoCacheTTL) {
        // Use cached data
        _updateChatHistoryFromRoomInfo(room, cached, companyId);
        return;
      }
    }

    _pendingRoomInfoRequests.add(room.id);

    try {
      // Fetch room info with timeout
      final roomInfoResponse = await _roomService
          .getRoomInfo(roomId: room.id, companyId: companyId)
          .timeout(
        const Duration(seconds: 5), // Reduced timeout - fail fast
        onTimeout: () {
          developer.log(
              '⏱️ [ChatHistoryTab] Timeout fetching room info for ${room.id}');
          return ApiResponse.error('Request timeout', statusCode: 408);
        },
      );

      _pendingRoomInfoRequests.remove(room.id);

      // Handle 429 rate limit errors
      if (roomInfoResponse.statusCode == 429) {
        developer.log(
            '⚠️ [ChatHistoryTab] Rate limit (429) for room ${room.id}, stopping batch processing');
        _lastRateLimitError = DateTime.now();
        // Don't retry - stop batch processing
        return;
      }

      if (!roomInfoResponse.success || roomInfoResponse.data == null) {
        developer.log(
            '⚠️ [ChatHistoryTab] Failed to get room info for ${room.id}: ${roomInfoResponse.error}');
        // Use basic room data (already shown in UI)
        return;
      }

      final roomInfo = roomInfoResponse.data!;

      // Cache room info
      _roomInfoCache[room.id] = roomInfo;
      _roomInfoCacheTimestamps[room.id] = DateTime.now();

      if (!mounted) return;

      // Update chat history with room info (name, avatar) - NO MESSAGES API CALL
      _updateChatHistoryFromRoomInfo(room, roomInfo, companyId);
    } catch (e) {
      _pendingRoomInfoRequests.remove(room.id);
      developer
          .log('❌ [ChatHistoryTab] Error loading room info for ${room.id}: $e');
      // Continue with basic room data (already shown)
    }
  }

  /// Update chat history item with room info (name, avatar)
  /// PERFORMANCE OPTIMIZATION: No messages API call - use cached last message or placeholder
  void _updateChatHistoryFromRoomInfo(
      Room room, RoomInfo roomInfo, int companyId) {
    if (!mounted) return;

    // For 1-to-1: prefer backend peer_user (source of truth), else derive from members
    String? otherMemberName;
    String? otherMemberId;
    String? otherMemberAvatar;

    if (roomInfo.peerUser != null) {
      otherMemberName = roomInfo.peerUser!.userName?.trim().isNotEmpty == true
          ? roomInfo.peerUser!.userName
          : room.name;
      otherMemberId = roomInfo.peerUser!.userId != null
          ? roomInfo.peerUser!.userId.toString()
          : null;
      otherMemberAvatar = roomInfo.peerUser!.avatar?.trim().isNotEmpty == true
          ? roomInfo.peerUser!.avatar
          : null;
    }
    if (otherMemberName == null || otherMemberId == null) {
      if (_currentUserId != null) {
        try {
          final otherMember = roomInfo.members.firstWhere(
            (m) => !m.isCurrentUser(_currentUserId),
            orElse: () => roomInfo.members.first,
          );
          otherMemberName = otherMember.username ?? room.name;
          otherMemberId = otherMember.userId;
          otherMemberAvatar = otherMember.avatar;
        } catch (e) {
          if (roomInfo.members.isNotEmpty) {
            otherMemberName = roomInfo.members.first.username ?? room.name;
            otherMemberId = roomInfo.members.first.userId;
            otherMemberAvatar = roomInfo.members.first.avatar;
          }
        }
      } else if (roomInfo.members.isNotEmpty) {
        otherMemberName = roomInfo.members.first.username ?? room.name;
        otherMemberId = roomInfo.members.first.userId;
        otherMemberAvatar = roomInfo.members.first.avatar;
      }
    }

    if (otherMemberName == null || otherMemberId == null) {
      return;
    }

    // PERFORMANCE OPTIMIZATION: Use cached last message from UnreadCountManager
    // Do NOT call messages API - that will be done when user opens the chat
    final lastMessage = _unreadManager.getLastMessage(room.id);
    final lastMessageTime = _unreadManager.getLastMessageTime(room.id) ??
        (roomInfo.lastActive ?? room.updatedAt);
    final unreadCount = _unreadManager.getUnreadCount(room.id);
    final isOpened = _openedChats.contains(room.id);

    final updatedChat = _ChatHistoryData(
      roomId: room.id,
      contactName: otherMemberName,
      contactId: otherMemberId,
      contactAvatar: otherMemberAvatar, // Now includes avatar from room info
      lastMessage:
          lastMessage ?? 'Tap to open chat', // Use cached or placeholder
      time: _formatTime(lastMessageTime),
      lastActive: lastMessageTime,
      unreadCount: isOpened ? 0 : unreadCount,
    );

    // Update existing chat history item or add new one
    final chatIndex = _chatHistory.indexWhere((chat) => chat.roomId == room.id);
    if (chatIndex != -1) {
      setState(() {
        _chatHistory[chatIndex] = updatedChat;
        // Re-sort by last active time
        _chatHistory.sort((a, b) => b.lastActive.compareTo(a.lastActive));
      });
      developer.log(
          '✅ [ChatHistoryTab] Updated chat history for room ${room.id} with room info');
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

  /// Build empty state for chat tab (same UI as committee tab)
  Widget _buildChatEmptyState() {
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
              'No chat history',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your chat conversations will appear here',
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

  /// Convert UTC DateTime to Indian Standard Time (IST - UTC+5:30)
  DateTime _toIST(DateTime dateTime) {
    // If the DateTime is already in UTC (has isUtc flag), convert to IST
    // Otherwise, assume it's UTC and convert to IST
    final utcDateTime = dateTime.isUtc ? dateTime : dateTime.toUtc();
    // IST is UTC+5:30
    return utcDateTime.add(const Duration(hours: 5, minutes: 30));
  }

  String _formatTime(DateTime dateTime) {
    // Convert to IST before formatting
    final istTime = _toIST(dateTime);
    final now = DateTime.now();
    final istNow = _toIST(now.toUtc());
    final difference = istNow.difference(istTime);

    if (difference.inDays == 0) {
      // Today - show time
      return DateFormat('h:mm a').format(istTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d').format(istTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE OPTIMIZATION: Don't show loading spinner - UI is visible immediately
    // Show empty state only if no rooms found after initial load
    if (_chatHistory.isEmpty && !_isLoading) {
      return _buildChatEmptyState();
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(top: 8),
      itemCount: _chatHistory.length,
      itemBuilder: (context, index) {
        final chat = _chatHistory[index];
        _maybePrefetchRoomInfoForChat(chat, index);
        final contact = IntercomContact(
          id: chat.contactId,
          name: chat.contactName,
          type: IntercomContactType.resident,
          status: IntercomContactStatus.offline,
          photoUrl: chat.contactAvatar, // Use avatar from chat history
        );
        // Derive opened state from both backend unread count and local flag:
        // if unreadCount > 0, always treat as NOT opened so indicator shows.
        final isOpened =
            chat.unreadCount == 0 && _openedChats.contains(chat.roomId);
        return _ChatHistoryItem(
          name: chat.contactName,
          role: '', // Can be enhanced with apartment number if available
          message: chat.lastMessage,
          time: chat.time,
          unreadCount:
              isOpened ? 0 : chat.unreadCount, // Hide unread count if opened
          contact: contact, // Pass contact for avatar display
          isOpened: isOpened, // Pass opened status
          onTap: () {
            // Mark chat as opened when user taps on it
            _markChatAsOpened(chat.roomId);

            // Navigate to chat screen with roomId to restore chat
            // This will call the messages API to restore chat history
            Navigator.pop(context); // Close the history modal first
            NavigationHelper.pushRoute(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  contact: contact,
                  roomId: chat.roomId, // Pass roomId to restore chat directly
                  returnToHistory:
                      true, // Navigate back to history page on back button
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChatHistoryItem extends StatelessWidget {
  final String name;
  final String role;
  final String message;
  final String time;
  final int unreadCount;
  final bool isOpened; // Whether this chat has been opened before
  final VoidCallback? onTap;
  final IntercomContact? contact; // Add contact parameter for avatar

  const _ChatHistoryItem({
    required this.name,
    required this.role,
    required this.message,
    required this.time,
    required this.unreadCount,
    this.isOpened = false, // Default to false (not opened)
    this.onTap,
    this.contact, // Optional contact for avatar
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _normalizeAvatarUrl(contact?.photoUrl);
    final preview = ActivityPreviewHelper.fromStored(message);
    final baseMessage = preview.text.isEmpty ? 'No messages yet' : preview.text;
    // If chat has been opened before, always show last message (no count, no badge, no indicator)
    // If chat hasn't been opened, show count/new messages with badge and indicator (green, like group chat)
    String displayMessage = baseMessage;
    bool showIndicator = false;
    bool showBadge = false;
    bool useMessagePreview = false;
    const Color unreadAccent =
        AppColors.success; // Green badge/indicator like group chat

    if (isOpened) {
      // Chat has been opened: show last message only, no count, no badge, no indicator
      displayMessage = baseMessage;
      showIndicator = false;
      showBadge = false;
      useMessagePreview = true;
    } else {
      // Chat hasn't been opened: show count/new messages with badge and indicator
      if (unreadCount > 1) {
        // More than 1 message from receiver: show count with "new messages"
        displayMessage = '$unreadCount new messages';
        showIndicator = true;
        showBadge = true;
      } else if (unreadCount == 1) {
        // Exactly 1 message from receiver: show first 10 characters or "New message"
        if (baseMessage.isNotEmpty && baseMessage != 'No messages yet') {
          displayMessage = baseMessage.length > 10
              ? '${baseMessage.substring(0, 10)}...'
              : baseMessage;
        } else {
          displayMessage = 'New message';
        }
        showIndicator = true;
        showBadge = true;
        useMessagePreview = true;
      } else {
        // No unread messages: show last message (may be from sender)
        displayMessage = baseMessage;
        showIndicator = false;
        showBadge = false;
        useMessagePreview = true;
      }
    }

    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            onBackgroundImageError:
                avatarUrl != null
                    ? (exception, stackTrace) {
                        // Fallback to icon if image fails to load
                      }
                    : null,
            child: avatarUrl == null
                ? Icon(
                    Icons.person,
                    color: AppColors.primary,
                  )
                : null,
          ),
          title: Text(
              name), // Receiver name as title (so user can identify whose chat it is)
          subtitle: Row(
            children: [
              if (useMessagePreview && preview.hasIcon) ...[
                Icon(
                  preview.icon,
                  size: 16,
                  color: showIndicator ? unreadAccent : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  displayMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: showIndicator ? unreadAccent : Colors.grey.shade600,
                    fontWeight:
                        showIndicator ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (showIndicator) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: unreadAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: TextStyle(
                  color: showIndicator ? unreadAccent : Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight:
                      showIndicator ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (showBadge && unreadCount > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: unreadAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
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
          onTap: onTap,
        ),
        // Divider with 0.1 opacity
        Divider(
          height: 1,
          thickness: 1,
          color: Colors.grey.withValues(alpha: 0.1),
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }
}
