import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/services/base_api_service.dart';
import '../../../../core/services/keycloak_service.dart';
import '../../../../core/models/api_response.dart';
import '../../../../core/network/network_interceptors.dart';
import '../models/room_model.dart';
import '../models/room_message_model.dart';
import '../models/room_info_model.dart';
import '../models/message_reaction_model.dart';
import '../../../../core/constants.dart';

/// Room API Service for managing rooms (groups)
/// Base URL: http://13.201.27.102:7071/api/v1
class RoomService extends BaseApiService {
  static RoomService? _instance;

  RoomService._()
      : super(
          baseUrl: AppConstants.roomServiceBaseUrl,
          serviceName: 'RoomService',
          connectTimeout:
              const Duration(seconds: 60), // Increased timeout for slow server
          receiveTimeout:
              const Duration(seconds: 60), // Increased timeout for slow server
        );

  /// Get singleton instance
  static RoomService get instance {
    _instance ??= RoomService._();
    return _instance!;
  }

  /// Transform localhost URLs to proper server URLs
  /// This fixes the issue where backend returns localhost URLs that don't work on mobile devices
  /// Converts: http://localhost:8080/uploads/... -> http://13.201.27.102:7071/uploads/...
  ///
  /// IMPORTANT: If the transformed URL returns 404, the files might be on S3 or a different endpoint.
  /// The backend should return the correct URL, but this transformation handles development environments.
  static String? transformLocalhostUrl(String? url) {
    if (url == null || url.isEmpty) {
      return url;
    }

    final serviceUri = Uri.tryParse(AppConstants.roomServiceBaseUrl);
    final serverOrigin = (serviceUri != null && serviceUri.hasAuthority)
        ? '${serviceUri.scheme}://${serviceUri.authority}'
        : 'http://localhost';

    // Check if URL contains localhost or 127.0.0.1
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      log('🔄 [RoomService] Transforming localhost URL: $url',
          name: 'RoomService');

      // Extract the path from the URL (everything after the host)
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final path = uri.path;
        final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
        final fragment = uri.fragment.isNotEmpty ? '#${uri.fragment}' : '';

        // Construct new URL with server host
        // Use the same path structure but with the actual server
        final transformedUrl = '$serverOrigin$path$query$fragment';

        log('✅ [RoomService] Transformed URL: $transformedUrl',
            name: 'RoomService');
        log('   Original path: $path', name: 'RoomService');
        return transformedUrl;
      }

      // Fallback: simple string replacement if URI parsing fails
      String transformedUrl = url
          .replaceAll('http://localhost:8080', serverOrigin)
          .replaceAll('https://localhost:8080', serverOrigin)
          .replaceAll('http://127.0.0.1:8080', serverOrigin)
          .replaceAll('https://127.0.0.1:8080', serverOrigin);

