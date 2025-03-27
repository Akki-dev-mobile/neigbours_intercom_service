import 'dart:developer';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:common_widgets/common_widgets.dart';

class VisitorDetailsScreen extends StatefulWidget {
  final VisitorLog visitorLog;
  String? image;
  String? unitList;

  VisitorDetailsScreen(
      {Key? key, required this.visitorLog, this.unitList, this.image})
      : super(key: key);

  @override
  State<VisitorDetailsScreen> createState() => _VisitorDetailsScreenState();
}

class _VisitorDetailsScreenState extends State<VisitorDetailsScreen> {
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
    log("visitsomethingggggg ${widget.unitList}");
    print(widget.visitorLog.visitor_building_assignment);
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
              Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.visitorLog.visitor?.name ?? "Guest",
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                          ),
                        ),
                        if (widget.visitorLog.visitor_count.toString() != '1')
                          _buildChip(
                            "${widget.visitorLog.visitor_count} visitors",
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xffFFEBE6),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        _capitalizeFirstLetter(widget
                                .visitorLog.purpose_sub_category_name ??
                            widget.visitorLog.visitor_purpose_Category_name ??
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
                          subtitle: widget.visitorLog.visitor?.mobile ?? "N/A",
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
                          subtitle: widget.unitList == "0001"
                              ? "Society Office"
                              : (widget.unitList != null &&
                                      widget.unitList != "")
                                  ? widget.unitList.toString()
                                  : "N/A",
                          iconColor: const Color.fromARGB(255, 225, 181, 154),
                        ),
                        // if (widget.visitorLog.visitor_coming_from != null)
                        if (widget.visitorLog.visitor_purpose_Category_name
                                    ?.toLowerCase() ==
                                "DELIVERY" ||
                            widget.visitorLog.visitor_purpose_Category_name
                                        ?.toLowerCase() ==
                                    "CABS" &&
                                widget.visitorLog.visitor_coming_from != null)
                          _buildInfoTile(
                            icon: Icons.location_on,
                            title: "Coming From",
                            subtitle: widget.visitorLog.visitor_coming_from
                                .toString(),
                            iconColor: const Color.fromARGB(255, 225, 181, 154),
                          ),

                        if (widget.visitorLog.visitor_card_number != null ||
                            widget.visitorLog.carNumber != null)
                          _buildInfoTile(
                            icon: widget.visitorLog.visitor_card_number != null
                                ? Icons.badge
                                : Icons.directions_car,
                            // Use car icon if carNumber is present
                            title: widget.visitorLog.visitor_card_number != null
                                ? "Card Number"
                                : "Car Number",
                            // Change title accordingly
                            subtitle: widget.visitorLog.visitor_card_number
                                    ?.toString() ??
                                widget.visitorLog.carNumber?.toString() ??
                                'N/A',
                            // Show available value
                            iconColor:
                                widget.visitorLog.visitor_card_number != null
                                    ? const Color.fromARGB(255, 225, 181, 154)
                                    : Color.fromARGB(255, 225, 181, 154),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: "Visitor Timeline",
                      children:
                          // Call the _buildTimeline method to generate the timeline items
                          _buildTimeline(),
                    ),
                  ],
                ),
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
        label: "Check In",
        description: widget.visitorLog.visitor_check_in!,
        icon: Icons.login,
        color: Colors.green,
        index: currentIndex++,
      );
    }

    // Add Approved By
    addTimelineItem(
      label: "Approved By",
      description: toBeginningOfSentenceCase(widget.unitList == "0001"
              ? "Pre approved Staff"
              : (widget.visitorLog.approved_by ?? "Gatekeeper")) ??
          "N/A",
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
                color: color.withOpacity(0.2),
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
                color: color.withOpacity(0.5),
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
              color: iconColor.withOpacity(0.1),
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
      onPressed: () => _makePhoneCall(widget.visitorLog.visitor?.mobile ?? ""),
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
