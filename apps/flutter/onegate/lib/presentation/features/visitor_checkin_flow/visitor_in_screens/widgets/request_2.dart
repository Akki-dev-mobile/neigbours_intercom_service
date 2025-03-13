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
          RequestType.allowByGatekeeper:
              self == true ? "Visitor is Self Check In" : "Visitor is allowed",
        }[type] ??
        "Unknown request type";
  }

  static const Map<RequestType, Color> _requestMessagesColor = {
    RequestType.allowByGatekeeper: Colors.green,
  };

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
      child: MyScrollView(
        pageTitleWidget: _buildHeader(),
        hasBackButton: false,
        pageBody: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildVisitorProfile(),
            const SizedBox(height: 24),
            _buildLottieSection(requestType),
            const SizedBox(height: 100),
            Align(
              alignment: Alignment.center,
              child: CustomLargeBtn(
                text: 'Finish',
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
                          builder: (context) => GateDashboardView(),
                        ),
                      ),
              ),
            ),
            const SizedBox(
              height: 30,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
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
                    builder: (context) => GateDashboardView(),
                  ),
                ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
                border: Border.all(color: const Color.fromARGB(93, 0, 0, 0)),
                borderRadius: BorderRadius.circular(10)),
            child:
                const Icon(Icons.home_outlined, color: Colors.black, size: 30),
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
        // Show Lottie animation based on request type
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
        // Show status message
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

  Widget _buildVisitorProfile() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ✅ Visitor Image
        Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
              ),
              child: ClipOval(
                child: widget.visitor.visitor_image != null &&
                        widget.visitor.visitor_image!.isNotEmpty
                    ? Image.network(
                        widget.visitor.visitor_image!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Symbols.person,
                              size: 60, color: Colors.grey);
                        },
                      )
                    : const Icon(Symbols.person, size: 60, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),

        // ✅ Vertical Divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16), // Spacing
          child: Container(
            width: 1.5, // Thickness
            height: 175, // Adjust based on content height
            color: Colors.grey.shade400,
          ),
        ),

        // ✅ Visitor Details (Aligned Right)
        Expanded(
          // This ensures that the details section can expand and push content down if needed
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The name will move down if needed
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
              widget.visitorLog?.visitor_coming_from != null
                  ? _buildDetailRow(
                      icon: Icons.location_on_outlined,
                      iconColor: Colors.orange,
                      label: "Coming From",
                      value: widget.visitorLog?.visitor_coming_from ??
                          "Not specified",
                    )
                  : const SizedBox(),
              const SizedBox(height: 10),
              _buildDetailRow(
                icon: _getPurposeIcon(
                    widget.visitorLog?.visitor_purpose_Category_name),
                iconColor: Colors.orange,
                label: "Purpose",
                value: widget.visitorLog?.visitor_purpose_Category_name ??
                    "Not specified",
              ),
            ],
          ),
        ),
      ],
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 15),
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
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
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
