// lib/screens/camera_screen.dart

import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';  // ← ADD THIS for compute()
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../utils/eye_detector.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  FlashMode _flashMode = FlashMode.torch; // Flash ON for ACD accuracy
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionsAndInit();
  }

  Future<void> _requestPermissionsAndInit() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initCamera();
    } else {
      setState(() => _errorMessage = 'Camera permission denied.');
    }
  }

  Future<void> _initCamera() async {
    // Select rear camera
    CameraDescription? rear;
    for (final cam in widget.cameras) {
      if (cam.lensDirection == CameraLensDirection.back) {
        rear = cam;
        break;
      }
    }

    if (rear == null) {
      setState(() => _errorMessage = 'No rear camera found.');
      return;
    }

    _controller = CameraController(
      rear,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = 'Camera init error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    final newMode =
        _flashMode == FlashMode.torch ? FlashMode.off : FlashMode.torch;
    await _controller!.setFlashMode(newMode);
    setState(() => _flashMode = newMode);
  }
Future<void> _captureAndAnalyze() async {
  if (_controller == null || _isCapturing || _isAnalyzing) return;
  setState(() => _isCapturing = true);

  try {
    final XFile image = await _controller!.takePicture();

    final dir = await getTemporaryDirectory();
    final savePath = p.join(
        dir.path, 'eye_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(image.path).copy(savePath);

    setState(() {
      _isCapturing = false;
      _isAnalyzing = true;
    });

    final ACDResult result = await EyeDetector.analyzeImage(savePath);

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          imagePath: savePath,
          result: result,
        ),
      ),
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isCapturing = false;
        _isAnalyzing = false;
      });
    }
  }
}
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // ── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Capture Eye Image',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(
              _flashMode == FlashMode.torch
                  ? Icons.flashlight_on_rounded
                  : Icons.flashlight_off_rounded,
              color: _flashMode == FlashMode.torch
                  ? const Color(0xFF38C5E0)
                  : Colors.white54,
            ),
            onPressed: _toggleFlash,
            tooltip: 'Toggle flash',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF38C5E0)),
      );
    }

    if (_isAnalyzing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF38C5E0)),
            SizedBox(height: 20),
            Text('Analyzing ACD...',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            SizedBox(height: 6),
            Text('Detecting cornea & pupil boundaries',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Camera preview – fills screen
        Positioned.fill(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize!.height,
                  height: _controller!.value.previewSize!.width,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
        ),

        // Eye targeting overlay
        Positioned.fill(child: CustomPaint(painter: _EyeTargetPainter())),

        // Tip banner
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '📌  Hold phone 5–8 cm from the eye. Keep flash ON for best ACD accuracy.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Capture button
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _isCapturing ? null : _captureAndAnalyze,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _isCapturing ? 70 : 78,
                height: _isCapturing ? 70 : 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isCapturing
                      ? const Color(0xFF38C5E0).withOpacity(0.5)
                      : const Color(0xFF38C5E0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38C5E0).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Eye targeting overlay ─────────────────────────────────────────────────────

class _EyeTargetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF38C5E0).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Outer iris guide ellipse
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 200, height: 140),
      paint,
    );

    // Inner pupil dot
    paint.color = const Color(0xFF38C5E0).withOpacity(0.4);
    canvas.drawCircle(Offset(cx, cy), 28, paint);

    // Corner brackets
    paint
      ..color = const Color(0xFF38C5E0)
      ..strokeWidth = 2.5;

    const g = 28.0;
    const pad = 80.0;

    void bracket(double bx, double by, double sx, double sy) {
      canvas.drawLine(Offset(bx, by), Offset(bx + sx * g, by), paint);
      canvas.drawLine(Offset(bx, by), Offset(bx, by + sy * g), paint);
    }

    bracket(cx - pad, cy - pad, 1, 1);
    bracket(cx + pad, cy - pad, -1, 1);
    bracket(cx - pad, cy + pad, 1, -1);
    bracket(cx + pad, cy + pad, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
