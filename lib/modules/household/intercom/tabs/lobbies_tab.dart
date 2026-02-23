import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_loader.dart';
import '../models/intercom_contact.dart';
import '../chat_screen.dart';
import '../widgets/voice_search_screen.dart';
import '../services/intercom_service.dart';
import '../../providers/selected_flat_provider.dart';

import '../../../../core/widgets/enhanced_toast.dart';
import '../../../../core/utils/navigation_helper.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../services/chat_service.dart';
import '../services/chat_websocket_service.dart';
import '../services/unread_count_manager.dart';
import '../utils/activity_preview_helper.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/keycloak_service.dart';
import '../widgets/call_bottom_sheet.dart';

class LobbiesTab extends ConsumerStatefulWidget {
  const LobbiesTab({Key? key}) : super(key: key);

  @override
  ConsumerState<LobbiesTab> createState() => _LobbiesTabState();
}

class _LobbiesTabState extends ConsumerState<LobbiesTab> {
  // Data for lobbies
  List<IntercomContact> _lobbyContacts = [];
  final TextEditingController _searchController = TextEditingController();
  List<IntercomContact> _filteredLobbyContacts = [];
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isLoading = true;
  final Set<String> _callStartingContactIds = <String>{};
  final IntercomService _intercomService = IntercomService();

  // WebSocket state (copied from chat_screen.dart pattern)
  final ChatService _chatService = ChatService.instance;
  final UnreadCountManager _unreadManager = UnreadCountManager.instance;
  final ApiService _apiService = ApiService.instance;
  StreamSubscription<WebSocketMessage>? _wsMessageSubscription;
  StreamSubscription<bool>? _wsConnectionSubscription;
  bool _isWebSocketConnected = false;

  @override
  void initState() {
    super.initState();
    _loadLobbyContacts();
    _searchController.addListener(_filterLobbyContacts);
    _initializeSpeech();
    _setupWebSocketListeners();
  }

  @override
  void dispose() {
    _wsMessageSubscription?.cancel();
    _wsConnectionSubscription?.cancel();
    _searchController.dispose();
    _speech.stop();
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
            '📊 [LobbiesTab] Received unread_count_update: room=$updateRoomId, user=$userId, count=$unreadCount');