      log('✅ [RoomService] Transformed URL (fallback): $transformedUrl',
          name: 'RoomService');
      return transformedUrl;
    }

    return url;
  }

  /// Construct file URL from file_key if available
  /// This is a fallback when file_url is not available or returns 404
  static String? constructFileUrlFromKey(String? fileKey, {String? baseUrl}) {
    if (fileKey == null || fileKey.isEmpty) {
      return null;
    }

    final serviceUri = Uri.tryParse(AppConstants.roomServiceBaseUrl);
    final serverOrigin = (serviceUri != null && serviceUri.hasAuthority)
        ? '${serviceUri.scheme}://${serviceUri.authority}'
        : 'http://localhost';
    final serverBaseUrl = baseUrl ?? serverOrigin;

    // If file_key is already a full URL, return it
    if (fileKey.startsWith('http://') || fileKey.startsWith('https://')) {
      return fileKey;
    }

    // Construct URL from file_key
    // Remove leading slash if present
    final cleanKey = fileKey.startsWith('/') ? fileKey.substring(1) : fileKey;
    final constructedUrl = '$serverBaseUrl/$cleanKey';

    log('🔧 [RoomService] Constructed file URL from key: $constructedUrl',
        name: 'RoomService');
    return constructedUrl;
  }

  /// Override getAuthHeaders to use old_gate_user_id for x-user-id header
  /// This ensures consistency with the user_id used when adding members
  /// CRITICAL: The x-user-id header must match the user_id used in member addition API calls
  @override
  Future<Map<String, String>> getAuthHeaders() async {
    try {
      // Get base headers from parent class (includes Authorization token)
      final headers = await super.getAuthHeaders();

      // Get user data from Keycloak token
      final userData = await KeycloakService.getUserData();
      if (userData != null) {
        // DEBUG: Log all available user ID fields
        log('🔍 [RoomService] User data keys: ${userData.keys.toList()}',
            name: serviceName);
        log('🔍 [RoomService] old_gate_user_id: ${userData['old_gate_user_id']}',
            name: serviceName);
        log('🔍 [RoomService] old_sso_user_id: ${userData['old_sso_user_id']}',
            name: serviceName);
        log('🔍 [RoomService] user_id: ${userData['user_id']}',
            name: serviceName);

        // CRITICAL FIX: Use old_gate_user_id for x-user-id header
        // This matches the user_id used when adding members to rooms
        // Priority: old_gate_user_id > old_sso_user_id > user_id
        final userId = userData['old_gate_user_id']?.toString() ??
            userData['old_sso_user_id']?.toString() ??
            userData['user_id']?.toString();

        if (userId != null && userId.isNotEmpty) {
          headers['x-user-id'] = userId;
          log('✅ [RoomService] Set x-user-id header: $userId (from old_gate_user_id)',
              name: serviceName);
          log('🔍 [RoomService] All headers being sent: ${headers.keys.toList()}',
              name: serviceName);
        } else {
          log('⚠️ [RoomService] No valid user_id found in token for x-user-id header',
              name: serviceName);
          log('⚠️ [RoomService] Available IDs: old_gate_user_id=${userData['old_gate_user_id']}, old_sso_user_id=${userData['old_sso_user_id']}, user_id=${userData['user_id']}',
              name: serviceName);
        }
      } else {
        log('⚠️ [RoomService] User data is null, cannot set x-user-id header',
            name: serviceName);
      }

      return headers;
    } catch (e, stackTrace) {
      log('❌ [RoomService] Error getting auth headers: $e', name: serviceName);
      log('❌ [RoomService] Stack trace: $stackTrace', name: serviceName);
      // Fallback to parent implementation on error
      return await super.getAuthHeaders();
    }
  }

  /// Create a new room (group)
  ///
  /// POST /rooms
  ///
  /// Request body:
  /// {
  ///   "name": "General Discussion",
  ///   "description": "A room for general discussions" (optional),
  ///   "company_id": 12345
  /// }
  ///
  /// Response:
  /// {
  ///   "data": {
  ///     "id": "d71c9ce4-9285-4ec0-9c24-4fee6344af7b",
  ///     "name": "General Discussion",
  ///     "description": "A room for general discussions",
  ///     "created_by": "46bdcd14-f6f7-44fa-a335-7bff9d10f6b5",
  ///     "created_at": "2026-01-08T06:17:44.231185Z",
  ///     "updated_at": "2026-01-08T06:17:44.231185Z"
  ///   },
  ///   "message": "Room created successfully",
  ///   "status": "success",
  ///   "status_code": 201
  /// }
  Future<ApiResponse<Room>> createRoom(CreateRoomRequest request) async {
    try {
      // Validate request
      if (!request.validate()) {
        final errors = request.getValidationErrors();
        return ApiResponse.error(
          errors.join(', '),
          statusCode: 400,
        );
      }

      log('Creating room: ${request.name}', name: serviceName);

      // Make API call with extended timeout for slow server
      // Note: Server at http://13.201.27.102:7071 can be slow, so we use longer timeout
      final response = await post<Room>(
        '/rooms',
        data: request.toJson(),
        fromJson: (json) => Room.fromJsonWithFallbacks(
          json as Map<String, dynamic>,
          request, // Pass original request for fallback values
        ),
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.success && response.data != null) {
        log('Room created successfully: ${response.data!.id}',
            name: serviceName);
      } else {
        log('Failed to create room: ${response.error}', name: serviceName);
        log('   statusCode: ${response.statusCode}, message: ${response.message}',
            name: serviceName);
      }

      return response;
    } catch (e) {
      log('Exception creating room: $e', name: serviceName);
      return ApiResponse.error(
        'Failed to create room: $e',
        statusCode: 0,
      );
    }
  }

  /// Get messages for a room (group)
  ///
  /// GET /rooms/{roomId}/messages?company_id={companyId}&limit=50&offset=0
  ///
  /// Query Parameters:
  /// - company_id: The company/society ID (optional but recommended)
  /// - limit: Number of messages to fetch (default: 50)
  /// - offset: Pagination offset (default: 0)
  ///
  /// Response:
  /// {
  ///   "data": null,  // or [] when no messages, or array of messages
  ///   "message": "Messages fetched successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  ///
  /// When messages exist, data is an array:
  /// [
  ///   {
  ///     "id": "string",
  ///     "room_id": "string",
  ///     "sender_id": "string",
  ///     "sender_name": "string",
  ///     "body": "string",
  ///     "created_at": "ISODate"
  ///   }
  /// ]
  ///
  /// ⚠️ Important: data can be null when there are no messages.
  /// Do NOT treat this as an error.
  /// Get messages for a room
  ///
  /// GET /rooms/{roomId}/messages?company_id={companyId}&limit={limit}&offset={offset}
  ///
  /// Matches curl format:
  /// curl --location 'http://13.201.27.102:7071/api/v1/rooms/{roomId}/messages?company_id={companyId}&limit={limit}&offset={offset}'
  /// --header 'Authorization: Bearer {token}'
  Future<ApiResponse<List<RoomMessage>>> getMessages({
    required String roomId,
    int? companyId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      log('📥 [RoomService] Fetching messages for room: $roomId',
          name: serviceName);
      log('   company_id: ${companyId ?? "not provided"}', name: serviceName);
      log('   limit: $limit', name: serviceName);
      log('   offset: $offset', name: serviceName);

      // Build query parameters (matching curl format)
      final queryParameters = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (companyId != null) {
        queryParameters['company_id'] = companyId;
      }

      // Log the exact URL that will be called
      final endpoint = '/rooms/$roomId/messages';
      final queryString = queryParameters.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      log('🌐 [RoomService] API Call:', name: serviceName);
      log('   Method: GET', name: serviceName);
      log('   Endpoint: $endpoint', name: serviceName);
      log('   Query: $queryString', name: serviceName);
      log('   Full URL: $baseUrl$endpoint?$queryString', name: serviceName);
      log('   Headers: Authorization: Bearer <token>', name: serviceName);

      // Make API call
      final response = await get<List<RoomMessage>>(
        endpoint,
        queryParameters: queryParameters,
        fromJson: (json) {
          // Handle null data (no messages)
          if (json == null) {
            return <RoomMessage>[];
          }

          // Handle array of messages
          if (json is List) {
            final messages = json
                .map((item) {
                  try {
                    if (item is Map<String, dynamic>) {
                      final message = RoomMessage.fromJson(item);
                      // Log message details for debugging
                      log('📨 [RoomService] Parsed message:',
                          name: serviceName);
                      log('   ID: ${message.id}', name: serviceName);
                      log('   Content: ${message.body.isEmpty ? "(empty)" : message.body.substring(0, message.body.length > 50 ? 50 : message.body.length)}',
                          name: serviceName);
                      log('   Sender: ${message.senderId}', name: serviceName);
                      log('   Created: ${message.createdAt}',
                          name: serviceName);
                      log('   ReplyTo: ${message.replyTo ?? "null"}',
                          name: serviceName);
                      return message;
                    } else {
                      log('⚠️ [RoomService] Invalid message item format: $item',
                          name: serviceName);
                      return null;
                    }
                  } catch (e, stackTrace) {
                    log('❌ [RoomService] Error parsing message item: $e',
                        name: serviceName, error: e, stackTrace: stackTrace);
                    log('⚠️ [RoomService] Problematic item: $item',
                        name: serviceName);
                    return null;
                  }
                })
                .whereType<RoomMessage>() // Filter out null values
                .toList();

            log('✅ [RoomService] Successfully parsed ${messages.length} messages',
                name: serviceName);
            return messages;
          }

          // CRITICAL FIX: Handle null data gracefully (backend returns data: null when no messages)
          // This is a valid response format, not an error
          // Backend response: { "data": null, "message": "Messages fetched successfully", "status": "success", "status_code": 200 }
          if (json == null) {
            log('✅ [RoomService] No messages (data is null) - returning empty list',
                name: serviceName);
            return <RoomMessage>[];
          }

          // Handle unexpected format (only log if truly unexpected)
          log('⚠️ [RoomService] Unexpected message data format: ${json.runtimeType}',
              name: serviceName);
          return <RoomMessage>[];
        },
      );

      // Handle response - data can be null or empty array
      if (response.success) {
        // Sort messages by created_at ascending (oldest first, newest last)
        // This ensures chronological order for display
        final messages = response.data ?? <RoomMessage>[];
        messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        // Log message order for debugging
        if (messages.isNotEmpty) {
          log('📅 [RoomService] Message order: oldest=${messages.first.createdAt}, newest=${messages.last.createdAt}',
              name: serviceName);
        }

        log('✅ [RoomService] Successfully fetched ${messages.length} messages for room: $roomId',
            name: serviceName);
        log('   Response status: ${response.statusCode ?? 200}',
            name: serviceName);
        log('   Response message: ${response.message ?? "Messages fetched successfully"}',
            name: serviceName);

        return ApiResponse.success(
          messages,
          message: response.message ?? 'Messages fetched successfully',
          statusCode: response.statusCode ?? 200,
        );
      } else {
        log('❌ [RoomService] Failed to fetch messages:', name: serviceName);
        log('   Error: ${response.error}', name: serviceName);
        log('   Status code: ${response.statusCode ?? "unknown"}',
            name: serviceName);
        return response;
      }
    } catch (e, stackTrace) {
      log('❌ [RoomService] Exception fetching messages: $e', name: serviceName);
      log('   Stack trace: $stackTrace', name: serviceName);
      return ApiResponse.error(
        'Failed to fetch messages: $e',
        statusCode: 0,
      );
    }
  }

  /// Mark all messages in a room as read for the current user
  ///
  /// POST /api/v1/rooms/{roomId}/read
  ///
  /// This endpoint:
  /// - Resets unread_count to 0 for the current user in the specified room
  /// - Backend automatically handles this when user opens chat (GetMessages also resets)
  /// - Can be called manually to mark as read without opening chat
  ///
  /// Response:
  /// {
  ///   "message": "Room marked as read",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  Future<ApiResponse<void>> markRoomAsRead(String roomId) async {
    try {
      log('📖 [RoomService] Marking room as read: $roomId', name: serviceName);

      final response = await post<void>(
        '/rooms/$roomId/read',
        data: {}, // Empty body - backend uses authenticated user from token
        fromJson: (_) => null, // No response data to parse
      );

      if (response.success) {
        log('✅ [RoomService] Room marked as read successfully: $roomId',
            name: serviceName);
      } else {
        log('❌ [RoomService] Failed to mark room as read: ${response.error}',
            name: serviceName);
      }

      return response;
    } catch (e, stackTrace) {
      log('❌ [RoomService] Exception marking room as read: $e',
          name: serviceName);
      log('   Stack trace: $stackTrace', name: serviceName);
      return ApiResponse.error(
        'Failed to mark room as read: $e',
        statusCode: 0,
      );
    }
  }

  /// Get rooms where user is a member (groups)
  ///
  /// GET /rooms/all?company_id=12345&chat_type=group&is_member=true
  ///
  /// ⚠️ IMPORTANT: This API returns ONLY rooms where the current user is already a member.
  /// This is NOT a discovery API. For browsing/discovery, use a different endpoint.
  ///
  /// Query Parameters:
  /// - company_id: The company/society ID (required)
  /// - chat_type: Filter by chat type - 'group' for groups, '1-1' for one-to-one chats (optional)
  /// - is_member: Filter by membership status - true to get only rooms where user is a member (default: true)
  ///
  /// Response:
  /// {
  ///   "data": [
  ///     {
  ///       "id": "9df6fa8c-5691-4953-8801-9d47bf84df38",
  ///       "name": "General Discussion",
  ///       "description": "A room for general discussions",
  ///       "created_by": "46bdcd14-f6f7-44fa-a335-7bff9d10f6b5",
  ///       "created_at": "2026-01-08T06:44:54.105491Z",
  ///       "updated_at": "2026-01-08T06:44:54.105491Z",
  ///       "last_active": "2026-01-08T06:44:54.105491Z"
  ///     }
  ///   ],
  ///   "message": "Rooms fetched successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  ///
  /// ⚠️ API already returns sorted by last_active DESC - DO NOT re-sort on frontend.
  Future<ApiResponse<List<Room>>> getAllRooms({
    int? companyId,
    String? chatType,
    bool isMember = true,
  }) async {
    try {
      log('Fetching all rooms${companyId != null ? ' for company_id: $companyId' : ''}${chatType != null ? ' with chat_type: $chatType' : ''}${isMember ? ' with is_member=true' : ''}',
          name: serviceName);

      // Build query parameters
      final queryParameters = <String, dynamic>{};
      if (companyId != null) {
        queryParameters['company_id'] = companyId;
        log('📋 [RoomService] Adding company_id=$companyId to query parameters',
            name: serviceName);
      } else {
        log('⚠️ [RoomService] WARNING: company_id is null - API call will not filter by company',
            name: serviceName);
      }

      if (chatType != null && chatType.isNotEmpty) {
        queryParameters['chat_type'] = chatType;
        log('📋 [RoomService] Adding chat_type=$chatType to query parameters',
            name: serviceName);
      }

      // Add is_member parameter (default: true)
      queryParameters['is_member'] = isMember;
      log('📋 [RoomService] Adding is_member=$isMember to query parameters',
          name: serviceName);

      // Log the full URL for debugging
      final fullUrl =
          '/rooms/all${queryParameters.isNotEmpty ? '?${queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&')}' : ''}';
      log('🌐 [RoomService] Making API call to: $fullUrl', name: serviceName);

      // Make API call to new endpoint /rooms/all
      final response = await get<List<Room>>(
        '/rooms/all',
        queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
        fromJson: (json) {
          // Handle null data (no rooms)
          if (json == null) {
            return <Room>[];
          }

          // Handle array of rooms
          if (json is List) {
            return json
                .map((item) => Room.fromJson(item as Map<String, dynamic>))
                .toList();
          }

          // Handle unexpected format
          log('Unexpected rooms data format: $json', name: serviceName);
          return <Room>[];
        },
      );

      if (response.success && response.data != null) {
        // API already returns sorted by last_active DESC
        // DO NOT re-sort - preserve backend order
        final rooms = response.data!;

        log('Fetched ${rooms.length} rooms (preserving API order)',
            name: serviceName);
        return ApiResponse.success(
          rooms,
          message: response.message ?? 'Rooms fetched successfully',
          statusCode: response.statusCode ?? 200,
        );
      } else {
        log('Failed to fetch rooms: ${response.error}', name: serviceName);
        return response;
      }
    } catch (e) {
      log('Exception fetching rooms: $e', name: serviceName);
      return ApiResponse.error(
        'Failed to fetch rooms: $e',
        statusCode: 0,
      );
    }
  }

  /// Create a 1-to-1 chat room and add the other party
  ///
  /// Flow:
  /// 1. POST /rooms (create room) - returns room_id (UUID)
  /// 2. POST /rooms/{roomId}/members (add the other party as member)
  ///
  /// API Format for adding members:
  /// POST /rooms/{roomId}/members
  /// {
  ///   "members": [
  ///     {
  ///       "user_id": 12345,
  ///       "name": "John Doe",
  ///       "phone": "+1234567890"
  ///     }
  ///   ]
  /// }
  ///
  /// Returns the UUID room_id that can be used for WebSocket connection
  Future<ApiResponse<String>> createOneToOneRoom({
    required String contactName,
    required String contactId, // Can be numeric or UUID
    required int companyId,
    String? contactPhone, // Phone number for the contact
  }) async {
    try {
      log('🚀 [RoomService] Creating 1-to-1 room for contact: $contactName (ID: $contactId)',
          name: serviceName);

      // Step 1: Create the room
      final roomName = contactName; // Use contact name as room name
      final createRequest = CreateRoomRequest(
        name: roomName,
        description: '1-to-1 chat with $contactName',
        companyId: companyId,
      );

      final createResponse = await createRoom(createRequest);

      if (!createResponse.success || createResponse.data == null) {
        log('❌ [RoomService] Failed to create 1-to-1 room: ${createResponse.error}',
            name: serviceName);
        log('   statusCode: ${createResponse.statusCode}, message: ${createResponse.message}',
            name: serviceName);
        return ApiResponse.error(
          createResponse.error ?? 'Failed to create room',
          statusCode: createResponse.statusCode ?? 0,
        );
      }

      final roomId = createResponse.data!.id;
      // Backend must return a valid UUID; Room.fromJson fallback can produce "unknown-..." if id is missing
      final isValidUuid = roomId.isNotEmpty &&
          roomId.contains('-') &&
          roomId.length >= 30 &&
          !roomId.startsWith('unknown-');
      if (!isValidUuid) {
        log('❌ [RoomService] Create returned invalid room id (backend may not have sent id): $roomId',
            name: serviceName);
        return ApiResponse.error(
          'Room created but invalid id returned (${roomId.length > 40 ? roomId.substring(0, 40) + "..." : roomId}). Please try again.',
          statusCode: createResponse.statusCode ?? 201,
        );
      }
      log('✅ [RoomService] 1-to-1 room created: $roomId', name: serviceName);

      // Step 2: Add the other party to the room using POST /rooms/{roomId}/members
      // Parse contactId to get numeric user_id
      int? userId;
      if (_isNumeric(contactId)) {
        userId = int.tryParse(contactId);
        if (userId == null) {
          log('⚠️ [RoomService] Contact ID is not a valid numeric ID: $contactId',
              name: serviceName);
          // Still return room_id - member can be added later
          return ApiResponse.success(
            roomId,
            message:
                'Room created, but failed to add member (invalid contact ID)',
            statusCode: 201,
          );
        }
      } else {
        log('⚠️ [RoomService] Contact ID is not numeric (UUID format): $contactId',
            name: serviceName);
        log('   Cannot use in members API which requires numeric user_id',
            name: serviceName);
        // Still return room_id - member might be added via UUID lookup or other method
        return ApiResponse.success(
          roomId,
          message: 'Room created, but member addition requires numeric user_id',
          statusCode: 201,
        );
      }

      // Prepare member data according to API specification
      final memberData = {
        'user_id': userId,
        'name': contactName,
        'phone': contactPhone ?? '', // Use provided phone or empty string
      };

      log('📝 [RoomService] Adding member to room: $roomId', name: serviceName);
      log('   Member data: user_id=$userId, name=$contactName, phone=${contactPhone ?? "not provided"}',
          name: serviceName);

      // Add member using the API endpoint
      final addMemberResponse = await addMembersToRoom(
        roomId: roomId,
        members: [memberData],
      );

      if (addMemberResponse.success) {
        log('✅ [RoomService] Successfully added member to 1-to-1 room: $roomId',
            name: serviceName);
        log('   Member: $contactName (user_id: $userId)', name: serviceName);
      } else {
        log('⚠️ [RoomService] Failed to add member to room, but room was created: ${addMemberResponse.error}',
            name: serviceName);
        log('   Room ID: $roomId - member can be added later',
            name: serviceName);
        // Don't fail - room is created, member addition can be retried
      }

      log('✅ [RoomService] 1-to-1 room creation complete: $roomId',
          name: serviceName);
      log('   Room name: $roomName', name: serviceName);
      log('   Contact: $contactName (ID: $contactId)', name: serviceName);
      log('   Room is ready for WebSocket connection', name: serviceName);

      return ApiResponse.success(
        roomId,
        message: '1-to-1 room created successfully',
        statusCode: 201,
      );
    } catch (e, stackTrace) {
      log('❌ [RoomService] Exception creating 1-to-1 room: $e',
          name: serviceName);
      log('   Stack trace: $stackTrace', name: serviceName);
      return ApiResponse.error(
        'Failed to create 1-to-1 room: $e',
        statusCode: 0,
      );
    }
  }

  /// Helper to check if a string is numeric
  bool _isNumeric(String? str) {
    if (str == null || str.isEmpty) return false;
    return int.tryParse(str) != null;
  }

  /// Forward an existing message to one or more rooms
  ///
  /// POST /messages/forward
  ///
  /// Request body:
  /// {
  ///   "message_id": "123e4567-e89b-12d3-a456-426614174000",
  ///   "target_room_ids": [
  ///     "223e4567-e89b-12d3-a456-426614174001",
  ///     ...
  ///   ]
  /// }
  ///
  /// Notes:
  /// - Backend caps target_room_ids at 5; we enforce the cap client-side.
  /// - Attachments are not re-uploaded; backend reuses existing file references.
  /// - Forwarding is blocked for deleted/view-once/restricted/system messages (handled server-side).
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

    try {
      log('🔁 [RoomService] Forwarding message $messageId to ${targetRoomIds.length} room(s)',
          name: serviceName);

      final response = await post<Map<String, dynamic>>(
        '/messages/forward',
        data: {
          'message_id': messageId,
          'target_room_ids': targetRoomIds,
          'is_forwarded':
              true, // So backend persists forwarded state in created message(s)
        },
        fromJson: (json) {
          if (json is Map<String, dynamic>) return json;
          if (json is Map) {
            return Map<String, dynamic>.from(
                json.map((key, value) => MapEntry(key.toString(), value)));
          }
          return <String, dynamic>{};
        },
      );

      if (response.success) {
        log('✅ [RoomService] Forwarded message $messageId successfully',
            name: serviceName);
      } else {
        log('❌ [RoomService] Forward failed: ${response.error}',
            name: serviceName);
      }

      return response;
    } catch (e, stackTrace) {
      log('❌ [RoomService] Exception forwarding message: $e',
          name: serviceName);
      log('   Stack: $stackTrace', name: serviceName);
      return ApiResponse.error(
        'Failed to forward message: $e',
        statusCode: 0,
      );
    }
  }

  /// Join a room (group)
  ///
  /// POST /rooms/join
  ///
  /// Request body:
  /// {
  ///   "room_id": "550e8400-e29b-41d4-a716-446655440000"
  /// }
  ///
  /// Response:
  /// {
  ///   "data": {
  ///     "room_id": "550e8400-e29b-41d4-a716-446655440000",
  ///     "is_member": true
  ///   },
  ///   "message": "Successfully joined room",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  Future<ApiResponse<Map<String, dynamic>>> joinRoom(String roomId) async {
    try {
      log('Joining room: $roomId', name: serviceName);

      // Make API call
      final response = await post<Map<String, dynamic>>(
        '/rooms/join',
        data: {
          'room_id': roomId,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        log('Successfully joined room: $roomId', name: serviceName);
      } else {
        log('Failed to join room: ${response.error}', name: serviceName);
      }

      return response;
    } catch (e) {
      log('Exception joining room: $e', name: serviceName);
      return ApiResponse.error(
        'Failed to join room: $e',
        statusCode: 0,
      );
    }
  }

  /// Leave a room (group)
  ///
  /// POST /rooms/leave
  ///
  /// Request body:
  /// {
  ///   "room_id": "c882fbeb-5b9f-4d0d-a947-dbb4252ac2a9"
  /// }
  ///
  /// Response:
  /// {
  ///   "data": {
  ///     "room_id": "c882fbeb-5b9f-4d0d-a947-dbb4252ac2a9"
  ///   },
  ///   "message": "Left room successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  Future<ApiResponse<Map<String, dynamic>>> leaveRoom(String roomId) async {
    try {
      log('Leaving room: $roomId', name: serviceName);

      // Make API call
      final response = await post<Map<String, dynamic>>(
        '/rooms/leave',
        data: {
          'room_id': roomId,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        log('Successfully left room: $roomId', name: serviceName);
      } else {
        log('Failed to leave room: ${response.error}', name: serviceName);
      }

      return response;
    } catch (e) {
      log('Exception leaving room: $e', name: serviceName);
      return ApiResponse.error(
        'Failed to leave room: $e',
        statusCode: 0,
      );
    }
  }

  /// Delete a room (group)
  ///
  /// DELETE /rooms/{roomId}
  ///
  /// Response:
  /// {
  ///   "data": { "room_id": "93b50116-22a7-4de5-9c88-f2d89369284c" },
  ///   "message": "Room deleted successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  Future<ApiResponse<Map<String, dynamic>>> deleteRoom(String roomId) async {
    try {
      log('Deleting room: $roomId', name: serviceName);

      // Make API call
      final response = await delete<Map<String, dynamic>>(
        '/rooms/$roomId',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success) {
        log('Room deleted successfully: $roomId', name: serviceName);
      } else {
        log('Failed to delete room: ${response.error}', name: serviceName);
      }

      return response;
    } catch (e) {
      log('Exception deleting room: $e', name: serviceName);
      return ApiResponse.error(
        'Failed to delete room: $e',
        statusCode: 0,
      );
    }
  }

  /// Get room info (group details)
  ///
  /// GET /rooms/{roomId}/info?company_id={companyId}
  ///
  /// Response:
  /// {
  ///   "data": {
  ///     "id": "string",
  ///     "name": "string",
  ///     "description": "string",
  ///     "created_by": "string",
  ///     "created_at": "ISODate",
  ///     "last_active": "ISODate",
  ///     "member_count": 0,
  ///     "admin": {
  ///       "username": "string",
  ///       "email": "string",
  ///       "user_id": "string"
  ///     },
  ///     "members": [
  ///       {
  ///         "user_id": "string",
  ///         "is_admin": false,
  ///         "joined_at": "ISODate"
  ///       }
  ///     ]
  ///   },
  ///   "message": "Room info fetched successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  Future<ApiResponse<RoomInfo>> getRoomInfo({
    required String roomId,
    int? companyId,
  }) async {
    try {
      log('Fetching room info for room: $roomId${companyId != null ? ' (company_id: $companyId)' : ''}',
          name: serviceName);

      // Build query parameters
      final queryParameters = <String, dynamic>{};
      if (companyId != null) {
        queryParameters['company_id'] = companyId;
      }

      // Make API call with longer timeout (room info can be heavy with many members)
      final response = await get<RoomInfo>(
        '/rooms/$roomId/info',
        queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
        options: Options(
          receiveTimeout:
              const Duration(seconds: 60), // Longer timeout for room info
        ),
        fromJson: (json) {
          // Safely handle the json parameter
          if (json == null) {
            log('⚠️ [RoomService] Room info response data is null',
                name: serviceName);
            throw Exception('Room info response data is null');
          }

          // Log the raw JSON structure for debugging
          log('📋 [RoomService] Raw JSON type: ${json.runtimeType}',
              name: serviceName);
          if (json is Map) {
            log('📋 [RoomService] JSON keys: ${json.keys.toList()}',
                name: serviceName);
          }

          // Handle case where json is already a Map
          if (json is Map<String, dynamic>) {
            log('✅ [RoomService] Parsing RoomInfo from Map<String, dynamic>',
                name: serviceName);
            return RoomInfo.fromJson(json);
          }

          // Handle case where json might be wrapped in another structure
          if (json is Map) {
            // Try to convert Map<dynamic, dynamic> to Map<String, dynamic>
            final convertedMap = <String, dynamic>{};
            json.forEach((key, value) {
              convertedMap[key.toString()] = value;
            });
            log('✅ [RoomService] Parsing RoomInfo from converted Map',
                name: serviceName);
            return RoomInfo.fromJson(convertedMap);
          }

          log('⚠️ [RoomService] Unexpected room info data type: ${json.runtimeType}',
              name: serviceName);
          throw Exception(
              'Unexpected room info response format: ${json.runtimeType}');
        },
      );

      if (response.success && response.data != null) {
        log('Room info fetched successfully: $roomId', name: serviceName);
        final roomInfo = response.data!;
        log('   Room name: ${roomInfo.name}', name: serviceName);
        log('   Member count: ${roomInfo.memberCount}', name: serviceName);
        for (final member in roomInfo.members) {
          log('   Member: ${member.username ?? "Unknown"} (ID: ${member.userId}), Avatar: ${member.avatar ?? "null"}',
              name: serviceName);
        }
      } else {
        log('Failed to fetch room info: ${response.error}', name: serviceName);
      }

      return response;
    } catch (e) {
      log('Exception fetching room info: $e', name: serviceName);
      return ApiResponse.error(
        'Failed to fetch room info: $e',
        statusCode: 0,
      );
    }
  }

  /// Upload room photo using file (multipart/form-data)
  ///
  /// POST /rooms/{roomId}/photo
  ///
  /// Content-Type: multipart/form-data
  ///
  /// Request body (multipart):
  /// - photo: File (jpeg/png)
  /// - is_primary: boolean (default: false)
  ///
  /// Response (201):
  /// {
  ///   "data": {
  ///     "photo_url": "...",
  ///     "is_primary": false
  ///   },
  ///   "message": "Photo uploaded successfully",
  ///   "status": "success",
  ///   "status_code": 201
  /// }
  Future<ApiResponse<Map<String, dynamic>>> uploadRoomPhotoFile({
    required String roomId,
    required File photoFile,
    bool isPrimary = false,
  }) async {
    try {
      log('Uploading photo file for room: $roomId', name: serviceName);

      // Validate file exists
      if (!await photoFile.exists()) {
        log('⚠️ [RoomService] Photo file does not exist: ${photoFile.path}',
            name: serviceName);
        return ApiResponse.error(
          'Photo file does not exist',
          statusCode: 400,
        );
      }

      // Validate file size
      final fileSize = await photoFile.length();
      if (fileSize == 0) {
        log('⚠️ [RoomService] Photo file is empty: ${photoFile.path}',
            name: serviceName);
        return ApiResponse.error(
          'Photo file is empty',
          statusCode: 400,
        );
      }

      // Validate file extension
      final fileName = photoFile.path.split('/').last;
      final fileExtension = fileName.split('.').last.toLowerCase();
      if (fileExtension != 'jpg' &&
          fileExtension != 'jpeg' &&
          fileExtension != 'png') {
        log('⚠️ [RoomService] Invalid file extension: $fileExtension',
            name: serviceName);
        return ApiResponse.error(
          'Invalid file type. Only JPEG and PNG images are allowed.',
          statusCode: 400,
        );
      }

      log('📤 [RoomService] Uploading file: $fileName (${(fileSize / 1024).toStringAsFixed(2)} KB)',
          name: serviceName);

      // Create multipart form data
      // Note: is_primary should be sent as a string "true" or "false" to match curl format
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          photoFile.path,
          filename: fileName,
        ),
        'is_primary': isPrimary ? 'true' : 'false',
      });

      // Get auth headers
      final authHeaders = await getAuthHeaders();

      // Make API call using Dio directly for multipart
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout:
            const Duration(seconds: 60), // Longer timeout for uploads
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          ...authHeaders,
          'Accept': 'application/json',
          // Don't set Content-Type - Dio will set it automatically for multipart
        },
        // Configure validateStatus to not throw for 400, we'll handle it manually
        validateStatus: (status) {
          return status != null &&
              status < 500; // Don't throw for 4xx, only 5xx
        },
      ));

      // Add interceptors for logging
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            log('→ POST ${options.uri}', name: serviceName);
            log('→ Headers: ${options.headers}', name: serviceName);
            log('→ Form fields: ${formData.fields}', name: serviceName);
            log('→ Form files: ${formData.files.map((f) => f.key).toList()}',
                name: serviceName);
            handler.next(options);
          },
          onResponse: (response, handler) {
            log('← ${response.statusCode} ${response.requestOptions.uri}',
                name: serviceName);
            log('← Response data: ${response.data}', name: serviceName);
            handler.next(response);
          },
          onError: (error, handler) {
            log('✗ ${error.type} ${error.requestOptions.uri}',
                name: serviceName);
            if (error.response != null) {
              log('✗ Error response: ${error.response?.data}',
                  name: serviceName);
              log('✗ Error status: ${error.response?.statusCode}',
                  name: serviceName);
              log('✗ Error headers: ${error.response?.headers}',
                  name: serviceName);
            }
            handler.next(error);
          },
        ),
      );

      try {
        final response = await dio.post<Map<String, dynamic>>(
          '/rooms/$roomId/photo',
          data: formData,
          // Don't set contentType explicitly - Dio will set it automatically with boundary for multipart
          // validateStatus is already set in BaseOptions to handle 4xx responses
        );

        // Parse response
        if (response.statusCode == 201 && response.data != null) {
          final data = response.data!;
          log('✅ [RoomService] Photo uploaded successfully for room: $roomId',
              name: serviceName);
          return ApiResponse.success(
            data,
            message:
                data['message'] as String? ?? 'Photo uploaded successfully',
            statusCode: 201,
          );
        } else if (response.statusCode == 400) {
          // Handle 400 Bad Request
          final errorData = response.data;
          String errorMessage = 'Failed to upload photo';

          if (errorData is Map<String, dynamic>) {
            errorMessage = errorData['message'] as String? ??
                errorData['error'] as String? ??
                errorMessage;
            log('⚠️ [RoomService] 400 Bad Request: $errorMessage',
                name: serviceName);
          } else {
            log('⚠️ [RoomService] 400 Bad Request: ${errorData.toString()}',
                name: serviceName);
          }

          return ApiResponse.error(
            errorMessage,
            statusCode: 400,
          );
        } else {
          log('⚠️ [RoomService] Photo upload failed: ${response.statusCode}',
              name: serviceName);
          return ApiResponse.error(
            'Failed to upload photo',
            statusCode: response.statusCode,
          );
        }
      } on DioException catch (e) {
        // Handle DioException specifically
        log('⚠️ [RoomService] DioException: ${e.type}', name: serviceName);

        if (e.response != null) {
          final statusCode = e.response!.statusCode;
          final errorData = e.response!.data;
          String errorMessage = 'Failed to upload photo';

          if (errorData is Map<String, dynamic>) {
            errorMessage = errorData['message'] as String? ??
                errorData['error'] as String? ??
                errorMessage;
          }

          log('⚠️ [RoomService] Error response ($statusCode): $errorMessage',
              name: serviceName);

          return ApiResponse.error(
            errorMessage,
            statusCode: statusCode,
          );
        } else {
          log('⚠️ [RoomService] DioException without response: ${e.message}',
              name: serviceName);
          return ApiResponse.error(
            'Failed to upload photo: ${e.message}',
            statusCode: 0,
          );
        }
      }
    } catch (e) {
      log('⚠️ [RoomService] Photo upload exception: $e', name: serviceName);
      return ApiResponse.error(
        'Failed to upload photo: $e',
        statusCode: 0,
      );
    }
  }

  /// Upload room photo using image URL (JSON)
  ///
  /// POST /rooms/{roomId}/photo?company_id={companyId}
  ///
  /// Content-Type: application/json
  ///
  /// Request body (JSON):
  /// {
  ///   "image_url": "https://...",
  ///   "is_primary": true
  /// }
  ///
  /// Response (201):
  /// {
  ///   "data": {
  ///     "photo_url": "...",
  ///     "is_primary": false
  ///   },
  ///   "message": "Photo uploaded successfully",
  ///   "status": "success",
  ///   "status_code": 201
  /// }
  ///
  /// ⚠️ This method is designed to fail silently - it does not throw exceptions.
  /// Call this AFTER room creation succeeds. If upload fails, group creation
  /// should still be considered successful.
  Future<ApiResponse<Map<String, dynamic>>> uploadRoomPhoto({
    required String roomId,
    required String imageUrl,
    required int companyId,
    bool isPrimary = false,
  }) async {
    try {
      log('Uploading photo for room: $roomId with image_url: $imageUrl',
          name: serviceName);

      // Validate image URL
      if (imageUrl.isEmpty) {
        log('⚠️ [RoomService] Image URL is empty', name: serviceName);
        return ApiResponse.error(
          'Image URL is required',
          statusCode: 400,
        );
      }

      // Build query parameters
      final queryParameters = <String, dynamic>{
        'company_id': companyId,
      };

      // Make API call using base service POST method
      final response = await post<Map<String, dynamic>>(
        '/rooms/$roomId/photo',
        data: {
          'image_url': imageUrl,
          'is_primary': isPrimary,
        },
        queryParameters: queryParameters,
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success) {
        log('✅ [RoomService] Photo uploaded successfully for room: $roomId',
            name: serviceName);
      } else {
        log('⚠️ [RoomService] Photo upload failed: ${response.error}',
            name: serviceName);
      }

      return response;
    } catch (e) {
      // Silent failure - just log, don't throw
      log('⚠️ [RoomService] Photo upload exception (silent): $e',
          name: serviceName);
      return ApiResponse.error(
        'Failed to upload photo: $e',
        statusCode: 0,
      );
    }
  }

  /// Edit a message
  ///
  /// PUT /messages/{messageId}
  ///
  /// Request body:
  /// {
  ///   "content": "Updated message text"
  /// }
  ///
  /// Response (200):
  /// {
  ///   "data": {
  ///     "id": "string",
  ///     "room_id": "string",
  ///     "sender_id": "string",
  ///     "sender_name": "string",
  ///     "body": "Updated message text",
  ///     "created_at": "ISODate",
  ///     "edited_at": "ISODate",
  ///     "updated_at": "ISODate"
  ///   },
  ///   "message": "Message updated successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  Future<ApiResponse<RoomMessage>> editMessage({
    required String messageId,
    required String content,
  }) async {
    try {
      log('Editing message: $messageId', name: serviceName);

      // Make API call
      final response = await put<RoomMessage>(
        '/messages/$messageId',
        data: {
          'content': content,
        },
        fromJson: (json) {
          if (json == null) {
            throw Exception('Response data is null');
          }
          return RoomMessage.fromJson(json as Map<String, dynamic>);
        },
      );

      if (response.success && response.data != null) {
        log('✅ Message edited successfully: $messageId', name: serviceName);
      } else {
        log('❌ Failed to edit message: ${response.error}', name: serviceName);
      }

      return response;
    } catch (e) {
      log('❌ Exception editing message: $e', name: serviceName);
      return ApiResponse.error(
        'Failed to edit message: $e',
        statusCode: 0,
      );
    }
  }

  /// Delete a message (soft delete)
  ///
  /// DELETE /messages/{messageId}
  ///
  /// Response (200):
  /// {
  ///   "data": {
  ///     "id": "string",
  ///     "is_deleted": true,
  ///     "deleted_at": "ISODate",
  ///     "deleted_by": "user_id"
  ///   },
  ///   "message": "Message deleted successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  Future<ApiResponse<RoomMessage>> deleteMessage({
    required String messageId,
  }) async {
    try {
      log('Deleting message: $messageId', name: serviceName);

      // Make API call
      final response = await delete<RoomMessage>(
        '/messages/$messageId',
        fromJson: (json) {
          if (json == null) {
            throw Exception('Response data is null');
          }
          return RoomMessage.fromJson(json as Map<String, dynamic>);
        },
      );

      if (response.success && response.data != null) {
        log('✅ Message deleted successfully: $messageId', name: serviceName);
      } else {
        log('❌ Failed to delete message: ${response.error}', name: serviceName);
      }

      return response;
    } catch (e) {
      log('❌ Exception deleting message: $e', name: serviceName);
      return ApiResponse.error(
        'Failed to delete message: $e',
        statusCode: 0,
      );
    }
  }

  /// Add members to a room (group)
  ///
  /// POST /rooms/{roomId}/members
  ///
  /// Request body:
  /// {
  ///   "members": [
  ///     {
  ///       "user_id": 12345,
  ///       "name": "John Doe",
  ///       "phone": "+1234567890"
  ///     }
  ///   ]
  /// }
  ///
  /// Response (200):
  /// {
  ///   "data": null,
  ///   "message": "Members added successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  ///
  /// ⚠️ Important:
  /// - Partial success supported (some members may fail)
  /// - Do NOT fail the whole flow if one member fails
  /// - API handles deduplication and validation
  /// - Creator is already a member (don't add again)
  Future<ApiResponse<void>> addMembersToRoom({
    required String roomId,
    required List<Map<String, dynamic>> members,
  }) async {
    try {
      if (members.isEmpty) {
        log('⚠️ [RoomService] Empty member list, skipping addMembersToRoom',
            name: serviceName);
        return ApiResponse.success(
          null,
          message: 'No members to add',
          statusCode: 200,
        );
      }

      log('Adding ${members.length} members to room: $roomId',
          name: serviceName);

      // Make API call
      final response = await post<void>(
        '/rooms/$roomId/members',
        data: {
          'members': members,
        },
        fromJson: (json) => null, // No response data to parse
      );

      if (response.success) {
        log('✅ Successfully added members to room: $roomId', name: serviceName);
        log('   Added ${members.length} members', name: serviceName);
      } else {
        // SPECIAL HANDLING: 409 "Already a member" should be treated as success
        // BACKEND FIX: Backend now filters by status='active' when checking membership
        // Inactive members being re-added will be reactivated automatically (not 409)
        // 409 only occurs for already-active members, which is idempotent behavior
        if (response.statusCode == 409 &&
            response.error?.toLowerCase().contains('already') == true) {
          log('✅ Member already exists in room (409 treated as success): $roomId',
              name: serviceName);
          // Return success instead of error for 409 "Already a member"
          return ApiResponse.success(
            null,
            message: 'Members processed (some were already members)',
            statusCode: 409, // Keep original status code for transparency
          );
        } else {
          log('⚠️ Failed to add some members: ${response.error}',
              name: serviceName);
          // Don't throw - partial success is acceptable for other errors
        }
      }

      return response;
    } catch (e) {
      log('⚠️ Exception adding members to room (non-blocking): $e',
          name: serviceName);
      // Return error but don't throw - group creation should still succeed
      return ApiResponse.error(
        'Failed to add members: $e',
        statusCode: 0,
      );
    }
  }

  /// Remove a member from a room (group)
  ///
  /// DELETE /api/v1/rooms/{roomId}/members/{userId}
  ///
  /// Headers:
  /// Authorization: Bearer <access_token>
  ///
  /// Body: NONE
  ///
  /// Response (200):
  /// {
  ///   "data": null,
  ///   "message": "Member removed from room",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  ///
  /// ⚠️ Important:
  /// - Removes member from the room
  /// - Member must already exist in the room
  /// - `userId` is the member's UUID you get from GET /rooms/{roomId}/info
  /// - Only admins allowed (backend enforced)
  Future<ApiResponse<void>> removeRoomMember({
    required String roomId,
    required String userId,
  }) async {
    try {
      log('Removing member $userId from room: $roomId', name: serviceName);

      // Make API call
      final response = await delete<void>(
        '/rooms/$roomId/members/$userId',
        fromJson: (json) => null, // No response data to parse
      );

      if (response.success) {
        log('✅ Member $userId removed successfully from room: $roomId',
            name: serviceName);
      } else {
        log('❌ Failed to remove member $userId: ${response.error}',
            name: serviceName);
      }

      return response;
    } catch (e) {
      log('❌ Exception removing member $userId: $e', name: serviceName);
      return ApiResponse.error(
        'Failed to remove member: $e',
        statusCode: 0,
      );
    }
  }

  /// Update a room member's metadata (name/phone only)
  ///
  /// PUT /api/v1/rooms/{roomId}/members/{userId}
  ///
  /// Request body:
  /// {
  ///   "name": "John Updated",
  ///   "phone": "+1234567899"
  /// }
  ///
  /// Response (200):
  /// {
  ///   "data": null,
  ///   "message": "Member details updated",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  ///
  /// ⚠️ Important:
  /// - Updates only existing member metadata (name/phone)
  /// - Member must already exist in the room
  /// - userId must be numeric (int)
  Future<ApiResponse<void>> updateRoomMember({
    required String roomId,
    required int userId,
    required String name,
    required String phone,
  }) async {
    try {
      log('Updating member $userId in room: $roomId', name: serviceName);
      log('   Name: $name, Phone: $phone', name: serviceName);

      // Validate inputs
      if (name.trim().isEmpty) {
        log('⚠️ [RoomService] Member name is empty', name: serviceName);
        return ApiResponse.error(
          'Member name is required',
          statusCode: 400,
        );
      }

      // Make API call
      final response = await put<void>(
        '/rooms/$roomId/members/$userId',
        data: {
          'name': name.trim(),
          'phone': phone.trim(),
        },
        fromJson: (json) => null, // No response data to parse
      );

      if (response.success) {
        log('✅ Member $userId updated successfully in room: $roomId',
            name: serviceName);
      } else {
        log('❌ Failed to update member $userId: ${response.error}',
            name: serviceName);
      }

      return response;
    } catch (e) {
      log('❌ Exception updating member $userId: $e', name: serviceName);
      return ApiResponse.error(
        'Failed to update member: $e',
        statusCode: 0,
      );
    }
  }

  /// Clear chat for a room (user-specific)
  ///
  /// POST /rooms/clear?company_id={companyId}
  ///
  /// Request body:
  /// {
  ///   "room_id": "550e8400-e29b-41d4-a716-446655440000"
  /// }
  ///
  /// Response (200):
  /// {
  ///   "data": null,
  ///   "message": "Chat cleared successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  ///
  /// ⚠️ Important: This clears chat only for the current user.
  /// Other members will still see their chat history.
  /// WebSocket connection should remain active.
  Future<ApiResponse<void>> clearChat({
    required String roomId,
    required int companyId,
  }) async {
    try {
      log('Clearing chat for room: $roomId (company_id: $companyId)',
          name: serviceName);

      // Make API call
      final response = await post<void>(
        '/rooms/clear',
        queryParameters: {
          'company_id': companyId,
        },
        data: {
          'room_id': roomId,
        },
        fromJson: (json) => null, // No response data to parse
      );

      if (response.success) {
        log('✅ Chat cleared successfully for room: $roomId', name: serviceName);
      } else {
        log('❌ Failed to clear chat: ${response.error}', name: serviceName);
      }

      return response;
    } catch (e) {
      log('❌ Exception clearing chat: $e', name: serviceName);
      return ApiResponse.error(
        'Failed to clear chat: $e',
        statusCode: 0,
      );
    }
  }

  /// Add a reaction to a message
  ///
  /// POST /api/v1/messages/{messageId}/reactions
  ///
  /// Headers:
  /// Authorization: Bearer <access_token>
  ///
  /// Request body:
  /// {
  ///   "reaction_type": "like"
  /// }
  ///
  /// Response (200):
  /// {
  ///   "data": {
  ///     "id": "string",
  ///     "message_id": "string",
  ///     "user_id": "string",
  ///     "reaction_type": "like"
  ///   },
  ///   "message": "Reaction added successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  ///
  /// ⚠️ Important:
  /// - One reaction per tap
  /// - Backend handles duplicate reactions (update/replace)
  /// - Allow reacting to own message
  /// - Fails silently on network errors (no UI crash)
  Future<ApiResponse<MessageReaction>> addReaction({
    required String messageId,
    required String reactionType,
  }) async {
    try {
      log('Adding reaction: $reactionType to message: $messageId',
          name: serviceName);

      // Validate reaction_type
      // We now allow any string (emoji) as reaction type
      if (reactionType.trim().isEmpty) {
        log('⚠️ [RoomService] Empty reaction_type', name: serviceName);
        return ApiResponse.error(
          'Reaction type cannot be empty',
          statusCode: 400,
        );
      }

      // Make API call
      final response = await post<MessageReaction>(
        '/messages/$messageId/reactions',
        data: {
          'reaction_type': reactionType,
        },
        fromJson: (json) {
          if (json == null) {
            throw Exception('Response data is null');
          }
          return MessageReaction.fromJson(json as Map<String, dynamic>);
        },
      );

      if (response.success && response.data != null) {
        log('✅ Reaction added successfully: $reactionType → message $messageId',
            name: serviceName);
      } else {
        log('❌ Failed to add reaction: ${response.error}', name: serviceName);
      }

      return response;
    } catch (e) {
      log('❌ Exception adding reaction: $e', name: serviceName);
      // Fail silently - don't crash UI
      return ApiResponse.error(
        'Failed to add reaction: $e',
        statusCode: 0,
      );
    }
  }

  /// Get reactions for a message
  ///
  /// GET /api/v1/messages/{messageId}/reactions
  ///
  /// Headers:
  /// Authorization: Bearer <access_token>
  ///
  /// Response (200):
  /// {
  ///   "data": [
  ///     {
  ///       "id": "string",
  ///       "message_id": "string",
  ///       "user_id": "string",
  ///       "reaction_type": "like",
  ///       "user_name": "string"
  ///     }
  ///   ],
  ///   "message": "Reactions fetched successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  ///
  /// ⚠️ Important:
  /// - Fetch only when needed (not on every scroll)
  /// - Cache reactions inside message object
  /// - Refresh only on reaction add/remove or initial load
  Future<ApiResponse<List<MessageReaction>>> getMessageReactions({
    required String messageId,
  }) async {
    try {
      log('Fetching reactions for message: $messageId', name: serviceName);

      // Make API call
      final response = await get<List<MessageReaction>>(
        '/messages/$messageId/reactions',
        fromJson: (json) {
          // Handle null data (no reactions)
          if (json == null) {
            return <MessageReaction>[];
          }

          // Handle array of reactions
          if (json is List) {
            return json
                .map((item) {
                  try {
                    if (item is Map<String, dynamic>) {
                      return MessageReaction.fromJson(item);
                    } else {
                      log('⚠️ [RoomService] Invalid reaction item format: $item',
                          name: serviceName);
                      return null;
                    }
                  } catch (e, stackTrace) {
                    log('❌ [RoomService] Error parsing reaction item: $e',
                        name: serviceName, error: e, stackTrace: stackTrace);
                    return null;
                  }
                })
                .whereType<MessageReaction>() // Filter out null values
                .toList();
          }

          // Handle unexpected format
          log('⚠️ [RoomService] Unexpected reactions data format: $json',
              name: serviceName);
          return <MessageReaction>[];
        },
      );

      if (response.success && response.data != null) {
        log('✅ Fetched ${response.data!.length} reactions for message: $messageId',
            name: serviceName);
      } else {
        log('❌ Failed to fetch reactions: ${response.error}',
            name: serviceName);
      }

      return response;
    } catch (e) {
      log('❌ Exception fetching reactions: $e', name: serviceName);
      // Fail silently - don't crash UI
      return ApiResponse.error(
        'Failed to fetch reactions: $e',
        statusCode: 0,
      );
    }
  }

  /// Update an existing reaction for a message
  ///
  /// PUT /api/v1/messages/{messageId}/reactions
  ///
  /// Headers:
  /// Authorization: Bearer <access_token>
  ///
  /// Request body:
  /// {
  ///   "reaction_type": "love"
  /// }
  ///
  /// Response (200):
  /// {
  ///   "data": {
  ///     "id": "string",
  ///     "message_id": "string",
  ///     "user_id": "string",
  ///     "reaction_type": "love",
  ///     "user_name": "string"
  ///   },
  ///   "message": "Reaction updated successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  ///
  /// ⚠️ Important:
  /// - Only call this if user has already reacted to the message
  /// - Updates the same reaction record (same reaction_id)
  /// - Reaction icon switches (👍 → ❤️), not duplicated
  /// - One user → one reaction per message
  Future<ApiResponse<MessageReaction>> updateReaction({
    required String messageId,
    required String reactionType,
  }) async {
    try {
      log('Updating reaction: $reactionType for message: $messageId',
          name: serviceName);

      // Validate reaction_type
      // We now allow any string (emoji) as reaction type
      if (reactionType.trim().isEmpty) {
        log('⚠️ [RoomService] Empty reaction_type', name: serviceName);
        return ApiResponse.error(
          'Reaction type cannot be empty',
          statusCode: 400,
        );
      }

      // Make API call - PUT /api/v1/messages/{messageId}/reactions
      // Endpoint: /messages/$messageId/reactions (baseUrl already includes /api/v1)
      // Body: { "reaction_type": "love" }
      final response = await put<MessageReaction>(
        '/messages/$messageId/reactions',
        data: {
          'reaction_type': reactionType,
        },
        fromJson: (json) {
          if (json == null) {
            throw Exception('Response data is null');
          }
          return MessageReaction.fromJson(json as Map<String, dynamic>);
        },
      );

      if (response.success && response.data != null) {
        log('✅ Reaction updated successfully: $reactionType → message $messageId',
            name: serviceName);
        log('   Updated reaction: ${response.data!.reactionType} by user ${response.data!.userId}',
            name: serviceName);
      } else {
        log('❌ Failed to update reaction: ${response.error}',
            name: serviceName);
        log('   Status code: ${response.statusCode}', name: serviceName);
      }

      return response;
    } catch (e) {
      log('❌ Exception updating reaction: $e', name: serviceName);
      // Fail silently - don't crash UI
      return ApiResponse.error(
        'Failed to update reaction: $e',
        statusCode: 0,
      );
    }
  }

  /// Delete a reaction for a message
  ///
  /// DELETE /api/v1/messages/{messageId}/reactions
  ///
  /// Headers:
  /// Authorization: Bearer <access_token>
  ///
  /// Body: NONE
  ///
  /// Response (200):
  /// {
  ///   "data": {
  ///     "message_id": "496c2ce8-7c45-49c4-b08d-f56127ee03ea"
  ///   },
  ///   "message": "Reaction deleted successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  ///
  /// ⚠️ Important:
  /// - Only call this when user taps ❌ on their existing reaction
  /// - Backend scopes deletion to authenticated user automatically
  /// - No soft-delete - reaction is fully removed
  /// - If no reactions left, UI should hide reaction container
  Future<ApiResponse<Map<String, dynamic>>> deleteReaction({
    required String messageId,
  }) async {
    try {
      log('Deleting reaction for message: $messageId', name: serviceName);

      // Make API call - no body needed
      final response = await delete<Map<String, dynamic>>(
        '/messages/$messageId/reactions',
        fromJson: (json) {
          if (json == null) {
            return <String, dynamic>{};
          }
          return json as Map<String, dynamic>;
        },
      );

      if (response.success) {
        log('✅ Reaction deleted successfully for message: $messageId',
            name: serviceName);
      } else {
        log('❌ Failed to delete reaction: ${response.error}',
            name: serviceName);
      }

      return response;
    } catch (e) {
      log('❌ Exception deleting reaction: $e', name: serviceName);
      // Fail silently - don't crash UI
      return ApiResponse.error(
        'Failed to delete reaction: $e',
        statusCode: 0,
      );
    }
  }

  /// Upload file/image to S3 via API
  ///
  /// POST /api/v1/rooms/{roomId}/messages/file
  ///
  /// Headers:
  /// - Authorization: Bearer {token}
  ///
  /// Request (multipart/form-data):
  /// - file: File to upload (required)
  /// - content: Optional caption text
  ///
  /// Response (200/201):
  /// Direct format:
  /// {
  ///   "file_url": "https://s3.amazonaws.com/bucket/path/file.jpg",
  ///   "file_key": "path/file.jpg",
  ///   "mime_type": "image/jpeg",
  ///   "size": 123456
  /// }
  ///
  /// Or wrapped format:
  /// {
  ///   "data": {
  ///     "file_url": "https://s3.amazonaws.com/bucket/path/file.jpg",
  ///     "file_key": "path/file.jpg",
  ///     "mime_type": "image/jpeg",
  ///     "size": 123456
  ///   },
  ///   "message": "File uploaded successfully",
  ///   "status": "success"
  /// }
  Future<ApiResponse<Map<String, dynamic>>> uploadFileToS3({
    required String roomId,
    required File file,
    String? content,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      log('📤 [RoomService] Uploading file to S3 for room: $roomId',
          name: serviceName);

      // Validate file exists
      if (!await file.exists()) {
        log('⚠️ [RoomService] File does not exist: ${file.path}',
            name: serviceName);
        return ApiResponse.error(
          'File does not exist',
          statusCode: 400,
        );
      }

      // Validate file size
      final fileSize = await file.length();
      if (fileSize == 0) {
        log('⚠️ [RoomService] File is empty: ${file.path}', name: serviceName);
        return ApiResponse.error(
          'File is empty',
          statusCode: 400,
        );
      }

      final fileName = file.path.split('/').last;
      log('📤 [RoomService] Uploading file: $fileName (${(fileSize / 1024).toStringAsFixed(2)} KB)',
          name: serviceName);

      // Create multipart form data
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
        if (content != null && content.isNotEmpty) 'content': content,
      });

      // Get auth headers (includes Authorization: Bearer token)
      final authHeaders = await getAuthHeaders();

      // Create Dio instance for this upload (to handle multipart properly)
      // Use the same base configuration as the service
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Accept': 'application/json',
          ...authHeaders, // This includes Authorization: Bearer {token}
          // Don't set Content-Type - Dio will set it automatically with boundary for multipart
        },
      ));

      // Add interceptors for logging
      dio.interceptors.add(NetworkLoggingInterceptor(clientTag: serviceName));

      try {
        final response = await dio.post<Map<String, dynamic>>(
          '/rooms/$roomId/messages/file',
          data: formData,
          onSendProgress: onSendProgress,
          // Don't set contentType explicitly - Dio will set it automatically with boundary for multipart
        );

        // Parse response
        // API may return 200 or 201 for success
        if ((response.statusCode == 200 || response.statusCode == 201) &&
            response.data != null) {
          final responseData = response.data!;

          // Handle different response formats:
          // 1. Direct format: { "file_url": "...", "file_key": "...", ... }
          // 2. Wrapped format: { "data": { "file_url": "...", ... }, "message": "...", "status": "success" }
          Map<String, dynamic> data;
          final dataField = responseData['data'];
          if (dataField != null && dataField is Map) {
            // Wrapped format
            data = Map<String, dynamic>.from(dataField);
          } else {
            // Direct format - responseData is already Map<String, dynamic>
            data = responseData;
          }

          // Transform localhost URLs to proper server URLs
          if (data['file_url'] != null && data['file_url'] is String) {
            final originalUrl = data['file_url'] as String;
            final transformedUrl = transformLocalhostUrl(originalUrl);
            if (transformedUrl != originalUrl) {
              data['file_url'] = transformedUrl;
              log('🔄 [RoomService] Transformed file_url from localhost to server URL',
                  name: serviceName);
            }
          }

          // If file_url is missing or empty, try to construct from file_key
          final fileUrlValue = data['file_url'] as String?;
          if ((fileUrlValue == null || fileUrlValue.isEmpty) &&
              data['file_key'] != null &&
              data['file_key'] is String) {
            final fileKeyValue = data['file_key'] as String;
            final constructedUrl = constructFileUrlFromKey(fileKeyValue);
            if (constructedUrl != null) {
              data['file_url'] = constructedUrl;
              log('🔧 [RoomService] Constructed file_url from file_key',
                  name: serviceName);
            }
          }

          log('✅ [RoomService] File uploaded successfully to S3 for room: $roomId',
              name: serviceName);
          log('   File URL: ${data['file_url']}', name: serviceName);
          log('   File Key: ${data['file_key']}', name: serviceName);
          log('   MIME Type: ${data['mime_type']}', name: serviceName);
          log('   Size: ${data['size']}', name: serviceName);

          return ApiResponse.success(
            data,
            message: responseData['message'] as String? ??
                'File uploaded successfully',
            statusCode: response.statusCode,
          );
        } else if (response.statusCode == 400) {
          // Handle 400 Bad Request
          final errorData = response.data;
          String errorMessage = 'Failed to upload file';

          if (errorData is Map<String, dynamic>) {
            errorMessage = errorData['message'] as String? ??
                errorData['error'] as String? ??
                errorMessage;
            log('⚠️ [RoomService] 400 Bad Request: $errorMessage',
                name: serviceName);
          } else {
            log('⚠️ [RoomService] 400 Bad Request: ${errorData.toString()}',
                name: serviceName);
          }

          return ApiResponse.error(
            errorMessage,
            statusCode: 400,
          );
        } else {
          log('⚠️ [RoomService] File upload failed: ${response.statusCode}',
              name: serviceName);
          return ApiResponse.error(
            'Failed to upload file',
            statusCode: response.statusCode,
          );
        }
      } on DioException catch (e) {
        // Handle DioException specifically
        log('⚠️ [RoomService] DioException: ${e.type}', name: serviceName);
        if (e.response != null) {
          log('   Status: ${e.response!.statusCode}', name: serviceName);
          log('   Data: ${e.response!.data}', name: serviceName);

          final errorData = e.response!.data;
          String errorMessage = 'Failed to upload file';

          if (errorData is Map<String, dynamic>) {
            errorMessage = errorData['message'] as String? ??
                errorData['error'] as String? ??
                errorMessage;
          }

          return ApiResponse.error(
            errorMessage,
            statusCode: e.response!.statusCode,
          );
        } else {
          log('   Error: ${e.message}', name: serviceName);
          return ApiResponse.error(
            'Network error: ${e.message}',
            statusCode: 0,
          );
        }
      }
    } catch (e) {
      log('❌ [RoomService] Exception uploading file: $e', name: serviceName);
      return ApiResponse.error(
        'Failed to upload file: $e',
        statusCode: 0,
      );
    }
  }

  /// Get read receipts for a specific message
  ///
  /// GET /api/v1/messages/{messageId}/read-receipts
  ///
  /// This endpoint returns a list of users who have read the message.
  ///
  /// Response:
  /// {
  ///   "data": [
  ///     {
  ///       "user_id": "string",
  ///       "user_name": "string",
  ///       "read_at": "2026-01-29T12:00:00Z"
  ///     }
  ///   ],
  ///   "message": "Read receipts fetched successfully",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  ///
  /// Example curl:
  /// curl --location 'http://13.201.27.102:7071/api/v1/messages/{messageId}/read-receipts' \
  /// --header 'Authorization: Bearer {token}'
  Future<ApiResponse<List<Map<String, dynamic>>>> getReadReceipts(
      String messageId) async {
    try {
      log('📖 [RoomService] Fetching read receipts for message: $messageId',
          name: serviceName);

      final response = await get<List<Map<String, dynamic>>>(
        '/messages/$messageId/read-receipts',
        fromJson: (json) {
          // Handle null data (no read receipts)
          if (json == null) {
            return <Map<String, dynamic>>[];
          }

          // Handle array of read receipts
          if (json is List) {
            return json
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    return item;
                  } else if (item is Map) {
                    return Map<String, dynamic>.from(item
                        .map((key, value) => MapEntry(key.toString(), value)));
                  }
                  return null;
                })
                .whereType<Map<String, dynamic>>()
                .toList();
          }

          // Handle unexpected format
          log('⚠️ [RoomService] Unexpected read receipts data format: ${json.runtimeType}',
              name: serviceName);
          return <Map<String, dynamic>>[];
        },
      );

      if (response.success) {
        final receipts = response.data ?? <Map<String, dynamic>>[];
        log('✅ [RoomService] Successfully fetched ${receipts.length} read receipts for message: $messageId',
            name: serviceName);
        return ApiResponse.success(
          receipts,
          message: response.message ?? 'Read receipts fetched successfully',
          statusCode: response.statusCode ?? 200,
        );
      } else {
        log('❌ [RoomService] Failed to fetch read receipts: ${response.error}',
            name: serviceName);
        return response;
      }
    } catch (e, stackTrace) {
      log('❌ [RoomService] Exception fetching read receipts: $e',
          name: serviceName);
      log('   Stack trace: $stackTrace', name: serviceName);
      return ApiResponse.error(
        'Failed to fetch read receipts: $e',
        statusCode: 0,
      );
    }
  }

  /// Mark a specific message as read
  ///
  /// POST /api/v1/messages/{messageId}/read
  ///
  /// This endpoint marks a specific message as read for the current user.
  ///
  /// Request body:
  /// {
  ///   "message_id": "770e8400-e29b-41d4-a716-446655440000"
  /// }
  ///
  /// Response:
  /// {
  ///   "message": "Message marked as read",
  ///   "status": "success",
  ///   "status_code": 200
  /// }
  ///
  /// Example curl:
  /// curl --location 'http://13.201.27.102:7071/api/v1/messages/{messageId}/read' \
  /// --header 'Authorization: Bearer {token}' \
  /// --header 'Content-Type: application/json' \
  /// --data '{"message_id": "770e8400-e29b-41d4-a716-446655440000"}'
  Future<ApiResponse<void>> markMessageAsRead(String messageId) async {
    try {
      log('📖 [RoomService] Marking message as read: $messageId',
          name: serviceName);

      final response = await post<void>(
        '/messages/$messageId/read',
        data: {
          'message_id': messageId,
        },
        fromJson: (_) => null, // No response data to parse
      );

      if (response.success) {
        log('✅ [RoomService] Message marked as read successfully: $messageId',
            name: serviceName);
      } else {
        log('❌ [RoomService] Failed to mark message as read: ${response.error}',
            name: serviceName);
      }

      return response;
    } catch (e, stackTrace) {
      log('❌ [RoomService] Exception marking message as read: $e',
          name: serviceName);
      log('   Stack trace: $stackTrace', name: serviceName);
      return ApiResponse.error(
        'Failed to mark message as read: $e',
        statusCode: 0,
      );
    }
  }

  /// Update user's online presence status
  ///
  /// Sets the current user's online/offline status and custom status message.
  /// This is used to show real-time presence indicators in the chat UI.
  ///
  /// POST /api/v1/presence
  ///
  /// Request body:
  /// {
  ///   "is_online": true,
  ///   "status": "online" // or "away", "busy", "offline"
  /// }
  ///
  /// Example:
  /// ```dart
  /// await RoomService.instance.updatePresence(
  ///   isOnline: true,
  ///   status: 'online',
  /// );
  /// ```
  Future<ApiResponse<void>> updatePresence({
    required bool isOnline,
    required String status,
  }) async {
    try {
      log('👤 [RoomService] Updating presence: isOnline=$isOnline, status=$status',
          name: serviceName);

      final response = await post<void>(
        '/presence',
        data: {
          'is_online': isOnline,
          'status': status,
        },
        fromJson: (_) => null, // No response data to parse
      );

      if (response.success) {
        log('✅ [RoomService] Presence updated successfully', name: serviceName);
      } else {
        log('❌ [RoomService] Failed to update presence: ${response.error}',
            name: serviceName);
      }

      return response;
    } catch (e, stackTrace) {
      log('❌ [RoomService] Exception updating presence: $e', name: serviceName);
      log('   Stack trace: $stackTrace', name: serviceName);
      return ApiResponse.error(
        'Failed to update presence: $e',
        statusCode: 0,
      );
    }
  }

  /// Get presence status for multiple users
  ///
  /// Fetches the online/offline status for a list of user IDs.
  /// This is used to show presence indicators for contacts in the chat list.
  ///
  /// GET /api/v1/presence?user_ids=uuid1,uuid2,uuid3
  ///
  /// Response:
  /// {
  ///   "data": [
  ///     {
  ///       "user_id": "uuid1",
  ///       "is_online": true,
  ///       "status": "online",
  ///       "last_seen": "2026-01-29T12:00:00Z"
  ///     }
  ///   ]
  /// }
  ///
  /// Example:
  /// ```dart
  /// final userIds = ['uuid1', 'uuid2', 'uuid3'];
  /// final response = await RoomService.instance.getPresence(userIds);
  /// if (response.success) {
  ///   for (var presence in response.data!) {
  ///     print('User ${presence['user_id']} is ${presence['status']}');
  ///   }
  /// }
  /// ```
  Future<ApiResponse<List<Map<String, dynamic>>>> getPresence(
      List<String> userIds) async {
    try {
      log('👥 [RoomService] Fetching presence for ${userIds.length} users',
          name: serviceName);

      // Join user IDs with comma for query parameter
      final userIdsParam = userIds.join(',');

      final response = await get<List<Map<String, dynamic>>>(
        '/presence?user_ids=$userIdsParam',
        fromJson: (json) {
          // Handle null data (no presence info)
          if (json == null) {
            return <Map<String, dynamic>>[];
          }

          // Handle array of presence data
          if (json is List) {
            return json
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    return item;
                  } else if (item is Map) {
                    return Map<String, dynamic>.from(item
                        .map((key, value) => MapEntry(key.toString(), value)));
                  }
                  return null;
                })
                .whereType<Map<String, dynamic>>()
                .toList();
          }

          // Handle single presence object wrapped in data field
          if (json is Map && json['data'] != null) {
            final data = json['data'];
            if (data is List) {
              return (data as List)
                  .map((item) {
                    if (item is Map<String, dynamic>) {
                      return item;
                    } else if (item is Map) {
                      return Map<String, dynamic>.from(item.map(
                          (key, value) => MapEntry(key.toString(), value)));
                    }
                    return null;
                  })
                  .whereType<Map<String, dynamic>>()
                  .toList();
            }
          }

          // Handle unexpected format
          log('⚠️ [RoomService] Unexpected presence data format: ${json.runtimeType}',
              name: serviceName);
          return <Map<String, dynamic>>[];
        },
      );

      if (response.success) {
        final presenceList = response.data ?? <Map<String, dynamic>>[];
        log('✅ [RoomService] Successfully fetched presence for ${presenceList.length} users',
            name: serviceName);
        return ApiResponse.success(
          presenceList,
          message: response.message ?? 'Presence fetched successfully',
          statusCode: response.statusCode ?? 200,
        );
      } else {
        log('❌ [RoomService] Failed to fetch presence: ${response.error}',
            name: serviceName);
        return response;
      }
    } catch (e, stackTrace) {
      log('❌ [RoomService] Exception fetching presence: $e', name: serviceName);
      log('   Stack trace: $stackTrace', name: serviceName);
      return ApiResponse.error(
        'Failed to fetch presence: $e',
        statusCode: 0,
      );
    }
  }
}
