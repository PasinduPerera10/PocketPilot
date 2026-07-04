import 'package:flutter/material.dart';
import 'services/pocketpilot_service.dart';
import 'screens/pin_lock_screen.dart';
import 'screens/pairing_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/trackpad_screen.dart';
import 'screens/keyboard_screen.dart';
import 'screens/power_screen.dart';
import 'screens/screen_mirror_screen.dart';
import 'screens/file_browser_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PocketPilotApp());
}

class PocketPilotApp extends StatelessWidget {
  const PocketPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketPilot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.dark,
          primary: const Color(0xFF0F3460),
          secondary: const Color(0xFFE94560),
          surface: const Color(0xFF16213E),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F3460),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF16213E),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE94560),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

/// Splash screen that checks PIN and saved connection
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 500)); // Brief splash
    final service = PocketPilotService();

    // Check if PIN is set
    final hasPin = await service.hasPin();

    if (!mounted) return;

    if (hasPin) {
      // Go to PIN unlock screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PinLockScreen(service: service),
        ),
      );
    } else {
      // No PIN — check for saved connection and auto-connect
      final saved = await service.loadSavedConnection();
      if (!mounted) return;

      if (saved != null) {
        // Try to auto-connect to saved server
        final connected = await service.testConnection();
        if (!mounted) return;

        if (connected) {
          // Auto-connected! Go straight to dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardScreen(service: service),
            ),
          );
          return;
        }
      }

      // No saved connection or server unreachable — show pairing screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PairingScreen(service: service),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flight_takeoff, size: 80, color: Color(0xFFE94560)),
            const SizedBox(height: 16),
            const Text('PocketPilot',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                    color: Colors.white, letterSpacing: 2)),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Color(0xFFE94560)),
          ],
        ),
      ),
    );
  }
}