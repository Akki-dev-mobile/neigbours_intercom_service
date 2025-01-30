import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:ionicons/ionicons.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
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
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: Theme.of(context).primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  widget.image != null && widget.image!.isNotEmpty
                      ? Image.network(
                          widget.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildFallbackImage(context),
                        )
                      : _buildFallbackImage(context),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Container(
                padding: EdgeInsets.all(16),
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
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        if (widget.visitorLog.visitor_count.toString() != '1')
                          _buildChip(
                            "${widget.visitorLog.visitor_count} visitors",
                            Icons.people,
                            Color(0xffFFB080),
                          ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _buildChip(
                      widget.visitorLog.purpose_sub_category_name ??
                          widget.visitorLog.visitor_purpose_Category_name ??
                          "",
                      Icons.category_rounded,
                      Color(0xffFFEBE6),
                    ),
                    SizedBox(height: 16),
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
                    SizedBox(height: 16),
                    _buildSection(
                      title: "Visit Details",
                      children: [
                        _buildInfoTile(
                          icon: Icons.apartment,
                          title: "Visiting Unit",
                          subtitle: widget.unitList == "0001"
                              ? "Society Office"
                              : widget.unitList ?? "N/A",
                          iconColor: Color(0xffFFB080),
                        ),
                        if (widget.visitorLog.visitor_coming_from != null)
                          _buildInfoTile(
                            icon: Icons.location_on,
                            title: "Coming From",
                            subtitle: widget.visitorLog.visitor_coming_from
                                .toString(),
                            iconColor: Color(0xffFFB080),
                          ),
                        if (widget.visitorLog.visitor_card_number != null)
                          _buildInfoTile(
                            icon: Icons.badge,
                            title: "Card Number",
                            subtitle: widget.visitorLog.visitor_card_number
                                .toString(),
                            iconColor: Color(0xffFFB080),
                          ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildSection(
                      title: "Timeline",
                      children: [
                        _buildTimelineTile(
                          "Check In",
                          widget.visitorLog.visitor_check_in!,
                          Colors.green,
                          isFirst: true,
                          isLast: widget.visitorLog.visitor_check_out == null,
                        ),
                        if (widget.visitorLog.visitor_check_out != null)
                          _buildTimelineTile(
                            "Check Out",
                            widget.visitorLog.visitor_check_out!,
                            Colors.red,
                            isFirst: false,
                            isLast: true,
                          ),
                      ],
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

  Widget _buildTimelineTile(
    String label,
    DateTime time,
    Color color, {
    required bool isFirst,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
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
                  isFirst ? Icons.login : Icons.logout,
                  size: 12,
                  color: color,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  margin: EdgeInsets.symmetric(vertical: 4),
                  color: Colors.grey.withOpacity(0.3),
                ),
            ],
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(time),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (!isLast) SizedBox(height: 24),
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
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
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
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor),
          ),
          SizedBox(width: 12),
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
                  style: TextStyle(
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton() {
    return ElevatedButton.icon(
      icon: Icon(Icons.call, size: 16),
      label: Text('Call'),
      onPressed: () => _makePhoneCall(widget.visitorLog.visitor?.mobile ?? ""),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
