import 'package:flutter/material.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

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

  static const Map<RequestType, String> _lottieAnimations = {
    RequestType.allowByGatekeeper:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/accepted_ef4c4982b2.json',
  };

  static const Map<RequestType, String> _requestMessages = {
    RequestType.allowByGatekeeper: "Visitor is always allowed by member",
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
        pageTitle: 'Request Permission',
        hasBackButton: true,
        pageBody: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVisitorCard(context),
            const SizedBox(height: 24),
            Center(
              child: Lottie.network(
                _lottieAnimations[requestType]!,
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _requestMessages[requestType]!,
                style: TextStyle(
                  fontSize: 16,
                  color: _requestMessagesColor[requestType],
                ),
              ),
            ),
            const SizedBox(height: 24),
            CustomLargeBtn(
              text: 'Finish',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GateDashboardView(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
