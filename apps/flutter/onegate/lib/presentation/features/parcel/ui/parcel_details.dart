import 'dart:async';
import 'dart:developer';
import 'package:flutter_onegate/presentation/features/parcel/ui/parcel_list.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:intl/intl.dart';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ionicons/ionicons.dart';
import 'package:pinput/pinput.dart';
import 'package:url_launcher/url_launcher.dart';

class ParcelDetails extends StatefulWidget {
  final Map<String, dynamic> parcel;

  ParcelDetails({Key? key, required this.parcel}) : super(key: key);

  @override
  State<ParcelDetails> createState() => _ParcelDetailsState();
}

class _ParcelDetailsState extends State<ParcelDetails> {
  late ScrollController _scrollController;
  double _imageHeight = 160.0; // Initial circular height
  final double _maxImageHeight = 300.0; // Maximum expanded height
  bool _isExpanded = false;
  RemoteDataSource remoteDataSource = RemoteDataSource();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        _handleScroll();
      });
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
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
                          _showFullImage(
                              context, widget.parcel['parcel_image']);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          height: _imageHeight,
                          width: _imageHeight,
                          padding: EdgeInsets.all(isTablet ? 8 : 6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              shape: _isExpanded
                                  ? BoxShape.rectangle
                                  : BoxShape.circle,
                              borderRadius: _isExpanded
                                  ? BorderRadius.circular(20)
                                  : null,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                              image: widget.parcel['parcel_image'] != null &&
                                      widget.parcel['parcel_image'].isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(
                                          widget.parcel['parcel_image']),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: widget.parcel['parcel_image'] == null ||
                                    widget.parcel['parcel_image'].isEmpty
                                ? Icon(
                                    Icons.inventory_2,
                                    size: _isExpanded ? 80 : 60,
                                    color: const Color(0xffF44336),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isTablet ? 24 : 16),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 12),
                  color: Colors.transparent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.parcel['member_name'] ?? 'No Name',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xff212427),
                                    fontSize: isTablet ? 28 : 22,
                                  ),
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
                          _capitalizeFirstLetter(widget
                                  .parcel['purpose_sub_category_name']
                                  ?.toString() ??
                              'Parcel'),
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
                            subtitle:
                                widget.parcel['visitor_mobile'] ?? 'No Number',
                            iconColor: const Color(0xff43A047),
                            iconBg: const Color(0xffE8F5E9),
                            trailing: _buildCallButton(),
                          ),
                        ],
                      ),
                      SizedBox(height: isTablet ? 20 : 16),
                      _buildBorderedSection(
                        context,
                        isTablet,
                        title: "Unit Information",
                        children: [
                          _buildInfoTile(
                            icon: Icons.apartment,
                            title: "Unit Name",
                            subtitle: widget.parcel['unit_name'] ?? 'N/A',
                            iconColor: const Color(0xffF44336),
                            iconBg: const Color(0xffFFEBEE),
                          ),
                        ],
                      ),
                      SizedBox(height: isTablet ? 20 : 16),
                      _buildBorderedSection(
                        context,
                        isTablet,
                        title: "Parcel Timeline",
                        children: _buildTimeline(),
                      ),
                      const SizedBox(height: 150),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: widget.parcel['parcel_status'] != "picked"
            ? Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.black, Colors.grey],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      TextEditingController otpController =
                          TextEditingController();
                  remoteDataSource.getParcelOtp(
                    widget.parcel['parcel_id'].toString(),
                    widget.parcel['memb_mobile_number'].toString(),
                  );
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                    builder: (BuildContext context) {
                      return OtpBottomSheet(
                        remoteDataSource: remoteDataSource,
                        parcel: widget.parcel,
                        otpController: otpController,
                      );
                    },
                  );
                },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Mark as Picked',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : const SizedBox());
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return "";
    return text
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' ');
  }

  List<Widget> _buildTimeline() {
    List<Widget> timelineItems = [];

    // Add Check-In
    timelineItems.add(
      _buildTimelineTile(
        "Parcel Check-in",
        _parseTime(widget.parcel['log_created_at']) ?? DateTime.now(),
        Icons.login,
        Colors.green,
        isFirst: true,
        isLast: widget.parcel['parcel_status'] == "pending",
        showConnector: widget.parcel['parcel_status'] != "pending",
      ),
    );

    // Add Check-Out if available
    if (widget.parcel['parcel_status'] != "pending") {
      timelineItems.add(
        _buildTimelineTile(
          "Parcel Picked at",
          _parseTime(widget.parcel['log_verified_at']) ?? DateTime.now(),
          Icons.logout,
          Colors.red,
          isFirst: false,
          isLast: true,
          showConnector: false,
        ),
      );
    }

    return timelineItems;
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

  DateTime? _parseTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) {
      return null;
    }
    try {
      return DateFormat('yyyy-MM-dd hh:mm:ss a').parse(timeString);
    } catch (e) {
      print('Date parsing failed: $e');
      return null;
    }
  }

  Widget _buildTimelineTile(
    String label,
    DateTime time,
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
                DateFormat('dd MMM yyyy, hh:mm a').format(time),
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

  Widget _buildCallButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.call, size: 16, color: Colors.white),
      label: const Text('Call',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      onPressed: () => _makePhoneCall(widget.parcel['visitor_mobile'] ?? ''),
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
}

