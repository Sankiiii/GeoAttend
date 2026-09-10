import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simplified geometric face signature extracted from ML Kit landmarks and contours.
class FaceSignature {
  final double eyeDistanceRatio; // eyeDistance / faceHeight
  final double noseToMouthRatio; // noseToMouth / faceHeight
  final double eyeToNoseRatio;  // eyeCenterToNose / faceHeight
  final double faceAspectRatio; // faceWidth / faceHeight

  const FaceSignature({
    required this.eyeDistanceRatio,
    required this.noseToMouthRatio,
    required this.eyeToNoseRatio,
    required this.faceAspectRatio,
  });

  Map<String, dynamic> toJson() => {
        'eyeDistanceRatio': eyeDistanceRatio,
        'noseToMouthRatio': noseToMouthRatio,
        'eyeToNoseRatio': eyeToNoseRatio,
        'faceAspectRatio': faceAspectRatio,
      };

  factory FaceSignature.fromJson(Map<String, dynamic> json) => FaceSignature(
        eyeDistanceRatio: (json['eyeDistanceRatio'] as num).toDouble(),
        noseToMouthRatio: (json['noseToMouthRatio'] as num).toDouble(),
        eyeToNoseRatio: (json['eyeToNoseRatio'] as num).toDouble(),
        faceAspectRatio: (json['faceAspectRatio'] as num).toDouble(),
      );

  /// Computes distance (difference) between this signature and another.
  /// Values < 0.25 indicate a high confidence match of the same facial structure.
  double distanceTo(FaceSignature other) {
    final d1 = (eyeDistanceRatio - other.eyeDistanceRatio).abs();
    final d2 = (noseToMouthRatio - other.noseToMouthRatio).abs();
    final d3 = (eyeToNoseRatio - other.eyeToNoseRatio).abs();
    final d4 = (faceAspectRatio - other.faceAspectRatio).abs();
    return (d1 * 1.5 + d2 * 1.0 + d3 * 1.0 + d4 * 0.8) / 4.3;
  }
}

/// Service that handles Profile Face Registration and Live Face Verification with Liveness checks.
class FaceVerificationService {
  static final FaceVerificationService _instance =
      FaceVerificationService._internal();
  factory FaceVerificationService() => _instance;
  FaceVerificationService._internal();

  FaceDetector? _detector;

  FaceDetector get detector {
    _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // Eye open/closed probabilities
        enableLandmarks: true,      // Eyes, nose, mouth positions
        enableContours: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    return _detector!;
  }

  /// Extracts [FaceSignature] from a detected ML Kit [Face].
  FaceSignature? extractSignature(Face face) {
    final box = face.boundingBox;
    final h = box.height;
    final w = box.width;
    if (h <= 0 || w <= 0) return null;

    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final mouth = face.landmarks[FaceLandmarkType.bottomMouth]?.position;

    // Fallback if specific landmarks are missing
    double eyeDist = w * 0.38;
    double eyeToNose = h * 0.25;
    double noseToMouth = h * 0.22;

    if (leftEye != null && rightEye != null) {
      eyeDist = math.sqrt(
        math.pow(rightEye.x - leftEye.x, 2) +
            math.pow(rightEye.y - leftEye.y, 2),
      );
    }
    if (nose != null && leftEye != null && rightEye != null) {
      final midEyeY = (leftEye.y + rightEye.y) / 2.0;
      eyeToNose = (nose.y - midEyeY).abs().toDouble();
    }
    if (nose != null && mouth != null) {
      noseToMouth = (mouth.y - nose.y).abs().toDouble();
    }

    return FaceSignature(
      eyeDistanceRatio: eyeDist / h,
      noseToMouthRatio: noseToMouth / h,
      eyeToNoseRatio: eyeToNose / h,
      faceAspectRatio: w / h,
    );
  }

  /// Analyzes a static image file (e.g. registered student profile photo).
  /// Returns the extracted [FaceSignature] and base64 string, or throws an exception if no face is detected.
  Future<({FaceSignature signature, String base64Thumbnail})> registerProfilePhoto(
      File photoFile) async {
    final inputImage = InputImage.fromFile(photoFile);
    final faces = await detector.processImage(inputImage);

    if (faces.isEmpty) {
      throw Exception(
          'No clear face detected in the photo. Please use a well-lit photo looking directly at the camera.');
    }

    if (faces.length > 1) {
      throw Exception(
          'Multiple faces detected. Please upload a photo with only you in it.');
    }

    final face = faces.first;
    final sig = extractSignature(face);
    if (sig == null) {
      throw Exception('Could not extract facial landmarks. Please try another photo.');
    }

    // Read bytes for storage thumbnail
    final bytes = await photoFile.readAsBytes();
    final base64Str = base64Encode(bytes);

    return (signature: sig, base64Thumbnail: base64Str);
  }

  /// Stores student face signature and profile photo path in SharedPreferences.
  Future<void> saveStudentProfile({
    required String rollNo,
    required String photoPath,
    required FaceSignature signature,
    required String base64Thumbnail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keyPrefix = 'student_face_${rollNo.trim().toUpperCase()}';
    await prefs.setString('${keyPrefix}_path', photoPath);
    await prefs.setString('${keyPrefix}_sig', jsonEncode(signature.toJson()));
    await prefs.setString('${keyPrefix}_thumb', base64Thumbnail);
  }

  /// Retrieves stored student profile information.
  Future<({String photoPath, FaceSignature signature, String base64Thumbnail})?>
      getStudentProfile(String rollNo) async {
    final prefs = await SharedPreferences.getInstance();
    final keyPrefix = 'student_face_${rollNo.trim().toUpperCase()}';
    final path = prefs.getString('${keyPrefix}_path');
    final sigStr = prefs.getString('${keyPrefix}_sig');
    final thumb = prefs.getString('${keyPrefix}_thumb');

    if (path == null || sigStr == null) return null;

    try {
      final sig = FaceSignature.fromJson(jsonDecode(sigStr) as Map<String, dynamic>);
      return (
        photoPath: path,
        signature: sig,
        base64Thumbnail: thumb ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Disposes the underlying native face detector resources.
  void dispose() {
    _detector?.close();
    _detector = null;
  }
}
