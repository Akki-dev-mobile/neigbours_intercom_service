import 'dart:async';

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
import '../../../../core/services/keycloak_service.dart';
import '../widgets/call_bottom_sheet.dart';

class SocietyOfficeTab extends ConsumerStatefulWidget {
  const SocietyOfficeTab({Key? key}) : super(key: key);

  @override
  ConsumerState<SocietyOfficeTab> createState() => _SocietyOfficeTabState();
}

class _SocietyOfficeTabState extends ConsumerState<SocietyOfficeTab> {
  // Data for office staff
  List<IntercomContact> _officeContacts = [];
  final TextEditingController _searchController = TextEditingController();
  List<IntercomContact> _filteredOfficeContacts = [];
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isLoading = true;
  final Set<String> _callStartingContactIds = <String>{};
  final IntercomService _intercomService = IntercomService();

  @override
  void initState() {
    super.initState();
    _loadOfficeContacts();
    _searchController.addListener(_filterOfficeContacts);
    _initializeSpeech();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _speech.stop();
    super.dispose();
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
                _filterOfficeContacts();
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
                _filterOfficeContacts();
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

  void _filterOfficeContacts() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredOfficeContacts = _officeContacts;
      } else {
        _filteredOfficeContacts = _officeContacts.where((contact) {
          return contact.name.toLowerCase().contains(query) ||
              (contact.role?.toLowerCase().contains(query) ?? false) ||
              (contact.phoneNumber?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  Future<void> _loadOfficeContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // CRITICAL: Get the selected society's soc_id from selectedFlatProvider
      // This ensures we always use the freshly selected society's ID
      final selectedFlatState = ref.read(selectedFlatProvider);
      final societyId = selectedFlatState.selectedSociety?.socId;

      debugPrint(
          '🟡 [SocietyOfficeTab] Loading office contacts with society soc_id: $societyId');

      // Pass the selected society's soc_id as companyId
      final contacts =
          await _intercomService.getSocietyOfficeContacts(companyId: societyId);
      if (mounted) {
        setState(() {
          _officeContacts = contacts;
          _filteredOfficeContacts = contacts;
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
          message: 'Failed to load office contacts: ${e.toString()}',
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
              // Society Office info card with gradient
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
                            //   right: -20,
                            //   top: -20,
                            //   child: Icon(
                            //     Icons.business_rounded,
                            //     color: Colors.white.withOpacity(0.2),
                            //     size: 60,
                            //   ),
                            // ),
                            // Main content
                            Row(
                              children: [
                                const Icon(
                                  Icons.business_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Society Office Contacts',
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
                        //     // Calculate percentage of online staff
                        //     final onlineCount = _officeContacts
                        //         .where((o) =>
                        //             o.status == IntercomContactStatus.online)
                        //         .length;
                        //     final percentage =
                        //         onlineCount / _officeContacts.length;

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
                              'Contact society office for administrative matters, maintenance issues, and more.',
                              style: GoogleFonts.montserrat(
                                color: Colors.grey.shade800,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    // boxShadow: [
                                    //   BoxShadow(
                                    //     color: Colors.red.withOpacity(0.1),
                                    //     blurRadius: 4,
                                    //     offset: const Offset(0, 2),
                                    //   ),
                                    // ],
                                  ),
                                  child: Text(
                                    'Total: ${_officeContacts.length}',
                                    style: GoogleFonts.montserrat(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    // boxShadow: [
                                    //   BoxShadow(
                                    //     color: Colors.green.withOpacity(0.1),
                                    //     blurRadius: 4,
                                    //     offset: const Offset(0, 2),
                                    //   ),
                                    // ],
                                  ),
                                  child: Row(
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
                                      Text(
                                        'Currently Available: ${_officeContacts.where((o) => o.status == IntercomContactStatus.online).length}',
                                        style: GoogleFonts.montserrat(
                                          color: Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
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
                    hintText: 'Search office staff...',
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

              // Office staff cards with improved styling
              _isLoading
                  ? const Center(
                      child: AppLoader(
                        title: 'Loading Office Staff',
                        subtitle: 'Fetching office contact information...',
                        icon: Icons.business_rounded,
                      ),
                    )
                  : _filteredOfficeContacts.isEmpty &&
                          _searchController.text.isNotEmpty
                      ? _buildEmptyState(
                          icon: Icons.search_off,
                          title: 'No office staff found',
                          subtitle: 'Try searching with a different keyword',
                        )
                      : _filteredOfficeContacts.isEmpty
                          ? _buildEmptyState(
                              icon: Icons.business_outlined,
                              title: 'No office contacts available',
                              subtitle:
                                  'Office contacts will appear here when available',
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: _filteredOfficeContacts.map((staff) {
                                  return _buildOfficeStaffCard(staff);
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
  Widget _buildOfficeStaffCard(IntercomContact staff) {
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
                              _getInitials(staff.name),
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
                              color: _getStatusColor(staff.status),
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
                            staff.name,
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
                                _getRoleIcon(staff.role ?? ''),
                                color: Colors.grey.shade600,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                staff.role ?? 'Office Staff',
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
                        onPressed: () => _handleChat(staff),
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
                        onPressed: _callStartingContactIds.contains(staff.id)
                            ? null
                            : () => _onCallPressed(staff),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _callStartingContactIds.contains(staff.id)
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
      case 'administrative office':
        return Icons.manage_accounts;
      case 'repairs & services':
        return Icons.build;
      case 'billing & payments':
        return Icons.account_balance_wallet;
      case 'guest & delivery approvals':
        return Icons.delivery_dining;
      default:
        return Icons.business_center;
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
      debugPrint('SocietyOfficeTab: Error getting user data: $e');
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