class OtpBottomSheet extends StatefulWidget {
  final RemoteDataSource remoteDataSource;
  final Map<String, dynamic> parcel;
  final TextEditingController otpController;

  const OtpBottomSheet({
    super.key,
    required this.remoteDataSource,
    required this.parcel,
    required this.otpController,
  });

  @override
  _OtpBottomSheetState createState() => _OtpBottomSheetState();
}

class _OtpBottomSheetState extends State<OtpBottomSheet> {
  int _timer = 0;
  Timer? _countdownTimer;
  FocusNode focusNode = FocusNode();
  String? errorText;
  bool isSubmitting = false;

  void _startTimer() {
    setState(() {
      _timer = 59;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timer > 0) {
        setState(() {
          _timer--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void validateOTP(String pin) {
    if (pin.length < 6) {
      setState(() {
        errorText = "OTP must be 6 digits.";
      });
    } else {
      setState(() {
        errorText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Enhanced Header Section
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xffF44336),
                  const Color(0xffE57373),
                  const Color(0xffFFAB91),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.6, 1.0],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffF44336).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left side with icon and text
                Expanded(
                  child: Row(
                    children: [
                      // Enhanced icon container
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.security,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Text content
                      Expanded(
                        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                              'Verification Required',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter the 6-digit code to pick up parcel',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Enhanced close button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Section
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
                top: 24,
                left: 20,
                right: 20,
              ),
              child: Column(
                children: [
                  // OTP Info Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade600,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
            Text(
                                'OTP Sent',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xff212427),
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Check your mobile for the verification code',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Enhanced OTP Input Section
            Column(
              children: [
                      Text(
                        'Enter Verification Code',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff212427),
                              fontSize: 22,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Type the 6-digit code from your SMS',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                      ),
                      const SizedBox(height: 24),

                      // Enhanced Pinput
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                  child: Pinput(
                    key: const Key("otp_field"),
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    length: 6,
                    onCompleted: validateOTP,
                    onChanged: (pin) {
                      if (errorText != null) {
                        setState(() {
                          errorText = null;
                        });
                      }
                    },
                    focusNode: focusNode,
                    controller: widget.otpController,
                    errorText: errorText,
                          animationDuration: const Duration(milliseconds: 300),
                    defaultPinTheme: PinTheme(
                            width: 48,
                            height: 56,
                      textStyle: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff212427),
                      ),
                      decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                    ),
                    submittedPinTheme: PinTheme(
                            width: 48,
                            height: 56,
                      textStyle: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                      ),
                      decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xff43A047),
                                  const Color(0xff66BB6A),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xff43A047),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xff43A047).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                    ),
                    errorPinTheme: PinTheme(
                            width: 48,
                            height: 56,
                      textStyle: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                      ),
                      decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xffF44336),
                                  const Color(0xffEF5350),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xffF44336),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xffF44336).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                    ),
                    focusedPinTheme: PinTheme(
                            width: 48,
                            height: 56,
                      textStyle: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff212427),
                      ),
                      decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.blue.shade400,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                    ),
                    followingPinTheme: PinTheme(
                            width: 48,
                            height: 56,
                      textStyle: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff212427),
                      ),
                      decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Enhanced Error Display
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: errorText != null ? 50 : 0,
                        child: errorText != null
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.red.shade50,
                                      Colors.red.shade100,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.error_outline_rounded,
                                        color: Colors.red.shade600,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                child: Text(
                                        errorText!,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                ),
              ),
            ),
                                  ],
                                ),
                              )
                            : const SizedBox(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Enhanced Resend Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade50,
                          Colors.indigo.shade50,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.shade100,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
              children: [
                            Icon(
                              Icons.schedule_rounded,
                              color: _timer == 0
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _timer == 0
                                  ? 'Didn\'t receive the code?'
                                  : 'Resend available in $_timer seconds',
                              style: TextStyle(
                                color: _timer == 0
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (_timer == 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade600,
                                  Colors.indigo.shade600,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                ),
              ],
            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: resendOtp,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.refresh_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Resend OTP',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Enhanced Submit Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black,
                          Colors.grey.shade800,
                          Colors.grey.shade600,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: isSubmitting ? null : submitOtp,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: isSubmitting
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
            const SizedBox(
                                        width: 20,
              height: 20,
                                        child: DashboardLoaderIcon(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Verifying...',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.verified_user_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Verify & Pick Parcel',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void resendOtp() async {
    try {
      await widget.remoteDataSource.getParcelOtp(
        widget.parcel['parcel_id'].toString(),
        widget.parcel['memb_mobile_number'].toString(),
      );
      _startTimer();
      _showEnhancedSuccessToast(
        title: 'OTP Resent',
        message: 'A new OTP has been sent to your mobile number',
        icon: Icons.message,
      );
    } catch (e) {
      _showEnhancedErrorToast(
        title: 'Resend Failed',
        message: 'Unable to send OTP. Please try again.',
        icon: Icons.error_outline,
      );
      log("Failed to resend OTP: $e");
    }
  }

  void submitOtp() async {
    String otp = widget.otpController.text;
    if (otp.length != 6) {
      setState(() {
        errorText = "Please enter a valid 6-digit OTP.";
      });
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final result = await widget.remoteDataSource.verifyParcelOtp(
        widget.parcel['parcel_id'].toString(),
        otp,
      );

      _showEnhancedSuccessToast(
        title: 'Parcel Picked Successfully!',
        message: 'The parcel has been marked as picked up',
        icon: Icons.inventory_2,
      );

      log("OTP verified: $result");

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ParcelList()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        errorText = "Invalid OTP. Please try again.";
        isSubmitting = false;
      });

      _showEnhancedErrorToast(
        title: 'Verification Failed',
        message: 'Invalid OTP entered. Please check and try again.',
        icon: Icons.lock_outline,
      );

      log("OTP verification failed: $e");
    }
  }

  /// Enhanced success toast
  void _showEnhancedSuccessToast({
    required String title,
    required String message,
    IconData? icon,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon ?? Icons.check_circle_rounded,
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
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xff43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 3000),
        elevation: 8,
      ),
    );
  }

  /// Enhanced error toast
  void _showEnhancedErrorToast({
    required String title,
    required String message,
    IconData? icon,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon ?? Icons.error_rounded,
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
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xffF44336),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 3000),
        elevation: 8,
      ),
    );
  }
}
