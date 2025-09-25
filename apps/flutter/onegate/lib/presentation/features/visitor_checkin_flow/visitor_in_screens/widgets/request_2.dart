import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/self_entry/self_home_view.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../../generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/utils/route_tracker.dart';

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
  final bool?
      isGatekeeperQRPasscodeEntry; // New parameter to distinguish Gatekeeper QR/Passcode entry

  RequestPermissionPage2(
      {Key? key,
      required this.visitor,
      this.request,
      this.logID,
      this.visitorLog,
      this.unitList,
      this.status,
      this.selfcheckinFlow,
      this.isGatekeeperQRPasscodeEntry})
      : super(key: key);

  @override
  State<RequestPermissionPage2> createState() => _RequestPermissionPage2State();
}

class _RequestPermissionPage2State extends State<RequestPermissionPage2> {
  final bool _isUploading = false;
  final double _uploadProgress = 0;
  bool? self;
  // Different Lottie animations for Express Entry vs Gatekeeper flows
  static const Map<RequestType, String> expressEntryLottieAnimations = {
    RequestType.allowByGatekeeper:
        'https://assets.lottiefiles.com/packages/lf20_jcikwtux.json', // Pre-approval animation
  };

  static const Map<RequestType, String> gatekeeperLottieAnimations = {
    RequestType.allowByGatekeeper:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/allow_gatekeeper_a7f14dfb91.json?updated_at=2023-09-21T12:29:40.807Z', // Original gatekeeper animation
  };

  String requestMessages(BuildContext context, RequestType type) {
    final l10n = AppLocalizations.of(context)!;
    return {
          RequestType.allowByGatekeeper: _shouldUseExpressEntryText()
              ? l10n
                  .visitorIsAllowedByGatekeeper // Express Entry or Gatekeeper QR/Passcode: "Visitor is pre-approved by member"
              : l10n
                  .visitorIsAllowedByGatekeeperOriginal, // Gatekeeper Mobile: "Visitor is allowed by gatekeeper" (original text)
        }[type] ??
        l10n.unknownRequestType;
  }

  // Helper method to determine if we should use Express Entry text and animation
  bool _shouldUseExpressEntryText() {
    // Express Entry flow
    if (self == true) return true;

    // Gatekeeper QR/Passcode entry flow
    if (self == false && widget.isGatekeeperQRPasscodeEntry == true)
      return true;

    // Gatekeeper Mobile entry flow (default)
    return false;
  }

  static const Map<RequestType, Color> _requestMessagesColor = {
    RequestType.allowByGatekeeper: Colors.green,
  };

  @override
  void initState() {
    super.initState();
    self = widget.selfcheckinFlow;
    _trackExpressEntryRoute();
  }

  // Track that user is in express entry flow
  Future<void> _trackExpressEntryRoute() async {
    if (widget.selfcheckinFlow == true) {
      await RouteTracker.saveCurrentRoute(
        'RequestPermissionPage2',
        isExpressEntry: true,
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Dialog cannot be dismissed by tapping outside
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Icon with OneGate theme
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xff4CAF50),
                          const Color(0xff2E7D32),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff4CAF50).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title with OneGate typography
                  Text(
                    'Success!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color:
                          const Color(0xff212427), // OneGate primary text color
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Your visit has been processed',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color:
                          const Color(0xff57636C), // OneGate muted text color
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Message container with OneGate styling
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xffFFEBE6)
                          .withOpacity(0.3), // OneGate primary container color
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xffF44336)
                            .withOpacity(0.1), // OneGate red color
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMessageRow(
                            '✅ Your visitor entry has been successfully recorded.'),
                        const SizedBox(height: 16),
                        _buildMessageRow(
                            '🏷️ Please ask the receptionist to assign an access card for you.'),
                        const SizedBox(height: 16),
                        _buildMessageRow(
                            '🚪 This will allow easy access to the lift and your designated floor.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // OK Button with OneGate theme
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xff212427), // OneGate primary text color
                          Color(0xff57636C), // OneGate muted text color
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
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
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        // Navigate based on flow type
                        if (self == true) {
                          // Express Entry flow - navigate to express entry dashboard
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SelfHomeView(),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        } else {
                          // Gatekeeper flow - navigate to gatekeeper dashboard
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GateDashboardView(),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: const Color(0xff212427), // OneGate primary text color
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                onTap: () {
                  if (self == true) {
                    // Express Entry flow - show success dialog
                    _showSuccessDialog();
                  } else {
                    // Gatekeeper flow (both mobile and QR/Passcode) - navigate directly without dialog
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GateDashboardView(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  }
                },
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
            title: Text(
              l10n.request,
              style: const TextStyle(
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
                        onPressed: () {
                          if (self == true) {
                            // Express Entry flow - show success dialog
                            _showSuccessDialog();
                          } else {
                            // Gatekeeper flow (both mobile and QR/Passcode) - navigate directly without dialog
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GateDashboardView(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.white, size: 24),
                        label: Text(
                          l10n.finish,
                          style: const TextStyle(
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
                  context: context,
                  icon: Icons.phone_outlined,
                  iconColor: Colors.green,
                  label: AppLocalizations.of(context)!.mobile,
                  value: widget.visitor.mobile ?? "",
                ),
                const SizedBox(height: 10),
                if (widget.visitorLog?.visitor_coming_from != null &&
                    widget.visitorLog!.visitor_coming_from!.isNotEmpty)
                  Column(
                    children: [
                      _buildDetailRow(
                        context: context,
                        icon: Icons.location_on_outlined,
                        iconColor: Colors.orange,
                        label: AppLocalizations.of(context)!.comingFrom,
                        value: widget.visitorLog?.visitor_coming_from ??
                            AppLocalizations.of(context)!.notSpecified,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                _buildDetailRow(
                  context: context,
                  icon: _getPurposeIcon(
                      widget.visitorLog?.visitor_purpose_Category_name),
                  iconColor: Colors.orange,
                  label: AppLocalizations.of(context)!.purpose,
                  value: widget.visitor.isStaff == true
                      ? AppLocalizations.of(context)!.staff
                      : widget.visitorLog?.visitor_purpose_Category_name ??
                          AppLocalizations.of(context)!.notSpecified,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
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
              _getLottieAnimationUrl(requestType),
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
              requestMessages(context, requestType) ?? "",
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

  String _getLottieAnimationUrl(RequestType requestType) {
    // Use different animations based on flow type
    if (_shouldUseExpressEntryText()) {
      // Express Entry flow or Gatekeeper QR/Passcode - use pre-approval animation
      return expressEntryLottieAnimations[requestType] ?? "";
    } else {
      // Gatekeeper Mobile flow - use original gatekeeper animation
      return gatekeeperLottieAnimations[requestType] ?? "";
    }
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
    final l10n = AppLocalizations.of(context)!;
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
                      "${l10n.uploading} ${(progress * 100).toStringAsFixed(0)}%",
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
