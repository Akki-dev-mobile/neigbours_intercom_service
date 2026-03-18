import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/self_entry/self_home_view.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/semantics.dart';
import 'package:audioplayers/audioplayers.dart';
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
  bool _visitorCardEntryEnabled = false;
  // Different Lottie animations for Express Entry vs Gatekeeper flows
  static const Map<RequestType, String> expressEntryLottieAnimations = {
    RequestType.allowByGatekeeper:
        'assets/animations/pre-approved.json', // Pre-approval animation (local file)
  };

  static const Map<RequestType, String> gatekeeperLottieAnimations = {
    RequestType.allowByGatekeeper:
        'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/allow_gatekeeper_a7f14dfb91.json?updated_at=2023-09-21T12:29:40.807Z', // Original gatekeeper animation
  };

  String requestMessages(BuildContext context, RequestType type) {
    final l10n = AppLocalizations.of(context);
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
    _loadVisitorCardSetting();
    _trackExpressEntryRoute();
  }

  // Load visitor card entry setting
  Future<void> _loadVisitorCardSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _visitorCardEntryEnabled = prefs.getBool('visitorCardNumber') ?? false;
    });
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

  // Play success sound
  Future<void> _playSuccessSound() async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('media/audio/express_sucess.mp3'));
    } catch (e) {
      log('Error playing success sound: $e');
    }
  }

  void _showSuccessDialog() {
    // Play success sound
    _playSuccessSound();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async {
            // Prevent dialog from closing when user navigates back
            return false;
          },
          child: _ModernSuccessDialog(
            onOkPressed: () {
              Navigator.of(context).pop();
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                  if (self == true && _visitorCardEntryEnabled) {
                    // Express Entry flow with visitor card entry enabled - show success dialog
                    _showSuccessDialog();
                  } else {
                    // Express Entry flow with visitor card entry disabled OR Gatekeeper flow - navigate directly without dialog
                    if (self == true) {
                      // Express Entry - go to self entry home
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SelfHomeView(),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    } else {
                      // Gatekeeper flow - go to gatekeeper dashboard
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GateDashboardView(),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    }
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
                        // Express Entry only: Centered Finish button directly below Lottie
                        if (widget.selfcheckinFlow == true)
                          Center(
                            child: Container(
                              margin:
                                  const EdgeInsets.only(top: 100, bottom: 50),
                              width: MediaQuery.of(context).size.width * 0.8,
                              height: 56,
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
                                  if (self == true &&
                                      _visitorCardEntryEnabled) {
                                    _showSuccessDialog();
                                  } else {
                                    if (self == true) {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SelfHomeView(),
                                        ),
                                        (Route<dynamic> route) => false,
                                      );
                                    } else {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const GateDashboardView(),
                                        ),
                                        (Route<dynamic> route) => false,
                                      );
                                    }
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
                    child: (widget.selfcheckinFlow == true)
                        ? Container() // Hide bottom finish in Express Entry approved/rejected
                        : Container(
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
                                if (self == true && _visitorCardEntryEnabled) {
                                  _showSuccessDialog();
                                } else {
                                  if (self == true) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SelfHomeView(),
                                      ),
                                      (Route<dynamic> route) => false,
                                    );
                                  } else {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const GateDashboardView(),
                                      ),
                                      (Route<dynamic> route) => false,
                                    );
                                  }
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
                  label: AppLocalizations.of(context).mobile,
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
                        label: AppLocalizations.of(context).comingFrom,
                        value: widget.visitorLog?.visitor_coming_from ??
                            AppLocalizations.of(context).notSpecified,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                _buildDetailRow(
                  context: context,
                  icon: _getPurposeIcon(
                      widget.visitorLog?.visitor_purpose_Category_name),
                  iconColor: Colors.orange,
                  label: AppLocalizations.of(context).purpose,
                  value: widget.visitor.isStaff == true
                      ? AppLocalizations.of(context).staff
                      : widget.visitorLog?.visitor_purpose_Category_name ??
                          AppLocalizations.of(context).notSpecified,
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
    final screenWidth = MediaQuery.of(context).size.width;

    // Enhanced responsive breakpoints for better scaling
    final isSmallMobile = screenWidth <= 600;
    final isMediumTablet = screenWidth > 600 && screenWidth <= 900;
    final isLargeTablet = screenWidth > 900 && screenWidth <= 1200;

    // Enhanced responsive scaling factors for LOTTIE animations
    final lottieScaleFactor = isSmallMobile
        ? 1.0
        : isMediumTablet
            ? 1.4
            : isLargeTablet
                ? 1.8
                : 2.2; // Much more aggressive scaling for desktop

    // Base dimensions (mobile)
    const baseLottieHeight = 250.0;
    const baseTextFontSize = 20.0;
    const baseSpacing = 20.0;

    // Scaled dimensions
    final lottieHeight = baseLottieHeight * lottieScaleFactor;
    final textFontSize = baseTextFontSize * lottieScaleFactor;
    final spacing = baseSpacing * lottieScaleFactor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: SizedBox(
            height: lottieHeight,
            child: _buildLottieAnimation(requestType),
          ),
        ),
        SizedBox(height: spacing),
        Center(
          child: Shimmer.fromColors(
            baseColor: _requestMessagesColor[requestType]!,
            highlightColor: Colors.black45,
            child: Text(
              requestMessages(context, requestType) ?? "",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: textFontSize,
                fontWeight: FontWeight.bold,
                color: _requestMessagesColor[requestType],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLottieAnimation(RequestType requestType) {
    String animationPath = _getLottieAnimationUrl(requestType);

    // Check if it's a local asset or network URL
    if (animationPath.startsWith('assets/')) {
      // Use local asset
      return Lottie.asset(
        animationPath,
        fit: BoxFit.contain,
      );
    } else {
      // Use network URL
      return Lottie.network(
        animationPath,
        fit: BoxFit.contain,
      );
    }
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
    final l10n = AppLocalizations.of(context);
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
                    const DashboardLoaderIcon(),
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

// OneGate Success Dialog with confetti
class _ModernSuccessDialog extends StatefulWidget {
  final VoidCallback onOkPressed;

  const _ModernSuccessDialog({required this.onOkPressed});

  @override
  State<_ModernSuccessDialog> createState() => _ModernSuccessDialogState();
}

class _ModernSuccessDialogState extends State<_ModernSuccessDialog>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  // Sequential animation controllers
  late AnimationController _sequenceController;
  late AnimationController _okButtonPulseController;
  late Animation<double> _okButtonPulseAnimation;
  late AnimationController _handGestureController;
  late Animation<double> _handGestureOpacity;
  late Animation<Offset> _handGestureOffset;

  // Animation states
  int _currentRowIndex = 0;
  bool _isSequenceComplete = false;
  bool _isReduceMotionEnabled = false;
  final int _handGesturePlays = 0;
  bool _handGestureActive = false;

  @override
  void initState() {
    super.initState();

    // Check for reduce motion preference
    _checkReduceMotion();

    // Initialize confetti controller
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    // Initialize scale animation controller
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Initialize sequence animation controller
    _sequenceController = AnimationController(
      duration: const Duration(milliseconds: 2000), // Total sequence duration
      vsync: this,
    );

    // Initialize OK button pulse controller
    _okButtonPulseController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );

    // Hand gesture controller (tap nudge)
    _handGestureController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _handGestureOpacity = CurvedAnimation(
      parent: _handGestureController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );
    _handGestureOffset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.08), // ~8-10dp relative on typical sizes
    ).animate(CurvedAnimation(
      parent: _handGestureController,
      curve: Curves.easeOut,
    ));

    // Create scale animation with bounce effect
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.7, end: 1.05),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0),
        weight: 40,
      ),
    ]).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Create OK button pulse animation
    _okButtonPulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.06),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1.0),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _okButtonPulseController,
      curve: Curves.easeInOut,
    ));

    // Start the scale animation
    _scaleController.forward();

    // Start confetti after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _confettiController.play();

      // Play speech audio when confetti animation completes
      Future.delayed(const Duration(seconds: 2), () {
        _playSpeechAudio();
      });
    });

    // Start sequential animation if not reduced motion
    if (!_isReduceMotionEnabled) {
      _startSequentialAnimation();
    } else {
      // Show all rows completed immediately
      setState(() {
        _currentRowIndex = 3;
        _isSequenceComplete = true;
      });
      // Announce accessible state
      SemanticsService.announce('Ready — tap OK', TextDirection.ltr);
    }
  }

  // Check if reduce motion is enabled
  void _checkReduceMotion() {
    // This would typically check MediaQuery.of(context).accessibleNavigation
    // For now, we'll assume it's disabled unless explicitly set
    _isReduceMotionEnabled = false;
  }

  // Start the sequential animation
  void _startSequentialAnimation() {
    _animateNextRow();
  }

  // Animate the next row in sequence
  void _animateNextRow() {
    if (_currentRowIndex >= 3) {
      // Sequence complete - pulse OK button
      setState(() {
        _isSequenceComplete = true;
      });
      _okButtonPulseController.forward();
      // Trigger hand gesture hint if allowed
      if (!_isReduceMotionEnabled) {
        _startHandGestureSequence();
      } else {
        // Accessible static hint
        SemanticsService.announce('Ready — tap OK', TextDirection.ltr);
      }
      return;
    }

    // Wait for dwell time (1.2s) + tick animation (600ms) + advance delay (200ms)
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _currentRowIndex++;
        });
        _animateNextRow();
      }
    });
  }

  // Start hand gesture sequence (max 2 plays with 1.2s pause)
  void _startHandGestureSequence() async {
    if (!mounted) return;
    _handGestureActive = true;
    // Loop until user taps OK or dialog is closed
    while (mounted && _handGestureActive) {
      await _playHandGestureOnce();
      if (!mounted || !_handGestureActive) break;
      await Future.delayed(const Duration(milliseconds: 1200));
    }
  }

  Future<void> _playHandGestureOnce() async {
    try {
      // Sync a subtle pulse on the OK button (160ms)
      await _okButtonPulseController.forward();
      _okButtonPulseController.reset();

      // Play hand tap: move down and fade
      _handGestureController.reset();
      await _handGestureController.forward();
      await _handGestureController.reverse();
    } catch (_) {}
  }

  // Play speech audio
  Future<void> _playSpeechAudio() async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('media/audio/speech_audio.mp3'));
    } catch (e) {
      log('Error playing speech audio: $e');
    }
  }

  // Build animated sequential success card
  Widget _buildCombinedSuccessCard({
    required BuildContext context,
    required bool isTablet,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 360;
    final isMobile = screenWidth >= 360 && screenWidth < 768;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isSmallMobile
          ? 16
          : isMobile
              ? 18
              : isTablet
                  ? 20
                  : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with read-only indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      color: const Color(0xFF4CAF50),
                      size: isSmallMobile ? 14 : 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Information Only',
                      style: TextStyle(
                        color: const Color(0xFF4CAF50),
                        fontSize: isSmallMobile ? 10 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.info_outline,
                color: const Color(0xFF4CAF50),
                size: isSmallMobile ? 18 : 20,
              ),
            ],
          ),

          SizedBox(height: isSmallMobile ? 16 : 20),

          // Animated sequential information rows
          _buildAnimatedInfoSection(
            context: context,
            isTablet: isTablet,
            index: 0,
            icon: Icons.check_circle,
            title: 'Entry Recorded',
            description: 'Your visitor entry has been successfully recorded.',
            color: const Color(0xFF4CAF50),
          ),

          SizedBox(height: isSmallMobile ? 12 : 16),

          _buildAnimatedInfoSection(
            context: context,
            isTablet: isTablet,
            index: 1,
            icon: Icons.credit_card,
            title: 'Access Card',
            description:
                'Please ask the receptionist to assign an access card for you.',
            color: const Color(0xFF2196F3),
          ),

          SizedBox(height: isSmallMobile ? 12 : 16),

          _buildAnimatedInfoSection(
            context: context,
            isTablet: isTablet,
            index: 2,
            icon: Icons.elevator,
            title: 'Easy Access',
            description:
                'This will allow easy access to the lift and your designated floor.',
            color: const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }

  // Build animated info section with sequential reveal
  Widget _buildAnimatedInfoSection({
    required BuildContext context,
    required bool isTablet,
    required int index,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 360;
    final isMobile = screenWidth >= 360 && screenWidth < 768;

    // Determine animation state for this row
    final bool isRowActive = _currentRowIndex == index;
    final bool isRowCompleted = _currentRowIndex > index;
    final bool isRowVisible = _currentRowIndex >= index;

    // Opacity based on state
    double opacity = 0.6; // Initial muted state
    if (isRowActive) {
      opacity = 1.0; // Active/highlighted
    } else if (isRowCompleted) {
      opacity = 0.85; // Completed (slightly dimmed)
    }

    return AnimatedOpacity(
      opacity: _isReduceMotionEnabled ? 1.0 : opacity,
      duration: const Duration(milliseconds: 300),
      child: Row(
        children: [
          // Icon section with tick animation
          Container(
            width: isSmallMobile
                ? 36
                : isMobile
                    ? 40
                    : isTablet
                        ? 44
                        : 48,
            height: isSmallMobile
                ? 36
                : isMobile
                    ? 40
                    : isTablet
                        ? 44
                        : 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Original icon
                AnimatedOpacity(
                  opacity: isRowCompleted ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    icon,
                    color: color,
                    size: isSmallMobile
                        ? 18
                        : isMobile
                            ? 20
                            : isTablet
                                ? 22
                                : 24,
                  ),
                ),
                // Tick icon for completed rows
                if (isRowCompleted)
                  AnimatedScale(
                    scale: _isReduceMotionEnabled ? 1.0 : 1.0,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    child: Container(
                      width: isSmallMobile
                          ? 20
                          : isMobile
                              ? 22
                              : isTablet
                                  ? 24
                                  : 26,
                      height: isSmallMobile
                          ? 20
                          : isMobile
                              ? 22
                              : isTablet
                                  ? 24
                                  : 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: isSmallMobile
                            ? 12
                            : isMobile
                                ? 14
                                : isTablet
                                    ? 16
                                    : 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(
              width: isSmallMobile
                  ? 12
                  : isMobile
                      ? 14
                      : isTablet
                          ? 16
                          : 18),

          // Content section with slide-up animation
          Expanded(
            child: AnimatedSlide(
              offset: _isReduceMotionEnabled || isRowVisible
                  ? Offset.zero
                  : const Offset(0, 0.3),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallMobile
                          ? 14
                          : isMobile
                              ? 15
                              : isTablet
                                  ? 16
                                  : 17,
                      color: const Color(0xff212427),
                    ),
                  ),
                  SizedBox(
                      height: isSmallMobile
                          ? 3
                          : isMobile
                              ? 4
                              : isTablet
                                  ? 5
                                  : 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: const Color(0xff57636C),
                      fontSize: isSmallMobile
                          ? 12
                          : isMobile
                              ? 13
                              : isTablet
                                  ? 14
                                  : 15,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    _sequenceController.dispose();
    _okButtonPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Enhanced responsive breakpoints
    final isSmallMobile = screenWidth < 360;
    final isMobile = screenWidth >= 360 && screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    // Responsive dimensions
    final dialogWidth = isSmallMobile
        ? screenWidth * 0.95
        : isMobile
            ? screenWidth * 0.9
            : isTablet
                ? 500.0
                : 600.0;

    final dialogPadding = isSmallMobile
        ? 20.0
        : isMobile
            ? 24.0
            : isTablet
                ? 32.0
                : 40.0;

    final iconSize = isSmallMobile
        ? 60.0
        : isMobile
            ? 70.0
            : isTablet
                ? 80.0
                : 90.0;

    final iconInnerSize = isSmallMobile
        ? 30.0
        : isMobile
            ? 35.0
            : isTablet
                ? 40.0
                : 45.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        children: [
          // Main dialog content with OneGate styling
          Center(
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: dialogWidth,
                    constraints: BoxConstraints(
                      maxWidth: dialogWidth,
                      maxHeight: screenHeight *
                          0.9, // Prevent overflow on small screens
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFFF8F9FA)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(dialogPadding),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Success Icon with OneGate theme - no complex animations
                            Container(
                              width: iconSize,
                              height: iconSize,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF4CAF50), // Green for success
                                    Color(0xFF2E7D32),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4CAF50)
                                        .withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: iconInnerSize,
                              ),
                            ),
                            SizedBox(
                                height: isSmallMobile
                                    ? 16
                                    : isMobile
                                        ? 20
                                        : 24),

                            // Title with responsive typography
                            Text(
                              'Success!',
                              style: TextStyle(
                                fontSize: isSmallMobile
                                    ? 22
                                    : isMobile
                                        ? 24
                                        : isTablet
                                            ? 28
                                            : 32,
                                fontWeight: FontWeight.bold,
                                color: const Color(
                                    0xff212427), // OneGate primary text color
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: isSmallMobile ? 6 : 8),

                            // Subtitle with responsive typography
                            Text(
                              'Your visitor entry has been successfully recorded',
                              style: TextStyle(
                                fontSize: isSmallMobile
                                    ? 14
                                    : isMobile
                                        ? 15
                                        : isTablet
                                            ? 16
                                            : 18,
                                fontWeight: FontWeight.w500,
                                color: const Color(
                                    0xff57636C), // OneGate muted text color
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(
                                height: isSmallMobile
                                    ? 20
                                    : isMobile
                                        ? 24
                                        : isTablet
                                            ? 28
                                            : 32),

                            // Combined success information card (read-only)
                            _buildCombinedSuccessCard(
                              context: context,
                              isTablet: isTablet,
                            ),
                            SizedBox(
                                height: isSmallMobile
                                    ? 20
                                    : isMobile
                                        ? 24
                                        : isTablet
                                            ? 28
                                            : 32),

                            // OK Button with responsive styling, pulse, and hand gesture cue
                            AnimatedBuilder(
                              animation: _okButtonPulseAnimation,
                              builder: (context, child) {
                                final button = Transform.scale(
                                  scale: _isSequenceComplete &&
                                          !_isReduceMotionEnabled
                                      ? _okButtonPulseAnimation.value
                                      : 1.0,
                                  child: Container(
                                    width: double.infinity,
                                    height: isSmallMobile
                                        ? 48
                                        : isMobile
                                            ? 52
                                            : isTablet
                                                ? 56
                                                : 60,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xff212427),
                                          Color(0xff57636C),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xff212427)
                                              .withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _handGestureActive = false;
                                        widget.onOkPressed();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        'OK',
                                        style: TextStyle(
                                          fontSize: isSmallMobile
                                              ? 16
                                              : isMobile
                                                  ? 17
                                                  : isTablet
                                                      ? 18
                                                      : 20,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                );

                                if (_isReduceMotionEnabled) {
                                  return button;
                                }

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    button,
                                    if (_isSequenceComplete &&
                                        _handGestureActive)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 8.0),
                                              child: FadeTransition(
                                                opacity: _handGestureOpacity,
                                                child: SlideTransition(
                                                  position: _handGestureOffset,
                                                  child: Transform.translate(
                                                    offset: const Offset(0, -6),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.touch_app,
                                                          color: Colors.white
                                                              .withOpacity(
                                                                  0.95),
                                                          size: isSmallMobile
                                                              ? 28
                                                              : isMobile
                                                                  ? 30
                                                                  : isTablet
                                                                      ? 32
                                                                      : 34,
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.35),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                          ),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 2),
                                                          child: Text(
                                                            'Tap here',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: isSmallMobile
                                                                  ? 10
                                                                  : isMobile
                                                                      ? 11
                                                                      : isTablet
                                                                          ? 12
                                                                          : 12,
                                                              letterSpacing:
                                                                  0.3,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Confetti overlay - positioned on top of dialog
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: 1.57, // Downward
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xFFF44336), // OneGate red
                  Color(0xFFD32F2F), // OneGate dark red
                  Colors.orange,
                  Colors.yellow,
                  Color(0xFF4CAF50), // Green
                  Colors.blue,
                  Colors.purple,
                  Colors.pink,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
