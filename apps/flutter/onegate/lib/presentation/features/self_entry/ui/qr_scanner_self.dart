import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_screens/widgets/request_2.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:common_widgets/common_widgets.dart';

class QRScannerScreen extends StatefulWidget {
  final String? companyId;

  const QRScannerScreen({Key? key, this.companyId}) : super(key: key);

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  Barcode? result;

  // State variables
  bool _isFlashOn = false;
  bool _isVerifying = false;
  bool _isScanComplete = false;
  bool _scanSuccessful = false;
  bool _isProcessing = false;

  // Camera state
  bool _isCameraPermissionGranted = false;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _successAnimation;

  // Data source for API calls
  final RemoteDataSource remoteDataSource = RemoteDataSource();

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();

    // Setup animation for scanning line
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _successAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  Future<void> _checkCameraPermission() async {
    setState(() {
      _isCameraPermissionGranted =
          true; // For simplicity - actual implementation would check permissions
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _verifyPasscode(String passcode) async {
    setState(() {
      _isVerifying = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString('company_id');
    try {
      // API call with proper error handling
      Map<String, dynamic> response = await remoteDataSource.verifyPasscode(
        companyId: companyId ?? " ",
        passcode: passcode,
      );

      return response['success'] == true;
    } catch (e) {
      // Proper error handling
      debugPrint('Error verifying passcode: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  void _toggleFlash() async {
    if (controller != null) {
      try {
        await controller!.toggleFlash();
        bool? flashStatus = await controller!.getFlashStatus();
        if (mounted) {
          setState(() {
            _isFlashOn = flashStatus ?? false;
          });
        }
      } catch (e) {
        debugPrint('Error toggling flash: $e');
      }
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    controller.scannedDataStream.listen((scanData) async {
      if (!mounted || _isProcessing || scanData.code == null || _isScanComplete)
        return;

      setState(() {
        _isProcessing = true;
        _isVerifying = true;
      });

      // Single API call
      final result = await remoteDataSource.verifyPasscode(
        companyId: widget.companyId ?? "",
        passcode: scanData.code!,
      );

      bool isValid = result['success'] == true && result['data'] != null;

      if (isValid) {
        final visitorData = result['data'][0];

        Visitor visitor = Visitor(
          id: visitorData['id'],
          name: visitorData['name'],
          mobile: visitorData['mobile'],
          visitor_image: null,
        );

        VisitorLog visitorLog = VisitorLog(
          visitor_coming_from: visitorData['coming_from'],
          visitor_purpose_Category_name: visitorData['category'],
        );

        setState(() {
          _isVerifying = false;
          _isProcessing = false;
          _isScanComplete = true;
        });

        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RequestPermissionPage2(
                status: 0,
                visitor: visitor,
                visitorLog: visitorLog,
                request: 'allowByGatekeeper',
                logID: visitorData['id'].toString(),
              ),
            ));
      } else {
        setState(() {
          _isVerifying = false;
          _isProcessing = false;
          _isScanComplete = false;
        });
        _showErrorDialog();
        await controller.resumeCamera();
      }
    });
  }

  Widget _buildPermissionDeniedUI() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Camera permission is required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please enable camera access in your device settings',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _checkCameraPermission,
              child: const Text('Check Permission'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerUI() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // QR Scanner View
        QRView(
          key: qrKey,
          onQRViewCreated: _onQRViewCreated,
          overlay: QrScannerOverlayShape(
            borderColor: _scanSuccessful ? Colors.green : Colors.blue,
            borderRadius: 12,
            borderLength: 32,
            borderWidth: 8,
            cutOutSize: MediaQuery.of(context).size.width * 0.7,
          ),
        ),

        // Animated Scanner Line
        if (!_isScanComplete)
          Positioned(
            left: MediaQuery.of(context).size.width * 0.15,
            width: MediaQuery.of(context).size.width * 0.7,
            child: AnimatedBuilder(
              animation: _scanLineAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                      0,
                      _scanLineAnimation.value *
                              (MediaQuery.of(context).size.width * 0.7) -
                          (MediaQuery.of(context).size.width * 0.35)),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withOpacity(0.1),
                          Colors.blue.withOpacity(0.8),
                          Colors.blue.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Scan Success Animation
        if (_isScanComplete && _scanSuccessful)
          AnimatedBuilder(
            animation: _successAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _successAnimation.value,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: MediaQuery.of(context).size.width * 0.7,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green,
                      width: 8 * (1 - _successAnimation.value / 2),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 64 * _successAnimation.value,
                    ),
                  ),
                ),
              );
            },
          ),

        // Scanning Text
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isVerifying ? Colors.amber : Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isVerifying ? 'Verifying QR Code...' : 'Scan QR Code',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Helper Text
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Align QR code within the frame',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Verification Loader
        if (_isVerifying)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verifying',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Scan the QR code',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
            ),
            onPressed: _toggleFlash,
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.help_outline, color: Colors.white),
            ),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      body: _isCameraPermissionGranted
          ? _buildScannerUI()
          : _buildPermissionDeniedUI(),
    );
  }

  void _showSuccessDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: Colors.green,
                child: Icon(Icons.check, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'Visitor Allowed By Gatekeeper',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              CustomLargeBtn(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(code);
                  },
                  text: 'Done')
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: Colors.red,
                child: Icon(Icons.close, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verification Failed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The QR code is invalid or expired',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    result = null;
                  });
                },
                child: const Text(
                  'Try Again',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How to scan QR codes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _helpItem(
              icon: Icons.center_focus_strong,
              title: 'Position the QR code',
              description: 'Center the QR code within the frame',
            ),
            const SizedBox(height: 16),
            _helpItem(
              icon: Icons.light_mode,
              title: 'Ensure good lighting',
              description: 'Make sure the QR code is well-lit',
            ),
            const SizedBox(height: 16),
            _helpItem(
              icon: Icons.flash_on,
              title: 'Use flash if needed',
              description: 'Toggle flash in dark environments',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Got it',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpItem(
      {required IconData icon,
      required String title,
      required String description}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blue),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
