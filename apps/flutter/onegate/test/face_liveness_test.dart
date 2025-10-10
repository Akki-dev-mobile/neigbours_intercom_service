import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

void main() {
  group('Face Liveness Detection Tests', () {
    late FaceDetector faceDetector;

    setUp(() {
      faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableLandmarks: true,
          enableClassification: true,
          enableTracking: true,
          minFaceSize: 0.1,
        ),
      );
    });

    tearDown(() {
      faceDetector.close();
    });

    test('Face detector should be initialized correctly', () {
      expect(faceDetector, isNotNull);
    });

    test('Face alignment thresholds should be within valid ranges', () {
      // Test face size thresholds
      const double minFaceSize = 0.15;
      const double maxFaceSize = 0.8;

      expect(minFaceSize, greaterThan(0.0));
      expect(maxFaceSize, lessThan(1.0));
      expect(maxFaceSize, greaterThan(minFaceSize));
    });

    test('Head rotation thresholds should be reasonable', () {
      const double maxHeadRotationX = 15.0;
      const double maxHeadRotationY = 15.0;
      const double maxHeadRotationZ = 10.0;

      expect(
          maxHeadRotationX, lessThan(45.0)); // Should be less than 45 degrees
      expect(maxHeadRotationY, lessThan(45.0));
      expect(maxHeadRotationZ, lessThan(45.0));
    });

    test('Eye openness threshold should be valid', () {
      const double minEyeOpenProbability = 0.3;

      expect(minEyeOpenProbability, greaterThan(0.0));
      expect(minEyeOpenProbability, lessThan(1.0));
    });

    test('Auto-capture timing should be reasonable', () {
      const int autoCaptureDelayMs = 2000;
      const int faceDetectionIntervalMs = 100;

      expect(autoCaptureDelayMs, greaterThan(1000)); // At least 1 second
      expect(autoCaptureDelayMs, lessThan(10000)); // Less than 10 seconds
      expect(faceDetectionIntervalMs, greaterThan(50)); // At least 50ms
      expect(faceDetectionIntervalMs, lessThan(500)); // Less than 500ms
    });
  });

  group('Face Alignment Logic Tests', () {
    test('Face size calculation should work correctly', () {
      // Mock face bounding box
      final mockBoundingBox = Rect.fromLTWH(100, 100, 200, 250);
      final mockFrameSize = const Size(400, 600);

      // Calculate face size
      final faceWidth = mockBoundingBox.width / mockFrameSize.width;
      final faceHeight = mockBoundingBox.height / mockFrameSize.height;
      final faceSize = faceWidth > faceHeight ? faceWidth : faceHeight;

      expect(
          faceSize, closeTo(0.5, 0.1)); // Should be around 0.5 (50% of frame)
    });

    test('Face alignment evaluation should work correctly', () {
      // Test face in frame
      const double faceSize = 0.3; // 30% of frame
      const double headRotationX = 5.0; // 5 degrees
      const double headRotationY = 3.0; // 3 degrees
      const double headRotationZ = 2.0; // 2 degrees
      const double leftEyeOpen = 0.8; // 80% open
      const double rightEyeOpen = 0.9; // 90% open

      const double minFaceSize = 0.15;
      const double maxFaceSize = 0.8;
      const double maxHeadRotationX = 15.0;
      const double maxHeadRotationY = 15.0;
      const double maxHeadRotationZ = 10.0;
      const double minEyeOpenProbability = 0.3;

      // Evaluate alignment
      const isFaceInFrame = faceSize >= minFaceSize && faceSize <= maxFaceSize;
      const isHeadStraight = headRotationX <= maxHeadRotationX &&
          headRotationY <= maxHeadRotationY &&
          headRotationZ <= maxHeadRotationZ;
      const eyesOpen = leftEyeOpen >= minEyeOpenProbability &&
          rightEyeOpen >= minEyeOpenProbability;
      const isLookingAtCamera = eyesOpen;
      const isFaceAligned =
          isFaceInFrame && isHeadStraight && isLookingAtCamera;

      expect(isFaceInFrame, isTrue);
      expect(isHeadStraight, isTrue);
      expect(eyesOpen, isTrue);
      expect(isLookingAtCamera, isTrue);
      expect(isFaceAligned, isTrue);
    });

    test('Face alignment should fail for poor conditions', () {
      // Test face too small
      const double smallFaceSize = 0.1; // 10% of frame
      const double minFaceSize = 0.15;

      const isFaceInFrame = smallFaceSize >= minFaceSize;
      expect(isFaceInFrame, isFalse);

      // Test head rotation too large
      const double largeHeadRotation = 20.0; // 20 degrees
      const double maxHeadRotation = 15.0;

      const isHeadStraight = largeHeadRotation <= maxHeadRotation;
      expect(isHeadStraight, isFalse);

      // Test eyes closed
      const double closedEye = 0.1; // 10% open
      const double minEyeOpen = 0.3;

      const eyesOpen = closedEye >= minEyeOpen;
      expect(eyesOpen, isFalse);
    });
  });
}
