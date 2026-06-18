import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../src/config/intercom_ui_strings.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/enhanced_toast.dart';
import '../../../../core/services/call_coordinator.dart';
import '../models/call_model.dart';
import '../models/call_type.dart';
import '../models/intercom_contact.dart';
import '../services/call_history_service.dart';
import '../services/call_manager.dart';
import '../services/call_service.dart';
import '../screens/outgoing_call_screen.dart';

/// Bottom sheet for selecting call type (Audio or Video)
///
/// This widget:
/// - Displays audio and video call options
/// - Handles call initiation through CallManager
/// - Shows loading state during call setup
/// - Displays errors via EnhancedToast
///
/// Usage:
/// ```dart
/// CallBottomSheet.show(
///   context: context,
///   contact: contact,
///   displayName: 'Current User Name',
/// );
/// ```
class CallBottomSheet extends StatefulWidget {
  final IntercomContact contact;
  final String displayName;
  final String? avatarUrl;
  final String? userEmail;
  final int? callbackCallId;

  const CallBottomSheet({
    Key? key,
    required this.contact,
    required this.displayName,
    this.avatarUrl,
    this.userEmail,
    this.callbackCallId,
  }) : super(key: key);

  /// Show the call bottom sheet
  static Future<void> show({
    required BuildContext context,
    required IntercomContact contact,
    required String displayName,
    String? avatarUrl,
    String? userEmail,
    int? callbackCallId,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => CallBottomSheet(
        contact: contact,
        displayName: displayName,
        avatarUrl: avatarUrl,
        userEmail: userEmail,
        callbackCallId: callbackCallId,
      ),
    );
  }

  @override
  State<CallBottomSheet> createState() => _CallBottomSheetState();
}

class _CallBottomSheetState extends State<CallBottomSheet> {
  final CallManager _callManager = CallManager.instance;
  bool _isLoading = false;
  CallType? _selectedCallType;

