import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_entry/ui/visitor_in_entry.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_screens/widgets/request_2.dart';
import 'package:flutter_onegate/presentation/features/self_entry/self_home_view.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/utils/route_tracker.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../../data/datasources/gate_storage.dart';

class QRScannerScreen extends StatefulWidget {
  final String? companyId;
  final int? status;
  final bool self_checkin;
  final bool?
      isGatekeeperQRPasscodeEntry; // New parameter to distinguish Gatekeeper QR/Passcode entry

  const QRScannerScreen(
      {Key? key,
      this.companyId,
      this.status,
      this.self_checkin = false,
      this.isGatekeeperQRPasscodeEntry})
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
  bool _isFrontCamera = false;

  // Camera state
  bool _isCameraPermissionGranted = false;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _scanCornerAnimation;

  // Audio players for QR scan sounds
  final AudioPlayer _successAudioPlayer = AudioPlayer();
  final AudioPlayer _failureAudioPlayer = AudioPlayer();

  // Data source for API calls
  final RemoteDataSource remoteDataSource = RemoteDataSource();

  // Track that user is in express entry flow
  Future<void> _trackExpressEntryRoute() async {
    if (widget.self_checkin) {
      await RouteTracker.saveCurrentRoute(
        'QRScannerScreen',
        isExpressEntry: true,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
    _trackExpressEntryRoute();

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
    _successAudioPlayer.dispose();
    _failureAudioPlayer.dispose();
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

  Future<void> _toggleCamera() async {
    try {
      if (controller == null) return;
      await controller!.flipCamera();
      // Update local state (best-effort)
      try {
        final info = await controller!.getCameraInfo();
        if (mounted) {
          setState(() {
            _isFrontCamera = info.toString().toLowerCase().contains('front');
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isFrontCamera = !_isFrontCamera;
          });
        }
      }
    } catch (e) {
      debugPrint('Error flipping camera: $e');
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    // For express entry (self_checkin), always use front camera
    if (widget.self_checkin) {
      // Switch to front camera for express entry
      controller.flipCamera().then((_) {
        log("📱 Switched to front camera for express entry");
        // Update the state to reflect that we're now using front camera
        if (mounted) {
          setState(() {
            _isFrontCamera = true;
          });
        }
      }).catchError((error) {
        log("⚠️ Could not switch to front camera: $error");
      });
    }

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
        bool? isStaff;

        dynamic scannedJson;
        try {
          scannedJson = jsonDecode(code);
          log("✅ Parsed JSON from QR: $scannedJson");

          mobile = scannedJson['mobile']?.toString();
          id = scannedJson['id'];
          name = scannedJson['name'];
          isStaff = scannedJson['is_staff'];

          passcode = scannedJson['passcode']?.toString();
        } catch (jsonError) {
          log("⚠️ QR code isn't valid JSON, treating as passcode: $code");
          passcode = code;
        }

        final result = await remoteDataSource.verifyPasscode(
          companyId: widget.companyId ?? "",
          passcode: passcode,
        );
        if (isStaff == true) {
          // Play success sound for staff
          _playSuccessSound();

          Visitor visitor = Visitor(
            visitor_image: result['data'][0]['visitor_image'],
            name: result['data'][0]['name'],
            mobile: result['data'][0]['mobile'],
            // visitor_image: visitorData['qr_code'],
          );
          VisitorLog visitorLog = VisitorLog(
            visitor: visitor,
            visitor_coming_from: result['data'][0]['coming_from'],
            visitor_purpose_Category_name: "Staff",
            visitor_purpose_category_id: 1,
            visitor_count: 1,
          );

          Navigator.of(context).pop();

          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RequestPermissionPage2(
                status: widget.status,
                visitor: visitor,
                visitorLog: visitorLog,
                request: 'allowByGatekeeper',
                selfcheckinFlow: widget.self_checkin,
                isGatekeeperQRPasscodeEntry: widget.isGatekeeperQRPasscodeEntry,
              ),
            ),
          );
        }
        final bool isValid = result['success'] == true &&
            result['data'] != null &&
            (result['data'] as List).isNotEmpty;

        if (isValid) {
          // Play success sound
          _playSuccessSound();

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
            initiated_from: "qr_code_scan", // Mark as QR code scan entry
          );

          setState(() {
            _isVerifying = false;
            _isProcessing = false;
            _isScanComplete = true;
            _scanSuccessful = true;
          });

          // Short delay to show success animation
          await Future.delayed(const Duration(milliseconds: 800));

          // Always redirect to purpose entry page with autopopulated guest data
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VisitorsInEntry(
                selfcheckinFlow: widget.self_checkin,
                comingfrom: visitorData['coming_from'],
                searchedVisitor: visitor,
                selectedValue:
                    PurposeCategory1(categoryId: 1, categoryName: "Guest"),
                mobile: mobile ?? visitor.mobile!,
                guestname: name ?? visitor.name ?? "",
                isFromQRScan: true, // Flag to indicate this is from QR scan
                isGatekeeperQRPasscodeEntry:
                    widget.isGatekeeperQRPasscodeEntry ??
                        false, // Pass the gatekeeper QR flag
                visitorLog: visitorLog,
              ),
            ),
          );
        } else {
          throw Exception("Invalid verification data received.");
        }
      } catch (e) {
        log("❌ Error processing QR scan: $e");
        // Play failure sound
        _playFailureSound();
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
      final comingFrom = await GateStorage().getComingFrom();
      log("_updateVisitorEntry : $comingFrom");
      final data = {
        "visitor_image": imageUrl,
        "coming_from": comingFrom,
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
            Text(
              AppLocalizations.of(context).cameraPermissionRequired,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                AppLocalizations.of(context).needCameraAccessForQR,
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
              child: Text(AppLocalizations.of(context).grantAccess,
                  style: const TextStyle(fontSize: 16)),
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
              // Flip camera button
              _buildRoundButton(
                onPressed: _toggleCamera,
                iconData: Icons.cameraswitch,
                label: _isFrontCamera ? 'Front' : 'Back',
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

        // Enhanced Loading Overlay
        if (_isVerifying)
          Container(
            color: const Color(0xFF212427)
                .withOpacity(0.9), // OneGate primary text color
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.grey.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF212427)
                          .withOpacity(0.3), // OneGate primary text color
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      blurRadius: 20,
                      spreadRadius: -5,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Enhanced QR Code Icon with Animation
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF4CAF50), // Green primary
                            Color(0xFF2E7D32), // Green accent color
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50)
                                .withOpacity(0.4), // Green primary
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Animated QR Code Icon
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 1500),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: 0.8 + (0.2 * value),
                                child: Opacity(
                                  opacity: 0.7 + (0.3 * value),
                                  child: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              );
                            },
                          ),
                          // Rotating Progress Ring
                          SizedBox(
                            width: 70,
                            height: 70,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.8),
                              ),
                              strokeWidth: 3,
                              backgroundColor: Colors.white.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Enhanced Title with Typography
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF4CAF50), // Green primary
                          Color(0xFF2E7D32), // Green accent color
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'Verifying QR Code',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Enhanced Subtitle with Better Styling
                    Container(
                      width: 240,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA), // Light background
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE9ECEF), // Light border
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'Please wait while we process the information',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              Color(0xFF57636C), // OneGate secondary text color
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Animated Progress Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 600 + (index * 200)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withOpacity(
                                  0.3 + (0.7 * value),
                                ), // Green primary
                                shape: BoxShape.circle,
                              ),
                            );
                          },
                        );
                      }),
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
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xffF44336).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Color(0xffF44336),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                "QR Code Verification Failed",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212427),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Message
              const Text(
                "The QR code could not be verified. It may be invalid or expired. Please try again or contact support.",
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // OK Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    _isDialogOpen = false;

                    // Navigate back to express entry dashboard
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SelfHomeView(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffF44336),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Play success sound for QR verification
  Future<void> _playSuccessSound() async {
    try {
      // Ensure no overlapping sounds
      await _failureAudioPlayer.stop();
      await _successAudioPlayer.stop();
      await _successAudioPlayer.setReleaseMode(ReleaseMode.stop);
      await _successAudioPlayer.setVolume(1.0);
      await _successAudioPlayer.play(AssetSource('media/audio/success.mp3'));
      log("🔊 Success sound played");
    } catch (e) {
      log("❌ Error playing success sound: $e");
    }
  }

  /// Play failure sound for invalid QR
  Future<void> _playFailureSound() async {
    try {
      // Ensure no overlapping sounds
      await _successAudioPlayer.stop();
      await _failureAudioPlayer.stop();
      await _failureAudioPlayer.setReleaseMode(ReleaseMode.stop);
      await _failureAudioPlayer.setVolume(1.0);
      await _failureAudioPlayer.play(AssetSource('media/audio/alarm.mp3'));
      log("🔊 Failure sound played");
    } catch (e) {
      log("❌ Error playing failure sound: $e");
    }
  }

  /// Enhanced error toast with gatekeeper app design
  void _showEnhancedErrorToast({
    required String title,
    required String message,
    IconData? icon,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon ?? Icons.error_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
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
        duration: const Duration(seconds: 4),
        elevation: 8,
      ),
    );

    // Add haptic feedback for error
    HapticFeedback.heavyImpact();
  }

  /// Legacy error dialog method (kept for reference but not used)
  void _showLegacyErrorDialog() {
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Enhanced drag handle
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),

            // Enhanced header with gradient background
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xffFF9800).withOpacity(0.08),
                    const Color(0xffFF5722).withOpacity(0.03),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  // Compact icon section
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xffFF9800).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffFF9800).withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xffFF9800),
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Simple label section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'How to Scan QR Codes',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff212427),
                                fontSize: isTablet ? 22 : 20,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Follow these simple steps for successful QR code scanning',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xff57636C),
                                    fontSize: isTablet ? 15 : 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Enhanced content area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      // Help items with enhanced styling
                      _buildEnhancedHelpItem(
                        context: context,
                        isTablet: isTablet,
                        icon: Icons.center_focus_strong,
                        title: 'Position the QR code',
                        description:
                            'Center the QR code within the scanning frame for optimal recognition.',
                        color: const Color(0xff4CAF50),
                      ),
                      SizedBox(height: isTablet ? 20 : 16),
                      _buildEnhancedHelpItem(
                        context: context,
                        isTablet: isTablet,
                        icon: Icons.light_mode,
                        title: 'Ensure good lighting',
                        description:
                            'Make sure the QR code is well-lit and clearly visible for better scanning.',
                        color: const Color(0xff2196F3),
                      ),
                      SizedBox(height: isTablet ? 20 : 16),
                      _buildEnhancedHelpItem(
                        context: context,
                        isTablet: isTablet,
                        icon: Icons.flash_on,
                        title: 'Use flash if needed',
                        description:
                            'Toggle the flash in dark environments for improved scanning results.',
                        color: const Color(0xffFF9800),
                      ),
                      SizedBox(height: isTablet ? 20 : 16),
                      _buildEnhancedHelpItem(
                        context: context,
                        isTablet: isTablet,
                        icon: Icons.front_hand,
                        title: 'Hold steady',
                        description:
                            'Keep your phone steady while scanning for the best possible results.',
                        color: const Color(0xff9C27B0),
                      ),
                      SizedBox(height: isTablet ? 32 : 24),

                      // Enhanced Got it button
                      Container(
                        width: double.infinity,
                        height: isTablet ? 52 : 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFF212427), // Black
                              Color(0xFF57636C), // Grey
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF212427).withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              alignment: Alignment.center,
                              child: Text(
                                'Got it',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 18 : 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Add extra padding at bottom
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedHelpItem({
    required BuildContext context,
    required bool isTablet,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Enhanced icon section
          Container(
            width: isTablet ? 56 : 48,
            height: isTablet ? 56 : 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: isTablet ? 28 : 24,
            ),
          ),
          SizedBox(width: isTablet ? 20 : 16),
          // Enhanced content section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 18 : 16,
                    color: const Color(0xff212427),
                  ),
                ),
                SizedBox(height: isTablet ? 8 : 6),
                Text(
                  description,
                  style: TextStyle(
                    color: const Color(0xff57636C),
                    fontSize: isTablet ? 15 : 14,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
