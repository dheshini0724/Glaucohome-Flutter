import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_screen.dart';
import 'research_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────
              const Text(
                'Glaucoband',
                style: TextStyle(
                  color: Color(0xFF38C5E0),
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Anterior Chamber Depth (ACD) Analysis',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 40),

              // ── Info card ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF112233),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF38C5E0), width: 1),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What is ACD?',
                      style: TextStyle(
                        color: Color(0xFF38C5E0),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Anterior Chamber Depth is the distance between the '
                      'cornea and the pupil. A shallow ACD (< 2.5 mm) is a '
                      'risk factor for angle-closure glaucoma.',
                      style: TextStyle(color: Colors.white70, height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ── Navigation buttons ────────────────────────────────
              _NavButton(
                icon: Icons.camera_alt_rounded,
                label: 'Capture Eye Image',
                subtitle: 'Use rear camera with flash',
                color: const Color(0xFF38C5E0),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CameraScreen(cameras: cameras),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _NavButton(
                icon: Icons.science_rounded,
                label: 'Research & Info',
                subtitle: 'ACD norms, glaucoma facts',
                color: const Color(0xFF5B8CFF),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResearchScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav Button Widget ─────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color.withOpacity(0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
