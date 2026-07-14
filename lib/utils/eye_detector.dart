// lib/utils/eye_detector.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

const String _serverIP   = '10.88.193.192';  // ← New IP, NO extra spaces!
const String _serverPort = '5000';
const String _baseUrl    = 'http://$_serverIP:$_serverPort';

class ACDResult {
  final double acdPixels;
  final double acdMm;
  final String riskLevel;
  final String riskDescription;
  final double cornealDiameterPx;
  final bool   detectionSuccess;
  final String debugInfo;
  final String? debugImageBase64;

  const ACDResult({
    required this.acdPixels,
    required this.acdMm,
    required this.riskLevel,
    required this.riskDescription,
    required this.cornealDiameterPx,
    required this.detectionSuccess,
    this.debugInfo        = '',
    this.debugImageBase64,
  });

  factory ACDResult.failed(String reason) => ACDResult(
        acdPixels:         0,
        acdMm:             0,
        riskLevel:         'Unknown',
        riskDescription:   reason,
        cornealDiameterPx: 0,
        detectionSuccess:  false,
        debugInfo:         reason,
      );

  factory ACDResult.fromJson(Map<String, dynamic> json) => ACDResult(
        acdPixels:         (json['acd_pixels']          ?? 0).toDouble(),
        acdMm:             (json['acd_mm']              ?? 0).toDouble(),
        riskLevel:          json['risk_level']           ?? 'Unknown',
        riskDescription:    json['risk_description']     ?? '',
        cornealDiameterPx: (json['corneal_diameter_px'] ?? 0).toDouble(),
        detectionSuccess:   json['detection_success']   ?? false,
        debugInfo:
            'Pupil r=${json["pupil_radius_px"]}px | '
            'Iris r=${json["iris_radius_px"]}px',
        debugImageBase64:   json['debug_image_base64'],
      );
}

class EyeDetector {
  static Future<ACDResult> analyzeImage(String imagePath) async {
    try {
      // 1. Compress image before sending
      final dir         = await getTemporaryDirectory();
      final targetPath  = p.join(dir.path, 'compressed_eye.jpg');

      final compressed  = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality:  60,    // reduce quality
        minWidth: 640,   // max width
        minHeight:480,   // max height
      );

      final String sendPath = compressed?.path ?? imagePath;
      final int fileSize    = File(sendPath).lengthSync();
      print('Sending image: ${(fileSize/1024).toStringAsFixed(0)} KB');

      // 2. Health check
      final health = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 180));
      if (health.statusCode != 200) {
        return ACDResult.failed('Server not reachable. Start py -3.11 app.py on PC.');
      }

      // 3. Send compressed image
      final req = http.MultipartRequest(
          'POST', Uri.parse('$_baseUrl/analyze'));
      req.files.add(
          await http.MultipartFile.fromPath('image', sendPath));

      final streamed = await req.send()
          .timeout(const Duration(seconds: 180));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        return ACDResult.failed('Server error: ${response.statusCode}');
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data['detection_success'] == false) {
        return ACDResult.failed(
            data['risk_description'] ?? 'Detection failed.');
      }

      return ACDResult.fromJson(data);

    } on SocketException {
      return ACDResult.failed(
          'Cannot connect to server.\n'
          '1. Run: py -3.11 app.py on PC\n'
          '2. Phone and PC on SAME WiFi\n'
          '3. Check IP in eye_detector.dart');
    } catch (e) {
      return ACDResult.failed('Error: $e');
    }
  }
}