        // Update local unread count manager if this is for current user
        final currentUserId = await _apiService.getUserId();
        if (userId == currentUserId) {
          if (unreadCount == 0) {
            await _unreadManager.clearUnreadCount(updateRoomId);
          } else {
            // Backend is source of truth - update local cache with exact count
            await _unreadManager.setUnreadCount(updateRoomId, unreadCount);
            developer.log(
                '📊 [LobbiesTab] Unread count updated to $unreadCount for room $updateRoomId');
          }

          // Update contact in lobbies list
          final contactId = _unreadManager.getContactIdForRoom(updateRoomId);
          if (contactId != null) {
            _updateContactFromWebSocket(contactId, updateRoomId);
          }
        }
      }
      return; // Don't process unread_count_update as messages
    }

    developer
        .log('📨 [LobbiesTab] Received WebSocket message for room: $roomId');

    // Get contact ID for this room
    final contactId = _unreadManager.getContactIdForRoom(roomId);
    if (contactId == null) return;

    // Check if this message is from current user
    final currentUserId = await _apiService.getUserId();
    final isFromCurrentUser = wsMessage.userId == currentUserId;

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

    // Update contact in lobbies list
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

  /// Update a contact in the lobbies list based on WebSocket message
  void _updateContactFromWebSocket(String contactId, String roomId) {
    if (!mounted) return;

    final contactIndex = _lobbyContacts.indexWhere((c) => c.id == contactId);
    if (contactIndex == -1) return;

    final unreadCount = _unreadManager.getUnreadCount(roomId);
    final lastMessageTime = _unreadManager.getLastMessageTime(roomId);

    final updatedContact = IntercomContact(
      id: _lobbyContacts[contactIndex].id,
      name: _lobbyContacts[contactIndex].name,
      unit: _lobbyContacts[contactIndex].unit,
      role: _lobbyContacts[contactIndex].role,
      building: _lobbyContacts[contactIndex].building,
      floor: _lobbyContacts[contactIndex].floor,
      type: _lobbyContacts[contactIndex].type,
      status: _lobbyContacts[contactIndex].status,
      hasUnreadMessages: unreadCount > 0,
      photoUrl: _lobbyContacts[contactIndex].photoUrl,
      lastContact: lastMessageTime,
      phoneNumber: _lobbyContacts[contactIndex].phoneNumber,
      familyMembers: _lobbyContacts[contactIndex].familyMembers,
      isPrimary: _lobbyContacts[contactIndex].isPrimary,
    );

    setState(() {
      _lobbyContacts[contactIndex] = updatedContact;
      _filteredLobbyContacts = List.from(_lobbyContacts);
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
                _filterLobbyContacts();
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
                _filterLobbyContacts();
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

  void _filterLobbyContacts() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredLobbyContacts = _lobbyContacts;
      } else {
        _filteredLobbyContacts = _lobbyContacts.where((lobby) {
          return lobby.name.toLowerCase().contains(query) ||
              (lobby.role?.toLowerCase().contains(query) ?? false) ||
              (lobby.phoneNumber?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  Future<void> _loadLobbyContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // CRITICAL: Get the selected society's soc_id from selectedFlatProvider
      // This ensures we always use the freshly selected society's ID
      final selectedFlatState = ref.read(selectedFlatProvider);
      final societyId = selectedFlatState.selectedSociety?.socId;

      debugPrint(
          '🟡 [LobbiesTab] Loading lobbies with society soc_id: $societyId');

      // Pass the selected society's soc_id as companyId
      final lobbies = await _intercomService.getLobbies(companyId: societyId);
      if (mounted) {
        setState(() {
          _lobbyContacts = lobbies;
          _filteredLobbyContacts = lobbies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        EnhancedToast.error(
          context,
          title: 'Error',
          message: 'Failed to load lobbies: ${e.toString()}',
        );
      }
    }
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
              // Lobbies info card with gradient
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
                            //     Icons.meeting_room_rounded,
                            //     color: Colors.white.withOpacity(0.2),
                            //     size: 50,
                            //   ),
                            // ),
                            // Main content
                            Row(
                              children: [
                                const Icon(
                                  Icons.meeting_room_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Building Lobbies',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: 18,
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
                        height: 0,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFEE4D5F), Color(0xFFFF9292)],
                          ),
                        ),
                        // child: LayoutBuilder(
                        //   builder: (context, constraints) {
                        //     // Calculate percentage of online lobbies
                        //     final onlineCount = _lobbyContacts
                        //         .where((l) =>
                        //             l.status == IntercomContactStatus.online)
                        //         .length;
                        //     final percentage =
                        //         onlineCount / _lobbyContacts.length;

                        //     return Row(
                        //       children: [
                        //         Container(
                        //           width: constraints.maxWidth * percentage,
                        //           decoration: BoxDecoration(
                        //             color: Colors.green.withOpacity(0.7),
                        //             boxShadow: [
                        //               BoxShadow(
                        //                 color: Colors.green.withOpacity(0.3),
                        //                 blurRadius: 8,
                        //                 spreadRadius: -2,
                        //               ),
                        //             ],
                        //           ),
                        //         ),
                        //       ],
                        //     );
                        //   },
                        // ),
                      ),

                      // Info content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contact building lobbies for delivery collections, visitor assistance, and general inquiries.',
                              style: GoogleFonts.montserrat(
                                color: Colors.grey.shade800,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact = constraints.maxWidth < 360;

                                final totalBadge = Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Total: ${_lobbyContacts.length}',
                                    style: GoogleFonts.montserrat(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );

                                final availableBadge = Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
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
                                      Flexible(
                                        child: Text(
                                          'Currently Available: ${_lobbyContacts.where((l) => l.status == IntercomContactStatus.online).length}',
                                          style: GoogleFonts.montserrat(
                                            color: Colors.green,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (isCompact) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      totalBadge,
                                      const SizedBox(height: 8),
                                      availableBadge,
                                    ],
                                  );
                                }

                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: totalBadge,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: availableBadge,
                                      ),
                                    ),
                                  ],
                                );
                              },
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
                    hintText: 'Search building lobbies...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: const Color(0xFFEE4D5F).withOpacity(0.7),
                      size: 20,
                    ),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, child) {
                        return value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Color(0xFFEE4D5F),
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFEE4D5F).withOpacity(0.1),
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
                                    color: const Color(0xFFEE4D5F),
                                    size: 20,
                                  ),
                                  onPressed: _startListening,
                                  tooltip: 'Voice Search',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  iconSize: 20,
                                ),
                              );
                      },
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

              // Lobby contact cards with improved styling
              _isLoading
                  ? const Center(
                      child: AppLoader(
                        title: 'Loading Lobbies',
                        subtitle: 'Fetching lobby information...',
                        icon: Icons.meeting_room_rounded,
                      ),
                    )
                  : _filteredLobbyContacts.isEmpty &&
                          _searchController.text.isNotEmpty
                      ? _buildEmptyState(
                          icon: Icons.search_off,
                          title: 'No lobbies found',
                          subtitle: 'Try searching with a different keyword',
                        )
                      : _filteredLobbyContacts.isEmpty
                          ? _buildEmptyState(
                              icon: Icons.meeting_room_outlined,
                              title: 'No lobbies available',
                              subtitle:
                                  'Lobbies will appear here when available',
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: _filteredLobbyContacts.map((lobby) {
                                  return _buildLobbyCard(lobby);
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
  Widget _buildLobbyCard(IntercomContact lobby) {
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
                          child: Center(
                            child: Text(
                              _getInitials(lobby.name),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
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
                              color: _getStatusColor(lobby.status),
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
                            lobby.name,
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
                                _getRoleIcon(lobby.role ?? ''),
                                color: Colors.grey.shade600,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lobby.role ?? 'Lobby Desk',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
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
              const Divider(height: 1, color: Colors.black12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: Colors.blue,
                        ),
                        label: const Text(
                          'Chat',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () => _handleChat(lobby),
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
                        onPressed: _callStartingContactIds.contains(lobby.id)
                            ? null
                            : () => _onCallPressed(lobby),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _callStartingContactIds.contains(lobby.id)
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
                            : const Icon(
                                Icons.phone_in_talk,
                                size: 22,
                                color: Colors.green,
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
      case 'ground floor':
        return Icons.door_front_door;
      case 'central lobby':
        return Icons.apartment;
      default:
        return Icons.meeting_room;
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
      developer.log('LobbiesTab: Error getting user data: $e');
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
