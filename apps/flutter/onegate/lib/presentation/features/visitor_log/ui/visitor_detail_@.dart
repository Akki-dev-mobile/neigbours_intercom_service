import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/data/visitor_info.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:common_widgets/common_widgets.dart';

class VisitorDetailsScreen2 extends StatefulWidget {
  final VisitorInfo visitorLog;
  final String? image;
  final String? unitList;
  final bool isFromMissedApprovalScreen;

  const VisitorDetailsScreen2({
    Key? key,
    required this.visitorLog,
    this.unitList,
    this.image,required this.isFromMissedApprovalScreen
  }) : super(key: key);

  @override
  State<VisitorDetailsScreen2> createState() => _VisitorDetailsScreenState();
}

class _VisitorDetailsScreenState extends State<VisitorDetailsScreen2> {
  late ScrollController _scrollController;

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
    // Empty method to handle scroll events
    // We keep this to maintain the listener structure
  }

  @override
  Widget build(BuildContext context) {
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
                        // Open full-screen view when tapped
                        _showFullImage(context, widget.image);
                      },
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 100,
                          backgroundImage: widget.image != null &&
                                  widget.image!.isNotEmpty
                              ? NetworkImage(
                                  widget.image!) // Show visitor's image
                              : const NetworkImage(
                                  "https://cdn.pixabay.com/photo/2022/06/05/07/04/person-7243410_1280.png"), // Default image
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.visitorLog.visitorName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
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
                  const SizedBox(height: 8),
                  // _buildChip(
                  //   widget.visitorLog.purpose_sub_category_name ??
                  //       widget.visitorLog.visitor_purpose_Category_name ??
                  //       "",
                  //   Icons.category_rounded,
                  //   const Color(0xffFFEBE6),
                  // ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xffFFEBE6),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      _capitalizeFirstLetter(
                          widget.visitorLog.purposeSubCategoryName ??
                              widget.visitorLog.purposeCategoryName ??
                              ""),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: "Contact Information",
                    children: [
                      _buildInfoTile(
                        icon: Icons.phone,
                        title: "Phone Number",
                        subtitle: widget.visitorLog.visitorMobile,
                        iconColor: Colors.green,
                        trailing: _buildCallButton(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: "Visit Details",
                    children: [
                      _buildInfoTile(
                        icon: Icons.apartment,
                        title: "Visiting Unit",
                        subtitle: widget.visitorLog.unitDetails.building_unit ==
                                "0001"
                            ? "Society Office"
                            : (widget.visitorLog.unitDetails.building_unit !=
                                        null &&
                                    widget.visitorLog.unitDetails
                                            .building_unit !=
                                        "")
                                ? widget.visitorLog.unitDetails.building_unit
                                    .toString()
                                : "N/A",
                        iconColor: const Color.fromARGB(255, 225, 181, 154),
                      ),
                      if (widget.visitorLog.inGate.isNotEmpty)
                        _buildInfoTile(
                          icon: Icons.meeting_room,
                          title: "In-Gate",
                          subtitle: widget.visitorLog.inGate,
                          iconColor: const Color.fromARGB(255, 225, 181, 154),
                        ),
                      // if (widget.visitorLog.visitor_coming_from != null)
                      if (widget.visitorLog.purposeSubCategoryName
                                  ?.toLowerCase() ==
                              "DELIVERY" ||
                          widget.visitorLog.purposeSubCategoryName
                                      ?.toLowerCase() ==
                                  "CABS" &&
                              widget.visitorLog.visitorComingFrom != null)
                        _buildInfoTile(
                          icon: Icons.location_on,
                          title: "Coming From",
                          subtitle:
                              widget.visitorLog.visitorComingFrom.toString(),
                          iconColor: const Color.fromARGB(255, 225, 181, 154),
                        ),

                      // if (widget.visitorLog. != null ||
                      //     widget.visitorLog.carNumber != null)
                      //   _buildInfoTile(
                      //     icon: widget.visitorLog.visitor_card_number != null
                      //         ? Icons.badge
                      //         : Icons.directions_car,
                      //     // Use car icon if carNumber is present
                      //     title: widget.visitorLog.visitor_card_number != null
                      //         ? "Card Number"
                      //         : "Car Number",
                      //     // Change title accordingly
                      //     subtitle: widget.visitorLog.visitor_card_number
                      //         ?.toString() ??
                      //         widget.visitorLog.carNumber?.toString() ??
                      //         'N/A',
                      //     // Show available value
                      //     iconColor:
                      //     widget.visitorLog.visitor_card_number != null
                      //         ? const Color.fromARGB(255, 225, 181, 154)
                      //         : Color.fromARGB(255, 225, 181, 154),
                      //   ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Show timeline or buttons based on visitor status and source
                  if (!widget.isFromMissedApprovalScreen||
                      widget.visitorLog.allowStatus.toLowerCase() ==
                          "allowed" ||
                      widget.visitorLog.allowStatus.toLowerCase() ==
                          "always_allowed" ||
                      widget.visitorLog.allowStatus.toLowerCase() ==
                          "allowed_by_gatekeeper")
                    _buildSection(
                      title: "Visitor Timeline",
                      children:
                          // Call the _buildTimeline method to generate the timeline items
                          _buildTimeline(),
                    )
                  else if(widget.isFromMissedApprovalScreen)
                    _buildSection(
                      title: "Actions",
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle, size: 16),
                              label: const Text('Allow by Gatekeeper'),
                              onPressed: () => _allowByGatekeeper(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry'),
                              onPressed: () => _retryPermission(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
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
    addTimelineItem(
      label: "Approved By",
      description: widget.unitList == "0001"
          ? "Pre approved Staff"
          : _getFormattedAllowStatus(widget.visitorLog.allowStatus),
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

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(26), // 0.1 * 255 = ~26
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
      label: const Text('Call'),
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
    myFluttertoast(
      msg: message,
      backgroundColor: isError ? Colors.red : Colors.green,
    );
  }
}
