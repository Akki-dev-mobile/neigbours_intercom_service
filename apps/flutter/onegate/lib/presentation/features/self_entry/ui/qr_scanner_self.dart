import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/units_selection/ui/unit_selection_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_screens/widgets/request_2.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QRScannerScreen extends StatefulWidget {
  final String? companyId;
  final int? status;
  final bool self_checkin;

  const QRScannerScreen(
      {Key? key, this.companyId, this.status, this.self_checkin = false})
      : super(key: key);

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
  late Animation<double> _scanCornerAnimation;

  // Data source for API calls
  final RemoteDataSource remoteDataSource = RemoteDataSource();

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();

    // Setup animation for scanning line
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _scanCornerAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _checkCameraPermission() async {
    setState(() {
      _isCameraPermissionGranted =
          true; // Actual implementation would check permissions
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

      try {
        final code = scanData.code!.trim();
        log("🔍 Raw QR Code data: $code");

        String? mobile;
        int? id;
        String? name;
        String? passcode;

        dynamic scannedJson;
        try {
          scannedJson = jsonDecode(code);
          log("✅ Parsed JSON from QR: $scannedJson");

          mobile = scannedJson['mobile']?.toString();
          id = scannedJson['id'];
          name = scannedJson['name'];
          passcode = scannedJson['passcode']?.toString();
        } catch (jsonError) {
          log("⚠️ QR code isn't valid JSON, treating as passcode: $code");
          passcode = code;
        }

        final result = await remoteDataSource.verifyPasscode(
          companyId: widget.companyId ?? "",
          mobile: mobile,
          id: id,
          passcode: passcode,
        );

        final bool isValid = result['success'] == true &&
            result['data'] != null &&
            (result['data'] as List).isNotEmpty;

        if (isValid) {
          final visitorData = result['data'][0];

          Visitor visitor = Visitor(
            id: visitorData['visitor_id'],
            name: visitorData['name'],
            mobile: visitorData['mobile'],
            // visitor_image: visitorData['qr_code'],
          );

          VisitorLog visitorLog = VisitorLog(
            visitor: visitor,
            visitor_coming_from: visitorData['coming_from'],
            visitor_purpose_Category_name: visitorData['category'],
            visitor_purpose_category_id: 1,
            visitor_count: 1,
            company_id: visitorData['company_id'],
          );

          setState(() {
            _isVerifying = false;
            _isProcessing = false;
            _isScanComplete = true;
            _scanSuccessful = true;
          });

          // Short delay to show success animation
          await Future.delayed(const Duration(milliseconds: 800));

          if (visitorData['passcode'] == null ||
              visitorData['passcode'].toString().isEmpty) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => UnitSelectionView(
                  null,
                  purposeCategory:
                      PurposeCategory1(categoryId: 1, categoryName: "Guest"),
                  guestname: name!,
                  mobileNumber: mobile ?? visitor.mobile!,
                  visitor: visitor,
                  selfcheckinFlow: widget.self_checkin,
                ),
              ),
            );
          } else {
            await _requestCameraPermissionAndCapture(
                mobile ?? "", visitorData['visitor_id'].toString());

            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text("Preparing visitor access..."),
                      ],
                    ),
                  ),
                );
              },
            );

