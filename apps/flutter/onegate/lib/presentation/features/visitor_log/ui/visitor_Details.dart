import 'dart:developer';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/presentation/widgets/assign_card_popup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';

class VisitorDetailsScreen extends StatefulWidget {
  final VisitorLog visitorLog;
  String? image;
  String? unitList;
  String? assignedCardNumber; // Add parameter for assigned card number
  final VoidCallback? onCardAssigned; // Callback to refresh visitor log list

  VisitorDetailsScreen(
      {Key? key,
      required this.visitorLog,
      this.unitList,
      this.image,
      this.assignedCardNumber,
      this.onCardAssigned})
      : super(key: key);

  @override
  State<VisitorDetailsScreen> createState() => _VisitorDetailsScreenState();
}

class _VisitorDetailsScreenState extends State<VisitorDetailsScreen> {
  late ScrollController _scrollController;
  double _imageHeight = 160.0; // Initial circular height
  final double _maxImageHeight = 300.0; // Maximum expanded height
  bool _isExpanded = false;
  String? _assignedCardNumber;
  bool _visitorCardEntryEnabled = false;

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  /// Check if Assign Card button should be shown
  bool _shouldShowAssignCardButton() {
    // API-driven: show Assign Card when entry is not from gatekeeper, no card is set, and visitor card entry is enabled
    final isNotGatekeeper = widget.visitorLog.initiated_from != "gatekeeper";

    final currentCardNumber =
        _assignedCardNumber ?? widget.visitorLog.visitor_card_number;
    final hasNoCardNumber =
        currentCardNumber == null || currentCardNumber.isEmpty;

    return isNotGatekeeper && hasNoCardNumber && _visitorCardEntryEnabled;
  }

  /// Get the current card number (either assigned or original)
  String? _getCurrentCardNumber() {
    return _assignedCardNumber ?? widget.visitorLog.visitor_card_number;
  }

