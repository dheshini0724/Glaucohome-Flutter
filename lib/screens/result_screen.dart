// lib/screens/result_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../utils/eye_detector.dart'; // ← correct relative import

class ResultScreen extends StatelessWidget {
  final String imagePath;
  final ACDResult result;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.result,
  });

  Color get _riskColor {
    switch (result.riskLevel) {
      case 'Normal':
        return const Color(0xFF2ECC71);
      case 'Borderline':
        return const Color(0xFFF39C12);
      case 'Deep Chamber':
        return const Color(0xFF5B8CFF);
      default:
        return const Color(0xFFE74C3C); // High Risk
    }
  }

  IconData get _riskIcon {
    switch (result.riskLevel) {
      case 'Normal':
        return Icons.check_circle_rounded;
      case 'Borderline':
        return Icons.warning_amber_rounded;
      case 'Deep Chamber':
        return Icons.info_rounded;
      default:
        return Icons.dangerous_rounded;
    }
  }

  double get _gaugePercent {
    if (!result.detectionSuccess) return 0;
    return (result.acdMm / 6.0).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        title: const Text('ACD Result'),
        backgroundColor: const Color(0xFF0B1120),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Retake',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Captured image ────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Image.file(
                    File(imagePath),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        result.detectionSuccess
                            ? '✓ Eye detected'
                            : '✗ Detection failed',
                        style: TextStyle(
                          color: result.detectionSuccess
                              ? const Color(0xFF2ECC71)
                              : const Color(0xFFE74C3C),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── ACD measurement card ──────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF112233),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Anterior Chamber Depth',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  result.detectionSuccess
                      ? Text(
                          '${result.acdMm} mm',
                          style: const TextStyle(
                            color: Color(0xFF38C5E0),
                            fontSize: 52,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        )
                      : const Text('—',
                          style:
                              TextStyle(color: Colors.white30, fontSize: 52)),
                  const SizedBox(height: 6),
                  const Text(
                    'Cornea → Pupil distance',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── ACD gauge ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF112233),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'ACD Depth Gauge  (0 – 6 mm)',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  LinearPercentIndicator(
                    lineHeight: 18,
                    percent: _gaugePercent,
                    backgroundColor: Colors.white12,
                    progressColor: _riskColor,
                    barRadius: const Radius.circular(9),
                    leading: const Text('0',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                    trailing: const Text('6mm',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                    center: result.detectionSuccess
                        ? Text(
                            '${result.acdMm} mm',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ECC71),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Normal range: 2.5 – 4.5 mm',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Risk classification card ───────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _riskColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _riskColor.withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_riskIcon, color: _riskColor, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.riskLevel,
                          style: TextStyle(
                            color: _riskColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          result.riskDescription,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.5,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Raw data rows ──────────────────────────────────────
            if (result.detectionSuccess) ...[
              _dataRow('ACD (pixels)', result.acdPixels.toStringAsFixed(1)),
              _dataRow('ACD (mm)', '${result.acdMm} mm'),
              _dataRow('Corneal diameter (px)',
                  result.cornealDiameterPx.toStringAsFixed(1)),
            ],

            const SizedBox(height: 24),

            // ── Disclaimer ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '⚠️  For screening purposes only. Does not replace a clinical '
                'examination. Consult a qualified ophthalmologist for diagnosis.',
                style:
                    TextStyle(color: Colors.white38, fontSize: 11, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // ── Retake button ─────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Retake Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38C5E0),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
