// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VisitorDetailsScreen extends StatefulWidget {
  final String visitorName;
  final String passId;
  final String mobileNumber;
  final String comingFrom;
  final String unit;
  final String? profileImageUrl;
  final bool isPendingApproval;

  const VisitorDetailsScreen({
    Key? key,
    required this.visitorName,
    required this.passId,
    required this.mobileNumber,
    required this.comingFrom,
    required this.unit,
    this.profileImageUrl,
    this.isPendingApproval = true,
  }) : super(key: key);

  @override
  State<VisitorDetailsScreen> createState() => _VisitorDetailsScreenState();
}

class _VisitorDetailsScreenState extends State<VisitorDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with OneGate branding
            _buildHeader(context, isTablet),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 16,
                  vertical: isTablet ? 20 : 16,
                ),
                child: Column(
                  children: [
                    // Visitor profile section
                    _buildVisitorProfile(context, isTablet),

                    SizedBox(height: isTablet ? 24 : 20),

                    // Visitor details section
                    _buildVisitorDetails(context, isTablet),

                    SizedBox(height: isTablet ? 24 : 20),

                    // Pending approval message (if applicable)
                    if (widget.isPendingApproval)
                      _buildPendingApprovalMessage(context, isTablet),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: isTablet ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // OneGate logo/icon
          Container(
            padding: EdgeInsets.all(isTablet ? 10 : 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xffF44336),
                  Color(0xffD32F2F),
                ],
              ),
              borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffF44336).withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.sensor_door_rounded,
              color: Colors.white,
              size: isTablet ? 24 : 20,
            ),
          ),

          SizedBox(width: isTablet ? 16 : 12),

          // App title
          Expanded(
            child: Text(
              'onegate',
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xff212427),
                letterSpacing: 0.5,
              ),
            ),
          ),

          // New Entry button
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 8 : 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xffF44336).withOpacity(0.1),
              borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
              border: Border.all(
                color: const Color(0xffF44336).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_home_rounded,
                  color: const Color(0xffF44336),
                  size: isTablet ? 18 : 16,
                ),
                SizedBox(width: isTablet ? 8 : 6),
                Text(
                  'New Entry',
                  style: TextStyle(
                    color: const Color(0xffF44336),
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorProfile(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile picture with loading indicator
          Stack(
            alignment: Alignment.center,
            children: [
              // Loading indicator ring
              Container(
                width: isTablet ? 120 : 100,
                height: isTablet ? 120 : 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xffF44336).withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: CircularProgressIndicator(
                  value: 0.7, // Partial loading
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xffF44336),
                  ),
                  backgroundColor: Colors.grey.withOpacity(0.2),
                ),
              ),

              // Profile image
              Container(
                width: isTablet ? 100 : 80,
                height: isTablet ? 100 : 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xffF44336),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: widget.profileImageUrl != null
                      ? Image.network(
                          widget.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultProfileImage();
                          },
                        )
                      : _buildDefaultProfileImage(),
                ),
              ),
            ],
          ),

          SizedBox(height: isTablet ? 20 : 16),

          // Pass ID section
          Row(
            children: [
              Container(
                width: 2,
                height: isTablet ? 40 : 32,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pass ID',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: const Color(0xff57636C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isTablet ? 4 : 2),
                  Text(
                    '#${widget.passId}',
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff212427),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultProfileImage() {
    return Container(
      color: const Color(0xffF44336).withOpacity(0.1),
      child: Center(
        child: Icon(
          Icons.person,
          size: 40,
          color: const Color(0xffF44336),
        ),
      ),
    );
  }

  Widget _buildVisitorDetails(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visitor name
          Text(
            widget.visitorName,
            style: TextStyle(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xff212427),
              letterSpacing: 0.5,
            ),
          ),

          SizedBox(height: isTablet ? 20 : 16),

          // Visitor information rows
          _buildInfoRow(
            context: context,
            isTablet: isTablet,
            icon: Icons.phone_rounded,
            label: 'Mobile',
            value: widget.mobileNumber,
            iconColor: const Color(0xffF44336),
            iconBg: const Color(0xffFFEBEE),
          ),

          SizedBox(height: isTablet ? 16 : 12),

          _buildInfoRow(
            context: context,
            isTablet: isTablet,
            icon: Icons.location_on_rounded,
            label: 'Coming From',
            value: widget.comingFrom,
            iconColor: const Color(0xffF44336),
            iconBg: const Color(0xffFFEBEE),
          ),

          SizedBox(height: isTablet ? 16 : 12),

          _buildInfoRow(
            context: context,
            isTablet: isTablet,
            icon: Icons.apartment_rounded,
            label: 'Unit',
            value: widget.unit,
            iconColor: const Color(0xffF44336),
            iconBg: const Color(0xffFFEBEE),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required bool isTablet,
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Row(
      children: [
        // Icon container
        Container(
          width: isTablet ? 48 : 40,
          height: isTablet ? 48 : 40,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: isTablet ? 24 : 20,
          ),
        ),

        SizedBox(width: isTablet ? 16 : 12),

        // Label and value
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12,
                  color: const Color(0xff57636C),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: isTablet ? 4 : 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff212427),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingApprovalMessage(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Information icon
          Container(
            width: isTablet ? 48 : 40,
            height: isTablet ? 48 : 40,
            decoration: BoxDecoration(
              color: const Color(0xffF44336).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: const Color(0xffF44336),
              size: isTablet ? 24 : 20,
            ),
          ),

          SizedBox(width: isTablet ? 16 : 12),

          // Message text
          Expanded(
            child: Text(
              'Please wait for some time. You will receive member\'s approval on your mobile.',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: const Color(0xff212427),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