  /// Handle card assignment
  void _handleAssignCard() {
    if (widget.visitorLog.visitor_id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Error: Visitor ID not found')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AssignCardPopup(
        visitorId: widget.visitorLog.visitor_id!,
        visitorName: widget.visitorLog.visitor?.name ?? 'Visitor',
        onCardAssigned: (cardNumber) {
          // Update the local state with the new card number
          setState(() {
            _assignedCardNumber = cardNumber;
          });
          // Trigger visitor log list refresh
          if (widget.onCardAssigned != null) {
            widget.onCardAssigned!();
          }
        },
      ),
    );
  }

  @override
  void initState() {
    log("visitsomethingggggg ${widget.unitList}");
    print(widget.visitorLog.visitor_building_assignment);
    _scrollController = ScrollController()
      ..addListener(() {
        _handleScroll();
      });

    // Initialize assigned card number from passed parameter
    if (widget.assignedCardNumber != null) {
      _assignedCardNumber = widget.assignedCardNumber;
    }

    // Load visitor card entry setting
    _loadVisitorCardSetting();

    super.initState();
  }

  void _handleScroll() {
    final double offset = _scrollController.offset;
    setState(() {
      if (offset < 0) {
        // Expanding
        _imageHeight = _maxImageHeight;
        _isExpanded = true;
      } else if (offset > 50) {
        // Collapsing
        _imageHeight = 160.0;
        _isExpanded = false;
      }
    });
  }

  Future<void> _loadVisitorCardSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _visitorCardEntryEnabled = prefs.getBool('visitorCardNumber') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return MyScrollView(
      pageBody: CustomScrollView(
        shrinkWrap: true,
        controller: _scrollController,
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _showFullImage(context, widget.image);
                      },
                      child: Padding(
                        padding: EdgeInsets.all(isTablet ? 8 : 6),
                        child: CircleAvatar(
                          radius: isTablet ? 80 : 60,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: isTablet ? 100 : 80,
                            backgroundImage: widget.image != null &&
                                    widget.image!.isNotEmpty
                                ? NetworkImage(widget.image!)
                                : const NetworkImage(
                                    "https://cdn.pixabay.com/photo/2022/06/05/07/04/person-7243410_1280.png"),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isTablet ? 24 : 16),
              Stack(
                children: [
                  Container(
                    margin:
                        EdgeInsets.symmetric(horizontal: isTablet ? 24 : 12),
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.only(
                                      right: (widget.visitorLog
                                                      .initiated_from ==
                                                  "invited_guest" ||
                                              widget.visitorLog
                                                      .initiated_from ==
                                                  "qr_code_scan" ||
                                              widget.visitorLog
                                                      .initiated_from ==
                                                  "passcode_entry")
                                          ? 120 // Add padding when pre-approved badge is present
                                          : 0,
                                    ),
                                    child: Text(
                                      widget.visitorLog.visitor?.name ??
                                          context.tr('Guest'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xff212427),
                                            fontSize: isTablet ? 28 : 22,
                                          ),
                                      softWrap: true,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Move visitor count badge below the name to avoid overlap with pre-approved badge
                            if (widget.visitorLog.visitor_count.toString() !=
                                '1')
                              Padding(
                                padding: EdgeInsets.only(
                                  top: isTablet ? 8 : 6,
                                ),
                                child: _buildChip(
                                  "${widget.visitorLog.visitor_count} visitors",
                                  Icons.people,
                                  const Color(0xffFFB080),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 12 : 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 12 : 8,
                              vertical: isTablet ? 6 : 2),
                          decoration: BoxDecoration(
                            color: const Color(0xffFFEBE6),
                            borderRadius:
                                BorderRadius.circular(isTablet ? 15 : 10),
                          ),
                          child: Text(
                            _formatPurposeLabel(
                                widget.visitorLog.purpose_sub_category_name ??
                                    widget.visitorLog
                                        .visitor_purpose_Category_name ??
                                    ""),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: isTablet ? 16 : 13),
                          ),
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        _buildBorderedSection(
                          context,
                          isTablet,
                          title: context.tr('visitorDetailsContactInformation'),
                          children: [
                            _buildInfoTile(
                              icon: Icons.phone,
                              title: context.tr('visitorDetailsPhoneNumber'),
                              subtitle: widget.visitorLog.visitor?.mobile ??
                                  context.tr('N/A'),
                              iconColor:
                                  const Color(0xff43A047), // Green (Scan icon)
                              iconBg: const Color(
                                  0xffE8F5E9), // Light green background
                              trailing: _buildCallButton(),
                            ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        _buildBorderedSection(
                          context,
                          isTablet,
                          title: context.tr('visitorDetailsVisitDetails'),
                          children: [
                            _buildInfoTile(
                              icon: Icons.apartment,
                              title: context.tr('visitorDetailsVisitingUnit'),
                              subtitle: widget.unitList == "0001"
                                  ? context.tr('Society Office')
                                  : (widget.unitList != null &&
                                          widget.unitList != "")
                                      ? widget.unitList.toString()
                                      : context.tr('N/A'),
                              iconColor: const Color(0xffF44336), // Red
                              iconBg: const Color(
                                  0xffFFEBEE), // Light red background
                            ),
                            if (widget.visitorLog.visitor_purpose_Category_name
                                        ?.toLowerCase() ==
                                    "DELIVERY" ||
                                widget.visitorLog.visitor_purpose_Category_name
                                            ?.toLowerCase() ==
                                        "CABS" &&
                                    widget.visitorLog.visitor_coming_from !=
                                        null)
                              _buildInfoTile(
                                icon: Icons.location_on,
                                title: context.tr('Coming From'),
                                subtitle: widget.visitorLog.visitor_coming_from
                                    .toString(),
                                iconColor: const Color(0xffF44336), // Red
                                iconBg: const Color(
                                    0xffFFEBEE), // Light red background
                              ),
                            // API-driven: for QR/Passcode/Express without card → show Assign Card; otherwise show card number if present
                            _shouldShowAssignCardButton()
                                ? Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr(
                                              'visitorDetailsCardNumber'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[700],
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                Color(
                                                    0xff212427), // Black color
                                                Color(0xff57636C), // Grey color
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xff212427)
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _handleAssignCard,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.badge_outlined,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  context.tr(
                                                      'visitorDetailsAssignCard'),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium!
                                                      .copyWith(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _getCurrentCardNumber() != null &&
                                        _getCurrentCardNumber()!.isNotEmpty &&
                                        _visitorCardEntryEnabled
                                    ? _buildInfoTile(
                                        icon: Icons.badge_outlined,
                                        title:
                                            context.tr('visitorDetailsCardNumber'),
                                        subtitle:
                                            _getCurrentCardNumber() ?? 'N/A',
                                        iconColor: Colors
                                            .white, // White icon for contrast
                                        iconBg: const Color(
                                            0xffF44336), // Solid red background
                                      )
                                    : const SizedBox.shrink(),
                          ],
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        _buildBorderedSection(
                          context,
                          isTablet,
                          title: context.tr('visitorDetailsTimeline'),
                          children: _buildTimeline(),
                        ),
                      ],
                    ),
                  ),
                  // Positioned Pre-approved Badge for top right corner
                  if (widget.visitorLog.initiated_from == "invited_guest" ||
                      widget.visitorLog.initiated_from == "qr_code_scan" ||
                      widget.visitorLog.initiated_from == "passcode_entry")
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xff4CAF50),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xff4CAF50).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.how_to_reg,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('visitorDetailsPreApproved'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.white.withOpacity(0.9),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Color(0xffF44336)),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: context.tr('Close'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// Define _buildTimeline method outside of the widget
  List<Widget> _buildTimeline() {
    List<Widget> timelineItems = [];
    int totalItems = (widget.visitorLog.visitor_check_in != null ? 1 : 0) +
        (widget.unitList != null ? 1 : 0) +
        (widget.visitorLog.visitor_check_out != null ? 1 : 0);

    void addTimelineItem({
      required String label,
      required dynamic description,
      required IconData icon,
      required Color color,
      required int index,
    }) {
      timelineItems.add(
        Column(
          children: [
            _buildTimelineTile(
              label,
              description,
              icon,
              color,
              isFirst: index == 0,
              isLast: index == totalItems - 1,
              showConnector: totalItems > 1 && index < totalItems - 1,
            ),
          ],
        ),
      );
    }

    int currentIndex = 0;

    // Add Check-In
    if (widget.visitorLog.visitor_check_in != null) {
      addTimelineItem(
        label: context.tr('visitorDetailsCheckIn'),
        description: widget.visitorLog.visitor_check_in!,
        icon: Icons.login,
        color: Colors.green,
        index: currentIndex++,
      );
    }

    // Add Approved By
    String approvedByText;
    if (widget.visitorLog.initiated_from == "invited_guest") {
      approvedByText = context.tr('visitorDetailsGuestPreApprovedByMember');
    } else if (widget.unitList == "0001") {
      approvedByText = context.tr('preApprovedStaff');
    } else {
      approvedByText =
          widget.visitorLog.approved_by ?? context.tr('gatekeeper');
    }

    addTimelineItem(
      label: context.tr('visitorDetailsApprovedBy'),
      description: toBeginningOfSentenceCase(approvedByText),
      icon: Icons.person,
      color: Colors.brown,
      index: currentIndex++,
    );

    // Add Check-Out (if available)
    if (widget.visitorLog.visitor_check_out != null) {
      addTimelineItem(
        label: context.tr('checkOut'),
        description: widget.visitorLog.visitor_check_out!,
        icon: Icons.logout,
        color: Colors.red,
        index: currentIndex++,
      );
    }

    return timelineItems;
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return "";
    return text
        .split(' ') // Split by spaces for multi-word strings
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' '); // Join words back together
  }

  String _formatPurposeLabel(String text) {
    if (text.trim().isEmpty) return '';
    final normalized = text.trim().toUpperCase();
    const purposeCategories = {
      'GUEST',
      'DELIVERY',
      'STAFF',
      'MEMBER STAFF',
      'VENDOR',
      'CABS',
    };
    if (purposeCategories.contains(normalized)) {
      return context.trPurposeCategory(text);
    }
    return _capitalizeFirstLetter(text);
  }

  Widget _buildTimelineTile(
    String label,
    dynamic description,
    IconData icon,
    Color color, {
    required bool isFirst,
    required bool isLast,
    bool showConnector = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(
                icon,
                color: color,
                size: 16,
              ),
            ),
            if (showConnector)
              Container(
                width: 2,
                height: 40,
                color: color.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description is DateTime
                    ? DateFormat('dd MMM yyyy, hh:mm a').format(description)
                    : description.toString(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBorderedSection(BuildContext context, bool isTablet,
      {required String title, required List<Widget> children}) {
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 20 : 14),
      padding: EdgeInsets.all(isTablet ? 18 : 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff212427),
                  fontSize: isTablet ? 20 : 16,
                ),
          ),
          SizedBox(height: isTablet ? 12 : 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBg,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xff212427),
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xff212427)),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.call, size: 16, color: Colors.white),
      label: Text(context.tr('visitorDetailsCall'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      onPressed: () => _makePhoneCall(widget.visitorLog.visitor?.mobile ?? ""),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    );
  }

  Widget _buildFallbackImage(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      width: double.infinity,
      height: _imageHeight,
      child: Center(
        child: Text(
          widget.visitorLog.visitor?.name?.isNotEmpty == true
              ? widget.visitorLog.visitor!.name![0].toUpperCase()
              : 'G',
          style: TextStyle(
            fontSize: _isExpanded ? 100 : 60,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
