// import 'dart:convert';
// import 'dart:io';
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_onegate/data/datasources/gate_storage.dart';
// import 'package:flutter_onegate/utils/app_urls.dart';
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import 'package:http/http.dart' as http;
// import 'package:dio/dio.dart';

// class FaceIDRegistrationScreen extends StatefulWidget {
//   const FaceIDRegistrationScreen({super.key});

//   @override
//   _FaceIDRegistrationScreenState createState() =>
//       _FaceIDRegistrationScreenState();
// }

// /// Upload multiple face images for face registration
// Future<void> _uploadImages(String userName, List<File> images) async {
//   try {
//     final societyid = await GateStorage().getSocietyId();

//     final faceRecConfig = await GateStorage().getFaceRecConfig();

//     List<String> allowed = faceRecConfig != null
//         ? List<String>.from(faceRecConfig['allowed'] ?? [])
//         : [];

//     Dio dio = Dio();
//     if (faceRecConfig != null &&
//         faceRecConfig['url'] != null &&
//         faceRecConfig['url'] != "" &&
//         faceRecConfig['allowed'] != null &&
//         societyid != null &&
//         allowed.contains(societyid.toString())) {
//       String apiUrl = faceRecConfig['url'] ?? '';

//       if (images.length < 8) {
//         // Update minimum requirement to 8 images
//         print("❌ Error: At least 8 images are required.");
//         return;
//       }

//       // Convert images to MultipartFile
//       List<MultipartFile> multipartFiles = [];
//       for (var image in images) {
//         multipartFiles.add(await MultipartFile.fromFile(image.path,
//             filename: image.path.split('/').last));
//       }

//       // Prepare form data
//       FormData formData = FormData.fromMap({
//         "name": userName, // Required name field
//         "files": multipartFiles, // Multiple images
//       });

//       // Send request
//       Response response = await dio.post(
//         apiUrl,
//         data: formData,
//         options: Options(
//           headers: {"Content-Type": "multipart/form-data"},
//         ),
//       );

//       // Handle Response
//       if (response.statusCode == 200) {
//         print('✅ Face registration successful: ${response.data["message"]}');
//         print('Uploaded Images: ${response.data["uploaded_images"]}');
//       } else {
//         print('⚠️ Unexpected Error (${response.statusCode}): ${response.data}');
//       }
//     }
//   } on DioError catch (e) {
//     if (e.response != null) {
//       if (e.response!.statusCode == 422) {
//         print('❌ Validation Error (422): ${e.response!.data}');
//       } else {
//         print(
//             '⚠️ Server Error (${e.response!.statusCode}): ${e.response!.data}');
//       }
//     } else {
//       print('🚨 Request failed: ${e.message}');
//     }
//   } catch (e) {
//     print('🚨 Unexpected Error: $e');
//   }
// }

// class _FaceIDRegistrationScreenState extends State<FaceIDRegistrationScreen> {
//   CameraController? _cameraController;
//   FaceDetector? _faceDetector;
//   bool _isProcessing = false;
//   final List<File> _capturedImages = [];
//   int _currentStep = 0;
//   final int maxSteps = 9; // Capture 9 different angles

//   final List<String> _instructions = [
//     "Look straight",
//     "Turn your head slightly left",
//     "Turn your head slightly right",
//     "Look up slightly",
//     "Look down slightly",
//     "Tilt your head left",
//     "Tilt your head right",
//     "Smile slightly",
//     "Blink your eyes",
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _initializeCamera();
//     _faceDetector =
//         FaceDetector(options: FaceDetectorOptions(enableClassification: true));
//   }

//   /// Initialize the camera
//   Future<void> _initializeCamera() async {
//     final cameras = await availableCameras();
//     if (cameras.isNotEmpty) {
//       _cameraController = CameraController(cameras[1], ResolutionPreset.medium);
//       await _cameraController!.initialize();
//       if (mounted) setState(() {});
//       _detectFaces();
//     } else {
//       print('No camera found');
//     }
//   }

//   /// Detects faces and tracks movement
//   Future<void> _detectFaces() async {
//     while (mounted) {
//       if (!_cameraController!.value.isInitialized || _isProcessing) continue;

