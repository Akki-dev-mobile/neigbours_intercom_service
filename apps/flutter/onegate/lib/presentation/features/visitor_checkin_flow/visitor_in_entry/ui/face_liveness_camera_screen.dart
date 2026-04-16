import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FaceLivenessCameraScreen extends StatefulWidget {
  final CameraController cameraController;
  final bool isExpressEntry;

  const FaceLivenessCameraScreen({
    Key? key,
    required this.cameraController,
    this.isExpressEntry = false,
  }) : super(key: key);

  @override
  State<FaceLivenessCameraScreen> createState() =>
      _FaceLivenessCameraScreenState();
}

class _FaceLivenessCameraScreenState extends State<FaceLivenessCameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late CameraController _cameraController;
  late CameraDescription _currentCamera;
  XFile? _capturedImage;
  bool _isCapturing = false;
  bool _isProcessing = false;

  // Face detection
  late FaceDetector _faceDetector;
  List<Face> _faces = [];
  bool _isFaceDetected = false;
  bool _isFaceAligned = false;
  bool _isFaceInFrame = false;
  bool _isGoodLighting = false;
  bool _isAutoCaptureReady = false;
  Timer? _faceDetectionTimer;
  Timer? _autoCaptureTimer;
  Timer? _alignmentStabilityTimer;

  // Stability tracking for smoother auto capture
  DateTime? _alignmentStartTime;
  bool _isAlignmentStable = false;

  // Get alignment duration for progress feedback
  int get _alignmentDurationMs {
    if (_alignmentStartTime == null) return 0;
    return DateTime.now().difference(_alignmentStartTime!).inMilliseconds;
  }

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _successAnimation;

  // TTS (voice prompts)
  late FlutterTts _tts;
  Timer? _ttsDebounce;
  String? _lastInstructionSpoken;

  // Face alignment thresholds
  static const double _minFaceSize =
      0.15; // Minimum face size relative to frame
  static const double _maxFaceSize = 0.8; // Maximum face size relative to frame
  static const double _maxHeadRotationX = 15.0; // Max head rotation up/down
  static const double _maxHeadRotationY = 15.0; // Max head rotation left/right
  static const double _maxHeadRotationZ = 10.0; // Max head tilt
  static const double _minEyeOpenProbability = 0.3; // Min eye open probability

  // Auto-capture settings - optimized for smoother flow
  static const int _autoCaptureDelayMs =
      1500; // 1.5 seconds of good alignment (reduced for faster capture)
  static const int _faceDetectionIntervalMs =
      150; // Check every 150ms (optimized for performance)
  static const int _alignmentStabilityMs =
      800; // Require 800ms of stable alignment before starting timer

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentCamera = widget.cameraController.description;
    _cameraController = widget.cameraController;
    _initializeFaceDetector();
    _initializeAnimations();
    _initializeTts();
    _lockCameraToPortrait();

    if (widget.isExpressEntry) {
      _startFaceDetection();
      _maybeSpeakInstruction();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _faceDetectionTimer?.cancel();
    _autoCaptureTimer?.cancel();
    _alignmentStabilityTimer?.cancel();
    _faceDetector.close();
    _pulseController.dispose();
    _scanController.dispose();
    _successController.dispose();
    _ttsDebounce?.cancel();
    // ignore: unawaited_futures
    _tts.stop();
    super.dispose();
  }

  void _initializeFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.1,
      ),
    );
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scanController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _pulseController.repeat(reverse: true);
    _scanController.repeat();
  }

  void _initializeTts() {
    _tts = FlutterTts();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
  }

  void _maybeSpeakInstruction() {
    if (!widget.isExpressEntry) return;
    final instruction = _getInstructionTextForTts();
    if (instruction == null) return;
    if (instruction == _lastInstructionSpoken) return;
    _lastInstructionSpoken = instruction;
    _ttsDebounce?.cancel();
    _ttsDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        await _tts.stop();
        await _tts.speak(instruction);
        print('📢 TTS: $instruction');
      } catch (_) {}
    });
  }

  Future<void> _lockCameraToPortrait() async {
    if (_cameraController.value.isInitialized) {
      await _cameraController
          .lockCaptureOrientation(DeviceOrientation.portraitUp);
    }
  }

  void _startFaceDetection() {
    _faceDetectionTimer = Timer.periodic(
      const Duration(milliseconds: _faceDetectionIntervalMs),
      (_) => _detectFaces(),
    );
  }

  Future<void> _detectFaces() async {
    if (_isProcessing || !_cameraController.value.isInitialized || _isCapturing)
      return;

    _isProcessing = true;
    try {
      // Take a picture for face detection
      final XFile image = await _cameraController.takePicture();
      final File file = File(image.path);
      final InputImage inputImage = InputImage.fromFile(file);

      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          _faces = faces;
          _isFaceDetected = faces.isNotEmpty;

          if (_isFaceDetected) {
            _evaluateFaceAlignment(faces.first);
          } else {
            _isFaceAligned = false;
            _isFaceInFrame = false;
            _isGoodLighting = false;
            _isAutoCaptureReady = false;
            _isAlignmentStable = false;
            _alignmentStartTime = null;
            _autoCaptureTimer?.cancel();
            _alignmentStabilityTimer?.cancel();
          }
        });
        _maybeSpeakInstruction();
      }

      // Clean up temporary file
      await file.delete();
    } catch (e) {
      print('Face detection error: $e');
    }
    _isProcessing = false;
  }

  void _evaluateFaceAlignment(Face face) {
    // Check face size
    final faceSize = _calculateFaceSize(face);
    _isFaceInFrame = faceSize >= _minFaceSize && faceSize <= _maxFaceSize;

    // Check head rotation
    final headRotationX = face.headEulerAngleX?.abs() ?? 0;
    final headRotationY = face.headEulerAngleY?.abs() ?? 0;
    final headRotationZ = face.headEulerAngleZ?.abs() ?? 0;

    final isHeadStraight = headRotationX <= _maxHeadRotationX &&
        headRotationY <= _maxHeadRotationY &&
        headRotationZ <= _maxHeadRotationZ;

    // Check eye openness
    final leftEyeOpen = face.leftEyeOpenProbability ?? 0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 0;
    final eyesOpen = leftEyeOpen >= _minEyeOpenProbability &&
        rightEyeOpen >= _minEyeOpenProbability;

    // Check if face is looking at camera (both eyes visible)
    final isLookingAtCamera = eyesOpen;

    // Check lighting (basic check - can be enhanced)
    _isGoodLighting = true; // For now, assume good lighting

    // Overall alignment check
    final wasAligned = _isFaceAligned;
    _isFaceAligned = _isFaceInFrame &&
        isHeadStraight &&
        isLookingAtCamera &&
        _isGoodLighting;

    // Enhanced auto-capture logic with stability tracking
    if (_isFaceAligned && !wasAligned) {
      // Face just became aligned - start stability timer
      _alignmentStartTime = DateTime.now();
      _alignmentStabilityTimer?.cancel();
      _alignmentStabilityTimer = Timer(
        const Duration(milliseconds: _alignmentStabilityMs),
        () {
          if (_isFaceAligned && !_isAutoCaptureReady) {
            _isAlignmentStable = true;
            _isAutoCaptureReady = true;
            _startAutoCaptureTimer();
          }
        },
      );
    } else if (!_isFaceAligned && wasAligned) {
      // Face became misaligned - reset everything
      _alignmentStartTime = null;
      _isAlignmentStable = false;
      _isAutoCaptureReady = false;
      _alignmentStabilityTimer?.cancel();
      _autoCaptureTimer?.cancel();
    }
  }

  double _calculateFaceSize(Face face) {
    final boundingBox = face.boundingBox;
    final frameSize = _cameraController.value.previewSize!;

    final faceWidth = boundingBox.width / frameSize.width;
    final faceHeight = boundingBox.height / frameSize.height;

    // Use the larger dimension to determine face size
    return math.max(faceWidth, faceHeight);
  }

  void _startAutoCaptureTimer() {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = Timer(
      const Duration(milliseconds: _autoCaptureDelayMs),
      () {
        if (_isFaceAligned &&
            _isAutoCaptureReady &&
            _isAlignmentStable &&
            !_isCapturing) {
          print('📷 Auto-capture triggered - face is stable and aligned');
          _lastInstructionSpoken = null;
          _tts.stop();
          _tts.speak('Hold still. Capturing.');
          _captureImage();
        } else {
          print('📷 Auto-capture cancelled - face not ready');
        }
      },
    );
  }

  Future<void> _captureImage() async {
    if (_isCapturing) return;

    print('📷 Starting image capture process');
    setState(() {
      _isCapturing = true;
    });

    try {
      // Stop all timers and detection
      _faceDetectionTimer?.cancel();
      _autoCaptureTimer?.cancel();
      _alignmentStabilityTimer?.cancel();

      // Play success animation
      _successController.forward();

      // Reduced wait time for smoother experience
      await Future.delayed(const Duration(milliseconds: 600));

      // Capture the image
      print('📷 Taking picture...');
      final XFile image = await _cameraController.takePicture();

      if (mounted) {
        print('📷 Image captured successfully');
        // For Express Entry, automatically proceed to next step
        if (widget.isExpressEntry) {
          Navigator.of(context).pop(image);
        } else {
          // For regular flow, show captured image
          setState(() {
            _capturedImage = image;
          });
        }
      }
    } catch (e) {
      print('❌ Error capturing image: $e');
      if (mounted) {
        _showErrorSnackBar(
            context.tr('Failed to capture image. Please try again.'));
        // Reset state to allow retry
        setState(() {
          _isCapturing = false;
          _isAutoCaptureReady = false;
          _isAlignmentStable = false;
        });
        // Restart face detection for Express Entry
        if (widget.isExpressEntry) {
          _startFaceDetection();
        }
      }
    } finally {
      if (mounted && !widget.isExpressEntry) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    // For express entry, prevent camera switching to maintain front camera
    if (widget.isExpressEntry) {
      print(
          '📷 Express Entry: Camera switching disabled - maintaining front camera');
      _showErrorSnackBar(
          context.tr('Camera switching is disabled for face verification'));
      return;
    }

    try {
      final cameras = await availableCameras();
      final CameraDescription newCamera = cameras.firstWhere(
        (camera) =>
            camera.lensDirection ==
            (_currentCamera.lensDirection == CameraLensDirection.front
                ? CameraLensDirection.back
                : CameraLensDirection.front),
      );

      await _cameraController.dispose();

      final CameraController newController = CameraController(
        newCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await newController.initialize();
      await newController.lockCaptureOrientation(DeviceOrientation.portraitUp);

      setState(() {
        _cameraController = newController;
        _currentCamera = newCamera;
        _capturedImage = null;
        _faces = [];
        _isFaceDetected = false;
        _isFaceAligned = false;
        _isFaceInFrame = false;
        _isGoodLighting = false;
        _isAutoCaptureReady = false;
      });

      // Restart face detection for Express Entry
      if (widget.isExpressEntry) {
        _startFaceDetection();
      }
    } catch (e) {
      print('Error switching cameras: $e');
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
      _faces = [];
      _isFaceDetected = false;
      _isFaceAligned = false;
      _isFaceInFrame = false;
      _isGoodLighting = false;
      _isAutoCaptureReady = false;
    });

    // Restart face detection for Express Entry
    if (widget.isExpressEntry) {
      _startFaceDetection();
    }
  }

  void _confirmPhoto() {
    if (_capturedImage != null) {
      Navigator.of(context).pop(_capturedImage);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    // Full screen layout - no responsive dimensions needed

    return Scaffold(
      backgroundColor:
          const Color(0xFF0A0A0A), // Slightly lighter than pure black
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.isExpressEntry
                ? context.tr('Face Verification')
                : context.tr('Take Photo'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              const Color(0xFF1A1A1A).withOpacity(0.3),
              const Color(0xFF0A0A0A),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Full screen camera preview
            Positioned.fill(
              child: _capturedImage == null
                  ? Stack(
                      children: [
                        CameraPreview(_cameraController),
                        // Subtle overlay to reduce reflections
                        Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 1.0,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.1),
                              ],
                              stops: const [0.7, 1.0],
                            ),
                          ),
                        ),
                        // Face detection overlay for Express Entry
                        if (widget.isExpressEntry) _buildFaceDetectionOverlay(),
                        // Enhanced success animation overlay
                        if (_isCapturing)
                          AnimatedBuilder(
                            animation: _successAnimation,
                            builder: (context, child) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment.center,
                                    radius: _successAnimation.value * 2,
                                    colors: [
                                      Colors.green.withOpacity(
                                          _successAnimation.value * 0.4),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Transform.scale(
                                    scale: _successAnimation.value,
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Colors.green,
                                            Colors.lightGreen
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.green.withOpacity(0.6),
                                            blurRadius: 20,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 60,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    )
                  : Image.file(
                      File(_capturedImage!.path),
                      fit: BoxFit.cover,
                    ),
            ),

            // Overlay UI elements
            SafeArea(
              child: Column(
                children: [
                  // Enhanced Instructions for Express Entry
                  if (widget.isExpressEntry) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Status indicator with icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isFaceAligned
                                      ? Colors.green
                                      : Colors.orange,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isFaceAligned
                                              ? Colors.green
                                              : Colors.orange)
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isFaceAligned
                                      ? Icons.check_circle
                                      : Icons.face,
                                  color: Colors.white,
                                  size: isTablet ? 28 : 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _getInstructionText(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isTablet ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),

                          // Progress indicator
                          if (_isFaceDetected) ...[
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: _isFaceAligned
                                        ? constraints.maxWidth
                                        : 0.0,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.green,
                                          Colors.lightGreen
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],

                          // Auto-capture countdown
                          if (_isAutoCaptureReady) ...[
                            const SizedBox(height: 12),
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.green,
                                          Colors.lightGreen
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(25),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.4),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.timer,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Auto-capturing in 2 seconds...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Spacer to push controls to bottom
                  const Spacer(),

                  // Controls
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: isTablet ? 32 : 16,
                      top: 8,
                    ),
                    child: _capturedImage == null
                        ? widget.isExpressEntry
                            ? // Express Entry: No camera switch button (front camera only)
                            Container() // Empty container - no camera switch for express entry
                            : // Regular flow: Show all controls
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildControlButton(
                                    onPressed: _switchCamera,
                                    icon: Icons.flip_camera_ios_rounded,
                                    size: isTablet ? 40 : 30,
                                  ),
                                  _buildCaptureButton(isTablet),
                                  _buildControlButton(
                                    onPressed:
                                        null, // Placeholder for future feature
                                    icon: Icons.flash_off_rounded,
                                    size: isTablet ? 40 : 30,
                                  ),
                                ],
                              )
                        : // Image captured: Show retake/confirm buttons
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildControlButton(
                                onPressed: _retakePhoto,
                                icon: Icons.refresh_rounded,
                                size: isTablet ? 40 : 30,
                              ),
                              _buildControlButton(
                                onPressed: _confirmPhoto,
                                icon: Icons.check_circle_rounded,
                                size: isTablet ? 50 : 40,
                                color: Colors.green,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceDetectionOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: FaceDetectionPainter(
            faces: _faces,
            isFaceAligned: _isFaceAligned,
            isFaceInFrame: _isFaceInFrame,
            isGoodLighting: _isGoodLighting,
            scanAnimation: _scanAnimation,
          ),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }

  Widget _buildControlButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required double size,
    Color? color,
  }) {
    return Container(
      width: size + 20,
      height: size + 20,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: color ?? Colors.white,
          size: size,
        ),
      ),
    );
  }

  Widget _buildCaptureButton(bool isTablet) {
    final buttonSize = isTablet ? 80.0 : 70.0;
    final innerSize = isTablet ? 60.0 : 50.0;

    return GestureDetector(
      onTap: _isCapturing ? null : _captureImage,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _isFaceAligned && widget.isExpressEntry
                ? Colors.green
                : Colors.white,
            width: 4,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isFaceAligned && widget.isExpressEntry
                ? Colors.green
                : Colors.white,
          ),
          child: Center(
            child: _isCapturing
                ? SizedBox(
                    width: innerSize * 0.4,
                    height: innerSize * 0.4,
                    child: const DashboardLoaderIcon(
                      color: Colors.black,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    Icons.camera_alt,
                    color: _isFaceAligned && widget.isExpressEntry
                        ? Colors.white
                        : Colors.black,
                    size: innerSize * 0.5,
                  ),
          ),
        ),
      ),
    );
  }

  String _getInstructionText() {
    if (!_isFaceDetected) {
      return 'Position your face in the oval guide';
    } else if (!_isFaceInFrame) {
      return 'Move closer or further away to fit the oval';
    } else if (!_isFaceAligned) {
      return 'Look straight at the camera and hold still';
    } else if (_isAutoCaptureReady) {
      return 'Perfect! Auto-capturing in 2 seconds...';
    } else {
      return 'Align your face perfectly in the oval';
    }
  }

  String? _getInstructionTextForTts() {
    if (!_isFaceDetected) {
      return 'Place your face inside the circle.';
    }
    if (!_isFaceInFrame) {
      return 'Move closer or further to fit your face inside the circle.';
    }
    if (!_isFaceAligned) {
      return 'Look straight at the camera and keep your head steady.';
    }
    if (_isAutoCaptureReady && !_isAlignmentStable) {
      final progress =
          (_alignmentDurationMs / _alignmentStabilityMs * 100).round();
      return 'Hold steady. $progress% ready.';
    }
    if (_isAutoCaptureReady && _isAlignmentStable) {
      return 'Perfect. Hold still. Capturing soon.';
    }
    return null;
  }
}

