import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gate_bu.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/self_entry/self_home_view.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:shimmer/shimmer.dart';

enum RequestType {
  allowByGatekeeper,
}

class RequestPermissionPage2 extends StatefulWidget {
  final Visitor visitor;
  final String? logID;
  final VisitorLog? visitorLog;
  List<String>? unitList;
  final String? request;
  int? status;
  final bool? selfcheckinFlow;

  RequestPermissionPage2(
      {Key? key,
      required this.visitor,
      this.request,
      this.logID,
      this.visitorLog,
      this.unitList,
      this.status,
      this.selfcheckinFlow})
      : super(key: key);

  @override
  State<RequestPermissionPage2> createState() => _RequestPermissionPage2State();
}

class _RequestPermissionPage2State extends State<RequestPermissionPage2> {
  final bool _isUploading = false;
  final double _uploadProgress = 0;
  bool? self;
  static const Map<RequestType, String> lottieAnimations = {
    RequestType.allowByGatekeeper:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/allow_gatekeeper_a7f14dfb91.json?updated_at=2023-09-21T12:29:40.807Z',
  };

  String requestMessages(RequestType type) {
    return {
          RequestType.allowByGatekeeper: self == true
              ? "Visitor is Self Check In"
              : "Visitor is allowed by gatekeeper",
        }[type] ??
        "Unknown request type";
  }

  static const Map<RequestType, Color> _requestMessagesColor = {
    RequestType.allowByGatekeeper: Colors.green,
  };

  @override
  void initState() {
    super.initState();
    self = widget.selfcheckinFlow;
  }

  @override
  Widget build(BuildContext context) {
    const requestType = RequestType.allowByGatekeeper;
    log(widget.status.toString());
    return LoadingOverlay(
      isUploading: _isUploading,
      progress: _uploadProgress,
      child: WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => widget.selfcheckinFlow == true
                    ? Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SelfHomeView(),
                        ),
                      )
                    : Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GateDashboardView(),
                        ),
                      ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xffF44336).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.home_outlined,
                      color: Color(0xffF44336), size: 28),
                ),
              ),
            ),
            title: const Text(
              'Request',
              style: TextStyle(
                color: Color(0xff212427),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildVisitorProfileCard(),
                        const SizedBox(height: 60),
                        _buildLottieSection(requestType),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 0.0, vertical: 16.0),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.001),
                        offset: Offset(0, -3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Container(
                      height: 56,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xff212427),
                            Color(0xff57636C),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextButton.icon(
                        onPressed: () => widget.selfcheckinFlow == true
                            ? Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SelfHomeView(),
                                ),
                              )
                            : Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const GateDashboardView(),
                                ),
                              ),
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.white, size: 24),
                        label: const Text(
                          "Finish",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisitorProfileCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Visitor Image
          Column(
            children: [
              ClipOval(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: widget.visitor.visitor_image?.isNotEmpty == true
                      ? Image.network(
                          widget.visitor.visitor_image!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Symbols.person,
                                size: 60, color: Colors.grey);
                          },
                        )
                      : const Icon(Symbols.person,
                          size: 60, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
          // Vertical Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: 1.5,
              height: 120,
              color: Colors.grey.shade400,
            ),
          ),
          // Visitor Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${widget.visitor.name}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  icon: Icons.phone_outlined,
                  iconColor: Colors.green,
                  label: "Mobile",
                  value: widget.visitor.mobile ?? "",
                ),
                const SizedBox(height: 10),
                if (widget.visitorLog?.visitor_coming_from != null &&
                    widget.visitorLog!.visitor_coming_from!.isNotEmpty)
                  Column(
                    children: [
                      _buildDetailRow(
                        icon: Icons.location_on_outlined,
                        iconColor: Colors.orange,
                        label: "Coming From",
                        value: widget.visitorLog?.visitor_coming_from ??
                            "Not specified",
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                _buildDetailRow(
                  icon: _getPurposeIcon(
                      widget.visitorLog?.visitor_purpose_Category_name),
                  iconColor: Colors.orange,
                  label: "Purpose",
                  value: widget.visitor.isStaff == true
                      ? "Staff"
                      : widget.visitorLog?.visitor_purpose_Category_name ??
                          "Not specified",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE), // light red
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.red, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          "$label:",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLottieSection(RequestType requestType) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: SizedBox(
            height: 250,
            child: Lottie.network(
              lottieAnimations[requestType] ?? "",
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Shimmer.fromColors(
            baseColor: _requestMessagesColor[requestType]!,
            highlightColor: Colors.black45,
            child: Text(
              requestMessages(requestType) ?? "",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _requestMessagesColor[requestType],
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getPurposeIcon(String? category) {
    switch (category?.toUpperCase()) {
      case "DELIVERY":
        return Icons.inventory_2_outlined;
      case "CABS":
        return Symbols.local_taxi;
      case "VENDOR":
        return Symbols.storefront;
      default:
        return Icons.person_2_outlined;
    }
  }
}

class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isUploading;
  final double progress;

  const LoadingOverlay({
    Key? key,
    required this.child,
    this.isUploading = false,
    this.progress = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isUploading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Uploading... ${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
