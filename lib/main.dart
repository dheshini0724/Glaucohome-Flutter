import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/home_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Camera init error: $e');
  }

  runApp(const GlaucomaApp());
}

class GlaucomaApp extends StatelessWidget {
  const GlaucomaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GlaucoScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A6E8A),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1120),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B1120),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      // Pass cameras to HomeScreen as the root
      home: HomeScreen(cameras: cameras),
    );
  }
}
