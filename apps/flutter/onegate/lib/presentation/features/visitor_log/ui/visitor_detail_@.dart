import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/data/visitor_info.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:common_widgets/common_widgets.dart';

class VisitorDetailsScreen2 extends StatefulWidget {
  final VisitorInfo visitorLog;
  final String? image;
  final String? unitList;
  final bool isFromMissedApprovalScreen;

  const VisitorDetailsScreen2(
      {Key? key,
      required this.visitorLog,
      this.unitList,
      this.image,
      required this.isFromMissedApprovalScreen})
      : super(key: key);

  @override
  State<VisitorDetailsScreen2> createState() => _VisitorDetailsScreenState();
}

class _VisitorDetailsScreenState extends State<VisitorDetailsScreen2> {
  late ScrollController _scrollController;
  double _imageHeight = 160.0; // Initial circular height
  final double _maxImageHeight = 300.0; // Maximum expanded height
  bool _isExpanded = false;

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  @override
  void initState() {
    log("Visitor details: ${widget.unitList}");
    log("Unit details: ${widget.visitorLog.unitDetails}");
    _scrollController = ScrollController()
      ..addListener(() {
        _handleScroll();
      });
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
                        _showFullImage(context, widget.visitorLog.visitorImage);
                      },
                      child: Padding(
                        padding: EdgeInsets.all(isTablet ? 8 : 6),
                        child: CircleAvatar(
                          radius: isTablet ? 80 : 60,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: isTablet ? 100 : 80,
                            backgroundImage: widget
                                    .visitorLog.visitorImage.isNotEmpty
                                ? NetworkImage(widget.visitorLog.visitorImage)
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.only(
                                  right: (widget.visitorLog.additionalDetails !=
                                              null &&
                                          widget.visitorLog.additionalDetails![
                                                  'invited_guest'] ==
                                              true)
                                      ? 120 // Add padding when pre-approved badge is present
                                      : 0,
                                ),
                                child: Text(
                                  widget.visitorLog.visitorName,
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
                            if (widget.visitorLog.visitorCount != null)
                              _buildChip(
                                "${widget.visitorLog.visitorCount} visitor${widget.visitorLog.visitorCount == 1 ? '' : 's'}",
                                Icons.people,
                                const Color(0xffFFB080),
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
                            _capitalizeFirstLetter(
                                widget.visitorLog.purposeSubCategoryName ??
                                    widget.visitorLog.purposeCategoryName ??
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
                          title: "Contact Information",
                          children: [
                            _buildInfoTile(
                              icon: Icons.phone,
                              title: "Phone Number",
                              subtitle: widget.visitorLog.visitorMobile,
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
                          title: "Visit Details",
                          children: [
                            _buildInfoTile(
                              icon: Icons.apartment,
                              title: "Visiting Unit",
                              subtitle:
                                  widget.visitorLog.unitDetails.building_unit ==
                                          "0001"
                                      ? "Society Office"
                                      : (widget.visitorLog.unitDetails
                                                      .building_unit !=
                                                  null &&
                                              widget.visitorLog.unitDetails
                                                      .building_unit !=
                                                  "")
                                          ? widget.visitorLog.unitDetails
                                              .building_unit
                                              .toString()
                                          : "N/A",
                              iconColor: const Color(0xffF44336), // Red
                              iconBg: const Color(
                                  0xffFFEBEE), // Light red background
                            ),
                            if (widget.visitorLog.inGate.isNotEmpty)
                              _buildInfoTile(
                                icon: Icons.meeting_room,
                                title: "In-Gate",
                                subtitle: widget.visitorLog.inGate,
                                iconColor: const Color(0xffF44336), // Red
                                iconBg: const Color(
                                    0xffFFEBEE), // Light red background
                              ),
                            if (widget.visitorLog.purposeSubCategoryName
                                        ?.toLowerCase() ==
                                    "delivery" ||
                                widget.visitorLog.purposeSubCategoryName
                                            ?.toLowerCase() ==
                                        "cabs" &&
                                    widget.visitorLog.visitorComingFrom != null)
                              _buildInfoTile(
                                icon: Icons.location_on,
                                title: "Coming From",
                                subtitle: widget.visitorLog.visitorComingFrom
                                    .toString(),
                                iconColor: const Color(0xffF44336), // Red
                                iconBg: const Color(
                                    0xffFFEBEE), // Light red background
                              ),
                            if (widget.visitorLog.visitorCardNumber != null &&
                                widget.visitorLog.visitorCardNumber!.isNotEmpty)
                              _buildInfoTile(
                                icon: Icons.badge,
                                title: "Card Number",
                                subtitle: widget.visitorLog.visitorCardNumber ??
                                    'N/A',
                                iconColor:
                                    Colors.white, // White icon for contrast
                                iconBg: const Color(
                                    0xffF44336), // Solid red background
                              ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        if (!widget.isFromMissedApprovalScreen ||
                            widget.visitorLog.allowStatus.toLowerCase() ==
                                "allowed" ||
                            widget.visitorLog.allowStatus.toLowerCase() ==
                                "always_allowed" ||
                            widget.visitorLog.allowStatus.toLowerCase() ==
                                "allowed_by_gatekeeper")
                          _buildBorderedSection(
                            context,
                            isTablet,
                            title: "Visitor Timeline",
                            children: _buildTimeline(),
                          )
                        else if (widget.isFromMissedApprovalScreen &&
                            widget.visitorLog.allowStatus.toLowerCase() ==
                                "pending")
                          _buildBorderedSection(
                            context,
                            isTablet,
                            title: "Actions",
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.check_circle,
                                        size: 16, color: Colors.black),
                                    label: Text(AppLocalizations.of(context)!
                                        .allowByGatekeeper),
                                    onPressed: () => _allowByGatekeeper(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: const BorderSide(
                                            color: Colors.black),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.black,
                                          Color(0xFF6E6E6E),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: Text(
                                          AppLocalizations.of(context)!.retry),
                                      onPressed: () => _retryPermission(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // Positioned Pre-approved Badge for top right corner
                  if (widget.visitorLog.additionalDetails != null &&
                      widget.visitorLog.additionalDetails!['invited_guest'] ==
                          true)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xff4CAF50),
                              const Color(0xff2E7D32),
                            ],
                          ),
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
                            Icon(
                              Icons.how_to_reg,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Pre-approved",
                              style: TextStyle(
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
                    tooltip: 'Close',
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
    int totalItems = 1 + // For logCreatedAt (always present)
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
    addTimelineItem(
      label: "Check In",
      description: widget.visitorLog.logCreatedAt,
      icon: Icons.login,
      color: Colors.green,
      index: currentIndex++,
    );

    // Add Approved By
    String approvedByText;
    // Check if this is an invited guest from additional_details
    bool isInvitedGuest = false;
    if (widget.visitorLog.additionalDetails != null) {
      final invitedGuest =
          widget.visitorLog.additionalDetails!['invited_guest'] as bool?;
      isInvitedGuest = invitedGuest == true;
    }

    if (isInvitedGuest) {
      approvedByText = "Guest pre-approved by member";
    } else if (widget.unitList == "0001") {
      approvedByText = "Pre approved Staff";
    } else {
      approvedByText = _getFormattedAllowStatus(widget.visitorLog.allowStatus);
    }

    addTimelineItem(
      label: "Approved By",
      description: approvedByText,
      icon: Icons.person,
      color: Colors.brown,
      index: currentIndex++,
    );

    // Add Check-Out (if available)
    if (widget.visitorLog.visitor_check_out != null) {
      addTimelineItem(
        label: "Check Out",
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

  String _getFormattedAllowStatus(String allowStatus) {
    switch (allowStatus.toLowerCase()) {
      case "allowed":
        return "Allowed";
      case "always_allowed":
        return "Always Allowed";
      case "allowed_by_gatekeeper":
        return "Allowed By Gatekeeper";
      default:
        return "Gatekeeper";
    }
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
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withAlpha(51), // 0.2 * 255 = ~51
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(
                icon,
                color: color,
                size: 12,
              ),
            ),
            if (showConnector)
              Container(
                width: 2,
                height: 40,
                color: color.withAlpha(128), // 0.5 * 255 = ~128
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
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description is DateTime
                    ? DateFormat('dd MMM yyyy, hh:mm a').format(description)
                    : description.toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor),
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
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.call, size: 16),
      label: Text(AppLocalizations.of(context)!.call),
      onPressed: () => _makePhoneCall(widget.visitorLog.visitorMobile),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Method to allow visitor by gatekeeper
  Future<void> _allowByGatekeeper() async {
    try {
      if (widget.visitorLog.visitorLogId == null) {
        _showSnackBar("Invalid visitor log ID", isError: true);
        return;
      }

      final response = await Dio().patch(
        '${ApiUrls.gateBaseUrl}/visitor/visitorLog/${widget.visitorLog.visitorId}',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: jsonEncode({"allow_status": "allowed_by_gatekeeper"}),
      );

      if (response.statusCode == 200) {
        log("✅ Visitor allowed by Gatekeeper successfully");
        _showSnackBar("Visitor allowed by Gatekeeper", isError: false);

        // Refresh the screen or navigate back
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        log("❌ Failed to allow visitor by Gatekeeper: ${response.statusMessage}");
        _showSnackBar("Error allowing visitor. Try again.", isError: true);
      }
    } catch (e) {
      log("❌ Error in _allowByGatekeeper: $e");
      _showSnackBar("Failed to allow visitor.", isError: true);
    }
  }

  // Method to retry sending permission request
  Future<void> _retryPermission() async {
    try {
      if (widget.visitorLog.visitorLogId == null) {
        _showSnackBar("Invalid visitor log ID", isError: true);
        return;
      }

      final formattedInTime =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      // Prepare request data
      final requestData = {
        'company_id': widget.visitorLog.companyId.toString(),
        'name': widget.visitorLog.visitorName,
        'mobile': widget.visitorLog.visitorMobile,
        'in_time': formattedInTime,
        'user_id': widget.visitorLog.memberInfo.userId.toString(),
        'visitor_count': widget.visitorLog.visitorCount.toString(),
        'purpose':
            widget.visitorLog.purposeCategoryName?.toLowerCase() ?? "general",
        'member_mobile_number': widget.visitorLog.memberInfo.mobileNumber ?? "",
        'visitor_id': widget.visitorLog.visitorId.toString(),
        'purpose_category':
            widget.visitorLog.visitorPurposeCategoryId.toString(),
        'visitor_log_id': widget.visitorLog.visitorLogId.toString(),
        'coming_from': widget.visitorLog.visitorComingFrom ?? "",
        'member_id': widget.visitorLog.memberInfo.memberId.toString(),
        "self_check_in": "false",
        "company_name": widget.visitorLog.companyName,
        "file": widget.visitorLog.visitorImage
      };

      final response = await Dio().post(
        '${ApiUrls.gateBaseUrl}/visitor/sendFcmNotification',
        options: Options(headers: {"Content-Type": "application/json"}),
        data: requestData,
      );

      if (response.statusCode == 200) {
        log("✅ Notification sent successfully");
        _showSnackBar("Notification sent to member", isError: false);

        // Reset the timer in SharedPreferences
        await _resetTimer(widget.visitorLog.visitorLogId ?? 0);

        // Navigate back to the previous screen to show the updated timer
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        log("❌ Failed to send notification: ${response.statusMessage}");
        _showSnackBar("Failed to send notification", isError: true);
      }
    } catch (e) {
      log("❌ Error in _retryPermission: $e");
      _showSnackBar("Error occurred while sending notification", isError: true);
    }
  }

  // Reset the timer for the visitor
  Future<void> _resetTimer(int visitorLogId) async {
    try {
      // Calculate new end time (60 seconds from now)
      final endTime = DateTime.now().add(const Duration(seconds: 60));

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('timer_$visitorLogId', endTime.toIso8601String());

      log("⏱️ Timer reset for visitor $visitorLogId");
    } catch (e) {
      log("❌ Error resetting timer: $e");
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final icon =
        isError ? Icons.error_outline_rounded : Icons.check_circle_rounded;
    final bgColor = isError ? const Color(0xffF44336) : const Color(0xff43A047);
    final title = isError ? 'Error' : 'Success';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 3000),
        elevation: 10,
      ),
    );
  }
}
