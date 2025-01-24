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

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageBody: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
            ),
            child: widget.image != null
                ? Image.network(
                    widget.image ?? "",
                    height: MediaQuery.of(context).size.height * 0.4,
                    width: double.maxFinite,
                    fit: BoxFit.contain,
                  )
                : Center(
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        widget.visitorLog.visitor!.name!.isNotEmpty
                            ? widget.visitorLog.visitor!.name![0].toUpperCase()
                            : 'G',
                        style: const TextStyle(
                          fontSize: 60,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
          // Visitor Info Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.visitorLog.visitor!.name ?? "",
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    if (widget.visitorLog.visitor_count.toString() != '1')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xffFFB080),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people, size: 18),
                            SizedBox(width: 4),
                            Text(
                              "${widget.visitorLog.visitor_count} visitors",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xffFFEBE6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.visitorLog.purpose_sub_category_name != null
                        ? "${widget.visitorLog.purpose_sub_category_name}"
                        : "${widget.visitorLog.visitor_purpose_Category_name}",
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contact Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Ionicons.call_outline, color: Colors.green),
              ),
              title: Text(
                'Phone Number',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                widget.visitorLog.visitor!.mobile ?? "",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              trailing: ElevatedButton.icon(
                icon: Icon(Icons.call, size: 18),
                label: Text('Call'),
                onPressed: () =>
                    _makePhoneCall(widget.visitorLog.visitor!.mobile ?? ""),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),

          // Visit Details Section
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Unit Details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xffFFB080).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Symbols.apartment,
                              color: Color(0xffFFB080),
                            ),
                          ),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Visiting Unit',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.6,
                                ),
                                child: Text(
                                  widget.unitList == "0001"
                                      ? "Society Office"
                                      : widget.unitList!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                widget.visitorLog.visitor_coming_from != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(0xffFFB080).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Symbols.location_away_rounded,
                                    color: Color(0xffFFB080),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Coming From',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.6,
                                      ),
                                      child: Text(
                                        widget.visitorLog.visitor_coming_from
                                            .toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : SizedBox(),

                widget.visitorLog.visitor_card_number != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(0xffFFB080).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Symbols.badge,
                                    color: Color(0xffFFB080),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Card Number',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.6,
                                      ),
                                      child: Text(
                                        widget.visitorLog.visitor_card_number
                                            .toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : SizedBox(),

                Divider(
                  indent: 16,
                  endIndent: 16,
                  color: Colors.grey[200],
                ),
                // Check In/Out Times
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildTimeInfo(
                        context,
                        "Check In Time",
                        widget.visitorLog.visitor_check_in!,
                        Colors.green,
                      ),
                      if (widget.visitorLog.visitor_check_out != null) ...[
                        SizedBox(height: 16),
                        _buildTimeInfo(
                          context,
                          "Check Out Time",
                          widget.visitorLog.visitor_check_out!,
                          Colors.red,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ID Card Section
          // visitorLog.visitor_card_number != null || visitorLog.carNumber != null
          //      ? Container(
          //    margin: const EdgeInsets.only(left: 8),
          //    padding: const EdgeInsets.symmetric(
          //      vertical: 2,
          //      horizontal: 10,
          //    ),
          //    decoration: BoxDecoration(
          //      gradient: LinearGradient(
          //        colors: const [
          //          Color.fromRGBO(255, 236, 158, 0.8),
          //          Color.fromRGBO(255, 190, 168, 0.8),
          //        ],
          //        begin: Alignment.topRight,
          //        end: Alignment.bottomLeft,
          //      ),
          //      borderRadius: BorderRadius.circular(8),
          //      border: Border.all(
          //        color: Color.fromRGBO(255, 190, 168, 1),
          //      ),
          //    ),
          //    child: Row(
          //      children: [
          //        Lottie.asset(
          //          'assets/json/idcard.json',
          //          width: 30,
          //          height: 30,
          //          fit: BoxFit.cover,
          //        ),
          //        const SizedBox(width: 5),
          //        Text(
          //         visitorLog.visitor_card_number != null
          //              ? visitorLog.visitor_card_number!
          //              : visitorLog.carNumber ?? 'N/A',
          //          style: const TextStyle(
          //            color: Colors.black,
          //            fontWeight: FontWeight.w800,
          //            fontSize: 14,
          //          ),
          //        ),
          //      ],
          //    ),
          //  )
          //      : const SizedBox(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(
    BuildContext context,
    String label,
    DateTime time,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Symbols.schedule, color: color),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(time),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  DateTime _parseDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return DateTime
          .now(); // Return a fallback value if the string is null or empty
    }

    try {
      return DateTime.parse(dateTimeString);
    } catch (e) {
      // Handle invalid date formats gracefully
      return DateTime.now(); // Fallback value for invalid format
    }
  }
}
