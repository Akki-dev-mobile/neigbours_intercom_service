import '../../../../src/config/chat_call_i18n.dart';

/// 🔥 CRITICAL FIX: CreateGroupPage UUID Member Support
///
/// PROBLEM: CreateGroupPage rejected valid UUID members with "invalid userId (must be numeric)"
/// This broke edit mode because RoomInfo returns UUID user_ids, causing "remove then add not updated"
///
/// SOLUTION:
/// - UI identity = UUID (mandatory for selection/display)
/// - Numeric ID = optional metadata (used for APIs when available)
/// - Accept members with UUID even if numeric ID is missing
/// - Skip API operations only when numeric ID is required but unavailable
///
/// This ensures UI consistency while gracefully handling API requirements.

import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/enhanced_toast.dart';
import '../../../../core/widgets/onegate_global_loader.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/society_backend_api_service.dart';
import '../models/intercom_contact.dart';
import '../models/group_chat_model.dart';
import '../models/room_model.dart';
import '../models/room_info_model.dart';
import '../services/intercom_service.dart';
import '../services/room_service.dart';
import '../services/room_info_cache.dart';
import '../services/group_info_loader.dart';
import '../tabs/groups_tab.dart';
import '../../providers/selected_flat_provider.dart';
import '../../../../core/utils/profile_data_helper.dart';
import '../../../../core/utils/oneapp_share.dart';
import '../widgets/voice_search_launcher.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  final GroupChat? groupToEdit;
  final bool
  isAddMemberMode; // Flag to indicate if opened from "Add Member" option

  const CreateGroupPage({
    Key? key,
    this.groupToEdit,
    this.isAddMemberMode = false, // Default to false for backward compatibility
  }) : super(key: key);

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<IntercomContact> _selectedMembers = [];
  List<IntercomContact> _availableResidents = [];
  // Track original members when editing (baseline for add/remove/update diff)
  Set<String> _originalMemberIds =
      {}; // Set of member IDs that were in the group when page opened
  Set<String> _originalMemberNumericIds =
      {}; // Set of numeric member IDs from original members
  // CRITICAL: Track original member data (name/phone) for diff comparison
  // Only set AFTER room info is loaded - this is the baseline for detecting edits
  Map<String, Map<String, String?>> _originalMemberData =
      {}; // Map of member UUID -> {name, phone, numericUserId}
  String? _groupIconPath; // Can be file path or URL
  File? _groupIconFile; // Local file path for new uploads
  final ImagePicker _imagePicker = ImagePicker();
  bool _isCreating = false; // Loading state for API call
  bool _isLoadingResidents = true; // Loading state for residents
  bool _isLoadingMore = false; // Loading more members
  bool _hasMore = true; // Has more pages
  int _currentPage = 1; // Current page
  final int _perPage = 50; // Members per page
  final ScrollController _scrollController = ScrollController();
  final RoomService _roomService = RoomService.instance;
  final ApiService _apiService = ApiService.instance;
  final IntercomService _intercomService = IntercomService();
  final SocietyBackendApiService _societyBackendApiService =
      SocietyBackendApiService.instance;
  final Connectivity _connectivity = Connectivity();

  // Pagination state for members API
  bool _isLoadingMembers = true;
  String? _errorMessage;
  String? _selectedBuilding; // null means "All Buildings"
  int? _cachedCompanyId;
  bool _isListening = false;

  // Flag to track whether we're editing or creating
  bool get _isEditMode => widget.groupToEdit != null;

  /// Indicates whether selection is allowed (no upper cap for new groups now).
  bool get _canSelectMoreMembers => true;

  String? _resolveAvatarUrl(String? rawUrl) {
    final trimmed = rawUrl?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return ProfileDataHelper.buildAvatarUrlFromUserId(trimmed);
    }
    final sanitized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return ProfileDataHelper.resolveAvatarUrl({'avatar': sanitized});
  }

  @override
  void initState() {
    super.initState();
    _loadAvailableResidents();

    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);

    // If editing, pre-fill the form with existing data
    if (_isEditMode) {
      _groupNameController.text = widget.groupToEdit!.name;

      if (widget.groupToEdit!.description != null) {
        _groupDescriptionController.text = widget.groupToEdit!.description!;
      }

      // Initialize with existing members (will be replaced by API fetch)
      _selectedMembers = List.from(widget.groupToEdit!.members);
      // DO NOT set _originalMemberIds here - wait for room info to load
      // Setting it here with potentially stale/empty data breaks diff logic
      debugPrint(
        '⏳ [CreateGroupPage] Waiting for room info to load before tracking original members',
      );

      if (widget.groupToEdit!.iconUrl != null) {
        _groupIconPath = widget.groupToEdit!.iconUrl;
        // If it's a URL, keep it as is. If it's a file path, load it as File
        if (_groupIconPath != null && !_groupIconPath!.startsWith('http')) {
          final file = File(_groupIconPath!);
          if (file.existsSync()) {
            _groupIconFile = file;
          }
        }
      }

      // PERFORMANCE FIX: Load from cache FIRST for immediate display, then refresh in background
      // This ensures members appear instantly instead of waiting for API call
      _loadRoomMembersFromCacheFirst();
    }

    // Add listener to search controller for real-time filtering
    _searchController.addListener(() {
      setState(() {}); // Rebuild when search text changes
    });
  }

  /// Load room members from cache FIRST for immediate display, then refresh in background
  /// This ensures members appear instantly instead of waiting for API call
  Future<void> _loadRoomMembersFromCacheFirst() async {
    if (!_isEditMode || widget.groupToEdit == null) return;

    try {
      final companyId =
          await _apiService.getSelectedSocietyId() ??
          ref.read(selectedFlatProvider).selectedSociety?.socId;
      if (companyId == null) {
        debugPrint(
          '⚠️ [CreateGroupPage] Cannot load members: company_id not available',
        );
        _loadRoomMembers();
        return;
      }
      _cachedCompanyId = companyId;

      final RoomInfoCache roomInfoCache = RoomInfoCache();

      // STEP 1: Try to load from cache FIRST for instant display
      // CRITICAL FIX: getCachedRoomInfo will return null if a member recently left
      // This ensures we always get fresh data when members leave
      final cachedRoomInfo = roomInfoCache.getCachedRoomInfo(
        widget.groupToEdit!.id,
        companyId,
        expiry: const Duration(minutes: 5), // Use cache up to 5 minutes old
      );

      if (cachedRoomInfo != null) {
        debugPrint(
          '⚡ [CreateGroupPage] Loading members from cache for instant display: ${cachedRoomInfo.memberCount} members',
        );

        // Update UI IMMEDIATELY with cached data
        _updateMembersFromRoomInfo(cachedRoomInfo);

        // STEP 2: Refresh in background to get latest data (non-blocking)
        // Don't wait for this - UI is already updated
        // CRITICAL: Always refresh in background to ensure we have latest data
        // This is especially important after members leave
        _loadRoomMembers();
      } else {
        debugPrint(
          '⏳ [CreateGroupPage] No cache available or member recently left - loading from API...',
        );
        // No cache or member left recently - load from API (will update UI when complete)
        // This ensures we always get fresh data when members leave
        _loadRoomMembers();
      }
    } catch (e) {
      debugPrint('⚠️ [CreateGroupPage] Error loading from cache: $e');
      // Fallback to API load
      _loadRoomMembers();
    }
  }

  /// Update members list from RoomInfo (used by both cache and API responses)
  void _updateMembersFromRoomInfo(RoomInfo roomInfo) {
    if (!mounted) return;

    // Create a map of existing members by ID to preserve phone numbers
    final existingMembersMap = <String, IntercomContact>{};
    for (final member in _selectedMembers) {
      existingMembersMap[member.id] = member;
    }

    // Convert RoomInfoMember to IntercomContact
    // CRITICAL: Populate numericUserId from RoomInfoMember for API calls
    // Preserve phone numbers from existing members if available
    // BACKEND FIX: Filter out inactive members - backend now filters by status='active' but add safety check
    final members = roomInfo.members
        .where(
          (member) =>
              member.status == null || member.status!.toLowerCase() == 'active',
        ) // Only include active members
        .map((member) {
          final existingMember = existingMembersMap[member.userId];
          String? avatarUrl =
              _resolveAvatarUrl(member.avatar) ??
              _resolveAvatarUrl(existingMember?.photoUrl);
          avatarUrl ??= ProfileDataHelper.buildAvatarUrlFromUserId(
            member.numericUserId ?? member.userId,
          );
          return IntercomContact(
            id: member.userId,
            name: member.username ?? existingMember?.name ?? 'Unknown User',
            type: IntercomContactType.resident,
            status: IntercomContactStatus.offline,
            phoneNumber: existingMember
                ?.phoneNumber, // Preserve phone number if available
            photoUrl: avatarUrl,
            numericUserId: member
                .numericUserId, // CRITICAL: Populate numeric ID for API calls
          );
        })
        .toList();

    // Also include admin if available
    if (roomInfo.admin != null && roomInfo.admin!.userId != null) {
      final existingAdmin = existingMembersMap[roomInfo.admin!.userId!];
      final adminAvatarUrl = _resolveAvatarUrl(existingAdmin?.photoUrl);
      final adminContact = IntercomContact(
        id: roomInfo.admin!.userId!,
        name:
            roomInfo.admin!.username ??
            roomInfo.admin!.email ??
            existingAdmin?.name ??
            'Admin',
        type: IntercomContactType.resident,
        status: IntercomContactStatus.offline,
        phoneNumber:
            existingAdmin?.phoneNumber, // Preserve phone number if available
        photoUrl: adminAvatarUrl,
        // Note: Admin numericUserId not available from RoomInfoAdmin
      );
      // Only add admin if not already in members list
      if (!members.any((m) => m.id == adminContact.id)) {
        members.add(adminContact);
      }
    }

    setState(() {
      _selectedMembers = members;
      // CRITICAL: Set original member IDs ONLY AFTER room info is loaded
      // This is the correct baseline for diff comparison
      _originalMemberIds = members.map((m) => m.id).toSet();
      _originalMemberNumericIds = members
          .map((m) => m.numericUserId?.toString())
          .whereType<String>()
          .toSet();

      // CRITICAL: Store original member data (name/phone/numericUserId) for diff comparison
      // This allows us to detect actual edits vs just loading data
      _originalMemberData.clear();
      for (final member in members) {
        _originalMemberData[member.id] = {
          'name': member.name,
          'phone': member.phoneNumber ?? '',
          'numericUserId': member.numericUserId?.toString(),
        };
      }
    });

    debugPrint(
      '✅ [CreateGroupPage] Updated selected members: ${_selectedMembers.length} members',
    );
    debugPrint(
      '🔒 [CreateGroupPage] Tracked ${_originalMemberIds.length} original members (cannot be removed)',
    );
    debugPrint(
      '📊 [CreateGroupPage] Stored original member data for ${_originalMemberData.length} members (baseline for edit detection)',
    );

    _enrichSelectedMembersFromResidents();
    if (_isEditMode && _availableResidents.isNotEmpty) {
      _realignSelectedMembersToResidentList();
    }
  }

  /// Map room members (UUID) onto resident-list contacts so checkmarks render.
  void _realignSelectedMembersToResidentList() {
    if (!mounted || !_isEditMode || _availableResidents.isEmpty) return;

    final realigned = <IntercomContact>[];
    for (final selected in _selectedMembers) {
      final match = _availableResidents.cast<IntercomContact?>().firstWhere(
        (r) => r != null && _isSameMemberOrNumeric(selected, r),
        orElse: () => null,
      );
      realigned.add(match ?? selected);
    }

    final originalRealigned = <String>{};
    final numericRealigned = <String>{};
    for (final id in _originalMemberIds) {
      final placeholder = IntercomContact(
        id: id,
        name: '',
        type: IntercomContactType.resident,
        numericUserId: int.tryParse(id),
      );
      final match = _availableResidents.cast<IntercomContact?>().firstWhere(
        (r) => r != null && _isSameMemberOrNumeric(placeholder, r),
        orElse: () => null,
      );
      if (match != null) {
        originalRealigned.add(match.id);
        if (match.numericUserId != null) {
          numericRealigned.add(match.numericUserId.toString());
        }
      } else {
        originalRealigned.add(id);
      }
    }

    setState(() {
      _selectedMembers = realigned;
      if (originalRealigned.isNotEmpty) {
        _originalMemberIds = originalRealigned;
      }
      if (numericRealigned.isNotEmpty) {
        _originalMemberNumericIds = numericRealigned;
      }
    });
  }

  /// Align selected members with resident list IDs (UUID vs numeric) for UI selection.
  void _enrichSelectedMembersFromResidents() {
    _syncSelectedMembersWithResidents();
  }

  /// Use resident-list identity for selected members so checkmarks match in edit mode.
  void _syncSelectedMembersWithResidents() {
    if (!mounted || _selectedMembers.isEmpty) return;

    if (_availableResidents.isEmpty) {
      setState(() {});
      return;
    }

    final synced = <IntercomContact>[];
    var changed = false;

    for (final selected in _selectedMembers) {
      final match = _availableResidents.cast<IntercomContact?>().firstWhere(
        (resident) =>
            resident != null && _isSameMemberOrNumeric(selected, resident),
        orElse: () => null,
      );

      if (match == null) {
        synced.add(selected);
        continue;
      }

      final merged = match.copyWith(
        numericUserId: selected.numericUserId ?? match.numericUserId,
        phoneNumber: (selected.phoneNumber?.isNotEmpty == true)
            ? selected.phoneNumber
            : match.phoneNumber,
        photoUrl: selected.photoUrl ?? match.photoUrl,
      );

      if (merged.id != selected.id ||
          merged.numericUserId != selected.numericUserId ||
          merged.phoneNumber != selected.phoneNumber) {
        changed = true;
      }
      synced.add(merged);
    }

    if (changed || synced.length != _selectedMembers.length) {
      setState(() {
        _selectedMembers = synced;
      });
    } else {
      setState(() {});
    }
  }

  int? _resolveNumericUserId(IntercomContact member, String roomId, int? companyId) {
    if (member.numericUserId != null) return member.numericUserId;
    if (companyId != null && member.id.contains('-')) {
      final mapped = RoomInfoCache().mapUuidToNumericId(
        roomId,
        member.id,
        companyId,
      );
      if (mapped != null) return mapped;
    }
    return int.tryParse(member.id);
  }

  /// Load room members from API (fast /info, conditional /members).
  Future<void> _loadRoomMembers() async {
    if (!_isEditMode || widget.groupToEdit == null) return;

    try {
      debugPrint(
        '📡 [CreateGroupPage] Fetching latest members for room: ${widget.groupToEdit!.id}',
      );

      final companyId =
          _cachedCompanyId ??
          await _apiService.getSelectedSocietyId() ??
          ref.read(selectedFlatProvider).selectedSociety?.socId;
      if (companyId == null) {
        debugPrint(
          '⚠️ [CreateGroupPage] Cannot fetch members: company_id not available',
        );
        return;
      }
      _cachedCompanyId = companyId;

      final result = await GroupInfoLoader().loadFresh(
        roomId: widget.groupToEdit!.id,
        companyId: companyId,
        roomService: _roomService,
        forceRefresh: true,
      );

      if (result.roomInfo != null) {
        final roomInfo = result.roomInfo!;
        debugPrint(
          '✅ [CreateGroupPage] Fetched room info: ${roomInfo.memberCount} members',
        );
        _updateMembersFromRoomInfo(roomInfo);
        _enrichSelectedMembersFromResidents();
      } else {
        debugPrint(
          '⚠️ [CreateGroupPage] Failed to fetch room info: ${result.error}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [CreateGroupPage] Exception loading room members: $e');
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        !_isLoadingResidents &&
        _hasMore) {
      _loadMoreResidents();
    }
  }

  /// Load more residents for pagination
  Future<void> _loadMoreResidents() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      // TODO: Implement pagination loading for residents
      // This method should load the next page of residents
      setState(() {
        _hasMore = false; // For now, disable pagination until implemented
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      debugPrint('Error loading more residents: $e');
    }
  }

  /// Handle create or update action
  Future<void> _handleCreateOrUpdate() async {
    // Validate group name
    final trimmedName = _groupNameController.text.trim();
    if (trimmedName.isEmpty) {
      EnhancedToast.warning(
        context,
        title: chatCallTr(context, 'chatCall_warning', fallback: 'Warning'),
        message: chatCallTr(context, 'chatCall_pleaseEnterAGroupName', fallback: 'Please enter a group name'),
      );
      return;
    }

    // Validate minimum name length
    if (trimmedName.length < 2) {
      EnhancedToast.warning(
        context,
        title: chatCallTr(context, 'chatCall_warning', fallback: 'Warning'),
        message: chatCallTr(context, 'chatCall_groupNameMustBeAtLeast', fallback: 'Group name must be at least 2 characters'),
      );
      return;
    }

    // Validate maximum name length
    if (trimmedName.length > 255) {
      EnhancedToast.error(
        context,
        title: chatCallTr(context, 'chatCall_validationError', fallback: 'Validation Error'),
        message: chatCallTr(context, 'chatCall_groupNameMustBe255Characters', fallback: 'Group name must be 255 characters or less'),
      );
      return;
    }

    // Validate description length if provided
    final trimmedDescription = _groupDescriptionController.text.trim();
    if (trimmedDescription.isNotEmpty && trimmedDescription.length > 500) {
      EnhancedToast.error(
        context,
        title: chatCallTr(context, 'chatCall_validationError', fallback: 'Validation Error'),
        message: chatCallTr(context, 'chatCall_descriptionMustBe500CharactersOr', fallback: 'Description must be 500 characters or less'),
      );
      return;
    }

    // Validate member count for new groups (min 2, no upper cap)
    if (!_isEditMode) {
      if (_selectedMembers.length < 2) {
        EnhancedToast.warning(
          context,
          title: chatCallTr(context, 'chatCall_membersRequired', fallback: 'Members Required'),
          message: chatCallTr(context, 'chatCall_selectAtLeastTwoMembers', fallback: 'Please select at least 2 members to create a group.'),
        );
        return;
      }
    }

    if (_isEditMode) {
      // Update existing group and member details
      await _updateGroup();
    } else {
      // Create new group via API
      await _createRoom();
    }
  }

  /// Create room via API with connectivity check and retry logic
  Future<void> _createRoom({int retryCount = 0}) async {
    // Disable button and show loading
    setState(() {
      _isCreating = true;
    });

    try {
      // Check connectivity before making API call (only on first attempt)
      if (retryCount == 0) {
        final isConnected = await _checkConnectivity();
        if (!isConnected) {
          setState(() {
            _isCreating = false;
          });
          EnhancedToast.error(
            context,
            title: chatCallTr(context, 'chatCall_networkError', fallback: 'Network Error'),
            message:
                chatCallTr(context, 'chatCall_noInternetConnectionPleaseCheckYour', fallback: 'No internet connection. Please check your network settings and try again.'),
          );
          return;
        }
      }

      // Prefer context port (OneGate gate storage); fallback to sync cache.
      final companyId =
          await _apiService.getSelectedSocietyId() ??
          ref.read(selectedFlatProvider).selectedSociety?.socId;
      if (companyId == null) {
        setState(() {
          _isCreating = false;
        });
        EnhancedToast.error(
          context,
          title: chatCallTr(context, 'chatCall_error', fallback: 'Error'),
          message: chatCallTr(context, 'chatCall_pleaseSelectSociety', fallback: 'Please select a society first'),
        );
        return;
      }

      // Create request
      final request = CreateRoomRequest(
        name: _groupNameController.text.trim(),
        description: _groupDescriptionController.text.trim().isNotEmpty
            ? _groupDescriptionController.text.trim()
            : null,
        companyId: companyId,
      );

      // Validate request
      if (!request.validate()) {
        final errors = request.getValidationErrors();
        setState(() {
          _isCreating = false;
        });
        EnhancedToast.error(
          context,
          title: chatCallTr(context, 'chatCall_validationError', fallback: 'Validation Error'),
          message: errors.join(', '),
        );
        return;
      }

      // Call API
      developer.log(
        '🚀 [CreateGroupPage] Creating room${retryCount > 0 ? ' (retry $retryCount)' : ''}...',
      );
      developer.log('📤 [CreateGroupPage] Request data: ${request.toJson()}');
      final response = await _roomService.createRoom(request);
      developer.log(
        '📥 [CreateGroupPage] Response success: ${response.success}',
      );
      developer.log('📥 [CreateGroupPage] Response data: ${response.data}');
      developer.log('📥 [CreateGroupPage] Response error: ${response.error}');

      // Handle response — trust API success + parsed room data (status may be 200/201 or omitted in body)
      if (response.success && response.data != null) {
        // Success - convert Room to GroupChat and return
        final room = response.data!;
        final newGroup = _convertRoomToGroupChat(room);

        // Upload photo if selected (silent - don't block on failure)
        if (_groupIconFile != null) {
          unawaited(_uploadRoomPhotoSilently(room.id, _groupIconFile!));
        }

        // Add members before returning so the group has >=3 members when list refreshes
        if (_selectedMembers.isNotEmpty) {
          await _addMembersToRoomSilently(room.id);
        }

        // Show success toast
        EnhancedToast.success(
          context,
          title: chatCallTr(context, 'Success', fallback: 'Success'),
          message: chatCallTr(context, 'chatCall_groupCreatedSuccessfully2', fallback: 'Group created successfully'),
        );

        // Close screen and return the new group
        if (mounted) {
          Navigator.of(context).pop(newGroup);
        }
      } else {
        // Handle different error cases
        setState(() {
          _isCreating = false;
        });

        final statusCode = response.statusCode;
        final errorMessage = response.displayError;

        if (statusCode == 400) {
          // Validation error
          EnhancedToast.error(
            context,
            title: chatCallTr(context, 'chatCall_validationError', fallback: 'Validation Error'),
            message: errorMessage,
          );
        } else if (statusCode == 401) {
          // Token expired - logout
          EnhancedToast.error(
            context,
            title: chatCallTr(context, 'chatCall_authError', fallback: 'Authentication Error'),
            message: chatCallTr(context, 'chatCall_sessionExpired', fallback: 'Your session has expired. Please login again.'),
          );
          // TODO: Navigate to login screen
        } else if (statusCode == 403) {
          // Not allowed
          EnhancedToast.error(
            context,
            title: chatCallTr(context, 'chatCall_accessDenied', fallback: 'Access Denied'),
            message: chatCallTr(context, 'chatCall_notAllowedToCreateGroup', fallback: 'Not allowed to create group'),
          );
        } else if (statusCode == 409) {
          // Conflict (duplicate name)
          EnhancedToast.error(
            context,
            title: chatCallTr(context, 'chatCall_conflict', fallback: 'Conflict'),
            message: chatCallTr(context, 'chatCall_aGroupWithThisNameAlready', fallback: 'A group with this name already exists'),
          );
        } else if (statusCode == 0) {
          // Network error - retry logic
          final errorMessage = response.displayError;
          final isRetryable =
              errorMessage.contains('timeout') ||
              errorMessage.contains('connection') ||
              errorMessage.contains('Network');

          if (isRetryable && retryCount < 2) {
            // Retry with exponential backoff
            final delaySeconds = (retryCount + 1) * 2; // 2s, 4s
            developer.log(
              '🔄 [CreateGroupPage] Retrying room creation in ${delaySeconds}s (attempt ${retryCount + 1}/2)...',
            );

            setState(() {
              _isCreating = false;
            });

            await Future.delayed(Duration(seconds: delaySeconds));

            // Check connectivity again before retry
            final isConnected = await _checkConnectivity();
            if (isConnected) {
              return _createRoom(retryCount: retryCount + 1);
            } else {
              EnhancedToast.error(
                context,
                title: chatCallTr(context, 'chatCall_networkError', fallback: 'Network Error'),
                message:
                    chatCallTr(context, 'chatCall_noInternetConnectionPleaseCheckYour', fallback: 'No internet connection. Please check your network settings and try again.'),
              );
              return;
            }
          } else {
            // Max retries reached or non-retryable error
            String networkMessage =
                'Unable to connect. Please check your internet connection and try again.';

            if (errorMessage.contains('timeout') ||
                errorMessage.contains('Timeout')) {
              networkMessage =
                  'Connection timeout. The server is taking too long to respond. Please check your internet connection and try again.';
            } else if (errorMessage.contains('SocketException') ||
                errorMessage.contains('ConnectionError')) {
              networkMessage =
                  'Unable to connect to the server. Please check your internet connection and try again.';
            }

            EnhancedToast.error(
              context,
              title: chatCallTr(context, 'chatCall_networkError', fallback: 'Network Error'),
              message: networkMessage,
            );
          }
        } else {
          // Other errors
          EnhancedToast.error(context, title: chatCallTr(context, 'chatCall_error', fallback: 'Error'), message: errorMessage);
        }
      }
    } catch (e) {
      setState(() {
        _isCreating = false;
      });
      EnhancedToast.error(
        context,
        title: chatCallTr(context, 'chatCall_error', fallback: 'Error'),
        message: chatCallTr(context, 'chatCall_unexpectedError', fallback: 'An unexpected error occurred: {error}', params: {'error': '$e'}),
      );
    }
  }

  /// Update existing group and member data
  ///
  /// This method handles:
  /// 1. Membership changes (add/remove members)
  /// 2. Member metadata updates (name/phone) for members with numeric IDs
  ///
  /// Member metadata updates only occur when:
  /// - Member has a valid numeric user ID (API requirement)
  /// - Name or phone has actually changed (prevents unnecessary API calls)
  ///
  /// Group metadata updates (name/description/icon) are not implemented yet
  /// as there's no PUT /rooms/{roomId} endpoint.
  ///
  /// Called when Update button is clicked in edit mode
  Future<void> _updateGroup() async {
    if (!_isEditMode || widget.groupToEdit == null) return;

    // Disable button and show loading
    setState(() {
      _isCreating = true;
    });

    try {
      final roomId = widget.groupToEdit!.id;
      final companyId = await _apiService.getSelectedSocietyId();

      if (companyId == null) {
        setState(() {
          _isCreating = false;
        });
        EnhancedToast.error(
          context,
          title: chatCallTr(context, 'chatCall_error', fallback: 'Error'),
          message: chatCallTr(context, 'chatCall_pleaseSelectSociety', fallback: 'Please select a society first'),
        );
        return;
      }

      // Get room info to get existing members (add-member mode uses cached baseline)
      RoomInfo? roomInfo;
      final existingMemberIds = <String>{};

      if (widget.isAddMemberMode && _originalMemberIds.isNotEmpty) {
        existingMemberIds.addAll(_originalMemberIds);
        debugPrint(
          '➕ [CreateGroupPage] Add-member mode — ${_originalMemberIds.length} existing members from cache',
        );
      } else {
        try {
          final roomInfoResponse = await _roomService.getRoomInfo(
            roomId: roomId,
            companyId: companyId,
            fetchMembersIfMissing: false,
          );
          if (roomInfoResponse.success && roomInfoResponse.data != null) {
            roomInfo = roomInfoResponse.data;
          }
        } catch (e) {
          debugPrint('⚠️ [CreateGroupPage] Failed to fetch room info: $e');
        }

        if (roomInfo != null) {
          for (final member in roomInfo.members) {
            if (member.status == null ||
                member.status!.toLowerCase() == 'active') {
              existingMemberIds.add(member.userId);
            }
          }
          if (roomInfo.admin != null && roomInfo.admin!.userId != null) {
            existingMemberIds.add(roomInfo.admin!.userId!);
          }
        } else if (_originalMemberIds.isNotEmpty) {
          existingMemberIds.addAll(_originalMemberIds);
        }
      }

      // Separate existing members from new members
      final existingMembers = <IntercomContact>[];
      final newMembers = <IntercomContact>[];

      // Get selected member UUIDs for comparison (UI selection uses UUIDs)
      final selectedMemberUuids = _selectedMembers.map((m) => m.id).toSet();

      for (final member in _selectedMembers) {
        // Validate member has valid data
        final name = member.name.trim();
        if (name.isEmpty) {
          debugPrint(
            '⚠️ [CreateGroupPage] Skipping member ${member.id}: name is empty',
          );
          continue;
        }

        // 🔥 FIX 1: UUID is PRIMARY UI identity - numeric ID is OPTIONAL metadata
        // Accept ANY member with valid UUID - do NOT reject based on missing numeric ID
        // This fixes the "remove then add not updated" issue by ensuring UI consistency
        if (member.id.isEmpty) {
          debugPrint(
            '⚠️ [CreateGroupPage] Skipping member ${member.name}: empty UUID (required for UI identity)',
          );
          continue;
        }

        // Numeric ID is bonus metadata for API calls, not required for UI selection
        if (member.numericUserId == null) {
          debugPrint(
            'ℹ️ [CreateGroupPage] Member ${member.name} (${member.id}) has no numeric ID - UUID sufficient for UI, numeric used for APIs when available',
          );
        }

        // Categorize as existing or new member
        if (_isExistingGroupMember(member, existingMemberIds)) {
          existingMembers.add(member);
        } else {
          newMembers.add(member);
        }
      }

      // Detect removed members (skip in add-member mode)
      final removedMembers = <String>[];
      if (!widget.isAddMemberMode && roomInfo != null) {
        for (final existingId in existingMemberIds) {
          if (!selectedMemberUuids.contains(existingId)) {
            removedMembers.add(existingId);
          }
        }
      }

      // Track results
      int updateSuccessCount = 0;
      int updateFailureCount = 0;
      int addSuccessCount = 0;
      int addFailureCount = 0;
      int removeSuccessCount = 0;
      int removeFailureCount = 0;

      // Step 1: Update existing members' metadata (skip in add-member mode)
      if (!widget.isAddMemberMode) {
      for (final member in existingMembers) {
        // Resolve numeric user ID - required for API call
        int? numericUserId = member.numericUserId;

        // Fallback: Try to get from original member data if not in member object
        if (numericUserId == null) {
          final originalData = _originalMemberData[member.id];
          if (originalData != null && originalData['numericUserId'] != null) {
            numericUserId = int.tryParse(originalData['numericUserId']!);
          }
        }

        // Fallback: Map member UUID to numeric ID using cached RoomInfo
        if (numericUserId == null) {
          numericUserId = RoomInfoCache().mapUuidToNumericId(
            roomId,
            member.id,
            companyId,
          );
        }

        // Final fallback: Try parsing UUID as numeric (unlikely but safe)
        if (numericUserId == null) {
          numericUserId = int.tryParse(member.id);
        }

        if (numericUserId == null) {
          // Hard fail: Log error but continue with other members
          debugPrint(
            '❌ [CreateGroupPage] Cannot update member ${member.name} (${member.id}): no numeric user ID available',
          );
          debugPrint('   Original data: ${_originalMemberData[member.id]}');
          debugPrint('   Member numericUserId: ${member.numericUserId}');
          continue;
        }

        final name = member.name.trim();
        final phone = (member.phoneNumber ?? '').trim();

        // CRITICAL: Compare against original baseline, not RoomInfo
        // Original baseline was set AFTER room info loaded, so it's the correct comparison point
        final originalData = _originalMemberData[member.id];
        if (originalData == null) {
          debugPrint(
            '⚠️ [CreateGroupPage] No original data for member ${member.id} - skipping update (should not happen)',
          );
          continue;
        }

        final originalName = originalData['name']?.trim() ?? '';
        final originalPhone = originalData['phone']?.trim() ?? '';

        // Only update if name or phone has actually changed from original baseline
        final nameChanged = originalName != name;
        final phoneChanged = originalPhone != phone;

        if (!nameChanged && !phoneChanged) {
          debugPrint(
            'ℹ️ [CreateGroupPage] Skipping member update for ${member.name}: no changes detected (name: "$originalName" -> "$name", phone: "$originalPhone" -> "$phone")',
          );
          continue;
        }

        debugPrint(
          '✏️ [CreateGroupPage] Member ${member.name} has changes - updating via API',
        );
        debugPrint(
          '   Name: "$originalName" -> "$name" (changed: $nameChanged)',
        );
        debugPrint(
          '   Phone: "$originalPhone" -> "$phone" (changed: $phoneChanged)',
        );
        debugPrint('   Numeric ID: $numericUserId');

        try {
          final response = await _roomService.updateRoomMember(
            roomId: roomId,
            userId: numericUserId,
            name: name,
            phone: phone,
          );

          if (response.success) {
            updateSuccessCount++;
            debugPrint(
              '✅ [CreateGroupPage] Updated member metadata for $numericUserId in room: $roomId',
            );
            // Update original data to reflect the change (so subsequent saves don't re-update)
            _originalMemberData[member.id] = {
              'name': name,
              'phone': phone,
              'numericUserId': numericUserId.toString(),
            };
          } else {
            updateFailureCount++;
            debugPrint(
              '⚠️ [CreateGroupPage] Failed to update member metadata for $numericUserId: ${response.error}',
            );
          }
        } catch (e) {
          updateFailureCount++;
          debugPrint(
            '⚠️ [CreateGroupPage] Exception updating member metadata for $numericUserId: $e',
          );
        }
      }
      }

      // Step 2: Remove members that were deselected
      for (final removedMemberUuid in removedMembers) {
        try {
          final response = await _roomService.removeRoomMember(
            roomId: roomId,
            userId: removedMemberUuid, // backend now expects member UUID
          );

          if (response.success) {
            removeSuccessCount++;
            debugPrint(
              '✅ [CreateGroupPage] Removed member $removedMemberUuid from room: $roomId',
            );

            // CRITICAL FIX: Update cache when admin removes a member
            // This ensures group info shows updated member list immediately
            final roomInfoCache = RoomInfoCache();
            // Optimistically remove the member from cache
            roomInfoCache.removeMemberOptimistically(
              roomId: roomId,
              memberUserId: removedMemberUuid,
            );
            // Mark that a member left - forces fresh API fetch for 30 seconds
            roomInfoCache.markMemberLeft(roomId);
            // Clear cache to ensure fresh data for all users
            roomInfoCache.clearRoomCache(roomId);

            // CRITICAL FIX: Decrement member count in GroupsTab immediately
            // This ensures member count updates immediately in groups list
            GroupsTab.decrementGroupMemberCount(roomId, 1);

            debugPrint(
              '✅ [CreateGroupPage] Updated cache and GroupsTab after removing member $removedMemberUuid from room: $roomId',
            );
          } else {
            removeFailureCount++;
            debugPrint(
              '⚠️ [CreateGroupPage] Failed to remove member $removedMemberUuid: ${response.error}',
            );
          }
        } catch (e) {
          removeFailureCount++;
          debugPrint(
            '⚠️ [CreateGroupPage] Exception removing member $removedMemberUuid: $e',
          );
        }
      }

      // Step 3: Add new members to the room
      if (newMembers.isNotEmpty) {
        try {
          // Convert new members to API format
          // addMembersToRoom API requires numeric user IDs
          final newMembersPayload = <Map<String, dynamic>>[];
          final skippedMembers = <String>[];

          for (final member in newMembers) {
            final userId = _resolveNumericUserId(member, roomId, companyId);
            if (userId == null) {
              // Skip members without numeric ID - API requirement
              skippedMembers.add(member.name);
              debugPrint(
                '⚠️ [CreateGroupPage] Skipping member ${member.name} (${member.id}): addMembersToRoom API requires numeric user ID',
              );
              continue;
            }
            newMembersPayload.add({
              'user_id': userId,
              'name': member.name.trim(),
              'phone': (member.phoneNumber ?? '').trim(),
            });
          }

          if (skippedMembers.isNotEmpty) {
            debugPrint(
              '⚠️ [CreateGroupPage] Skipped ${skippedMembers.length} members due to missing numeric IDs: ${skippedMembers.join(", ")}',
            );
          }

          debugPrint(
            '📤 [CreateGroupPage] Adding ${newMembersPayload.length} new members to room: $roomId',
          );

          final addResponse = await _roomService.addMembersToRoom(
            roomId: roomId,
            members: newMembersPayload,
          );

          if (addResponse.success) {
            addSuccessCount = newMembersPayload
                .length; // Use actual payload length, not original list
            debugPrint(
              '✅ [CreateGroupPage] Successfully added ${newMembersPayload.length} new members to room: $roomId',
            );
            if (skippedMembers.isNotEmpty) {
              debugPrint(
                'ℹ️ [CreateGroupPage] Note: ${skippedMembers.length} members were skipped due to missing numeric IDs',
              );
            }

            // OPTIMISTIC UPDATE: Immediately update UI with new member data
            try {
              // Only include members that were actually sent to API (not skipped due to missing numeric IDs)
              final addedMembers = newMembers.where((member) {
                return _resolveNumericUserId(member, roomId, companyId) != null;
              }).toList();

              // Convert added members to RoomInfoMember format
              final newRoomInfoMembers = addedMembers.map((contact) {
                return RoomInfoMember(
                  userId: contact.id, // This should be UUID for UI consistency
                  username: contact.name,
                  avatar: contact.photoUrl,
                  isAdmin: false, // New members are not admins by default
                  joinedAt: DateTime.now(),
                  numericUserId:
                      contact.numericUserId, // Use the stored numeric ID
                );
              }).toList();

              // Optimistically update RoomInfo cache
              final RoomInfoCache roomInfoCache = RoomInfoCache();
              roomInfoCache.addMembersOptimistically(
                roomId: roomId,
                newMembers: newRoomInfoMembers,
              );

              // Optimistically update GroupsTab member count
              GroupsTab.incrementGroupMemberCount(
                roomId,
                newRoomInfoMembers.length,
              );

              debugPrint(
                '⚡ [CreateGroupPage] Optimistic UI update: +${newMembers.length} members to room $roomId',
              );
            } catch (e) {
              debugPrint('⚠️ [CreateGroupPage] Error in optimistic update: $e');
            }

            // UNIFIED CACHE STRATEGY: Optimistic update provides immediate UI feedback
            // Background refresh ensures cache consistency without UI disruption
            Future.delayed(const Duration(seconds: 30), () async {
              try {
                final coordinator = RoomRefreshCoordinator();
                await coordinator.requestRefresh(
                  roomId: roomId,
                  source: 'background_consistency',
                  skipIfOptimisticUpdate:
                      false, // Allow background refresh even after optimistic
                  refreshAction: () async {
                    // Silent background refresh - only update cache, no UI changes
                    final companyId = await _apiService.getSelectedSocietyId();
                    if (companyId != null) {
                      final response = await _roomService.getRoomInfo(
                        roomId: roomId,
                        companyId: companyId,
                      );
                      if (response.success && response.data != null) {
                        // Update cache silently (no UI refresh)
                        final roomInfoCache = RoomInfoCache();
                        roomInfoCache.cacheRoomInfo(
                          roomId: roomId,
                          companyId: companyId,
                          roomInfo: response.data!,
                        );
                        debugPrint(
                          '🔄 [CreateGroupPage] Background cache refresh completed for room $roomId',
                        );
                      }
                    }
                  },
                );
              } catch (e) {
                debugPrint(
                  '⚠️ [CreateGroupPage] Error in background cache refresh: $e',
                );
              }
            });
          } else {
            addFailureCount = newMembers.length;
            debugPrint(
              '⚠️ [CreateGroupPage] Failed to add new members: ${addResponse.error}',
            );
          }
        } catch (e) {
          addFailureCount = newMembers.length;
          debugPrint('⚠️ [CreateGroupPage] Exception adding new members: $e');
        }
      }

      // Calculate totals (including member metadata updates)
      final totalSuccess =
          updateSuccessCount + addSuccessCount + removeSuccessCount;
      final totalFailure =
          updateFailureCount + addFailureCount + removeFailureCount;

      // CRITICAL: Log explicitly if no member edits were detected
      if (updateSuccessCount == 0 &&
          addSuccessCount == 0 &&
          removeSuccessCount == 0) {
        debugPrint(
          'ℹ️ [CreateGroupPage] No member edits detected — skipping update API',
        );
        debugPrint(
          '   Update attempts: $updateSuccessCount success, $updateFailureCount failed',
        );
        debugPrint(
          '   Add attempts: $addSuccessCount success, $addFailureCount failed',
        );
        debugPrint(
          '   Remove attempts: $removeSuccessCount success, $removeFailureCount failed',
        );
      }

      // Show appropriate toast based on all operation results
      if (totalSuccess > 0 && totalFailure == 0) {
        String message = 'Group updated successfully';
        final parts = <String>[];

        if (updateSuccessCount > 0) {
          parts.add('$updateSuccessCount member profile(s) updated');
        }
        if (addSuccessCount > 0) {
          parts.add('$addSuccessCount new member(s) added');
        }
        if (removeSuccessCount > 0) {
          parts.add('$removeSuccessCount member(s) removed');
        }

        if (parts.isNotEmpty) {
          message = 'Group updated: ${parts.join(', ')}';
        }

        EnhancedToast.success(context, title: chatCallTr(context, 'Success', fallback: 'Success'), message: message);
      } else if (totalSuccess > 0 && totalFailure > 0) {
        EnhancedToast.warning(
          context,
          title: chatCallTr(context, 'chatCall_partialSuccess', fallback: 'Partial Success'),
          message: chatCallTr(
            context,
            'chatCall_partialSuccessSummary',
            fallback: '{success} succeeded, {failure} failed',
            params: {
              'success': '$totalSuccess',
              'failure': '$totalFailure',
            },
          ),
        );
      } else if (totalFailure > 0) {
        EnhancedToast.error(
          context,
          title: chatCallTr(context, 'chatCall_error', fallback: 'Error'),
          message: chatCallTr(context, 'chatCall_failedToUpdateGroupPleaseTry', fallback: 'Failed to update group. Please try again.'),
        );
      } else if (totalSuccess == 0 && totalFailure == 0) {
        // No changes were attempted or all were skipped due to missing data
        EnhancedToast.info(
          context,
          title: chatCallTr(context, 'chatCall_noChanges', fallback: 'No Changes'),
          message: chatCallTr(context, 'chatCall_noMemberEditsDetectedNoUpdates', fallback: 'No member edits detected. No updates were needed.'),
        );
      }

      // Create updated group object
      final updatedGroup = widget.groupToEdit!.copyWith(
        name: _groupNameController.text.trim(),
        description: _groupDescriptionController.text.trim().isNotEmpty
            ? _groupDescriptionController.text.trim()
            : null,
        members: _selectedMembers,
        iconUrl: _groupIconFile != null ? _groupIconFile!.path : _groupIconPath,
        lastMessageTime: DateTime.now(),
      );

      // Upload photo if selected (silent - don't block on failure)
      if (_groupIconFile != null) {
        await _uploadRoomPhotoSilently(roomId, _groupIconFile!);
      }

      // Mark group as updated ONLY if membership changes actually succeeded
      // This ensures GroupsTab refreshes only when there were real API successes
      // CRITICAL: Member count updates already happened during add/remove operations
      // (incrementGroupMemberCount/decrementGroupMemberCount were called immediately)
      // So we don't need to recalculate net changes here
      if (totalSuccess > 0) {
        // Mark group as updated to trigger refresh
        GroupsTab.markGroupUpdated();

        // Invalidate groups cache for consistency
        GroupsTab.invalidateGroupsCache();

        debugPrint(
          '✅ [CreateGroupPage] Group marked as updated due to successful membership changes',
        );
        debugPrint(
          '   Member count updates already applied: +$addSuccessCount, -$removeSuccessCount',
        );
      } else {
        debugPrint(
          'ℹ️ [CreateGroupPage] Group not marked as updated - no successful membership changes',
        );
        debugPrint(
          '   This is expected if no member edits were made (loading data ≠ editing)',
        );
      }

      // Return the updated group
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
        Navigator.of(context).pop(updatedGroup);
      }
    } catch (e) {
      setState(() {
        _isCreating = false;
      });
      EnhancedToast.error(
        context,
        title: chatCallTr(context, 'chatCall_error', fallback: 'Error'),
        message: chatCallTr(context, 'chatCall_unexpectedError', fallback: 'An unexpected error occurred: {error}', params: {'error': '$e'}),
      );
    }
  }

  /// Convert Room to GroupChat for UI compatibility
  GroupChat _convertRoomToGroupChat(Room room) {
    final memberCount = room.membersCount != null && room.membersCount! > 0
        ? room.membersCount
        : 1 + _selectedMembers.length;
    return GroupChat(
      id: room.id,
      name: room.name,
      description: room.description,
      iconUrl:
          room.photoUrl ??
          (_groupIconFile != null ? _groupIconFile!.path : _groupIconPath),
      creatorId: room.createdBy,
      createdByUserId: room.createdByUserId, // Pass numeric user ID
      members: _selectedMembers, // Keep selected members if any
      memberCount: memberCount,
      createdAt: room.createdAt,
      lastMessageTime: room.updatedAt,
    );
  }

  /// Upload room photo silently (non-blocking, no error popups)
  /// Called after room creation succeeds. If upload fails, group creation
  /// is still considered successful.
  Future<void> _uploadRoomPhotoSilently(String roomId, File photoFile) async {
    try {
      final companyId =
          await _apiService.getSelectedSocietyId() ??
          ref.read(selectedFlatProvider).selectedSociety?.socId;
      if (companyId == null) {
        debugPrint(
          '⚠️ [CreateGroup] Cannot upload photo: company_id not available',
        );
        return;
      }

      // Upload photo file directly via multipart API
      final response = await _roomService.uploadRoomPhotoFile(
        roomId: roomId,
        photoFile: photoFile,
        companyId: companyId,
        isPrimary: true,
      );
      if (response.success) {
        debugPrint(
          '✅ [CreateGroup] Photo uploaded successfully for room: $roomId',
        );
      } else {
        debugPrint(
          '⚠️ [CreateGroup] Photo upload failed (silent): ${response.error}',
        );
      }
    } catch (e) {
      // Silent failure - just log
      debugPrint('⚠️ [CreateGroup] Photo upload error (silent): $e');
    }
  }

  /// Add members to room silently (non-blocking, no error popups)
  /// Called after room creation succeeds. If member addition fails, group creation
  /// is still considered successful.
  Future<void> _addMembersToRoomSilently(String roomId) async {
    try {
      // Convert selected members to API format
      // CRITICAL FIX: Use numericUserId which should match old_gate_user_id from token
      // This ensures the user_id used when adding members matches the x-user-id header
      final membersPayload = _selectedMembers.map((member) {
        // DEBUG: Log member details for troubleshooting
        developer.log(
          '🔍 [CreateGroup] Member details for ${member.name}: id=${member.id}, numericUserId=${member.numericUserId}',
        );

        // Use numericUserId if available (this should be the user_id from API)
        // This MUST match the old_gate_user_id that will be used in x-user-id header
        final userId = member.numericUserId ?? int.tryParse(member.id);

        if (userId == null) {
          developer.log(
            '⚠️ [CreateGroup] WARNING: Could not determine user_id for member ${member.name} (id: ${member.id}, numericUserId: ${member.numericUserId})',
          );
        } else {
          developer.log(
            '✅ [CreateGroup] Using user_id=$userId for member ${member.name} (should match old_gate_user_id in token)',
          );
        }

        return {
          'user_id':
              userId ?? member.id, // Use numeric user_id, fallback to string id
          'name': member.name,
          'phone': member.phoneNumber ?? '',
        };
      }).toList();

      if (membersPayload.isEmpty) {
        debugPrint('⚠️ [CreateGroup] No members to add, skipping');
        return;
      }

      debugPrint(
        '📤 [CreateGroup] Adding ${membersPayload.length} members to room: $roomId',
      );

      final response = await _roomService.addMembersToRoom(
        roomId: roomId,
        members: membersPayload,
      );

      if (response.success) {
        debugPrint(
          '✅ [CreateGroup] Successfully added ${membersPayload.length} members to room: $roomId',
        );

        // OPTIMISTIC UPDATE: Immediately update UI with new member data
        try {
          final newRoomInfoMembers = _selectedMembers.map((contact) {
            return RoomInfoMember(
              userId: contact.id,
              username: contact.name,
              avatar: contact.photoUrl,
              isAdmin: false,
              joinedAt: DateTime.now(),
              numericUserId: contact.numericUserId ??
                  int.tryParse(contact.id),
            );
          }).toList();

          final RoomInfoCache roomInfoCache = RoomInfoCache();
          roomInfoCache.addMembersOptimistically(
            roomId: roomId,
            newMembers: newRoomInfoMembers,
          );

          GroupsTab.incrementGroupMemberCount(
            roomId,
            membersPayload.length,
          );

          debugPrint(
            '⚡ [CreateGroup] Optimistic UI update: +${membersPayload.length} members to room $roomId',
          );
        } catch (e) {
          debugPrint('⚠️ [CreateGroup] Error in optimistic update: $e');
        }

        Future.delayed(const Duration(seconds: 30), () async {
          try {
            final coordinator = RoomRefreshCoordinator();
            await coordinator.requestRefresh(
              roomId: roomId,
              source: 'background_consistency',
              skipIfOptimisticUpdate: false,
              refreshAction: () async {
                final companyId = await _apiService.getSelectedSocietyId();
                if (companyId != null) {
                  final infoResponse = await _roomService.getRoomInfo(
                    roomId: roomId,
                    companyId: companyId,
                  );
                  if (infoResponse.success && infoResponse.data != null) {
                    RoomInfoCache().applyRoomInfoUpdate(
                      roomId: roomId,
                      companyId: companyId,
                      roomInfo: infoResponse.data!,
                    );
                  }
                }
              },
            );
          } catch (e) {
            debugPrint('⚠️ [CreateGroup] Background refresh error: $e');
          }
        });
      } else {
        debugPrint(
          '⚠️ [CreateGroup] Failed to add members to room: $roomId - ${response.error}',
        );
      }
    } catch (e) {
      // Silent failure - just log
      debugPrint('⚠️ [CreateGroup] Member addition error (silent): $e');
    }
  }

  /// Load available residents from API
  /// Uses the same API as participant_selector.dart
  /// Check network connectivity before making API calls
  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;
      if (!isConnected) {
        developer.log('⚠️ [CreateGroupPage] No internet connection detected');
      }
      return isConnected;
    } catch (e) {
      developer.log('⚠️ [CreateGroupPage] Error checking connectivity: $e');
      // Assume connected if check fails (to avoid blocking on connectivity check errors)
      return true;
    }
  }

  /// Load residents with retry logic for network failures
  Future<void> _loadAvailableResidents({
    bool reset = true,
    int retryCount = 0,
  }) async {
    if (!mounted) return;

    // Check connectivity before making API call
    if (retryCount == 0) {
      final isConnected = await _checkConnectivity();
      if (!isConnected) {
        if (mounted) {
          setState(() {
            _isLoadingMembers = false;
            _isLoadingMore = false;
            _errorMessage =
                'No internet connection. Please check your network settings and try again.';
          });
        }
        return;
      }
    }

    if (reset) {
      setState(() {
        _isLoadingMembers = true;
        _currentPage = 1;
        _hasMore = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      // Get the selected society ID
      final societyId = await _apiService.getSelectedSocietyId();
      if (societyId == null) {
        developer.log(
          '⚠️ [CreateGroupPage] No society ID found, cannot load members',
        );
        if (mounted) {
          setState(() {
            _isLoadingMembers = false;
            _isLoadingMore = false;
            _errorMessage = chatCallTr(context, 'chatCall_pleaseSelectSocietyToLoadMembers', fallback: 'Please select a society first to load members');
          });
        }
        return;
      }

      // Validate society ID is not empty
      final societyIdStr = societyId.toString().trim();
      if (societyIdStr.isEmpty) {
        developer.log(
          '⚠️ [CreateGroupPage] Society ID is empty, cannot load members',
        );
        if (mounted) {
          setState(() {
            _isLoadingMembers = false;
            _isLoadingMore = false;
            _errorMessage = chatCallTr(context, 'chatCall_invalidSocietyId', fallback: 'Invalid society ID. Please select a society first');
          });
        }
        return;
      }

      developer.log(
        '👥 [CreateGroupPage] Loading residents via IntercomService for society: $societyIdStr',
      );

      if (!reset) {
        // IntercomService.getResidents already returns the full list (no pagination)
        if (mounted) {
          setState(() {
            _isLoadingMore = false;
            _hasMore = false;
          });
        }
        return;
      }

      final societyIdInt = int.tryParse(societyIdStr);
      final residents = await _intercomService.getResidents(
        companyId: societyIdInt,
      );

      if (!mounted) return;

      developer.log(
        '📊 [CreateGroupPage] Loaded ${residents.length} residents via IntercomService',
      );

      if (mounted) {
        setState(() {
          _availableResidents = residents;
          developer.log(
            '🔄 [CreateGroupPage] Set residents list to ${_availableResidents.length}',
          );
          _isLoadingMembers = false;
          _isLoadingMore = false;
          _hasMore = false;
          _errorMessage = null;

          // Auto-select first building if no building is selected and buildings are available
          if (reset && _selectedBuilding == null && _buildings.isNotEmpty) {
            _selectedBuilding = _buildings.first;
            developer.log(
              '🏢 [CreateGroupPage] Auto-selected first building: $_selectedBuilding',
            );
          }

          developer.log(
            '✅ [CreateGroupPage] State updated - Total residents: ${_availableResidents.length}, Has more: $_hasMore',
          );

          _enrichSelectedMembersFromResidents();
          if (_isEditMode) {
            _realignSelectedMembersToResidentList();
          }
        });
      }
    } catch (e, stackTrace) {
      developer.log('❌ [CreateGroupPage] Error loading members: $e');
      developer.log('❌ [CreateGroupPage] Stack trace: $stackTrace');

      // Parse error message to provide user-friendly feedback
      String userFriendlyMessage = 'Failed to load members';
      final errorString = e.toString();
      bool isRetryable = false;

      if (errorString.contains('500')) {
        userFriendlyMessage =
            'Server error occurred. Please try again later or contact support if the issue persists.';
        isRetryable = true;
      } else if (errorString.contains('401') ||
          errorString.contains('Unauthorized')) {
        userFriendlyMessage = 'Authentication failed. Please login again.';
      } else if (errorString.contains('403') ||
          errorString.contains('Forbidden')) {
        userFriendlyMessage =
            'You don\'t have permission to access member data.';
      } else if (errorString.contains('404') ||
          errorString.contains('Not Found')) {
        userFriendlyMessage =
            'Member data not found. Please check your society selection.';
      } else if (errorString.contains('Network') ||
          errorString.contains('connection') ||
          errorString.contains('timeout') ||
          errorString.contains('SocketException') ||
          errorString.contains('ConnectionError') ||
          errorString.contains('ConnectionTimeout')) {
        isRetryable = true;

        // Distinguish between different network error types
        if (errorString.contains('timeout') ||
            errorString.contains('Timeout')) {
          userFriendlyMessage =
              'Connection timeout. The server is taking too long to respond. Please check your internet connection and try again.';
        } else if (errorString.contains('SocketException') ||
            errorString.contains('ConnectionError')) {
          userFriendlyMessage =
              'Unable to connect to the server. Please check your internet connection and try again.';
        } else {
          userFriendlyMessage =
              'Network error. Please check your internet connection and try again.';
        }
      } else if (errorString.contains('society') ||
          errorString.contains('Society')) {
        userFriendlyMessage = 'Please select a society first to load members.';
      } else if (errorString.isNotEmpty) {
        // Extract meaningful part of error message
        final match = RegExp(
          r'Failed to (?:get|load).*?:(.*)',
        ).firstMatch(errorString);
        if (match != null && match.group(1) != null) {
          userFriendlyMessage =
              'Failed to load members: ${match.group(1)!.trim()}';
        } else {
          userFriendlyMessage = 'Failed to load members. Please try again.';
        }
        isRetryable = true;
      }

      // Retry logic for network errors (up to 2 retries with exponential backoff)
      if (isRetryable && retryCount < 2) {
        final delaySeconds = (retryCount + 1) * 2; // 2s, 4s
        developer.log(
          '🔄 [CreateGroupPage] Retrying in ${delaySeconds}s (attempt ${retryCount + 1}/2)...',
        );

        await Future.delayed(Duration(seconds: delaySeconds));

        // Check connectivity again before retry
        final isConnected = await _checkConnectivity();
        if (isConnected) {
          return _loadAvailableResidents(
            reset: reset,
            retryCount: retryCount + 1,
          );
        } else {
          userFriendlyMessage =
              'No internet connection. Please check your network settings and try again.';
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingMembers = false;
          _isLoadingMore = false;
          _errorMessage = userFriendlyMessage;
          // Keep existing residents if this was a "load more" attempt
          if (reset) {
            _availableResidents = [];
          }
        });
      }
    }
  }

  Future<void> _loadMoreMembers() async {
    if (_isLoadingMore || !_hasMore) return;
    await _loadAvailableResidents(reset: false);
  }

  /// Helper method to check if two member IDs refer to the same member
  /// Handles both numeric IDs and UUIDs for proper matching
  bool _isSameMember(String id1, String id2) {
    // Direct match
    if (id1 == id2) return true;

    // Try numeric comparison if both can be parsed as int
    final num1 = int.tryParse(id1);
    final num2 = int.tryParse(id2);
    if (num1 != null && num2 != null && num1 == num2) return true;

    // CRITICAL: Also check if one is numeric string and other is int string representation
    // This handles cases where API returns different formats
    if (num1 != null && num2 == null && id2 == num1.toString()) return true;
    if (num2 != null && num1 == null && id1 == num2.toString()) return true;

    return false;
  }

  /// Check if a member is an original member (cannot be removed in edit mode)
  bool _isOriginalMember(String memberId, {int? numericUserId}) {
    // Check if this member ID is in the original members set
    if (!_isEditMode) return false; // Only disable in edit mode
    if (_originalMemberIds.isEmpty && _originalMemberNumericIds.isEmpty) {
      return false; // No original members tracked
    }

    final isOriginal = _originalMemberIds.any(
      (originalId) => _isSameMember(originalId, memberId),
    );
    if (isOriginal) {
      debugPrint(
        '🔒 [CreateGroupPage] Member ${memberId} is an original member (cannot be removed)',
      );
      return true;
    }

    if (numericUserId != null) {
      final numericId = numericUserId.toString();
      final isOriginalNumeric = _originalMemberNumericIds.any(
        (originalId) => _isSameMember(originalId, numericId),
      );
      if (isOriginalNumeric) {
        debugPrint(
          '🔒 [CreateGroupPage] Member ${memberId} (numeric $numericId) is an original member (cannot be removed)',
        );
        return true;
      }
    }

    return false;
  }

  bool _isSameMemberOrNumeric(IntercomContact a, IntercomContact b) {
    if (_isSameMember(a.id, b.id)) return true;
    if (a.numericUserId != null &&
        b.numericUserId != null &&
        a.numericUserId == b.numericUserId) {
      return true;
    }
    if (a.numericUserId != null &&
        _isSameMember(a.numericUserId.toString(), b.id)) {
      return true;
    }
    if (b.numericUserId != null &&
        _isSameMember(a.id, b.numericUserId.toString())) {
      return true;
    }

    final roomId = widget.groupToEdit?.id;
    final companyId = _cachedCompanyId;
    if (roomId != null && companyId != null) {
      final cache = RoomInfoCache();
      if (a.id.contains('-')) {
        final mapped = cache.mapUuidToNumericId(roomId, a.id, companyId);
        if (mapped != null &&
            (mapped == b.numericUserId ||
                _isSameMember(mapped.toString(), b.id))) {
          return true;
        }
      }
      if (b.id.contains('-')) {
        final mapped = cache.mapUuidToNumericId(roomId, b.id, companyId);
        if (mapped != null &&
            (mapped == a.numericUserId ||
                _isSameMember(mapped.toString(), a.id))) {
          return true;
        }
      }
    }

    // Last resort: same resident name (UUID vs numeric member_id mismatch).
    if (a.name.trim().isNotEmpty &&
        b.name.trim().isNotEmpty &&
        a.name.trim().toLowerCase() == b.name.trim().toLowerCase()) {
      return true;
    }

    return false;
  }

  bool _isResidentSelected(IntercomContact resident) {
    if (_selectedMembers.any((m) => _isSameMemberOrNumeric(m, resident))) {
      return true;
    }
    if (!_isEditMode) return false;
    if (_isExistingGroupMember(resident, _originalMemberIds)) {
      return true;
    }
    final residentName = resident.name.trim().toLowerCase();
    if (residentName.isEmpty) return false;
    for (final selected in _selectedMembers) {
      final selectedName = selected.name.trim().toLowerCase();
      if (selectedName.isNotEmpty && selectedName == residentName) {
        return true;
      }
    }
    return false;
  }

  bool _isExistingGroupMember(
    IntercomContact member,
    Set<String> existingMemberIds,
  ) {
    for (final existingId in existingMemberIds) {
      if (_isSameMember(existingId, member.id)) return true;
      final placeholder = IntercomContact(
        id: existingId,
        name: '',
        type: IntercomContactType.resident,
        numericUserId: int.tryParse(existingId),
      );
      if (_isSameMemberOrNumeric(placeholder, member)) return true;
    }
    if (member.numericUserId != null) {
      for (final existingId in existingMemberIds) {
        if (_isSameMember(existingId, member.numericUserId.toString())) {
          return true;
        }
      }
      if (_originalMemberNumericIds.contains(member.numericUserId.toString())) {
        return true;
      }
    }
    final roomId = widget.groupToEdit?.id;
    if (roomId != null && _cachedCompanyId != null) {
      for (final existingId in existingMemberIds) {
        if (existingId.contains('-')) {
          final mapped = RoomInfoCache().mapUuidToNumericId(
            roomId,
            existingId,
            _cachedCompanyId,
          );
          if (mapped != null &&
              (mapped == member.numericUserId ||
                  _isSameMember(mapped.toString(), member.id))) {
            return true;
          }
        }
      }
      if (member.id.contains('-')) {
        final mapped = RoomInfoCache().mapUuidToNumericId(
          roomId,
          member.id,
          _cachedCompanyId,
        );
        if (mapped != null &&
            _originalMemberNumericIds.contains(mapped.toString())) {
          return true;
        }
      }
    }
    return false;
  }

  void _toggleMemberSelection(IntercomContact contact) {
    // Disable selection for members without user_id (not OneApp users)
    // CRITICAL: Check hasUserId field which tracks if user_id was null in API response
    if (!contact.hasUserId) {
      debugPrint(
        '🔒 [CreateGroupPage] Cannot select member without user_id: ${contact.name} (${contact.id})',
      );
      EnhancedToast.info(
        context,
        title: chatCallTr(context, 'chatCall_cannotSelect', fallback: 'Cannot Select'),
        message:
            '${contact.name} is not a OneApp user and cannot be added to the group',
      );
      return;
    }

    final existingIndex = _selectedMembers.indexWhere(
      (member) => _isSameMemberOrNumeric(member, contact),
    );
    final isCurrentlySelected = existingIndex >= 0;

    setState(() {
      // CRITICAL FIX: Use proper ID comparison
      if (isCurrentlySelected) {
        _selectedMembers.removeAt(existingIndex);
      } else {
        _selectedMembers.add(contact);
      }
    });
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

  // Get unique buildings from available residents
  List<String> get _buildings {
    final buildings = _availableResidents
        .map((resident) {
          // Use building field if available
          if (resident.building != null && resident.building!.isNotEmpty) {
            return resident.building;
          }

          // Fallback: Extract from unit (e.g., 'A' from 'A-101' or 'A101')
          if (resident.unit != null && resident.unit!.isNotEmpty) {
            final unit = resident.unit!;
            if (unit.contains('-')) {
              final building = unit.split('-')[0].trim();
              return building.isNotEmpty ? building : null;
            } else if (RegExp(r'^[A-Za-z]').hasMatch(unit)) {
              // Extract first letter if unit starts with a letter (e.g., "A101" -> "A")
              return unit[0].toUpperCase();
            }
          }
          return null;
        })
        .whereType<String>()
        .toSet()
        .toList();
    buildings.sort();
    return buildings;
  }

  Future<void> _startVoiceSearch() async {
    if (!mounted) return;

    setState(() {
      _isListening = true;
    });

    final result = await VoiceSearchLauncher.open(
      context,
      onTextRecognized: (text) {
        if (!mounted) return;
        setState(() {
          _searchController.text = text;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        });
      },
      onFinalResult: (text) {
        if (!mounted) return;
        setState(() {
          _searchController.text = text;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        });
      },
    );

    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }

    if (mounted && result != null && result.trim().isNotEmpty) {
      setState(() {
        _searchController.text = result;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: result.length),
        );
      });
    }
  }

  // Get filtered residents based on search query and building filter
  List<IntercomContact> get _filteredResidents {
    final query = _searchController.text.toLowerCase().trim();

    // First filter by building if selected
    var filtered = _availableResidents.where((resident) {
      // Filter by building (only if a building is selected)
      if (_selectedBuilding != null && _selectedBuilding!.isNotEmpty) {
        String? extractedBuilding;

        // Use building field if available
        if (resident.building != null && resident.building!.isNotEmpty) {
          extractedBuilding = resident.building;
        } else if (resident.unit != null && resident.unit!.isNotEmpty) {
          // Fallback: Extract from unit
          final unit = resident.unit!;
          if (unit.contains('-')) {
            extractedBuilding = unit.split('-')[0].trim();
          } else if (RegExp(r'^[A-Za-z]').hasMatch(unit)) {
            extractedBuilding = unit[0].toUpperCase();
          }
        }

        // Compare extracted building with selected building (case-insensitive)
        if (extractedBuilding != null && extractedBuilding.isNotEmpty) {
          if (extractedBuilding.toUpperCase() !=
              _selectedBuilding!.toUpperCase()) {
            return false; // Exclude if building doesn't match
          }
        } else {
          // If we can't determine building, exclude it when a building is selected
          return false;
        }
      }
      return true;
    }).toList();

    // Then filter by search query if provided
    if (query.isEmpty) {
      return filtered;
    }

    return filtered.where((resident) {
      // Search by name
      final nameMatch = resident.name.toLowerCase().contains(query);

      // Search by unit
      final unitMatch = resident.unit != null
          ? resident.unit!.toLowerCase().contains(query)
          : false;

      // Search by building
      final buildingMatch = resident.building != null
          ? resident.building!.toLowerCase().contains(query)
          : false;

      // Search by phone number
      final phoneMatch = resident.phoneNumber != null
          ? resident.phoneNumber!.toLowerCase().contains(query)
          : false;

      return nameMatch || unitMatch || buildingMatch || phoneMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: Text(
          widget.isAddMemberMode
              ? chatCallTr(
                  context,
                  'chatCall_addMembers',
                  fallback: 'Add Members',
                )
              : (_isEditMode
                  ? chatCallTr(
                      context,
                      'chatCall_updateGroup',
                      fallback: 'Update Group',
                    )
                  : chatCallTr(
                      context,
                      'chatCall_createGroup',
                      fallback: 'Create Group',
                    )),
          style: GoogleFonts.montserrat(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isCreating ? null : _handleCreateOrUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        widget.isAddMemberMode
                            ? chatCallTr(
                                context,
                                'chatCall_addUpper',
                                fallback: 'ADD',
                              )
                            : (_isEditMode
                                ? chatCallTr(
                                    context,
                                    'chatCall_updateUpper',
                                    fallback: 'UPDATE',
                                  )
                                : chatCallTr(
                                    context,
                                    'chatCall_createGroupUpper',
                                    fallback: 'CREATE',
                                  )),
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group header card with gradient
              // When in add member mode, visually indicate it's disabled
              Opacity(
                opacity: widget.isAddMemberMode ? 0.6 : 1.0,
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
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xffc62828), Color(0xffff8a80)],
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
                            Row(
                              children: [
                                const Icon(
                                  Icons.group_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(chatCallTr(context, 'chatCall_groupInfo', fallback: 'Group Information'),
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (!_isEditMode)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(chatCallTr(context, 'Select at least 2 members to create a new group.', fallback: 'Select at least 2 members to create a new group.'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      if (!_isEditMode) const SizedBox(height: 8),

                      // Group details
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Group name field
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _groupNameController,
                                maxLength:
                                    12, // Limit group name to 12 characters
                                enabled: !widget
                                    .isAddMemberMode, // Disable when in add member mode
                                readOnly: widget
                                    .isAddMemberMode, // Make read-only when in add member mode
                                style: TextStyle(
                                  color: widget.isAddMemberMode
                                      ? Colors.grey.shade600
                                      : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: chatCallTr(
                                    context,
                                    'chatCall_enterGroupName',
                                    fallback: 'Enter group name',
                                  ),
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.group,
                                    color: widget.isAddMemberMode
                                        ? Colors.grey.shade400
                                        : const Color(0xffc62828),
                                    size: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: widget.isAddMemberMode
                                      ? Colors.grey.shade100
                                      : Colors.white,
                                  counterText: '', // Hide default counter
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Group description field
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _groupDescriptionController,
                                maxLines: 3,
                                enabled: !widget
                                    .isAddMemberMode, // Disable when in add member mode
                                readOnly: widget
                                    .isAddMemberMode, // Make read-only when in add member mode
                                style: TextStyle(
                                  color: widget.isAddMemberMode
                                      ? Colors.grey.shade600
                                      : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: chatCallTr(
                                    context,
                                    'chatCall_enterGroupDescription',
                                    fallback: 'Enter group description',
                                  ),
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      right: 8,
                                    ),
                                    child: Icon(
                                      Icons.description,
                                      color: widget.isAddMemberMode
                                          ? Colors.grey.shade400
                                          : const Color(0xffc62828),
                                      size: 20,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: widget.isAddMemberMode
                                      ? Colors.grey.shade100
                                      : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  alignLabelWithHint: true,
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

              const SizedBox(height: 24),

              // Selected members section
              if (_selectedMembers.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
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
                            colors: [Color(0xffc62828), Color(0xffff8a80)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people_alt_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              chatCallTr(
                                context,
                                'chatCall_selectedMembersCount',
                                fallback:
                                    'Selected Members ({count})',
                                params: {
                                  'count': '${_selectedMembers.length}',
                                },
                              ),
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Selected members chips
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedMembers.map((member) {
                            final avatarUrl = _resolveAvatarUrl(
                              member.photoUrl,
                            );
                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xffffebee),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(0xffffebee),
                                    backgroundImage: avatarUrl != null
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    onBackgroundImageError: avatarUrl != null
                                        ? (exception, stackTrace) {}
                                        : null,
                                    child: avatarUrl == null
                                        ? Text(
                                            _getInitials(member.name),
                                            style: const TextStyle(
                                              color: Color(0xffc62828),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    member.name.length > 23
                                        ? '${member.name.substring(0, 23)}...'
                                        : member.name,
                                    style: GoogleFonts.montserrat(
                                      color: Colors.grey.shade800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Only show cancel icon for newly added members in edit mode, not for original members
                                  if (!_isEditMode ||
                                      !_isOriginalMember(
                                        member.id,
                                        numericUserId: member.numericUserId,
                                      )) ...[
                                    GestureDetector(
                                      onTap: () =>
                                          _toggleMemberSelection(member),
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Residents section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
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
                          colors: [Color(0xffc62828), Color(0xffff8a80)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.apartment_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(chatCallTr(context, 'chatCall_addResidents', fallback: 'Add Residents'),
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Building chips
                    if (_buildings.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              // Building chips
                              ..._buildings.map((building) {
                                final isSelected =
                                    _selectedBuilding == building;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(building),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedBuilding = selected
                                            ? building
                                            : null;
                                      });
                                    },
                                    backgroundColor: Colors.white,
                                    selectedColor: const Color(0xffc62828),
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey.shade800,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    side: BorderSide(
                                      color: isSelected
                                          ? Colors.transparent
                                          : Colors.grey.shade300,
                                    ),
                                    showCheckmark: false,
                                    shape: const StadiumBorder(),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.search,
                              color: Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: chatCallTr(
                                    context,
                                    'chatCall_searchResidentsByName',
                                    fallback: 'Search residents by name',
                                  ),
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                ),
                                onChanged: (value) {
                                  setState(() {});
                                },
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              ),
                            Container(
                              margin: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xffffebee),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isListening ? Icons.mic : Icons.mic_none,
                                  color: _isListening
                                      ? Colors.red
                                      : const Color(0xffc62828),
                                  size: 20,
                                ),
                                onPressed:
                                    _isListening ? null : _startVoiceSearch,
                                tooltip: chatCallTr(
                                  context,
                                  'chatCall_voiceSearch',
                                  fallback: 'Voice Search',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Residents list
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _isLoadingMembers && _availableResidents.isEmpty
                          ? OneGateGlobalLoader(
                              title: chatCallTr(context, 'chatCall_loadingResidents', fallback: 'Loading Residents'),
                              subtitle: chatCallTr(context, 'chatCall_fetchingResidentInformation', fallback: 'Fetching resident information...'),
                            )
                          : _errorMessage != null && _availableResidents.isEmpty
                          ? _buildErrorState()
                          : _filteredResidents.isEmpty
                          ? _buildEmptyState()
                          : Column(
                              children: [
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _filteredResidents.length,
                                  itemBuilder: (context, index) {
                                    final resident = _filteredResidents[index];
                                    final isSelected = _isResidentSelected(
                                      resident,
                                    );
                                    // Disable only when contact cannot be added (not a OneApp user)
                                    final isDisabled = !resident.hasUserId;
                                    final isNotOneApp = !resident.hasUserId;
                                    final showSelectedPill =
                                        _isEditMode &&
                                        isSelected &&
                                        !isNotOneApp;
                                    final reachedSelectionLimit =
                                        !_isEditMode &&
                                        _selectedMembers.length >= 2;
                                    final cannotSelectMore =
                                        reachedSelectionLimit && !isSelected;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Card(
                                        elevation: 2,
                                        margin: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          side: BorderSide(
                                            color: isSelected
                                                ? const Color(0xffc62828)
                                                : Colors.grey.shade100,
                                            width: 1,
                                          ),
                                        ),
                                        color: Colors.white,
                                        shadowColor: Colors.black12,
                                        child: InkWell(
                                          onTap: isDisabled
                                              ? null // Disable tap for original members
                                              : () => _toggleMemberSelection(
                                                  resident,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              children: [
                                                // Avatar with initials
                                                CircleAvatar(
                                                  radius: 20,
                                                  backgroundColor: const Color(
                                                    0xffffebee,
                                                  ),
                                                  backgroundImage:
                                                      _resolveAvatarUrl(
                                                            resident.photoUrl,
                                                          ) !=
                                                          null
                                                      ? NetworkImage(
                                                          _resolveAvatarUrl(
                                                            resident.photoUrl,
                                                          )!,
                                                        )
                                                      : null,
                                                  onBackgroundImageError:
                                                      _resolveAvatarUrl(
                                                            resident.photoUrl,
                                                          ) !=
                                                          null
                                                      ? (
                                                          exception,
                                                          stackTrace,
                                                        ) {}
                                                      : null,
                                                  child:
                                                      _resolveAvatarUrl(
                                                            resident.photoUrl,
                                                          ) ==
                                                          null
                                                      ? Text(
                                                          _getInitials(
                                                            resident.name,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xffc62828,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                fontSize: 16,
                                                              ),
                                                        )
                                                      : null,
                                                ),

                                                const SizedBox(width: 12),

                                                // Resident details
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        resident.name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      if (resident.unit != null)
                                                        Text(
                                                          chatCallTr(
                                                            context,
                                                            'chatCall_unitLabel',
                                                            fallback:
                                                                'Unit {unit}',
                                                            params: {
                                                              'unit':
                                                                  '${resident.unit}',
                                                            },
                                                          ),
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey
                                                                .shade600,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      if (isNotOneApp)
                                                        Text(chatCallTr(context, 'chatCall_notOneappUser', fallback: 'Not a oneapp user'),
                                                          style: TextStyle(
                                                            color: Colors
                                                                .orange
                                                                .shade700,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        )
                                                      else if (showSelectedPill)
                                                        Text(chatCallTr(context, 'chatCall_alreadyAMember', fallback: 'Already a member'),
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey
                                                                .shade600,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),

                                                // Add/Remove icon or Invite/Selected for disabled members
                                                if (isNotOneApp)
                                                  ElevatedButton.icon(
                                                    onPressed: () =>
                                                        OneAppShare.shareInvite(
                                                          name: resident.name,
                                                        ),
                                                    icon: const Icon(
                                                      Icons.person_add_alt_1,
                                                      size: 16,
                                                    ),
                                                    label: Text(chatCallTr(context, 'chatCall_invite', fallback: 'Invite'),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.orange,
                                                      foregroundColor:
                                                          Colors.white,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 6,
                                                          ),
                                                      elevation: 0,
                                                      minimumSize: const Size(
                                                        0,
                                                        0,
                                                      ),
                                                      tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                    ),
                                                  )
                                                else if (showSelectedPill)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xffffebee,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(chatCallTr(context, 'chatCall_selected', fallback: 'Selected'),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: const Color(
                                                          0xffc62828,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                      color: cannotSelectMore
                                                          ? Colors.grey.shade200
                                                          : (isSelected
                                                                ? const Color(
                                                                    0xffffebee,
                                                                  )
                                                                : Colors
                                                                      .grey
                                                                      .shade100),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                        isSelected
                                                            ? Icons.remove
                                                            : Icons.add,
                                                        color: cannotSelectMore
                                                            ? Colors
                                                                  .grey
                                                                  .shade400
                                                            : (isSelected
                                                                  ? const Color(
                                                                      0xffc62828,
                                                                    )
                                                                  : Colors
                                                                        .grey
                                                                        .shade700),
                                                        size: 18,
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
                                ),
                                // Load more button
                                if (_hasMore || _isLoadingMore)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      bottom: 8,
                                    ),
                                    child: _isLoadingMore
                                        ? SizedBox(
                                            height: 240,
                                            child: OneGateGlobalLoader(
                                              title: chatCallTr(context, 'chatCall_loadingResidents', fallback: 'Loading Residents'),
                                              subtitle:
                                                  chatCallTr(context, 'chatCall_fetchingResidentInformation', fallback: 'Fetching resident information...'),
                                            ),
                                          )
                                        : ElevatedButton.icon(
                                            onPressed: _loadMoreMembers,
                                            icon: const Icon(
                                              Icons.refresh,
                                              size: 20,
                                            ),
                                            label: Text(
                                              chatCallTr(
                                                context,
                                                'chatCall_loadMore',
                                                fallback: 'Load More',
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                    vertical: 14,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              elevation: 2,
                                            ),
                                          ),
                                  ),
                              ],
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

  void _showImageSourceDialog() {
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
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(chatCallTr(context, 'Select Image Source', fallback: 'Select Image Source'),
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
                    label: chatCallTr(context, 'chatCall_camera', fallback: 'Camera'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickGroupImage(ImageSource.camera);
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: chatCallTr(context, 'chatCall_gallery', fallback: 'Gallery'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickGroupImage(ImageSource.gallery);
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
            Icon(icon, size: 24, color: AppColors.primary),
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

  Future<void> _pickGroupImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        setState(() {
          _groupIconFile = File(image.path);
          _groupIconPath = image.path; // Update path for display
        });

        EnhancedToast.success(
          context,
          title: chatCallTr(context, 'Success', fallback: 'Success'),
          message: chatCallTr(context, 'chatCall_groupPhotoUpdatedSuccessfully', fallback: 'Group photo updated successfully'),
        );
      }
    } catch (e) {
      EnhancedToast.error(
        context,
        title: chatCallTr(context, 'chatCall_error', fallback: 'Error'),
        message: 'Failed to pick image: ${e.toString()}',
      );
    }
  }

  Widget _buildEmptyState() {
    // Show different message based on whether we have data or not
    final hasData = _availableResidents.isNotEmpty;
    final searchQuery = _searchController.text.trim();
    IconData icon;
    String title;
    String subtitle;

    if (hasData) {
      if (searchQuery.isNotEmpty) {
        icon = Icons.search_off;
        title = 'No members found';
        subtitle =
            'No members match your search query. Try a different search term.';
      } else if (_selectedBuilding != null) {
        icon = Icons.people_outline;
        title = 'No members found';
        subtitle = 'Select a different building to view members';
      } else {
        icon = Icons.people_outline;
        title = 'No members found';
        subtitle = 'No members available';
      }
    } else {
      icon = Icons.people_outline;
      title = 'No members';
      subtitle = 'No members available';
    }

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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xffffebee),
              ),
              child: Icon(icon, size: 28, color: const Color(0xffc62828)),
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(chatCallTr(context, 'chatCall_failedToLoadMembersShort', fallback: 'Failed to load members'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
                _loadAvailableResidents();
              },
              icon: const Icon(Icons.refresh),
              label: Text(
                chatCallTr(context, 'chatCall_retry', fallback: 'Retry'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