//       _isProcessing = true;
//       try {
//         final XFile image = await _cameraController!.takePicture();
//         final File file = File(image.path);
//         final InputImage inputImage = InputImage.fromFile(file);
//         final List<Face> faces = await _faceDetector!.processImage(inputImage);

//         if (faces.isNotEmpty) {
//           Face face = faces.first;

//           // Debugging: Print detected face angles
//           print(
//               "Head Euler Angles - X: ${face.headEulerAngleX}, Y: ${face.headEulerAngleY}, Z: ${face.headEulerAngleZ}");

//           _evaluateFacePosition(face, file);
//         }
//       } catch (e) {
//         print('Face detection error: $e');
//       }
//       _isProcessing = false;
//       await Future.delayed(
//           const Duration(milliseconds: 300)); // Faster response time
//     }
//   }

//   /// Evaluates the face position and captures at different angles
//   void _evaluateFacePosition(Face face, File file) {
//     if (_currentStep >= maxSteps) return;

//     bool shouldCapture = false;
//     switch (_currentStep) {
//       case 0: // Look straight
//         shouldCapture = true;
//         break;
//       case 1: // Turn left slightly
//         shouldCapture = face.headEulerAngleY! < -7; // Reduced threshold
//         break;
//       case 2: // Turn right slightly
//         shouldCapture = face.headEulerAngleY! > 7;
//         break;
//       case 3: // Look up slightly
//         shouldCapture = face.headEulerAngleX! < -7;
//         break;
//       case 4: // Look down slightly
//         shouldCapture = face.headEulerAngleX! > 7;
//         break;
//       case 5: // Tilt left
//         shouldCapture = face.headEulerAngleZ! < -7;
//         break;
//       case 6: // Tilt right
//         shouldCapture = face.headEulerAngleZ! > 7;
//         break;
//       case 7: // Smile (If ML Kit detects smiling)
//         shouldCapture =
//             (face.smilingProbability ?? 0) > 0.7; // Reduced threshold
//         break;
//       case 8: // Blink (If ML Kit detects blinking)
//         shouldCapture = (face.leftEyeOpenProbability ?? 0) < 0.3 ||
//             (face.rightEyeOpenProbability ?? 0) < 0.3;
//         break;
//     }

//     if (shouldCapture) {
//       _capturedImages.add(file);
//       _currentStep++;

//       print("Captured: ${_instructions[_currentStep - 1]}");

//       if (_currentStep >= maxSteps) {
//         _showCompletionDialog();
//       } else {
//         setState(() {});
//       }
//     }
//   }

//   /// Show a dialog when capturing is completed
//   void _showCompletionDialog() {
//     TextEditingController usernameController = TextEditingController();

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Face Registration Complete'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text(
//                 'Captured all angles successfully. Enter your name to proceed with upload.'),
//             const SizedBox(height: 10),
//             TextField(
//               controller: usernameController,
//               decoration: const InputDecoration(
//                 labelText: "Username",
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               String username = usernameController.text.trim();
//               if (username.isEmpty) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text("Please enter a username!")),
//                 );
//                 return;
//               }

//               _uploadImages(username, _capturedImages);
//               Navigator.pop(context);
//               Navigator.pop(context);
//             },
//             child: const Text('Upload'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _cameraController?.dispose();
//     _faceDetector?.close();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Face ID Registration")),
//       body: Column(
//         children: [
//           if (_cameraController != null &&
//               _cameraController!.value.isInitialized)
//             Expanded(child: CameraPreview(_cameraController!))
//           else
//             const Center(child: CircularProgressIndicator()),
//           const SizedBox(height: 20),
//           const Text(
//             "Move your head as instructed",
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           Text(
//             "Step ${_currentStep + 1} of $maxSteps: ${_instructions[_currentStep]}",
//             style: const TextStyle(fontSize: 20, color: Colors.blue),
//           ),
//           const SizedBox(height: 20),
//           LinearProgressIndicator(value: (_currentStep + 1) / maxSteps),
//           const SizedBox(height: 20),
//           if (_capturedImages.isNotEmpty)
//             SizedBox(
//               height: 100,
//               child: ListView.builder(
//                 scrollDirection: Axis.horizontal,
//                 itemCount: _capturedImages.length,
//                 itemBuilder: (context, index) => Padding(
//                   padding: const EdgeInsets.all(5.0),
//                   child: Image.file(_capturedImages[index], width: 80),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
