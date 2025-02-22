import 'package:flutter/material.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_screens/ui/request_permission_page.dart';
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

  RequestPermissionPage2(
      {Key? key,
      required this.visitor,
      this.request,
      this.logID,
      this.visitorLog,
      this.unitList})
      : super(key: key);

  @override
  State<RequestPermissionPage2> createState() => _RequestPermissionPage2State();
}

class _RequestPermissionPage2State extends State<RequestPermissionPage2> {
  bool _isUploading = false;
  double _uploadProgress = 0;

  static const Map<RequestType, String> lottieAnimations = {
    RequestType.allowByGatekeeper:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/allow_gatekeeper_a7f14dfb91.json?updated_at=2023-09-21T12:29:40.807Z',
  };

  static const Map<RequestType, String> requestMessages = {
    RequestType.allowByGatekeeper: "Visitor is allowed by Gatekeeper",
  };

  static const Map<RequestType, Color> _requestMessagesColor = {
    RequestType.allowByGatekeeper: Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    const requestType = RequestType.allowByGatekeeper;

    return LoadingOverlay(
      isUploading: _isUploading,
      progress: _uploadProgress,
      child: MyScrollView(
        pageTitleWidget: _buildHeader(),

        // pageTitle: 'Request Permission',
        hasBackButton: false,
        pageBody: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment
              .start, // Ensures elements are aligned at the top
          children: [
            _buildVisitorProfile(),
            const SizedBox(height: 24),
            _buildLottieSection(requestType),
            const SizedBox(height: 100),
            Align(
              alignment: Alignment.center, // Centers the button horizontally
              child: CustomLargeBtn(
                text: 'Finish',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GateDashboardView(),
                  ),
                ),
              ),
            ),
            SizedBox(
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
          onTap: () => Navigator.push(
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
              requestMessages[requestType] ?? "",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _requestMessagesColor[requestType],
              ),
            ),
          ),
        ),
        // Display action buttons when time is expired
        // if (requestType == RequestType.notRecheable)
        //   _buildNotRecheableButtons(), // Show buttons for retrying or allowing by gatekeeper
      ],
    );
  }

  Widget _buildVisitorProfile() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Visitor Image
        Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.shade400, width: 4),
              ),
              child: ClipOval(
                child: Image.network(
                  widget.visitor.visitor_image!,
                  fit: BoxFit.cover,
                ),
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
                  : SizedBox(),
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
        return Icons.inventory_2_outlined; // Delivery icon
      case "CABS":
        return Symbols
            .local_taxi; // Cabs icon (make sure `Symbols` is imported or replace with `Icons`)
      case "VENDOR":
        return Symbols
            .storefront; // Vendor icon (ensure `Symbols` is properly imported or use `Icons`)
      default:
        return Icons.person_2_outlined; // Default icon if no match
    }
  }

  Widget _buildVisitorCard(BuildContext context) {
    Color colortoshow = const Color(0xffFFB080);
    Size screensize = MediaQuery.of(context).size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Image.network(
                width: screensize.width * 0.37,
                height: screensize.height * 0.15,
                fit: BoxFit.fill,
                widget.visitor.visitor_image!),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(
            left: 25.0,
          ),
          child: Text(
            widget.visitor.name ?? "",
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 25.0),
          child: Container(
            decoration: BoxDecoration(
              color: colortoshow.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                widget.visitorLog?.visitor_purpose_Category_name ?? "",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: 16, right: 16),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Ionicons.call_outline, color: Colors.green),
                ),
                title: Text(
                  'Phone Number',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  widget.visitor.mobile ?? "",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 18.0, bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colortoshow.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Symbols.apartment,
                        color: colortoshow,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                            maxWidth: MediaQuery.of(context).size.width * 0.6,
                          ),
                          child: Text(
                            widget.unitList!.first,
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
              ),
            ],
          ),
        ),
      ],
    );
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
