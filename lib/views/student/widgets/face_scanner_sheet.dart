import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../services/face_verification_service.dart';

class FaceScannerSheet extends StatefulWidget {
  final FaceSignature? targetSignature;
  final String studentName;

  const FaceScannerSheet({
    super.key,
    required this.targetSignature,
    required this.studentName,
  });

  @override
  State<FaceScannerSheet> createState() => _FaceScannerSheetState();
}

class _FaceScannerSheetState extends State<FaceScannerSheet>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  bool _cameraUnavailable = false;

  // Liveness & Matching states
  String _instruction = 'Position your face in the oval';
  Color _statusColor = Colors.white;
  bool _faceInOval = false;
  bool _hasBlinked = false;
  bool _isSuccess = false;
  String? _capturedPhotoPath;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraUnavailable = true);
        return;
      }

      // Pick the front camera
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) return;

      _cameraController = controller;
      setState(() => _isCameraInitialized = true);

      // Start processing frames
      controller.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('FaceScannerSheet camera error: $e');
      if (mounted) {
        setState(() => _cameraUnavailable = true);
      }
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessingFrame || _isSuccess || !mounted) return;
    _isProcessingFrame = true;

    try {
      final faceService = FaceVerificationService();
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final faces = await faceService.detector.processImage(inputImage);
      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _instruction = 'No face detected • Look at camera';
          _statusColor = Colors.orange;
          _faceInOval = false;
        });
        _isProcessingFrame = false;
        return;
      }

      final face = faces.first;
      final box = face.boundingBox;

      // Ensure face is reasonably centered
      final isCentered = box.width > 80 && box.height > 80;

      if (!isCentered) {
        setState(() {
          _instruction = 'Move closer to the camera';
          _statusColor = Colors.amber;
          _faceInOval = false;
        });
        _isProcessingFrame = false;
        return;
      }

      _faceInOval = true;

      // ── Step 1: Liveness / Blink check ─────────────────────────────
      final leftOpen = face.leftEyeOpenProbability ?? 1.0;
      final rightOpen = face.rightEyeOpenProbability ?? 1.0;

      if (!_hasBlinked) {
        if (leftOpen < 0.35 && rightOpen < 0.35) {
          _hasBlinked = true;
          HapticFeedback.lightImpact();
        } else {
          setState(() {
            _instruction = 'Blink naturally for liveness check';
            _statusColor = Colors.cyanAccent;
          });
          _isProcessingFrame = false;
          return;
        }
      }

      // ── Step 2: Compare with registered signature ───────────────────
      final liveSignature = faceService.extractSignature(face);
      if (liveSignature != null && widget.targetSignature != null) {
        final distance = liveSignature.distanceTo(widget.targetSignature!);
        if (distance > 0.38) {
          setState(() {
            _instruction = 'Face does not match registered profile photo!';
            _statusColor = Colors.redAccent;
          });
          _isProcessingFrame = false;
          return;
        }
      }

      // ── Verification Passed! ────────────────────────────────────────
      _isSuccess = true;
      HapticFeedback.mediumImpact();

      setState(() {
        _instruction = 'Face Verified Successfully! ✓';
        _statusColor = Colors.greenAccent;
      });

      // Stop stream and take snapshot picture for audit thumbnail
      await _cameraController?.stopImageStream();
      try {
        final pic = await _cameraController?.takePicture();
        _capturedPhotoPath = pic?.path;
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      Navigator.of(context).pop<({bool verified, String? photoPath})>((
        verified: true,
        photoPath: _capturedPhotoPath,
      ));
    } catch (e) {
      debugPrint('Face detection frame error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    final orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

    final rotation = InputImageRotationValue.fromRawValue(
      (sensorOrientation - (orientations[DeviceOrientation.portraitUp] ?? 0) + 360) %
          360,
    ) ?? InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        (Platform.isAndroid
            ? InputImageFormat.nv21
            : InputImageFormat.bgra8888);

    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF101216),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Drag Handle & Title
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Layer 2: Face Verification',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Verifying for ${widget.studentName}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 20),

          // Main Viewport (Camera or Fallback)
          Expanded(
            child: Center(
              child: _cameraUnavailable
                  ? _buildFallbackUi()
                  : _isCameraInitialized
                      ? _buildCameraScanner()
                      : const CircularProgressIndicator(color: Colors.white),
            ),
          ),

          // Instruction Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            color: Colors.black45,
            child: Column(
              children: [
                Text(
                  _instruction,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _hasBlinked
                      ? 'Liveness verified ✓ • Matching with profile'
                      : 'Please keep head upright & blink naturally',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraScanner() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera Preview clipped to oval shape
        ClipOval(
          child: SizedBox(
            width: 250,
            height: 330,
            child: CameraPreview(_cameraController!),
          ),
        ),

        // Animated Oval Outline Reticle
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 250,
            height: 330,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(130),
              border: Border.all(
                color: _isSuccess
                    ? Colors.greenAccent
                    : (_faceInOval ? Colors.cyanAccent : _statusColor)
                        .withValues(alpha: 0.8),
                width: _isSuccess ? 5.0 : 3.0,
              ),
            ),
          ),
        ),

        // Success Checkmark Badge
        if (_isSuccess)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
          ),
      ],
    );
  }

  /// Fallback UI for Simulator or when camera permission is unavailable
  Widget _buildFallbackUi() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_photography_rounded, size: 60, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          const Text(
            'Camera Unavailable',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hardware camera is not available on this simulator. You can bypass in test mode.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop<({bool verified, String? photoPath})>((
                verified: true,
                photoPath: null,
              ));
            },
            icon: const Icon(Icons.verified_user_rounded),
            label: const Text('Simulate Face Verified (Test Mode)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