// Dismiss the dialog
            Navigator.of(context).pop();

            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => RequestPermissionPage2(
                  status: widget.status,
                  visitor: visitor,
                  visitorLog: visitorLog,
                  request: 'allowByGatekeeper',
                  logID: visitorData['id'].toString(),
                ),
              ),
            );
          }
        } else {
          throw Exception("Invalid verification data received.");
        }
      } catch (e) {
        log("❌ Error processing QR scan: $e");
        _showErrorDialog();
        await controller.resumeCamera();
        setState(() {
          _isVerifying = false;
          _isProcessing = false;
          _isScanComplete = false;
        });
      }
    });
  }

  File? _imageFile;

  Future<void> _requestCameraPermissionAndCapture(
      String mobileNumber, String id) async {
    PermissionStatus status = await Permission.camera.status;

    if (status.isDenied || status.isRestricted) {
      // Request permission
      status = await Permission.camera.request();

      if (!status.isGranted) {
        print("❌ Camera permission denied!");
        myFluttertoast(
          msg: "Camera permission required to capture an image.",
          backgroundColor: Colors.orange,
        );
        return;
      }
    }

    // ✅ Capture Image if Permission is Granted
    await _captureImageFromCamera(mobileNumber, id);
  }

  /// ✅ Captures Image from Camera & Uploads it
  Future<void> _captureImageFromCamera(String mobileNumber, String id) async {
    final picker = ImagePicker();
    XFile? image;

    try {
      // 📷 Capture image from camera
      image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null) {
        print("❌ No image captured");
        return;
      }

      setState(() {
        _imageFile = File(image!.path); // ✅ Assign image to _imageFile
      });

      print("📷 Image captured: ${_imageFile!.path}");

      // ✅ Upload the captured image
      await _uploadCapturedImage(mobileNumber, id);
    } catch (e) {
      log('❌ Error capturing image from camera: $e');
    }
  }

  Future<void> _uploadCapturedImage(String mobileNumber, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id');

      if (_imageFile == null) {
        print("❌ No image to upload.");
        return;
      }

      // ✅ Compress Image
      File? compressedImage = await _compressImage(_imageFile!);
      if (compressedImage == null) {
        print("❌ Compression failed, using original file.");
        compressedImage = _imageFile!;
      }

      print("📷 Final Image Size: ${compressedImage.lengthSync()} bytes");

      // ✅ Upload Image to Server
      final response = await remoteDataSource.uploadFile(
        compressedImage,
        mobileNumber,
        int.parse(companyId ?? "0"),
      );

      print("✅ Image uploaded successfully: $response");

      if (response != null) {
        await prefs.setString('uploaded_image_url', response);
        print("🔄 Image URL saved: $response");

        // ✅ Update Visitor Entry with Uploaded Image URL
        await _updateVisitorEntry(mobileNumber, response, id);
      }
    } catch (e) {
      print("❌ Error uploading image: $e");
    }
  }

  /// ✅ Compress Image Before Uploading
  Future<File?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
          dir.path, "compressed_${DateTime.now().millisecondsSinceEpoch}.jpg");

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, // Adjust quality (higher = better, but larger file)
        format: CompressFormat.jpeg,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      print("❌ Error compressing image: $e");
      return null;
    }
  }

  /// ✅ PATCH Request to Update Visitor Entry
  Future<void> _updateVisitorEntry(
      String mobileNumber, String imageUrl, String id) async {
    try {
      int id1 = int.parse(id);
      final dio = Dio();
      final String apiUrl = "${ApiUrls.gateBaseUrl}/visitor/entry/$id1";

      final data = {
        "visitor_image": imageUrl,
      };

      final response = await dio.patch(
        apiUrl,
        options: Options(headers: {"Content-Type": "application/json"}),
        data: data,
      );

      if (response.statusCode == 200) {
        print("✅ Visitor entry updated successfully: ${response.data}");
      } else {
        print("❌ Failed to update visitor entry: ${response.statusMessage}");
      }
    } catch (e) {
      print("❌ Error updating visitor entry: $e");
    }

    // // ✅ Navigate to Dashboard after successful update
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => GateDashboardView(),
    //   ),
    // );
  }

  Widget _buildPermissionDeniedUI() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            const Text(
              'Camera Permission Required',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'We need camera access to scan QR codes',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
              onPressed: _checkCameraPermission,
              child: const Text('Grant Access', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerUI() {
    final scannerSize = MediaQuery.of(context).size.width * 0.75;

    return Stack(
      alignment: Alignment.center,
      children: [
        // QR Scanner View
        QRView(
          key: qrKey,
          onQRViewCreated: _onQRViewCreated,
          overlay: QrScannerOverlayShape(
            borderColor: Colors.transparent,
            borderRadius: 16,
            borderLength: 32,
            borderWidth: 0,
            cutOutSize: scannerSize,
          ),
        ),

        // Scanner Frame (animated corners)
        SizedBox(
          width: scannerSize,
          height: scannerSize,
          child: AnimatedBuilder(
            animation: _scanCornerAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: ScannerFramePainter(
                    _scanCornerAnimation.value,
                    _isScanComplete
                        ? (_scanSuccessful ? Colors.green : Colors.red)
                        : Colors.white),
              );
            },
          ),
        ),

        // Animated Scanner Line
        // Inside the _buildScannerUI() method, replace the "Animated Scanner Line" section with this:

// Animated Scanner Effect (replace the simple line)
// Animated Scanner Line - Single Line
        if (!_isScanComplete && !_isVerifying)
          Positioned(
            width: scannerSize,
            height: scannerSize,
            child: AnimatedBuilder(
              animation: _scanLineAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: SingleLineScannerPainter(
                    _scanLineAnimation.value,
                    Theme.of(context).primaryColor,
                  ),
                  size: Size(scannerSize, scannerSize),
                );
              },
            ),
          ),

// Add this new CustomPainter class at the bottom of the file, after ScannerFramePainter:

        // Scan Success/Error Animation
        if (_isScanComplete)
          AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: scannerSize,
              height: scannerSize,
              decoration: BoxDecoration(
                color: _scanSuccessful
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(
                  _scanSuccessful ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 80,
                ),
              ),
            ),
          ),

        // Status Indicator
        Positioned(
          top: MediaQuery.of(context).size.height * 0.13,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(30),
              border:
                  Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _isVerifying
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor),
                        ),
                      )
                    : Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                const SizedBox(width: 12),
                Text(
                  _isVerifying ? 'Verifying...' : 'Scan QR Code',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Instruction Card
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.12,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Position the QR code inside the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Scanning will happen automatically',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Actions
        Positioned(
          bottom: 30,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flash button
              _buildRoundButton(
                onPressed: _toggleFlash,
                iconData: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                label: _isFlashOn ? 'Flash On' : 'Flash Off',
              ),
              const SizedBox(width: 24),
              // Help button
              _buildRoundButton(
                onPressed: _showHelpDialog,
                iconData: Icons.help_outline,
                label: 'Help',
              ),
            ],
          ),
        ),

        // Loading Overlay
        if (_isVerifying)
          Container(
            color: Colors.black.withOpacity(0.6),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor),
                        strokeWidth: 4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Verifying QR Code...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 200,
                      child: Text(
                        'Please wait while we process the information',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
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

  Widget _buildRoundButton({
    required VoidCallback onPressed,
    required IconData iconData,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: IconButton(
            icon: Icon(iconData, color: Colors.white, size: 24),
            onPressed: onPressed,
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
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
          'Scan QR Code',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(20),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Visitor Allowed',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The visitor has been successfully verified',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              CustomLargeBtn(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(code);
                },
                text: 'Done',
              )
            ],
          ),
        ),
      ),
    );
  }

  bool _isDialogOpen = false; // Track if dialog is already open

  void _showErrorDialog() {
    if (_isDialogOpen) return; // Prevent duplicate pop-ups
    _isDialogOpen = true;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(20),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Verification Failed',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The QR code could not be verified. It may be invalid or expired.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    result = null;
                    _isDialogOpen = false; // Reset the flag when closed
                  });
                },
                child: const Text(
                  'Try Again',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _isDialogOpen = false; // Reset flag when dialog is dismissed
    });
  }

  void _showHelpDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'How to Scan QR Codes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _helpItem(
              icon: Icons.center_focus_strong,
              title: 'Position the QR code',
              description: 'Center the QR code within the scanning frame.',
            ),
            const SizedBox(height: 20),
            _helpItem(
              icon: Icons.light_mode,
              title: 'Ensure good lighting',
              description:
                  'Make sure the QR code is well-lit and clearly visible.',
            ),
            const SizedBox(height: 20),
            _helpItem(
              icon: Icons.flash_on,
              title: 'Use flash if needed',
              description:
                  'Toggle the flash in dark environments for better scanning.',
            ),
            const SizedBox(height: 20),
            _helpItem(
              icon: Icons.front_hand,
              title: 'Hold steady',
              description:
                  'Keep your phone steady while scanning for best results.',
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                minimumSize: const Size(double.infinity, 56),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Got it',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _helpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.black, size: 24),
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
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Custom Scanner Frame Painter
class ScannerFramePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  ScannerFramePainter(this.animationValue, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Calculate corner size based on animation value
    final cornerSize = 30.0 * animationValue;

    // Draw corners
    // Top-left
    canvas.drawLine(const Offset(0, 0), Offset(cornerSize, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, cornerSize), paint);

    // Top-right
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width - cornerSize, 0), paint);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, cornerSize), paint);

    // Bottom-left
    canvas.drawLine(
        Offset(0, size.height), Offset(cornerSize, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(0, size.height - cornerSize), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - cornerSize, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - cornerSize), paint);
  }

  @override
  bool shouldRepaint(ScannerFramePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}

