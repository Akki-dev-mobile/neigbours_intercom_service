import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/colors.dart';
import '../models/intercom_contact.dart';

class IntercomContactCard extends StatefulWidget {
  final IntercomContact contact;
  final VoidCallback? onChat;
  final VoidCallback? onCall;
  final bool hasFamilyMembers;
  final VoidCallback? onFamilyMembersToggle;

  const IntercomContactCard({
    Key? key,
    required this.contact,
    this.onChat,
    this.onCall,
    this.hasFamilyMembers = false,
    this.onFamilyMembersToggle,
  }) : super(key: key);

  @override
  State<IntercomContactCard> createState() => _IntercomContactCardState();
}

class _IntercomContactCardState extends State<IntercomContactCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(
          bottom: 1), // Reduced margin as parent handles spacing
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Contact info with enhanced styling
            InkWell(
              onTap: widget.hasFamilyMembers
                  ? () {
                      setState(() => _isExpanded = !_isExpanded);
                      if (widget.onFamilyMembersToggle != null) {
                        widget.onFamilyMembersToggle!();
                      }
                    }
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Enhanced Avatar
                    _buildEnhancedAvatar(),
                    const SizedBox(width: 12),

                    // Contact details with improved layout
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.contact.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.hasFamilyMembers)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.people,
                                        size: 12,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Family',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.withOpacity(0.8),
                                        ),
                                      ),
                                      Icon(
                                        _isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: Colors.red,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Unit or role info
                          Text(
                            widget.contact.typeLabel,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Status with badge
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: widget.contact.statusColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.contact.statusColor
                                          .withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.contact.statusText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.contact.statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (widget.contact.hasUnreadMessages) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.infoBlue,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppColors.infoBlue.withOpacity(0.3),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'New',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Family members expansion section - Removed as it's handled by parent widget

            // Action buttons with divider
            Divider(
              color: Colors.black.withOpacity(0.1),
              height: 1,
              thickness: 1,
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap:
                            widget.contact.isContactable ? widget.onChat : null,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 16,
                                color: widget.contact.isContactable
                                    ? Colors.blue
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Chat',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: widget.contact.isContactable
                                      ? Colors.blue
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.grey.shade300,
                  ),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.contact.isContactable
                            ? (widget.contact.phoneNumber != null
                                ? () =>
                                    _makePhoneCall(widget.contact.phoneNumber!)
                                : widget.onCall)
                            : null,
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone,
                                size: 16,
                                color: widget.contact.isContactable
                                    ? Colors.green
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Call',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: widget.contact.isContactable
                                      ? Colors.green
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      await launchUrl(launchUri);
    } catch (e) {
      // Handle exception if unable to launch phone dialer
      debugPrint('Could not launch phone dialer: $e');
      // Fallback to onCall if provided
      if (widget.onCall != null) {
        widget.onCall!();
      }
    }
  }

  Widget _buildEnhancedAvatar() {
    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade500, Colors.grey.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.contact.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        if (widget.contact.isFavorite)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star,
                color: Colors.amber,
                size: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFamilyMemberItem(FamilyMember member) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          // Family member avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                member.initials,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Family member info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        member.relation,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _getStatusColor(member.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getStatusText(member.status),
                      style: TextStyle(
                        fontSize: 11,
                        color: _getStatusColor(member.status),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_outlined, size: 18),
                color: AppColors.primary,
                tooltip: 'Chat',
                onPressed: () {
                  // Handle family member chat
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.phone_outlined, size: 18),
                color: Colors.green,
                tooltip: 'Call',
                onPressed: () {
                  // Handle family member call
                  if (member.phoneNumber != null) {
                    _makePhoneCall(member.phoneNumber!);
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method for status text
  String _getStatusText(IntercomContactStatus status) {
    switch (status) {
      case IntercomContactStatus.online:
        return 'Online';
      case IntercomContactStatus.offline:
        return 'Offline';
      case IntercomContactStatus.busy:
        return 'Busy';
      case IntercomContactStatus.away:
        return 'Away';
      default:
        return 'Unknown';
    }
  }

  // Helper method for status color
  Color _getStatusColor(IntercomContactStatus status) {
    switch (status) {
      case IntercomContactStatus.online:
        return Colors.green;
      case IntercomContactStatus.offline:
        return Colors.grey;
      case IntercomContactStatus.busy:
        return Colors.amber;
      case IntercomContactStatus.away:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