class FaceDetectionPainter extends CustomPainter {
  final List<Face> faces;
  final bool isFaceAligned;
  final bool isFaceInFrame;
  final bool isGoodLighting;
  final Animation<double> scanAnimation;

  FaceDetectionPainter({
    required this.faces,
    required this.isFaceAligned,
    required this.isFaceInFrame,
    required this.isGoodLighting,
    required this.scanAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;

    final face = faces.first;
    final boundingBox = face.boundingBox;

    // Calculate face center and dimensions
    final faceCenter = Offset(
      boundingBox.center.dx,
      boundingBox.center.dy,
    );
    final faceWidth = boundingBox.width;
    final faceHeight = boundingBox.height;

    // Draw face oval guide
    _drawFaceOval(canvas, faceCenter, faceWidth, faceHeight);

    // Draw face landmarks
    _drawFaceLandmarks(canvas, face);

    // Draw scanning animation
    _drawScanningAnimation(canvas, size);
  }

  void _drawFaceOval(
      Canvas canvas, Offset center, double width, double height) {
    // Create a more prominent oval shape
    final ovalWidth = width * 1.3; // Slightly larger oval
    final ovalHeight = height * 1.6; // More oval-shaped (taller)

    final rect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    // Draw main oval with gradient effect
    final mainPaint = Paint()
      ..color = isFaceAligned ? Colors.green : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawOval(rect, mainPaint);

    // Draw inner oval for better visual guidance
    final innerRect = Rect.fromCenter(
      center: center,
      width: ovalWidth * 0.8,
      height: ovalHeight * 0.8,
    );

    final innerPaint = Paint()
      ..color = (isFaceAligned ? Colors.green : Colors.white).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawOval(innerRect, innerPaint);

    // Draw corner indicators with better styling
    final cornerPaint = Paint()
      ..color = isFaceAligned ? Colors.green : Colors.white
      ..style = PaintingStyle.fill;

    const cornerSize = 24.0;
    final cornerPositions = [
      Offset(rect.left, rect.top), // Top-left
      Offset(rect.right, rect.top), // Top-right
      Offset(rect.left, rect.bottom), // Bottom-left
      Offset(rect.right, rect.bottom), // Bottom-right
    ];

    for (final corner in cornerPositions) {
      // Draw corner circle
      canvas.drawCircle(corner, cornerSize / 2, cornerPaint);

      // Draw corner border
      final cornerBorderPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(corner, cornerSize / 2, cornerBorderPaint);
    }

    // Draw center crosshair for better alignment
    final crosshairPaint = Paint()
      ..color = (isFaceAligned ? Colors.green : Colors.white).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const crosshairSize = 20.0;
    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - crosshairSize, center.dy),
      Offset(center.dx + crosshairSize, center.dy),
      crosshairPaint,
    );
    // Vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - crosshairSize),
      Offset(center.dx, center.dy + crosshairSize),
      crosshairPaint,
    );
  }

  void _drawFaceLandmarks(Canvas canvas, Face face) {
    final paint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    // Draw key landmarks
    final landmarks = [
      face.landmarks[FaceLandmarkType.leftEye],
      face.landmarks[FaceLandmarkType.rightEye],
      face.landmarks[FaceLandmarkType.noseBase],
      face.landmarks[FaceLandmarkType.leftEar],
      face.landmarks[FaceLandmarkType.rightEar],
    ];

    for (final landmark in landmarks) {
      if (landmark != null) {
        canvas.drawCircle(
          Offset(
              landmark.position.x.toDouble(), landmark.position.y.toDouble()),
          3,
          paint,
        );
      }
    }
  }

  void _drawScanningAnimation(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Draw scanning line
    final scanY = size.height * scanAnimation.value;
    final rect = Rect.fromLTWH(0, scanY - 2, size.width, 4);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