  @override
  Widget build(BuildContext context) {
    final ui = IntercomUiStringsScope.of(context);

    return PopScope(
      canPop: !_isLoading,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(ui),

                const SizedBox(height: 16),

                Divider(
                  color: Colors.grey.withOpacity(0.2),
                  thickness: 1,
                ),

                const SizedBox(height: 16),

                // Contact info
                _buildContactInfo(),

                const SizedBox(height: 24),

                // Call type options
                if (_isLoading) _buildLoadingState(ui) else _buildCallOptions(ui),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(IntercomUiStrings ui) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xffffebee),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.phone,
            color: const Color(0xffc62828),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            ui.startCall,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            color: Colors.grey.shade600,
            iconSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo() {
    return Row(
      children: [
        // Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xffffebee),
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: (widget.contact.photoUrl != null &&
                    widget.contact.photoUrl!.isNotEmpty)
                ? Image.network(
                    widget.contact.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          widget.contact.initials,
                          style: TextStyle(
                            color: const Color(0xffc62828),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Text(
                      widget.contact.initials,
                      style: TextStyle(
                        color: const Color(0xffc62828),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.contact.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (widget.contact.unit != null)
                Text(
                  widget.contact.unit!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(IntercomUiStrings ui) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: AppLoader(
          size: 120,
          title: _selectedCallType != null
              ? ui.startingCallLabel(_selectedCallType!.displayName)
              : ui.connecting,
        ),
      ),
    );
  }

  Widget _buildCallOptions(IntercomUiStrings ui) {
    return Column(
      children: [
        _buildCallOption(
          icon: Icons.phone_in_talk,
          title: ui.audioCall,
          subtitle: ui.audioCallSubtitle,
          color: Colors.green,
          callType: CallType.audio,
        ),

        const SizedBox(height: 12),

        _buildCallOption(
          icon: Icons.videocam,
          title: ui.videoCall,
          subtitle: ui.videoCallSubtitle,
          color: Colors.blue,
          callType: CallType.video,
        ),
      ],
    );
  }

  Widget _buildCallOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required CallType callType,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _initiateCall(callType),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initiateCall(CallType callType) async {
    if (_isLoading) return;

    var contact = widget.contact;
    // Validate phone number - backend expects phone number for recipient user upsert
    // Backend will create recipient user if doesn't exist (using phone number)
    var toUserId = _resolveToUserId(contact);
    var hasPhone = contact.phoneNumber != null &&
        contact.phoneNumber!.isNotEmpty &&
        CallService.isLikelyPhone(contact.phoneNumber!);

    if ((toUserId == null || toUserId.isEmpty) &&
        widget.callbackCallId != null) {
      // Missed-call callbacks should prefer resolving a real user id from call details,
      // even if a phone number is present, because the backend now requires to_user_id.
      final resolved = await _resolveContactFromCallId(
        callId: widget.callbackCallId!,
        fallback: contact,
      );
      if (resolved != null) {
        contact = resolved;
        toUserId = _resolveToUserId(contact);
        hasPhone = contact.phoneNumber != null &&
            contact.phoneNumber!.isNotEmpty &&
            CallService.isLikelyPhone(contact.phoneNumber!);
      }
    }

    if ((toUserId == null || toUserId.isEmpty) && !hasPhone) {
      final ui = IntercomUiStringsScope.of(context);
      EnhancedToast.error(
        context,
        title: ui.cannotMakeCall,
        message: ui.noValidCallIdentifierMessage(contact.name),
      );
      return;
    }

    // Single-flight outgoing call creation gate (prevents duplicate call IDs).
    final locked = CallCoordinator.instance.tryLockOutgoingCallCreation();
    if (!locked) {
      final ui = IntercomUiStringsScope.of(context);
      EnhancedToast.error(
        context,
        title: ui.callInProgress,
        message: ui.callInProgressMessage,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedCallType = callType;
    });

    try {
      // Pass the recipient's phone number to the backend
      // Backend performs recipient user upsert (creates if doesn't exist)
      final result = await _callManager.initiateCall(
        toUserPhone: hasPhone ? contact.phoneNumber : null,
        toUserId: toUserId,
        toUserAvatarUrl: contact.photoUrl,
        callType: callType,
        displayName: widget.displayName,
        avatarUrl: widget.avatarUrl,
        userEmail: widget.userEmail,
        // IMPORTANT: never open Jitsi at initiation; show outgoing ringing UI instead.
        joinJitsiImmediately: false,
      );

      if (!mounted) {
        CallCoordinator.instance.unlockOutgoingCallCreation();
        return;
      }

      if (result.success && result.call != null) {
        final call = result.call!;
        final sheetNavigator = Navigator.of(context);
        final rootNavigator = Navigator.of(context, rootNavigator: true);

        // Bind outgoing call immediately to prevent duplicate initiations and
        // to correctly gate accept/reject events to the active call id.
        CallCoordinator.instance.startOutgoingCall(call);

        await _recordHistory(call);
        if (!mounted) {
          CallCoordinator.instance.unlockOutgoingCallCreation();
          return;
        }

        sheetNavigator.pop(); // close bottom sheet
        unawaited(rootNavigator.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => OutgoingCallScreen(
              call: call,
              calleeName: contact.name,
              calleePhone: contact.phoneNumber,
              calleeAvatarUrl: contact.photoUrl,
            ),
          ),
        ));
      } else {
        CallCoordinator.instance.unlockOutgoingCallCreation();
        setState(() {
          _isLoading = false;
          _selectedCallType = null;
        });

        if (result.permissionsDenied) {
          _showPermissionDeniedDialog(result.message ?? result.error ?? '');
        } else {
          final ui = IntercomUiStringsScope.of(context);
          EnhancedToast.error(
            context,
            title: ui.callFailed,
            message: result.message ?? result.error ?? ui.unknownError,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      CallCoordinator.instance.unlockOutgoingCallCreation();
      setState(() {
        _isLoading = false;
        _selectedCallType = null;
      });

      final ui = IntercomUiStringsScope.of(context);
      EnhancedToast.error(
        context,
        title: ui.callFailed,
        message: e.toString(),
      );
    }
  }

  Future<IntercomContact?> _resolveContactFromCallId({
    required int callId,
    required IntercomContact fallback,
  }) async {
    try {
      final call = await CallService.instance.getCall(callId);
      final fromUser = call?.fromUser;
      if (fromUser == null && call?.fromUserId == null) return null;

      final resolvedUserIdRaw =
          fromUser?.userId?.trim() ?? call?.fromUserId?.toString();
      final resolvedUserId = int.tryParse(resolvedUserIdRaw ?? '');
      final resolvedPhone = fromUser?.phone ?? fallback.phoneNumber;
      final resolvedName = (fromUser?.name ?? fallback.name).trim();
      final resolvedId = resolvedUserIdRaw?.isNotEmpty == true
          ? resolvedUserIdRaw!
          : (resolvedPhone != null ? 'phone:$resolvedPhone' : fallback.id);

      return fallback.copyWith(
        id: resolvedId,
        name: resolvedName.isNotEmpty ? resolvedName : fallback.name,
        phoneNumber: resolvedPhone,
        numericUserId: resolvedUserId ?? fallback.numericUserId,
        hasUserId: resolvedUserIdRaw != null
            ? resolvedUserIdRaw.isNotEmpty
            : fallback.hasUserId,
      );
    } catch (e) {
      debugPrint('🧩 [CallBottomSheet] Failed to resolve call contact: $e');
      return null;
    }
  }

  void _showPermissionDeniedDialog(String message) {
    final ui = IntercomUiStringsScope.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
            ),
            const SizedBox(width: 8),
            Text(ui.permissionsRequired),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(ui.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: Text(ui.openSettings),
          ),
        ],
      ),
    );
  }

  Future<void> _recordHistory(Call call) async {
    if (widget.contact.phoneNumber == null) return;
    try {
      await CallHistoryService.instance.recordCall(
        call: call,
        contactName: widget.contact.name,
        contactPhone: widget.contact.phoneNumber!,
        contactAvatar: widget.contact.photoUrl,
      );
    } catch (e) {
      debugPrint('📝 [CallBottomSheet] Failed to save call history: $e');
    }
  }
}

String? _resolveToUserId(IntercomContact contact) {
  if (contact.numericUserId != null) {
    return contact.numericUserId!.toString();
  }

  final id = contact.id.trim();
  if (RegExp(r'^\d+$').hasMatch(id)) {
    return id;
  }

  return null;
}