// Add this new CustomPainter class at the bottom of the file, after ScannerFramePainter:

class ScannerEffectPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  ScannerEffectPainter(this.animationValue, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = RadialGradient(
      center: Alignment(0, 2 * animationValue - 1),
      radius: 0.8,
      colors: [
        color.withOpacity(0.0),
        color.withOpacity(0.2),
        color.withOpacity(0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

// Draw a subtle scanning effect
    canvas.drawRect(rect, paint);

// Draw scan lines
    final linePaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

// Calculate position based on animation
    final y = animationValue * size.height;

// Draw multiple lines with spacing
    const lineSpacing = 12.0;
    const numberOfLines = 5;

    for (int i = 0; i < numberOfLines; i++) {
      final lineY = (y + (i * lineSpacing)) % size.height;
      canvas.drawLine(
        Offset(20, lineY),
        Offset(size.width - 20, lineY),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(ScannerEffectPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}
// Inside the _buildScannerUI() method, replace the "Animated Scanner Line" section with this:

// Add this new CustomPainter class at the bottom of the file, after ScannerFramePainter:

class SingleLineScannerPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  SingleLineScannerPainter(this.animationValue, this.color);

  @override
  void paint(Canvas canvas, Size size) {
// Calculate position based on animation
    final y = animationValue * size.height;

// Draw a single line with glow effect
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

// Create glow effect with shadow
    canvas.drawLine(
      Offset(10, y),
      Offset(size.width - 10, y),
      Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0),
    );

// Draw main line
    canvas.drawLine(
      Offset(10, y),
      Offset(size.width - 10, y),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(SingleLineScannerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}
