import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_loader.dart';
import '../models/gatekeeper.dart';
import '../services/intercom_service.dart';
import '../widgets/call_bottom_sheet.dart';
import '../../../../core/services/keycloak_service.dart';
import '../../providers/selected_flat_provider.dart';
import 'tab_activation_mixin.dart';
import '../../../../core/widgets/enhanced_toast.dart';
import 'dart:developer' as developer;
import '../../../../core/utils/navigation_helper.dart';
import '../chat_screen.dart';

class GatekeepersTab extends ConsumerStatefulWidget {
  final ValueNotifier<int> activeTabNotifier;
  final int tabIndex;

  const GatekeepersTab({
    Key? key,
    required this.activeTabNotifier,
    required this.tabIndex,
  }) : super(key: key);

  @override
  ConsumerState<GatekeepersTab> createState() => _GatekeepersTabState();
}

class _GatekeepersTabState extends ConsumerState<GatekeepersTab>
    with TabActivationMixin {
  // Clean gatekeepers data - exactly matching API
  List<Gatekeeper> _gatekeepers = [];
  List<Gatekeeper> _filteredGatekeepers = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  final Set<int> _callStartingUserIds = <int>{};
  final IntercomService _intercomService = IntercomService();

  @override
  ValueNotifier<int>? get activeTabNotifier => widget.activeTabNotifier;

  @override
  int? get tabIndex => widget.tabIndex;

  @override
  bool get isLoading => _isLoading;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterGatekeepers);
    initializeTabActivation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    disposeTabActivation();
    super.dispose();
  }

  @override
  void onTabBecameActive({required bool shouldFetchFromNetwork}) {
    // First: Render cached data immediately (if exists)
    _renderCachedDataIfAvailable();

    // Then: Fetch from network if needed
    if (shouldFetchFromNetwork) {
      _fetchFromNetwork();
    }
  }

  /// Render cached data immediately if available
  void _renderCachedDataIfAvailable() {
    // If we have cached data, show it immediately
    if (_gatekeepers.isNotEmpty) {
      _filterGatekeepers();
      setState(() {});
    }
  }

  /// Fetch from network when tab becomes active
  void _fetchFromNetwork() async {
    // Try to acquire request lock
    final token = tryAcquireRequestLock();
    if (token == null) {
      developer.log(
          '⏸️ [GatekeepersTab] Request already in-flight, ignoring duplicate request');
      return;
    }

    try {
      // Get selected society ID
      final selectedFlatState = ref.read(selectedFlatProvider);
      final societyId = selectedFlatState.selectedSociety?.socId;

      if (societyId == null) {
        developer.log('⚠️ [GatekeepersTab] No society selected');
        if (mounted) {
          EnhancedToast.error(
            context,
            title: 'Error',
            message: 'No society selected',
          );
        }
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // Fetch gatekeepers using the clean API
      final gatekeepers = await _intercomService.getGatekeepersList(societyId);

      // Check if still valid before updating state
      if (!token.isValid(lifecycleController.generation)) {
        developer
            .log('⏹️ [GatekeepersTab] Tab became inactive, discarding result');
        return;
      }

      if (mounted) {
        setState(() {
          _gatekeepers = gatekeepers;
          _filterGatekeepers();
          _isLoading = false;
        });

        // Mark data as loaded for debounce tracking
        markDataLoaded();
      }
    } catch (e) {
      // Check if still valid before showing error
      if (!token.isValid(lifecycleController.generation)) {
        return;
      }

      developer.log('❌ [GatekeepersTab] Error fetching gatekeepers: $e');
      if (mounted) {
        setState(() {
          _gatekeepers = [];
          _filteredGatekeepers = [];
          _isLoading = false;
        });

        EnhancedToast.error(
          context,
          title: 'Error',
          message: 'Failed to load gatekeepers: $e',
        );
      }
    } finally {
      releaseRequestLock();
    }
  }

  void _filterGatekeepers() {
    final query = _searchController.text.toLowerCase().trim();

    // Filter: status == active, then apply search
    final activeGatekeepers = _gatekeepers.where((g) => g.isActive).toList();

    if (query.isEmpty) {
      _filteredGatekeepers = activeGatekeepers;
    } else {
      _filteredGatekeepers = activeGatekeepers.where((gatekeeper) {
        return gatekeeper.username.toLowerCase().contains(query) ||
            (gatekeeper.email?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Sort: alphabetical by username
    _filteredGatekeepers.sort((a, b) => a.username.compareTo(b.username));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search gatekeepers...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: AppLoader(
                        title: 'Loading Gatekeepers',
                        subtitle: 'Fetching gatekeeper information...',
                        icon: Icons.security_rounded,
                      ),
                    )
                  : _filteredGatekeepers.isEmpty &&
                          _searchController.text.isNotEmpty
                      ? _buildEmptyState(
                          icon: Icons.search_off,
                          title: 'No gatekeepers found',
                          subtitle: 'Try searching with a different keyword',
                        )
                      : _filteredGatekeepers.isEmpty
                          ? _buildEmptyState(
                              icon: Icons.security_rounded,
                              title: 'No gatekeepers available',
                              subtitle:
                                  'Gatekeepers will appear here when available',
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                // Reset load state to force refresh
                                resetLoadState();
                                _fetchFromNetwork();
                              },
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _filteredGatekeepers.length,
                                itemBuilder: (context, index) {
                                  final gatekeeper =
                                      _filteredGatekeepers[index];
                                  return _buildGatekeeperCard(gatekeeper);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGatekeeperCard(Gatekeeper gatekeeper) {
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
          onTap: () {
            // Handle tap if needed
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Main gatekeeper information section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar with status indicator
                    Stack(
                      children: [
                        // Avatar circle
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Center(
                            child: Text(
                              gatekeeper.initials,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        // Status indicator
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: gatekeeper.isActive
                                  ? Colors.green
                                  : Colors.grey,
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

                    // Gatekeeper details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  gatekeeper.username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Email if available
                          if (gatekeeper.email != null &&
                              gatekeeper.email!.isNotEmpty)
                            Text(
                              gatekeeper.email!,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else
                            Text(
                              'Gatekeeper',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons (same layout as Residents tab)
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
                        onPressed: () => _handleChat(gatekeeper),
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
                        onPressed: _callStartingUserIds.contains(gatekeeper.userId)
                            ? null
                            : () => _onCallPressed(gatekeeper),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _callStartingUserIds.contains(gatekeeper.userId)
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

  void _handleChat(Gatekeeper gatekeeper) {
    NavigationHelper.pushRoute(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          contact: gatekeeper.toIntercomContact(),
          returnToHistory: true, // Navigate back to history page on back button
        ),
      ),
    );
  }

  /// Show popup with Audio and Video Call options using Jitsi SDK (same as Residents tab)
  Future<void> _showCallOptionsPopup(Gatekeeper gatekeeper) async {
    final contact = gatekeeper.toIntercomContact();
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
      developer.log('GatekeepersTab: Error getting user data: $e');
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

  Future<void> _onCallPressed(Gatekeeper gatekeeper) async {
    if (_callStartingUserIds.contains(gatekeeper.userId)) return;
    setState(() {
      _callStartingUserIds.add(gatekeeper.userId);
    });
    try {
      await _showCallOptionsPopup(gatekeeper);
    } finally {
      if (mounted) {
        setState(() {
          _callStartingUserIds.remove(gatekeeper.userId);
        });
      }
    }
  }

}
